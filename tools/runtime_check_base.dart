import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract base class BaseRuntimeCheck {
  const BaseRuntimeCheck();

  static const String _moduleCheckScriptName = 'Invoke-ModuleCheck.ps1';
  static const String _defaultToolsDirectory = 'tools';
  static const String _windowsPowerShellExecutable = 'powershell.exe';
  static const String _portablePowerShellExecutable = 'pwsh';
  static const int _successExitCode = 0;
  static const int _failureExitCode = 1;
  static const int _usageErrorExitCode = 64;

  static final RegExp _moduleNamePattern = RegExp(r'^[A-Za-z0-9_.-]+$');

  String get moduleName;

  Future<void> run(List<String> arguments) async {
    try {
      _validateModuleName(moduleName);
      final _RuntimeCheckOptions options =
          _RuntimeCheckOptions.parse(arguments);
      if (options.showHelp) {
        stdout.writeln(_usageText);
        exitCode = _successExitCode;
        return;
      }

      final String projectRoot =
          options.projectRoot ?? _findDefaultProjectRoot();
      final String scriptPath = _resolveModuleCheckScript(projectRoot);
      final int processExitCode = await _runModuleCheck(
        options: options,
        projectRoot: projectRoot,
        scriptPath: scriptPath,
      );
      exitCode = processExitCode;
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

  Future<int> _runModuleCheck({
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

    final Process process = await Process.start(
      powerShellExecutable,
      processArguments,
      runInShell: false,
    );
    final Future<void> stdoutForward = stdout.addStream(process.stdout);
    final Future<void> stderrForward = stderr.addStream(process.stderr);
    final int processExitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stdoutForward, stderrForward]);
    return processExitCode;
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

  String get _usageText {
    return '''
Runs the shared PowerShell module check for "$moduleName".

Usage:
  dart run tools/<module>_runtime_check.dart [options] [-- legacy script args]

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
