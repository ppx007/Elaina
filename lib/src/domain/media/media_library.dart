import '../../foundation/baseline_defaults.dart';

final class LocalMediaId {
  const LocalMediaId(this.value)
      : assert(value != '', 'Local media id must not be empty.');

  final String value;
}

final class MediaScanId {
  const MediaScanId(this.value)
      : assert(value != '', 'Media scan id must not be empty.');

  final String value;
}

final class MediaLibraryItemId {
  const MediaLibraryItemId(this.value)
      : assert(value != '', 'Media library item id must not be empty.');

  final String value;
}

final class MediaFileFingerprint {
  const MediaFileFingerprint({required this.algorithm, required this.value})
      : assert(algorithm != '', 'Fingerprint algorithm must not be empty.'),
        assert(value != '', 'Fingerprint value must not be empty.');

  final String algorithm;
  final String value;
}

final class LocalMediaIdentity {
  const LocalMediaIdentity({
    required this.id,
    required this.uri,
    required this.basename,
    this.fingerprint,
  }) : assert(basename != '', 'Media basename must not be empty.');

  final LocalMediaId id;
  final Uri uri;
  final String basename;
  final MediaFileFingerprint? fingerprint;
}

final class MediaScanScope {
  const MediaScanScope({
    required this.roots,
    required this.extensions,
    this.recursive = true,
    this.excludePatterns = const <String>[],
  }) : assert(roots.length > 0,
            'Media scan scope must include at least one root.');

  final List<Uri> roots;
  final Set<String> extensions;
  final bool recursive;
  final List<String> excludePatterns;
}

final class NormalizedMediaScanScope {
  const NormalizedMediaScanScope({
    required this.roots,
    required this.extensions,
    required this.recursive,
    required this.excludePatterns,
  });

  final List<Uri> roots;
  final Set<String> extensions;
  final bool recursive;
  final List<String> excludePatterns;

  bool accepts(Uri uri, {String? basename}) {
    if (!uri.isScheme('file')) {
      return false;
    }
    if (!_isUnderAnyRoot(uri)) {
      return false;
    }

    final String candidateName = basename ?? _basenameFromUri(uri);
    if (extensions.isNotEmpty &&
        !extensions.contains(_extensionOf(candidateName))) {
      return false;
    }

    final String normalizedUri = uri.toString().toLowerCase();
    final String normalizedName = candidateName.toLowerCase();
    for (final String pattern in excludePatterns) {
      if (normalizedUri.contains(pattern) || normalizedName.contains(pattern)) {
        return false;
      }
    }
    return true;
  }

  bool _isUnderAnyRoot(Uri uri) {
    final String value = uri.toString();
    for (final Uri root in roots) {
      if (value.startsWith(root.toString())) {
        return true;
      }
    }
    return false;
  }
}

final class MediaScanScopeNormalizationResult {
  const MediaScanScopeNormalizationResult._(
      {this.scope, this.failures = const <MediaScanFailure>[]});

  const MediaScanScopeNormalizationResult.success(
      NormalizedMediaScanScope scope)
      : this._(scope: scope);

  const MediaScanScopeNormalizationResult.failure(
      List<MediaScanFailure> failures)
      : this._(failures: failures);

  final NormalizedMediaScanScope? scope;
  final List<MediaScanFailure> failures;

  bool get isSuccess => scope != null;
}

MediaScanScopeNormalizationResult normalizeMediaScanScope(
    MediaScanScope scope) {
  final List<Uri> roots = <Uri>[];
  final List<MediaScanFailure> failures = <MediaScanFailure>[];
  for (final Uri root in scope.roots) {
    if (root.isScheme('file')) {
      roots.add(root);
    } else {
      failures.add(
        MediaScanFailure(
          kind: MediaScanFailureKind.unsupportedScheme,
          uri: root,
          message: 'Only file URI scan roots are supported.',
        ),
      );
    }
  }

  if (failures.isNotEmpty) {
    return MediaScanScopeNormalizationResult.failure(failures);
  }

  return MediaScanScopeNormalizationResult.success(
    NormalizedMediaScanScope(
      roots: roots,
      extensions: _normalizeExtensions(scope.extensions),
      recursive: scope.recursive,
      excludePatterns: _normalizePatterns(scope.excludePatterns),
    ),
  );
}

