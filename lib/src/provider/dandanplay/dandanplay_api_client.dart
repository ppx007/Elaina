import 'dart:convert';
import 'dart:io';

import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../../foundation/security/outbound_uri_guard.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';
import 'dandanplay_comments.dart';
import 'dandanplay_provider.dart';
import 'dandanplay_registration.dart';
import 'dandanplay_runtime.dart';

/// dandanplay protocol constants kept near the wire mapper.
///
/// They are named even when the upstream API uses numeric modes so future
/// maintainers do not need to rediscover response-mode semantics from samples.
const String defaultDandanplayApiUserAgent = 'Elaina/0.1';
const String dandanplayMatchModeFileNameOnly = 'fileNameOnly';
const int dandanplayCommentsFromOffset = 0;
const bool dandanplayCommentsWithRelated = true;
const int dandanplayCommentsChineseConversionNone = 0;
const double dandanplayExactMatchConfidence = 1;
const double dandanplayFuzzyMatchConfidence = 0.85;
const double dandanplaySearchCandidateConfidence = 0.75;
const int dandanplayRequestModeScrolling = 1;
const int dandanplayRequestModeTop = 4;

/// Milliseconds per second, used when converting comment timestamps to/from
/// the dandanplay API's fractional-second `time` field.
const int dandanplayMillisecondsPerSecond = 1000;
const int dandanplayRequestModeBottom = 5;
const int dandanplayResponseModeScrolling = 1;
const int dandanplayResponseModeBottom = 4;
const int dandanplayResponseModeTop = 5;
const int dandanplayDefaultCommentColorArgb = 0x00ffffff;

final Uri defaultDandanplayApiBaseUri = Uri.parse('https://api.dandanplay.net');

typedef DandanplayCredentialProvider = Future<DandanplayApiCredentials?>
    Function();

final class DandanplayApiCredentials {
  const DandanplayApiCredentials({
    this.bearerToken,
    this.appId,
    this.appSecret,
  });

  final String? bearerToken;
  final String? appId;
  final String? appSecret;

  bool get canPostComment {
    return _hasText(bearerToken) || (_hasText(appId) && _hasText(appSecret));
  }
}

