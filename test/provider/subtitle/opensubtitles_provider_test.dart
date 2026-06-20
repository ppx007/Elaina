import 'dart:convert';

import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concrete provider maps subtitle search through gateway', () async {
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    final _FakeOpenSubtitlesTransport transport = _FakeOpenSubtitlesTransport(
      responses: <String, OpenSubtitlesApiResponse>{
        'GET /api/v1/subtitles?query=Frieren&languages=ja&season_number=1&episode_number=2':
            const OpenSubtitlesApiResponse(
          statusCode: 200,
          body: '''
{
  "data": [
    {
      "id": "subtitle-1001",
      "attributes": {
        "release": "Frieren S01E02",
        "language": "ja",
        "url": "https://www.opensubtitles.com/subtitles/subtitle-1001",
        "files": [
          {
            "file_id": 1001,
            "file_name": "frieren.s01e02.ja.ass"
          }
        ]
      }
    }
  ]
}
''',
        ),
      },
    );
    final OpenSubtitlesProvider provider = OpenSubtitlesProvider(
      gateway: gateway,
      client: OpenSubtitlesApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      config: const OpenSubtitlesApiConfig(apiKey: 'api-key-1'),
    );

    final AcgProviderResult<List<SubtitleProviderCandidate>> result =
        await provider.searchSubtitles(
      const SubtitleSearchQuery(
        title: 'Frieren',
        languageCode: 'ja',
        seasonNumber: 1,
        episodeNumber: 2,
      ),
    );

    expect(result, isA<AcgProviderSuccess<List<SubtitleProviderCandidate>>>());
    final List<SubtitleProviderCandidate> candidates =
        (result as AcgProviderSuccess<List<SubtitleProviderCandidate>>).value;
    expect(candidates.single.id, 'subtitle-1001');
    expect(candidates.single.providerId, opensubtitlesProviderId);
    expect(candidates.single.title, 'Frieren S01E02');
    expect(candidates.single.reference, '1001');
    expect(candidates.single.format, ProviderSubtitleFormat.ass);
    expect(candidates.single.languageCode, 'ja');
    expect(candidates.single.confidence, opensubtitlesCandidateConfidence);
    expect(gateway.lastCacheKey, 'opensubtitles-search:frieren:ja:1:2');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkFirst);
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse(
          'https://api.test/api/v1/subtitles?query=Frieren&languages=ja&season_number=1&episode_number=2'),
    );
    expect(
      gateway.lastDeduplicationWindow,
      opensubtitlesRuntimeDeduplicationWindow,
    );
    expect(transport.requests.single.method, 'GET');
    expect(transport.requests.single.uri.path, opensubtitlesSubtitlesPath);
    expect(transport.requests.single.proxyUrl, 'http://127.0.0.1:7890');
    expect(transport.requests.single.headers[opensubtitlesApiKeyHeader],
        'api-key-1');
  });

  test('concrete provider downloads subtitle files through provider candidate',
      () async {
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    final _FakeOpenSubtitlesTransport transport = _FakeOpenSubtitlesTransport(
      responses: <String, OpenSubtitlesApiResponse>{
        'POST /api/v1/download': const OpenSubtitlesApiResponse(
          statusCode: 200,
          body: '{"link":"https://cdn.test/file/subtitle.srt"}',
        ),
        'GET /file/subtitle.srt': const OpenSubtitlesApiResponse(
          statusCode: 200,
          body: '1\n00:00:01,000 --> 00:00:02,000\nFrieren',
        ),
      },
    );
    final OpenSubtitlesProvider provider = OpenSubtitlesProvider(
      gateway: gateway,
      client: OpenSubtitlesApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      config: const OpenSubtitlesApiConfig(apiKey: 'api-key-1'),
    );
    final SubtitleProviderCandidate candidate = _candidate(reference: '1001');

    final AcgProviderResult<RetrievedSubtitleFile> result =
        await provider.retrieveSubtitle(candidate);

    expect(result, isA<AcgProviderSuccess<RetrievedSubtitleFile>>());
    final RetrievedSubtitleFile file =
        (result as AcgProviderSuccess<RetrievedSubtitleFile>).value;
    expect(file.candidate, candidate);
    expect(file.content, contains('Frieren'));
    expect(file.encodingHint, opensubtitlesDefaultEncodingHint);
    expect(file.cachedUri, Uri.parse('https://cdn.test/file/subtitle.srt'));
    expect(gateway.lastCacheKey, 'opensubtitles-file:1001');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkFirst);
    expect(gateway.networkPolicyUris, <Uri>[
      Uri.parse('https://api.test/api/v1/download'),
      Uri.parse('https://cdn.test/file/subtitle.srt'),
    ]);
    expect(
      gateway.lastDeduplicationWindow,
      opensubtitlesRuntimeDeduplicationWindow,
    );

    final OpenSubtitlesApiRequest downloadRequest = transport.requests.first;
    expect(downloadRequest.method, 'POST');
    expect(downloadRequest.uri.path, opensubtitlesDownloadPath);
    expect(downloadRequest.proxyUrl, 'http://127.0.0.1:7890');
    expect(downloadRequest.headers[opensubtitlesApiKeyHeader], 'api-key-1');
    final Map<String, Object?> downloadBody =
        jsonDecode(downloadRequest.body!) as Map<String, Object?>;
    expect(downloadBody[opensubtitlesFileIdKey], 1001);

    final OpenSubtitlesApiRequest fileRequest = transport.requests.last;
    expect(fileRequest.method, 'GET');
    expect(fileRequest.uri.host, 'cdn.test');
    expect(fileRequest.proxyUrl, 'http://127.0.0.1:7890');
    expect(fileRequest.headers.containsKey(opensubtitlesApiKeyHeader), isFalse);
  });

  test('concrete provider normalizes API and response failures', () async {
    final _RecordingGateway gateway = _RecordingGateway();
    final _FakeOpenSubtitlesTransport transport = _FakeOpenSubtitlesTransport(
      responses: <String, OpenSubtitlesApiResponse>{
        'GET /api/v1/subtitles?query=Slow&languages=ja':
            const OpenSubtitlesApiResponse(statusCode: 429, body: '{}'),
        'GET /api/v1/subtitles?query=Malformed&languages=ja':
            const OpenSubtitlesApiResponse(statusCode: 200, body: '{bad'),
        'GET /api/v1/subtitles?query=NoFiles&languages=ja':
            const OpenSubtitlesApiResponse(
          statusCode: 200,
          body: '{"data":[{"id":"subtitle-empty","attributes":{"files":[]}}]}',
        ),
        'POST /api/v1/download': const OpenSubtitlesApiResponse(
          statusCode: 404,
          body: '{}',
        ),
      },
    );
    final OpenSubtitlesProvider provider = OpenSubtitlesProvider(
      gateway: gateway,
      client: OpenSubtitlesApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      config: const OpenSubtitlesApiConfig(apiKey: 'api-key-1'),
    );

    final AcgProviderResult<List<SubtitleProviderCandidate>> throttled =
        await provider.searchSubtitles(
      const SubtitleSearchQuery(title: 'Slow', languageCode: 'ja'),
    );
    expect(
      (throttled as AcgProviderFailure<List<SubtitleProviderCandidate>>).kind,
      AcgProviderFailureKind.throttled,
    );

    final AcgProviderResult<List<SubtitleProviderCandidate>> malformed =
        await provider.searchSubtitles(
      const SubtitleSearchQuery(title: 'Malformed', languageCode: 'ja'),
    );
    expect(
      (malformed as AcgProviderFailure<List<SubtitleProviderCandidate>>).kind,
      AcgProviderFailureKind.terminal,
    );

    final AcgProviderResult<List<SubtitleProviderCandidate>> noFiles =
        await provider.searchSubtitles(
      const SubtitleSearchQuery(title: 'NoFiles', languageCode: 'ja'),
    );
    expect(
      (noFiles as AcgProviderFailure<List<SubtitleProviderCandidate>>).kind,
      AcgProviderFailureKind.terminal,
    );

    final AcgProviderResult<RetrievedSubtitleFile> missing =
        await provider.retrieveSubtitle(_candidate(reference: '1001'));
    expect(
      (missing as AcgProviderFailure<RetrievedSubtitleFile>).kind,
      AcgProviderFailureKind.cachedMiss,
    );

    final AcgProviderResult<RetrievedSubtitleFile> invalidReference =
        await provider.retrieveSubtitle(_candidate(reference: 'not-a-number'));
    expect(
      (invalidReference as AcgProviderFailure<RetrievedSubtitleFile>).kind,
      AcgProviderFailureKind.terminal,
    );
  });
}

