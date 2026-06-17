import 'dart:io';

import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpFeedFetcher', () {
    test('fetches HTTP feeds through gateway with validators and headers',
        () async {
      final DateTime lastModified = DateTime.utc(2026, 6, 17, 10);
      final DateTime responseModified = DateTime.utc(2026, 6, 17, 12);
      final _RecordingFeedHttpTransport transport = _RecordingFeedHttpTransport(
        responses: <FeedHttpResponse>[
          FeedHttpResponse(
            statusCode: HttpStatus.ok,
            body: _rssBody(),
            headers: <String, String>{
              HttpHeaders.etagHeader: '"etag-v2"',
              HttpHeaders.lastModifiedHeader: HttpDate.format(responseModified),
            },
          ),
        ],
      );
      final HttpFeedFetcher fetcher = _fetcher(transport: transport);

      final AcgProviderResult<FeedFetchResponse> result =
          await fetcher.fetchFeed(
        FeedFetchRequest(
          source: _rssSource(
            defaultHeaders: const <String, String>{
              'x-feed-token': 'token-1',
            },
          ),
          etag: '"etag-v1"',
          lastModified: lastModified,
        ),
      );

      final FeedFetchResponse response =
          (result as AcgProviderSuccess<FeedFetchResponse>).value;
      final FeedHttpRequest request = transport.requests.single;
      expect(request.method, 'GET');
      expect(request.uri, Uri.parse('https://example.test/rss.xml'));
      expect(
          request.headers[HttpHeaders.acceptHeader], defaultFeedAcceptHeader);
      expect(
        request.headers[HttpHeaders.userAgentHeader],
        defaultHttpFeedFetcherUserAgent,
      );
      expect(request.headers['x-feed-token'], 'token-1');
      expect(request.headers[HttpHeaders.ifNoneMatchHeader], '"etag-v1"');
      expect(
        request.headers[HttpHeaders.ifModifiedSinceHeader],
        HttpDate.format(lastModified),
      );
      expect(response.etag, '"etag-v2"');
      expect(response.lastModified, responseModified);
      expect(response.notModified, isFalse);
      expect(response.body, _rssBody());
    });

    test('returns notModified without requiring a response body', () async {
      final DateTime lastModified = DateTime.utc(2026, 6, 17, 10);
      final _RecordingFeedHttpTransport transport = _RecordingFeedHttpTransport(
        responses: const <FeedHttpResponse>[
          FeedHttpResponse(statusCode: HttpStatus.notModified, body: ''),
        ],
      );
      final HttpFeedFetcher fetcher = _fetcher(transport: transport);

      final AcgProviderResult<FeedFetchResponse> result =
          await fetcher.fetchFeed(
        FeedFetchRequest(
          source: _rssSource(),
          etag: '"etag-v1"',
          lastModified: lastModified,
        ),
      );

      final FeedFetchResponse response =
          (result as AcgProviderSuccess<FeedFetchResponse>).value;
      expect(response.notModified, isTrue);
      expect(response.body, isEmpty);
      expect(response.etag, '"etag-v1"');
      expect(response.lastModified, lastModified);
      expect(transport.requests.single.headers[HttpHeaders.ifNoneMatchHeader],
          '"etag-v1"');
    });

    test('normalizes unsupported schemes and retryable server failures',
        () async {
      final _RecordingFeedHttpTransport transport = _RecordingFeedHttpTransport(
        responses: const <FeedHttpResponse>[
          FeedHttpResponse(
            statusCode: HttpStatus.serviceUnavailable,
            body: 'temporary failure',
          ),
        ],
      );
      final HttpFeedFetcher fetcher = _fetcher(transport: transport);

      final AcgProviderResult<FeedFetchResponse> unsupported =
          await fetcher.fetchFeed(
        FeedFetchRequest(
          source: _rssSource(uri: Uri.parse('ftp://example.test/rss.xml')),
        ),
      );
      final AcgProviderResult<FeedFetchResponse> retryable =
          await fetcher.fetchFeed(FeedFetchRequest(source: _rssSource()));

      expect(
        (unsupported as AcgProviderFailure<FeedFetchResponse>).kind,
        AcgProviderFailureKind.terminal,
      );
      expect(
        (retryable as AcgProviderFailure<FeedFetchResponse>).kind,
        AcgProviderFailureKind.retryable,
      );
      expect(transport.requests.single.uri,
          Uri.parse('https://example.test/rss.xml'));
    });
  });

  group('XmlFeedParser', () {
    test('parses RSS item fields into feed items', () async {
      const RssXmlFeedParser parser = RssXmlFeedParser();

      final FeedParseResult result = await parser.parse(
        FeedParseRequest(source: _rssSource(), body: _rssBody()),
      );

      final FeedItem item = result.items.single;
      expect(result.sourceId.value, 'anime-feed');
      expect(item.id.value, 'anime-feed::guid-1');
      expect(item.dedupeKey.value, 'anime-feed::guid-1');
      expect(item.title, 'Episode 1');
      expect(item.link, Uri.parse('https://example.test/episode-1'));
      expect(item.publishedAt, DateTime.utc(2026, 6, 17, 10));
      expect(item.summary, 'RSS summary');
      expect(item.categories, const <String>['anime']);
      expect(item.enclosure?.uri,
          Uri.parse('https://example.test/episode-1.torrent'));
      expect(item.enclosure?.mimeType, 'application/x-bittorrent');
      expect(item.enclosure?.lengthBytes, 123);
    });

    test('parses Atom entry fields into feed items', () async {
      const AtomXmlFeedParser parser = AtomXmlFeedParser();

      final FeedParseResult result = await parser.parse(
        FeedParseRequest(source: _atomSource(), body: _atomBody()),
      );

      final FeedItem item = result.items.single;
      expect(item.id.value, 'atom-feed::tag:example.test,2026:episode-2');
      expect(item.title, 'Atom Episode 2');
      expect(item.link, Uri.parse('https://example.test/episode-2'));
      expect(item.publishedAt, DateTime.utc(2026, 6, 17, 11));
      expect(item.summary, 'Atom summary');
      expect(item.categories, const <String>['ova']);
      expect(item.enclosure?.uri,
          Uri.parse('https://example.test/episode-2.torrent'));
      expect(item.enclosure?.lengthBytes, 456);
    });

    test('uses title fallback for identity-less RSS items', () async {
      const RssXmlFeedParser parser = RssXmlFeedParser();

      final FeedParseResult result = await parser.parse(
        FeedParseRequest(
          source: _rssSource(),
          body: '''
<rss version="2.0">
  <channel>
    <item><title>Only Title</title></item>
  </channel>
</rss>
''',
        ),
      );

      expect(result.items.single.dedupeKey.value, 'anime-feed::only title');
    });

    test('throws provider failure for malformed XML', () async {
      const RssXmlFeedParser parser = RssXmlFeedParser();

      expect(
        parser.parse(
          FeedParseRequest(source: _rssSource(), body: '<rss><channel>'),
        ),
        throwsA(
          isA<ProviderFailure>().having(
            (ProviderFailure failure) => failure.kind,
            'kind',
            ProviderFailureKind.terminal,
          ),
        ),
      );
    });
  });
}

