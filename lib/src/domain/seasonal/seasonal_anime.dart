import 'dart:async';

import '../../foundation/baseline_defaults.dart';
import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/provider_result.dart';
import '../../provider/rss/feed_contracts.dart';
import '../media/media_library.dart';
import '../rss/rss_engine.dart';

const double defaultAutomaticBangumiMatchMinimumConfidence = 0.8;
const double exactBangumiTitleMatchConfidence = 1.0;
const double partialBangumiTitleMatchConfidence = 0.6;
const String defaultSeasonalCatalogEntryIdPrefix = 'seasonal-entry';

enum AnimeSeasonKind {
  winter,
  spring,
  summer,
  fall,
}

final class AnimeSeason {
  const AnimeSeason({required this.year, required this.kind})
      : assert(year >= 1900, 'year is out of range.');

  final int year;
  final AnimeSeasonKind kind;
}

final class SeasonalCatalogEntryId {
  const SeasonalCatalogEntryId(this.value)
      : assert(value != '', 'Seasonal catalog entry id must not be empty.');

  final String value;
}

final class SeasonalFeedSourceId {
  const SeasonalFeedSourceId(this.value)
      : assert(value != '', 'Seasonal feed source id must not be empty.');

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
  const SeasonalCatalog(
      {required this.season, required this.entries, required this.updatedAt});

  final AnimeSeason season;
  final List<SeasonalCatalogEntry> entries;
  final DateTime updatedAt;
}

SeasonalSourceItem seasonalSourceItemFromFeedItem(FeedItem item) {
  return SeasonalSourceItem(
    id: item.id.value,
    sourceId: SeasonalFeedSourceId(item.sourceId.value),
    title: item.title,
    link: item.link,
    publishedAt: item.publishedAt,
    summary: item.summary,
  );
}

StoredSeasonalCatalogEntryRecord storedRecordFromSeasonalEntry(
    SeasonalCatalogEntry entry,
    {required DateTime updatedAt}) {
  return StoredSeasonalCatalogEntryRecord(
    id: entry.id.value,
    seasonYear: entry.season.year,
    seasonKind: entry.season.kind.name,
    title: entry.title,
    sourceId: entry.sourceItem.sourceId.value,
    sourceItemId: entry.sourceItem.id,
    link: entry.sourceItem.link,
    summary: entry.summary,
    officialUri: entry.officialUri,
    publishedAt: entry.publishedAt,
    updatedAt: updatedAt,
  );
}

SeasonalCatalogEntry seasonalEntryFromStoredRecord(
    StoredSeasonalCatalogEntryRecord record) {
  return SeasonalCatalogEntry(
    id: SeasonalCatalogEntryId(record.id),
    season: AnimeSeason(
      year: record.seasonYear,
      kind: _seasonKindFromName(record.seasonKind),
    ),
    title: record.title,
    sourceItem: SeasonalSourceItem(
      id: record.sourceItemId,
      sourceId: SeasonalFeedSourceId(record.sourceId),
      title: record.title,
      link: record.link,
      publishedAt: record.publishedAt,
      summary: record.summary,
    ),
    summary: record.summary,
    officialUri: record.officialUri,
    publishedAt: record.publishedAt,
  );
}

AnimeSeasonKind _seasonKindFromName(String name) {
  return switch (name) {
    'winter' => AnimeSeasonKind.winter,
    'spring' => AnimeSeasonKind.spring,
    'summer' => AnimeSeasonKind.summer,
    'fall' => AnimeSeasonKind.fall,
    _ => AnimeSeasonKind.winter,
  };
}

abstract interface class SeasonalAnimeConsumer {
  bool accepts(SeasonalFeedSourceId sourceId);

  Future<List<SeasonalCatalogEntry>> consume(
      SeasonalFeedSourceId sourceId, Iterable<SeasonalSourceItem> items);
}

final class FeedItemSeasonalAnimeConsumer implements SeasonalAnimeConsumer {
  const FeedItemSeasonalAnimeConsumer({
    required this.sourceId,
    required this.season,
    this.catalogEntryIdPrefix = defaultSeasonalCatalogEntryIdPrefix,
  }) : assert(
          catalogEntryIdPrefix != '',
          'Catalog entry id prefix must not be empty.',
        );

