// Elaina tool tests cover the Dart CLI orchestration layer that replaced PS1.
// Keep policy in registries and assert runner behavior here.
// Avoid shell-specific assumptions so checks stay cross-platform.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tools/tooling/changed_test_runner.dart';
import '../../tools/tooling/module_check_runner.dart';
import '../../tools/tooling/process_runner.dart';
import '../../tools/tooling/tool_exception.dart';
import '../../tools/tooling/windows_release_packager.dart';

void main() {
  group('ModuleCheckRunner', () {
    test('runs required files, dependencies, term checks, and Dart scripts',
        () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      await _writeJson(root, 'tools/module_checks.json', <String, Object?>{
        'version': 1,
        'modules': <String, Object?>{
          'foundation': <String, Object?>{
            'requiredFiles': <String>['lib/foundation.dart'],
          },
          'feature': <String, Object?>{
            'dependsOnChecks': <String>['foundation'],
            'requiredFiles': <String>['lib/feature.dart'],
            'requiredTermsByFile': <String, Object?>{
              'lib/feature.dart': <String>['FeatureRuntime'],
            },
            'forbiddenTermsByFile': <String, Object?>{
              'lib/feature.dart': <String>['package:flutter/material.dart'],
            },
            'dartCheckScripts': <String>['tools/feature_contract.dart'],
          },
        },
      });
      await _writeText(root, 'lib/foundation.dart', 'class Foundation {}');
      await _writeText(root, 'lib/feature.dart', 'class FeatureRuntime {}');
      await _writeText(root, 'tools/feature_contract.dart', 'void main() {}');

      final _RecordingRunner processRunner = _RecordingRunner.success();
      await ModuleCheckRunner(
        projectRoot: root.path,
        processRunner: processRunner,
      ).runModule('feature');

      expect(processRunner.commands, <String>[
        'dart run tools/feature_contract.dart',
      ]);
    });

    test('fails fast when a required file is missing', () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      await _writeJson(root, 'tools/module_checks.json', <String, Object?>{
        'version': 1,
        'modules': <String, Object?>{
          'feature': <String, Object?>{
            'requiredFiles': <String>['lib/missing.dart'],
          },
        },
      });

      await expectLater(
        ModuleCheckRunner(
          projectRoot: root.path,
          processRunner: _RecordingRunner.success(),
        ).runModule('feature'),
        throwsA(isA<ToolException>().having(
          (ToolException error) => error.message,
          'message',
          contains('Missing required path'),
        )),
      );
    });

    test('fails fast when a forbidden term is present', () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      await _writeJson(root, 'tools/module_checks.json', <String, Object?>{
        'version': 1,
        'modules': <String, Object?>{
          'feature': <String, Object?>{
            'forbiddenTermsByFile': <String, Object?>{
              'lib/feature.dart': <String>['dart:ffi'],
            },
          },
        },
      });
      await _writeText(root, 'lib/feature.dart', "import 'dart:ffi';");

      await expectLater(
        ModuleCheckRunner(
          projectRoot: root.path,
          processRunner: _RecordingRunner.success(),
        ).runModule('feature'),
        throwsA(isA<ToolException>().having(
          (ToolException error) => error.message,
          'message',
          contains('forbidden term'),
        )),
      );
    });
  });

  group('ChangedTestRunner', () {
    test('selects suites from changed paths and runs focused commands',
        () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      await _writeJson(root, 'tools/test_suites.json', <String, Object?>{
        'suites': <Object?>[
          <String, Object?>{
            'name': 'tools',
            'runner': 'dart',
            'paths': <String>['test/tools'],
            'scopes': <String>['Fast', 'Module'],
            'triggers': <String>['tools/**'],
          },
          <String, Object?>{
            'name': 'ui',
            'runner': 'flutter',
            'paths': <String>['test/widget_test.dart'],
            'scopes': <String>['Module'],
            'triggers': <String>['lib/src/ui/**'],
          },
        ],
      });
      await Directory('${root.path}/test/tools').create(recursive: true);
      await _writeText(root, 'test/widget_test.dart', 'void main() {}');

      final _RecordingRunner processRunner = _RecordingRunner.success();
      await ChangedTestRunner(
        projectRoot: root.path,
        processRunner: processRunner,
      ).run(
        scope: ChangedTestScope.fast,
        changedPaths: <String>['tools/elaina_tool.dart'],
      );

      expect(processRunner.commands, <String>[
        'dart analyze',
        'dart test test/tools',
      ]);
    });

    test('full scope delegates to the Dart full gate runner', () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      await _writeJson(root, 'tools/test_suites.json', <String, Object?>{
        'suites': <Object?>[],
      });
      await _writeJson(root, 'tools/module_checks.json', <String, Object?>{
        'version': 1,
        'modules': <String, Object?>{
          for (final String module in FullGateRunnerTestData.releaseModules)
            module: <String, Object?>{},
        },
      });

      final _RecordingRunner processRunner = _RecordingRunner.success();
      await ChangedTestRunner(
        projectRoot: root.path,
        processRunner: processRunner,
      ).run(scope: ChangedTestScope.full);

      expect(
        processRunner.commands.take(4),
        <String>[
          'openspec.cmd validate --all',
          'dart analyze',
          'flutter analyze',
          'flutter test',
        ],
      );
    });
  });

  group('WindowsReleasePackager', () {
    test('stages libmpv and creates a zip with the executable and dll',
        () async {
      final Directory root = await _createTempProject();
      addTearDown(() => _deleteIfExists(root));
      final Directory release = Directory('${root.path}/release');
      await release.create(recursive: true);
      await File('${release.path}/Elaina.exe').writeAsString('exe');
      final File libMpv = File('${root.path}/libmpv-2.dll');
      await libMpv.writeAsString('dll');

      final String zipPath = '${root.path}/dist/elaina.zip';
      await WindowsReleasePackager(projectRoot: root.path).package(
        releaseDir: release.path,
        libMpvPath: libMpv.path,
        outputZip: zipPath,
      );

      expect(File('${release.path}/libmpv-2.dll').existsSync(), isTrue);
      expect(File(zipPath).existsSync(), isTrue);
    });
  });

  test('repository no longer tracks PowerShell scripts', () async {
    final ProcessResult result = await Process.run(
      'git',
      <String>['ls-files', '*.ps1'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), isEmpty);
  });
}

final class FullGateRunnerTestData {
  const FullGateRunnerTestData._();

  static const List<String> releaseModules = <String>[
    'player_core',
    'acg_data_experience',
    'library_smoke_gate',
    'advanced_playback_core',
    'automation_extension_core',
    'bt_streaming_smoke_gate',
    'diagnostics_center_runtime',
  ];
}

final class _RecordingRunner implements ToolProcessRunner {
  _RecordingRunner.success();

  final List<String> commands = <String>[];

  @override
  Future<ToolProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    commands.add(<String>[executable, ...arguments].join(' '));
    return ToolProcessResult(
      executable: executable,
      arguments: arguments,
      exitCode: 0,
      stdoutText: '',
      stderrText: '',
    );
  }
}

Future<Directory> _createTempProject() async {
  return Directory.systemTemp.createTemp('elaina_tool_test_');
}

Future<void> _deleteIfExists(Directory directory) async {
  if (directory.existsSync()) {
    await directory.delete(recursive: true);
  }
}

Future<void> _writeText(
  Directory root,
  String relativePath,
  String content,
) async {
  final File file = File('${root.path}/$relativePath');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

Future<void> _writeJson(
  Directory root,
  String relativePath,
  Map<String, Object?> content,
) {
  return _writeText(root, relativePath, jsonEncode(content));
}
