import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../playback/playback_source_handoff.dart';
import 'media_library.dart';

enum MediaLibraryRuntimeStatus {
  idle,
  scanning,
  importing,
  ready,
  failed,
  disposed,
}

enum MediaLibraryRuntimeFailureKind {
  disposed,
  unavailable,
  unsupported,
  scanFailed,
  importFailed,
  catalogFailed,
  historyFailed,
  bindingFailed,
  playbackHandoffFailed,
}

final class MediaLibraryRuntimeFailure {
  const MediaLibraryRuntimeFailure({required this.kind, required this.message})
      : assert(message != '', 'Media library runtime failure message must not be empty.');

  final MediaLibraryRuntimeFailureKind kind;
  final String message;
}

enum MediaLibraryActionResultKind {
  success,
  unavailable,
  unsupported,
  ignored,
  failed,
}

final class MediaLibraryActionResult<T> {
  const MediaLibraryActionResult._({required this.kind, this.value, this.failure});

  const MediaLibraryActionResult.success([T? value]) : this._(kind: MediaLibraryActionResultKind.success, value: value);

  MediaLibraryActionResult.unavailable(String message)
      : this._(
          kind: MediaLibraryActionResultKind.unavailable,
          failure: MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.unavailable, message: message),
        );

  MediaLibraryActionResult.unsupported(String message)
      : this._(
          kind: MediaLibraryActionResultKind.unsupported,
          failure: MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.unsupported, message: message),
        );

  MediaLibraryActionResult.ignored(String message)
      : this._(
          kind: MediaLibraryActionResultKind.ignored,
          failure: MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.unavailable, message: message),
        );

  const MediaLibraryActionResult.failed(MediaLibraryRuntimeFailure failure)
      : this._(kind: MediaLibraryActionResultKind.failed, failure: failure);

  final MediaLibraryActionResultKind kind;
  final T? value;
  final MediaLibraryRuntimeFailure? failure;

  bool get isSuccess => kind == MediaLibraryActionResultKind.success;
}

final class MediaLibraryCatalogItemState {
  const MediaLibraryCatalogItemState({
    required this.item,
    this.continueWatching,
    this.binding,
  });

  final MediaLibraryItem item;
  final ContinueWatchingState? continueWatching;
  final ProviderBinding? binding;
}

final class MediaLibraryRuntimeSnapshot {
  MediaLibraryRuntimeSnapshot({
    required this.status,
    Iterable<MediaLibraryCatalogItemState> catalogItems = const <MediaLibraryCatalogItemState>[],
    Iterable<ContinueWatchingState> continueWatching = const <ContinueWatchingState>[],
    Iterable<MediaScanEvent> scanEvents = const <MediaScanEvent>[],
    Iterable<MediaLibraryRuntimeFailure> failures = const <MediaLibraryRuntimeFailure>[],
  })  : catalogItems = List<MediaLibraryCatalogItemState>.unmodifiable(catalogItems),
        continueWatching = List<ContinueWatchingState>.unmodifiable(continueWatching),
        scanEvents = List<MediaScanEvent>.unmodifiable(scanEvents),
        failures = List<MediaLibraryRuntimeFailure>.unmodifiable(failures);

  const MediaLibraryRuntimeSnapshot.idle()
      : status = MediaLibraryRuntimeStatus.idle,
        catalogItems = const <MediaLibraryCatalogItemState>[],
        continueWatching = const <ContinueWatchingState>[],
        scanEvents = const <MediaScanEvent>[],
        failures = const <MediaLibraryRuntimeFailure>[];

  final MediaLibraryRuntimeStatus status;
  final List<MediaLibraryCatalogItemState> catalogItems;
  final List<ContinueWatchingState> continueWatching;
  final List<MediaScanEvent> scanEvents;
  final List<MediaLibraryRuntimeFailure> failures;
}

abstract interface class MediaLibraryRuntimeObserver {
  void onMediaLibraryRuntimeSnapshot(MediaLibraryRuntimeSnapshot snapshot);
}

