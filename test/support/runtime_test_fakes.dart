import 'dart:async';

import 'package:elaina/elaina.dart';

final class RecordingCacheInvalidationBus implements CacheInvalidationBus {
  final StreamController<CacheInvalidationEvent> _controller =
      StreamController<CacheInvalidationEvent>.broadcast(sync: true);
  final List<CacheInvalidationEvent> publishedEvents =
      <CacheInvalidationEvent>[];

  @override
  Stream<CacheInvalidationEvent> get events => _controller.stream;

  @override
  void publish(CacheInvalidationEvent event) {
    publishedEvents.add(event);
    _controller.add(event);
  }

  @override
  Future<void> close() => _controller.close();
}

final class RecordingPlaybackSourceHandoff
    implements PlaybackSourceHandoffContract {
  final List<LocalMediaIdentity> inputs = <LocalMediaIdentity>[];

  @override
  PlaybackSourceHandoffResult prepare(PlaybackSourceHandoffInput input) {
    if (input case LocalMediaIdentityHandoffInput(:final identity)) {
      inputs.add(identity);
    }
    return const LocalPlaybackSourceHandoff().prepare(input);
  }
}

final class FakeBangumiTrackingProvider implements BangumiTrackingProvider {
  const FakeBangumiTrackingProvider(this.snapshot);

  final BangumiTrackingSnapshot snapshot;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    return snapshot;
  }
}

final class MutableBangumiTrackingProvider implements BangumiTrackingProvider {
  MutableBangumiTrackingProvider(this.snapshot);

  BangumiTrackingSnapshot snapshot;
  int calls = 0;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    calls++;
    return snapshot;
  }
}

final class RecordingBangumiTrackingSyncProvider
    implements BangumiTrackingSyncProvider {
  final List<String> calls = <String>[];

  @override
  Future<BangumiTrackingSyncResult> syncTrackingStatus({
    required String subjectId,
    required BangumiTrackingStatus status,
  }) async {
    calls.add('$subjectId:${status.name}');
    return const BangumiTrackingSyncResult.success();
  }
}

final class EmptyMediaLibraryScanner implements MediaLibraryScanner {
  const EmptyMediaLibraryScanner();

  @override
  Future<void> cancel(MediaScanId scanId) => Future<void>.value();

  @override
  Future<MediaScanResult> scan(MediaScanScope scope) {
    return Future<MediaScanResult>.value(
      const MediaScanResult(
        scanId: MediaScanId('empty'),
        candidates: <MediaScanCandidate>[],
      ),
    );
  }

  @override
  Stream<MediaScanEvent> watch(MediaScanId scanId) {
    return const Stream<MediaScanEvent>.empty();
  }
}

LocalMediaIdentity testLocalMediaIdentity(String id, String basename) {
  return LocalMediaIdentity(
    id: LocalMediaId(id),
    uri: Uri.file('/library/$basename'),
    basename: basename,
  );
}

BangumiSubject testBangumiSubject({
  String id = 'subject-1',
  String title = 'Subject Title',
  String summary = 'Subject summary',
}) {
  return BangumiSubject(
    id: BangumiSubjectId(id),
    title: title,
    summary: summary,
  );
}

BangumiEpisode testBangumiEpisode({
  required String id,
  required int index,
  String subjectId = 'subject-1',
}) {
  return BangumiEpisode(
    id: BangumiEpisodeId(id),
    subjectId: BangumiSubjectId(subjectId),
    index: index,
    title: 'Episode $index',
  );
}
