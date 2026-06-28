import 'dart:convert';
import 'dart:io';

import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../../foundation/security/outbound_uri_guard.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';
import 'subtitle_provider.dart';
import 'subtitle_registration.dart';

const SubtitleProviderId opensubtitlesProviderId =
    SubtitleProviderId('opensubtitles');
const String opensubtitlesDefaultUserAgent = 'Elaina/0.11';
const double opensubtitlesCandidateConfidence = 0.8;
const String opensubtitlesDefaultEncodingHint = 'utf-8';
const Duration opensubtitlesSearchCacheTtl = Duration(minutes: 30);
const Duration opensubtitlesFileCacheTtl = Duration(days: 7);
const Duration opensubtitlesRuntimeDeduplicationWindow = Duration(seconds: 30);
const String opensubtitlesApiKeyHeader = 'Api-Key';
const String opensubtitlesSubtitlesPath = '/api/v1/subtitles';
const String opensubtitlesDownloadPath = '/api/v1/download';
const String opensubtitlesSearchQueryKey = 'query';
const String opensubtitlesLanguageQueryKey = 'languages';
const String opensubtitlesSeasonQueryKey = 'season_number';
const String opensubtitlesEpisodeQueryKey = 'episode_number';
const String opensubtitlesFileIdKey = 'file_id';
const String opensubtitlesDownloadLinkKey = 'link';
const String opensubtitlesDataKey = 'data';
const String opensubtitlesAttributesKey = 'attributes';
const String opensubtitlesFilesKey = 'files';
const String opensubtitlesReleaseKey = 'release';
const String opensubtitlesLanguageKey = 'language';
const String opensubtitlesFileNameKey = 'file_name';
const String opensubtitlesUrlKey = 'url';

final Uri defaultOpenSubtitlesApiBaseUri =
    Uri.parse('https://api.opensubtitles.com');

final class OpenSubtitlesApiConfig {
  const OpenSubtitlesApiConfig({
    required this.apiKey,
    this.userAgent = opensubtitlesDefaultUserAgent,
  }) : assert(apiKey != '', 'OpenSubtitles API key must not be empty.');

  final String apiKey;
  final String userAgent;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
}

