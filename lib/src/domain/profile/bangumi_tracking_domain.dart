enum BangumiTrackingStatus {
  planned,
  completed,
  watching,
  onHold,
  dropped,
}

enum BangumiTrackingLoadStatus {
  loaded,
  unauthenticated,
  failed,
}

final class BangumiTrackingSnapshot {
  BangumiTrackingSnapshot.loaded(Iterable<BangumiTrackingItem> items)
      : status = BangumiTrackingLoadStatus.loaded,
        message = null,
        items = List<BangumiTrackingItem>.unmodifiable(items);

  const BangumiTrackingSnapshot.unauthenticated(String this.message)
      : status = BangumiTrackingLoadStatus.unauthenticated,
        items = const <BangumiTrackingItem>[];

  const BangumiTrackingSnapshot.failed(String this.message)
      : status = BangumiTrackingLoadStatus.failed,
        items = const <BangumiTrackingItem>[];

  final BangumiTrackingLoadStatus status;
  final String? message;
  final List<BangumiTrackingItem> items;
}

final class BangumiTrackingItem {
  const BangumiTrackingItem({
    required this.subjectId,
    required this.title,
    required this.status,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    this.coverUri,
    this.updatedAt,
  })  : assert(subjectId != '', 'Bangumi subject id must not be empty.'),
        assert(title != '', 'Bangumi tracking title must not be empty.'),
        assert(watchedEpisodes >= 0,
            'Bangumi watched episode count must not be negative.'),
        assert(totalEpisodes >= 0,
            'Bangumi total episode count must not be negative.');

  final String subjectId;
  final String title;
  final BangumiTrackingStatus status;
  final int watchedEpisodes;
  final int totalEpisodes;
  final Uri? coverUri;
  final DateTime? updatedAt;
}

abstract interface class BangumiTrackingProvider {
  Future<BangumiTrackingSnapshot> currentAnimeCollection();
}