final class MediaScanCandidate {
  const MediaScanCandidate({
    required this.identity,
    required this.sizeBytes,
    this.duration,
    this.discoveredAt,
  }) : assert(sizeBytes >= 0, 'sizeBytes must not be negative.');

  final LocalMediaIdentity identity;
  final int sizeBytes;
  final Duration? duration;
  final DateTime? discoveredAt;
}

final class MediaLibraryItem {
  const MediaLibraryItem({
    required this.id,
    required this.identity,
    required this.addedAt,
    this.duration,
    this.binding,
  });

  final MediaLibraryItemId id;
  final LocalMediaIdentity identity;
  final DateTime addedAt;
  final Duration? duration;
  final ProviderBinding? binding;
}

final class MediaLibraryQuery {
  const MediaLibraryQuery({
    this.offset = 0,
    this.limit = defaultListPageLimit,
    this.onlyUnbound = false,
  })  : assert(offset >= 0, 'offset must not be negative.'),
        assert(limit > 0, 'limit must be positive.');

  final int offset;
  final int limit;
  final bool onlyUnbound;
}

abstract interface class MediaLibraryCatalogRepository {
  Future<MediaLibraryItem> store(MediaLibraryItem item);

  Future<MediaLibraryItem?> findById(MediaLibraryItemId id);

  Future<MediaLibraryItem?> findByLocalMediaId(LocalMediaId mediaId);

  Future<MediaLibraryItem?> findByUri(Uri uri);

  Future<MediaLibraryItem?> findByFingerprint(MediaFileFingerprint fingerprint);

  Future<List<MediaLibraryItem>> list(
      {MediaLibraryQuery query = const MediaLibraryQuery()});

  Future<MediaLibraryItem> update(MediaLibraryItem item);

  Future<bool> remove(MediaLibraryItemId id);

  Future<int> count();
}

enum MediaImportFailureKind {
  duplicateConflict,
  invalidCandidate,
  persistenceFailed,
}

final class MediaImportFailure {
  const MediaImportFailure(
      {required this.kind, required this.candidate, required this.message})
      : assert(message != '', 'Import failure message must not be empty.');

  final MediaImportFailureKind kind;
  final MediaScanCandidate candidate;
  final String message;
}

enum MediaImportItemOutcomeKind {
  imported,
  skippedDuplicate,
  failed,
}

final class MediaImportItemOutcome {
  const MediaImportItemOutcome._({
    required this.kind,
    required this.candidate,
    this.item,
    this.failure,
  });

  const MediaImportItemOutcome.imported(
      {required MediaScanCandidate candidate, required MediaLibraryItem item})
      : this._(
            kind: MediaImportItemOutcomeKind.imported,
            candidate: candidate,
            item: item);

  const MediaImportItemOutcome.skippedDuplicate(
      {required MediaScanCandidate candidate, required MediaLibraryItem item})
      : this._(
            kind: MediaImportItemOutcomeKind.skippedDuplicate,
            candidate: candidate,
            item: item);

  MediaImportItemOutcome.failed(MediaImportFailure failure)
      : this._(
            kind: MediaImportItemOutcomeKind.failed,
            candidate: failure.candidate,
            failure: failure);

  final MediaImportItemOutcomeKind kind;
  final MediaScanCandidate candidate;
  final MediaLibraryItem? item;
  final MediaImportFailure? failure;

  bool get isSuccess => kind == MediaImportItemOutcomeKind.imported;
}

final class MediaImportResult {
  const MediaImportResult({required this.outcomes});

  final List<MediaImportItemOutcome> outcomes;

  List<MediaLibraryItem> get imported {
    final List<MediaLibraryItem> items = <MediaLibraryItem>[];
    for (final MediaImportItemOutcome outcome in outcomes) {
      if (outcome.kind == MediaImportItemOutcomeKind.imported &&
          outcome.item != null) {
        items.add(outcome.item!);
      }
    }
    return items;
  }

