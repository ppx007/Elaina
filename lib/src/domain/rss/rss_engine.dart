import 'dart:async';

import '../../foundation/baseline_defaults.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../../provider/provider_result.dart';
import '../../provider/rss/feed_contracts.dart';

final class RssRefreshRequest {
  const RssRefreshRequest({required this.sourceId});

  final FeedSourceId sourceId;
}

final class RssRefreshFailure {
  const RssRefreshFailure({required this.kind, required this.message})
      : assert(message != '', 'RSS refresh failure message must not be empty.');

  final AcgProviderFailureKind kind;
  final String message;
}

final class RssRefreshOutcome {
  const RssRefreshOutcome._(
      {required this.sourceId,
      required this.newItems,
      required this.warnings,
      this.failure});

  const RssRefreshOutcome.success(
      {required FeedSourceId sourceId,
      required List<FeedItem> newItems,
      List<String> warnings = const <String>[]})
      : this._(sourceId: sourceId, newItems: newItems, warnings: warnings);

  const RssRefreshOutcome.failure(
      {required FeedSourceId sourceId,
      required RssRefreshFailure failure,
      List<String> warnings = const <String>[]})
      : this._(
            sourceId: sourceId,
            newItems: const <FeedItem>[],
            warnings: warnings,
            failure: failure);

  final FeedSourceId sourceId;
  final List<FeedItem> newItems;
  final List<String> warnings;
  final RssRefreshFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class RssEngineContract {
  Future<void> registerSource(FeedSource source);

  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request);

  Stream<FeedItem> get updates;
}

final class DeterministicRssEngine implements RssEngineContract, FeedEngine {
  DeterministicRssEngine({
    required this.store,
    required this.fetcher,
    required this.parser,
    required this.deduplicator,
    DateTime Function()? clock,
  })  : _clock = clock ?? _defaultClock,
        _updates = StreamController<FeedItem>.broadcast(sync: true);

  final RssFeedStore store;
  final FeedFetcher fetcher;
  final FeedParser parser;
  final FeedDeduplicator deduplicator;
  final DateTime Function() _clock;
  final StreamController<FeedItem> _updates;

  @override
  Stream<FeedItem> get updates => _updates.stream;

  @override
  Future<void> registerSource(FeedSource source) {
    return store
        .storeSource(_sourceRecordFromFeedSource(source))
        .then((StoredFeedSourceRecord _) {});
  }

  @override
  Future<AcgProviderResult<FeedRefreshResult>> refresh(
      FeedSourceId sourceId) async {
    final RssRefreshOutcome outcome =
        await refreshSource(RssRefreshRequest(sourceId: sourceId));
    if (outcome.isSuccess) {
      return AcgProviderSuccess<FeedRefreshResult>(
        FeedRefreshResult(
            sourceId: outcome.sourceId,
            newItems: outcome.newItems,
            warnings: outcome.warnings),
      );
    }
    final RssRefreshFailure failure = outcome.failure!;
    return AcgProviderFailure<FeedRefreshResult>(
        kind: failure.kind, message: failure.message);
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    final StoredFeedSourceRecord? storedSource =
        await store.sourceById(request.sourceId.value);
    if (storedSource == null) {
      return RssRefreshOutcome.failure(
        sourceId: request.sourceId,
        failure: const RssRefreshFailure(
            kind: AcgProviderFailureKind.notFound,
            message: 'Feed source is not registered.'),
      );
    }

    final FeedSource source = _feedSourceFromRecord(storedSource);
    if (parser.format != source.format) {
      return RssRefreshOutcome.failure(
        sourceId: source.id,
        failure: const RssRefreshFailure(
            kind: AcgProviderFailureKind.terminal,
            message: 'Feed parser format does not match source format.'),
      );
    }

    final StoredFeedCursorRecord? cursor =
        await store.cursorFor(source.id.value);
    final AcgProviderResult<FeedFetchResponse> fetchResult =
        await fetcher.fetchFeed(
      FeedFetchRequest(
          source: source,
          etag: cursor?.etag,
          lastModified: cursor?.lastModified),
    );
    switch (fetchResult) {
      case AcgProviderFailure<FeedFetchResponse>(:final kind, :final message):
        return RssRefreshOutcome.failure(
            sourceId: source.id,
            failure: RssRefreshFailure(kind: kind, message: message));
      case AcgProviderSuccess<FeedFetchResponse>(:final value):
        final FeedParseResult parsed = await parser
            .parse(FeedParseRequest(source: source, body: value.body));
        final List<FeedItem> deduplicatorAccepted =
            await deduplicator.retainNewItems(parsed.items);
        final DateTime now = _clock();
        final List<FeedItem> accepted = <FeedItem>[];
        for (final FeedItem item in deduplicatorAccepted) {
          final bool known = await store.hasDedupeKey(
              sourceId: item.sourceId.value, dedupeKey: item.dedupeKey.value);
          if (!known) {
            accepted.add(item);
            await store.recordDedupeKey(
              StoredFeedDedupeKeyRecord(
                  sourceId: item.sourceId.value,
                  dedupeKey: item.dedupeKey.value,
                  acceptedAt: now),
            );
          }
        }
        await store.storeItems(<StoredFeedItemRecord>[
          for (final FeedItem item in accepted)
            _itemRecordFromFeedItem(item, acceptedAt: now),
        ]);
        await store.saveCursor(
          StoredFeedCursorRecord(
              sourceId: source.id.value,
              etag: value.etag,
              lastModified: value.lastModified,
              refreshedAt: now),
        );
        for (final FeedItem item in accepted) {
          _updates.add(item);
        }
        return RssRefreshOutcome.success(
            sourceId: source.id, newItems: accepted, warnings: parsed.warnings);
    }
  }

