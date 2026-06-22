import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../playback/playback_source_handoff.dart';
import 'media_library.dart';

// Runtime boundary for local media-library workflows.
//
// UI pages ask this runtime to scan, import, match Bangumi subjects, and prepare
// playback. That keeps folder preferences and widgets from constructing
// playback sources or provider bindings directly.
const int bangumiLocalMediaSearchCandidateLimit = 6;
const int bangumiLocalMediaMatchQueryMinLength = 2;
const int bangumiLocalMediaMatchQueryMaxLength = 80;
const double bangumiLocalMediaExactTitleConfidence = 1.0;
const double bangumiLocalMediaPartialTitleConfidence = 0.6;
const double bangumiLocalMediaUserConfirmedConfidence = 1.0;

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
  ignored,
  scanFailed,
  importFailed,
  catalogFailed,
  historyFailed,
  bindingFailed,
  matchFailed,
  playbackHandoffFailed,
}

final class MediaLibraryRuntimeFailure {
  const MediaLibraryRuntimeFailure({required this.kind, required this.message})
      : assert(message != '',
            'Media library runtime failure message must not be empty.');

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
  const MediaLibraryActionResult._(
      {required this.kind, this.value, this.failure});

  const MediaLibraryActionResult.success([T? value])
      : this._(kind: MediaLibraryActionResultKind.success, value: value);

  MediaLibraryActionResult.unavailable(String message)
      : this._(
          kind: MediaLibraryActionResultKind.unavailable,
          failure: MediaLibraryRuntimeFailure(
              kind: MediaLibraryRuntimeFailureKind.unavailable,
              message: message),
        );

  MediaLibraryActionResult.unsupported(String message)
      : this._(
          kind: MediaLibraryActionResultKind.unsupported,
          failure: MediaLibraryRuntimeFailure(
              kind: MediaLibraryRuntimeFailureKind.unsupported,
              message: message),
        );

  MediaLibraryActionResult.ignored(String message)
      : this._(
          kind: MediaLibraryActionResultKind.ignored,
          failure: MediaLibraryRuntimeFailure(
              kind: MediaLibraryRuntimeFailureKind.ignored, message: message),
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
    Iterable<MediaLibraryCatalogItemState> catalogItems =
        const <MediaLibraryCatalogItemState>[],
    Iterable<ContinueWatchingState> continueWatching =
        const <ContinueWatchingState>[],
    Iterable<MediaScanEvent> scanEvents = const <MediaScanEvent>[],
    Iterable<MediaLibraryRuntimeFailure> failures =
        const <MediaLibraryRuntimeFailure>[],
  })  : catalogItems =
            List<MediaLibraryCatalogItemState>.unmodifiable(catalogItems),
        continueWatching =
            List<ContinueWatchingState>.unmodifiable(continueWatching),
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

typedef LocalMediaMatchQueryNormalizer = String Function(String basename);

final class LocalMediaBangumiMatchCandidate {
  const LocalMediaBangumiMatchCandidate({
    required this.subjectId,
    required this.title,
    required this.confidence,
  }) : assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final ProviderSubjectId subjectId;
  final String title;
  final double confidence;
}

final class LocalMediaBangumiMatchResult {
  LocalMediaBangumiMatchResult({
    required this.mediaId,
    required this.query,
    Iterable<LocalMediaBangumiMatchCandidate> candidates =
        const <LocalMediaBangumiMatchCandidate>[],
  }) : candidates =
            List<LocalMediaBangumiMatchCandidate>.unmodifiable(candidates);

  final LocalMediaId mediaId;
  final String query;
  final List<LocalMediaBangumiMatchCandidate> candidates;
}

abstract interface class LocalMediaBangumiMatcher {
  Future<AcgProviderResult<LocalMediaBangumiMatchResult>> search(
      MediaLibraryItem item);
}

final class BangumiLocalMediaMatcher implements LocalMediaBangumiMatcher {
  BangumiLocalMediaMatcher({
    required BangumiProvider bangumiProvider,
    LocalMediaMatchQueryNormalizer? queryNormalizer,
    this.candidateLimit = bangumiLocalMediaSearchCandidateLimit,
  })  : assert(candidateLimit > 0, 'candidateLimit must be positive.'),
        _bangumiProvider = bangumiProvider,
        _queryNormalizer =
            queryNormalizer ?? defaultBangumiLocalMediaMatchQuery;