  List<MediaLibraryItem> get skippedDuplicates {
    final List<MediaLibraryItem> items = <MediaLibraryItem>[];
    for (final MediaImportItemOutcome outcome in outcomes) {
      if (outcome.kind == MediaImportItemOutcomeKind.skippedDuplicate &&
          outcome.item != null) {
        items.add(outcome.item!);
      }
    }
    return items;
  }

  List<MediaImportFailure> get failures {
    final List<MediaImportFailure> values = <MediaImportFailure>[];
    for (final MediaImportItemOutcome outcome in outcomes) {
      if (outcome.failure != null) {
        values.add(outcome.failure!);
      }
    }
    return values;
  }

  int get importedCount => imported.length;

  int get skippedDuplicateCount => skippedDuplicates.length;

  int get failureCount => failures.length;
}

abstract interface class MediaBatchImportContract {
  Future<MediaImportResult> importBatch(
      Iterable<MediaScanCandidate> candidates);
}

final class DeterministicMediaLibraryCatalogRepository
    implements MediaLibraryCatalogRepository {
  DeterministicMediaLibraryCatalogRepository(
      {Iterable<MediaLibraryItem> seedItems = const <MediaLibraryItem>[]}) {
    for (final MediaLibraryItem item in seedItems) {
      _itemsById[item.id.value] = item;
    }
  }

  final Map<String, MediaLibraryItem> _itemsById = <String, MediaLibraryItem>{};

  @override
  Future<int> count() => Future<int>.value(_itemsById.length);

  @override
  Future<MediaLibraryItem?> findByFingerprint(
      MediaFileFingerprint fingerprint) {
    for (final MediaLibraryItem item in _itemsById.values) {
      final MediaFileFingerprint? existing = item.identity.fingerprint;
      if (existing != null &&
          existing.algorithm == fingerprint.algorithm &&
          existing.value == fingerprint.value) {
        return Future<MediaLibraryItem?>.value(item);
      }
    }
    return Future<MediaLibraryItem?>.value();
  }

  @override
  Future<MediaLibraryItem?> findById(MediaLibraryItemId id) =>
      Future<MediaLibraryItem?>.value(_itemsById[id.value]);

  @override
  Future<MediaLibraryItem?> findByLocalMediaId(LocalMediaId mediaId) {
    for (final MediaLibraryItem item in _itemsById.values) {
      if (item.identity.id.value == mediaId.value) {
        return Future<MediaLibraryItem?>.value(item);
      }
    }
    return Future<MediaLibraryItem?>.value();
  }

  @override
  Future<MediaLibraryItem?> findByUri(Uri uri) {
    for (final MediaLibraryItem item in _itemsById.values) {
      if (item.identity.uri == uri) {
        return Future<MediaLibraryItem?>.value(item);
      }
    }
    return Future<MediaLibraryItem?>.value();
  }

  @override
  Future<List<MediaLibraryItem>> list(
      {MediaLibraryQuery query = const MediaLibraryQuery()}) {
    final List<MediaLibraryItem> items = <MediaLibraryItem>[
      for (final MediaLibraryItem item in _itemsById.values)
        if (!query.onlyUnbound || item.binding == null) item,
    ];
    final int start = query.offset > items.length ? items.length : query.offset;
    final int end =
        start + query.limit > items.length ? items.length : start + query.limit;
    return Future<List<MediaLibraryItem>>.value(items.sublist(start, end));
  }

  @override
  Future<bool> remove(MediaLibraryItemId id) =>
      Future<bool>.value(_itemsById.remove(id.value) != null);

  @override
  Future<MediaLibraryItem> store(MediaLibraryItem item) {
    _itemsById[item.id.value] = item;
    return Future<MediaLibraryItem>.value(item);
  }

  @override
  Future<MediaLibraryItem> update(MediaLibraryItem item) {
    _itemsById[item.id.value] = item;
    return Future<MediaLibraryItem>.value(item);
  }
}

