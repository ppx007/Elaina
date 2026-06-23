import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../../foundation/security/outbound_uri_guard.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';
import 'bangumi_auth.dart';
import 'bangumi_provider.dart';
import 'bangumi_registration.dart';
import 'bangumi_runtime.dart';

const String defaultBangumiApiUserAgent =
    'ppx007/Elaina/0.1.0 (Windows; Flutter) '
    '(https://github.com/ppx007/Elaina)';
const int bangumiApiDefaultSearchLimit = 20;
const int bangumiApiDefaultSearchOffset = 0;
const String bangumiApiSubjectSearchMatchSort = 'match';
const String bangumiApiSubjectSearchHeatSort = 'heat';
const int bangumiApiRecentPopularAnimeLimit = bangumiApiDefaultSearchLimit;
const int bangumiApiRecentPopularAnimeOffset = 0;
const String bangumiApiRecentPopularAnimeSort = 'heat';
const String bangumiTrendsBrowserSort = 'trends';
const int bangumiTrendsHeroLimit = 7;
const int bangumiTrendsBrowserPageSize = 24;
const int bangumiTrendsBrowserInitialOffset = 0;
const int bangumiApiEpisodePageLimit = 200;
const int bangumiApiEpisodeInitialOffset = 0;
const int bangumiApiCollectionPageLimit = 50;
const int bangumiApiCollectionInitialOffset = 0;
const int bangumiAnimeSubjectType = 2;
const int bangumiSubjectCollectionWish = 1;
const int bangumiSubjectCollectionDone = 2;
const int bangumiSubjectCollectionDoing = 3;
const int bangumiSubjectCollectionOnHold = 4;
const int bangumiSubjectCollectionDropped = 5;
const int bangumiEpisodeCollectionWish = 1;
const int bangumiEpisodeCollectionDone = 2;
const int bangumiEpisodeCollectionDropped = 3;
const Duration bangumiApiSessionProjectionTtl = Duration(minutes: 15);
const String defaultBangumiOAuthClientId = 'bgm63916a369e2af2ca6';
const String bangumiOAuthAuthorizationResponseType = 'code';
const int _asciiDigitZeroCodeUnit = 0x30;
const int _asciiDigitNineCodeUnit = 0x39;

final Uri defaultBangumiApiBaseUri = Uri.parse('https://api.bgm.tv');
final Uri defaultBangumiWebBaseUri = Uri.parse('https://bgm.tv');
final Uri defaultBangumiOAuthAuthorizeBaseUri =
    Uri.parse('https://bgm.tv/oauth/authorize');
final Uri defaultBangumiOAuthAuthorizationPageUri =
    bangumiOAuthAuthorizationUri();
final Uri defaultBangumiAccessTokenPageUri =
    Uri.parse('https://next.bgm.tv/demo/access-token');

typedef BangumiAccessTokenProvider = Future<BangumiApiAccessToken?> Function();
typedef BangumiMirrorConfigProvider = Future<BangumiApiMirrorConfig> Function();
typedef BangumiImageUriRewriter = Uri Function(Uri uri);

const String bangumiMirrorImageUrlParameter = 'url';
const Set<String> bangumiMirrorImageHosts = <String>{
  'lain.bgm.tv',
};
final RegExp _whitespacePattern = RegExp(r'\s+');

Uri bangumiOAuthAuthorizationUri({
  Uri? authorizationBaseUri,
  String clientId = defaultBangumiOAuthClientId,
  Uri? redirectUri,
  String? state,
}) {
  final String trimmedClientId = clientId.trim();
  assert(trimmedClientId.isNotEmpty, 'Bangumi OAuth client id is required.');
  return (authorizationBaseUri ?? defaultBangumiOAuthAuthorizeBaseUri).replace(
    queryParameters: <String, String>{
      'client_id': trimmedClientId,
      'response_type': bangumiOAuthAuthorizationResponseType,
      if (redirectUri != null) 'redirect_uri': redirectUri.toString(),
      if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
    },
  );
}

final class BangumiApiAccessToken {
  const BangumiApiAccessToken({
    required this.value,
    this.expiresAt,
  }) : assert(value != '', 'Bangumi access token must not be empty.');

  final String value;
  final DateTime? expiresAt;

  bool isExpiredAt(DateTime now) {
    final DateTime? expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now);
  }
}

final class BangumiApiMirrorConfig {
  const BangumiApiMirrorConfig({
    required this.enabled,
    this.apiBaseUri,
    this.imageBaseUri,
  }) : assert(
          !enabled || (apiBaseUri != null && imageBaseUri != null),
          'Enabled Bangumi mirror requires API and image base URIs.',
        );

  const BangumiApiMirrorConfig.disabled()
      : enabled = false,
        apiBaseUri = null,
        imageBaseUri = null;

  const BangumiApiMirrorConfig.enabled({
    required this.apiBaseUri,
    required this.imageBaseUri,
  }) : enabled = true;

  final bool enabled;
  final Uri? apiBaseUri;
  final Uri? imageBaseUri;
}

final class BangumiApiRequest {
  const BangumiApiRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
    this.proxyUrl,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
  final String? proxyUrl;
}

final class BangumiApiResponse {
  const BangumiApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class BangumiApiTransport {
  Future<BangumiApiResponse> send(BangumiApiRequest request);
}

/// Concrete HTTP transport for Bangumi requests.
///
/// It owns socket-level concerns such as proxy wiring and the outbound URI
/// guard. Endpoint construction, cache policy, and JSON mapping stay in
/// BangumiApiClient/BangumiApiProvider.
final class HttpBangumiApiTransport implements BangumiApiTransport {
  HttpBangumiApiTransport({
    HttpClient? httpClient,
    OutboundUriGuard outboundGuard = const OutboundUriGuard(),
  })  : _httpClient = httpClient ?? HttpClient(),
        _outboundGuard = outboundGuard;

  final HttpClient _httpClient;
  final OutboundUriGuard _outboundGuard;

  @override
  Future<BangumiApiResponse> send(BangumiApiRequest request) async {
    final OutboundHostRisk? risk = _outboundGuard.classifyUri(request.uri);
    if (risk != null) {
      throw StateError(
          'Bangumi request blocked by SSRF guard: ${risk.name} ${request.uri}');
    }
    final HttpClient client = _clientFor(request.proxyUrl);
    try {
      final HttpClientRequest httpRequest =
          await client.openUrl(request.method, request.uri);
      for (final MapEntry<String, String> header in request.headers.entries) {
        httpRequest.headers.set(header.key, header.value);
      }
      final String? body = request.body;
      if (body != null) {
        final List<int> bodyBytes = utf8.encode(body);
        httpRequest.contentLength = bodyBytes.length;
        httpRequest.add(bodyBytes);
      }

      final HttpClientResponse response = await httpRequest.close();
      final String responseBody = await response.transform(utf8.decoder).join();
      return BangumiApiResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on IOException catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.retryable,
        message: 'Bangumi API network request failed: $error',
      );
    } finally {
      if (!identical(client, _httpClient)) client.close(force: true);
    }
  }

  HttpClient _clientFor(String? proxyUrl) {
    if (proxyUrl == null || proxyUrl.trim().isEmpty) return _httpClient;
    final String? proxyConfig = _proxyConfig(proxyUrl);
    if (proxyConfig == null) return _httpClient;
    final HttpClient client = HttpClient();
    client.findProxy = (_) => proxyConfig;
    return client;
  }

  String? _proxyConfig(String proxyUrl) {
    final String trimmed = proxyUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'direct') return 'DIRECT';
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return trimmed.contains(':') ? 'PROXY $trimmed' : null;
    }
    final int port = uri.hasPort ? uri.port : 80;
    return 'PROXY ${uri.host}:$port';
  }
}

/// Endpoint-level Bangumi client used by the provider adapter.
///
/// The client reads mirror configuration per request so settings changes take
/// effect immediately without rebuilding the provider runtime. It still returns
/// plain provider models; UI and domain layers must not consume raw Bangumi JSON.
final class BangumiApiClient {
  BangumiApiClient({
    required BangumiApiTransport transport,
    Uri? baseUri,
    BangumiMirrorConfigProvider? mirrorConfigProvider,
    String userAgent = defaultBangumiApiUserAgent,
  })  : _transport = transport,
        _baseUri = baseUri ?? defaultBangumiApiBaseUri,
        _mirrorConfigProvider = mirrorConfigProvider,
        _userAgent = userAgent;

