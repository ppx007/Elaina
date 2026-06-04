import 'dart:async';

sealed class CacheInvalidationEvent {
  const CacheInvalidationEvent({required this.occurredAt});

  final DateTime occurredAt;
}

final class DanmakuPosted extends CacheInvalidationEvent {
  const DanmakuPosted({
    required super.occurredAt,
    required this.subjectId,
    required this.episodeId,
  });

  final String subjectId;
  final String episodeId;
}

final class BindingChanged extends CacheInvalidationEvent {
  const BindingChanged({
    required super.occurredAt,
    required this.localMediaId,
    this.providerId,
    this.providerSubjectId,
  });

  final String localMediaId;
  final String? providerId;
  final String? providerSubjectId;
}

final class ProviderAuthChanged extends CacheInvalidationEvent {
  const ProviderAuthChanged({
    required super.occurredAt,
    required this.providerId,
  });

  final String providerId;
}

enum MediaLibraryChangeKind {
  created,
  updated,
  removed,
}

final class MediaLibraryItemChanged extends CacheInvalidationEvent {
  const MediaLibraryItemChanged({
    required super.occurredAt,
    required this.mediaLibraryItemId,
    required this.localMediaId,
    required this.changeKind,
  });

  final String mediaLibraryItemId;
  final String localMediaId;
  final MediaLibraryChangeKind changeKind;
}

final class LibraryItemAdded extends MediaLibraryItemChanged {
  const LibraryItemAdded({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.created);
}

final class LibraryItemUpdated extends MediaLibraryItemChanged {
  const LibraryItemUpdated({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.updated);
}

final class LibraryItemRemoved extends MediaLibraryItemChanged {
  const LibraryItemRemoved({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.removed);
}

final class HistoryRecorded extends CacheInvalidationEvent {
  const HistoryRecorded({required super.occurredAt, required this.localMediaId});

  final String localMediaId;
}

abstract interface class CacheInvalidationBus {
  Stream<CacheInvalidationEvent> get events;

  void publish(CacheInvalidationEvent event);
}

final class StreamCacheInvalidationBus implements CacheInvalidationBus {
  StreamCacheInvalidationBus()
      : _controller = StreamController<CacheInvalidationEvent>.broadcast(sync: true);

  final StreamController<CacheInvalidationEvent> _controller;

  @override
  Stream<CacheInvalidationEvent> get events => _controller.stream;

  @override
  void publish(CacheInvalidationEvent event) {
    if (_controller.isClosed) {
      throw StateError('Cannot publish after CacheInvalidationBus is closed.');
    }
    _controller.add(event);
  }

  Future<void> close() => _controller.close();
}
