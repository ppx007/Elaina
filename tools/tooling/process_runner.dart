import 'dart:convert';
import 'dart:io';

import 'tool_exception.dart';

abstract interface class ToolProcessRunner {
  Future<ToolProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

final class SystemToolProcessRunner implements ToolProcessRunner {
  const SystemToolProcessRunner();

  @override
  Future<ToolProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final ProcessResult result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      // Windows resolves Flutter/Dart shims through .bat/.cmd files. Running
      // through the shell keeps the Dart CLI gate equivalent to a developer
      // typing the command in PowerShell, while non-Windows platforms keep the
      // stricter direct exec path.
      runInShell: Platform.isWindows,
    );
    return ToolProcessResult(
      executable: executable,
      arguments: arguments,
      exitCode: result.exitCode,
      stdoutText: _outputToString(result.stdout),
      stderrText: _outputToString(result.stderr),
    );
  }

  static String _outputToString(Object? output) {
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
}

final class RecordingToolProcessRunner implements ToolProcessRunner {
  RecordingToolProcessRunner(this._handler);

  final Future<ToolProcessResult> Function(
    String executable,
    List<String> arguments,
    String? workingDirectory,
  ) _handler;

  @override
  Future<ToolProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return _handler(executable, arguments, workingDirectory);
  }
}

final class ToolProcessResult {
  const ToolProcessResult({
    required this.executable,
    required this.arguments,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  final String executable;
  final List<String> arguments;
  final int exitCode;
  final String stdoutText;
  final String stderrText;

  String get displayCommand => <String>[executable, ...arguments].join(' ');
}

final class ToolCommandExecutor {
  const ToolCommandExecutor({
    required ToolProcessRunner processRunner,
    required this.projectRoot,
    required this.dryRun,
  }) : _processRunner = processRunner;

  final ToolProcessRunner _processRunner;
  final String projectRoot;
  final bool dryRun;

  Future<ToolProcessResult> run(
    String name,
    String executable,
    List<String> arguments,
  ) async {
    stdout.writeln('$name: $executable ${arguments.join(' ')}');
    if (dryRun) {
      return ToolProcessResult(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
        exitCode: ToolExitCodes.success,
        stdoutText: '',
        stderrText: '',
      );
    }

    final ToolProcessResult result = await _processRunner.run(
      executable,
      List<String>.unmodifiable(arguments),
      workingDirectory: projectRoot,
    );
    _write(stdout, result.stdoutText);
    _write(stderr, result.stderrText);
    if (result.exitCode != ToolExitCodes.success) {
      throw ToolException(
        "$name failed with exit code ${result.exitCode}: "
        '${result.displayCommand}',
      );
    }
    return result;
  }

  static void _write(IOSink sink, String text) {
    if (text.isEmpty) {
      return;
    }
    sink.write(text);
    if (!text.endsWith('\n')) {
      sink.writeln();
    }
  }
}
