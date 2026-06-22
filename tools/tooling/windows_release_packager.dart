import 'dart:io';

import 'package:archive/archive_io.dart';

import 'tool_exception.dart';
import 'tool_paths.dart';

/// Windows release staging and archive builder.
///
/// Packaging is kept in Dart so validation uses the same toolchain as the app.
/// The explicit libmpv staging check prevents a release zip that launches with
/// a blank/native-player failure on machines without the DLL in PATH.
final class WindowsReleasePackager {
  WindowsReleasePackager({required this.projectRoot});

  static const String libMpvFileName = 'libmpv-2.dll';
  static const String _libMpvEnvironmentVariable = 'CELESTERIA_LIBMPV_PATH';
  static const String _defaultReleaseDir = 'build/windows/x64/runner/Release';
  static const String _defaultOutputZip = 'build/dist/elaina-windows-x64.zip';
  static const String _defaultCachedLibMpvDirectory =
      '.cache/native/media-kit-libmpv/extracted';

  final String projectRoot;

  Future<WindowsReleasePackageResult> package({
    String? releaseDir,
    String? libMpvPath,
    String? outputZip,
    bool skipZip = false,
  }) async {
    final String resolvedReleaseDir = _fullPath(releaseDir ??
        ToolPaths.resolveProjectPath(projectRoot, _defaultReleaseDir));
    final String resolvedLibMpv = resolveLibMpvDll(libMpvPath);
    final String resolvedOutputZip = _fullPath(outputZip ??
        ToolPaths.resolveProjectPath(projectRoot, _defaultOutputZip));

    _assertReleaseDirectory(resolvedReleaseDir);
    final String targetLibMpv =
        ToolPaths.join(resolvedReleaseDir, libMpvFileName);
    await File(resolvedLibMpv).copy(targetLibMpv);
    if (!File(targetLibMpv).existsSync()) {
      throw ToolException(
        'Failed to stage $libMpvFileName beside the app executable: '
        '$targetLibMpv',
      );
    }

    if (skipZip) {
      stdout.writeln('Windows release staging passed: $resolvedReleaseDir');
      return WindowsReleasePackageResult(
        releaseDir: resolvedReleaseDir,
        libMpvPath: resolvedLibMpv,
        outputZip: null,
      );
    }

    final File zipFile = File(resolvedOutputZip);
    await zipFile.parent.create(recursive: true);
    if (zipFile.existsSync()) {
      await zipFile.delete();
    }

    final ZipFileEncoder encoder = ZipFileEncoder();
    await encoder.zipDirectory(
      Directory(resolvedReleaseDir),
      filename: resolvedOutputZip,
    );
    _assertZipContainsReleaseFiles(resolvedOutputZip);
    stdout.writeln('Windows release package created: $resolvedOutputZip');
    return WindowsReleasePackageResult(
      releaseDir: resolvedReleaseDir,
      libMpvPath: resolvedLibMpv,
      outputZip: resolvedOutputZip,
    );
  }

  String resolveLibMpvDll(String? candidate) {
    final List<String> candidates = <String>[
      if (candidate != null && candidate.trim().isNotEmpty) candidate,
      if ((Platform.environment[_libMpvEnvironmentVariable] ?? '')
          .trim()
          .isNotEmpty)
        Platform.environment[_libMpvEnvironmentVariable]!,
      ToolPaths.resolveProjectPath(projectRoot, _defaultCachedLibMpvDirectory),
    ];

    for (final String path in candidates) {
      final String fullPath = _fullPath(path);
      final File file = File(fullPath);
      if (file.existsSync()) {
        if (_baseName(fullPath) != libMpvFileName) {
          throw ToolException(
            'Libmpv path must point to $libMpvFileName, got: $fullPath',
          );
        }
        return fullPath;
      }
      final Directory directory = Directory(fullPath);
      if (directory.existsSync()) {
        final String dllPath = ToolPaths.join(fullPath, libMpvFileName);
        if (File(dllPath).existsSync()) {
          return dllPath;
        }
      }
    }

    throw ToolException(
      'Missing $libMpvFileName. Pass --libmpv-path or set '
      '$_libMpvEnvironmentVariable to a DLL or directory.',
    );
  }

  void _assertReleaseDirectory(String directoryPath) {
    final Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw ToolException(
          'Windows release directory does not exist: $directoryPath');
    }
    final bool hasExecutable = directory
        .listSync(followLinks: false)
        .whereType<File>()
        .any((File file) => file.path.toLowerCase().endsWith('.exe'));
    if (!hasExecutable) {
      throw ToolException(
        'Windows release directory must contain an application .exe: '
        '$directoryPath',
      );
    }
  }

  void _assertZipContainsReleaseFiles(String zipPath) {
    final List<int> bytes = File(zipPath).readAsBytesSync();
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    bool hasExe = false;
    bool hasLibMpv = false;
    for (final ArchiveFile file in archive.files) {
      final String name = file.name.replaceAll(r'\', '/');
      if (!name.contains('/') && name.toLowerCase().endsWith('.exe')) {
        hasExe = true;
      }
      if (name == libMpvFileName) {
        hasLibMpv = true;
      }
    }
    if (!hasExe) {
      throw ToolException(
          'Release zip is missing a root application .exe: $zipPath');
    }
    if (!hasLibMpv) {
      throw ToolException(
          'Release zip is missing root $libMpvFileName: $zipPath');
    }
  }

  static String _fullPath(String path) {
    return File(path).absolute.path;
  }

  static String _baseName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }
}

final class WindowsReleasePackageResult {
  const WindowsReleasePackageResult({
    required this.releaseDir,
    required this.libMpvPath,
    required this.outputZip,
  });

  final String releaseDir;
  final String libMpvPath;
  final String? outputZip;
}