  final BangumiProvider _bangumiProvider;
  final LocalMediaMatchQueryNormalizer _queryNormalizer;
  final int candidateLimit;

  @override
  Future<AcgProviderResult<LocalMediaBangumiMatchResult>> search(
      MediaLibraryItem item) async {
    final String query = _queryNormalizer(item.identity.basename);
    if (query.isEmpty) {
      return AcgProviderSuccess<LocalMediaBangumiMatchResult>(
        LocalMediaBangumiMatchResult(
          mediaId: item.identity.id,
          query: query,
        ),
      );
    }

    final AcgProviderResult<List<BangumiSubject>> result =
        await _bangumiProvider.searchSubjects(query);
    return switch (result) {
      AcgProviderFailure<List<BangumiSubject>>(:final kind, :final message) =>
        AcgProviderFailure<LocalMediaBangumiMatchResult>(
          kind: kind,
          message: message,
        ),
      AcgProviderSuccess<List<BangumiSubject>>(:final value) =>
        AcgProviderSuccess<LocalMediaBangumiMatchResult>(
          LocalMediaBangumiMatchResult(
            mediaId: item.identity.id,
            query: query,
            // Confidence is intentionally simple and explainable. The user must
            // confirm a binding before it becomes authoritative.
            candidates: <LocalMediaBangumiMatchCandidate>[
              for (final BangumiSubject subject in value.take(candidateLimit))
                LocalMediaBangumiMatchCandidate(
                  subjectId: ProviderSubjectId(subject.id.value),
                  title: subject.title,
                  confidence: _confidenceFor(query, subject.title),
                ),
            ],
          ),
        ),
    };
  }

  static double _confidenceFor(String query, String title) {
    return query.trim().toLowerCase() == title.trim().toLowerCase()
        ? bangumiLocalMediaExactTitleConfidence
        : bangumiLocalMediaPartialTitleConfidence;
  }
}

String defaultBangumiLocalMediaMatchQuery(String basename) {
  final String stem = _basenameStem(basename);
  final String withoutBracketedSegments =
      stem.replaceAll(_bracketedMediaTokenPattern, ' ');
  final String withoutQualityTokens = withoutBracketedSegments
      .replaceAll(_mediaQualityTokenPattern, ' ')
      .replaceAll(_mediaSeparatorPattern, ' ');
  final String withoutTrailingEpisode = _compactWhitespace(withoutQualityTokens)
      .replaceAll(_trailingEpisodeTokenPattern, ' ');
  final String normalized = _compactWhitespace(withoutTrailingEpisode);
  if (normalized.length >= bangumiLocalMediaMatchQueryMinLength) {
    return _boundedBangumiMatchQuery(normalized);
  }
  return _boundedBangumiMatchQuery(_compactWhitespace(stem));
}

final RegExp _bracketedMediaTokenPattern =
    RegExp(r'[\[\(【（][^\]\)】）]*[\]\)】）]');
final RegExp _mediaQualityTokenPattern = RegExp(
  r'\b(?:480p|720p|1080p|2160p|4k|8k|x264|x265|h264|h265|hevc|avc|aac|flac|web-dl|bdrip|bluray|chs|cht|jpn|gb|big5)\b',
  caseSensitive: false,
);
final RegExp _mediaSeparatorPattern = RegExp(r'[._]+');
final RegExp _pathSeparatorPattern = RegExp(r'[/\\]');
final RegExp _trailingEpisodeTokenPattern = RegExp(
  r'(?:[-_\s]+(?:s\d{1,2}e\d{1,3}|e\d{1,3}|ep?\.?\s*\d{1,3}|第\s*\d{1,3}\s*(?:话|集)|\d{1,3}))+$',
  caseSensitive: false,
);
final RegExp _whitespacePattern = RegExp(r'\s+');