  final BangumiApiTransport _transport;
  final Uri _baseUri;
  final BangumiMirrorConfigProvider? _mirrorConfigProvider;
  final String _userAgent;

  Uri lookupSubjectRequestUri(BangumiSubjectId id) {
    return _uri(_lookupSubjectPath(id));
  }

  Future<Uri> lookupSubjectNetworkPolicyUri(BangumiSubjectId id) {
    return _effectiveUri(_lookupSubjectPath(id));
  }

  Uri searchSubjectsRequestUri() {
    return _uri(
      _subjectSearchPath,
      const <String, String>{
        'limit': '$bangumiApiDefaultSearchLimit',
        'offset': '$bangumiApiDefaultSearchOffset',
      },
    );
  }

  Future<Uri> searchSubjectsNetworkPolicyUri() {
    return _effectiveUri(
      _subjectSearchPath,
      const <String, String>{
        'limit': '$bangumiApiDefaultSearchLimit',
        'offset': '$bangumiApiDefaultSearchOffset',
      },
    );
  }

  Uri recentPopularAnimeRequestUri({
    int limit = bangumiApiRecentPopularAnimeLimit,
    int offset = bangumiApiRecentPopularAnimeOffset,
  }) {
    return _uri(
      _subjectSearchPath,
      <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Future<Uri> recentPopularAnimeNetworkPolicyUri({
    int limit = bangumiApiRecentPopularAnimeLimit,
    int offset = bangumiApiRecentPopularAnimeOffset,
  }) {
    return _effectiveUri(
      _subjectSearchPath,
      <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Uri trendingAnimeRequestUri({
    int limit = bangumiTrendsHeroLimit,
    int offset = bangumiTrendsBrowserInitialOffset,
  }) {
    return _webUri(
      _animeBrowserPath,
      _trendsBrowserQueryParameters(
        _trendsPageForWindow(limit: limit, offset: offset),
      ),
    );
  }

  Future<Uri> trendingAnimeNetworkPolicyUri({
    int limit = bangumiTrendsHeroLimit,
    int offset = bangumiTrendsBrowserInitialOffset,
  }) {
    return _effectiveWebUri(
      _animeBrowserPath,
      _trendsBrowserQueryParameters(
        _trendsPageForWindow(limit: limit, offset: offset),
      ),
    );
  }

  Uri lookupEpisodeRequestUri(BangumiEpisodeId id) {
    return _uri(_lookupEpisodePath(id));
  }

  Future<Uri> lookupEpisodeNetworkPolicyUri(BangumiEpisodeId id) {
    return _effectiveUri(_lookupEpisodePath(id));
  }

  Uri listEpisodesRequestUri({
    required BangumiSubjectId subjectId,
    int limit = bangumiApiEpisodePageLimit,
    int offset = bangumiApiEpisodeInitialOffset,
  }) {
    return _uri(
      _episodeListPath,
      <String, String>{
        'subject_id': subjectId.value,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Future<Uri> listEpisodesNetworkPolicyUri({
    required BangumiSubjectId subjectId,
    int limit = bangumiApiEpisodePageLimit,
    int offset = bangumiApiEpisodeInitialOffset,
  }) {
    return _effectiveUri(
      _episodeListPath,
      <String, String>{
        'subject_id': subjectId.value,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Uri listSubjectPersonsRequestUri(BangumiSubjectId subjectId) {
    return _uri(_subjectPersonsPath(subjectId));
  }

  Future<Uri> listSubjectPersonsNetworkPolicyUri(
    BangumiSubjectId subjectId,
  ) {
    return _effectiveUri(_subjectPersonsPath(subjectId));
  }

  Uri listSubjectCharactersRequestUri(BangumiSubjectId subjectId) {
    return _uri(_subjectCharactersPath(subjectId));
  }

  Future<Uri> listSubjectCharactersNetworkPolicyUri(
    BangumiSubjectId subjectId,
  ) {
    return _effectiveUri(_subjectCharactersPath(subjectId));
  }

  Uri listSubjectRelationsRequestUri(BangumiSubjectId subjectId) {
    return _uri(_subjectRelationsPath(subjectId));
  }

  Future<Uri> listSubjectRelationsNetworkPolicyUri(
    BangumiSubjectId subjectId,
  ) {
    return _effectiveUri(_subjectRelationsPath(subjectId));
  }

  Uri currentSessionRequestUri() {
    return _uri(_currentSessionPath);
  }

  Future<Uri> currentSessionNetworkPolicyUri() {
    return _effectiveUri(_currentSessionPath);
  }

  Uri currentAnimeCollectionRequestUri({
    required String username,
    int limit = bangumiApiCollectionPageLimit,
    int offset = bangumiApiCollectionInitialOffset,
  }) {
    return _uri(
      _currentAnimeCollectionPath(username),
      <String, String>{
        'subject_type': '$bangumiAnimeSubjectType',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Future<Uri> currentAnimeCollectionNetworkPolicyUri({
    required String username,
    int limit = bangumiApiCollectionPageLimit,
    int offset = bangumiApiCollectionInitialOffset,
  }) {
    return _effectiveUri(
      _currentAnimeCollectionPath(username),
      <String, String>{
        'subject_type': '$bangumiAnimeSubjectType',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Uri accessTokenPageUri({Uri? tokenPageUri}) {
    return tokenPageUri ?? defaultBangumiAccessTokenPageUri;
  }

  Uri oauthAuthorizationPageUri({
    Uri? authorizationBaseUri,
    String clientId = defaultBangumiOAuthClientId,
    Uri? redirectUri,
    String? state,
  }) {
    return bangumiOAuthAuthorizationUri(
      authorizationBaseUri: authorizationBaseUri,
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
    );
  }

  Uri syncProgressRequestUri(BangumiProgressUpdate update) {
    return _uri(_syncProgressPath(update));
  }

  Future<Uri> syncProgressNetworkPolicyUri(BangumiProgressUpdate update) {
    return _effectiveUri(_syncProgressPath(update));
  }

  Uri syncSubjectCollectionRequestUri(BangumiSubjectCollectionUpdate update) {
    return _uri(_syncSubjectCollectionPath(update));
  }

  Future<Uri> syncSubjectCollectionNetworkPolicyUri(
    BangumiSubjectCollectionUpdate update,
  ) {
    return _effectiveUri(_syncSubjectCollectionPath(update));
  }

  Future<BangumiSubject> lookupSubject(
    BangumiSubjectId id, {
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_lookupSubjectPath(id));
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _subjectFromJson(
      _jsonObject(json, 'Bangumi subject'),
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<List<BangumiSubject>> searchSubjects(
    String query, {
    BangumiSubjectSearchSort sort = BangumiSubjectSearchSort.match,
    String? proxyUrl,
  }) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <BangumiSubject>[];

    final _BangumiResolvedRequest request =
        await _resolvedRequest(_subjectSearchPath, const <String, String>{
      'limit': '$bangumiApiDefaultSearchLimit',
      'offset': '$bangumiApiDefaultSearchOffset',
    });
    final Object? json = await _sendJson(
      'POST',
      request.uri,
      proxyUrl: proxyUrl,
      body: _animeSubjectSearchBody(
        keyword: normalizedQuery,
        sort: _apiSubjectSearchSort(sort),
      ),
    );
    return _subjectsFromJsonList(
      json,
      missingDataMessage: 'Bangumi subject search response missing data list.',
      itemLabel: 'Bangumi search subject',
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<List<BangumiSubject>> recentPopularAnime({
    required DateTime now,
    int limit = bangumiApiRecentPopularAnimeLimit,
    int offset = bangumiApiRecentPopularAnimeOffset,
    String? proxyUrl,
  }) async {
    final _BangumiAirDateRange airDateRange =
        _recentPopularAnimeAirDateRange(now);
    final _BangumiResolvedRequest request = await _resolvedRequest(
      _subjectSearchPath,
      <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final Object? json = await _sendJson(
      'POST',
      request.uri,
      proxyUrl: proxyUrl,
      body: _animeSubjectSearchBody(
        sort: bangumiApiRecentPopularAnimeSort,
        airDateFilters: airDateRange.filters,
      ),
    );
    return _subjectsFromJsonList(
      json,
      missingDataMessage:
          'Bangumi recent popular anime response missing data list.',
      itemLabel: 'Bangumi recent popular subject',
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<List<BangumiSubject>> trendingAnime({
    int limit = bangumiTrendsHeroLimit,
    int offset = bangumiTrendsBrowserInitialOffset,
    String? proxyUrl,
  }) async {
    final int page = _trendsPageForWindow(limit: limit, offset: offset);
    final _BangumiResolvedRequest request = await _resolvedWebRequest(
      _animeBrowserPath,
      _trendsBrowserQueryParameters(page),
    );
    final String html = await _sendText(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _trendingAnimeSubjectsFromHtml(
      html,
      limit: limit,
      missingDataMessage:
          'Bangumi trending anime page did not contain subject entries.',
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<BangumiEpisode> lookupEpisode(
    BangumiEpisodeId id, {
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_lookupEpisodePath(id));
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _episodeFromJson(_jsonObject(json, 'Bangumi episode'));
  }

  Future<List<BangumiEpisode>> listEpisodes(
    BangumiSubjectId subjectId, {
    String? proxyUrl,
  }) async {
    final List<BangumiEpisode> episodes = <BangumiEpisode>[];
    int offset = bangumiApiEpisodeInitialOffset;
    int? total;
    while (total == null || offset < total) {
      final _BangumiEpisodePage page = await _episodePage(
        subjectId: subjectId,
        offset: offset,
        proxyUrl: proxyUrl,
      );
      total = page.total;
      episodes.addAll(page.episodes);
      if (page.episodes.length < page.limit) break;
      offset += page.limit;
    }
    episodes.sort(
      (BangumiEpisode left, BangumiEpisode right) =>
          left.index.compareTo(right.index),
    );
    return List<BangumiEpisode>.unmodifiable(episodes);
  }

  Future<List<BangumiRelatedPerson>> listSubjectPersons(
    BangumiSubjectId subjectId, {
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_subjectPersonsPath(subjectId));
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _relatedPersonsFromJson(
      json,
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<List<BangumiRelatedCharacter>> listSubjectCharacters(
    BangumiSubjectId subjectId, {
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_subjectCharactersPath(subjectId));
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _relatedCharactersFromJson(
      json,
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<List<BangumiRelatedSubject>> listSubjectRelations(
    BangumiSubjectId subjectId, {
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_subjectRelationsPath(subjectId));
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    return _relatedSubjectsFromJson(
      json,
      imageUriRewriter: request.rewriteImageUri,
    );
  }

  Future<_BangumiEpisodePage> _episodePage({
    required BangumiSubjectId subjectId,
    required int offset,
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request = await _resolvedRequest(
      _episodeListPath,
      <String, String>{
        'subject_id': subjectId.value,
        'limit': '$bangumiApiEpisodePageLimit',
        'offset': '$offset',
      },
    );
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object =
        _jsonObject(json, 'Bangumi episode page');
    final Object? data = object['data'];
    if (data is! List<Object?>) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi episode list response missing data list.',
      );
    }
    return _BangumiEpisodePage(
      total: _optionalNonNegativeInt(object['total'], fallback: data.length),
      limit: _optionalPositiveInt(
        object['limit'],
        fallback: bangumiApiEpisodePageLimit,
      ),
      episodes: data
          .map(
            (Object? value) =>
                _episodeFromJson(_jsonObject(value, 'Bangumi episode')),
          )
          .toList(growable: false),
    );
  }

  Future<BangumiAuthSession> currentSession({
    required BangumiApiAccessToken token,
    required DateTime now,
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_currentSessionPath);
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      token: token,
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object = _jsonObject(json, 'Bangumi user');
    final String userId = _firstNonEmptyString(<Object?>[
      object['username'],
      object['id'],
      object['nickname'],
    ]);
    if (userId.isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi current user response missing id.',
      );
    }
    return BangumiAuthSession(
      userId: userId,
      expiresAt: token.expiresAt ?? now.add(bangumiApiSessionProjectionTtl),
      displayName: _firstNonEmptyString(<Object?>[
        object['nickname'],
        object['username'],
        object['id'],
      ]),
      avatarUri: _avatarUriFromJson(
        object['avatar'],
        imageUriRewriter: request.rewriteImageUri,
      ),
    );
  }

  Future<List<BangumiAnimeCollectionItem>> currentAnimeCollection({
    required BangumiApiAccessToken token,
    required DateTime now,
    String? proxyUrl,
  }) async {
    final BangumiAuthSession session = await currentSession(
      token: token,
      now: now,
      proxyUrl: proxyUrl,
    );
    final List<BangumiAnimeCollectionItem> items =
        <BangumiAnimeCollectionItem>[];
    int offset = bangumiApiCollectionInitialOffset;
    int? total;
    while (total == null || offset < total) {
      final _BangumiCollectionPage page = await _animeCollectionPage(
        username: session.userId,
        token: token,
        offset: offset,
        proxyUrl: proxyUrl,
      );
      total = page.total;
      items.addAll(page.items);
      if (page.items.length < page.limit) break;
      offset += page.limit;
    }
    return List<BangumiAnimeCollectionItem>.unmodifiable(items);
  }

  Future<_BangumiCollectionPage> _animeCollectionPage({
    required String username,
    required BangumiApiAccessToken token,
    required int offset,
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request = await _resolvedRequest(
      _currentAnimeCollectionPath(username),
      <String, String>{
        'subject_type': '$bangumiAnimeSubjectType',
        'limit': '$bangumiApiCollectionPageLimit',
        'offset': '$offset',
      },
    );
    final Object? json = await _sendJson(
      'GET',
      request.uri,
      token: token,
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object =
        _jsonObject(json, 'Bangumi collection page');
    final Object? data = object['data'];
    if (data is! List<Object?>) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi collection response missing data list.',
      );
    }
    return _BangumiCollectionPage(
      total: _optionalNonNegativeInt(object['total'], fallback: data.length),
      limit: _optionalPositiveInt(
        object['limit'],
        fallback: bangumiApiCollectionPageLimit,
      ),
      items: data
          .map(
            (Object? value) => _collectionItemFromJson(
              _jsonObject(value, 'Bangumi collection item'),
              imageUriRewriter: request.rewriteImageUri,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> syncProgress({
    required BangumiProgressUpdate update,
    required BangumiApiAccessToken token,
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_syncProgressPath(update));
    await _sendJson(
      'PUT',
      request.uri,
      token: token,
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'type': _episodeCollectionType(update.state),
      },
      allowEmptySuccessBody: true,
    );
  }

  Future<void> syncSubjectCollection({
    required BangumiSubjectCollectionUpdate update,
    required BangumiApiAccessToken token,
    String? proxyUrl,
  }) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(_syncSubjectCollectionPath(update));
    await _sendJson(
      'POST',
      request.uri,
      token: token,
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'type': _subjectCollectionType(update.status),
      },
      allowEmptySuccessBody: true,
    );
  }

  Future<Object?> _sendJson(
    String method,
    Uri uri, {
    BangumiApiAccessToken? token,
    Map<String, Object?>? body,
    bool allowEmptySuccessBody = false,
    String? proxyUrl,
  }) async {
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final BangumiApiResponse response = await _transport.send(
      BangumiApiRequest(
        method: method,
        uri: uri,
        headers: _headers(
          token: token,
          hasBody: encodedBody != null,
          accept: 'application/json',
        ),
        body: encodedBody,
        proxyUrl: proxyUrl,
      ),
    );

    if (response.statusCode == HttpStatus.noContent) return null;
    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      _throwFailureForStatus(response);
    }
    if (response.body.trim().isEmpty) {
      if (allowEmptySuccessBody) return null;
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi API returned an empty response body.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi API returned malformed JSON: ${error.message}',
      );
    }
  }

  Future<String> _sendText(
    String method,
    Uri uri, {
    String? proxyUrl,
  }) async {
    final BangumiApiResponse response = await _transport.send(
      BangumiApiRequest(
        method: method,
        uri: uri,
        headers: _headers(
          token: null,
          hasBody: false,
          accept: 'text/html,application/xhtml+xml',
        ),
        proxyUrl: proxyUrl,
      ),
    );

    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      _throwFailureForStatus(response);
    }
    if (response.body.trim().isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi trends page returned an empty response body.',
      );
    }
    return response.body;
  }

  Map<String, String> _headers({
    required BangumiApiAccessToken? token,
    required bool hasBody,
    required String accept,
  }) {
    return <String, String>{
      HttpHeaders.acceptHeader: accept,
      HttpHeaders.userAgentHeader: _userAgent,
      if (hasBody)
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      if (token != null)
        HttpHeaders.authorizationHeader: 'Bearer ${token.value}',
    };
  }

  Uri _uri(String path, [Map<String, String> queryParameters = const {}]) {
    return _uriFromBase(_baseUri, path, queryParameters);
  }

  Uri _webUri(
    String path, [
    Map<String, String> queryParameters = const {},
  ]) {
    return _uriFromBase(defaultBangumiWebBaseUri, path, queryParameters);
  }

  Future<Uri> _effectiveUri(
    String path, [
    Map<String, String> queryParameters = const {},
  ]) async {
    final _BangumiResolvedRequest request =
        await _resolvedRequest(path, queryParameters);
    return request.uri;
  }

  Future<Uri> _effectiveWebUri(
    String path, [
    Map<String, String> queryParameters = const {},
  ]) async {
    final _BangumiResolvedRequest request =
        await _resolvedWebRequest(path, queryParameters);
    return request.uri;
  }

  Future<_BangumiResolvedRequest> _resolvedRequest(
    String path, [
    Map<String, String> queryParameters = const {},
  ]) async {
    final BangumiApiMirrorConfig config = await _activeMirrorConfig();
    final Uri apiBaseUri = config.enabled ? config.apiBaseUri! : _baseUri;
    return _BangumiResolvedRequest(
      uri: _uriFromBase(apiBaseUri, path, queryParameters),
      imageBaseUri: config.enabled ? config.imageBaseUri : null,
    );
  }

  Future<_BangumiResolvedRequest> _resolvedWebRequest(
    String path, [
    Map<String, String> queryParameters = const {},
  ]) async {
    final BangumiApiMirrorConfig config = await _activeMirrorConfig();
    return _BangumiResolvedRequest(
      uri: _uriFromBase(defaultBangumiWebBaseUri, path, queryParameters),
      imageBaseUri: config.enabled ? config.imageBaseUri : null,
    );
  }

  Future<BangumiApiMirrorConfig> _activeMirrorConfig() async {
    final BangumiMirrorConfigProvider? provider = _mirrorConfigProvider;
    if (provider == null) return const BangumiApiMirrorConfig.disabled();

    final BangumiApiMirrorConfig config = await provider();
    if (!config.enabled) return const BangumiApiMirrorConfig.disabled();

    final Uri? apiBaseUri = config.apiBaseUri;
    final Uri? imageBaseUri = config.imageBaseUri;
    // Mirror URLs are user/operator configuration, but they still need a hard
    // shape check here. Allowing query/fragment on a base URI would make every
    // request ambiguous and weaken ProviderGateway network-policy accounting.
    if (!_isMirrorBaseUri(apiBaseUri) || !_isMirrorBaseUri(imageBaseUri)) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message:
            'Bangumi mirror configuration is invalid: mirror URLs must be absolute http or https URLs without query or fragment.',
      );
    }
    return config;
  }
}

final class _BangumiResolvedRequest {
  const _BangumiResolvedRequest({
    required this.uri,
    required this.imageBaseUri,
  });

  final Uri uri;
  final Uri? imageBaseUri;

  Uri rewriteImageUri(Uri original) {
    final Uri? baseUri = imageBaseUri;
    final String originalHost = original.host.toLowerCase();
    if (baseUri == null || !bangumiMirrorImageHosts.contains(originalHost)) {
      return original;
    }
    // Rewrite only Bangumi-owned image hosts. The image mirror endpoint is not
    // a general URL proxy, so third-party URLs stay untouched.
    return baseUri.replace(
      queryParameters: <String, String>{
        bangumiMirrorImageUrlParameter: original.toString(),
      },
    );
  }
}

Uri _uriFromBase(
  Uri baseUri,
  String path, [
  Map<String, String> queryParameters = const {},
]) {
  return baseUri.replace(
    path: _joinedPath(baseUri.path, path),
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
}

bool _isMirrorBaseUri(Uri? uri) {
  if (uri == null) return false;
  final bool isHttp = uri.scheme == 'https' || uri.scheme == 'http';
  return isHttp && uri.host.isNotEmpty && !uri.hasQuery && !uri.hasFragment;
}

const String _subjectSearchPath = '/v0/search/subjects';
const String _animeBrowserPath = '/anime/browser/';
const String _episodeListPath = '/v0/episodes';
const String _currentSessionPath = '/v0/me';

Map<String, String> _trendsBrowserQueryParameters(int page) {
  return <String, String>{
    'sort': bangumiTrendsBrowserSort,
    if (page > 1) 'page': '$page',
  };
}

int _trendsPageForWindow({
  required int limit,
  required int offset,
}) {
  if (limit <= 0 ||
      limit > bangumiTrendsBrowserPageSize ||
      offset < 0 ||
      (offset != 0 && offset % bangumiTrendsBrowserPageSize != 0)) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message:
          'Bangumi trends requests must use a positive limit within one browser page and page-aligned offsets.',
    );
  }
  return (offset ~/ bangumiTrendsBrowserPageSize) + 1;
}

String _lookupSubjectPath(BangumiSubjectId id) {
  return '/v0/subjects/${Uri.encodeComponent(id.value)}';
}

String _lookupEpisodePath(BangumiEpisodeId id) {
  return '/v0/episodes/${Uri.encodeComponent(id.value)}';
}

String _subjectPersonsPath(BangumiSubjectId subjectId) {
  return '/v0/subjects/${Uri.encodeComponent(subjectId.value)}/persons';
}

String _subjectCharactersPath(BangumiSubjectId subjectId) {
  return '/v0/subjects/${Uri.encodeComponent(subjectId.value)}/characters';
}

String _subjectRelationsPath(BangumiSubjectId subjectId) {
  return '/v0/subjects/${Uri.encodeComponent(subjectId.value)}/subjects';
}

String _currentAnimeCollectionPath(String username) {
  return '/v0/users/${Uri.encodeComponent(username)}/collections';
}

String _syncProgressPath(BangumiProgressUpdate update) {
  return '/v0/users/-/collections/-/episodes/'
      '${Uri.encodeComponent(update.episodeId.value)}';
}

String _syncSubjectCollectionPath(BangumiSubjectCollectionUpdate update) {
  return '/v0/users/-/collections/'
      '${Uri.encodeComponent(update.subjectId.value)}';
}

String _joinedPath(String basePath, String path) {
  final String normalizedBase = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  return '$normalizedBase$path';
}

final class BangumiApiProvider
    implements
        BangumiProvider,
        BangumiAuthProvider,
        BangumiSubjectCollectionSyncProvider,
        BangumiCollectionProvider,
        BangumiDiscoveryProvider,
        GatewayBoundProvider {
  BangumiApiProvider({
    required this.gateway,
    required BangumiApiClient client,
    BangumiAccessTokenProvider? accessTokenProvider,
    DateTime Function()? now,
  })  : _client = client,
        _accessTokenProvider = accessTokenProvider,
        _now = now;

  final BangumiApiClient _client;
  final BangumiAccessTokenProvider? _accessTokenProvider;
  final DateTime Function()? _now;
  final Map<String, BangumiSubject> _subjectCache = <String, BangumiSubject>{};

  @override
  final ProviderGateway gateway;

  @override
  String get id => bangumiProviderId.value;

  @override
  String get displayName => 'Bangumi API';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => bangumiProviderRegistration();

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: bangumiProviderId,
      cacheKey: cacheKey,
    );
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return gateway.execute<T>(
      bangumiGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(
    BangumiSubjectId id,
  ) async {
    final AcgProviderResult<BangumiSubject> result =
        await _execute<BangumiSubject>(
      key: bangumiSubjectRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.lookupSubjectNetworkPolicyUri(id),
      load: (ProviderGatewayRequestContext context) =>
          _client.lookupSubject(id, proxyUrl: context.proxyUrl),
    );
    if (result is AcgProviderSuccess<BangumiSubject>) {
      _rememberSubject(result.value);
      return result;
    }
    if (result is AcgProviderFailure<BangumiSubject> &&
        _canFallbackToCachedSubject(result.kind)) {
      final BangumiSubject? cached = _subjectCache[id.value];
      if (cached != null) return AcgProviderSuccess<BangumiSubject>(cached);
    }
    return result;
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query, {
    BangumiSubjectSearchSort sort = BangumiSubjectSearchSort.match,
  }) async {
    final AcgProviderResult<List<BangumiSubject>> result =
        await _execute<List<BangumiSubject>>(
      key: bangumiSubjectSearchRequestKey(query, sort: sort),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.searchSubjectsNetworkPolicyUri(),
      load: (ProviderGatewayRequestContext context) => _client.searchSubjects(
        query,
        sort: sort,
        proxyUrl: context.proxyUrl,
      ),
    );
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      _rememberSubjects(result.value);
    }
    return result;
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> trendingAnime({
    required int limit,
    required int offset,
  }) async {
    final DateTime now = (_now ?? DateTime.now)();
    final AcgProviderResult<List<BangumiSubject>> result =
        await _execute<List<BangumiSubject>>(
      key: bangumiTrendingAnimeRequestKey(
        now: now,
        limit: limit,
        offset: offset,
      ),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.trendingAnimeNetworkPolicyUri(
        limit: limit,
        offset: offset,
      ),
      load: (ProviderGatewayRequestContext context) => _client.trendingAnime(
        limit: limit,
        offset: offset,
        proxyUrl: context.proxyUrl,
      ),
    );
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      _rememberSubjects(result.value);
    }
    return result;
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> recentPopularAnime({
    required int limit,
    required int offset,
  }) async {
    final DateTime now = (_now ?? DateTime.now)();
    final AcgProviderResult<List<BangumiSubject>> result =
        await _execute<List<BangumiSubject>>(
      key: bangumiRecentPopularAnimeRequestKey(
        now: now,
        limit: limit,
        offset: offset,
      ),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.recentPopularAnimeNetworkPolicyUri(
        limit: limit,
        offset: offset,
      ),
      load: (ProviderGatewayRequestContext context) =>
          _client.recentPopularAnime(
        now: now,
        limit: limit,
        offset: offset,
        proxyUrl: context.proxyUrl,
      ),
    );
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      _rememberSubjects(result.value);
    }
    return result;
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
    BangumiEpisodeId id,
  ) async {
    return _execute<BangumiEpisode>(
      key: bangumiEpisodeRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.lookupEpisodeNetworkPolicyUri(id),
      load: (ProviderGatewayRequestContext context) =>
          _client.lookupEpisode(id, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) async {
    return _execute<List<BangumiEpisode>>(
      key: bangumiEpisodeListRequestKey(subjectId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri:
          _client.listEpisodesNetworkPolicyUri(subjectId: subjectId),
      load: (ProviderGatewayRequestContext context) =>
          _client.listEpisodes(subjectId, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedPerson>>> listSubjectPersons(
    BangumiSubjectId subjectId,
  ) async {
    return _execute<List<BangumiRelatedPerson>>(
      key: bangumiSubjectPersonsRequestKey(subjectId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.listSubjectPersonsNetworkPolicyUri(subjectId),
      load: (ProviderGatewayRequestContext context) =>
          _client.listSubjectPersons(subjectId, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedCharacter>>>
      listSubjectCharacters(
    BangumiSubjectId subjectId,
  ) async {
    return _execute<List<BangumiRelatedCharacter>>(
      key: bangumiSubjectCharactersRequestKey(subjectId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri:
          _client.listSubjectCharactersNetworkPolicyUri(subjectId),
      load: (ProviderGatewayRequestContext context) =>
          _client.listSubjectCharacters(subjectId, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedSubject>>> listSubjectRelations(
    BangumiSubjectId subjectId,
  ) async {
    return _execute<List<BangumiRelatedSubject>>(
      key: bangumiSubjectRelationsRequestKey(subjectId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.listSubjectRelationsNetworkPolicyUri(subjectId),
      load: (ProviderGatewayRequestContext context) =>
          _client.listSubjectRelations(subjectId, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<BangumiAuthSession>> currentSession() async {
    final BangumiApiAccessToken? token = await _activeToken();
    if (token == null) return _unauthenticated<BangumiAuthSession>();
    return _execute<BangumiAuthSession>(
      key: bangumiSessionRequestKey(),
      cachePolicy: ProviderCachePolicy.networkOnly,
      deduplicationWindow: Duration.zero,
      networkPolicyUri: _client.currentSessionNetworkPolicyUri(),
      load: (ProviderGatewayRequestContext context) => _client.currentSession(
        token: token,
        now: (_now ?? DateTime.now)(),
        proxyUrl: context.proxyUrl,
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiAnimeCollectionItem>>>
      currentAnimeCollection() async {
    final BangumiApiAccessToken? token = await _activeToken();
    if (token == null) {
      return _unauthenticated<List<BangumiAnimeCollectionItem>>();
    }
    final AcgProviderResult<List<BangumiAnimeCollectionItem>> result =
        await _execute<List<BangumiAnimeCollectionItem>>(
      key: bangumiAnimeCollectionRequestKey(),
      cachePolicy: ProviderCachePolicy.networkOnly,
      deduplicationWindow: Duration.zero,
      networkPolicyUri:
          _client.currentAnimeCollectionNetworkPolicyUri(username: '-'),
      load: (ProviderGatewayRequestContext context) =>
          _client.currentAnimeCollection(
        token: token,
        now: (_now ?? DateTime.now)(),
        proxyUrl: context.proxyUrl,
      ),
    );
    if (result is AcgProviderSuccess<List<BangumiAnimeCollectionItem>>) {
      _rememberCollectionItems(result.value);
    }
    return result;
  }

  @override
  Future<AcgProviderResult<void>> syncProgress(
    BangumiProgressUpdate update,
  ) async {
    final BangumiApiAccessToken? token = await _activeToken();
    if (token == null) return _unauthenticated<void>();
    return _execute<void>(
      key: bangumiProgressRequestKey(update),
      cachePolicy: ProviderCachePolicy.networkOnly,
      networkPolicyUri: _client.syncProgressNetworkPolicyUri(update),
      load: (ProviderGatewayRequestContext context) => _client.syncProgress(
        update: update,
        token: token,
        proxyUrl: context.proxyUrl,
      ),
    );
  }

  @override
  Future<AcgProviderResult<void>> syncSubjectCollection(
    BangumiSubjectCollectionUpdate update,
  ) async {
    final BangumiApiAccessToken? token = await _activeToken();
    if (token == null) return _unauthenticated<void>();
    return _execute<void>(
      key: bangumiSubjectCollectionSyncRequestKey(update),
      cachePolicy: ProviderCachePolicy.networkOnly,
      networkPolicyUri: _client.syncSubjectCollectionNetworkPolicyUri(update),
      load: (ProviderGatewayRequestContext context) =>
          _client.syncSubjectCollection(
        update: update,
        token: token,
        proxyUrl: context.proxyUrl,
      ),
    );
  }

  Future<AcgProviderResult<T>> _execute<T>({
    required ProviderRequestKey key,
    required Future<T> Function(ProviderGatewayRequestContext context) load,
    required ProviderCachePolicy cachePolicy,
    required Future<Uri> networkPolicyUri,
    Duration deduplicationWindow = bangumiRuntimeDeduplicationWindow,
  }) async {
    try {
      final Uri resolvedNetworkPolicyUri = await networkPolicyUri;
      final ProviderGatewayResponse<T> response = await gateway.execute<T>(
        bangumiGatewayRequest<T>(
          key: key,
          load: () => load(const ProviderGatewayRequestContext()),
          loadWithContext: load,
          cachePolicy: cachePolicy,
          deduplicationWindow: deduplicationWindow,
          networkPolicyUri: resolvedNetworkPolicyUri,
        ),
      );
      return AcgProviderSuccess<T>(response.value);
    } on _BangumiApiUnauthenticated catch (failure) {
      return AcgProviderFailure<T>(
        kind: AcgProviderFailureKind.unauthenticated,
        message: failure.message,
      );
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<T>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    } on IOException catch (failure) {
      return AcgProviderFailure<T>(
        kind: AcgProviderFailureKind.retryable,
        message: 'Bangumi API network request failed: $failure',
      );
    }
  }

  void _rememberSubject(BangumiSubject subject) {
    _subjectCache[subject.id.value] = subject;
  }

  void _rememberSubjects(Iterable<BangumiSubject> subjects) {
    for (final BangumiSubject subject in subjects) {
      _rememberSubject(subject);
    }
  }

  void _rememberCollectionItems(Iterable<BangumiAnimeCollectionItem> items) {
    for (final BangumiAnimeCollectionItem item in items) {
      _rememberSubject(
        BangumiSubject(
          id: item.subjectId,
          title: item.title,
          coverUri: item.coverUri,
          episodeCount: item.totalEpisodes,
        ),
      );
    }
  }

  bool _canFallbackToCachedSubject(AcgProviderFailureKind kind) {
    return switch (kind) {
      AcgProviderFailureKind.retryable ||
      AcgProviderFailureKind.throttled ||
      AcgProviderFailureKind.unavailable =>
        true,
      AcgProviderFailureKind.unauthenticated ||
      AcgProviderFailureKind.cachedMiss ||
      AcgProviderFailureKind.notFound ||
      AcgProviderFailureKind.terminal =>
        false,
    };
  }

  Future<BangumiApiAccessToken?> _activeToken() async {
    final BangumiApiAccessToken? token = await _accessTokenProvider?.call();
    if (token == null || token.isExpiredAt((_now ?? DateTime.now)())) {
      return null;
    }
    return token;
  }

  AcgProviderFailure<T> _unauthenticated<T>() {
    return AcgProviderFailure<T>(
      kind: AcgProviderFailureKind.unauthenticated,
      message: 'Bangumi API request requires an active access token.',
    );
  }
}

Map<String, Object?> _jsonObject(Object? value, String label) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((Object? key, Object? value) =>
        MapEntry<String, Object?>('$key', value));
  }
  throw ProviderFailure(
    kind: ProviderFailureKind.terminal,
    message: '$label response was not a JSON object.',
  );
}

Map<String, Object?> _animeSubjectSearchBody({
  required String sort,
  String? keyword,
  List<String> airDateFilters = const <String>[],
}) {
  return <String, Object?>{
    if (keyword != null) 'keyword': keyword,
    'sort': sort,
    'filter': <String, Object?>{
      'type': const <int>[bangumiAnimeSubjectType],
      if (airDateFilters.isNotEmpty) 'air_date': airDateFilters,
    },
  };
}

String _apiSubjectSearchSort(BangumiSubjectSearchSort sort) {
  return switch (sort) {
    BangumiSubjectSearchSort.match => bangumiApiSubjectSearchMatchSort,
    BangumiSubjectSearchSort.heat => bangumiApiSubjectSearchHeatSort,
  };
}

List<BangumiSubject> _subjectsFromJsonList(
  Object? json, {
  required String missingDataMessage,
  required String itemLabel,
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final Object? data = switch (json) {
    final Map<String, Object?> object => object['data'],
    final List<Object?> list => list,
    _ => null,
  };
  if (data is! List<Object?>) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: missingDataMessage,
    );
  }
  return data
      .map(
        (Object? value) => _subjectFromJson(
          _jsonObject(value, itemLabel),
          imageUriRewriter: imageUriRewriter,
        ),
      )
      .toList(growable: false);
}

_BangumiAirDateRange _recentPopularAnimeAirDateRange(DateTime now) {
  return _animeTrailingDayAirDateRange(
    now: now,
    windowDays: bangumiRecentPopularAnimeWindowDays,
  );
}

_BangumiAirDateRange _animeTrailingDayAirDateRange({
  required DateTime now,
  required int windowDays,
}) {
  assert(windowDays > 0, 'Bangumi air date day window must be positive.');
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime endExclusive = today.add(const Duration(days: 1));
  final DateTime start = endExclusive.subtract(Duration(days: windowDays));
  return _BangumiAirDateRange(
    startDate: _bangumiDate(start),
    endExclusiveDate: _bangumiDate(endExclusive),
  );
}

String _bangumiDate(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

List<BangumiSubject> _trendingAnimeSubjectsFromHtml(
  String html, {
  required int limit,
  required String missingDataMessage,
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final html_dom.Document document = html_parser.parse(html);
  final List<html_dom.Element> entries = _trendingAnimeEntryElements(document);
  if (entries.isEmpty) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: missingDataMessage,
    );
  }
  return entries
      .take(limit)
      .map(
        (html_dom.Element element) => _trendingAnimeSubjectFromElement(
          element,
          imageUriRewriter: imageUriRewriter,
        ),
      )
      .toList(growable: false);
}

List<html_dom.Element> _trendingAnimeEntryElements(
  html_dom.Document document,
) {
  final List<html_dom.Element> browserItems = document
      .querySelectorAll('#browserItemList li')
      .where((html_dom.Element element) => element.id.startsWith('item_'))
      .toList(growable: false);
  if (browserItems.isNotEmpty) return browserItems;
  return document
      .querySelectorAll('.featuredItems .mainItem')
      .toList(growable: false);
}

BangumiSubject _trendingAnimeSubjectFromElement(
  html_dom.Element element, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String? subjectId = _subjectIdFromTrendElement(element);
  if (subjectId == null || subjectId.isEmpty) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Bangumi trends entry missing subject id.',
    );
  }
  final String title = _trendTitleFromElement(element);
  if (title.isEmpty) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Bangumi trends entry $subjectId missing title.',
    );
  }

  final Uri? coverUri = _trendCoverUriFromElement(element);
  final Uri? rewrittenCoverUri =
      coverUri == null ? null : imageUriRewriter?.call(coverUri) ?? coverUri;
  final String summary = _normalizedText(
    element.querySelector('.info.tip')?.text,
  );

  return BangumiSubject(
    id: BangumiSubjectId(subjectId),
    title: title,
    summary: summary.isEmpty ? null : summary,
    coverUri: rewrittenCoverUri,
    rank: _firstIntegerFromText(element.querySelector('.rank')?.text),
    score: double.tryParse(
      _normalizedText(element.querySelector('.rateInfo small.fade')?.text),
    ),
    collectionTotal: _trendCollectionTotalFromElement(element),
    episodeCount: _episodeCountFromInfo(summary),
  );
}

String? _subjectIdFromTrendElement(html_dom.Element element) {
  if (element.id.startsWith('item_')) {
    final String id = element.id.substring('item_'.length).trim();
    if (id.isNotEmpty) return id;
  }
  for (final html_dom.Element anchor
      in element.querySelectorAll('a[href*="/subject/"]')) {
    final String? id = _subjectIdFromHref(anchor.attributes['href']);
    if (id != null) return id;
  }
  return null;
}

String? _subjectIdFromHref(String? href) {
  final String normalizedHref = _normalizedText(href);
  if (normalizedHref.isEmpty) return null;
  final Uri? uri = Uri.tryParse(normalizedHref);
  final List<String> segments = uri?.pathSegments ?? const <String>[];
  final int subjectSegment = segments.indexOf('subject');
  if (subjectSegment < 0 || subjectSegment + 1 >= segments.length) {
    return null;
  }
  final String id = segments[subjectSegment + 1].trim();
  return id.isEmpty ? null : id;
}

String _trendTitleFromElement(html_dom.Element element) {
  final html_dom.Element? anchor = element.querySelector('h3 a.l') ??
      element.querySelector('p.title a.l') ??
      element.querySelector('a[href*="/subject/"]');
  final String text = _normalizedText(anchor?.text);
  if (text.isNotEmpty) return text;
  return _normalizedText(anchor?.attributes['title']);
}

Uri? _trendCoverUriFromElement(html_dom.Element element) {
  final html_dom.Element? image =
      element.querySelector('img.cover') ?? element.querySelector('img');
  final Uri? srcUri = _bangumiReferenceUri(image?.attributes['src']);
  if (srcUri != null) return srcUri;

  final html_dom.Element? imageBox = element.querySelector('.image');
  return _backgroundImageUri(imageBox?.attributes['style']);
}

Uri? _backgroundImageUri(String? style) {
  final String normalizedStyle = _normalizedText(style);
  if (normalizedStyle.isEmpty) return null;
  const String marker = 'url(';
  final int start = normalizedStyle.indexOf(marker);
  if (start < 0) return null;
  final int valueStart = start + marker.length;
  final int valueEnd = normalizedStyle.indexOf(')', valueStart);
  if (valueEnd <= valueStart) return null;
  final String raw = normalizedStyle
      .substring(valueStart, valueEnd)
      .replaceAll('"', '')
      .replaceAll("'", '')
      .trim();
  return _bangumiReferenceUri(raw);
}

Uri? _bangumiReferenceUri(String? rawUri) {
  final String value = _normalizedText(rawUri);
  if (value.isEmpty) return null;
  if (value.startsWith('//')) return Uri.tryParse('https:$value');
  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.hasScheme) return uri;
  return defaultBangumiWebBaseUri.resolveUri(uri);
}

int? _trendCollectionTotalFromElement(html_dom.Element element) {
  for (final html_dom.Element label in element.querySelectorAll('small.grey')) {
    final String text = _normalizedText(label.text);
    if (text.contains('关注')) return _firstIntegerFromText(text);
  }
  return null;
}

int? _episodeCountFromInfo(String text) {
  final int marker = text.indexOf('话');
  if (marker <= 0) return null;
  int start = marker;
  while (start > 0 && _isAsciiDigit(text.codeUnitAt(start - 1))) {
    start -= 1;
  }
  if (start == marker) return null;
  return int.tryParse(text.substring(start, marker));
}

int? _firstIntegerFromText(String? text) {
  final String value = _normalizedText(text);
  int start = -1;
  for (int index = 0; index < value.length; index += 1) {
    if (_isAsciiDigit(value.codeUnitAt(index))) {
      start = index;
      break;
    }
  }
  if (start < 0) return null;
  int end = start + 1;
  while (end < value.length && _isAsciiDigit(value.codeUnitAt(end))) {
    end += 1;
  }
  return int.tryParse(value.substring(start, end));
}

bool _isAsciiDigit(int codeUnit) {
  return codeUnit >= _asciiDigitZeroCodeUnit &&
      codeUnit <= _asciiDigitNineCodeUnit;
}

String _normalizedText(String? text) {
  return text?.replaceAll(_whitespacePattern, ' ').trim() ?? '';
}

List<BangumiRelatedPerson> _relatedPersonsFromJson(
  Object? json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final List<Object?> data =
      _jsonArray(json, 'Bangumi subject persons response');
  return data
      .map(
        (Object? value) => _relatedPersonFromJson(
          _jsonObject(value, 'Bangumi related person'),
          imageUriRewriter: imageUriRewriter,
        ),
      )
      .toList(growable: false);
}

List<BangumiRelatedCharacter> _relatedCharactersFromJson(
  Object? json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final List<Object?> data =
      _jsonArray(json, 'Bangumi subject characters response');
  return data
      .map(
        (Object? value) => _relatedCharacterFromJson(
          _jsonObject(value, 'Bangumi related character'),
          imageUriRewriter: imageUriRewriter,
        ),
      )
      .toList(growable: false);
}

List<BangumiRelatedSubject> _relatedSubjectsFromJson(
  Object? json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final List<Object?> data =
      _jsonArray(json, 'Bangumi subject relations response');
  return data
      .map(
        (Object? value) => _relatedSubjectFromJson(
          _jsonObject(value, 'Bangumi related subject'),
          imageUriRewriter: imageUriRewriter,
        ),
      )
      .toList(growable: false);
}

BangumiRelatedPerson _relatedPersonFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id = _requiredIdString(json['id'], 'Bangumi related person id');
  final String name = _firstNonEmptyString(<Object?>[
    json['name'],
    id,
  ]);
  final String relation = _firstNonEmptyString(<Object?>[
    json['relation'],
    'Staff',
  ]);
  return BangumiRelatedPerson(
    id: BangumiPersonId(id),
    name: name,
    relation: relation,
    imageUri: _avatarUriFromJson(
      json['images'],
      imageUriRewriter: imageUriRewriter,
    ),
    careers: _stringList(json['career']),
    episodeRange: _optionalString(json['eps']),
  );
}

BangumiRelatedCharacter _relatedCharacterFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id =
      _requiredIdString(json['id'], 'Bangumi related character id');
  final String name = _firstNonEmptyString(<Object?>[
    json['name'],
    id,
  ]);
  final String relation = _firstNonEmptyString(<Object?>[
    json['relation'],
    '角色',
  ]);
  final List<Object?> actors = _optionalArray(json['actors']);
  return BangumiRelatedCharacter(
    id: BangumiCharacterId(id),
    name: name,
    relation: relation,
    summary: _optionalString(json['summary']),
    imageUri: _avatarUriFromJson(
      json['images'],
      imageUriRewriter: imageUriRewriter,
    ),
    actors: actors
        .map(
          (Object? value) => _voiceActorFromJson(
            _jsonObject(value, 'Bangumi voice actor'),
            imageUriRewriter: imageUriRewriter,
          ),
        )
        .toList(growable: false),
  );
}

BangumiVoiceActor _voiceActorFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id = _requiredIdString(json['id'], 'Bangumi voice actor id');
  final String name = _firstNonEmptyString(<Object?>[
    json['name'],
    id,
  ]);
  return BangumiVoiceActor(
    id: BangumiPersonId(id),
    name: name,
    imageUri: _avatarUriFromJson(
      json['images'],
      imageUriRewriter: imageUriRewriter,
    ),
    careers: _stringList(json['career']),
  );
}

BangumiRelatedSubject _relatedSubjectFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id = _requiredIdString(json['id'], 'Bangumi related subject id');
  final String title = _firstNonEmptyString(<Object?>[
    json['name_cn'],
    json['name'],
    id,
  ]);
  final String relation = _firstNonEmptyString(<Object?>[
    json['relation'],
    '关联条目',
  ]);
  return BangumiRelatedSubject(
    id: BangumiSubjectId(id),
    title: title,
    relation: relation,
    coverUri: _avatarUriFromJson(
      json['images'],
      imageUriRewriter: imageUriRewriter,
    ),
    type: _optionalPositiveIntOrNull(json['type']),
  );
}

BangumiSubject _subjectFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id = _requiredIdString(json['id'], 'Bangumi subject id');
  final String title = _firstNonEmptyString(<Object?>[
    json['name_cn'],
    json['name'],
  ]);
  if (title.isEmpty) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Bangumi subject response missing title.',
    );
  }
  return BangumiSubject(
    id: BangumiSubjectId(id),
    title: title,
    summary: _optionalString(json['summary'] ?? json['short_summary']),
    coverUri: _avatarUriFromJson(
      json['images'] ?? json['image'],
      imageUriRewriter: imageUriRewriter,
    ),
    rank:
        _optionalPositiveIntOrNull(json['rank'] ?? _ratingValue(json, 'rank')),
    score: _optionalNonNegativeDouble(_ratingValue(json, 'score')),
    collectionTotal: _subjectCollectionTotal(json),
    episodeCount:
        _optionalNonNegativeIntOrNull(json['eps'] ?? json['total_episodes']),
  );
}

BangumiEpisode _episodeFromJson(Map<String, Object?> json) {
  final String id = _requiredIdString(json['id'], 'Bangumi episode id');
  final String subjectId =
      _requiredIdString(json['subject_id'], 'Bangumi episode subject id');
  final int index = _firstInt(<Object?>[
    json['ep'],
    json['sort'],
  ]);
  final String title = _firstNonEmptyString(<Object?>[
    json['name_cn'],
    json['name'],
  ]);
  return BangumiEpisode(
    id: BangumiEpisodeId(id),
    subjectId: BangumiSubjectId(subjectId),
    index: index,
    title: title.isEmpty ? 'Episode $index' : title,
  );
}

BangumiAnimeCollectionItem _collectionItemFromJson(
  Map<String, Object?> json, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String id =
      _requiredIdString(json['subject_id'], 'Bangumi collection subject id');
  final Map<String, Object?>? subject = _optionalJsonObject(json['subject']);
  final String title = _firstNonEmptyString(<Object?>[
    subject?['name_cn'],
    subject?['name'],
    json['subject_name_cn'],
    json['subject_name'],
    id,
  ]);
  return BangumiAnimeCollectionItem(
    subjectId: BangumiSubjectId(id),
    title: title,
    status: _subjectCollectionStatus(json['type']),
    watchedEpisodes: _optionalNonNegativeInt(json['ep_status']),
    totalEpisodes: _optionalNonNegativeInt(
      subject?['eps'] ?? subject?['total_episodes'],
    ),
    coverUri: _avatarUriFromJson(
      subject?['images'],
      imageUriRewriter: imageUriRewriter,
    ),
    updatedAt: _optionalDateTime(json['updated_at']),
  );
}

String _requiredIdString(Object? value, String label) {
  final String id = _stringValue(value);
  if (id.isEmpty) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: '$label missing from Bangumi API response.',
    );
  }
  return id;
}

String? _optionalString(Object? value) {
  final String text = _stringValue(value);
  return text.isEmpty ? null : text;
}

Map<String, Object?>? _optionalJsonObject(Object? value) {
  if (value == null) return null;
  return _jsonObject(value, 'Bangumi nested object');
}

List<Object?> _jsonArray(Object? value, String label) {
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  throw ProviderFailure(
    kind: ProviderFailureKind.terminal,
    message: '$label was not a JSON array.',
  );
}

List<Object?> _optionalArray(Object? value) {
  if (value == null) return const <Object?>[];
  return _jsonArray(value, 'Bangumi optional nested array');
}

List<String> _stringList(Object? value) {
  final List<Object?> values = _optionalArray(value);
  return values
      .map(_stringValue)
      .where((String text) => text.isNotEmpty)
      .toList(growable: false);
}

Object? _ratingValue(Map<String, Object?> json, String key) {
  final Object? directValue = json[key];
  if (directValue != null) return directValue;
  final Map<String, Object?>? rating = _optionalJsonObject(json['rating']);
  return rating?[key];
}

int? _subjectCollectionTotal(Map<String, Object?> json) {
  final int? direct = _optionalNonNegativeIntOrNull(json['collection_total']);
  if (direct != null) return direct;

  final Map<String, Object?>? collection =
      _optionalJsonObject(json['collection']);
  if (collection == null) return null;

  int total = 0;
  bool hasCount = false;
  for (final String key in const <String>[
    'wish',
    'collect',
    'doing',
    'on_hold',
    'dropped',
  ]) {
    final int? count = _optionalNonNegativeIntOrNull(collection[key]);
    if (count == null) continue;
    total += count;
    hasCount = true;
  }
  return hasCount ? total : null;
}

Uri? _avatarUriFromJson(
  Object? value, {
  BangumiImageUriRewriter? imageUriRewriter,
}) {
  final String text = switch (value) {
    final String raw => raw.trim(),
    final Map<String, Object?> object => _firstNonEmptyString(<Object?>[
        object['large'],
        object['common'],
        object['medium'],
        object['small'],
        object['grid'],
      ]),
    final Map<Object?, Object?> object => _firstNonEmptyString(<Object?>[
        object['large'],
        object['common'],
        object['medium'],
        object['small'],
        object['grid'],
      ]),
    _ => '',
  };
  if (text.isEmpty) return null;
  final Uri? uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return imageUriRewriter?.call(uri) ?? uri;
}

String _firstNonEmptyString(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String text = _stringValue(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _stringValue(Object? value) {
  return switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    final double number => number.toStringAsFixed(0),
    _ => '',
  };
}

int _firstInt(Iterable<Object?> values) {
  for (final Object? value in values) {
    final int? parsed = switch (value) {
      final int number => number,
      final double number => number.round(),
      final String text => int.tryParse(text),
      _ => null,
    };
    if (parsed != null) return parsed;
  }
  throw const ProviderFailure(
    kind: ProviderFailureKind.terminal,
    message: 'Bangumi episode response missing index.',
  );
}

int _optionalNonNegativeInt(Object? value, {int fallback = 0}) {
  final int? parsed = switch (value) {
    final int number => number,
    final double number => number.round(),
    final String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed < 0) return fallback;
  return parsed;
}

int? _optionalNonNegativeIntOrNull(Object? value) {
  final int? parsed = switch (value) {
    final int number => number,
    final double number => number.round(),
    final String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

int? _optionalPositiveIntOrNull(Object? value) {
  final int? parsed = _optionalNonNegativeIntOrNull(value);
  return parsed == null || parsed <= 0 ? null : parsed;
}

double? _optionalNonNegativeDouble(Object? value) {
  final double? parsed = switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

int _optionalPositiveInt(Object? value, {required int fallback}) {
  final int parsed = _optionalNonNegativeInt(value, fallback: fallback);
  return parsed > 0 ? parsed : fallback;
}

DateTime? _optionalDateTime(Object? value) {
  final String text = _stringValue(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

BangumiSubjectCollectionStatus _subjectCollectionStatus(Object? value) {
  return switch (_optionalNonNegativeInt(value)) {
    bangumiSubjectCollectionWish => BangumiSubjectCollectionStatus.planned,
    bangumiSubjectCollectionDone => BangumiSubjectCollectionStatus.completed,
    bangumiSubjectCollectionDoing => BangumiSubjectCollectionStatus.watching,
    bangumiSubjectCollectionOnHold => BangumiSubjectCollectionStatus.onHold,
    bangumiSubjectCollectionDropped => BangumiSubjectCollectionStatus.dropped,
    _ => throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi collection item has unknown collection type.',
      ),
  };
}

int _subjectCollectionType(BangumiSubjectCollectionStatus status) {
  return switch (status) {
    BangumiSubjectCollectionStatus.planned => bangumiSubjectCollectionWish,
    BangumiSubjectCollectionStatus.completed => bangumiSubjectCollectionDone,
    BangumiSubjectCollectionStatus.watching => bangumiSubjectCollectionDoing,
    BangumiSubjectCollectionStatus.onHold => bangumiSubjectCollectionOnHold,
    BangumiSubjectCollectionStatus.dropped => bangumiSubjectCollectionDropped,
  };
}

int _episodeCollectionType(BangumiProgressState state) {
  return switch (state) {
    BangumiProgressState.planned => bangumiEpisodeCollectionWish,
    BangumiProgressState.watching => bangumiEpisodeCollectionDone,
    BangumiProgressState.completed => bangumiEpisodeCollectionDone,
    // On-hold means paused, not abandoned: keep it as "want to watch" so a
    // paused series is never destructively flagged as dropped on Bangumi.
    BangumiProgressState.onHold => bangumiEpisodeCollectionWish,
    BangumiProgressState.dropped => bangumiEpisodeCollectionDropped,
  };
}

void _throwFailureForStatus(BangumiApiResponse response) {
  if (response.statusCode == HttpStatus.unauthorized ||
      response.statusCode == HttpStatus.forbidden) {
    throw _BangumiApiUnauthenticated(
      'Bangumi API authentication failed with HTTP ${response.statusCode}.',
    );
  }
  throw ProviderFailure(
    kind: _failureKindForStatus(response.statusCode),
    message: 'Bangumi API request failed with HTTP ${response.statusCode}.',
  );
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

final class _BangumiApiUnauthenticated implements Exception {
  const _BangumiApiUnauthenticated(this.message);

  final String message;
}

final class _BangumiAirDateRange {
  const _BangumiAirDateRange({
    required this.startDate,
    required this.endExclusiveDate,
  });

  final String startDate;
  final String endExclusiveDate;

  List<String> get filters => <String>[
        '>=$startDate',
        '<$endExclusiveDate',
      ];
}

final class _BangumiCollectionPage {
  const _BangumiCollectionPage({
    required this.total,
    required this.limit,
    required this.items,
  });

  final int total;
  final int limit;
  final List<BangumiAnimeCollectionItem> items;
}

final class _BangumiEpisodePage {
  const _BangumiEpisodePage({
    required this.total,
    required this.limit,
    required this.episodes,
  });

  final int total;
  final int limit;
  final List<BangumiEpisode> episodes;
}