HttpFeedFetcher _fetcher({required FeedHttpTransport transport}) {
  return HttpFeedFetcher(
    gateway: DeterministicProviderGateway(
      storage: DeterministicStorageFoundation(),
    ),
    transport: transport,
  );
}

FeedSource _rssSource({
  Uri? uri,
  Map<String, String> defaultHeaders = const <String, String>{},
}) {
  return FeedSource(
    id: const FeedSourceId('anime-feed'),
    displayName: 'Anime Feed',
    uri: uri ?? Uri.parse('https://example.test/rss.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
    defaultHeaders: defaultHeaders,
  );
}

FeedSource _atomSource() {
  return FeedSource(
    id: const FeedSourceId('atom-feed'),
    displayName: 'Atom Feed',
    uri: Uri.parse('https://example.test/atom.xml'),
    format: FeedFormat.atom,
    refreshInterval: const Duration(hours: 1),
  );
}

String _rssBody() {
  return '''
<rss version="2.0">
  <channel>
    <item>
      <title>Episode 1</title>
      <link>/episode-1</link>
      <guid>GUID-1</guid>
      <pubDate>Wed, 17 Jun 2026 10:00:00 GMT</pubDate>
      <description>RSS summary</description>
      <category>anime</category>
      <enclosure url="/episode-1.torrent" type="application/x-bittorrent" length="123" />
    </item>
  </channel>
</rss>
''';
}

String _atomBody() {
  return '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Atom Episode 2</title>
    <id>tag:example.test,2026:episode-2</id>
    <link rel="alternate" href="/episode-2" />
    <updated>2026-06-17T11:00:00Z</updated>
    <summary>Atom summary</summary>
    <category term="ova" />
    <link rel="enclosure" href="/episode-2.torrent" type="application/x-bittorrent" length="456" />
  </entry>
</feed>
''';
}

final class _RecordingFeedHttpTransport implements FeedHttpTransport {
  _RecordingFeedHttpTransport({required this.responses});

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
