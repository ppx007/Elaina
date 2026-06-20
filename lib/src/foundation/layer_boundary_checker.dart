import 'layers/layer_manifest.dart';

/// Deterministic layer-boundary metadata for Phase 0 foundation bootstrap.
///
/// Identifies forbidden imports from Flutter UI, playback adapters, provider
/// implementations, streaming engines, concrete network clients, and platform
/// services.  Used by checker scripts and tests to enforce 8-layer isolation.
final class LayerBoundaryChecker {
  const LayerBoundaryChecker();

  /// Terms that are forbidden in foundation-layer code.
  ///
  /// These represent concrete UI, playback, BT, platform, or network adapter
  /// dependencies that must not appear in the foundation bootstrap slice.
  static const Set<String> foundationForbiddenTerms = <String>{
    // Flutter UI
    'package:flutter',
    'MaterialApp',
    'Scaffold',
    'StatelessWidget',
    'StatefulWidget',
    // Playback adapters
    'mpv',
    'libmpv',
    'vlc',
    'MediaPlayer',
    // Provider implementations
    'bangumi',
    'dandanplay',
    'yuc.wiki',
    // BT / streaming
    'libtorrent',
    'DownloadEngineAdapter',
    'bt_task_core',
    // Concrete network/platform
    'HttpClient(',
    'DnsClient',
    'DoHClient',
    'DoTClient',
    'ProxyServer',
    'VpnService',
    'TunInterface',
    'PacketCapture',
    'DpiEngine',
    // Online rule execution
    'runJavascript',
    'dart:mirrors',
    'eval(',
    'Function.apply',
    'WebViewController',
    'captchaSolver',
    'headless',
    'Crawler',
    'Scraper',
    // Remote telemetry
    'remoteTelemetry',
    'CrashReporter',
    'AnalyticsClient',
    'cloudUpload',
    'supportBundleUpload',
    // Database/platform specifics
    'sqlite',
    'SQLite',
    'drift',
    'moor',
    'hive',
    'path_provider',
    'shared_preferences',
  };

  /// Terms that must be present in the foundation runtime bootstrap.
  static const Set<String> foundationRequiredTerms = <String>{
    'FoundationRuntime',
    'StorageFoundation',
    'ProviderGateway',
    'CacheInvalidationBus',
    'LayerBoundary',
    'elainaLayerManifest',
  };

  /// Checks that [content] does not contain any forbidden foundation terms.
  ///
  /// Returns a list of forbidden terms found.  Empty list means clean.
  static List<String> findForbiddenTerms(String content) {
    final List<String> found = <String>[];
    for (final String term in foundationForbiddenTerms) {
      if (content.contains(term)) {
        found.add(term);
      }
    }
    return found;
  }

  /// Checks that [content] contains all required foundation terms.
  ///
  /// Returns a list of missing terms.  Empty list means complete.
  static List<String> findMissingRequiredTerms(String content) {
    final List<String> missing = <String>[];
    for (final String term in foundationRequiredTerms) {
      if (!content.contains(term)) {
        missing.add(term);
      }
    }
    return missing;
  }

  /// Validates that the 8-layer manifest is consistent.
  ///
  /// Returns a list of validation errors.  Empty list means valid.
  static List<String> validateManifest() {
    final List<String> errors = <String>[];
    final Set<LayerId> declaredIds =
        elainaLayerManifest.map((LayerBoundary b) => b.id).toSet();

    for (final LayerBoundary boundary in elainaLayerManifest) {
      for (final LayerId dep in boundary.allowedDependencies) {
        if (!declaredIds.contains(dep)) {
          errors.add(
            'Layer ${boundary.id.name} depends on undeclared layer ${dep.name}.',
          );
        }
      }
    }
    return errors;
  }
}
