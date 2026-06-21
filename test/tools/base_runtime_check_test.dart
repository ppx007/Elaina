import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../tools/runtime_check_base.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  test('returns normally when the PowerShell check exits with code 0',
      () async {
    final Directory projectRoot = await _createProjectRoot();
    addTearDown(() async {
      if (await projectRoot.exists()) {
        await projectRoot.delete(recursive: true);
      }
    });

    final _MockProcessRunner runner = _MockProcessRunner();
    late String capturedExecutable;
    late List<String> capturedArguments;
    when(() => runner(any(), any())).thenAnswer((Invocation invocation) async {
      capturedExecutable = invocation.positionalArguments[0] as String;
      capturedArguments =
          List<String>.from(invocation.positionalArguments[1] as List<String>);
      return ProcessResult(1001, 0, 'runtime ok', '');
    });

    final _RuntimeCheckUnderTest check = _RuntimeCheckUnderTest(
      moduleName: 'bangumi_runtime',
      processRunner: runner.call,
    );

    final RuntimeCheckResult result = await check.execute(<String>[
      '--project-root',
      projectRoot.path,
      '--powershell',
      'pwsh-test',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdoutText, 'runtime ok');
    expect(result.stderrText, isEmpty);
    expect(capturedExecutable, 'pwsh-test');
    expect(
        capturedArguments,
        containsAllInOrder(<String>[
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
        ]));
    expect(
        capturedArguments,
        containsAllInOrder(<String>[
          '-Module',
          'bangumi_runtime',
          '-ProjectRoot',
          projectRoot.path,
        ]));
    verify(() => runner(any(), any())).called(1);
  });

  test('throws RuntimeCheckException with extracted logs on non-zero exit',
      () async {
    final Directory projectRoot = await _createProjectRoot();
    addTearDown(() async {
      if (await projectRoot.exists()) {
        await projectRoot.delete(recursive: true);
      }
    });

    final _MockProcessRunner runner = _MockProcessRunner();
    when(() => runner(any(), any())).thenAnswer((_) async {
      return ProcessResult(
        1002,
        17,
        'stdout progress before failure',
        'stderr failure detail',
      );
    });

    final _RuntimeCheckUnderTest check = _RuntimeCheckUnderTest(
      moduleName: 'player_core',
      processRunner: runner.call,
    );

    await expectLater(
      check.execute(<String>[
        '--project-root',
        projectRoot.path,
        '--powershell',
        'pwsh-test',
      ]),
      throwsA(
        isA<RuntimeCheckException>()
            .having(
                (RuntimeCheckException error) => error.exitCode, 'exitCode', 17)
            .having((RuntimeCheckException error) => error.moduleName,
                'moduleName', 'player_core')
            .having((RuntimeCheckException error) => error.stderrText,
                'stderrText', contains('stderr failure detail'))
            .having((RuntimeCheckException error) => error.stdoutText,
                'stdoutText', contains('stdout progress before failure'))
            .having(
              (RuntimeCheckException error) => error.errorLog,
              'errorLog',
              allOf(
                contains('stdout progress before failure'),
                contains('stderr failure detail'),
              ),
            ),
      ),
    );
    verify(() => runner(any(), any())).called(1);
  });

  test('rejects invalid parameters before invoking PowerShell', () async {
    final _MockProcessRunner runner = _MockProcessRunner();
    final _RuntimeCheckUnderTest check = _RuntimeCheckUnderTest(
      moduleName: 'bad module',
      processRunner: runner.call,
    );

    await expectLater(
      check.execute(<String>['--project-root', 'unused']),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('Invalid moduleName'),
        ),
      ),
    );
    verifyNever(() => runner(any(), any()));
  });

  test('rejects options missing a required value before invoking PowerShell',
      () async {
    final _MockProcessRunner runner = _MockProcessRunner();
    final _RuntimeCheckUnderTest check = _RuntimeCheckUnderTest(
      moduleName: 'bangumi_runtime',
      processRunner: runner.call,
    );

    await expectLater(
      check.execute(<String>['--project-root']),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('Missing value for --project-root'),
        ),
      ),
    );
    verifyNever(() => runner(any(), any()));
  });

  test('runtime check entrypoints resolve to module proxies and contracts', () {
    final Directory toolsDirectory = Directory('tools');
    final List<File> entrypoints = toolsDirectory
        .listSync(followLinks: false)
        .whereType<File>()
        .where((File file) => _fileName(file.path).endsWith(
              '_runtime_check.dart',
            ))
        .toList()
      ..sort((File left, File right) => left.path.compareTo(right.path));

    expect(entrypoints, isNotEmpty);
    for (final File entrypoint in entrypoints) {
      final String entrypointName = _fileName(entrypoint.path);
      final String source = entrypoint.readAsStringSync();
      final RegExpMatch? moduleNameMatch = RegExp(
        r"String get moduleName => '([A-Za-z0-9_.-]+)';",
      ).firstMatch(source);
      expect(
        moduleNameMatch,
        isNotNull,
        reason: '$entrypointName must expose a literal moduleName getter.',
      );
      final String moduleName = moduleNameMatch!.group(1)!;
      final File moduleProxy = File(
        'tools${Platform.pathSeparator}check_$moduleName.ps1',
      );
      expect(
        moduleProxy.existsSync(),
        isTrue,
        reason: '$entrypointName points at missing module proxy $moduleName.',
      );

      final String contractName = entrypointName.replaceFirst(
        '_runtime_check.dart',
        '_runtime_contract.dart',
      );
      final File contractFile = File(
        'tools${Platform.pathSeparator}runtime_checks'
        '${Platform.pathSeparator}$contractName',
      );
      expect(
        contractFile.existsSync(),
        isTrue,
        reason: '$entrypointName must keep its implementation in '
            'tools/runtime_checks/$contractName.',
      );
    }
  });
}

final class _RuntimeCheckUnderTest extends BaseRuntimeCheck {
  const _RuntimeCheckUnderTest({
    required this.moduleName,
    RuntimeCheckProcessRunner? processRunner,
  }) : super(processRunner: processRunner);

  @override
  final String moduleName;
}

final class _MockProcessRunner extends Mock {
  Future<ProcessResult> call(String executable, List<String> arguments);
}

Future<Directory> _createProjectRoot() async {
  final Directory directory =
      await Directory.systemTemp.createTemp('base_runtime_check_test_');
  final File script = File(
    '${directory.path}${Platform.pathSeparator}Invoke-ModuleCheck.ps1',
  );
  await script.writeAsString('# test module check script');
  return directory;
}

String _fileName(String path) {
  return path.split(Platform.pathSeparator).last;
}
