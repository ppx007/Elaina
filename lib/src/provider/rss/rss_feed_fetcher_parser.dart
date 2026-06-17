import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../provider_result.dart';
import 'feed_contracts.dart';

const String defaultHttpFeedFetcherProviderId = 'rss-feed-fetcher';
const String defaultHttpFeedFetcherUserAgent = 'Celesteria/0.1';
const String defaultFeedAcceptHeader =
    'application/rss+xml, application/atom+xml, application/xml, text/xml, */*';
const Duration httpFeedFetcherDeduplicationWindow = Duration(seconds: 30);
const String feedParserUntitledItemTitle = 'Untitled feed item';

final class FeedHttpRequest {
  const FeedHttpRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
}

final class FeedHttpResponse {
  const FeedHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

abstract interface class FeedHttpTransport {
  Future<FeedHttpResponse> send(FeedHttpRequest request);
}

final class HttpFeedHttpTransport implements FeedHttpTransport {
  HttpFeedHttpTransport({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<FeedHttpResponse> send(FeedHttpRequest request) async {
    final HttpClientRequest httpRequest =
        await _httpClient.openUrl(request.method, request.uri);
    for (final MapEntry<String, String> header in request.headers.entries) {
      httpRequest.headers.set(header.key, header.value);
    }
    final HttpClientResponse response = await httpRequest.close();
    final Map<String, String> headers = <String, String>{};
    response.headers.forEach((String name, List<String> values) {
      if (values.isNotEmpty) headers[name.toLowerCase()] = values.join(',');
    });
    return FeedHttpResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
      headers: headers,
    );
  }
}

final class HttpFeedFetcher implements FeedFetcher {
  HttpFeedFetcher({
    required this.gateway,
    required FeedHttpTransport transport,
    String providerId = defaultHttpFeedFetcherProviderId,
    String userAgent = defaultHttpFeedFetcherUserAgent,
  })  : assert(providerId != '', 'Feed fetcher provider id must not be empty.'),
        assert(userAgent != '', 'Feed fetcher user agent must not be empty.'),
        _transport = transport,
        _providerId = providerId,
        _userAgent = userAgent;

  final FeedHttpTransport _transport;
  final String _providerId;
  final String _userAgent;
  bool _registered = false;

  @override
  final ProviderGateway gateway;

  @override
  String get displayName => 'HTTP Feed Fetcher';

  @override
  String get id => _providerId;

  @override
  ProviderKind get kind => ProviderKind.rss;

  @override
  ProviderRegistration get registration => rssProviderRegistration(
        sourceId: FeedSourceId(_providerId),
      );

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: ProviderId(_providerId),
      cacheKey: cacheKey,
    );
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    await _ensureRegistered();
    return gateway.execute<T>(
      ProviderGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
        deduplicationWindow: httpFeedFetcherDeduplicationWindow,
      ),
    );
  }

  @override
  Future<AcgProviderResult<FeedFetchResponse>> fetchFeed(
    FeedFetchRequest request,
  ) async {
    try {
      final ProviderGatewayResponse<FeedFetchResponse> response =
          await executeGatewayRequest<FeedFetchResponse>(
        cacheKey: _feedCacheKey(request),
        cachePolicy: ProviderCachePolicy.networkFirst,
        load: () => _fetch(request),
      );
      return AcgProviderSuccess<FeedFetchResponse>(response.value);
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<FeedFetchResponse>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    }
  }

  Future<FeedFetchResponse> _fetch(FeedFetchRequest request) async {
    final Uri uri = request.source.uri;
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Feed fetcher supports only HTTP and HTTPS sources.',
      );
    }

    final FeedHttpResponse response;
    try {
      response = await _transport.send(
        FeedHttpRequest(
          method: 'GET',
          uri: uri,
          headers: _headers(request),
        ),
      );
    } on ProviderFailure {
      rethrow;
    } catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.retryable,
        message: 'Feed HTTP transport failed: $error',
      );
    }

    final String? etag =
        _headerValue(response.headers, HttpHeaders.etagHeader) ?? request.etag;
    final DateTime? lastModified = _parseHttpDate(
            _headerValue(response.headers, HttpHeaders.lastModifiedHeader)) ??
        request.lastModified;

    if (response.statusCode == HttpStatus.notModified) {
      return FeedFetchResponse(
        sourceId: request.source.id,
        body: '',
        etag: etag,
        lastModified: lastModified,
        notModified: true,
      );
    }
    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      throw ProviderFailure(
        kind: _failureKindForStatus(response.statusCode),
        message: 'Feed fetch failed with HTTP ${response.statusCode}.',
      );
    }
    if (response.body.trim().isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Feed fetch returned an empty response body.',
      );
    }
    return FeedFetchResponse(
      sourceId: request.source.id,
      body: response.body,
      etag: etag,
      lastModified: lastModified,
    );
  }

  Map<String, String> _headers(FeedFetchRequest request) {
    return <String, String>{
      HttpHeaders.acceptHeader: defaultFeedAcceptHeader,
      HttpHeaders.userAgentHeader: _userAgent,
      ...request.source.defaultHeaders,
      if (request.etag != null) HttpHeaders.ifNoneMatchHeader: request.etag!,
      if (request.lastModified != null)
        HttpHeaders.ifModifiedSinceHeader:
            HttpDate.format(request.lastModified!),
    };
  }

  Future<void> _ensureRegistered() async {
    if (_registered) return;
    await gateway.registerProvider(registration);
    _registered = true;
  }
}

