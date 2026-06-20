@TestOn('vm')
library;

import 'dart:io';

import 'package:celesteria/src/foundation/layers/layer_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the real `lib/src` import graph and enforces the layer manifest.
///
/// Unlike the substring-based [LayerBoundaryChecker], this test parses every
/// Dart file's relative imports, resolves the source and target [LayerId], and
/// asserts each cross-layer edge against [isLayerDependencyAllowed].  This is
/// the check that would have caught the historical `network -> gateway` edge.
///
/// `foundation/` is the cross-cutting base (it has no [LayerId] member), so
/// imports into it are always allowed and imports originating there are not
/// constrained by the manifest.
void main() {
  // Directory name under lib/src -> LayerId.  `gateway` and `storage` live
  // physically under foundation/ but are their own manifest layers.
  const Map<String, LayerId> layerByDir = <String, LayerId>{
    'ui': LayerId.ui,
    'domain': LayerId.domain,
    'playback': LayerId.playback,
    'provider': LayerId.provider,
    'streaming': LayerId.streaming,
    'network': LayerId.network,
  };

  test('lib/src import graph honors the layer dependency manifest', () {
    final Directory libSrc = Directory('lib/src');
    expect(libSrc.existsSync(), isTrue, reason: 'lib/src must exist');

    final List<String> violations = <String>[];
    final RegExp relativeImport =
        RegExp(r'''import\s+['"](\.\./[^'"]+)['"]''');

    for (final FileSystemEntity entity
        in libSrc.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final LayerId? fromLayer = _layerForPath(entity.path, layerByDir);
      if (fromLayer == null) {
        continue; // foundation/ or unclassified: not a manifest source layer.
      }
      final String content = entity.readAsStringSync();
      for (final RegExpMatch match in relativeImport.allMatches(content)) {
        final String target = match.group(1)!;
        final LayerId? toLayer = _layerForImport(target, layerByDir);
        if (toLayer == null || toLayer == fromLayer) {
          continue; // foundation import or same-layer: always allowed.
        }
        if (!isLayerDependencyAllowed(from: fromLayer, to: toLayer)) {
          violations.add(
            '${entity.path}: ${fromLayer.name} -> ${toLayer.name} ($target)',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Forbidden cross-layer imports:\n${violations.join('\n')}',
    );
  });
}

LayerId? _layerForPath(String path, Map<String, LayerId> layerByDir) {
  final String normalized = path.replaceAll(r'\', '/');
  final int idx = normalized.indexOf('lib/src/');
  if (idx < 0) {
    return null;
  }
  final List<String> segments =
      normalized.substring(idx + 'lib/src/'.length).split('/');
  if (segments.isEmpty) {
    return null;
  }
  return layerByDir[segments.first];
}

LayerId? _layerForImport(String importPath, Map<String, LayerId> layerByDir) {
  // Relative imports look like ../network/foo.dart or ../foundation/bar.dart.
  for (final MapEntry<String, LayerId> entry in layerByDir.entries) {
    if (importPath.contains('/${entry.key}/')) {
      return entry.value;
    }
  }
  return null;
}
