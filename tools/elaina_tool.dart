import 'dart:io';

import 'package:args/command_runner.dart';

import 'tooling/changed_test_runner.dart';
import 'tooling/full_gate_runner.dart';
import 'tooling/module_check_runner.dart';
import 'tooling/process_runner.dart';
import 'tooling/tool_exception.dart';
import 'tooling/tool_paths.dart';
import 'tooling/windows_release_packager.dart';

Future<void> main(List<String> arguments) async {
  final CommandRunner<void> runner = CommandRunner<void>(
    'elaina_tool',
    'Elaina repository validation and packaging tool.',
  )
    ..addCommand(_CheckCommand())
    ..addCommand(_PackageCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(error.usage);
    exitCode = ToolExitCodes.usage;
  } on ToolException catch (error) {
    stderr.writeln(error.message);
    exitCode = ToolExitCodes.failure;
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = ToolExitCodes.failure;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = ToolExitCodes.failure;
  }
}

abstract base class _ElainaCommand extends Command<void> {
  _ElainaCommand() {
    argParser.addOption(
      _projectRootOption,
      help: 'Project root. Defaults to the current working directory.',
    );
  }

  static const String _projectRootOption = 'project-root';

  final ToolProcessRunner processRunner = const SystemToolProcessRunner();

  String get projectRoot {
    return ToolPaths.requireExistingProjectRoot(
        argResults?[_projectRootOption] as String?);
  }
}

final class _CheckCommand extends Command<void> {
  _CheckCommand() {
    addSubcommand(_CheckModuleCommand());
    addSubcommand(_CheckChangedCommand());
    addSubcommand(_CheckFullCommand());
  }

  @override
  String get name => 'check';

  @override
  String get description => 'Run validation checks.';
}

final class _CheckModuleCommand extends _ElainaCommand {
  _CheckModuleCommand() {
    argParser
      ..addOption(
        _moduleOption,
        mandatory: true,
        help: 'Module name from tools/module_checks.json.',
      )
      ..addFlag(
        _dryRunFlag,
        negatable: false,
        help: 'Print commands without executing external processes.',
      );
  }

  static const String _moduleOption = 'module';
  static const String _dryRunFlag = 'dry-run';

  @override
  String get name => 'module';

  @override
  String get description => 'Run one module check from the Dart registry.';

  @override
  Future<void> run() async {
    await ModuleCheckRunner(
      projectRoot: projectRoot,
      processRunner: processRunner,
      dryRun: argResults![_dryRunFlag] as bool,
    ).runModule(argResults![_moduleOption] as String);
  }
}

final class _CheckChangedCommand extends _ElainaCommand {
  _CheckChangedCommand() {
    argParser
      ..addOption(
        _scopeOption,
        defaultsTo: ChangedTestScope.fast.label,
        allowed: ChangedTestScope.values
            .map((ChangedTestScope scope) => scope.label)
            .toList(growable: false),
        help: 'Validation scope.',
      )
      ..addMultiOption(
        _changedPathOption,
        help:
            'Changed path override. Defaults to git diff and untracked files.',
      )
      ..addFlag(
        _dryRunFlag,
        negatable: false,
        help: 'Print commands without executing validation commands.',
      );
  }

  static const String _scopeOption = 'scope';
  static const String _changedPathOption = 'changed-path';
  static const String _dryRunFlag = 'dry-run';

  @override
  String get name => 'changed';

  @override
  String get description => 'Run the focused validation set for changed paths.';

  @override
  Future<void> run() async {
    await ChangedTestRunner(
      projectRoot: projectRoot,
      processRunner: processRunner,
      dryRun: argResults![_dryRunFlag] as bool,
    ).run(
      scope: ChangedTestScope.parse(argResults![_scopeOption] as String),
      changedPaths: argResults![_changedPathOption] as List<String>,
    );
  }
}

final class _CheckFullCommand extends _ElainaCommand {
  _CheckFullCommand() {
    argParser
      ..addOption(
        _libMpvPathOption,
        help: 'Path to libmpv-2.dll or a directory containing it.',
      )
      ..addOption(
        _sampleMediaPathOption,
        help: 'Media sample for the non-UI native playback smoke.',
      )
      ..addFlag(
        _requireNativeSmokeFlag,
        negatable: false,
        help: 'Fail if native smoke prerequisites are missing.',
      )
      ..addFlag(
        _skipNativePlayerSmokeFlag,
        negatable: false,
        help: 'Skip the non-UI playback smoke after packaging smoke.',
      )
      ..addFlag(
        _dryRunFlag,
        negatable: false,
        help: 'Print commands without executing validation commands.',
      );
  }

  static const String _libMpvPathOption = 'libmpv-path';
  static const String _sampleMediaPathOption = 'sample-media-path';
  static const String _requireNativeSmokeFlag = 'require-native-smoke';
  static const String _skipNativePlayerSmokeFlag = 'skip-native-player-smoke';
  static const String _dryRunFlag = 'dry-run';

  @override
  String get name => 'full';

  @override
  String get description => 'Run the release-readiness validation gate.';

  @override
  Future<void> run() async {
    await FullGateRunner(
      projectRoot: projectRoot,
      processRunner: processRunner,
      dryRun: argResults![_dryRunFlag] as bool,
    ).run(
      libMpvPath: argResults![_libMpvPathOption] as String?,
      sampleMediaPath: argResults![_sampleMediaPathOption] as String?,
      requireNativeSmoke: argResults![_requireNativeSmokeFlag] as bool,
      skipNativePlayerSmoke: argResults![_skipNativePlayerSmokeFlag] as bool,
    );
  }
}

final class _PackageCommand extends Command<void> {
  _PackageCommand() {
    addSubcommand(_PackageWindowsReleaseCommand());
  }

  @override
  String get name => 'package';

  @override
  String get description => 'Package release artifacts.';
}

final class _PackageWindowsReleaseCommand extends _ElainaCommand {
  _PackageWindowsReleaseCommand() {
    argParser
      ..addOption(
        _releaseDirOption,
        help: 'Windows Flutter release directory.',
      )
      ..addOption(
        _libMpvPathOption,
        help: 'Path to libmpv-2.dll or a directory containing it.',
      )
      ..addOption(
        _outputZipOption,
        help: 'Output zip path.',
      )
      ..addFlag(
        _skipZipFlag,
        negatable: false,
        help: 'Only stage libmpv beside the executable.',
      );
  }

  static const String _releaseDirOption = 'release-dir';
  static const String _libMpvPathOption = 'libmpv-path';
  static const String _outputZipOption = 'output-zip';
  static const String _skipZipFlag = 'skip-zip';

  @override
  String get name => 'windows-release';

  @override
  String get description => 'Stage libmpv and zip the Windows release.';

  @override
  Future<void> run() async {
    await WindowsReleasePackager(projectRoot: projectRoot).package(
      releaseDir: argResults![_releaseDirOption] as String?,
      libMpvPath: argResults![_libMpvPathOption] as String?,
      outputZip: argResults![_outputZipOption] as String?,
      skipZip: argResults![_skipZipFlag] as bool,
    );
  }
}