final class MediaLibraryRuntime {
  MediaLibraryRuntime({
    required MediaLibraryScanner scanner,
    required MediaLibraryCatalogRepository catalogRepository,
    required MediaBatchImportContract importer,
    required PlaybackHistoryStore historyStore,
    required ProviderBindingStore bindingStore,
    required PlaybackSourceHandoffContract playbackSourceHandoff,
    required CacheInvalidationBus invalidationBus,
    DateTime Function()? now,
  })  : _scanner = scanner,
        _catalogRepository = catalogRepository,
        _importer = importer,
        _historyStore = historyStore,
        _bindingStore = bindingStore,
        _playbackSourceHandoff = playbackSourceHandoff,
        _invalidationBus = invalidationBus,
        _now = now ?? DateTime.now;

  final MediaLibraryScanner _scanner;
  final MediaLibraryCatalogRepository _catalogRepository;
  final MediaBatchImportContract _importer;
  final PlaybackHistoryStore _historyStore;
  final ProviderBindingStore _bindingStore;
  final PlaybackSourceHandoffContract _playbackSourceHandoff;
  final CacheInvalidationBus _invalidationBus;
  final DateTime Function() _now;
  final List<MediaLibraryRuntimeObserver> _observers = <MediaLibraryRuntimeObserver>[];
  MediaLibraryRuntimeSnapshot _snapshot = const MediaLibraryRuntimeSnapshot.idle();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  MediaLibraryRuntimeSnapshot get currentSnapshot => _snapshot;

  void addObserver(MediaLibraryRuntimeObserver observer) {
    if (_disposed) throw StateError('MediaLibraryRuntime has been disposed.');
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(MediaLibraryRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<MediaLibraryActionResult<MediaScanResult>> scan(MediaScanScope scope) async {
    if (_disposed) return _disposedResult();
    _publish(MediaLibraryRuntimeSnapshot(status: MediaLibraryRuntimeStatus.scanning, catalogItems: _snapshot.catalogItems, continueWatching: _snapshot.continueWatching));
    final MediaScanResult result = await _scanner.scan(scope);
    final List<MediaScanEvent> events = await _scanner.watch(result.scanId).toList();
    final List<MediaLibraryRuntimeFailure> failures = <MediaLibraryRuntimeFailure>[
      for (final MediaScanFailure failure in result.failures)
        MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.scanFailed, message: failure.message),
    ];
    _publish(MediaLibraryRuntimeSnapshot(
      status: failures.isEmpty ? MediaLibraryRuntimeStatus.ready : MediaLibraryRuntimeStatus.failed,
      catalogItems: _snapshot.catalogItems,
      continueWatching: _snapshot.continueWatching,
      scanEvents: events,
      failures: failures,
    ));
    return MediaLibraryActionResult<MediaScanResult>.success(result);
  }

  Future<MediaLibraryActionResult<void>> cancelScan(MediaScanId scanId) async {
    if (_disposed) return _disposedResult();
    await _scanner.cancel(scanId);
    return const MediaLibraryActionResult<void>.success();
  }

  Future<MediaLibraryActionResult<List<MediaScanEvent>>> watchScan(MediaScanId scanId) async {
    if (_disposed) return _disposedResult();
    return MediaLibraryActionResult<List<MediaScanEvent>>.success(await _scanner.watch(scanId).toList());
  }

  Future<MediaLibraryActionResult<MediaImportResult>> importCandidates(Iterable<MediaScanCandidate> candidates) async {
    if (_disposed) return _disposedResult();
    _publish(MediaLibraryRuntimeSnapshot(status: MediaLibraryRuntimeStatus.importing, catalogItems: _snapshot.catalogItems, continueWatching: _snapshot.continueWatching));
    final MediaImportResult result = await _importer.importBatch(candidates);
    for (final MediaLibraryItem item in result.imported) {
      _publishItemChanged(item, MediaLibraryChangeKind.created);
    }
    await refresh();
    return MediaLibraryActionResult<MediaImportResult>.success(result);
  }

  Future<MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>> refresh({MediaLibraryQuery query = const MediaLibraryQuery(), int continueWatchingLimit = 20}) async {
    if (_disposed) return _disposedResult();
    final List<MediaLibraryItem> items = await _catalogRepository.list(query: query);
    final List<ContinueWatchingState> continueWatching = await _historyStore.continueWatching(limit: continueWatchingLimit);
    final Map<String, ContinueWatchingState> continueByMediaId = <String, ContinueWatchingState>{
      for (final ContinueWatchingState state in continueWatching) state.mediaId.value: state,
    };
    final List<MediaLibraryCatalogItemState> projected = <MediaLibraryCatalogItemState>[];
    for (final MediaLibraryItem item in items) {
      projected.add(MediaLibraryCatalogItemState(
        item: item,
        continueWatching: continueByMediaId[item.identity.id.value],
        binding: await _bindingStore.bindingFor(item.identity.id) ?? item.binding,
      ));
    }
    final MediaLibraryRuntimeSnapshot snapshot = MediaLibraryRuntimeSnapshot(status: MediaLibraryRuntimeStatus.ready, catalogItems: projected, continueWatching: continueWatching);
    _publish(snapshot);
    return MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>.success(snapshot);
  }

  Future<MediaLibraryActionResult<MediaLibraryItem>> detail(MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? item = await _catalogRepository.findById(id);
    if (item == null) return MediaLibraryActionResult<MediaLibraryItem>.unavailable('Media library item was not found.');
    return MediaLibraryActionResult<MediaLibraryItem>.success(item);
  }

  Future<MediaLibraryActionResult<MediaLibraryItem>> update(MediaLibraryItem item) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem updated = await _catalogRepository.update(item);
    _publishItemChanged(updated, MediaLibraryChangeKind.updated);
    await refresh();
    return MediaLibraryActionResult<MediaLibraryItem>.success(updated);
  }