final class DandanplayApiRequest {
  const DandanplayApiRequest({
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

final class DandanplayApiResponse {
  const DandanplayApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class DandanplayApiTransport {
  Future<DandanplayApiResponse> send(DandanplayApiRequest request);
}

/// HTTP transport for dandanplay requests.
///
/// Proxy wiring lives here; endpoint construction, request signatures, and
/// response normalization stay in [DandanplayApiClient].
final class HttpDandanplayApiTransport implements DandanplayApiTransport {
  HttpDandanplayApiTransport({
    HttpClient? httpClient,
    OutboundUriGuard outboundGuard = const OutboundUriGuard(),
  })  : _httpClient = httpClient ?? HttpClient(),
        _outboundGuard = outboundGuard;

  final HttpClient _httpClient;
  final OutboundUriGuard _outboundGuard;

  @override
  Future<DandanplayApiResponse> send(DandanplayApiRequest request) async {
    final OutboundHostRisk? risk = _outboundGuard.classifyUri(request.uri);
    if (risk != null) {
      throw StateError(
          'Dandanplay request blocked by SSRF guard: ${risk.name} ${request.uri}');
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
      return DandanplayApiResponse(
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

final class DandanplayApiClient {
  DandanplayApiClient({
    required DandanplayApiTransport transport,
    Uri? baseUri,
    String userAgent = defaultDandanplayApiUserAgent,
  })  : _transport = transport,
        _baseUri = baseUri ?? defaultDandanplayApiBaseUri,
        _userAgent = userAgent;

  final DandanplayApiTransport _transport;
  final Uri _baseUri;
  final String _userAgent;

  Uri matchLocalMediaRequestUri() => _uri('/api/v2/match');

  Uri searchRequestUri(String query) {
    return _uri(
      '/api/v2/search/episodes',
      <String, String>{'anime': query.trim()},
    );
  }

  Uri commentsForEpisodeRequestUri(DandanplayEpisodeId episodeId) {
    return _uri(
      '/api/v2/comment/${Uri.encodeComponent(episodeId.value)}',
      const <String, String>{
        'from': '$dandanplayCommentsFromOffset',
        'withRelated': '$dandanplayCommentsWithRelated',
        'chConvert': '$dandanplayCommentsChineseConversionNone',
      },
    );
  }

  Uri postCommentRequestUri(DandanplayCommentPost post) {
    return _uri('/api/v2/comment/${Uri.encodeComponent(post.episodeId.value)}');
  }

  Future<List<DandanplayMatchCandidate>> matchLocalMedia(
    String filename, {
    String? proxyUrl,
  }) async {
    final String normalizedFilename = filename.trim();
    if (normalizedFilename.isEmpty) {
      return const <DandanplayMatchCandidate>[];
    }
    final Object? json = await _sendJson(
      'POST',
      matchLocalMediaRequestUri(),
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'fileName': normalizedFilename,
        'matchMode': dandanplayMatchModeFileNameOnly,
      },
    );
    final Map<String, Object?> object = _jsonObject(json, 'Dandanplay match');
    _throwIfApiFailure(object, 'Dandanplay match');
    final bool isMatched = object['isMatched'] == true;
    final List<Object?> matches =
        _jsonList(object['matches'], 'Dandanplay match results');
    return matches
        .map(
          (Object? value) => _matchCandidateFromMatchJson(
            _jsonObject(value, 'Dandanplay match result'),
            confidence: isMatched
                ? dandanplayExactMatchConfidence
                : dandanplayFuzzyMatchConfidence,
          ),
        )
        .toList(growable: false);
  }

  Future<List<DandanplayMatchCandidate>> search(
    String query, {
    String? proxyUrl,
  }) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <DandanplayMatchCandidate>[];
    }
    final Object? json = await _sendJson(
      'GET',
      searchRequestUri(normalizedQuery),
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object = _jsonObject(json, 'Dandanplay search');
    _throwIfApiFailure(object, 'Dandanplay search');
    final List<Object?> animes =
        _jsonList(object['animes'], 'Dandanplay search animes');
    final List<DandanplayMatchCandidate> candidates =
        <DandanplayMatchCandidate>[];
    for (final Object? animeValue in animes) {
      final Map<String, Object?> anime =
          _jsonObject(animeValue, 'Dandanplay search anime');
      final String animeId =
          _requiredIdString(anime['animeId'], 'Dandanplay anime id');
      final String animeTitle = _stringValue(anime['animeTitle']);
      final List<Object?> episodes =
          _jsonList(anime['episodes'], 'Dandanplay search episodes');
      for (final Object? episodeValue in episodes) {
        final Map<String, Object?> episode =
            _jsonObject(episodeValue, 'Dandanplay search episode');
        final String episodeId =
            _requiredIdString(episode['episodeId'], 'Dandanplay episode id');
        final String episodeTitle = _stringValue(episode['episodeTitle']);
        candidates.add(
          DandanplayMatchCandidate(
            animeId: DandanplayAnimeId(animeId),
            episodeId: DandanplayEpisodeId(episodeId),
            title: _candidateTitle(animeTitle, episodeTitle),
            confidence: dandanplaySearchCandidateConfidence,
          ),
        );
      }
    }
    return candidates;
  }

  Future<List<DandanplayComment>> commentsForEpisode(
    DandanplayEpisodeId episodeId, {
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      commentsForEpisodeRequestUri(episodeId),
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object =
        _jsonObject(json, 'Dandanplay comments');
    final List<Object?> comments =
        _jsonList(object['comments'], 'Dandanplay comments list');
    return comments
        .map((Object? value) =>
            _commentFromJson(_jsonObject(value, 'Dandanplay comment')))
        .toList(growable: false);
  }

  Future<void> postComment({
    required DandanplayCommentPost post,
    required DandanplayApiCredentials credentials,
    String? proxyUrl,
  }) async {
    await _sendJson(
      'POST',
      postCommentRequestUri(post),
      credentials: credentials,
      proxyUrl: proxyUrl,
      body: <String, Object?>{
        'time': post.comment.timestamp.inMilliseconds /
            dandanplayMillisecondsPerSecond,
        'mode': _requestMode(post.comment.mode),
        'color': post.comment.colorArgb ?? dandanplayDefaultCommentColorArgb,
        'comment': post.comment.text,
      },
      allowEmptySuccessBody: false,
    );
  }

  Future<Object?> _sendJson(
    String method,
    Uri uri, {
    DandanplayApiCredentials? credentials,
    Map<String, Object?>? body,
    bool allowEmptySuccessBody = false,
    String? proxyUrl,
  }) async {
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final DandanplayApiResponse response;
    try {
      response = await _transport.send(
        DandanplayApiRequest(
          method: method,
          uri: uri,
          headers:
              _headers(credentials: credentials, hasBody: encodedBody != null),
          body: encodedBody,
          proxyUrl: proxyUrl,
        ),
      );
    } on ProviderFailure {
      rethrow;
    } catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.retryable,
        message: 'Dandanplay API transport failed: $error',
      );
    }

    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      _throwFailureForStatus(response);
    }
    if (response.body.trim().isEmpty) {
      if (allowEmptySuccessBody) return null;
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Dandanplay API returned an empty response body.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Dandanplay API returned malformed JSON: ${error.message}',
      );
    }
  }

  Map<String, String> _headers({
    required DandanplayApiCredentials? credentials,
    required bool hasBody,
  }) {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.userAgentHeader: _userAgent,
      if (hasBody) HttpHeaders.contentTypeHeader: 'application/json',
      if (_hasText(credentials?.bearerToken))
        HttpHeaders.authorizationHeader: 'Bearer ${credentials!.bearerToken}',
      if (_hasText(credentials?.appId)) 'X-AppId': credentials!.appId!,
      if (_hasText(credentials?.appSecret))
        'X-AppSecret': credentials!.appSecret!,
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

final class DandanplayApiProvider
    implements
        DandanplayProvider,
        DandanplayCommentProvider,
        GatewayBoundProvider {
  DandanplayApiProvider({
    required this.gateway,
    required DandanplayApiClient client,
    DandanplayCredentialProvider? credentialProvider,
  })  : _client = client,
        _credentialProvider = credentialProvider;

  final DandanplayApiClient _client;
  final DandanplayCredentialProvider? _credentialProvider;

  @override
  final ProviderGateway gateway;

  @override
  String get id => dandanplayProviderId.value;

  @override
  String get displayName => 'Dandanplay API';

  @override
  ProviderKind get kind => ProviderKind.danmaku;

  @override
  ProviderRegistration get registration => dandanplayProviderRegistration();

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: dandanplayProviderId,
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
      dandanplayGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchLocalMedia(
    String filename,
  ) {
    return _execute<List<DandanplayMatchCandidate>>(
      key: dandanplayMatchRequestKey(filename),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.matchLocalMediaRequestUri(),
      load: (ProviderGatewayRequestContext context) =>
          _client.matchLocalMedia(filename, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> search(
    String query,
  ) {
    return _execute<List<DandanplayMatchCandidate>>(
      key: dandanplaySearchRequestKey(query),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.searchRequestUri(query),
      load: (ProviderGatewayRequestContext context) =>
          _client.search(query, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
    DandanplayEpisodeId episodeId,
  ) {
    return _execute<List<DandanplayComment>>(
      key: dandanplayCommentsRequestKey(episodeId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      networkPolicyUri: _client.commentsForEpisodeRequestUri(episodeId),
      load: (ProviderGatewayRequestContext context) =>
          _client.commentsForEpisode(episodeId, proxyUrl: context.proxyUrl),
    );
  }

  @override
  Future<AcgProviderResult<void>> postComment(
      DandanplayCommentPost post) async {
    final DandanplayApiCredentials? credentials =
        await _credentialProvider?.call();
    if (credentials == null || !credentials.canPostComment) {
      return AcgProviderFailure<void>(
        kind: AcgProviderFailureKind.unauthenticated,
        message: 'Dandanplay comment posting requires credentials.',
      );
    }
    return _execute<void>(
      key: dandanplayPostCommentRequestKey(post),
      cachePolicy: ProviderCachePolicy.networkOnly,
      networkPolicyUri: _client.postCommentRequestUri(post),
      load: (ProviderGatewayRequestContext context) => _client.postComment(
        post: post,
        credentials: credentials,
        proxyUrl: context.proxyUrl,
      ),
    );
  }

  Future<AcgProviderResult<T>> _execute<T>({
    required ProviderRequestKey key,
    required Future<T> Function(ProviderGatewayRequestContext context) load,
    required ProviderCachePolicy cachePolicy,
    required Uri networkPolicyUri,
  }) async {
    try {
      final ProviderGatewayResponse<T> response = await gateway.execute<T>(
        dandanplayGatewayRequest<T>(
          key: key,
          load: () => load(const ProviderGatewayRequestContext()),
          loadWithContext: load,
          cachePolicy: cachePolicy,
          networkPolicyUri: networkPolicyUri,
        ),
      );
      return AcgProviderSuccess<T>(response.value);
    } on _DandanplayApiUnauthenticated catch (failure) {
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

List<Object?> _jsonList(Object? value, String label) {
  if (value == null) return const <Object?>[];
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  throw ProviderFailure(
    kind: ProviderFailureKind.terminal,
    message: '$label response was not a JSON list.',
  );
}

DandanplayMatchCandidate _matchCandidateFromMatchJson(
  Map<String, Object?> json, {
  required double confidence,
}) {
  final String animeId =
      _requiredIdString(json['animeId'], 'Dandanplay anime id');
  final String episodeId =
      _requiredIdString(json['episodeId'], 'Dandanplay episode id');
  final String animeTitle = _stringValue(json['animeTitle']);
  final String episodeTitle = _stringValue(json['episodeTitle']);
  return DandanplayMatchCandidate(
    animeId: DandanplayAnimeId(animeId),
    episodeId: DandanplayEpisodeId(episodeId),
    title: _candidateTitle(animeTitle, episodeTitle),
    confidence: confidence,
  );
}

DandanplayComment _commentFromJson(Map<String, Object?> json) {
  final String params = _stringValue(json['p']);
  final List<String> parts = params.split(',');
  if (parts.length < 3) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Dandanplay comment parameter field is malformed.',
    );
  }
  final double? seconds = double.tryParse(parts[0]);
  final int? mode = int.tryParse(parts[1]);
  final int? color = int.tryParse(parts[2]);
  final String text = _stringValue(json['m']);
  if (seconds == null || mode == null || text.isEmpty) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'Dandanplay comment response missing required fields.',
    );
  }
  return DandanplayComment(
    timestamp: Duration(
        milliseconds: (seconds * dandanplayMillisecondsPerSecond).round()),
    text: text,
    mode: _responseMode(mode),
    colorArgb: color,
  );
}

void _throwIfApiFailure(Map<String, Object?> object, String label) {
  final Object? success = object['success'];
  if (success == null || success == true) return;
  final int errorCode = _intValue(object['errorCode']) ?? 0;
  final String message = _stringValue(object['errorMessage']);
  throw ProviderFailure(
    kind: errorCode == HttpStatus.tooManyRequests
        ? ProviderFailureKind.throttled
        : ProviderFailureKind.terminal,
    message: message.isEmpty
        ? '$label API response reported failure.'
        : '$label API response reported failure: $message',
  );
}

String _candidateTitle(String animeTitle, String episodeTitle) {
  if (animeTitle.isEmpty) {
    return episodeTitle.isEmpty ? 'Dandanplay match' : episodeTitle;
  }
  if (episodeTitle.isEmpty) {
    return animeTitle;
  }
  return '$animeTitle - $episodeTitle';
}

String _requiredIdString(Object? value, String label) {
  final String id = _stringValue(value);
  if (id.isEmpty) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: '$label missing from Dandanplay API response.',
    );
  }
  return id;
}

String _stringValue(Object? value) {
  return switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    final double number => number.toStringAsFixed(0),
    _ => '',
  };
}

int? _intValue(Object? value) {
  return switch (value) {
    final int number => number,
    final double number => number.round(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

int _requestMode(DandanplayCommentMode mode) {
  return switch (mode) {
    DandanplayCommentMode.scrolling => dandanplayRequestModeScrolling,
    DandanplayCommentMode.top => dandanplayRequestModeTop,
    DandanplayCommentMode.bottom => dandanplayRequestModeBottom,
  };
}

DandanplayCommentMode _responseMode(int mode) {
  return switch (mode) {
    dandanplayResponseModeTop => DandanplayCommentMode.top,
    dandanplayResponseModeBottom => DandanplayCommentMode.bottom,
    _ => DandanplayCommentMode.scrolling,
  };
}

void _throwFailureForStatus(DandanplayApiResponse response) {
  if (response.statusCode == HttpStatus.unauthorized ||
      response.statusCode == HttpStatus.forbidden) {
    throw _DandanplayApiUnauthenticated(
      'Dandanplay API authentication failed with HTTP ${response.statusCode}.',
    );
  }
  throw ProviderFailure(
    kind: _failureKindForStatus(response.statusCode),
    message: 'Dandanplay API request failed with HTTP ${response.statusCode}.',
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

final class _DandanplayApiUnauthenticated implements Exception {
  const _DandanplayApiUnauthenticated(this.message);

  final String message;
}
