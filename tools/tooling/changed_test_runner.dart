import 'dart:convert';
import 'dart:io';

import 'full_gate_runner.dart';
import 'process_runner.dart';
import 'tool_exception.dart';
import 'tool_paths.dart';

enum ChangedTestScope {
  fast('Fast'),
  module('Module'),
  full('Full');

  const ChangedTestScope(this.label);

  final String label;

  static ChangedTestScope parse(String value) {
    for (final ChangedTestScope scope in ChangedTestScope.values) {
      if (scope.label.toLowerCase() == value.toLowerCase()) {
        return scope;
      }
    }
    throw ToolException('Unsupported changed-test scope: $value');
  }
}

/// Runs the validation subset selected from tools/test_suites.json.
///
/// The selection logic is data-driven so adding a page or module means editing
/// the registry, not branching this runner. Fast/Module scopes therefore stay
/// cheap enough for everyday UI work while Full remains the release gate.
final class ChangedTestRunner {
  ChangedTestRunner({
    required this.projectRoot,
    required ToolProcessRunner processRunner,
    this.dryRun = false,
    String registryPath = _defaultRegistryPath,
  })  : _registryPath = registryPath,
        _processRunner = processRunner,
        _executor = ToolCommandExecutor(
          processRunner: processRunner,
          projectRoot: projectRoot,
          dryRun: dryRun,
        );

  static const String _defaultRegistryPath = 'tools/test_suites.json';
  static const String _dartExecutable = 'dart';
  static const String _flutterExecutable = 'flutter';
  static const String _gitExecutable = 'git';
  static const String _analyzeSubcommand = 'analyze';
  static const String _testSubcommand = 'test';

  final String projectRoot;
  final bool dryRun;
  final String _registryPath;
  final ToolProcessRunner _processRunner;
  final ToolCommandExecutor _executor;

  Future<void> run({
    required ChangedTestScope scope,
    List<String> changedPaths = const <String>[],
  }) async {
    if (scope == ChangedTestScope.full) {
      await FullGateRunner(
        projectRoot: projectRoot,
        processRunner: _processRunner,
        dryRun: dryRun,
      ).run();
      return;
    }

    final TestSuiteRegistry registry = _loadRegistry();
    final List<String> paths = changedPaths.isEmpty
        ? await _discoverChangedPaths()
        : changedPaths.map(ToolPaths.normalizeToken).toList(growable: false);

    stdout.writeln('Changed test gate scope: ${scope.label}');
    if (paths.isEmpty) {
      stdout.writeln('Changed test gate: no changed paths detected.');
    } else {
      stdout.writeln('Changed test gate paths:');
      for (final String path in paths) {
        stdout.writeln('  $path');
      }
    }

    final List<TestSuiteDefinition> suites = _selectSuites(
      registry: registry,
      scope: scope,
      changedPaths: paths,
    );
    if (suites.isNotEmpty) {
      stdout.writeln('Changed test gate suites:');
      for (final TestSuiteDefinition suite in suites) {
        stdout.writeln('  ${suite.name}');
      }
    }

    final _RunnerGroups groups = _runnerGroups(suites);
    await _executor.run(
      'dart analyze',
      _dartExecutable,
      const <String>[_analyzeSubcommand],
    );
    if (groups.dartTests.isNotEmpty) {
      await _executor.run(
        'dart targeted tests',
        _dartExecutable,
        <String>[_testSubcommand, ...groups.dartTests],
      );
    }
    if (groups.flutterTestsWithoutExtraArgs.isNotEmpty) {
      await _executor.run(
        'flutter targeted tests',
        _flutterExecutable,
        <String>[_testSubcommand, ...groups.flutterTestsWithoutExtraArgs],
      );
    }
    for (final MapEntry<String, List<String>> entry
        in groups.flutterExtraArgsByPath.entries) {
      await _executor.run(
        'flutter targeted test ${entry.key}',
        _flutterExecutable,
        <String>[_testSubcommand, entry.key, ...entry.value],
      );
    }
    if (groups.flutterTestsWithoutExtraArgs.isEmpty &&
        groups.flutterExtraArgsByPath.isEmpty) {
      stdout.writeln('Changed test gate: no targeted Flutter tests selected.');
    }
  }

