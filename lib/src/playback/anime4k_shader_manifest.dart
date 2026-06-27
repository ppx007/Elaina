import 'dart:io';
import 'dart:typed_data';

import 'video_enhancement_pipeline.dart';

typedef Anime4kShaderAssetLoader = Future<ByteData> Function(String assetPath);

const String anime4kShaderSourceBundled = 'bundled';
const String anime4kShaderSourceOverride = 'override';
const String anime4kShaderSourceUnavailable = 'unavailable';
const String anime4kAssetDirectory = 'assets/anime4k';
const String anime4kRestoreShaderFileName = 'Anime4K_Restore_CNN_M.glsl';
const String anime4kUpscaleShaderFileName = 'Anime4K_Upscale_CNN_x2_M.glsl';
const String anime4kLicenseFileName = 'LICENSE';
const String anime4kBundledCacheDirectoryName = 'elaina-anime4k-shaders';
const String anime4kOverrideIncompleteReason =
    'Custom Anime4K shader directory is incomplete; using bundled shaders.';

const Map<Anime4kPresetIntent, List<String>> anime4kPresetShaderFiles =
    <Anime4kPresetIntent, List<String>>{
  Anime4kPresetIntent.restore: <String>[anime4kRestoreShaderFileName],
  Anime4kPresetIntent.upscale: <String>[anime4kUpscaleShaderFileName],
  Anime4kPresetIntent.restoreAndUpscale: <String>[
    anime4kRestoreShaderFileName,
    anime4kUpscaleShaderFileName,
  ],
};

final class Anime4kShaderManifest {
  Anime4kShaderManifest({
    required this.source,
    required Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset,
    this.reason,
    Map<String, String> details = const <String, String>{},
  })  : shaderChainsByPreset =
            _freezeChainsByPreset(shaderChainsByPreset),
        details = Map<String, String>.unmodifiable(details);

  const Anime4kShaderManifest.unavailable(this.reason)
      : source = anime4kShaderSourceUnavailable,
        shaderChainsByPreset =
            const <Anime4kPresetIntent, List<Uri>>{},
        details = const <String, String>{};

  final String source;
  final Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset;
  final String? reason;
  final Map<String, String> details;

  bool get isAvailable => shaderChainsByPreset.isNotEmpty;
}

final class Anime4kShaderManifestResolver {
  const Anime4kShaderManifestResolver({
    required Anime4kShaderAssetLoader assetLoader,
    Directory? bundledDirectory,
  })  : _assetLoader = assetLoader,
        _bundledDirectory = bundledDirectory;

  final Anime4kShaderAssetLoader _assetLoader;
  final Directory? _bundledDirectory;

  Future<Anime4kShaderManifest> resolve({
    String? overrideDirectoryPath,
  }) async {
    final Directory? overrideDirectory =
        _overrideDirectoryFromPath(overrideDirectoryPath);
    if (overrideDirectory != null) {
      final Map<Anime4kPresetIntent, List<Uri>> overrideChains =
          _chainsFromDirectory(overrideDirectory);
      if (_allShaderFilesExist(overrideChains)) {
        return Anime4kShaderManifest(
          source: anime4kShaderSourceOverride,
          shaderChainsByPreset: overrideChains,
          details: <String, String>{
            'overrideDirectory': overrideDirectory.path,
          },
        );
      }
    }

    try {
      final Directory bundledDirectory =
          await _ensureBundledShadersAreFiles();
      final Map<Anime4kPresetIntent, List<Uri>> bundledChains =
          _chainsFromDirectory(bundledDirectory);
      if (!_allShaderFilesExist(bundledChains)) {
        return const Anime4kShaderManifest.unavailable(
          'Bundled Anime4K shaders could not be materialized.',
        );
      }
      return Anime4kShaderManifest(
        source: anime4kShaderSourceBundled,
        shaderChainsByPreset: bundledChains,
        reason: overrideDirectory == null ? null : anime4kOverrideIncompleteReason,
        details: <String, String>{
          'bundledDirectory': bundledDirectory.path,
          if (overrideDirectory != null)
            'fallbackFromOverrideDirectory': overrideDirectory.path,
        },
      );
    } on Object catch (error) {
      return Anime4kShaderManifest.unavailable(
        'Bundled Anime4K shaders are unavailable: $error',
      );
    }
  }

  Directory? _overrideDirectoryFromPath(String? rawPath) {
    final String path = rawPath?.trim() ?? '';
    if (path.isEmpty) return null;
    final Directory directory = Directory(path);
    if (!directory.existsSync()) return directory;
    return directory;
  }

  Future<Directory> _ensureBundledShadersAreFiles() async {
    final Directory directory = _bundledDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          '$anime4kBundledCacheDirectoryName',
        );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    for (final String fileName in _bundledAssetFileNames) {
      await _copyAssetToFile(
        assetPath: '$anime4kAssetDirectory/$fileName',
        target: File(_joinPath(directory.path, fileName)),
      );
    }
    return directory;
  }

  Future<void> _copyAssetToFile({
    required String assetPath,
    required File target,
  }) async {
    final ByteData data = await _assetLoader(assetPath);
    final Uint8List bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await target.writeAsBytes(bytes, flush: true);
  }
}

const List<String> _bundledAssetFileNames = <String>[
  anime4kRestoreShaderFileName,
  anime4kUpscaleShaderFileName,
  anime4kLicenseFileName,
];

Map<Anime4kPresetIntent, List<Uri>> _chainsFromDirectory(Directory directory) {
  return <Anime4kPresetIntent, List<Uri>>{
    for (final MapEntry<Anime4kPresetIntent, List<String>> entry
        in anime4kPresetShaderFiles.entries)
      entry.key: <Uri>[
        for (final String fileName in entry.value)
          File(_joinPath(directory.path, fileName)).uri,
      ],
  };
}

bool _allShaderFilesExist(Map<Anime4kPresetIntent, List<Uri>> chains) {
  if (chains.isEmpty) return false;
  for (final Uri shader in chains.values.expand((List<Uri> chain) => chain)) {
    if (!shader.isScheme('file')) return false;
    if (!File(shader.toFilePath()).existsSync()) return false;
  }
  return true;
}

Map<Anime4kPresetIntent, List<Uri>> _freezeChainsByPreset(
  Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset,
) {
  return Map<Anime4kPresetIntent, List<Uri>>.unmodifiable(
    <Anime4kPresetIntent, List<Uri>>{
      for (final MapEntry<Anime4kPresetIntent, List<Uri>> entry
          in shaderChainsByPreset.entries)
        entry.key: List<Uri>.unmodifiable(entry.value),
    },
  );
}

String _joinPath(String directory, String fileName) {
  if (directory.endsWith('/') || directory.endsWith('\\')) {
    return '$directory$fileName';
  }
  return '$directory${Platform.pathSeparator}$fileName';
}