final class DeterministicMediaBatchImportContract
    implements MediaBatchImportContract {
  DeterministicMediaBatchImportContract({
    required this.repository,
    DateTime Function()? clock,
    this.itemIdPrefix = 'imported',
  })  : assert(itemIdPrefix != '', 'itemIdPrefix must not be empty.'),
        _clock = clock ?? _defaultClock;

  final MediaLibraryCatalogRepository repository;
  final DateTime Function() _clock;
  final String itemIdPrefix;

  @override
  Future<MediaImportResult> importBatch(
      Iterable<MediaScanCandidate> candidates) async {
    final List<MediaImportItemOutcome> outcomes = <MediaImportItemOutcome>[];
    var index = 0;
    for (final MediaScanCandidate candidate in candidates) {
      final MediaLibraryItem? uriMatch =
          await repository.findByUri(candidate.identity.uri);
      final MediaFileFingerprint? fingerprint = candidate.identity.fingerprint;
      final MediaLibraryItem? fingerprintMatch = fingerprint == null
          ? null
          : await repository.findByFingerprint(fingerprint);

      if (uriMatch != null &&
          fingerprintMatch != null &&
          uriMatch.id.value != fingerprintMatch.id.value) {
        outcomes.add(
          MediaImportItemOutcome.failed(
            MediaImportFailure(
              kind: MediaImportFailureKind.duplicateConflict,
              candidate: candidate,
              message:
                  'Candidate URI and fingerprint match different catalog items.',
            ),
          ),
        );
        index += 1;
        continue;
      }

      final MediaLibraryItem? duplicate = uriMatch ?? fingerprintMatch;
      if (duplicate != null) {
        outcomes.add(MediaImportItemOutcome.skippedDuplicate(
            candidate: candidate, item: duplicate));
        index += 1;
        continue;
      }

      final MediaLibraryItem item = MediaLibraryItem(
        id: MediaLibraryItemId(
            '$itemIdPrefix-${candidate.identity.id.value}-$index'),
        identity: candidate.identity,
        addedAt: _clock(),
        duration: candidate.duration,
      );
      outcomes.add(MediaImportItemOutcome.imported(
          candidate: candidate, item: await repository.store(item)));
      index += 1;
    }
    return MediaImportResult(outcomes: outcomes);
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

abstract interface class MediaLibraryScanner {
  Future<MediaScanResult> scan(MediaScanScope scope);

  Stream<MediaScanEvent> watch(MediaScanId scanId);

  Future<void> cancel(MediaScanId scanId);
}

final class DeterministicMediaLibraryScanner implements MediaLibraryScanner {
  DeterministicMediaLibraryScanner({
    required MediaScanId scanId,
    List<MediaScanCandidate> candidates = const <MediaScanCandidate>[],
    List<MediaScanFailure> unreadableEntries = const <MediaScanFailure>[],
  })  : _scanId = scanId,
        _candidates = candidates,
        _unreadableEntries = unreadableEntries;

  final MediaScanId _scanId;
  final List<MediaScanCandidate> _candidates;
  final List<MediaScanFailure> _unreadableEntries;
  final Map<String, List<MediaScanEvent>> _eventsByScanId =
      <String, List<MediaScanEvent>>{};
  final Set<String> _cancelledScanIds = <String>{};

  @override
  Future<MediaScanResult> scan(MediaScanScope scope) {
    if (_cancelledScanIds.contains(_scanId.value)) {
      final MediaScanFailure failure = MediaScanFailure(
        kind: MediaScanFailureKind.cancelled,
        uri: _firstRootOrEmpty(scope),
        message: 'Media scan was cancelled.',
      );
      final MediaScanResult result = MediaScanResult(
          scanId: _scanId,
          candidates: const <MediaScanCandidate>[],
          failures: <MediaScanFailure>[failure]);
      _recordCancelled(_scanId, failure);
      return Future<MediaScanResult>.value(result);
    }

    final MediaScanScopeNormalizationResult normalization =
        normalizeMediaScanScope(scope);
    final NormalizedMediaScanScope? normalizedScope = normalization.scope;
    if (normalizedScope == null) {
      final MediaScanResult result = MediaScanResult(
          scanId: _scanId,
          candidates: const <MediaScanCandidate>[],
          failures: normalization.failures);
      for (final MediaScanFailure failure in normalization.failures) {
        _record(_scanId, MediaScanFailed(scanId: _scanId, failure: failure));
      }
      return Future<MediaScanResult>.value(result);
    }

    final List<MediaScanCandidate> accepted = <MediaScanCandidate>[];
    final List<MediaScanFailure> failures = <MediaScanFailure>[
      ..._unreadableEntries
    ];
    for (final MediaScanCandidate candidate in _candidates) {
      if (normalizedScope.accepts(candidate.identity.uri,
          basename: candidate.identity.basename)) {
        accepted.add(candidate);
        _record(
            _scanId,
            MediaScanCandidateDiscovered(
                scanId: _scanId, candidate: candidate));
        _record(
            _scanId,
            MediaScanProgressChanged(
                scanId: _scanId, scannedCount: accepted.length));
      } else {
        failures.add(
          MediaScanFailure(
            kind: candidate.identity.uri.isScheme('file')
                ? MediaScanFailureKind.excluded
                : MediaScanFailureKind.unsupportedScheme,
            uri: candidate.identity.uri,
            message: 'Media scan candidate is outside the normalized scope.',
          ),
        );
      }
    }

    final MediaScanResult result = MediaScanResult(
        scanId: _scanId, candidates: accepted, failures: failures);
    _record(_scanId, MediaScanCompleted(scanId: _scanId, result: result));
    return Future<MediaScanResult>.value(result);
  }

  @override
  Stream<MediaScanEvent> watch(MediaScanId scanId) {
    return Stream<MediaScanEvent>.fromIterable(
        _eventsByScanId[scanId.value] ?? const <MediaScanEvent>[]);
  }

  @override
  Future<void> cancel(MediaScanId scanId) {
    if (_cancelledScanIds.add(scanId.value)) {
      final MediaScanFailure failure = MediaScanFailure(
        kind: MediaScanFailureKind.cancelled,
        uri: Uri.parse(''),
        message: 'Media scan was cancelled.',
      );
      _recordCancelled(scanId, failure);
    }
    return Future<void>.value();
  }

  void _recordCancelled(MediaScanId scanId, MediaScanFailure failure) {
    final List<MediaScanEvent> events =
        _eventsByScanId.putIfAbsent(scanId.value, () => <MediaScanEvent>[]);
    if (events.whereType<MediaScanCancelled>().isEmpty) {
      events.add(MediaScanCancelled(scanId: scanId, failure: failure));
    }
  }

  void _record(MediaScanId scanId, MediaScanEvent event) {
    _eventsByScanId
        .putIfAbsent(scanId.value, () => <MediaScanEvent>[])
        .add(event);
  }
}

final class MediaScanResult {
  const MediaScanResult({
    required this.scanId,
    required this.candidates,
    this.failures = const <MediaScanFailure>[],
  });

  final MediaScanId scanId;
  final List<MediaScanCandidate> candidates;
  final List<MediaScanFailure> failures;
}

enum MediaScanFailureKind {
  unsupportedScheme,
  excluded,
  unreadableEntry,
  cancelled,
  discoveryFailed,
}

final class MediaScanFailure {
  const MediaScanFailure(
      {required this.kind, required this.uri, required this.message});

  final MediaScanFailureKind kind;
  final Uri uri;
  final String message;
}

sealed class MediaScanEvent {
  const MediaScanEvent({required this.scanId});

  final MediaScanId scanId;
}

final class MediaScanCandidateDiscovered extends MediaScanEvent {
  const MediaScanCandidateDiscovered(
      {required super.scanId, required this.candidate});

  final MediaScanCandidate candidate;
}

final class MediaScanProgressChanged extends MediaScanEvent {
  const MediaScanProgressChanged(
      {required super.scanId, required this.scannedCount});

  final int scannedCount;
}

final class MediaScanCompleted extends MediaScanEvent {
  const MediaScanCompleted({required super.scanId, required this.result});

  final MediaScanResult result;
}

final class MediaScanFailed extends MediaScanEvent {
  const MediaScanFailed({required super.scanId, required this.failure});

  final MediaScanFailure failure;
}

final class MediaScanCancelled extends MediaScanEvent {
  const MediaScanCancelled({required super.scanId, required this.failure});

  final MediaScanFailure failure;
}

Set<String> _normalizeExtensions(Set<String> extensions) {
  return <String>{
    for (final String extension in extensions)
      if (extension.trim().isNotEmpty)
        extension.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), ''),
  };
}