  Future<MediaLibraryActionResult<bool>> remove(MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? existing = await _catalogRepository.findById(id);
    if (existing == null) return MediaLibraryActionResult<bool>.ignored('Media library item was already absent.');
    final bool removed = await _catalogRepository.remove(id);
    if (!removed) return MediaLibraryActionResult<bool>.ignored('Media library item was already absent.');
    _publishItemChanged(existing, MediaLibraryChangeKind.removed);
    await refresh();
    return const MediaLibraryActionResult<bool>.success(true);
  }

  Future<MediaLibraryActionResult<int>> count() async {
    if (_disposed) return _disposedResult();
    return MediaLibraryActionResult<int>.success(await _catalogRepository.count());
  }

  Future<MediaLibraryActionResult<void>> recordHistory(PlaybackHistoryEntry entry) async {
    if (_disposed) return _disposedResult();
    await _historyStore.record(entry);
    _invalidationBus.publish(HistoryRecorded(occurredAt: entry.updatedAt, localMediaId: entry.mediaId.value));
    await refresh();
    return const MediaLibraryActionResult<void>.success();
  }

  Future<MediaLibraryActionResult<ProviderBinding>> saveUserBinding(ProviderBinding binding) async {
    if (_disposed) return _disposedResult();
    final ProviderBinding saved = await _bindingStore.saveUserConfirmed(binding);
    _publishBindingChanged(saved);
    await refresh();
    return MediaLibraryActionResult<ProviderBinding>.success(saved);
  }

  Future<MediaLibraryActionResult<ProviderBinding>> saveAutomaticBinding(ProviderBinding binding) async {
    if (_disposed) return _disposedResult();
    final ProviderBinding saved = await _bindingStore.saveAutomaticIfAllowed(binding);
    if (saved.id.value == binding.id.value) _publishBindingChanged(saved);
    await refresh();
    return MediaLibraryActionResult<ProviderBinding>.success(saved);
  }

  Future<MediaLibraryActionResult<PlaybackSourceHandoffResult>> playItem(MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? item = await _catalogRepository.findById(id);
    if (item == null) return MediaLibraryActionResult<PlaybackSourceHandoffResult>.unavailable('Media library item was not found.');
    return _prepare(PlaybackSourceHandoffInput.localMediaIdentity(item.identity));
  }

