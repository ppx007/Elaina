import 'dart:convert';
import 'dart:io';

import 'process_runner.dart';
import 'tool_exception.dart';
import 'tool_paths.dart';

/// Executes declarative module checks from tools/module_checks.json.
///
/// This replaces the old pile of script-per-module entrypoints. Each module
/// describes required files, forbidden terms, and focused commands in data,
/// while this runner owns ordering, dependency recursion, and failure reporting.
final class ModuleCheckRunner {
  ModuleCheckRunner({
    required this.projectRoot,
    required ToolProcessRunner processRunner,
    this.dryRun = false,
    String registryPath = _defaultRegistryPath,
  })  : _registryPath = registryPath,
        _executor = ToolCommandExecutor(
          processRunner: processRunner,
          projectRoot: projectRoot,
          dryRun: dryRun,
        );

  static const String _defaultRegistryPath = 'tools/module_checks.json';
  static const String _dartExecutable = 'dart';
  static const String _flutterExecutable = 'flutter';
  static const String _dartRunSubcommand = 'run';
  static const String _dartTestSubcommand = 'test';
  static const String _flutterTestSubcommand = 'test';
  static const String _defaultRecursiveExtension = '.dart';

  static final RegExp _moduleNamePattern = RegExp(r'^[A-Za-z0-9_.-]+$');

  final String projectRoot;
  final bool dryRun;
  final String _registryPath;
  final ToolCommandExecutor _executor;

  ModuleCheckRegistry? _cachedRegistry;

  Future<void> runModule(String moduleName) async {
    _validateModuleName(moduleName);
    final ModuleCheckRegistry registry = _loadRegistry();
    await _runModule(
      moduleName,
      registry: registry,
      stack: <String>{},
      completed: <String>{},
    );
  }

  Future<void> runModules(Iterable<String> moduleNames) async {
    final ModuleCheckRegistry registry = _loadRegistry();
    final Set<String> completed = <String>{};
    for (final String moduleName in moduleNames) {
      _validateModuleName(moduleName);
      await _runModule(
        moduleName,
        registry: registry,
        stack: <String>{},
        completed: completed,
      );
    }
  }

  List<String> allModuleNames() {
    return _loadRegistry().modules.keys.toList(growable: false)..sort();
  }