  final SeasonalFeedSourceId sourceId;
  final AnimeSeason season;
  final String catalogEntryIdPrefix;

  @override
  bool accepts(SeasonalFeedSourceId sourceId) =>
      sourceId.value == this.sourceId.value;

  @override
  Future<List<SeasonalCatalogEntry>> consume(
    SeasonalFeedSourceId sourceId,
    Iterable<SeasonalSourceItem> items,
  ) {
    if (!accepts(sourceId)) {
      return Future<List<SeasonalCatalogEntry>>.value(
        const <SeasonalCatalogEntry>[],
      );
    }
    return Future<List<SeasonalCatalogEntry>>.value(
      <SeasonalCatalogEntry>[
        for (final SeasonalSourceItem item in items)
          SeasonalCatalogEntry(
            id: SeasonalCatalogEntryId('$catalogEntryIdPrefix-${item.id}'),
            season: season,
            title: item.title,
            sourceItem: item,
            summary: item.summary,
            officialUri: item.link,
            publishedAt: item.publishedAt,
          ),
      ],
    );
  }
}

final class BangumiMatchQueueItemId {
  const BangumiMatchQueueItemId(this.value)
      : assert(value != '', 'Bangumi match queue item id must not be empty.');

  final String value;
}

final class BangumiMatchCandidate {
  const BangumiMatchCandidate({
    required this.subjectId,
    required this.title,
    required this.confidence,
  })  : assert(title != '', 'Bangumi match candidate title must not be empty.'),
        assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final ProviderSubjectId subjectId;
  final String title;
  final double confidence;
}

final class BangumiMatchQueueItem {
  const BangumiMatchQueueItem({
    required this.id,
    required this.entry,
    required this.candidates,
    this.localMediaId,
    this.existingBinding,
  });

  final BangumiMatchQueueItemId id;
  final SeasonalCatalogEntry entry;
  final List<BangumiMatchCandidate> candidates;
  final LocalMediaId? localMediaId;
  final ProviderBinding? existingBinding;

  bool get mayApplyAutomatically =>
      existingBinding?.authority != ProviderBindingAuthority.userConfirmed;
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

  Future<AutomaticBangumiMatchResult> applyAutomaticMatch(
      BangumiMatchQueueItemId id, BangumiMatchCandidate candidate);
}

abstract interface class SeasonalIndexerContract {
  Stream<SeasonalCatalogEntry> get catalogUpdates;

  Future<void> startListening();

  Future<void> stopListening();

  Future<List<SeasonalCatalogEntry>> processFeedItem(FeedItem item);
}