List<String> _normalizePatterns(List<String> patterns) {
  return <String>[
    for (final String pattern in patterns)
      if (pattern.trim().isNotEmpty) pattern.trim().toLowerCase(),
  ];
}

String _basenameFromUri(Uri uri) {
  if (uri.pathSegments.isEmpty) {
    return '';
  }
  return uri.pathSegments.last;
}

String _extensionOf(String basename) {
  final int dotIndex = basename.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == basename.length - 1) {
    return '';
  }
  return basename.substring(dotIndex + 1).toLowerCase();
}

Uri _firstRootOrEmpty(MediaScanScope scope) {
  if (scope.roots.isEmpty) {
    return Uri.parse('');
  }
  return scope.roots.first;
}

final class PlaybackHistoryEntryId {
  const PlaybackHistoryEntryId(this.value)
      : assert(value != '', 'Playback history entry id must not be empty.');

  final String value;
}

final class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.id,
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  })  : assert(position >= Duration.zero, 'position must not be negative.'),
        assert(duration >= Duration.zero, 'duration must not be negative.');

  final PlaybackHistoryEntryId id;
  final LocalMediaId mediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
}

final class ContinueWatchingState {
  const ContinueWatchingState({
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  })  : assert(position >= Duration.zero, 'position must not be negative.'),
        assert(duration >= Duration.zero, 'duration must not be negative.');

