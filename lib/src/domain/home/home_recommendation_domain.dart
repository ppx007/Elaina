enum HomeRecommendationLoadStatus {
  loaded,
  failed,
}

final class HomeRecommendationSnapshot {
  HomeRecommendationSnapshot.loaded(Iterable<HomeRecommendationItem> items)
      : status = HomeRecommendationLoadStatus.loaded,
        message = null,
        items = List<HomeRecommendationItem>.unmodifiable(items);

  const HomeRecommendationSnapshot.failed(String this.message)
      : status = HomeRecommendationLoadStatus.failed,
        items = const <HomeRecommendationItem>[];

  final HomeRecommendationLoadStatus status;
  final String? message;
  final List<HomeRecommendationItem> items;
}

final class HomeRecommendationItem {
  const HomeRecommendationItem({
    required this.subjectId,
    required this.title,
    this.summary,
    this.coverUri,
    this.rank,
    this.score,
    this.collectionTotal,
    this.episodeCount,
  })  : assert(subjectId != '', 'Recommendation subject id must not be empty.'),
        assert(title != '', 'Recommendation title must not be empty.'),
        assert(rank == null || rank > 0, 'Rank must be positive.'),
        assert(score == null || score >= 0, 'Score must not be negative.'),
        assert(collectionTotal == null || collectionTotal >= 0,
            'Collection total must not be negative.'),
        assert(episodeCount == null || episodeCount >= 0,
            'Episode count must not be negative.');

  final String subjectId;
  final String title;
  final String? summary;
  final Uri? coverUri;
  final int? rank;
  final double? score;
  final int? collectionTotal;
  final int? episodeCount;

  String get popularitySentence {
    final List<String> parts = <String>[];
    final double? valueScore = score;
    if (valueScore != null) {
      parts.add('评分 ${valueScore.toStringAsFixed(1)}');
    }
    final int? valueCollectionTotal = collectionTotal;
    if (valueCollectionTotal != null) {
      parts.add('$valueCollectionTotal 人收藏');
    }
    if (parts.isEmpty) return 'Bangumi 近期热门';
    return 'Bangumi 近期热门，${parts.join('，')}。';
  }
}

abstract interface class HomeRecommendationProvider {
  Future<HomeRecommendationSnapshot> popularAnime();
}
