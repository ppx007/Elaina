import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../playback/playback_state.dart';
import 'media_library.dart';

const String playbackHistoryRecorderEntryIdPrefix = 'playback-history';

const Set<PlaybackLifecycleStatus> playbackHistoryRecordableStatuses =
    <PlaybackLifecycleStatus>{
  PlaybackLifecycleStatus.playing,
  PlaybackLifecycleStatus.paused,
  PlaybackLifecycleStatus.buffering,
  PlaybackLifecycleStatus.ended,
};

enum PlaybackHistoryRecordingResultKind {
  recorded,
  skipped,
  failed,
}

enum PlaybackHistoryRecordingFailureKind {
  disposed,
  nonRecordableStatus,
  missingSourceUri,
  missingDuration,
  invalidTimeline,
  catalogItemNotFound,
  persistenceFailed,
}

final class PlaybackHistoryRecordingFailure {
  const PlaybackHistoryRecordingFailure({
    required this.kind,
    required this.message,
  }) : assert(
          message != '',
          'Playback history recording failure message must not be empty.',
        );

  final PlaybackHistoryRecordingFailureKind kind;
  final String message;
}

final class PlaybackHistoryRecordingResult {
  const PlaybackHistoryRecordingResult._({
    required this.kind,
    this.entry,
    this.mediaItem,
    this.failure,
  });

  const PlaybackHistoryRecordingResult.recorded({
    required PlaybackHistoryEntry entry,
    required MediaLibraryItem mediaItem,
  }) : this._(
          kind: PlaybackHistoryRecordingResultKind.recorded,
          entry: entry,
          mediaItem: mediaItem,
        );

  const PlaybackHistoryRecordingResult.skipped(
    PlaybackHistoryRecordingFailure failure,
  ) : this._(
          kind: PlaybackHistoryRecordingResultKind.skipped,
          failure: failure,
        );

  const PlaybackHistoryRecordingResult.failed(
    PlaybackHistoryRecordingFailure failure,
  ) : this._(
          kind: PlaybackHistoryRecordingResultKind.failed,
          failure: failure,
        );

  final PlaybackHistoryRecordingResultKind kind;
  final PlaybackHistoryEntry? entry;
  final MediaLibraryItem? mediaItem;
  final PlaybackHistoryRecordingFailure? failure;

  bool get isRecorded => kind == PlaybackHistoryRecordingResultKind.recorded;
}

final class PlaybackHistoryRecorder {
  PlaybackHistoryRecorder({
    required MediaLibraryCatalogRepository catalogRepository,
    required PlaybackHistoryStore historyStore,
    required CacheInvalidationBus invalidationBus,
    DateTime Function()? now,
    String entryIdPrefix = playbackHistoryRecorderEntryIdPrefix,
  })  : assert(entryIdPrefix != '', 'entryIdPrefix must not be empty.'),
        _catalogRepository = catalogRepository,
        _historyStore = historyStore,
        _invalidationBus = invalidationBus,
        _now = now ?? DateTime.now,
        _entryIdPrefix = entryIdPrefix;

  final MediaLibraryCatalogRepository _catalogRepository;
  final PlaybackHistoryStore _historyStore;
  final CacheInvalidationBus _invalidationBus;
  final DateTime Function() _now;
  final String _entryIdPrefix;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  Future<PlaybackHistoryRecordingResult> record(
    PlaybackStateSnapshot snapshot,
  ) async {
    if (_disposed) {
      return _skipped(
        PlaybackHistoryRecordingFailureKind.disposed,
        'PlaybackHistoryRecorder has been disposed.',
      );
    }
    if (!playbackHistoryRecordableStatuses.contains(snapshot.status)) {
      return _skipped(
        PlaybackHistoryRecordingFailureKind.nonRecordableStatus,
        'Playback status is not recordable.',
      );
    }

    final Uri? sourceUri = snapshot.sourceUri;
    if (sourceUri == null) {
      return _skipped(
        PlaybackHistoryRecordingFailureKind.missingSourceUri,
        'Playback snapshot has no source URI.',
      );
    }
    final Duration? duration = snapshot.timeline.duration;
    if (duration == null) {
      return _skipped(
        PlaybackHistoryRecordingFailureKind.missingDuration,
        'Playback snapshot has no duration.',
      );
    }
    if (snapshot.timeline.position < Duration.zero ||
        duration < Duration.zero) {
      return _skipped(
        PlaybackHistoryRecordingFailureKind.invalidTimeline,
        'Playback snapshot timeline must not be negative.',
      );
    }

    try {
      final MediaLibraryItem? item =
          await _catalogRepository.findByUri(sourceUri);
      if (item == null) {
        return _skipped(
          PlaybackHistoryRecordingFailureKind.catalogItemNotFound,
          'Playback source URI is not present in the media catalog.',
        );
      }

      final DateTime updatedAt = snapshot.timeline.observedAt ?? _now();
      final PlaybackHistoryEntry entry = PlaybackHistoryEntry(
        id: PlaybackHistoryEntryId(
          _entryIdFor(
            mediaId: item.identity.id,
            updatedAt: updatedAt,
            position: snapshot.timeline.position,
          ),
        ),
        mediaId: item.identity.id,
        position: snapshot.timeline.position,
        duration: duration,
        updatedAt: updatedAt,
      );
      await _historyStore.record(entry);
      _invalidationBus.publish(
        HistoryRecorded(
          occurredAt: entry.updatedAt,
          localMediaId: entry.mediaId.value,
        ),
      );
      return PlaybackHistoryRecordingResult.recorded(
        entry: entry,
        mediaItem: item,
      );
    } on Object catch (error) {
      return _failed(
        PlaybackHistoryRecordingFailureKind.persistenceFailed,
        'Playback history recording failed: $error',
      );
    }
  }

  void dispose() {
    _disposed = true;
  }

  String _entryIdFor({
    required LocalMediaId mediaId,
    required DateTime updatedAt,
    required Duration position,
  }) {
    return '$_entryIdPrefix-${mediaId.value}-'
        '${updatedAt.microsecondsSinceEpoch}-${position.inMicroseconds}';
  }

  PlaybackHistoryRecordingResult _skipped(
    PlaybackHistoryRecordingFailureKind kind,
    String message,
  ) {
    return PlaybackHistoryRecordingResult.skipped(
      PlaybackHistoryRecordingFailure(kind: kind, message: message),
    );
  }

  PlaybackHistoryRecordingResult _failed(
    PlaybackHistoryRecordingFailureKind kind,
    String message,
  ) {
    return PlaybackHistoryRecordingResult.failed(
      PlaybackHistoryRecordingFailure(kind: kind, message: message),
    );
  }
}

final class PlaybackHistoryRecordingObserver implements PlaybackStateObserver {
  PlaybackHistoryRecordingObserver({
    required PlaybackStateObservable observable,
    required PlaybackHistoryRecorder recorder,
  })  : _observable = observable,
        _recorder = recorder {
    _observable.addPlaybackStateObserver(this);
  }

  final PlaybackStateObservable _observable;
  final PlaybackHistoryRecorder _recorder;
  Future<PlaybackHistoryRecordingResult>? lastRecording;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    if (_disposed) return;
    lastRecording = _recorder.record(snapshot);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _observable.removePlaybackStateObserver(this);
  }
}
