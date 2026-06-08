import "cache_invalidation/cache_invalidation_bus.dart";
import "gateway/provider_gateway.dart";
import "layers/layer_manifest.dart";
import "storage/storage_contracts.dart";

/// Phase 0 foundation runtime bootstrap.
///
/// Composes only Step 1-4 surfaces: layer manifest, [StorageFoundation],
/// [ProviderGateway], and [CacheInvalidationBus].  Does not import Flutter UI,
/// playback adapters, provider implementations, streaming engines, concrete
/// network clients, or platform services.
final class FoundationRuntime {
  FoundationRuntime({
    required StorageFoundation storage,
    required CacheInvalidationBus invalidationBus,
    ProviderGateway? gateway,
  })  : _storage = storage,
        _invalidationBus = invalidationBus,
        _gateway = gateway ??
            DeterministicProviderGateway(
              storage: storage,
            );

  final StorageFoundation _storage;
  final CacheInvalidationBus _invalidationBus;
  final ProviderGateway _gateway;
  bool _disposed = false;

  /// The layer manifest for the 8-layer Celesteria architecture.
  static const List<LayerBoundary> layerManifest = celesteriaLayerManifest;

  /// Storage foundation exposing all local store contracts.
  StorageFoundation get storage {
    _checkNotDisposed();
    return _storage;
  }

  /// Provider gateway for provider registration and request execution.
  ProviderGateway get gateway {
    _checkNotDisposed();
    return _gateway;
  }

  /// Cache invalidation bus for publishing and observing foundation events.
  CacheInvalidationBus get invalidationBus {
    _checkNotDisposed();
    return _invalidationBus;
  }

  /// Whether this runtime has been disposed.
  bool get isDisposed => _disposed;

  /// Disposes the runtime, closing owned lifecycle-managed components.
  ///
  /// After disposal, accessing [storage], [gateway], or [invalidationBus]
  /// throws a [StateError]. Publishing on the bus after disposal is rejected,
  /// and deterministic gateways owned by the runtime reject further operations.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final ProviderGateway gateway = _gateway;
    if (gateway is DeterministicProviderGateway) {
      gateway.close();
    }
    final CacheInvalidationBus bus = _invalidationBus;
    if (bus is StreamCacheInvalidationBus) {
      await bus.close();
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError("FoundationRuntime has been disposed.");
    }
  }
}

/// Deterministic [ProviderGateway] implementation for Phase 0 bootstrap.
///
/// Preserves provider registration, request keys, cache policy, typed failure
/// semantics, and de-duplication boundaries without owning concrete HTTP
/// transport.  Executes supplied loader functions directly and returns typed
/// results.
final class DeterministicProviderGateway implements ProviderGateway {
  DeterministicProviderGateway({
    required StorageFoundation storage,
  }) : _storage = storage;

  final StorageFoundation _storage;

  final Map<String, ProviderRegistration> _registrations =
      <String, ProviderRegistration>{};
  final Map<String, ProviderGatewayResponse<Object?>> _dedupeCache =
      <String, ProviderGatewayResponse<Object?>>{};
  bool _closed = false;

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) async {
    _checkNotClosed();
    _registrations[registration.providerId.value] = registration;
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) async {
    _checkNotClosed();

    final ProviderRegistration? registration =
        _registrations[request.key.providerId.value];
    if (registration == null) {
      return Future<ProviderGatewayResponse<T>>.error(
        ProviderFailure(
          kind: ProviderFailureKind.terminal,
          message:
              "Provider ${request.key.providerId.value} is not registered.",
        ),
      );
    }

    // Always check de-duplication cache for matching request keys.
    final String dedupeKey = _dedupeKey(request.key);
    final ProviderGatewayResponse<Object?>? cached = _dedupeCache[dedupeKey];
    if (cached != null) {
      return ProviderGatewayResponse<T>(
        value: cached.value as T,
        source: cached.source,
      );
    }

    try {
      final T value = await request.load();
      final ProviderGatewayResponse<T> response = ProviderGatewayResponse<T>(
        value: value,
        source: ProviderGatewayResponseSource.network,
      );

      // Always cache the outcome for de-duplication.
      _dedupeCache[dedupeKey] = ProviderGatewayResponse<Object?>(
        value: value,
        source: response.source,
      );

      return response;
    } on ProviderFailure {
      rethrow;
    } catch (e) {
      return Future<ProviderGatewayResponse<T>>.error(
        ProviderFailure(
          kind: ProviderFailureKind.retryable,
          message: "Loader failed: $e",
        ),
      );
    }
  }

  void close() {
    _closed = true;
    _registrations.clear();
    _dedupeCache.clear();
  }

  void _checkNotClosed() {
    if (_closed) {
      throw StateError(
          "DeterministicProviderGateway has been closed.");
    }
  }

  static String _dedupeKey(ProviderRequestKey key) =>
      "${key.providerId.value}::${key.cacheKey}";
}