  MediaLibraryActionResult<PlaybackSourceHandoffResult> playCandidate(MediaScanCandidate candidate) {
    if (_disposed) return _disposedResult();
    return _prepare(PlaybackSourceHandoffInput.mediaScanCandidate(candidate));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(MediaLibraryRuntimeSnapshot(
      status: MediaLibraryRuntimeStatus.disposed,
      catalogItems: _snapshot.catalogItems,
      continueWatching: _snapshot.continueWatching,
      scanEvents: _snapshot.scanEvents,
      failures: const <MediaLibraryRuntimeFailure>[
        MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.disposed, message: 'MediaLibraryRuntime has been disposed.'),
      ],
    ));
    _observers.clear();
  }

  MediaLibraryActionResult<PlaybackSourceHandoffResult> _prepare(PlaybackSourceHandoffInput input) {
    final PlaybackSourceHandoffResult result = _playbackSourceHandoff.prepare(input);
    if (!result.isSuccess) {
      final PlaybackSourceHandoffFailure? failure = result.failure;
      final MediaLibraryActionResultKind kind = failure?.kind == PlaybackSourceHandoffFailureKind.missingSourceData
          ? MediaLibraryActionResultKind.unavailable
          : MediaLibraryActionResultKind.unsupported;
      return MediaLibraryActionResult<PlaybackSourceHandoffResult>._(
        kind: kind,
        failure: MediaLibraryRuntimeFailure(
          kind: kind == MediaLibraryActionResultKind.unavailable ? MediaLibraryRuntimeFailureKind.unavailable : MediaLibraryRuntimeFailureKind.playbackHandoffFailed,
          message: failure?.message ?? 'Playback source handoff failed.',
        ),
      );
    }
    return MediaLibraryActionResult<PlaybackSourceHandoffResult>.success(result);
  }

  void _publishItemChanged(MediaLibraryItem item, MediaLibraryChangeKind kind) {
    _invalidationBus.publish(MediaLibraryItemChanged(
      occurredAt: _now(),
      mediaLibraryItemId: item.id.value,
      localMediaId: item.identity.id.value,
      changeKind: kind,
    ));
  }

  void _publishBindingChanged(ProviderBinding binding) {
    _invalidationBus.publish(BindingChanged(
      occurredAt: binding.createdAt,
      localMediaId: binding.localMediaId.value,
      providerId: binding.providerId,
      providerSubjectId: binding.subjectId?.value,
    ));
  }

  void _publish(MediaLibraryRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    for (final MediaLibraryRuntimeObserver observer in List<MediaLibraryRuntimeObserver>.of(_observers)) {
      observer.onMediaLibraryRuntimeSnapshot(snapshot);
    }
  }

  MediaLibraryActionResult<T> _disposedResult<T>() {
    return MediaLibraryActionResult<T>.failed(
      const MediaLibraryRuntimeFailure(kind: MediaLibraryRuntimeFailureKind.disposed, message: 'MediaLibraryRuntime has been disposed.'),
    );
  }
}

final class MediaLibraryBootstrap {
  MediaLibraryBootstrap({
    required MediaLibraryScanner scanner,
    required MediaLibraryCatalogRepository catalogRepository,
    required MediaBatchImportContract importer,
    required PlaybackHistoryStore historyStore,
    required ProviderBindingStore bindingStore,
    required PlaybackSourceHandoffContract playbackSourceHandoff,
    required CacheInvalidationBus invalidationBus,
    DateTime Function()? now,
  }) : runtime = MediaLibraryRuntime(
          scanner: scanner,
          catalogRepository: catalogRepository,
          importer: importer,
          historyStore: historyStore,
          bindingStore: bindingStore,
          playbackSourceHandoff: playbackSourceHandoff,
          invalidationBus: invalidationBus,
          now: now,
        );

  final MediaLibraryRuntime runtime;

  Future<MediaLibraryActionResult<MediaScanResult>> scan(MediaScanScope scope) => runtime.scan(scope);

  Future<MediaLibraryActionResult<MediaImportResult>> importCandidates(Iterable<MediaScanCandidate> candidates) => runtime.importCandidates(candidates);

  Future<MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>> refresh({MediaLibraryQuery query = const MediaLibraryQuery(), int continueWatchingLimit = 20}) {
    return runtime.refresh(query: query, continueWatchingLimit: continueWatchingLimit);
  }

  void dispose() => runtime.dispose();
}
