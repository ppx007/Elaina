import '../baseline_defaults.dart';

final class StoredSeasonalCatalogEntryRecord {
  const StoredSeasonalCatalogEntryRecord({
    required this.id,
    required this.seasonYear,
    required this.seasonKind,
    required this.title,
    required this.sourceId,
    required this.sourceItemId,
    required this.updatedAt,
    this.link,
    this.summary,
    this.officialUri,
    this.publishedAt,
  })  : assert(id != '', 'Seasonal catalog entry id must not be empty.'),
        assert(seasonYear >= 1900, 'seasonYear is out of range.'),
        assert(seasonKind != '', 'Season kind must not be empty.'),
        assert(title != '', 'Seasonal catalog entry title must not be empty.'),
        assert(sourceId != '', 'Seasonal source id must not be empty.'),
        assert(
            sourceItemId != '', 'Seasonal source item id must not be empty.');

  final String id;
  final int seasonYear;
  final String seasonKind;
  final String title;
  final String sourceId;
  final String sourceItemId;
  final Uri? link;
  final String? summary;
  final Uri? officialUri;
  final DateTime? publishedAt;
  final DateTime updatedAt;
}

abstract interface class SeasonalCatalogStore {
  Future<StoredSeasonalCatalogEntryRecord> store(
      StoredSeasonalCatalogEntryRecord entry);

  Future<StoredSeasonalCatalogEntryRecord?> findById(String id);

  Future<StoredSeasonalCatalogEntryRecord?> findBySourceItem(
      {required String sourceId, required String sourceItemId});

  Future<List<StoredSeasonalCatalogEntryRecord>> entriesForSeason(
      {required int year, required String kind});

  Future<List<StoredSeasonalCatalogEntryRecord>> list(
      {int offset = 0, int limit = defaultListPageLimit});

  Future<bool> remove(String id);

  Future<int> count();
}

final class DeterministicSeasonalCatalogStore implements SeasonalCatalogStore {
  DeterministicSeasonalCatalogStore(
      {Iterable<StoredSeasonalCatalogEntryRecord> seedEntries =
          const <StoredSeasonalCatalogEntryRecord>[]}) {
    for (final StoredSeasonalCatalogEntryRecord entry in seedEntries) {
      _entriesById[entry.id] = entry;
    }
  }

  final Map<String, StoredSeasonalCatalogEntryRecord> _entriesById =
      <String, StoredSeasonalCatalogEntryRecord>{};

  @override
  Future<int> count() => Future<int>.value(_entriesById.length);

  @override
  Future<List<StoredSeasonalCatalogEntryRecord>> entriesForSeason(
      {required int year, required String kind}) {
    return Future<List<StoredSeasonalCatalogEntryRecord>>.value(
      <StoredSeasonalCatalogEntryRecord>[
        for (final StoredSeasonalCatalogEntryRecord entry
            in _entriesById.values)
          if (entry.seasonYear == year && entry.seasonKind == kind) entry,
      ],
    );
  }

  @override
  Future<StoredSeasonalCatalogEntryRecord?> findById(String id) {
    return Future<StoredSeasonalCatalogEntryRecord?>.value(_entriesById[id]);
  }

  @override
  Future<StoredSeasonalCatalogEntryRecord?> findBySourceItem(
      {required String sourceId, required String sourceItemId}) {
    for (final StoredSeasonalCatalogEntryRecord entry in _entriesById.values) {
      if (entry.sourceId == sourceId && entry.sourceItemId == sourceItemId) {
        return Future<StoredSeasonalCatalogEntryRecord?>.value(entry);
      }
    }
    return Future<StoredSeasonalCatalogEntryRecord?>.value();
  }

  @override
  Future<List<StoredSeasonalCatalogEntryRecord>> list(
      {int offset = 0, int limit = defaultListPageLimit}) {
    assert(offset >= 0, 'offset must not be negative.');
    assert(limit > 0, 'limit must be positive.');
    final List<StoredSeasonalCatalogEntryRecord> entries =
        <StoredSeasonalCatalogEntryRecord>[..._entriesById.values];
    final int start = offset > entries.length ? entries.length : offset;
    final int end =
        start + limit > entries.length ? entries.length : start + limit;
    return Future<List<StoredSeasonalCatalogEntryRecord>>.value(
        entries.sublist(start, end));
  }

  @override
  Future<bool> remove(String id) {
    return Future<bool>.value(_entriesById.remove(id) != null);
  }

  @override
  Future<StoredSeasonalCatalogEntryRecord> store(
      StoredSeasonalCatalogEntryRecord entry) {
    _entriesById[entry.id] = entry;
    return Future<StoredSeasonalCatalogEntryRecord>.value(entry);
  }
}

enum StoredBangumiMatchQueueStatus {
  pending,
  candidatesStored,
  applied,
  skippedUserConfirmedBinding,
  rejectedLowConfidence,
  failed,
}

final class StoredBangumiMatchCandidateRecord {
  const StoredBangumiMatchCandidateRecord({
    required this.subjectId,
    required this.title,
    required this.confidence,
  })  : assert(subjectId != '', 'Bangumi subject id must not be empty.'),
        assert(title != '', 'Bangumi match candidate title must not be empty.'),
        assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final String subjectId;
  final String title;
  final double confidence;
}