SubtitleProviderCandidate _candidate({required String reference}) {
  return SubtitleProviderCandidate(
    id: 'subtitle-$reference',
    providerId: opensubtitlesProviderId,
    title: 'OpenSubtitles Candidate',
    format: ProviderSubtitleFormat.srt,
    reference: reference,
    confidence: opensubtitlesCandidateConfidence,
    languageCode: 'ja',
  );
}

final class _RecordingGateway implements ProviderGateway {
  _RecordingGateway({this.proxyUrl});

  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();
  final String? proxyUrl;
  String? lastCacheKey;
  ProviderCachePolicy? lastCachePolicy;
  Duration? lastDeduplicationWindow;
  Uri? lastNetworkPolicyUri;
  final List<Uri> networkPolicyUris = <Uri>[];

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) async {}

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) async {
    lastCacheKey = request.key.cacheKey;
    lastCachePolicy = request.cachePolicy;
    lastDeduplicationWindow = request.deduplicationWindow;
    lastNetworkPolicyUri = request.networkPolicyUri;
    final Uri? networkPolicyUri = request.networkPolicyUri;
    if (networkPolicyUri != null) networkPolicyUris.add(networkPolicyUri);
    return ProviderGatewayResponse<T>(
      value: await request.executeLoad(
        ProviderGatewayRequestContext(proxyUrl: proxyUrl),
      ),
      source: ProviderGatewayResponseSource.network,
    );
  }
}

final class _FakeOpenSubtitlesTransport implements OpenSubtitlesApiTransport {
  _FakeOpenSubtitlesTransport({
    required Map<String, OpenSubtitlesApiResponse> responses,
  }) : _responses = responses;

  final Map<String, OpenSubtitlesApiResponse> _responses;
  final List<OpenSubtitlesApiRequest> requests = <OpenSubtitlesApiRequest>[];

  @override
  Future<OpenSubtitlesApiResponse> send(
    OpenSubtitlesApiRequest request,
  ) async {
    requests.add(request);
    final OpenSubtitlesApiResponse? response = _responses[_requestKey(request)];
    if (response != null) return response;
    return const OpenSubtitlesApiResponse(
      statusCode: 404,
      body: '{"message":"missing fake response"}',
    );
  }

  String _requestKey(OpenSubtitlesApiRequest request) {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '${request.method} ${request.uri.path}$query';
  }
}
