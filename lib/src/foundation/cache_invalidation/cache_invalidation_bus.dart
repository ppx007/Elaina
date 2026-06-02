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
    required this.providerSubjectId,
  });

  final String localMediaId;
  final String providerSubjectId;
}

final class ProviderAuthChanged extends CacheInvalidationEvent {
  const ProviderAuthChanged({
    required super.occurredAt,
    required this.providerId,
  });

  final String providerId;
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
