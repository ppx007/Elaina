import 'dart:convert';
import 'dart:io';

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
const int bangumiApiPopularAnimeLimit = 8;
const int bangumiApiPopularAnimeOffset = 0;
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

final Uri defaultBangumiApiBaseUri = Uri.parse('https://api.bgm.tv');
final Uri defaultBangumiAccessTokenPageUri =
    Uri.parse('https://next.bgm.tv/demo/access-token');

typedef BangumiAccessTokenProvider = Future<BangumiApiAccessToken?> Function();

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
        httpRequest.write(body);
      }

      final HttpClientResponse response = await httpRequest.close();
      final String responseBody = await response.transform(utf8.decoder).join();
      return BangumiApiResponse(
        statusCode: response.statusCode,
        body: responseBody,
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

final class BangumiApiClient {
  BangumiApiClient({
    required BangumiApiTransport transport,
    Uri? baseUri,
    String userAgent = defaultBangumiApiUserAgent,
  })  : _transport = transport,
        _baseUri = baseUri ?? defaultBangumiApiBaseUri,
        _userAgent = userAgent;

  final BangumiApiTransport _transport;
  final Uri _baseUri;
  final String _userAgent;

  Uri lookupSubjectRequestUri(BangumiSubjectId id) {
    return _uri('/v0/subjects/${Uri.encodeComponent(id.value)}');
  }

  Uri searchSubjectsRequestUri() {
    return _uri(
      '/v0/search/subjects',
      const <String, String>{
        'limit': '$bangumiApiDefaultSearchLimit',
        'offset': '$bangumiApiDefaultSearchOffset',
      },
    );
  }

  Uri popularAnimeRequestUri({
    int limit = bangumiApiPopularAnimeLimit,
    int offset = bangumiApiPopularAnimeOffset,
  }) {
    return _uri(
      '/v0/subjects',
      <String, String>{
        'type': '$bangumiAnimeSubjectType',
        'sort': 'rank',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Uri lookupEpisodeRequestUri(BangumiEpisodeId id) {
    return _uri('/v0/episodes/${Uri.encodeComponent(id.value)}');
  }

  Uri listEpisodesRequestUri({
    required BangumiSubjectId subjectId,
    int limit = bangumiApiEpisodePageLimit,
    int offset = bangumiApiEpisodeInitialOffset,
  }) {
    return _uri(
      '/v0/episodes',
      <String, String>{
        'subject_id': subjectId.value,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Uri currentSessionRequestUri() {
    return _uri('/v0/me');
  }

  Uri currentAnimeCollectionRequestUri({
    required String username,
    int limit = bangumiApiCollectionPageLimit,
    int offset = bangumiApiCollectionInitialOffset,
  }) {
    return _uri(
      '/v0/users/${Uri.encodeComponent(username)}/collections',
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

  Uri syncProgressRequestUri(BangumiProgressUpdate update) {
    return _uri(
      '/v0/users/-/collections/-/episodes/'
      '${Uri.encodeComponent(update.episodeId.value)}',
    );
  }

  Future<BangumiSubject> lookupSubject(
    BangumiSubjectId id, {
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      lookupSubjectRequestUri(id),
      proxyUrl: proxyUrl,
    );
    return _subjectFromJson(_jsonObject(json, 'Bangumi subject'));
  }

  Future<List<BangumiSubject>> searchSubjects(
    String query, {
    String? proxyUrl,
  }) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <BangumiSubject>[];

    final Object? json = await _sendJson(
      'POST',
      searchSubjectsRequestUri(),
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'keyword': normalizedQuery,
        'sort': 'match',
        'filter': const <String, Object?>{
          'type': <int>[bangumiAnimeSubjectType],
        },
      },
    );
    final Object? data = switch (json) {
      final Map<String, Object?> object => object['data'],
      final List<Object?> list => list,
      _ => null,
    };
    if (data is! List<Object?>) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi subject search response missing data list.',
      );
    }
    return data
        .map((Object? value) =>
            _subjectFromJson(_jsonObject(value, 'Bangumi search subject')))
        .toList(growable: false);
  }

  Future<List<BangumiSubject>> popularAnime({
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      popularAnimeRequestUri(),
      proxyUrl: proxyUrl,
    );
    final Object? data = switch (json) {
      final Map<String, Object?> object => object['data'],
      final List<Object?> list => list,
      _ => null,
    };
    if (data is! List<Object?>) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Bangumi popular anime response missing data list.',
      );
    }
    return data
        .map((Object? value) =>
            _subjectFromJson(_jsonObject(value, 'Bangumi popular subject')))
        .toList(growable: false);
  }

  Future<BangumiEpisode> lookupEpisode(
    BangumiEpisodeId id, {
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      lookupEpisodeRequestUri(id),
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

  Future<_BangumiEpisodePage> _episodePage({
    required BangumiSubjectId subjectId,
    required int offset,
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      listEpisodesRequestUri(subjectId: subjectId, offset: offset),
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
    final Object? json = await _sendJson(
      'GET',
      currentSessionRequestUri(),
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
      avatarUri: _avatarUriFromJson(object['avatar']),
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
    final Object? json = await _sendJson(
      'GET',
      currentAnimeCollectionRequestUri(username: username, offset: offset),
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
    await _sendJson(
      'PUT',
      syncProgressRequestUri(update),
      token: token,
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'type': _episodeCollectionType(update.state),
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
        headers: _headers(token: token, hasBody: encodedBody != null),
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

  Map<String, String> _headers({
    required BangumiApiAccessToken? token,
    required bool hasBody,
  }) {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.userAgentHeader: _userAgent,
      if (hasBody) HttpHeaders.contentTypeHeader: 'application/json',
      if (token != null)
        HttpHeaders.authorizationHeader: 'Bearer ${token.value}',
    };
  }

  Uri _uri(String path, [Map<String, String> queryParameters = const {}]) {
    return _baseUri.replace(
      path: _joinedPath(_baseUri.path, path),
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
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
  ) {
    return _execute<BangumiSubject>(
      key: bangumiSubjectRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.lookupSubjectRequestUri(id),
      load: (ProviderGatewayRequestContext context) =>
          _client.lookupSubject(id, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query,
  ) {
    return _execute<List<BangumiSubject>>(
      key: bangumiSubjectSearchRequestKey(query),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.searchSubjectsRequestUri(),
      load: (ProviderGatewayRequestContext context) =>
          _client.searchSubjects(query, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> popularAnime() {
    return _execute<List<BangumiSubject>>(
      key: bangumiPopularAnimeRequestKey(),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.popularAnimeRequestUri(),
      load: (ProviderGatewayRequestContext context) =>
          _client.popularAnime(proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
    BangumiEpisodeId id,
  ) {
    return _execute<BangumiEpisode>(
      key: bangumiEpisodeRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.lookupEpisodeRequestUri(id),
      load: (ProviderGatewayRequestContext context) =>
          _client.lookupEpisode(id, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    return _execute<List<BangumiEpisode>>(
      key: bangumiEpisodeListRequestKey(subjectId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.listEpisodesRequestUri(subjectId: subjectId),
      load: (ProviderGatewayRequestContext context) =>
          _client.listEpisodes(subjectId, proxyUrl: context.proxyUrl),
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
      networkPolicyUri: _client.currentSessionRequestUri(),
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
    return _execute<List<BangumiAnimeCollectionItem>>(
      key: bangumiAnimeCollectionRequestKey(),
      cachePolicy: ProviderCachePolicy.networkOnly,
      deduplicationWindow: Duration.zero,
      networkPolicyUri: _client.currentAnimeCollectionRequestUri(username: '-'),
      load: (ProviderGatewayRequestContext context) =>
          _client.currentAnimeCollection(
        token: token,
        now: (_now ?? DateTime.now)(),
        proxyUrl: context.proxyUrl,
      ),
    );
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
      networkPolicyUri: _client.syncProgressRequestUri(update),
      load: (ProviderGatewayRequestContext context) => _client.syncProgress(
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
    required Uri networkPolicyUri,
    Duration deduplicationWindow = bangumiRuntimeDeduplicationWindow,
  }) async {
    try {
      final ProviderGatewayResponse<T> response = await gateway.execute<T>(
        bangumiGatewayRequest<T>(
          key: key,
          load: () => load(const ProviderGatewayRequestContext()),
          loadWithContext: load,
          cachePolicy: cachePolicy,
          deduplicationWindow: deduplicationWindow,
          networkPolicyUri: networkPolicyUri,
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
    }
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

BangumiSubject _subjectFromJson(Map<String, Object?> json) {
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
    coverUri: _avatarUriFromJson(json['images']),
    rank: _optionalPositiveIntOrNull(json['rank']),
    score: _optionalNonNegativeDouble(_ratingValue(json, 'score')),
    collectionTotal: _optionalNonNegativeIntOrNull(json['collection_total']),
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
  Map<String, Object?> json,
) {
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
    coverUri: _avatarUriFromJson(subject?['images']),
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

Object? _ratingValue(Map<String, Object?> json, String key) {
  final Object? directValue = json[key];
  if (directValue != null) return directValue;
  final Map<String, Object?>? rating = _optionalJsonObject(json['rating']);
  return rating?[key];
}

Uri? _avatarUriFromJson(Object? value) {
  final String text = switch (value) {
    final String raw => raw.trim(),
    final Map<String, Object?> object => _firstNonEmptyString(<Object?>[
        object['large'],
        object['medium'],
        object['small'],
        object['grid'],
      ]),
    final Map<Object?, Object?> object => _firstNonEmptyString(<Object?>[
        object['large'],
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
  return uri;
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
