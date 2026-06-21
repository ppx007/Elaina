import 'dart:io';

import 'runtime_check_proxy.dart';

const int _usageErrorExitCode = 64;

Future<void> main(List<String> arguments) async {
  final _RuntimeCheckCliOptions options;
  try {
    options = _RuntimeCheckCliOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('Run with --help to see supported runtime check options.');
    exitCode = _usageErrorExitCode;
    return;
  }
  if (options.showHelp) {
    stdout.writeln(_usageText);
    return;
  }
  if (options.moduleName == null) {
    stderr.writeln('Missing required --module option.');
    stderr.writeln('Run with --help to see supported runtime check options.');
    exitCode = _usageErrorExitCode;
    return;
  }
  await runModuleRuntimeCheck(options.moduleName!, options.forwardedArguments);
}

final class _RuntimeCheckCliOptions {
  const _RuntimeCheckCliOptions({
    required this.showHelp,
    required this.forwardedArguments,
    this.moduleName,
  });

  final bool showHelp;
  final String? moduleName;
  final List<String> forwardedArguments;

  static _RuntimeCheckCliOptions parse(List<String> arguments) {
    bool showHelp = false;
    String? moduleName;
    final List<String> forwardedArguments = <String>[];

    for (int index = 0; index < arguments.length; index += 1) {
      final String argument = arguments[index];
      if (argument == '--') {
        forwardedArguments.addAll(arguments.skip(index));
        break;
      }
      switch (argument) {
        case '-h':
        case '--help':
          showHelp = true;
          break;
        case '--module':
          final int valueIndex = index + 1;
          if (valueIndex >= arguments.length) {
            throw const FormatException('Missing value for --module.');
          }
          moduleName = arguments[valueIndex];
          index += 1;
          break;
        default:
          if (argument.startsWith('--module=')) {
            moduleName = argument.substring('--module='.length);
          } else {
            forwardedArguments.add(argument);
          }
      }
    }

    return _RuntimeCheckCliOptions(
      showHelp: showHelp,
      moduleName: moduleName,
      forwardedArguments: List<String>.unmodifiable(forwardedArguments),
    );
  }
}

const String _usageText = '''
Runs a shared runtime check module.

Usage:
  dart run tools/runtime_check.dart --module <name> [options] [-- legacy args]

Options:
  -h, --help          Show this help text.
      --module <name> Runtime check module name.

All other options are forwarded to BaseRuntimeCheck.''';