  Future<void> _runModule(
    String moduleName, {
    required ModuleCheckRegistry registry,
    required Set<String> stack,
    required Set<String> completed,
  }) async {
    if (completed.contains(moduleName)) {
      stdout.writeln("Module check '$moduleName' already passed.");
      return;
    }
    final ModuleCheckDefinition? definition = registry.modules[moduleName];
    if (definition == null) {
      throw ToolException("Unknown module check '$moduleName'.");
    }
    if (stack.contains(moduleName)) {
      throw ToolException(
        'Module check dependency cycle: ${<String>[
          ...stack,
          moduleName
        ].join(' -> ')}',
      );
    }

    stdout.writeln("Starting module check '$moduleName'.");
    final Set<String> nextStack = <String>{...stack, moduleName};
    for (final String dependency in definition.dependsOnChecks) {
      await _runModule(
        dependency,
        registry: registry,
        stack: nextStack,
        completed: completed,
      );
    }

    _assertRequiredFiles(definition.requiredPaths);
    _assertRequiredTerms(definition.requiredTermsByFile);
    _assertForbiddenTerms(definition.forbiddenTermsByFile);
    _assertRecursiveForbiddenTerms(
      definition.recursiveForbiddenTermsByPath,
      extension: definition.recursiveFileExtension,
    );
    await _runDartScripts(definition.dartCheckScripts);
    await _runDartTests(definition.dartTestPaths);
    await _runFlutterTests(definition.flutterTestPaths);
    completed.add(moduleName);
    stdout.writeln("Module check '$moduleName' passed.");
  }

  ModuleCheckRegistry _loadRegistry() {
    final ModuleCheckRegistry? cached = _cachedRegistry;
    if (cached != null) {
      return cached;
    }
    final File file =
        File(ToolPaths.resolveProjectPath(projectRoot, _registryPath));
    if (!file.existsSync()) {
      throw ToolException(
          'Module check registry does not exist: $_registryPath');
    }
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const ToolException(
          'Module check registry root must be a JSON object.');
    }
    final ModuleCheckRegistry registry = ModuleCheckRegistry.fromJson(decoded);
    _cachedRegistry = registry;
    return registry;
  }

  void _assertRequiredFiles(List<String> paths) {
    for (final String path in paths) {
      final String resolved = ToolPaths.resolveProjectPath(projectRoot, path);
      if (FileSystemEntity.typeSync(resolved) ==
          FileSystemEntityType.notFound) {
        throw ToolException('Missing required path: $path');
      }
    }
  }

  void _assertRequiredTerms(Map<String, List<String>> termsByFile) {
    for (final MapEntry<String, List<String>> entry in termsByFile.entries) {
      final String content = _readProjectFile(entry.key);
      for (final String term in entry.value) {
        if (!content.contains(term)) {
          throw ToolException('${entry.key} is missing required term: $term');
        }
      }
    }
  }

  void _assertForbiddenTerms(Map<String, List<String>> termsByFile) {
    for (final MapEntry<String, List<String>> entry in termsByFile.entries) {
      final String content = _readProjectFile(entry.key);
      for (final String term in entry.value) {
        if (content.contains(term)) {
          throw ToolException('${entry.key} contains forbidden term: $term');
        }
      }
    }
  }

  void _assertRecursiveForbiddenTerms(
    Map<String, List<String>> termsByPath, {
    required String extension,
  }) {
    for (final MapEntry<String, List<String>> entry in termsByPath.entries) {
      final String resolved =
          ToolPaths.resolveProjectPath(projectRoot, entry.key);
      final Directory directory = Directory(resolved);
      if (!directory.existsSync()) {
        continue;
      }
      final Iterable<File> files = directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((File file) => file.path.endsWith(extension));
      for (final File file in files) {
        final String content = file.readAsStringSync();
        for (final String term in entry.value) {
          if (content.contains(term)) {
            throw ToolException(
              '${_relativePath(file.path)} contains forbidden term: $term',
            );
          }
        }
      }
    }
  }

  Future<void> _runDartScripts(List<String> scripts) async {
    for (final String script in scripts) {
      await _executor.run(
        'Dart check script $script',
        _dartExecutable,
        <String>[_dartRunSubcommand, script],
      );
    }
  }

  Future<void> _runDartTests(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    await _executor.run(
      'Dart module tests',
      _dartExecutable,
      <String>[_dartTestSubcommand, ...paths],
    );
  }

  Future<void> _runFlutterTests(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    await _executor.run(
      'Flutter module tests',
      _flutterExecutable,
      <String>[_flutterTestSubcommand, ...paths],
    );
  }

  String _readProjectFile(String path) {
    final File file = File(ToolPaths.resolveProjectPath(projectRoot, path));
    if (!file.existsSync()) {
      throw ToolException('Required file does not exist: $path');
    }
    return file.readAsStringSync();
  }

  String _relativePath(String absolutePath) {
    final String normalizedRoot = ToolPaths.normalizeToken(projectRoot);
    final String normalizedPath = ToolPaths.normalizeToken(absolutePath);
    if (normalizedPath.startsWith(normalizedRoot)) {
      return normalizedPath
          .substring(normalizedRoot.length)
          .replaceFirst('/', '');
    }
    return normalizedPath;
  }

  static void _validateModuleName(String value) {
    if (value.isEmpty || !_moduleNamePattern.hasMatch(value)) {
      throw ToolException(
        "Invalid module name '$value'. Use letters, numbers, dots, dashes, "
        'or underscores.',
      );
    }
  }
}

