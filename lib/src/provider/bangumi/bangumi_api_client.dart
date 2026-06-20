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

const String defaultBangumiApiUserAgent = 'Celesteria/0.1';
const int bangumiApiDefaultSearchLimit = 20;
const int bangumiApiDefaultSearchOffset = 0;
const int bangumiAnimeSubjectType = 2;
const int bangumiEpisodeCollectionWish = 1;
const int bangumiEpisodeCollectionDone = 2;
const int bangumiEpisodeCollectionDropped = 3;
const Duration bangumiApiSessionProjectionTtl = Duration(minutes: 15);

final Uri defaultBangumiApiBaseUri = Uri.parse('https://api.bgm.tv');

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
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
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
    final HttpClientRequest httpRequest =
        await _httpClient.openUrl(request.method, request.uri);
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

  Future<BangumiSubject> lookupSubject(BangumiSubjectId id) async {
    final Object? json = await _sendJson(
      'GET',
      _uri('/v0/subjects/${Uri.encodeComponent(id.value)}'),
    );
    return _subjectFromJson(_jsonObject(json, 'Bangumi subject'));
  }

  Future<List<BangumiSubject>> searchSubjects(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <BangumiSubject>[];

    final Object? json = await _sendJson(
      'POST',
      _uri(
        '/v0/search/subjects',
        const <String, String>{
          'limit': '$bangumiApiDefaultSearchLimit',
          'offset': '$bangumiApiDefaultSearchOffset',
        },
      ),
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

  Future<BangumiEpisode> lookupEpisode(BangumiEpisodeId id) async {
    final Object? json = await _sendJson(
      'GET',
      _uri('/v0/episodes/${Uri.encodeComponent(id.value)}'),
    );
    return _episodeFromJson(_jsonObject(json, 'Bangumi episode'));
  }

  Future<BangumiAuthSession> currentSession({
    required BangumiApiAccessToken token,
    required DateTime now,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      _uri('/v0/me'),
      token: token,
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
    );
  }

  Future<void> syncProgress({
    required BangumiProgressUpdate update,
    required BangumiApiAccessToken token,
  }) async {
    await _sendJson(
      'PUT',
      _uri(
        '/v0/users/-/collections/-/episodes/'
        '${Uri.encodeComponent(update.episodeId.value)}',
      ),
      token: token,
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
  }) async {
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final BangumiApiResponse response = await _transport.send(
      BangumiApiRequest(
        method: method,
        uri: uri,
        headers: _headers(token: token, hasBody: encodedBody != null),
        body: encodedBody,
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
    final String basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      path: '$basePath$path',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
}

final class BangumiApiProvider
    implements BangumiProvider, BangumiAuthProvider, GatewayBoundProvider {
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
      load: () => _client.lookupSubject(id),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query,
  ) {
    return _execute<List<BangumiSubject>>(
      key: bangumiSubjectSearchRequestKey(query),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () => _client.searchSubjects(query),
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
    BangumiEpisodeId id,
  ) {
    return _execute<BangumiEpisode>(
      key: bangumiEpisodeRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () => _client.lookupEpisode(id),
    );
  }

  @override
  Future<AcgProviderResult<BangumiAuthSession>> currentSession() async {
    final BangumiApiAccessToken? token = await _activeToken();
    if (token == null) return _unauthenticated<BangumiAuthSession>();
    return _execute<BangumiAuthSession>(
      key: bangumiSessionRequestKey(),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () => _client.currentSession(
        token: token,
        now: (_now ?? DateTime.now)(),
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
      load: () => _client.syncProgress(update: update, token: token),
    );
  }

  Future<AcgProviderResult<T>> _execute<T>({
    required ProviderRequestKey key,
    required Future<T> Function() load,
    required ProviderCachePolicy cachePolicy,
  }) async {
    try {
      final ProviderGatewayResponse<T> response = await gateway.execute<T>(
        bangumiGatewayRequest<T>(
          key: key,
          load: load,
          cachePolicy: cachePolicy,
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
    summary: _optionalString(json['summary']),
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
