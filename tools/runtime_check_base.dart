import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef RuntimeCheckProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

Future<ProcessResult> runRuntimeCheckProcess(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}

final class RuntimeCheckResult {
  const RuntimeCheckResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  final int exitCode;
  final String stdoutText;
  final String stderrText;
}

final class RuntimeCheckException implements Exception {
  RuntimeCheckException({
    required this.moduleName,
    required this.exitCode,
    required this.executable,
    required List<String> arguments,
    required this.stdoutText,
    required this.stderrText,
  }) : arguments = List<String>.unmodifiable(arguments);

  final String moduleName;
  final int exitCode;
  final String executable;
  final List<String> arguments;
  final String stdoutText;
  final String stderrText;

  String get message =>
      "Module check '$moduleName' failed with exit code $exitCode.";

  String get errorLog {
    final List<String> parts = <String>[
      stdoutText.trim(),
      stderrText.trim(),
    ].where((String text) => text.isNotEmpty).toList(growable: false);
    return parts.join('\n');
  }

  @override
  String toString() {
    final String log = errorLog;
    if (log.isEmpty) {
      return message;
    }
    return '$message\n$log';
  }
}

abstract base class BaseRuntimeCheck {
  const BaseRuntimeCheck({
    RuntimeCheckProcessRunner? processRunner,
  }) : _processRunner = processRunner;

  static const String _moduleCheckScriptName = 'Invoke-ModuleCheck.ps1';
  static const String _defaultToolsDirectory = 'tools';
  static const String _windowsPowerShellExecutable = 'powershell.exe';
  static const String _portablePowerShellExecutable = 'pwsh';
  static const int _successExitCode = 0;
  static const int _failureExitCode = 1;
  static const int _usageErrorExitCode = 64;

  static final RegExp _moduleNamePattern = RegExp(r'^[A-Za-z0-9_.-]+$');

  final RuntimeCheckProcessRunner? _processRunner;

  String get moduleName;

  Future<void> run(List<String> arguments) async {
    try {
      final RuntimeCheckResult result = await execute(arguments);
      _writeOutput(stdout, result.stdoutText);
      _writeOutput(stderr, result.stderrText);
      exitCode = result.exitCode;
    } on RuntimeCheckException catch (error) {
      stderr.writeln(error.message);
      _writeOutput(stdout, error.stdoutText);
      _writeOutput(stderr, error.stderrText);
      exitCode = error.exitCode == _successExitCode
          ? _failureExitCode
          : error.exitCode;
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      stderr.writeln('Run with --help to see supported runtime check options.');
      exitCode = _usageErrorExitCode;
    } on ProcessException catch (error) {
      stderr.writeln(error.message);
      exitCode = _failureExitCode;
    } on FileSystemException catch (error) {
      stderr.writeln(error.message);
      exitCode = _failureExitCode;
    }
  }

  Future<RuntimeCheckResult> execute(List<String> arguments) async {
    _validateModuleName(moduleName);
    final _RuntimeCheckOptions options = _RuntimeCheckOptions.parse(arguments);
    if (options.showHelp) {
      return RuntimeCheckResult(
        exitCode: _successExitCode,
        stdoutText: _usageText,
        stderrText: '',
      );
    }

    final String projectRoot = options.projectRoot ?? _findDefaultProjectRoot();
    final String scriptPath = _resolveModuleCheckScript(projectRoot);
    return _runModuleCheck(
      options: options,
      projectRoot: projectRoot,
      scriptPath: scriptPath,
    );
  }

  Future<RuntimeCheckResult> _runModuleCheck({
    required _RuntimeCheckOptions options,
    required String projectRoot,
    required String scriptPath,
  }) async {
    final String powerShellExecutable = options.powerShellExecutable ??
        (Platform.isWindows
            ? _windowsPowerShellExecutable
            : _portablePowerShellExecutable);
    final List<String> processArguments = <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      '-Module',
      moduleName,
      '-ProjectRoot',
      projectRoot,
      '-ToolsDirectory',
      options.toolsDirectory,
      if (options.skipLegacyScript) '-SkipLegacyScript',
      if (options.whatIf) '-WhatIf',
      if (options.passThru) '-PassThru',
      if (options.scriptArguments.isNotEmpty) ...<String>[
        '-ScriptArgumentsBase64',
        _encodeScriptArguments(options.scriptArguments),
      ],
    ];

    final ProcessResult result =
        await (_processRunner ?? runRuntimeCheckProcess)(
      powerShellExecutable,
      processArguments,
    );
    final RuntimeCheckResult runtimeResult = RuntimeCheckResult(
      exitCode: result.exitCode,
      stdoutText: _processOutputToString(result.stdout),
      stderrText: _processOutputToString(result.stderr),
    );
    if (runtimeResult.exitCode != _successExitCode) {
      throw RuntimeCheckException(
        moduleName: moduleName,
        exitCode: runtimeResult.exitCode,
        executable: powerShellExecutable,
        arguments: processArguments,
        stdoutText: runtimeResult.stdoutText,
        stderrText: runtimeResult.stderrText,
      );
    }
    return runtimeResult;
  }

  static void _validateModuleName(String value) {
    if (value.isEmpty || !_moduleNamePattern.hasMatch(value)) {
      throw FormatException(
        "Invalid moduleName '$value'. Use letters, numbers, dots, dashes, "
        'or underscores.',
      );
    }
  }

  static String _findDefaultProjectRoot() {
    final Directory current = Directory.current;
    if (_hasModuleCheckScript(current.path)) {
      return current.path;
    }

    final Uri scriptUri = Platform.script;
    if (scriptUri.isScheme('file')) {
      Directory cursor = File.fromUri(scriptUri).parent;
      while (true) {
        if (_hasModuleCheckScript(cursor.path)) {
          return cursor.path;
        }
        final Directory parent = cursor.parent;
        if (parent.path == cursor.path) {
          break;
        }
        cursor = parent;
      }
    }

    throw const FileSystemException(
      'Could not find Invoke-ModuleCheck.ps1 from the current directory or '
      'the runtime check script path.',
    );
  }

  static String _resolveModuleCheckScript(String projectRoot) {
    final String scriptPath = _joinPath(projectRoot, _moduleCheckScriptName);
    if (!File(scriptPath).existsSync()) {
      throw FileSystemException(
          'Module check script does not exist.', scriptPath);
    }
    return scriptPath;
  }

  static bool _hasModuleCheckScript(String directoryPath) {
    return File(_joinPath(directoryPath, _moduleCheckScriptName)).existsSync();
  }

  static String _joinPath(String first, String second) {
    if (first.endsWith('/') || first.endsWith(r'\')) {
      return '$first$second';
    }
    return '$first${Platform.pathSeparator}$second';
  }

  static String _encodeScriptArguments(List<String> arguments) {
    final String jsonText = jsonEncode(arguments);
    return base64.encode(utf8.encode(jsonText));
  }

  static String _processOutputToString(Object? output) {
    if (output == null) {
      return '';
    }
    if (output is String) {
      return output;
    }
    if (output is List<int>) {
      return utf8.decode(output);
    }
    return output.toString();
  }

  static void _writeOutput(IOSink sink, String text) {
    if (text.isEmpty) {
      return;
    }
    sink.write(text);
    if (!text.endsWith('\n')) {
      sink.writeln();
    }
  }

  String get _usageText {
    return '''
Runs the shared PowerShell module check for "$moduleName".

Usage:
  dart run tools/runtime_check.dart --module $moduleName [options] [-- legacy script args]

Options:
  -h, --help                  Show this help text.
      --project-root <path>   Project root containing Invoke-ModuleCheck.ps1.
      --tools-directory <dir> Tools directory passed to Invoke-ModuleCheck.ps1.
      --powershell <path>     PowerShell executable. Defaults to powershell.exe on Windows.
      --what-if               Forward -WhatIf to Invoke-ModuleCheck.ps1.
      --pass-thru             Forward -PassThru to Invoke-ModuleCheck.ps1.
      --skip-legacy-script    Forward -SkipLegacyScript to Invoke-ModuleCheck.ps1.

Unknown arguments are passed through to the wrapped legacy script.''';
  }
}