final class OpenSubtitlesApiRequest {
  const OpenSubtitlesApiRequest({
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

final class OpenSubtitlesApiResponse {
  const OpenSubtitlesApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class OpenSubtitlesApiTransport {
  Future<OpenSubtitlesApiResponse> send(OpenSubtitlesApiRequest request);
}

/// Socket-level transport for OpenSubtitles requests.
///
/// Endpoint construction and provider caching stay outside this class; the
/// transport only applies proxy wiring and the outbound URI guard.
final class HttpOpenSubtitlesApiTransport implements OpenSubtitlesApiTransport {
  HttpOpenSubtitlesApiTransport({
    HttpClient? httpClient,
    OutboundUriGuard outboundGuard = const OutboundUriGuard(),
  })  : _httpClient = httpClient ?? HttpClient(),
        _outboundGuard = outboundGuard;

  final HttpClient _httpClient;
  final OutboundUriGuard _outboundGuard;

  @override
  Future<OpenSubtitlesApiResponse> send(
    OpenSubtitlesApiRequest request,
  ) async {
    final OutboundHostRisk? risk = _outboundGuard.classifyUri(request.uri);
    if (risk != null) {
      throw StateError(
          'OpenSubtitles request blocked by SSRF guard: ${risk.name} ${request.uri}');
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
      return OpenSubtitlesApiResponse(
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

/// Endpoint-level OpenSubtitles client.
///
/// It maps provider queries into OpenSubtitles HTTP calls and parses API JSON.
/// Rate limiting, dedupe, and cache policy are still owned by ProviderGateway.
final class OpenSubtitlesApiClient {
  OpenSubtitlesApiClient({
    required OpenSubtitlesApiTransport transport,
    Uri? baseUri,
  })  : _transport = transport,
        _baseUri = baseUri ?? defaultOpenSubtitlesApiBaseUri;

  final OpenSubtitlesApiTransport _transport;
  final Uri _baseUri;

  Uri searchSubtitlesRequestUri(SubtitleSearchQuery query) {
    return _uri(opensubtitlesSubtitlesPath, _searchQueryParameters(query));
  }

  Uri retrieveSubtitleRequestUri() {
    return _uri(opensubtitlesDownloadPath);
  }

  Future<List<SubtitleProviderCandidate>> searchSubtitles({
    required SubtitleSearchQuery query,
    required OpenSubtitlesApiConfig config,
    String? proxyUrl,
  }) async {
    final Object? json = await _sendJson(
      'GET',
      searchSubtitlesRequestUri(query),
      config: config,
      proxyUrl: proxyUrl,
    );
    final Map<String, Object?> object =
        _jsonObject(json, 'OpenSubtitles search');
    final List<Object?> data =
        _jsonList(object[opensubtitlesDataKey], 'OpenSubtitles search data');
    return <SubtitleProviderCandidate>[
      for (final Object? item in data)
        _candidateFromSearchItem(
          _jsonObject(item, 'OpenSubtitles search item'),
          query.languageCode,
        ),
    ];
  }

  Future<RetrievedSubtitleFile> retrieveSubtitle({
    required SubtitleProviderCandidate candidate,
    required OpenSubtitlesApiConfig config,
    String? proxyUrl,
  }) async {
    final Uri fileUri = await retrieveSubtitleFileUri(
      candidate: candidate,
      config: config,
      proxyUrl: proxyUrl,
    );
    return retrieveSubtitleFile(
      candidate: candidate,
      fileUri: fileUri,
      config: config,
      proxyUrl: proxyUrl,
    );
  }

  Future<Uri> retrieveSubtitleFileUri({
    required SubtitleProviderCandidate candidate,
    required OpenSubtitlesApiConfig config,
    String? proxyUrl,
  }) async {
    final int? fileId = int.tryParse(candidate.reference);
    if (fileId == null) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message:
            'OpenSubtitles candidate reference is not a numeric file id: ${candidate.reference}.',
      );
    }

    final Object? json = await _sendJson(
      'POST',
      retrieveSubtitleRequestUri(),
      config: config,
      proxyUrl: proxyUrl,
      body: <String, Object?>{opensubtitlesFileIdKey: fileId},
    );
    final Map<String, Object?> object =
        _jsonObject(json, 'OpenSubtitles download');
    final String link = _stringValue(object[opensubtitlesDownloadLinkKey]);
    if (link.isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'OpenSubtitles download response missing link.',
      );
    }

    return Uri.parse(link);
  }

  Future<RetrievedSubtitleFile> retrieveSubtitleFile({
    required SubtitleProviderCandidate candidate,
    required Uri fileUri,
    required OpenSubtitlesApiConfig config,
    String? proxyUrl,
  }) async {
    final OpenSubtitlesApiResponse fileResponse = await _send(
      OpenSubtitlesApiRequest(
        method: 'GET',
        uri: fileUri,
        headers: _headers(config: config, hasBody: false, includeApiKey: false),
        proxyUrl: proxyUrl,
      ),
    );
    if (fileResponse.statusCode < HttpStatus.ok ||
        fileResponse.statusCode >= HttpStatus.multipleChoices) {
      _throwFailureForStatus(fileResponse.statusCode);
    }
    if (fileResponse.body.trim().isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'OpenSubtitles subtitle file response was empty.',
      );
    }
    return RetrievedSubtitleFile(
      candidate: candidate,
      content: fileResponse.body,
      encodingHint: opensubtitlesDefaultEncodingHint,
      cachedUri: fileUri,
    );
  }

  Future<Object?> _sendJson(
    String method,
    Uri uri, {
    required OpenSubtitlesApiConfig config,
    Map<String, Object?>? body,
    String? proxyUrl,
  }) async {
    if (!config.hasApiKey) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'OpenSubtitles API key must not be empty.',
      );
    }
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final OpenSubtitlesApiResponse response = await _send(
      OpenSubtitlesApiRequest(
        method: method,
        uri: uri,
        headers: _headers(config: config, hasBody: encodedBody != null),
        body: encodedBody,
        proxyUrl: proxyUrl,
      ),
    );
    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      _throwFailureForStatus(response.statusCode);
    }
    if (response.body.trim().isEmpty) {
      throw const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'OpenSubtitles API returned an empty response body.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'OpenSubtitles API returned malformed JSON: ${error.message}',
      );
    }
  }