base class XmlFeedParser implements FeedParser {
  const XmlFeedParser({required this.format});

  const XmlFeedParser.rss() : format = FeedFormat.rss;

  const XmlFeedParser.atom() : format = FeedFormat.atom;

  @override
  final FeedFormat format;

  @override
  Future<FeedParseResult> parse(FeedParseRequest request) async {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(request.body);
    } catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Feed XML was malformed: $error',
      );
    }
    return switch (format) {
      FeedFormat.rss => _parseRss(document, request),
      FeedFormat.atom => _parseAtom(document, request),
    };
  }
}

final class RssXmlFeedParser extends XmlFeedParser {
  const RssXmlFeedParser() : super.rss();
}

final class AtomXmlFeedParser extends XmlFeedParser {
  const AtomXmlFeedParser() : super.atom();
}

FeedParseResult _parseRss(XmlDocument document, FeedParseRequest request) {
  final XmlElement? channel = _firstDescendant(document.rootElement, 'channel');
  if (channel == null) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'RSS feed is missing channel element.',
    );
  }
  final List<FeedItem> items = <FeedItem>[
    for (final XmlElement item in _childElements(channel, 'item'))
      _rssItem(request.source, item),
  ];
  return FeedParseResult(
    sourceId: request.source.id,
    items: items,
    warnings: items.isEmpty
        ? const <String>['RSS feed contains no items.']
        : const <String>[],
  );
}

FeedItem _rssItem(FeedSource source, XmlElement item) {
  final String rawGuid = _textOf(item, 'guid');
  final Uri? link = _resolveUri(source, _textOf(item, 'link'));
  final String title = _firstNonEmpty(<String>[
    _textOf(item, 'title'),
    link?.toString() ?? '',
    rawGuid,
    feedParserUntitledItemTitle,
  ]);
  final FeedDedupeKey dedupeKey = feedDedupeKeyFor(
    source,
    rawGuid: _firstNonEmpty(<String>[rawGuid, link?.toString() ?? '', title]),
    link: link,
  );
  return FeedItem(
    id: FeedItemId(dedupeKey.value),
    sourceId: source.id,
    dedupeKey: dedupeKey,
    title: title,
    link: link,
    publishedAt: _parseFeedDate(_firstNonEmpty(<String>[
      _textOf(item, 'pubDate'),
      _textOf(item, 'published'),
      _textOf(item, 'updated'),
    ])),
    summary: _optionalText(_firstNonEmpty(<String>[
      _textOf(item, 'description'),
      _textOf(item, 'summary'),
    ])),
    categories: _categoriesFromRss(item),
    enclosure: _rssEnclosure(source, item),
  );
}

FeedParseResult _parseAtom(XmlDocument document, FeedParseRequest request) {
  final List<XmlElement> entries = <XmlElement>[
    for (final XmlElement entry
        in _childElements(document.rootElement, 'entry'))
      entry,
  ];
  if (_localName(document.rootElement) != 'feed') {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Atom feed is missing feed root element.',
    );
  }
  final List<FeedItem> items = <FeedItem>[
    for (final XmlElement entry in entries) _atomEntry(request.source, entry),
  ];
  return FeedParseResult(
    sourceId: request.source.id,
    items: items,
    warnings: items.isEmpty
        ? const <String>['Atom feed contains no entries.']
        : const <String>[],
  );
}

FeedItem _atomEntry(FeedSource source, XmlElement entry) {
  final String rawId = _textOf(entry, 'id');
  final Uri? link = _atomLink(source, entry);
  final String title = _firstNonEmpty(<String>[
    _textOf(entry, 'title'),
    link?.toString() ?? '',
    rawId,
    feedParserUntitledItemTitle,
  ]);
  final FeedDedupeKey dedupeKey = feedDedupeKeyFor(
    source,
    rawGuid: _firstNonEmpty(<String>[rawId, link?.toString() ?? '', title]),
    link: link,
  );
  return FeedItem(
    id: FeedItemId(dedupeKey.value),
    sourceId: source.id,
    dedupeKey: dedupeKey,
    title: title,
    link: link,
    publishedAt: _parseFeedDate(_firstNonEmpty(<String>[
      _textOf(entry, 'published'),
      _textOf(entry, 'updated'),
    ])),
    summary: _optionalText(_firstNonEmpty(<String>[
      _textOf(entry, 'summary'),
      _textOf(entry, 'content'),
    ])),
    categories: _categoriesFromAtom(entry),
    enclosure: _atomEnclosure(source, entry),
  );
}