final class ModuleCheckRegistry {
  const ModuleCheckRegistry({required this.modules});

  final Map<String, ModuleCheckDefinition> modules;

  factory ModuleCheckRegistry.fromJson(Map<String, Object?> json) {
    final Object? modulesJson = json['modules'];
    if (modulesJson is! Map<String, Object?>) {
      throw const ToolException('Module check registry must contain modules.');
    }
    final Map<String, ModuleCheckDefinition> modules =
        <String, ModuleCheckDefinition>{};
    for (final MapEntry<String, Object?> entry in modulesJson.entries) {
      if (entry.value is! Map<String, Object?>) {
        throw ToolException("Module '${entry.key}' must be a JSON object.");
      }
      modules[entry.key] = ModuleCheckDefinition.fromJson(
        entry.value! as Map<String, Object?>,
      );
    }
    return ModuleCheckRegistry(
        modules: Map<String, ModuleCheckDefinition>.unmodifiable(modules));
  }
}

final class ModuleCheckDefinition {
  const ModuleCheckDefinition({
    required this.dependsOnChecks,
    required this.requiredPaths,
    required this.requiredTermsByFile,
    required this.forbiddenTermsByFile,
    required this.recursiveForbiddenTermsByPath,
    required this.recursiveFileExtension,
    required this.dartCheckScripts,
    required this.dartTestPaths,
    required this.flutterTestPaths,
  });

  final List<String> dependsOnChecks;
  final List<String> requiredPaths;
  final Map<String, List<String>> requiredTermsByFile;
  final Map<String, List<String>> forbiddenTermsByFile;
  final Map<String, List<String>> recursiveForbiddenTermsByPath;
  final String recursiveFileExtension;
  final List<String> dartCheckScripts;
  final List<String> dartTestPaths;
  final List<String> flutterTestPaths;

  factory ModuleCheckDefinition.fromJson(Map<String, Object?> json) {
    return ModuleCheckDefinition(
      dependsOnChecks: _stringList(json['dependsOnChecks']),
      requiredPaths: <String>{
        ..._stringList(json['requiredFiles']),
        ..._stringList(json['contracts']),
        ..._stringList(json['dartCheckScripts']),
        ..._stringList(json['dartTestPaths']),
        ..._stringList(json['flutterTestPaths']),
      }.toList(growable: false),
      requiredTermsByFile: _stringListMap(json['requiredTermsByFile']),
      forbiddenTermsByFile: _stringListMap(json['forbiddenTermsByFile']),
      recursiveForbiddenTermsByPath:
          _stringListMap(json['recursiveForbiddenTermsByPath']),
      recursiveFileExtension: _stringValue(json['recursiveFileExtension']) ??
          ModuleCheckRunner._defaultRecursiveExtension,
      dartCheckScripts: _stringList(json['dartCheckScripts']),
      dartTestPaths: _stringList(json['dartTestPaths']),
      flutterTestPaths: _stringList(json['flutterTestPaths']),
    );
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw const ToolException('Expected a non-empty string.');
    }
    return value;
  }

  static List<String> _stringList(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is String) {
      return <String>[value];
    }
    if (value is! List<Object?>) {
      throw const ToolException('Expected a string list.');
    }
    return List<String>.unmodifiable(value.map((Object? item) {
      if (item is! String || item.trim().isEmpty) {
        throw const ToolException('Expected only non-empty strings.');
      }
      return item;
    }));
  }

  static Map<String, List<String>> _stringListMap(Object? value) {
    if (value == null) {
      return const <String, List<String>>{};
    }
    if (value is! Map<String, Object?>) {
      throw const ToolException('Expected an object with string list values.');
    }
    final Map<String, List<String>> result = <String, List<String>>{};
    for (final MapEntry<String, Object?> entry in value.entries) {
      result[entry.key] = _stringList(entry.value);
    }
    return Map<String, List<String>>.unmodifiable(result);
  }
}