String _basenameStem(String basename) {
  final int separator = basename.lastIndexOf(_pathSeparatorPattern);
  final String name =
      separator >= 0 ? basename.substring(separator + 1) : basename;
  final int dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

String _compactWhitespace(String value) {
  return value.replaceAll(_whitespacePattern, ' ').trim();
}

String _boundedBangumiMatchQuery(String query) {
  if (query.length <= bangumiLocalMediaMatchQueryMaxLength) return query;
  return query.substring(0, bangumiLocalMediaMatchQueryMaxLength).trim();
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
    LocalMediaBangumiMatcher? bangumiMatcher,
    DateTime Function()? now,
  })  : _scanner = scanner,
        _catalogRepository = catalogRepository,
        _importer = importer,
        _historyStore = historyStore,
        _bindingStore = bindingStore,
        _playbackSourceHandoff = playbackSourceHandoff,
        _invalidationBus = invalidationBus,
        _bangumiMatcher = bangumiMatcher,
        _now = now ?? DateTime.now;

  final MediaLibraryScanner _scanner;
  final MediaLibraryCatalogRepository _catalogRepository;
  final MediaBatchImportContract _importer;
  final PlaybackHistoryStore _historyStore;
  final ProviderBindingStore _bindingStore;
  final PlaybackSourceHandoffContract _playbackSourceHandoff;
  final CacheInvalidationBus _invalidationBus;
  final LocalMediaBangumiMatcher? _bangumiMatcher;
  final DateTime Function() _now;
  final List<MediaLibraryRuntimeObserver> _observers =
      <MediaLibraryRuntimeObserver>[];
  MediaLibraryRuntimeSnapshot _snapshot =
      const MediaLibraryRuntimeSnapshot.idle();
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

  Future<MediaLibraryActionResult<MediaScanResult>> scan(
      MediaScanScope scope) async {
    if (_disposed) return _disposedResult();
    _publish(MediaLibraryRuntimeSnapshot(
        status: MediaLibraryRuntimeStatus.scanning,
        catalogItems: _snapshot.catalogItems,
        continueWatching: _snapshot.continueWatching));
    final MediaScanResult result = await _scanner.scan(scope);
    final List<MediaScanEvent> events =
        await _scanner.watch(result.scanId).toList();
    final List<MediaLibraryRuntimeFailure> failures =
        <MediaLibraryRuntimeFailure>[
      for (final MediaScanFailure failure in result.failures)
        MediaLibraryRuntimeFailure(
            kind: MediaLibraryRuntimeFailureKind.scanFailed,
            message: failure.message),
    ];
    _publish(MediaLibraryRuntimeSnapshot(
      status: failures.isEmpty
          ? MediaLibraryRuntimeStatus.ready
          : MediaLibraryRuntimeStatus.failed,
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

  Future<MediaLibraryActionResult<List<MediaScanEvent>>> watchScan(
      MediaScanId scanId) async {
    if (_disposed) return _disposedResult();
    return MediaLibraryActionResult<List<MediaScanEvent>>.success(
        await _scanner.watch(scanId).toList());
  }

  Future<MediaLibraryActionResult<MediaImportResult>> importCandidates(
      Iterable<MediaScanCandidate> candidates) async {
    if (_disposed) return _disposedResult();
    _publish(MediaLibraryRuntimeSnapshot(
        status: MediaLibraryRuntimeStatus.importing,
        catalogItems: _snapshot.catalogItems,
        continueWatching: _snapshot.continueWatching));
    final MediaImportResult result = await _importer.importBatch(candidates);
    for (final MediaLibraryItem item in result.imported) {
      _publishItemChanged(item, MediaLibraryChangeKind.created);
    }
    await refresh();
    return MediaLibraryActionResult<MediaImportResult>.success(result);
  }

  Future<MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>> refresh(
      {MediaLibraryQuery query = const MediaLibraryQuery(),
      int continueWatchingLimit = 20}) async {
    if (_disposed) return _disposedResult();
    final List<MediaLibraryItem> items =
        await _catalogRepository.list(query: query);
    final List<ContinueWatchingState> continueWatching =
        await _historyStore.continueWatching(limit: continueWatchingLimit);
    final Map<String, ContinueWatchingState> continueByMediaId =
        <String, ContinueWatchingState>{
      for (final ContinueWatchingState state in continueWatching)
        state.mediaId.value: state,
    };
    final List<MediaLibraryCatalogItemState> projected =
        <MediaLibraryCatalogItemState>[];
    for (final MediaLibraryItem item in items) {
      projected.add(MediaLibraryCatalogItemState(
        item: item,
        continueWatching: continueByMediaId[item.identity.id.value],
        binding:
            await _bindingStore.bindingFor(item.identity.id) ?? item.binding,
      ));
    }
    final MediaLibraryRuntimeSnapshot snapshot = MediaLibraryRuntimeSnapshot(
        status: MediaLibraryRuntimeStatus.ready,
        catalogItems: projected,
        continueWatching: continueWatching);
    _publish(snapshot);
    return MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>.success(
        snapshot);
  }

  Future<MediaLibraryActionResult<MediaLibraryItem>> detail(
      MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? item = await _catalogRepository.findById(id);
    if (item == null)
      return MediaLibraryActionResult<MediaLibraryItem>.unavailable(
          'Media library item was not found.');
    return MediaLibraryActionResult<MediaLibraryItem>.success(item);
  }

  Future<MediaLibraryActionResult<MediaLibraryItem>> update(
      MediaLibraryItem item) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem updated = await _catalogRepository.update(item);
    _publishItemChanged(updated, MediaLibraryChangeKind.updated);
    await refresh();
    return MediaLibraryActionResult<MediaLibraryItem>.success(updated);
  }

  Future<MediaLibraryActionResult<bool>> remove(MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? existing = await _catalogRepository.findById(id);
    if (existing == null)
      return MediaLibraryActionResult<bool>.ignored(
          'Media library item was already absent.');
    final bool removed = await _catalogRepository.remove(id);
    if (!removed)
      return MediaLibraryActionResult<bool>.ignored(
          'Media library item was already absent.');
    _publishItemChanged(existing, MediaLibraryChangeKind.removed);
    await refresh();
    return const MediaLibraryActionResult<bool>.success(true);
  }

  Future<MediaLibraryActionResult<int>> count() async {
    if (_disposed) return _disposedResult();
    return MediaLibraryActionResult<int>.success(
        await _catalogRepository.count());
  }

  Future<MediaLibraryActionResult<void>> recordHistory(
      PlaybackHistoryEntry entry) async {
    if (_disposed) return _disposedResult();
    await _historyStore.record(entry);
    _invalidationBus.publish(HistoryRecorded(
        occurredAt: entry.updatedAt, localMediaId: entry.mediaId.value));
    await refresh();
    return const MediaLibraryActionResult<void>.success();
  }

  Future<MediaLibraryActionResult<ProviderBinding>> saveUserBinding(
      ProviderBinding binding) async {
    if (_disposed) return _disposedResult();
    final ProviderBinding saved =
        await _bindingStore.saveUserConfirmed(binding);
    _publishBindingChanged(saved);
    await refresh();
    return MediaLibraryActionResult<ProviderBinding>.success(saved);
  }

  Future<MediaLibraryActionResult<ProviderBinding>> saveAutomaticBinding(
      ProviderBinding binding) async {
    if (_disposed) return _disposedResult();
    final ProviderBinding saved =
        await _bindingStore.saveAutomaticIfAllowed(binding);
    if (saved.id.value == binding.id.value) _publishBindingChanged(saved);
    await refresh();
    return MediaLibraryActionResult<ProviderBinding>.success(saved);
  }

  Future<MediaLibraryActionResult<LocalMediaBangumiMatchResult>>
      searchBangumiMatches(LocalMediaId mediaId) async {
    if (_disposed) return _disposedResult();
    final LocalMediaBangumiMatcher? matcher = _bangumiMatcher;
    if (matcher == null) {
      return MediaLibraryActionResult<LocalMediaBangumiMatchResult>.unavailable(
          'Bangumi media matching is unavailable.');
    }
    final MediaLibraryItem? item =
        await _catalogRepository.findByLocalMediaId(mediaId);
    if (item == null) {
      return MediaLibraryActionResult<LocalMediaBangumiMatchResult>.ignored(
          'Media item was not found.');
    }
    final AcgProviderResult<LocalMediaBangumiMatchResult> result =
        await matcher.search(item);
    return switch (result) {
      AcgProviderSuccess<LocalMediaBangumiMatchResult>(:final value) =>
        MediaLibraryActionResult<LocalMediaBangumiMatchResult>.success(value),
      AcgProviderFailure<LocalMediaBangumiMatchResult>(
        :final kind,
        :final message
      ) =>
        MediaLibraryActionResult<LocalMediaBangumiMatchResult>.failed(
          _matchFailure(kind, message),
        ),
    };
  }

  Future<MediaLibraryActionResult<ProviderBinding>> confirmBangumiMatch({
    required LocalMediaId mediaId,
    required LocalMediaBangumiMatchCandidate candidate,
  }) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? item =
        await _catalogRepository.findByLocalMediaId(mediaId);
    if (item == null) {
      return MediaLibraryActionResult<ProviderBinding>.ignored(
          'Media item was not found.');
    }
    return saveUserBinding(
      ProviderBinding(
        id: ProviderBindingId(
          '${mediaId.value}:$bangumiProviderBindingProviderId:'
          '${candidate.subjectId.value}',
        ),
        localMediaId: mediaId,
        providerId: bangumiProviderBindingProviderId,
        subjectId: candidate.subjectId,
        authority: ProviderBindingAuthority.userConfirmed,
        confidence: bangumiLocalMediaUserConfirmedConfidence,
        createdAt: _now(),
      ),
    );
  }

  Future<MediaLibraryActionResult<PlaybackSourceHandoffResult>> playItem(
      MediaLibraryItemId id) async {
    if (_disposed) return _disposedResult();
    final MediaLibraryItem? item = await _catalogRepository.findById(id);
    if (item == null)
      return MediaLibraryActionResult<PlaybackSourceHandoffResult>.unavailable(
          'Media library item was not found.');
    return _prepare(
        PlaybackSourceHandoffInput.localMediaIdentity(item.identity));
  }

  MediaLibraryActionResult<PlaybackSourceHandoffResult> playCandidate(
      MediaScanCandidate candidate) {
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
        MediaLibraryRuntimeFailure(
            kind: MediaLibraryRuntimeFailureKind.disposed,
            message: 'MediaLibraryRuntime has been disposed.'),
      ],
    ));
    _observers.clear();
  }

  MediaLibraryActionResult<PlaybackSourceHandoffResult> _prepare(
      PlaybackSourceHandoffInput input) {
    final PlaybackSourceHandoffResult result =
        _playbackSourceHandoff.prepare(input);
    if (!result.isSuccess) {
      final PlaybackSourceHandoffFailure? failure = result.failure;
      final MediaLibraryActionResultKind kind =
          failure?.kind == PlaybackSourceHandoffFailureKind.missingSourceData
              ? MediaLibraryActionResultKind.unavailable
              : MediaLibraryActionResultKind.unsupported;
      return MediaLibraryActionResult<PlaybackSourceHandoffResult>._(
        kind: kind,
        failure: MediaLibraryRuntimeFailure(
          kind: kind == MediaLibraryActionResultKind.unavailable
              ? MediaLibraryRuntimeFailureKind.unavailable
              : MediaLibraryRuntimeFailureKind.playbackHandoffFailed,
          message: failure?.message ?? 'Playback source handoff failed.',
        ),
      );
    }
    return MediaLibraryActionResult<PlaybackSourceHandoffResult>.success(
        result);
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
    for (final MediaLibraryRuntimeObserver observer
        in List<MediaLibraryRuntimeObserver>.of(_observers)) {
      observer.onMediaLibraryRuntimeSnapshot(snapshot);
    }
  }

  MediaLibraryActionResult<T> _disposedResult<T>() {
    return MediaLibraryActionResult<T>.failed(
      const MediaLibraryRuntimeFailure(
          kind: MediaLibraryRuntimeFailureKind.disposed,
          message: 'MediaLibraryRuntime has been disposed.'),
    );
  }

  MediaLibraryRuntimeFailure _matchFailure(
      AcgProviderFailureKind kind, String message) {
    final MediaLibraryRuntimeFailureKind mediaKind =
        kind == AcgProviderFailureKind.unavailable
            ? MediaLibraryRuntimeFailureKind.unavailable
            : MediaLibraryRuntimeFailureKind.matchFailed;
    return MediaLibraryRuntimeFailure(kind: mediaKind, message: message);
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
    LocalMediaBangumiMatcher? bangumiMatcher,
    DateTime Function()? now,
  }) : runtime = MediaLibraryRuntime(
          scanner: scanner,
          catalogRepository: catalogRepository,
          importer: importer,
          historyStore: historyStore,
          bindingStore: bindingStore,
          playbackSourceHandoff: playbackSourceHandoff,
          invalidationBus: invalidationBus,
          bangumiMatcher: bangumiMatcher,
          now: now,
        );

  final MediaLibraryRuntime runtime;

  Future<MediaLibraryActionResult<MediaScanResult>> scan(
          MediaScanScope scope) =>
      runtime.scan(scope);

  Future<MediaLibraryActionResult<MediaImportResult>> importCandidates(
          Iterable<MediaScanCandidate> candidates) =>
      runtime.importCandidates(candidates);

  Future<MediaLibraryActionResult<MediaLibraryRuntimeSnapshot>> refresh(
      {MediaLibraryQuery query = const MediaLibraryQuery(),
      int continueWatchingLimit = 20}) {
    return runtime.refresh(
        query: query, continueWatchingLimit: continueWatchingLimit);
  }

  void dispose() => runtime.dispose();
}
