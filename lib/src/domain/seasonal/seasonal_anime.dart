import '../media/media_library.dart';

enum AnimeSeasonKind {
  winter,
  spring,
  summer,
  fall,
}

final class AnimeSeason {
  const AnimeSeason({required this.year, required this.kind}) : assert(year >= 1900, 'year is out of range.');

  final int year;
  final AnimeSeasonKind kind;
}

final class SeasonalCatalogEntryId {
  const SeasonalCatalogEntryId(this.value) : assert(value != '', 'Seasonal catalog entry id must not be empty.');

  final String value;
}

final class SeasonalFeedSourceId {
  const SeasonalFeedSourceId(this.value) : assert(value != '', 'Seasonal feed source id must not be empty.');

  final String value;
}

final class SeasonalSourceItem {
  const SeasonalSourceItem({
    required this.id,
    required this.sourceId,
    required this.title,
    this.link,
    this.publishedAt,
    this.summary,
  })  : assert(id != '', 'Seasonal source item id must not be empty.'),
        assert(title != '', 'Seasonal source item title must not be empty.');

  final String id;
  final SeasonalFeedSourceId sourceId;
  final String title;
  final Uri? link;
  final DateTime? publishedAt;
  final String? summary;
}

final class SeasonalCatalogEntry {
  const SeasonalCatalogEntry({
    required this.id,
    required this.season,
    required this.title,
    required this.sourceItem,
    this.summary,
    this.officialUri,
    this.publishedAt,
  }) : assert(title != '', 'Seasonal catalog title must not be empty.');

  final SeasonalCatalogEntryId id;
  final AnimeSeason season;
  final String title;
  final SeasonalSourceItem sourceItem;
  final String? summary;
  final Uri? officialUri;
  final DateTime? publishedAt;
}

final class SeasonalCatalog {
  const SeasonalCatalog({required this.season, required this.entries, required this.updatedAt});

  final AnimeSeason season;
  final List<SeasonalCatalogEntry> entries;
  final DateTime updatedAt;
}

abstract interface class SeasonalAnimeConsumer {
  bool accepts(SeasonalFeedSourceId sourceId);

  Future<List<SeasonalCatalogEntry>> consume(SeasonalFeedSourceId sourceId, Iterable<SeasonalSourceItem> items);
}

final class BangumiMatchQueueItemId {
  const BangumiMatchQueueItemId(this.value) : assert(value != '', 'Bangumi match queue item id must not be empty.');

  final String value;
}

final class BangumiMatchCandidate {
  const BangumiMatchCandidate({
    required this.subjectId,
    required this.title,
    required this.confidence,
  })  : assert(title != '', 'Bangumi match candidate title must not be empty.'),
        assert(confidence >= 0 && confidence <= 1, 'confidence must be between 0 and 1.');

  final ProviderSubjectId subjectId;
  final String title;
  final double confidence;
}

final class BangumiMatchQueueItem {
  const BangumiMatchQueueItem({
    required this.id,
    required this.entry,
    required this.candidates,
    this.existingBinding,
  });

  final BangumiMatchQueueItemId id;
  final SeasonalCatalogEntry entry;
  final List<BangumiMatchCandidate> candidates;
  final ProviderBinding? existingBinding;

  bool get mayApplyAutomatically => existingBinding?.authority != ProviderBindingAuthority.userConfirmed;
}

enum AutomaticBangumiMatchOutcome {
  applied,
  skippedUserConfirmedBinding,
  rejectedLowConfidence,
}

final class AutomaticBangumiMatchResult {
  const AutomaticBangumiMatchResult({required this.outcome, this.binding});

  final AutomaticBangumiMatchOutcome outcome;
  final ProviderBinding? binding;
}

abstract interface class BangumiMatchQueue {
  Future<void> enqueue(BangumiMatchQueueItem item);

  Future<BangumiMatchQueueItem?> next();

  Future<AutomaticBangumiMatchResult> applyAutomaticMatch(BangumiMatchQueueItemId id, BangumiMatchCandidate candidate);
}