  Future<OpenSubtitlesApiResponse> _send(
    OpenSubtitlesApiRequest request,
  ) async {
    try {
      return await _transport.send(request);
    } on ProviderFailure {
      rethrow;
    } catch (error) {
      throw ProviderFailure(
        kind: ProviderFailureKind.retryable,
        message: 'OpenSubtitles API transport failed: $error',
      );
    }
  }

  Map<String, String> _headers({
    required OpenSubtitlesApiConfig config,
    required bool hasBody,
    bool includeApiKey = true,
  }) {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.userAgentHeader: config.userAgent,
      if (hasBody) HttpHeaders.contentTypeHeader: 'application/json',
      if (includeApiKey) opensubtitlesApiKeyHeader: config.apiKey,
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

final class OpenSubtitlesProvider
    implements SubtitleProvider, GatewayBoundProvider {
  OpenSubtitlesProvider({
    required this.gateway,
    required OpenSubtitlesApiClient client,
    required OpenSubtitlesApiConfig config,
    SubtitleProviderCachePolicy? cachePolicy,
  })  : _client = client,
        _config = config,
        _cachePolicy = cachePolicy ??
            SubtitleProviderCachePolicy(
              searchTtl: opensubtitlesSearchCacheTtl,
              fileTtl: opensubtitlesFileCacheTtl,
            );

  final OpenSubtitlesApiClient _client;
  final OpenSubtitlesApiConfig _config;
  final SubtitleProviderCachePolicy _cachePolicy;

  @override
  final ProviderGateway gateway;

  @override
  SubtitleProviderCachePolicy get cachePolicy => _cachePolicy;

  @override
  String get displayName => 'OpenSubtitles';

  @override
  String get id => opensubtitlesProviderId.value;

  @override
  ProviderKind get kind => ProviderKind.subtitle;

  @override
  ProviderRegistration get registration =>
      subtitleProviderRegistration(providerId: opensubtitlesProviderId);

  @override
  SubtitleProviderId get subtitleProviderId => opensubtitlesProviderId;

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: ProviderId(opensubtitlesProviderId.value),
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
      ProviderGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
        deduplicationWindow: opensubtitlesRuntimeDeduplicationWindow,
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
    SubtitleSearchQuery query,
  ) {
    return _execute<List<SubtitleProviderCandidate>>(
      key: requestKey(_searchCacheKey(query)),
      cachePolicy: cachePolicy.gatewayPolicy,
      networkPolicyUri: _client.searchSubtitlesRequestUri(query),
      load: (ProviderGatewayRequestContext context) => _client.searchSubtitles(
        query: query,
        config: _config,
        proxyUrl: context.proxyUrl,
      ),
    );
  }

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
    SubtitleProviderCandidate candidate,
  ) async {
    final AcgProviderResult<Uri> link = await _execute<Uri>(
      key: requestKey(_downloadLinkCacheKey(candidate)),
      cachePolicy: ProviderCachePolicy.networkOnly,
      networkPolicyUri: _client.retrieveSubtitleRequestUri(),
      load: (ProviderGatewayRequestContext context) =>
          _client.retrieveSubtitleFileUri(
        candidate: candidate,
        config: _config,
        proxyUrl: context.proxyUrl,
      ),
    );
    if (link is AcgProviderFailure<Uri>) {
      return AcgProviderFailure<RetrievedSubtitleFile>(
        kind: link.kind,
        message: link.message,
      );
    }
    final Uri fileUri = (link as AcgProviderSuccess<Uri>).value;
    return _execute<RetrievedSubtitleFile>(
      key: requestKey(_retrieveCacheKey(candidate)),
      cachePolicy: cachePolicy.gatewayPolicy,
      networkPolicyUri: fileUri,
      load: (ProviderGatewayRequestContext context) =>
          _client.retrieveSubtitleFile(
        candidate: candidate,
        fileUri: fileUri,
        config: _config,
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
      final ProviderGatewayResponse<T> response =
          await gateway.execute<T>(ProviderGatewayRequest<T>(
        key: key,
        load: () => load(const ProviderGatewayRequestContext()),
        loadWithContext: load,
        cachePolicy: cachePolicy,
        deduplicationWindow: opensubtitlesRuntimeDeduplicationWindow,
        networkPolicyUri: networkPolicyUri,
      ));
      return AcgProviderSuccess<T>(response.value);
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<T>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    }
  }
}

Map<String, String> _searchQueryParameters(SubtitleSearchQuery query) {
  return <String, String>{
    opensubtitlesSearchQueryKey: query.title.trim(),
    opensubtitlesLanguageQueryKey: query.languageCode.trim(),
    if (query.seasonNumber != null)
      opensubtitlesSeasonQueryKey: '${query.seasonNumber}',
    if (query.episodeNumber != null)
      opensubtitlesEpisodeQueryKey: '${query.episodeNumber}',
  };
}

SubtitleProviderCandidate _candidateFromSearchItem(
  Map<String, Object?> item,
  String fallbackLanguageCode,
) {
  final String id = _requiredString(item['id'], 'OpenSubtitles subtitle id');
  final Map<String, Object?> attributes = _jsonObject(
      item[opensubtitlesAttributesKey], 'OpenSubtitles subtitle attributes');
  final List<Object?> files = _jsonList(
      attributes[opensubtitlesFilesKey], 'OpenSubtitles subtitle files');
  if (files.isEmpty) {
    throw const ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: 'OpenSubtitles subtitle response missing files.',
    );
  }
  final Map<String, Object?> file =
      _jsonObject(files.first, 'OpenSubtitles subtitle file');
  final String fileId = _requiredString(
      file[opensubtitlesFileIdKey], 'OpenSubtitles subtitle file id');
  final String fileName = _stringValue(file[opensubtitlesFileNameKey]);
  final String release = _stringValue(attributes[opensubtitlesReleaseKey]);
  final String languageCode =
      _stringValue(attributes[opensubtitlesLanguageKey]).isEmpty
          ? fallbackLanguageCode
          : _stringValue(attributes[opensubtitlesLanguageKey]);
  return SubtitleProviderCandidate(
    id: id,
    providerId: opensubtitlesProviderId,
    title: release.isEmpty
        ? (fileName.isEmpty ? 'OpenSubtitles $id' : fileName)
        : release,
    format: _formatFromFileName(fileName),
    reference: fileId,
    confidence: opensubtitlesCandidateConfidence,
    languageCode: languageCode,
    sourceUri: _optionalUri(attributes[opensubtitlesUrlKey]),
  );
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

String _requiredString(Object? value, String label) {
  final String text = _stringValue(value);
  if (text.isEmpty) {
    throw ProviderFailure(
      kind: ProviderFailureKind.terminal,
      message: '$label missing from API response.',
    );
  }
  return text;
}

String _stringValue(Object? value) {
  return switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    final double number => number.toStringAsFixed(0),
    _ => '',
  };
}