  Future<void> close() => _updates.close();

  static DateTime _defaultClock() => deterministicContractEpoch;
}

final class DeterministicFeedDeduplicator implements FeedDeduplicator {
  final Set<String> _seenKeys = <String>{};

  @override
  FeedDedupeKey keyFor(FeedSource source, String rawGuid, Uri? link) {
    final String normalizedGuid = rawGuid.trim().toLowerCase();
    if (normalizedGuid.isNotEmpty) {
      return FeedDedupeKey('${source.id.value}::$normalizedGuid');
    }
    final String linkValue = link?.toString().trim().toLowerCase() ?? '';
    return FeedDedupeKey('${source.id.value}::$linkValue');
  }

  @override
  Future<List<FeedItem>> retainNewItems(Iterable<FeedItem> items) {
    final List<FeedItem> retained = <FeedItem>[];
    for (final FeedItem item in items) {
      if (_seenKeys.add('${item.sourceId.value}::${item.dedupeKey.value}')) {
        retained.add(item);
      }
    }
    return Future<List<FeedItem>>.value(retained);
  }
}

StoredFeedSourceRecord _sourceRecordFromFeedSource(FeedSource source) {
  return StoredFeedSourceRecord(
    id: source.id.value,
    displayName: source.displayName,
    uri: source.uri,
    format: source.format.name,
    refreshInterval: source.refreshInterval,
    defaultHeaders: source.defaultHeaders,
  );
}

FeedSource _feedSourceFromRecord(StoredFeedSourceRecord record) {
  return FeedSource(
    id: FeedSourceId(record.id),
    displayName: record.displayName,
    uri: record.uri,
    format: _feedFormatFromName(record.format),
    refreshInterval: record.refreshInterval,
    defaultHeaders: record.defaultHeaders,
  );
}

StoredFeedItemRecord _itemRecordFromFeedItem(FeedItem item,
    {required DateTime acceptedAt}) {
  return StoredFeedItemRecord(
    id: item.id.value,
    sourceId: item.sourceId.value,
    dedupeKey: item.dedupeKey.value,
    title: item.title,
    link: item.link,
    publishedAt: item.publishedAt,
    summary: item.summary,
    categories: item.categories,
    enclosure: item.enclosure == null
        ? null
        : StoredFeedEnclosureRecord(
            uri: item.enclosure!.uri,
            mimeType: item.enclosure!.mimeType,
            lengthBytes: item.enclosure!.lengthBytes,
          ),
    acceptedAt: acceptedAt,
  );
}

FeedItem feedItemFromStoredRecord(StoredFeedItemRecord record) {
  return FeedItem(
    id: FeedItemId(record.id),
    sourceId: FeedSourceId(record.sourceId),
    dedupeKey: FeedDedupeKey(record.dedupeKey),
    title: record.title,
    link: record.link,
    publishedAt: record.publishedAt,
    summary: record.summary,
    categories: record.categories,
    enclosure: record.enclosure == null
        ? null
        : FeedEnclosure(
            uri: record.enclosure!.uri,
            mimeType: record.enclosure!.mimeType,
            lengthBytes: record.enclosure!.lengthBytes,
          ),
  );
}

FeedFormat _feedFormatFromName(String name) {
  return switch (name) {
    'rss' => FeedFormat.rss,
    'atom' => FeedFormat.atom,
    _ => FeedFormat.rss,
  };
}