List<String> _categoriesFromRss(XmlElement item) {
  return <String>[
    for (final XmlElement category in _childElements(item, 'category'))
      if (category.innerText.trim().isNotEmpty) category.innerText.trim(),
  ];
}

List<String> _categoriesFromAtom(XmlElement entry) {
  return <String>[
    for (final XmlElement category in _childElements(entry, 'category'))
      if (_attribute(category, 'term')?.trim().isNotEmpty == true)
        _attribute(category, 'term')!.trim()
      else if (category.innerText.trim().isNotEmpty)
        category.innerText.trim(),
  ];
}

FeedEnclosure? _rssEnclosure(FeedSource source, XmlElement item) {
  final XmlElement? enclosure = _firstChild(item, 'enclosure');
  if (enclosure == null) return null;
  final Uri? uri = _resolveUri(source, _attribute(enclosure, 'url') ?? '');
  if (uri == null) return null;
  return FeedEnclosure(
    uri: uri,
    mimeType: _optionalText(_attribute(enclosure, 'type') ?? ''),
    lengthBytes: int.tryParse(_attribute(enclosure, 'length') ?? ''),
  );
}

FeedEnclosure? _atomEnclosure(FeedSource source, XmlElement entry) {
  for (final XmlElement link in _childElements(entry, 'link')) {
    if ((_attribute(link, 'rel') ?? '').toLowerCase() != 'enclosure') {
      continue;
    }
    final Uri? uri = _resolveUri(source, _attribute(link, 'href') ?? '');
    if (uri == null) return null;
    return FeedEnclosure(
      uri: uri,
      mimeType: _optionalText(_attribute(link, 'type') ?? ''),
      lengthBytes: int.tryParse(_attribute(link, 'length') ?? ''),
    );
  }
  return null;
}

Uri? _atomLink(FeedSource source, XmlElement entry) {
  XmlElement? fallback;
  for (final XmlElement link in _childElements(entry, 'link')) {
    final String rel = (_attribute(link, 'rel') ?? 'alternate').toLowerCase();
    if (fallback == null && _attribute(link, 'href') != null) fallback = link;
    if (rel == 'alternate') {
      return _resolveUri(source, _attribute(link, 'href') ?? '');
    }
  }
  return fallback == null
      ? _resolveUri(source, _textOf(entry, 'link'))
      : _resolveUri(source, _attribute(fallback, 'href') ?? '');
}

DateTime? _parseFeedDate(String value) {
  final String text = value.trim();
  if (text.isEmpty) return null;
  final DateTime? iso = DateTime.tryParse(text);
  if (iso != null) return iso.toUtc();
  try {
    return HttpDate.parse(text).toUtc();
  } on FormatException {
    return null;
  }
}

Uri? _resolveUri(FeedSource source, String value) {
  final String text = value.trim();
  if (text.isEmpty) return null;
  try {
    return source.uri.resolve(text);
  } on FormatException {
    return null;
  }
}

String _textOf(XmlElement parent, String localName) {
  return _firstChild(parent, localName)?.innerText.trim() ?? '';
}

XmlElement? _firstChild(XmlElement parent, String localName) {
  for (final XmlElement element in parent.childElements) {
    if (_localName(element) == localName) return element;
  }
  return null;
}

XmlElement? _firstDescendant(XmlElement parent, String localName) {
  for (final XmlElement element in parent.descendants.whereType<XmlElement>()) {
    if (_localName(element) == localName) return element;
  }
  return null;
}

Iterable<XmlElement> _childElements(XmlElement parent, String localName) {
  return parent.childElements
      .where((XmlElement element) => _localName(element) == localName);
}

String _localName(XmlElement element) => element.name.local;

String? _attribute(XmlElement element, String localName) {
  for (final XmlAttribute attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

String? _optionalText(String value) {
  final String text = value.trim();
  return text.isEmpty ? null : text;
}

String _firstNonEmpty(Iterable<String> values) {
  for (final String value in values) {
    final String text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _feedCacheKey(FeedFetchRequest request) {
  final String lastModified =
      request.lastModified?.toUtc().toIso8601String() ?? '';
  return 'feed:${request.source.id.value}:${request.source.uri}:'
      'etag=${request.etag ?? ''}:lastModified=$lastModified';
}

String? _headerValue(Map<String, String> headers, String name) {
  return headers[name] ?? headers[name.toLowerCase()];
}

DateTime? _parseHttpDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    return HttpDate.parse(value).toUtc();
  } on FormatException {
    return null;
  }
}

ProviderFailureKind _failureKindForStatus(int statusCode) {
  if (statusCode == HttpStatus.tooManyRequests) {
    return ProviderFailureKind.throttled;
  }
  if (statusCode == HttpStatus.notFound) {
    return ProviderFailureKind.cachedMiss;
  }
  if (statusCode == HttpStatus.requestTimeout ||
      statusCode >= HttpStatus.internalServerError) {
    return ProviderFailureKind.retryable;
  }
  return ProviderFailureKind.terminal;
}
