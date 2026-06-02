import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class FeedSourceId {
  const FeedSourceId(this.value) : assert(value != '', 'Feed source id must not be empty.');

  final String value;
}

enum FeedFormat {
  rss,
  atom,
}

final class FeedSource {
  const FeedSource({
    required this.id,
    required this.displayName,
    required this.uri,
    required this.format,
    required this.refreshInterval,
    this.defaultHeaders = const <String, String>{},
  })  : assert(displayName != '', 'Feed display name must not be empty.'),
        assert(refreshInterval > Duration.zero, 'refreshInterval must be positive.');

  final FeedSourceId id;
  final String displayName;
  final Uri uri;
  final FeedFormat format;
  final Duration refreshInterval;
  final Map<String, String> defaultHeaders;
}

final class FeedFetchRequest {
  const FeedFetchRequest({required this.source, this.etag, this.lastModified});

  final FeedSource source;
  final String? etag;
  final DateTime? lastModified;
}

final class FeedFetchResponse {
  const FeedFetchResponse({
    required this.sourceId,
    required this.body,
    this.etag,
    this.lastModified,
  });

  final FeedSourceId sourceId;
  final String body;
  final String? etag;
  final DateTime? lastModified;
}

abstract interface class FeedFetcher implements GatewayBoundProvider {
  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderGateway get gateway;

  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(FeedFetchRequest request);
}

final class FeedItemId {
  const FeedItemId(this.value) : assert(value != '', 'Feed item id must not be empty.');

  final String value;
}

final class FeedDedupeKey {
  const FeedDedupeKey(this.value) : assert(value != '', 'Feed dedupe key must not be empty.');

  final String value;
}

final class FeedEnclosure {
  const FeedEnclosure({required this.uri, this.mimeType, this.lengthBytes})
      : assert(lengthBytes == null || lengthBytes >= 0, 'lengthBytes must not be negative.');

  final Uri uri;
  final String? mimeType;
  final int? lengthBytes;
}

final class FeedItem {
  const FeedItem({
    required this.id,
    required this.sourceId,
    required this.dedupeKey,
    required this.title,
    this.link,
    this.publishedAt,
    this.summary,
    this.categories = const <String>[],
    this.enclosure,
  }) : assert(title != '', 'Feed item title must not be empty.');

  final FeedItemId id;
  final FeedSourceId sourceId;
  final FeedDedupeKey dedupeKey;
  final String title;
  final Uri? link;
  final DateTime? publishedAt;
  final String? summary;
  final List<String> categories;
  final FeedEnclosure? enclosure;
}

final class FeedParseRequest {
  const FeedParseRequest({required this.source, required this.body});

  final FeedSource source;
  final String body;
}

final class FeedParseResult {
  const FeedParseResult({required this.sourceId, required this.items, this.warnings = const <String>[]});

  final FeedSourceId sourceId;
  final List<FeedItem> items;
  final List<String> warnings;
}

abstract interface class FeedParser {
  FeedFormat get format;

  Future<FeedParseResult> parse(FeedParseRequest request);
}

final class FeedScheduleDecision {
  const FeedScheduleDecision({required this.source, required this.dueAt});

  final FeedSource source;
  final DateTime dueAt;
}

abstract interface class FeedScheduler {
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources);
}

abstract interface class FeedDeduplicator {
  FeedDedupeKey keyFor(FeedSource source, String rawGuid, Uri? link);

  Future<List<FeedItem>> retainNewItems(Iterable<FeedItem> items);
}

final class FeedRefreshResult {
  const FeedRefreshResult({required this.sourceId, required this.newItems, this.warnings = const <String>[]});

  final FeedSourceId sourceId;
  final List<FeedItem> newItems;
  final List<String> warnings;
}

abstract interface class FeedEngine {
  Future<void> registerSource(FeedSource source);

  Future<AcgProviderResult<FeedRefreshResult>> refresh(FeedSourceId sourceId);

  Stream<FeedItem> get updates;
}

ProviderRegistration rssProviderRegistration({
  required FeedSourceId sourceId,
  ProviderRatePolicy ratePolicy = const ProviderRatePolicy(maxRequests: 12, window: Duration(minutes: 1)),
  ProviderRetryPolicy retryPolicy = const ProviderRetryPolicy(maxAttempts: 3, initialBackoff: Duration(seconds: 2)),
  ProviderNegativeCachePolicy? negativeCachePolicy = const ProviderNegativeCachePolicy(ttl: Duration(minutes: 15)),
}) {
  return ProviderRegistration(
    providerId: ProviderId(sourceId.value),
    ratePolicy: ratePolicy,
    retryPolicy: retryPolicy,
    negativeCachePolicy: negativeCachePolicy,
  );
}