  final LocalMediaId mediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get progress {
    if (duration == Duration.zero) {
      return 0;
    }
    final ratio = position.inMilliseconds / duration.inMilliseconds;
    return ratio.clamp(0, 1).toDouble();
  }
}

abstract interface class PlaybackHistoryStore {
  Future<void> record(PlaybackHistoryEntry entry);

  Future<PlaybackHistoryEntry?> latestFor(LocalMediaId mediaId);

  Future<List<ContinueWatchingState>> continueWatching(
      {int limit = defaultRecentListLimit});
}

enum ProviderBindingAuthority {
  automatic,
  userConfirmed,
}

final class ProviderBindingId {
  const ProviderBindingId(this.value)
      : assert(value != '', 'Provider binding id must not be empty.');

  final String value;
}

final class ProviderSubjectId {
  const ProviderSubjectId(this.value)
      : assert(value != '', 'Provider subject id must not be empty.');

  final String value;
}

final class ProviderBinding {
  const ProviderBinding({
    required this.id,
    required this.localMediaId,
    required this.providerId,
    required this.subjectId,
    required this.authority,
    required this.confidence,
    required this.createdAt,
  }) : assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final ProviderBindingId id;
  final LocalMediaId localMediaId;
  final String providerId;
  final ProviderSubjectId? subjectId;
  final ProviderBindingAuthority authority;
  final double confidence;
  final DateTime createdAt;

  bool outranks(ProviderBinding other) {
    if (authority == other.authority) {
      return confidence >= other.confidence;
    }
    return authority == ProviderBindingAuthority.userConfirmed;
  }
}

abstract interface class ProviderBindingStore {
  Future<ProviderBinding?> bindingFor(LocalMediaId mediaId);

  Future<ProviderBinding?> bindingForProvider(
      {required LocalMediaId mediaId, required String providerId});

  Future<List<ProviderBinding>> bindingsFor(LocalMediaId mediaId);

  Future<ProviderBinding> saveUserConfirmed(ProviderBinding binding);

  Future<ProviderBinding> saveAutomaticIfAllowed(ProviderBinding candidate);
}

final class DeterministicPlaybackHistoryStore implements PlaybackHistoryStore {
  final Map<String, List<PlaybackHistoryEntry>> _entriesByMediaId =
      <String, List<PlaybackHistoryEntry>>{};