Uri? _optionalUri(Object? value) {
  final String text = _stringValue(value);
  return text.isEmpty ? null : Uri.tryParse(text);
}

ProviderSubtitleFormat _formatFromFileName(String fileName) {
  final String normalized = fileName.toLowerCase();
  if (normalized.endsWith('.vtt')) return ProviderSubtitleFormat.vtt;
  if (normalized.endsWith('.ass')) return ProviderSubtitleFormat.ass;
  return ProviderSubtitleFormat.srt;
}

String _searchCacheKey(SubtitleSearchQuery query) {
  final String season = query.seasonNumber?.toString() ?? '';
  final String episode = query.episodeNumber?.toString() ?? '';
  return 'opensubtitles-search:${query.title.trim().toLowerCase()}:'
      '${query.languageCode.trim().toLowerCase()}:$season:$episode';
}

String _retrieveCacheKey(SubtitleProviderCandidate candidate) {
  return 'opensubtitles-file:${candidate.reference}';
}

String _downloadLinkCacheKey(SubtitleProviderCandidate candidate) {
  return 'opensubtitles-download-link:${candidate.reference}';
}

void _throwFailureForStatus(int statusCode) {
  throw ProviderFailure(
    kind: _failureKindForStatus(statusCode),
    message: 'OpenSubtitles API request failed with HTTP $statusCode.',
  );
}

ProviderFailureKind _failureKindForStatus(int statusCode) {
  if (statusCode == HttpStatus.tooManyRequests) {
    return ProviderFailureKind.throttled;
  }
  if (statusCode == HttpStatus.notFound) {
    return ProviderFailureKind.cachedMiss;
  }
  if (statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.forbidden) {
    return ProviderFailureKind.terminal;
  }
  if (statusCode == HttpStatus.requestTimeout ||
      statusCode >= HttpStatus.internalServerError) {
    return ProviderFailureKind.retryable;
  }
  return ProviderFailureKind.terminal;
}