  TestSuiteRegistry _loadRegistry() {
    final File file =
        File(ToolPaths.resolveProjectPath(projectRoot, _registryPath));
    if (!file.existsSync()) {
      throw ToolException('Test suite registry does not exist: $_registryPath');
    }
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const ToolException('Test suite registry root must be an object.');
    }
    return TestSuiteRegistry.fromJson(decoded);
  }

  Future<List<String>> _discoverChangedPaths() async {
    final ToolProcessResult tracked = await _processRunner.run(
      _gitExecutable,
      const <String>['diff', '--name-only', 'HEAD'],
      workingDirectory: projectRoot,
    );
    if (tracked.exitCode != ToolExitCodes.success) {
      throw ToolException('git diff failed while selecting changed tests.');
    }
    final ToolProcessResult untracked = await _processRunner.run(
      _gitExecutable,
      const <String>['ls-files', '--others', '--exclude-standard'],
      workingDirectory: projectRoot,
    );
    if (untracked.exitCode != ToolExitCodes.success) {
      throw ToolException('git ls-files failed while selecting changed tests.');
    }
    final Set<String> paths = <String>{};
    for (final String line in <String>[
      ...tracked.stdoutText.split(RegExp(r'\r?\n')),
      ...untracked.stdoutText.split(RegExp(r'\r?\n')),
    ]) {
      final String path = ToolPaths.normalizeToken(line);
      if (path.isNotEmpty) {
        paths.add(path);
      }
    }
    return paths.toList(growable: false)..sort();
  }

  List<TestSuiteDefinition> _selectSuites({
    required TestSuiteRegistry registry,
    required ChangedTestScope scope,
    required List<String> changedPaths,
  }) {
    final List<TestSuiteDefinition> selected = <TestSuiteDefinition>[];
    for (final TestSuiteDefinition suite in registry.suites) {
      if (!suite.supports(scope)) {
        continue;
      }
      final bool matched = changedPaths.any(
        (String path) => suite.triggers.any(
          (String trigger) => ToolPaths.matchesGlob(path, trigger),
        ),
      );
      if (matched) {
        selected.add(suite);
      }
    }
    selected.sort(
      (TestSuiteDefinition left, TestSuiteDefinition right) =>
          left.name.compareTo(right.name),
    );
    return selected;
  }

  _RunnerGroups _runnerGroups(List<TestSuiteDefinition> suites) {
    final Set<String> dartTests = <String>{};
    final Set<String> flutterTests = <String>{};
    final Map<String, List<String>> flutterExtraArgsByPath =
        <String, List<String>>{};

    for (final TestSuiteDefinition suite in suites) {
      for (final String path in suite.paths) {
        final String resolved = ToolPaths.resolveProjectPath(projectRoot, path);
        if (FileSystemEntity.typeSync(resolved) ==
            FileSystemEntityType.notFound) {
          continue;
        }
        switch (suite.runner) {
          case TestSuiteRunner.dart:
            dartTests.add(path);
            break;
          case TestSuiteRunner.flutter:
            if (suite.extraArgs.isEmpty) {
              flutterTests.add(path);
            } else {
              flutterExtraArgsByPath[path] = suite.extraArgs;
            }
            break;
        }
      }
    }

    final List<String> sortedDartTests = dartTests.toList(growable: false)
      ..sort();
    final List<String> sortedFlutterTests = flutterTests.toList(growable: false)
      ..sort();
    return _RunnerGroups(
      dartTests: sortedDartTests,
      flutterTestsWithoutExtraArgs: sortedFlutterTests,
      flutterExtraArgsByPath:
          Map<String, List<String>>.unmodifiable(flutterExtraArgsByPath),
    );
  }
}

final class TestSuiteRegistry {
  const TestSuiteRegistry({required this.suites});

  final List<TestSuiteDefinition> suites;

  factory TestSuiteRegistry.fromJson(Map<String, Object?> json) {
    final Object? suitesJson = json['suites'];
    if (suitesJson is! List<Object?>) {
      throw const ToolException('Test suite registry must contain suites.');
    }
    return TestSuiteRegistry(
      suites: List<TestSuiteDefinition>.unmodifiable(
        suitesJson.map((Object? value) {
          if (value is! Map<String, Object?>) {
            throw const ToolException('Test suite entry must be an object.');
          }
          return TestSuiteDefinition.fromJson(value);
        }),
      ),
    );
  }
}

enum TestSuiteRunner {
  dart,
  flutter;

  static TestSuiteRunner parse(String value) {
    return switch (value) {
      'dart' => TestSuiteRunner.dart,
      'flutter' => TestSuiteRunner.flutter,
      _ => throw ToolException('Unsupported test suite runner: $value'),
    };
  }
}

final class TestSuiteDefinition {
  const TestSuiteDefinition({
    required this.name,
    required this.runner,
    required this.paths,
    required this.scopes,
    required this.triggers,
    required this.extraArgs,
  });

  final String name;
  final TestSuiteRunner runner;
  final List<String> paths;
  final List<ChangedTestScope> scopes;
  final List<String> triggers;
  final List<String> extraArgs;

  bool supports(ChangedTestScope scope) {
    return switch (scope) {
      ChangedTestScope.fast => scopes.contains(ChangedTestScope.fast),
      ChangedTestScope.module => scopes.contains(ChangedTestScope.fast) ||
          scopes.contains(ChangedTestScope.module),
      ChangedTestScope.full => false,
    };
  }

  factory TestSuiteDefinition.fromJson(Map<String, Object?> json) {
    return TestSuiteDefinition(
      name: _requiredString(json, 'name'),
      runner: TestSuiteRunner.parse(_requiredString(json, 'runner')),
      paths: _stringList(json['paths']),
      scopes: _stringList(json['scopes']).map(ChangedTestScope.parse).toList(),
      triggers: _stringList(json['triggers']),
      extraArgs: _stringList(json['extraArgs']),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw ToolException('Test suite field $key must be a non-empty string.');
    }
    return value;
  }

  static List<String> _stringList(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List<Object?>) {
      throw const ToolException(
          'Expected a string list in test suite registry.');
    }
    return List<String>.unmodifiable(value.map((Object? item) {
      if (item is! String || item.trim().isEmpty) {
        throw const ToolException('Expected non-empty string list values.');
      }
      return item;
    }));
  }
}

final class _RunnerGroups {
  const _RunnerGroups({
    required this.dartTests,
    required this.flutterTestsWithoutExtraArgs,
    required this.flutterExtraArgsByPath,
  });

  final List<String> dartTests;
  final List<String> flutterTestsWithoutExtraArgs;
  final Map<String, List<String>> flutterExtraArgsByPath;
}