  @override
  Future<List<ContinueWatchingState>> continueWatching(
      {int limit = defaultRecentListLimit}) {
    assert(limit > 0, 'limit must be positive.');
    final List<PlaybackHistoryEntry> latestEntries = <PlaybackHistoryEntry>[];
    for (final String mediaId in _entriesByMediaId.keys) {
      final PlaybackHistoryEntry? entry = _latestEntryFor(mediaId);
      if (entry != null) {
        latestEntries.add(entry);
      }
    }
    latestEntries.sort(
        (PlaybackHistoryEntry left, PlaybackHistoryEntry right) =>
            right.updatedAt.compareTo(left.updatedAt));
    final int end = latestEntries.length > limit ? limit : latestEntries.length;
    return Future<List<ContinueWatchingState>>.value(
      <ContinueWatchingState>[
        for (final PlaybackHistoryEntry entry in latestEntries.sublist(0, end))
          ContinueWatchingState(
            mediaId: entry.mediaId,
            position: entry.position,
            duration: entry.duration,
            updatedAt: entry.updatedAt,
          ),
      ],
    );
  }

  @override
  Future<PlaybackHistoryEntry?> latestFor(LocalMediaId mediaId) =>
      Future<PlaybackHistoryEntry?>.value(_latestEntryFor(mediaId.value));

  @override
  Future<void> record(PlaybackHistoryEntry entry) {
    _entriesByMediaId
        .putIfAbsent(entry.mediaId.value, () => <PlaybackHistoryEntry>[])
        .add(entry);
    return Future<void>.value();
  }

  PlaybackHistoryEntry? _latestEntryFor(String mediaId) {
    final List<PlaybackHistoryEntry>? entries = _entriesByMediaId[mediaId];
    if (entries == null || entries.isEmpty) {
      return null;
    }
    PlaybackHistoryEntry latest = entries.first;
    for (final PlaybackHistoryEntry entry in entries.skip(1)) {
      if (entry.updatedAt.isAfter(latest.updatedAt)) {
        latest = entry;
      }
    }
    return latest;
  }
}

final class DeterministicProviderBindingStore implements ProviderBindingStore {
  final Map<String, ProviderBinding> _bindingsByLocalAndProvider =
      <String, ProviderBinding>{};

  @override
  Future<ProviderBinding?> bindingFor(LocalMediaId mediaId) {
    ProviderBinding? strongest;
    for (final ProviderBinding binding in _bindingsForMedia(mediaId)) {
      if (strongest == null || binding.outranks(strongest)) {
        strongest = binding;
      }
    }
    return Future<ProviderBinding?>.value(strongest);
  }

  @override
  Future<ProviderBinding?> bindingForProvider(
      {required LocalMediaId mediaId, required String providerId}) {
    return Future<ProviderBinding?>.value(
        _bindingsByLocalAndProvider[_key(mediaId, providerId)]);
  }

  @override
  Future<List<ProviderBinding>> bindingsFor(LocalMediaId mediaId) =>
      Future<List<ProviderBinding>>.value(_bindingsForMedia(mediaId));

  @override
  Future<ProviderBinding> saveAutomaticIfAllowed(ProviderBinding candidate) {
    final String key = _key(candidate.localMediaId, candidate.providerId);
    final ProviderBinding? existing = _bindingsByLocalAndProvider[key];
    if (existing != null && existing.outranks(candidate)) {
      return Future<ProviderBinding>.value(existing);
    }
    _bindingsByLocalAndProvider[key] = candidate;
    return Future<ProviderBinding>.value(candidate);
  }

  @override
  Future<ProviderBinding> saveUserConfirmed(ProviderBinding binding) {
    _bindingsByLocalAndProvider[
        _key(binding.localMediaId, binding.providerId)] = binding;
    return Future<ProviderBinding>.value(binding);
  }

  List<ProviderBinding> _bindingsForMedia(LocalMediaId mediaId) {
    return <ProviderBinding>[
      for (final ProviderBinding binding in _bindingsByLocalAndProvider.values)
        if (binding.localMediaId.value == mediaId.value) binding,
    ];
  }

  static String _key(LocalMediaId mediaId, String providerId) =>
      '${mediaId.value}::$providerId';
}
