import 'dart:io';

import '../lib/elaina.dart';

Future<void> main() async {
  await verifyRssFeedFetcherParserContract();
  stdout.writeln('RSS feed fetcher/parser checks passed.');
}

Future<void> verifyRssFeedFetcherParserContract() async {
  await _verifyRssRefresh();
  await _verifyAtomRefresh();
  await _verifyNotModifiedRefresh();
}

Future<void> _verifyRssRefresh() async {
  final _CheckFeedHttpTransport transport = _CheckFeedHttpTransport(
    responses: <FeedHttpResponse>[
      FeedHttpResponse(statusCode: HttpStatus.ok, body: _rssBody()),
    ],
  );
  final RssEngineBootstrap bootstrap = _bootstrap(
    fetcher: _fetcher(transport),
    parser: const RssXmlFeedParser(),
  );
  final FeedSource source = _source(format: FeedFormat.rss);

  await bootstrap.registerSource(source);
  final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
      await bootstrap.refreshSource(source.id);

  _expect(refreshed.isSuccess, 'RSS refresh must succeed.');
  _expect(
    refreshed.value?.acceptedItems.single.title == 'Check RSS Episode',
    'RSS parser must project item titles.',
  );
  _expect(
    transport.requests.single.headers[HttpHeaders.acceptHeader] ==
        defaultFeedAcceptHeader,
    'HTTP feed fetcher must send an RSS/Atom accept header.',
  );
  await bootstrap.dispose();
}

Future<void> _verifyAtomRefresh() async {
  final _CheckFeedHttpTransport transport = _CheckFeedHttpTransport(
    responses: <FeedHttpResponse>[
      FeedHttpResponse(statusCode: HttpStatus.ok, body: _atomBody()),
    ],
  );
  final RssEngineBootstrap bootstrap = _bootstrap(
    fetcher: _fetcher(transport),
    parser: const AtomXmlFeedParser(),
  );
  final FeedSource source = _source(format: FeedFormat.atom);

  await bootstrap.registerSource(source);
  final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
      await bootstrap.refreshSource(source.id);

  _expect(refreshed.isSuccess, 'Atom refresh must succeed.');
  _expect(
    refreshed.value?.acceptedItems.single.link ==
        Uri.parse('https://example.test/check-atom'),
    'Atom parser must resolve alternate links.',
  );
  await bootstrap.dispose();
}

Future<void> _verifyNotModifiedRefresh() async {
  final DateTime refreshedAt = DateTime.utc(2026, 6, 17, 12);
  final _CheckFeedHttpTransport transport = _CheckFeedHttpTransport(
    responses: const <FeedHttpResponse>[
      FeedHttpResponse(statusCode: HttpStatus.notModified, body: ''),
    ],
  );
  final RssEngineBootstrap bootstrap = _bootstrap(
    fetcher: _fetcher(transport),
    parser: const RssXmlFeedParser(),
    clock: () => refreshedAt,
  );
  final FeedSource source = _source(format: FeedFormat.rss);

  await bootstrap.registerSource(source);
  final RssEngineActionResult<RssEngineRefreshSnapshot> refreshed =
      await bootstrap.refreshSource(source.id);
  final RssEngineActionResult<RssEngineCursorSnapshot?> cursor =
      await bootstrap.runtime.cursorSnapshot(source.id);

  _expect(refreshed.isSuccess, 'Not-modified refresh must be successful.');
  _expect(
    refreshed.value?.acceptedItems.isEmpty == true,
    'Not-modified refresh must not create accepted items.',
  );
  _expect(
    cursor.value?.refreshedAt == refreshedAt,
    'Not-modified refresh must still update cursor refresh time.',
  );
  await bootstrap.dispose();
}

RssEngineBootstrap _bootstrap({
  required FeedFetcher fetcher,
  required FeedParser parser,
  DateTime Function()? clock,
}) {
  return RssEngineBootstrap(
    store: DeterministicRssFeedStore(),
    fetcher: fetcher,
    parser: parser,
    scheduler: _CheckFeedScheduler(),
    clock: clock ?? () => DateTime.utc(2026, 6, 17, 12),
  );
}

HttpFeedFetcher _fetcher(FeedHttpTransport transport) {
  return HttpFeedFetcher(
    gateway: DeterministicProviderGateway(
      storage: DeterministicStorageFoundation(),
    ),
    transport: transport,
  );
}

FeedSource _source({required FeedFormat format}) {
  return FeedSource(
    id: const FeedSourceId('check-feed'),
    displayName: 'Check Feed',
    uri: Uri.parse('https://example.test/check.xml'),
    format: format,
    refreshInterval: const Duration(hours: 1),
  );
}

String _rssBody() {
  return '''
<rss version="2.0">
  <channel>
    <item>
      <title>Check RSS Episode</title>
      <guid>check-rss-episode</guid>
      <link>/check-rss</link>
    </item>
  </channel>
</rss>
''';
}

String _atomBody() {
  return '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Check Atom Episode</title>
    <id>check-atom-episode</id>
    <link rel="alternate" href="/check-atom" />
    <updated>2026-06-17T12:00:00Z</updated>
  </entry>
</feed>
''';
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) async* {
    for (final FeedSource source in sources) {
      yield FeedScheduleDecision(
        source: source,
        dueAt: DateTime.utc(2026, 6, 17, 12),
      );
    }
  }
}

final class _CheckFeedHttpTransport implements FeedHttpTransport {
  _CheckFeedHttpTransport({required this.responses});

  final List<FeedHttpResponse> responses;
  final List<FeedHttpRequest> requests = <FeedHttpRequest>[];
  int _index = 0;

  @override
  Future<FeedHttpResponse> send(FeedHttpRequest request) {
    requests.add(request);
    final FeedHttpResponse response =
        responses[_index < responses.length ? _index : responses.length - 1];
    _index += 1;
    return Future<FeedHttpResponse>.value(response);
  }
}
