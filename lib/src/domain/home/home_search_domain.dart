enum HomeSearchLoadStatus {
  loaded,
  failed,
}

const int homeSearchMinimumQueryLength = 2;
const int homeSearchSuggestionLimit = 10;
const Duration homeSearchDebounceDuration = Duration(milliseconds: 300);

final class HomeSearchSnapshot {
  HomeSearchSnapshot.loaded(Iterable<HomeSearchItem> items)
      : status = HomeSearchLoadStatus.loaded,
        message = null,
        items = List<HomeSearchItem>.unmodifiable(items);

  const HomeSearchSnapshot.failed(String this.message)
      : status = HomeSearchLoadStatus.failed,
        items = const <HomeSearchItem>[];

  final HomeSearchLoadStatus status;
  final String? message;
  final List<HomeSearchItem> items;
}

final class HomeSearchItem {
  const HomeSearchItem({
    required this.subjectId,
    required this.title,
    this.summary,
    this.coverUri,
    this.rank,
    this.score,
    this.collectionTotal,
    this.episodeCount,
  })  : assert(subjectId != '', 'Search subject id must not be empty.'),
        assert(title != '', 'Search title must not be empty.'),
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

  String get metadataSentence {
    final List<String> parts = <String>[];
    final double? valueScore = score;
    if (valueScore != null) {
      parts.add('评分 ${valueScore.toStringAsFixed(1)}');
    }
    final int? valueCollectionTotal = collectionTotal;
    if (valueCollectionTotal != null) {
      parts.add('$valueCollectionTotal 人收藏');
    }
    final int? valueEpisodeCount = episodeCount;
    if (valueEpisodeCount != null && valueEpisodeCount > 0) {
      parts.add('$valueEpisodeCount 话');
    }
    return parts.join(' · ');
  }
}

abstract interface class HomeSearchProvider {
  Future<HomeSearchSnapshot> searchAnime(String query);
}
