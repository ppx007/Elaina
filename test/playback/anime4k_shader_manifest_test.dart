import 'dart:io';
import 'dart:typed_data';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolver materializes bundled Anime4K shaders as file URI chains',
      () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('elaina-anime4k-bundled-test');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final Anime4kShaderManifest manifest =
        await Anime4kShaderManifestResolver(
      assetLoader: _fakeAssetLoader,
      bundledDirectory: directory,
    ).resolve();

    expect(manifest.source, anime4kShaderSourceBundled);
    expect(manifest.isAvailable, isTrue);
    expect(
      manifest.shaderChainsByPreset[Anime4kPresetIntent.restoreAndUpscale],
      hasLength(2),
    );
    for (final Uri shader in manifest.shaderChainsByPreset.values
        .expand((List<Uri> chain) => chain)) {
      expect(shader.isScheme('file'), isTrue);
      expect(File(shader.toFilePath()).existsSync(), isTrue);
    }
    expect(File('${directory.path}${Platform.pathSeparator}LICENSE').existsSync(),
        isTrue);
  });

  test('resolver prefers complete override directory without loading assets',
      () async {
    final Directory override =
        await Directory.systemTemp.createTemp('elaina-anime4k-override-test');
    addTearDown(() async {
      if (await override.exists()) await override.delete(recursive: true);
    });
    await File('${override.path}${Platform.pathSeparator}'
            '$anime4kRestoreShaderFileName')
        .writeAsString('// restore');
    await File('${override.path}${Platform.pathSeparator}'
            '$anime4kUpscaleShaderFileName')
        .writeAsString('// upscale');

    final Anime4kShaderManifest manifest =
        await Anime4kShaderManifestResolver(
      assetLoader: (_) => throw StateError('bundled asset should not load'),
    ).resolve(overrideDirectoryPath: override.path);

    expect(manifest.source, anime4kShaderSourceOverride);
    expect(manifest.reason, isNull);
    expect(
      manifest.shaderChainsByPreset[Anime4kPresetIntent.restore]!.single
          .toFilePath(),
      contains(anime4kRestoreShaderFileName),
    );
  });

  test('resolver falls back to bundled shaders when override is incomplete',
      () async {
    final Directory override =
        await Directory.systemTemp.createTemp('elaina-anime4k-bad-override');
    final Directory bundled =
        await Directory.systemTemp.createTemp('elaina-anime4k-fallback');
    addTearDown(() async {
      if (await override.exists()) await override.delete(recursive: true);
      if (await bundled.exists()) await bundled.delete(recursive: true);
    });
    await File('${override.path}${Platform.pathSeparator}'
            '$anime4kRestoreShaderFileName')
        .writeAsString('// restore only');

    final Anime4kShaderManifest manifest =
        await Anime4kShaderManifestResolver(
      assetLoader: _fakeAssetLoader,
      bundledDirectory: bundled,
    ).resolve(overrideDirectoryPath: override.path);

    expect(manifest.source, anime4kShaderSourceBundled);
    expect(manifest.reason, anime4kOverrideIncompleteReason);
    expect(manifest.isAvailable, isTrue);
  });
}

Future<ByteData> _fakeAssetLoader(String assetPath) async {
  final Uint8List bytes = Uint8List.fromList('// $assetPath'.codeUnits);
  return ByteData.sublistView(bytes);
}
