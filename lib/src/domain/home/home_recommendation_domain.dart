enum HomeRecommendationLoadStatus {
  loaded,
  failed,
}

final class HomeRecommendationCategory {
  const HomeRecommendationCategory({
    required this.id,
    required this.label,
    this.metaTag,
  })  : assert(id != '', 'Home recommendation category id must not be empty.'),
        assert(label != '',
            'Home recommendation category label must not be empty.'),
        assert(metaTag == null || metaTag != '',
            'Home recommendation category meta tag must not be empty.');

  static const HomeRecommendationCategory popular =
      HomeRecommendationCategory(id: 'popular', label: '热门番组');
  static const HomeRecommendationCategory daily =
      HomeRecommendationCategory(id: 'daily', label: '日常', metaTag: '日常');
  static const HomeRecommendationCategory yuri =
      HomeRecommendationCategory(id: 'yuri', label: '百合', metaTag: '百合');
  static const HomeRecommendationCategory romance =
      HomeRecommendationCategory(id: 'romance', label: '恋爱', metaTag: '恋爱');
  static const HomeRecommendationCategory school =
      HomeRecommendationCategory(id: 'school', label: '校园', metaTag: '校园');
  static const HomeRecommendationCategory fantasy =
      HomeRecommendationCategory(id: 'fantasy', label: '奇幻', metaTag: '奇幻');
  static const HomeRecommendationCategory scienceFiction =
      HomeRecommendationCategory(id: 'sci-fi', label: '科幻', metaTag: '科幻');
  static const HomeRecommendationCategory healing =
      HomeRecommendationCategory(id: 'healing', label: '治愈', metaTag: '治愈');
  static const HomeRecommendationCategory comedy =
      HomeRecommendationCategory(id: 'comedy', label: '搞笑', metaTag: '搞笑');
  static const HomeRecommendationCategory battle =
      HomeRecommendationCategory(id: 'battle', label: '战斗', metaTag: '战斗');

  static const List<HomeRecommendationCategory> values =
      <HomeRecommendationCategory>[
    popular,
    daily,
    yuri,
    romance,
    school,
    fantasy,
    scienceFiction,
    healing,
    comedy,
    battle,
  ];

  final String id;
  final String label;
  final String? metaTag;
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
    if (parts.isEmpty) return 'Bangumi 热门条目';
    return 'Bangumi 热门条目，${parts.join('，')}。';
  }
}

abstract interface class HomeRecommendationProvider {
  Future<HomeRecommendationSnapshot> trendingAnime({
    required int limit,
    required int offset,
  });

  Future<HomeRecommendationSnapshot> recentPopularAnime({
    required int limit,
    required int offset,
    HomeRecommendationCategory category = HomeRecommendationCategory.popular,
  });
}