final class StoredBangumiMatchQueueItemRecord {
  const StoredBangumiMatchQueueItemRecord({
    required this.id,
    required this.seasonalCatalogEntryId,
    required this.localMediaId,
    required this.title,
    required this.status,
    required this.enqueuedAt,
    this.existingBindingId,
    this.candidates = const <StoredBangumiMatchCandidateRecord>[],
    this.failureMessage,
  })  : assert(id != '', 'Bangumi match queue item id must not be empty.'),
        assert(seasonalCatalogEntryId != '',
            'Seasonal catalog entry id must not be empty.'),
        assert(localMediaId != '', 'Local media id must not be empty.'),
        assert(title != '', 'Bangumi match queue title must not be empty.');

  final String id;
  final String seasonalCatalogEntryId;
  final String localMediaId;
  final String title;
  final StoredBangumiMatchQueueStatus status;
  final DateTime enqueuedAt;
  final String? existingBindingId;
  final List<StoredBangumiMatchCandidateRecord> candidates;
  final String? failureMessage;

  StoredBangumiMatchQueueItemRecord copyWith({
    StoredBangumiMatchQueueStatus? status,
    String? existingBindingId,
    List<StoredBangumiMatchCandidateRecord>? candidates,
    String? failureMessage,
  }) {
    return StoredBangumiMatchQueueItemRecord(
      id: id,
      seasonalCatalogEntryId: seasonalCatalogEntryId,
      localMediaId: localMediaId,
      title: title,
      status: status ?? this.status,
      enqueuedAt: enqueuedAt,
      existingBindingId: existingBindingId ?? this.existingBindingId,
      candidates: candidates ?? this.candidates,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }
}

abstract interface class BangumiMatchQueueStore {
  Future<void> enqueue(StoredBangumiMatchQueueItemRecord item);

  Future<StoredBangumiMatchQueueItemRecord?> findById(String id);

  Future<StoredBangumiMatchQueueItemRecord?> findByCatalogEntryId(
      String seasonalCatalogEntryId);

  Future<StoredBangumiMatchQueueItemRecord?> nextPending();

  Future<void> storeCandidates(
      {required String queueItemId,
      required Iterable<StoredBangumiMatchCandidateRecord> candidates});

  Future<List<StoredBangumiMatchCandidateRecord>> candidatesFor(
      String queueItemId);

  Future<void> updateStatus(
      {required String queueItemId,
      required StoredBangumiMatchQueueStatus status,
      String? failureMessage});

  Future<int> pendingCount();
}

final class DeterministicBangumiMatchQueueStore
    implements BangumiMatchQueueStore {
  DeterministicBangumiMatchQueueStore(
      {Iterable<StoredBangumiMatchQueueItemRecord> seedItems =
          const <StoredBangumiMatchQueueItemRecord>[]}) {
    for (final StoredBangumiMatchQueueItemRecord item in seedItems) {
      _itemsById[item.id] = item;
    }
  }

  final Map<String, StoredBangumiMatchQueueItemRecord> _itemsById =
      <String, StoredBangumiMatchQueueItemRecord>{};

  @override
  Future<List<StoredBangumiMatchCandidateRecord>> candidatesFor(
      String queueItemId) {
    return Future<List<StoredBangumiMatchCandidateRecord>>.value(
        _itemsById[queueItemId]?.candidates ??
            const <StoredBangumiMatchCandidateRecord>[]);
  }

  @override
  Future<void> enqueue(StoredBangumiMatchQueueItemRecord item) {
    _itemsById.putIfAbsent(item.id, () => item);
    return Future<void>.value();
  }

  @override
  Future<StoredBangumiMatchQueueItemRecord?> findByCatalogEntryId(
      String seasonalCatalogEntryId) {
    for (final StoredBangumiMatchQueueItemRecord item in _itemsById.values) {
      if (item.seasonalCatalogEntryId == seasonalCatalogEntryId) {
        return Future<StoredBangumiMatchQueueItemRecord?>.value(item);
      }
    }
    return Future<StoredBangumiMatchQueueItemRecord?>.value();
  }

  @override
  Future<StoredBangumiMatchQueueItemRecord?> findById(String id) {
    return Future<StoredBangumiMatchQueueItemRecord?>.value(_itemsById[id]);
  }

  @override
  Future<StoredBangumiMatchQueueItemRecord?> nextPending() {
    for (final StoredBangumiMatchQueueItemRecord item in _itemsById.values) {
      if (item.status == StoredBangumiMatchQueueStatus.pending) {
        return Future<StoredBangumiMatchQueueItemRecord?>.value(item);
      }
    }
    return Future<StoredBangumiMatchQueueItemRecord?>.value();
  }

  @override
  Future<int> pendingCount() {
    return Future<int>.value(
      _itemsById.values
          .where((StoredBangumiMatchQueueItemRecord item) =>
              item.status == StoredBangumiMatchQueueStatus.pending)
          .length,
    );
  }

  @override
  Future<void> storeCandidates(
      {required String queueItemId,
      required Iterable<StoredBangumiMatchCandidateRecord> candidates}) {
    final StoredBangumiMatchQueueItemRecord? item = _itemsById[queueItemId];
    if (item != null) {
      _itemsById[queueItemId] = item.copyWith(
        status: StoredBangumiMatchQueueStatus.candidatesStored,
        candidates: <StoredBangumiMatchCandidateRecord>[...candidates],
      );
    }
    return Future<void>.value();
  }

  @override
  Future<void> updateStatus(
      {required String queueItemId,
      required StoredBangumiMatchQueueStatus status,
      String? failureMessage}) {
    final StoredBangumiMatchQueueItemRecord? item = _itemsById[queueItemId];
    if (item != null) {
      _itemsById[queueItemId] =
          item.copyWith(status: status, failureMessage: failureMessage);
    }
    return Future<void>.value();
  }
}