final class DeterministicSeasonalIndexer implements SeasonalIndexerContract {
  DeterministicSeasonalIndexer({
    required this.rssEngine,
    required this.consumers,
    required this.catalogStore,
    required this.matchQueueStore,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _clock = clock ?? _defaultClock,
        _catalogUpdates =
            StreamController<SeasonalCatalogEntry>.broadcast(sync: true);

  final RssEngineContract rssEngine;
  final List<SeasonalAnimeConsumer> consumers;
  final SeasonalCatalogStore catalogStore;
  final BangumiMatchQueueStore matchQueueStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;
  final StreamController<SeasonalCatalogEntry> _catalogUpdates;
  StreamSubscription<FeedItem>? _subscription;

  @override
  Stream<SeasonalCatalogEntry> get catalogUpdates => _catalogUpdates.stream;

  @override
  Future<List<SeasonalCatalogEntry>> processFeedItem(FeedItem item) async {
    final SeasonalSourceItem sourceItem = seasonalSourceItemFromFeedItem(item);
    final List<SeasonalCatalogEntry> accepted = <SeasonalCatalogEntry>[];
    for (final SeasonalAnimeConsumer consumer in consumers) {
      if (!consumer.accepts(sourceItem.sourceId)) {
        continue;
      }
      final List<SeasonalCatalogEntry> entries = await consumer
          .consume(sourceItem.sourceId, <SeasonalSourceItem>[sourceItem]);
      for (final SeasonalCatalogEntry entry in entries) {
        final StoredSeasonalCatalogEntryRecord? existing =
            await catalogStore.findBySourceItem(
          sourceId: entry.sourceItem.sourceId.value,
          sourceItemId: entry.sourceItem.id,
        );
        if (existing != null) {
          continue;
        }
        await catalogStore
            .store(storedRecordFromSeasonalEntry(entry, updatedAt: _clock()));
        await _enqueueMatch(entry);
        accepted.add(entry);
        _catalogUpdates.add(entry);
        cacheInvalidationBus?.publish(
          SeasonalCatalogUpdated(
            occurredAt: _clock(),
            seasonalCatalogEntryId: entry.id.value,
            seasonYear: entry.season.year,
            seasonKind: entry.season.kind.name,
          ),
        );
      }
    }
    return accepted;
  }

  @override
  Future<void> startListening() {
    _subscription ??= rssEngine.updates.listen((FeedItem item) {
      unawaited(processFeedItem(item));
    });
    return Future<void>.value();
  }

  @override
  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> close() async {
    await stopListening();
    await _catalogUpdates.close();
  }

  Future<void> _enqueueMatch(SeasonalCatalogEntry entry) async {
    final String queueItemId = 'match-${entry.id.value}';
    final StoredBangumiMatchQueueItemRecord? existingQueueItem =
        await matchQueueStore.findByCatalogEntryId(entry.id.value);
    if (existingQueueItem != null) {
      return;
    }
    await matchQueueStore.enqueue(
      StoredBangumiMatchQueueItemRecord(
        id: queueItemId,
        seasonalCatalogEntryId: entry.id.value,
        localMediaId: entry.id.value,
        title: entry.title,
        status: StoredBangumiMatchQueueStatus.pending,
        enqueuedAt: _clock(),
      ),
    );
    cacheInvalidationBus?.publish(
      BangumiMatchEnqueued(
        occurredAt: _clock(),
        queueItemId: queueItemId,
        seasonalCatalogEntryId: entry.id.value,
      ),
    );
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

abstract interface class BangumiMatchWorkerContract {
  Future<BangumiMatchWorkerResult> processNext();

  Future<int> pendingCount();
}

final class BangumiMatchWorkerResult {
  const BangumiMatchWorkerResult._({
    this.queueItemId,
    this.candidates = const <BangumiMatchCandidate>[],
    this.matchResult,
    this.failure,
    this.empty = false,
  });

  const BangumiMatchWorkerResult.empty() : this._(empty: true);

  const BangumiMatchWorkerResult.processed({
    required BangumiMatchQueueItemId queueItemId,
    required List<BangumiMatchCandidate> candidates,
    required AutomaticBangumiMatchResult matchResult,
  }) : this._(
          queueItemId: queueItemId,
          candidates: candidates,
          matchResult: matchResult,
        );

  BangumiMatchWorkerResult.failed({
    required BangumiMatchQueueItemId queueItemId,
    required AcgProviderFailureKind kind,
    required String message,
  }) : this._(
          queueItemId: queueItemId,
          failure: RssRefreshFailure(kind: kind, message: message),
        );

  final BangumiMatchQueueItemId? queueItemId;
  final List<BangumiMatchCandidate> candidates;
  final AutomaticBangumiMatchResult? matchResult;
  final RssRefreshFailure? failure;
  final bool empty;

  bool get isSuccess => failure == null && !empty;
}

final class DeterministicBangumiMatchQueue implements BangumiMatchQueue {
  DeterministicBangumiMatchQueue({
    required this.store,
    required this.bindingStore,
    DateTime Function()? clock,
    this.minimumConfidence = defaultAutomaticBangumiMatchMinimumConfidence,
  }) : _clock = clock ?? _defaultClock;

  final BangumiMatchQueueStore store;
  final ProviderBindingStore bindingStore;
  final double minimumConfidence;
  final DateTime Function() _clock;

  @override
  Future<AutomaticBangumiMatchResult> applyAutomaticMatch(
      BangumiMatchQueueItemId id, BangumiMatchCandidate candidate) async {
    final StoredBangumiMatchQueueItemRecord? record =
        await store.findById(id.value);
    if (record == null) {
      return const AutomaticBangumiMatchResult(
          outcome: AutomaticBangumiMatchOutcome.rejectedLowConfidence);
    }
    final LocalMediaId mediaId = LocalMediaId(record.localMediaId);
    final ProviderBinding? existing = await bindingStore.bindingFor(mediaId);
    if (existing?.authority == ProviderBindingAuthority.userConfirmed) {
      await store.updateStatus(
          queueItemId: id.value,
          status: StoredBangumiMatchQueueStatus.skippedUserConfirmedBinding);
      return AutomaticBangumiMatchResult(
          outcome: AutomaticBangumiMatchOutcome.skippedUserConfirmedBinding,
          binding: existing);
    }
    if (candidate.confidence < minimumConfidence) {
      await store.updateStatus(
          queueItemId: id.value,
          status: StoredBangumiMatchQueueStatus.rejectedLowConfidence);
      return const AutomaticBangumiMatchResult(
          outcome: AutomaticBangumiMatchOutcome.rejectedLowConfidence);
    }
    final ProviderBinding binding = ProviderBinding(
      id: ProviderBindingId('auto-${id.value}'),
      localMediaId: mediaId,
      providerId: bangumiProviderBindingProviderId,
      subjectId: candidate.subjectId,
      authority: ProviderBindingAuthority.automatic,
      confidence: candidate.confidence,
      createdAt: _clock(),
    );
    final ProviderBinding saved =
        await bindingStore.saveAutomaticIfAllowed(binding);
    await store.updateStatus(
        queueItemId: id.value, status: StoredBangumiMatchQueueStatus.applied);
    return AutomaticBangumiMatchResult(
        outcome: saved == binding
            ? AutomaticBangumiMatchOutcome.applied
            : AutomaticBangumiMatchOutcome.skippedUserConfirmedBinding,
        binding: saved);
  }

  @override
  Future<void> enqueue(BangumiMatchQueueItem item) {
    return store.enqueue(_recordFromQueueItem(item, _clock()));
  }

  @override
  Future<BangumiMatchQueueItem?> next() async {
    final StoredBangumiMatchQueueItemRecord? record = await store.nextPending();
    if (record == null) {
      return null;
    }
    return _queueItemFromRecord(record);
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

final class DeterministicBangumiMatchWorker
    implements BangumiMatchWorkerContract {
  DeterministicBangumiMatchWorker({
    required this.queueStore,
    required this.bindingStore,
    required this.bangumiProvider,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
    this.minimumConfidence = defaultAutomaticBangumiMatchMinimumConfidence,
  })  : _clock = clock ?? _defaultClock,
        _queue = DeterministicBangumiMatchQueue(
          store: queueStore,
          bindingStore: bindingStore,
          clock: clock,
          minimumConfidence: minimumConfidence,
        );

  final BangumiMatchQueueStore queueStore;
  final ProviderBindingStore bindingStore;
  final BangumiProvider bangumiProvider;
  final CacheInvalidationBus? cacheInvalidationBus;
  final double minimumConfidence;
  final DateTime Function() _clock;
  final DeterministicBangumiMatchQueue _queue;

  @override
  Future<int> pendingCount() => queueStore.pendingCount();

  @override
  Future<BangumiMatchWorkerResult> processNext() async {
    final StoredBangumiMatchQueueItemRecord? record =
        await queueStore.nextPending();
    if (record == null) {
      return const BangumiMatchWorkerResult.empty();
    }
    final AcgProviderResult<List<BangumiSubject>> searchResult =
        await bangumiProvider.searchSubjects(record.title);
    switch (searchResult) {
      case AcgProviderFailure<List<BangumiSubject>>(
          :final kind,
          :final message
        ):
        await queueStore.updateStatus(
            queueItemId: record.id,
            status: StoredBangumiMatchQueueStatus.failed,
            failureMessage: message);
        return BangumiMatchWorkerResult.failed(
            queueItemId: BangumiMatchQueueItemId(record.id),
            kind: kind,
            message: message);
      case AcgProviderSuccess<List<BangumiSubject>>(:final value):
        final List<BangumiMatchCandidate> candidates = <BangumiMatchCandidate>[
          for (final BangumiSubject subject in value)
            BangumiMatchCandidate(
              subjectId: ProviderSubjectId(subject.id.value),
              title: subject.title,
              confidence: _confidenceFor(record.title, subject.title),
            ),
        ];
        await queueStore.storeCandidates(
          queueItemId: record.id,
          candidates: <StoredBangumiMatchCandidateRecord>[
            for (final BangumiMatchCandidate candidate in candidates)
              StoredBangumiMatchCandidateRecord(
                subjectId: candidate.subjectId.value,
                title: candidate.title,
                confidence: candidate.confidence,
              ),
          ],
        );
        final BangumiMatchCandidate? best = _bestCandidate(candidates);
        final AutomaticBangumiMatchResult matchResult = best == null
            ? const AutomaticBangumiMatchResult(
                outcome: AutomaticBangumiMatchOutcome.rejectedLowConfidence)
            : await _queue.applyAutomaticMatch(
                BangumiMatchQueueItemId(record.id), best);
        if (best == null) {
          await queueStore.updateStatus(
              queueItemId: record.id,
              status: StoredBangumiMatchQueueStatus.rejectedLowConfidence);
        }
        if (matchResult.outcome == AutomaticBangumiMatchOutcome.applied &&
            matchResult.binding != null) {
          cacheInvalidationBus?.publish(
            BangumiMatchApplied(
              occurredAt: _clock(),
              queueItemId: record.id,
              bindingId: matchResult.binding!.id.value,
              localMediaId: matchResult.binding!.localMediaId.value,
              providerSubjectId: matchResult.binding!.subjectId?.value ?? '',
            ),
          );
        }
        return BangumiMatchWorkerResult.processed(
          queueItemId: BangumiMatchQueueItemId(record.id),
          candidates: candidates,
          matchResult: matchResult,
        );
    }
  }

  BangumiMatchCandidate? _bestCandidate(
      List<BangumiMatchCandidate> candidates) {
    BangumiMatchCandidate? best;
    for (final BangumiMatchCandidate candidate in candidates) {
      if (candidate.confidence < minimumConfidence) {
        continue;
      }
      if (best == null || candidate.confidence > best.confidence) {
        best = candidate;
      }
    }
    return best;
  }

  static double _confidenceFor(String query, String title) {
    return query.trim().toLowerCase() == title.trim().toLowerCase()
        ? exactBangumiTitleMatchConfidence
        : partialBangumiTitleMatchConfidence;
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

StoredBangumiMatchQueueItemRecord _recordFromQueueItem(
    BangumiMatchQueueItem item, DateTime enqueuedAt) {
  return StoredBangumiMatchQueueItemRecord(
    id: item.id.value,
    seasonalCatalogEntryId: item.entry.id.value,
    localMediaId:
        (item.localMediaId ?? LocalMediaId(item.entry.id.value)).value,
    title: item.entry.title,
    status: StoredBangumiMatchQueueStatus.pending,
    enqueuedAt: enqueuedAt,
    existingBindingId: item.existingBinding?.id.value,
    candidates: <StoredBangumiMatchCandidateRecord>[
      for (final BangumiMatchCandidate candidate in item.candidates)
        StoredBangumiMatchCandidateRecord(
          subjectId: candidate.subjectId.value,
          title: candidate.title,
          confidence: candidate.confidence,
        ),
    ],
  );
}

BangumiMatchQueueItem _queueItemFromRecord(
    StoredBangumiMatchQueueItemRecord record) {
  final SeasonalCatalogEntry entry = SeasonalCatalogEntry(
    id: SeasonalCatalogEntryId(record.seasonalCatalogEntryId),
    season: const AnimeSeason(year: 2026, kind: AnimeSeasonKind.winter),
    title: record.title,
    sourceItem: SeasonalSourceItem(
      id: record.seasonalCatalogEntryId,
      sourceId: const SeasonalFeedSourceId('stored-match-queue'),
      title: record.title,
    ),
  );
  return BangumiMatchQueueItem(
    id: BangumiMatchQueueItemId(record.id),
    entry: entry,
    localMediaId: LocalMediaId(record.localMediaId),
    candidates: <BangumiMatchCandidate>[
      for (final StoredBangumiMatchCandidateRecord candidate
          in record.candidates)
        BangumiMatchCandidate(
          subjectId: ProviderSubjectId(candidate.subjectId),
          title: candidate.title,
          confidence: candidate.confidence,
        ),
    ],
  );
}
