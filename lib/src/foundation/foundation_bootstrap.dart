import "cache_invalidation/cache_invalidation_bus.dart";
import "deterministic_storage_foundation.dart";
import "foundation_runtime.dart";
import "gateway/provider_gateway.dart";
import "layer_boundary_checker.dart";
import "layers/layer_manifest.dart";
import "storage/storage_contracts.dart";

// ---------------------------------------------------------------------------
// Foundation Bootstrap Composition (Phase 0, Step 1-4)
// ---------------------------------------------------------------------------
// This module provides the single entry-point for composing the Phase 0
// foundation runtime from existing contract surfaces:
//
//   1. Layer manifest (layer_manifest.dart)
//   2. Layer boundary checker (layer_boundary_checker.dart)
//   3. StorageFoundation (deterministic_storage_foundation.dart)
//   4. ProviderGateway (foundation_runtime.dart)
//   5. CacheInvalidationBus (cache_invalidation_bus.dart)
//
// This module MUST NOT import Flutter UI, playback adapters, provider
// implementations, streaming engines, concrete network/platform adapters.

/// Forbidden import terms for foundation bootstrap files.
/// Re-exports from [LayerBoundaryChecker.foundationForbiddenTerms].
const Set<String> foundationBootstrapForbiddenDependencies =
    LayerBoundaryChecker.foundationForbiddenTerms;

/// Allowed export surface for the foundation bootstrap barrel.
const Set<String> foundationBootstrapAllowedExports = <String>{
  "foundation_bootstrap",
  "foundation_runtime",
  "deterministic_storage_foundation",
  "layer_boundary_checker",
  "cache_invalidation_bus",
  "provider_gateway",
  "storage_contracts",
  "layer_manifest",
  "extension_points",
  "diagnostics_center",
  "advanced_caption_storage_contracts",
  "av_sync_guard_storage_contracts",
  "bt_task_storage_contracts",
  "diagnostics_storage_contracts",
  "fallback_adapter_storage_contracts",
  "network_policy_storage_contracts",
  "online_rule_runtime_storage_contracts",
  "piece_priority_scheduler_storage_contracts",
  "rss_auto_download_policy_storage_contracts",
  "seasonal_storage_contracts",
  "timeline_overlay_storage_contracts",
  "video_enhancement_storage_contracts",
  "virtual_stream_storage_contracts",
  "webview_session_backfill_storage_contracts",
};

/// Phase 0 foundation bootstrap that composes Step 1-4 surfaces.
///
/// Constructing an instance gives you:
/// - [storage]: deterministic local stores (24 stores)
/// - [gateway]: deterministic provider gateway (registration, de-dup, typed failures)
/// - [invalidationBus]: lifecycle-managed cache invalidation bus
/// - [layerManifest]: 8-layer boundary metadata
/// - [layerBoundaryChecker]: forbidden/required term validation
///
/// After use, call [dispose] to close the invalidation bus and reject
/// further operations.
final class FoundationBootstrap {
  /// Creates a foundation bootstrap with default deterministic implementations.
  FoundationBootstrap()
      : _storage = DeterministicStorageFoundation(),
        _bus = StreamCacheInvalidationBus() {
    _runtime = FoundationRuntime(
      storage: _storage,
      invalidationBus: _bus,
    );
  }

  /// Creates a foundation bootstrap with explicit dependencies.
  FoundationBootstrap.withDependencies({
    required StorageFoundation storage,
    required CacheInvalidationBus invalidationBus,
    ProviderGateway? gateway,
  })  : _storage = storage,
        _bus = invalidationBus {
    _runtime = FoundationRuntime(
      storage: storage,
      invalidationBus: invalidationBus,
      gateway: gateway,
    );
  }

  final StorageFoundation _storage;
  final CacheInvalidationBus _bus;
  late final FoundationRuntime _runtime;

  /// The 8-layer manifest for boundary validation.
  static const List<LayerBoundary> layerManifest = elainaLayerManifest;

  /// Forbidden import terms for foundation bootstrap.
  static const Set<String> forbiddenDependencies =
      LayerBoundaryChecker.foundationForbiddenTerms;

  /// Required terms for foundation bootstrap validation.
  static const Set<String> requiredTerms =
      LayerBoundaryChecker.foundationRequiredTerms;

  /// The storage foundation providing all local deterministic stores.
  StorageFoundation get storage => _runtime.storage;

  /// The provider gateway for provider request governance.
  ProviderGateway get gateway => _runtime.gateway;

  /// The lifecycle-managed cache invalidation bus.
  CacheInvalidationBus get invalidationBus => _runtime.invalidationBus;

  /// Whether this bootstrap has been disposed.
  bool get isDisposed => _runtime.isDisposed;

  /// Disposes the bootstrap, closing the invalidation bus and
  /// rejecting further operations.
  Future<void> dispose() => _runtime.dispose();

  /// Validates that [content] does not contain any forbidden foundation terms.
  static List<String> findForbiddenTerms(String content) =>
      LayerBoundaryChecker.findForbiddenTerms(content);

  /// Validates that [content] contains all required foundation terms.
  static List<String> findMissingRequiredTerms(String content) =>
      LayerBoundaryChecker.findMissingRequiredTerms(content);

  /// Validates that the 8-layer manifest is internally consistent.
  static List<String> validateManifest() =>
      LayerBoundaryChecker.validateManifest();
}
