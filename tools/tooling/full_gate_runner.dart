import 'dart:io';

import 'module_check_runner.dart';
import 'process_runner.dart';
import 'tool_exception.dart';
import 'tool_paths.dart';
import 'windows_release_packager.dart';

final class FullGateRunner {
  FullGateRunner({
    required this.projectRoot,
    required ToolProcessRunner processRunner,
    this.dryRun = false,
  })  : _processRunner = processRunner,
        _executor = ToolCommandExecutor(
          processRunner: processRunner,
          projectRoot: projectRoot,
          dryRun: dryRun,
        );

  static const String _openspecExecutable = 'openspec.cmd';
  static const String _dartExecutable = 'dart';
  static const String _flutterExecutable = 'flutter';
  static const String _ffmpegExecutable = 'ffmpeg';
  static const String _analyzeSubcommand = 'analyze';
  static const String _testSubcommand = 'test';
  static const String _libMpvSmokeScript =
      'tools/media_kit_mpv_binding_smoke.dart';
  static const String _sampleFilter = 'testsrc=size=160x90:rate=10';
  static const String _sampleDurationSeconds = '1';

  static const List<String> _releaseGateModules = <String>[
    'player_core',
    'acg_data_experience',
    'library_smoke_gate',
    'advanced_playback_core',
    'automation_extension_core',
    'bt_streaming_smoke_gate',
    'diagnostics_center_runtime',
  ];

  final String projectRoot;
  final bool dryRun;
  final ToolProcessRunner _processRunner;
  final ToolCommandExecutor _executor;

  Future<void> run({
    String? libMpvPath,
    String? sampleMediaPath,
    bool requireNativeSmoke = false,
    bool skipNativePlayerSmoke = false,
  }) async {
    await _executor.run(
      'openspec validate --all',
      _openspecExecutable,
      const <String>['validate', '--all'],
    );
    await _executor.run(
      'dart analyze',
      _dartExecutable,
      const <String>[_analyzeSubcommand],
    );
    await _executor.run(
      'flutter analyze',
      _flutterExecutable,
      const <String>[_analyzeSubcommand],
    );
    await _executor.run(
      'flutter test',
      _flutterExecutable,
      const <String>[_testSubcommand],
    );
    await ModuleCheckRunner(
      projectRoot: projectRoot,
      processRunner: _processRunner,
      dryRun: dryRun,
    ).runModules(_releaseGateModules);
    await runPlayerSmokeGate(
      libMpvPath: libMpvPath,
      sampleMediaPath: sampleMediaPath,
      requireNativeSmoke: requireNativeSmoke,
      skipNativeSmoke: skipNativePlayerSmoke,
    );
    stdout.writeln('Full feature gate checks passed.');
  }

  Future<void> runPlayerSmokeGate({
    String? libMpvPath,
    String? sampleMediaPath,
    bool requireNativeSmoke = false,
    bool skipNativeSmoke = false,
  }) async {
    final Directory tempRoot = await Directory.systemTemp.createTemp(
      'elaina-player-smoke-',
    );
    try {
      final WindowsReleasePackager packager =
          WindowsReleasePackager(projectRoot: projectRoot);
      final String resolvedLibMpv;
      try {
        resolvedLibMpv = packager.resolveLibMpvDll(libMpvPath);
      } on ToolException {
        if (requireNativeSmoke) {
          rethrow;
        }
        stdout.writeln(
          'Player smoke gate skipped native checks: missing '
          '${WindowsReleasePackager.libMpvFileName}.',
        );
        return;
      }

      final String releaseDir = ToolPaths.join(tempRoot.path, 'release');
      final String distDir = ToolPaths.join(tempRoot.path, 'dist');
      await Directory(releaseDir).create(recursive: true);
      await Directory(distDir).create(recursive: true);
      await File(ToolPaths.join(releaseDir, 'Elaina.exe'))
          .writeAsString('temporary smoke executable');

      final String zipPath = ToolPaths.join(distDir, 'elaina-player-smoke.zip');
      if (!dryRun) {
        await packager.package(
          releaseDir: releaseDir,
          libMpvPath: resolvedLibMpv,
          outputZip: zipPath,
        );
      } else {
        stdout.writeln('player smoke package: $releaseDir -> $zipPath');
      }
      if (!dryRun && !File(zipPath).existsSync()) {
        throw ToolException(
          'Windows release package smoke did not create zip: $zipPath',
        );
      }

      if (skipNativeSmoke) {
        stdout.writeln('Player smoke gate skipped non-UI playback smoke.');
        stdout.writeln('Player smoke gate passed release packaging smoke.');
        return;
      }

      final String? resolvedSamplePath = await _resolveSampleMedia(
        sampleMediaPath: sampleMediaPath,
        tempRoot: tempRoot,
        requireNativeSmoke: requireNativeSmoke,
      );
      if (resolvedSamplePath == null) {
        return;
      }
      await _executor.run(
        'non-UI media_kit/libmpv playback smoke',
        _dartExecutable,
        <String>[
          'run',
          _libMpvSmokeScript,
          '--libmpv',
          resolvedLibMpv,
          resolvedSamplePath,
        ],
      );
      stdout.writeln(
        'Player smoke gate passed release packaging and non-UI playback smoke.',
      );
    } finally {
      ToolPaths.assertInsideTemp(tempRoot.path);
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<String?> _resolveSampleMedia({
    required String? sampleMediaPath,
    required Directory tempRoot,
    required bool requireNativeSmoke,
  }) async {
    if (sampleMediaPath != null && sampleMediaPath.trim().isNotEmpty) {
      final File sample = File(sampleMediaPath).absolute;
      if (!sample.existsSync()) {
        throw ToolException('Sample media file does not exist: ${sample.path}');
      }
      return sample.path;
    }

    final String generatedSamplePath =
        ToolPaths.join(tempRoot.path, 'sample.mp4');
    if (dryRun) {
      return generatedSamplePath;
    }
    final ToolProcessResult ffmpeg;
    try {
      ffmpeg = await _processRunner.run(
        _ffmpegExecutable,
        <String>[
          '-hide_banner',
          '-loglevel',
          'error',
          '-y',
          '-f',
          'lavfi',
          '-i',
          _sampleFilter,
          '-t',
          _sampleDurationSeconds,
          '-pix_fmt',
          'yuv420p',
          generatedSamplePath,
        ],
        workingDirectory: projectRoot,
      );
    } on ProcessException {
      if (requireNativeSmoke) {
        throw const ToolException(
          'Missing sample media and ffmpeg is unavailable to generate one.',
        );
      }
      stdout.writeln(
        'Player smoke gate skipped non-UI playback smoke: missing sample '
        'media and ffmpeg.',
      );
      stdout.writeln('Player smoke gate passed release packaging smoke.');
      return null;
    }
    if (ffmpeg.exitCode != ToolExitCodes.success ||
        !File(generatedSamplePath).existsSync()) {
      if (requireNativeSmoke) {
        throw const ToolException(
          'Missing sample media and ffmpeg is unavailable to generate one.',
        );
      }
      stdout.writeln(
        'Player smoke gate skipped non-UI playback smoke: missing sample '
        'media and ffmpeg.',
      );
      stdout.writeln('Player smoke gate passed release packaging smoke.');
      return null;
    }
    return generatedSamplePath;
  }
}