final class _RuntimeCheckOptions {
  const _RuntimeCheckOptions({
    required this.showHelp,
    required this.whatIf,
    required this.passThru,
    required this.skipLegacyScript,
    required this.toolsDirectory,
    required this.scriptArguments,
    this.projectRoot,
    this.powerShellExecutable,
  });

  final bool showHelp;
  final bool whatIf;
  final bool passThru;
  final bool skipLegacyScript;
  final String? projectRoot;
  final String toolsDirectory;
  final String? powerShellExecutable;
  final List<String> scriptArguments;

  static _RuntimeCheckOptions parse(List<String> arguments) {
    bool showHelp = false;
    bool whatIf = false;
    bool passThru = false;
    bool skipLegacyScript = false;
    String? projectRoot;
    String toolsDirectory = BaseRuntimeCheck._defaultToolsDirectory;
    String? powerShellExecutable;
    final List<String> scriptArguments = <String>[];

    for (int index = 0; index < arguments.length; index += 1) {
      final String argument = arguments[index];
      if (argument == '--') {
        scriptArguments.addAll(arguments.skip(index + 1));
        break;
      }

      switch (argument) {
        case '-h':
        case '--help':
          showHelp = true;
          break;
        case '--what-if':
          whatIf = true;
          break;
        case '--pass-thru':
          passThru = true;
          break;
        case '--skip-legacy-script':
          skipLegacyScript = true;
          break;
        case '--project-root':
          projectRoot = _readOptionValue(
            arguments: arguments,
            option: argument,
            index: index,
          );
          index += 1;
          break;
        case '--tools-directory':
          toolsDirectory = _readOptionValue(
            arguments: arguments,
            option: argument,
            index: index,
          );
          index += 1;
          break;
        case '--powershell':
        case '--powershell-executable':
          powerShellExecutable = _readOptionValue(
            arguments: arguments,
            option: argument,
            index: index,
          );
          index += 1;
          break;
        default:
          final _OptionAssignment? assignment =
              _OptionAssignment.tryParse(argument);
          if (assignment == null) {
            scriptArguments.add(argument);
            continue;
          }
          switch (assignment.name) {
            case '--project-root':
              projectRoot = assignment.value;
              break;
            case '--tools-directory':
              toolsDirectory = assignment.value;
              break;
            case '--powershell':
            case '--powershell-executable':
              powerShellExecutable = assignment.value;
              break;
            default:
              scriptArguments.add(argument);
              break;
          }
      }
    }

    return _RuntimeCheckOptions(
      showHelp: showHelp,
      whatIf: whatIf,
      passThru: passThru,
      skipLegacyScript: skipLegacyScript,
      projectRoot: projectRoot,
      toolsDirectory: toolsDirectory,
      powerShellExecutable: powerShellExecutable,
      scriptArguments: List<String>.unmodifiable(scriptArguments),
    );
  }

  static String _readOptionValue({
    required List<String> arguments,
    required String option,
    required int index,
  }) {
    final int valueIndex = index + 1;
    if (valueIndex >= arguments.length) {
      throw FormatException('Missing value for $option.');
    }
    final String value = arguments[valueIndex];
    if (value.isEmpty) {
      throw FormatException('Empty value for $option.');
    }
    return value;
  }
}

final class _OptionAssignment {
  const _OptionAssignment({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  static _OptionAssignment? tryParse(String argument) {
    final int separatorIndex = argument.indexOf('=');
    if (separatorIndex <= 0) {
      return null;
    }
    final String name = argument.substring(0, separatorIndex);
    final String value = argument.substring(separatorIndex + 1);
    if (value.isEmpty) {
      throw FormatException('Empty value for $name.');
    }
    return _OptionAssignment(name: name, value: value);
  }
}
