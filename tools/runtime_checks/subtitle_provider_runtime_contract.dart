import '../../lib/elaina.dart';
import 'media_library_runtime_contract.dart';

Future<void> main() async {
  await verifySubtitleProviderRuntimeContract();
}

Future<void> verifySubtitleProviderRuntimeContract() async {
  final DateTime now = DateTime.utc(2026, 6, 11, 12);
  final SubtitleProviderCandidate candidate = SubtitleProviderCandidate(
    id: 'subtitle-provider-check-candidate',
    providerId: const SubtitleProviderId('opensubtitles'),
    title: 'Subtitle Provider Check',
    format: ProviderSubtitleFormat.srt,
    reference: 'subtitle-provider-check-ref',
    confidence: 0.9,
    languageCode: 'ja',
  );
  final _CheckSubtitleProvider provider = _CheckSubtitleProvider(candidate);
  final SubtitleProviderBootstrap bootstrap = SubtitleProviderBootstrap(
    provider: provider,
    cache: DeterministicSubtitleCacheStore(),
    localScanner: _CheckLocalSubtitleScanner(),
    clock: () => now,
  );

  final SubtitleDiscoveryRequest request = SubtitleDiscoveryRequest(
    media: LocalMediaReference(
        uri: Uri.file('D:/media/check.mkv'), basename: 'check.mkv'),
    providerQuery: const SubtitleSearchQuery(
        title: 'Check', languageCode: 'ja', seasonNumber: 1, episodeNumber: 1),
  );
  final SubtitleProviderActionResult<SubtitleDiscoveryResult> first =
      await bootstrap.discover(request);
  final SubtitleProviderActionResult<SubtitleDiscoveryResult> second =
      await bootstrap.discover(request);
  _expect(
      first.isSuccess, 'Subtitle provider runtime must discover candidates.');
  _expect(
      first.value?.localCandidates.single.candidate.source.id ==
          'check-local-ja',
      'Runtime must include local subtitle candidates.');
  _expect(first.value?.providerCandidates.single.fromCache == false,
      'First provider search must not be cached.');
  _expect(second.value?.providerCandidates.single.fromCache == true,
      'Second provider search must reuse cached search results.');

  final SubtitleProviderActionResult<SubtitleProviderHandoffResult> handoff =
      await bootstrap.prepareProviderSubtitle(candidate);
  final SubtitleProviderActionResult<SubtitleParseRequest> parser =
      await bootstrap.prepareParserRequest(candidate);
  _expect(handoff.isSuccess, 'Runtime must retrieve provider subtitle file.');
  _expect(handoff.value?.file?.encodingHint == 'utf-8',
      'Runtime must preserve encoding hints.');
  _expect(parser.value?.content.contains('subtitle-provider-check') == true,
      'Runtime must produce parser-compatible content.');
  _expect(provider.searchCount == 1,
      'Provider search must be called once after cache reuse.');
  _expect(provider.retrieveCount == 1,
      'Provider retrieval must be called once after content cache reuse.');

  await _verifyOpenSubtitlesProviderContract();

  bootstrap.dispose();
  await verifyMediaLibraryRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckLocalSubtitleScanner implements LocalExternalSubtitleScanner {
  @override
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request) {
    return Future<
        List<ExternalSubtitleCandidate>>.value(<ExternalSubtitleCandidate>[
      ExternalSubtitleCandidate(
        source: ExternalSubtitleSource(
          id: 'check-local-ja',
          format: SubtitleFormat.srt,
          languageCode: 'ja',
          uri: Uri.file('D:/media/check.ja.srt'),
          title: 'Check Local Japanese',
        ),
        matchConfidence: 0.95,
      ),
    ]);
  }
}

final class _CheckSubtitleProvider implements SubtitleProvider {
  _CheckSubtitleProvider(this.candidate);

  final SubtitleProviderCandidate candidate;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
      searchTtl: const Duration(minutes: 10),
      fileTtl: const Duration(hours: 1));

  @override
  String get displayName => 'Check Subtitle Provider';

  @override
  ProviderGateway get gateway => throw UnsupportedError(
      'Smoke checker does not expose a provider gateway.');

  @override
  String get id => subtitleProviderId.value;

  @override
  ProviderKind get kind => ProviderKind.subtitle;

  @override
  ProviderRegistration get registration =>
      subtitleProviderRegistration(providerId: subtitleProviderId);

  @override
  SubtitleProviderId get subtitleProviderId =>
      const SubtitleProviderId('opensubtitles');

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>(
      {required String cacheKey,
      required Future<T> Function() load,
      ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly}) {
    throw UnsupportedError('Smoke checker does not execute gateway requests.');
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
      providerId: const ProviderId('opensubtitles'), cacheKey: cacheKey);

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
      SubtitleProviderCandidate candidate) {
    retrieveCount += 1;
    return Future<AcgProviderResult<RetrievedSubtitleFile>>.value(
      AcgProviderSuccess<RetrievedSubtitleFile>(
        RetrievedSubtitleFile(
          candidate: candidate,
          content: '1\n00:00:01,000 --> 00:00:02,000\nsubtitle-provider-check',
          encodingHint: 'utf-8',
          cachedUri: Uri.file('D:/cache/subtitle-provider-check.srt'),
        ),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
      SubtitleSearchQuery query) {
    searchCount += 1;
    return Future<AcgProviderResult<List<SubtitleProviderCandidate>>>.value(
        AcgProviderSuccess<List<SubtitleProviderCandidate>>(
            <SubtitleProviderCandidate>[candidate]));
  }
}

Future<void> _verifyOpenSubtitlesProviderContract() async {
  final _CheckOpenSubtitlesTransport transport = _CheckOpenSubtitlesTransport(
    responses: <String, OpenSubtitlesApiResponse>{
      'GET /api/v1/subtitles?query=Check&languages=ja&season_number=1&episode_number=1':
          const OpenSubtitlesApiResponse(
        statusCode: 200,
        body:
            '{"data":[{"id":"check-open-subtitles","attributes":{"release":"Check OpenSubtitles","language":"ja","files":[{"file_id":1017,"file_name":"check.ja.srt"}]}}]}',
      ),
      'POST /api/v1/download': const OpenSubtitlesApiResponse(
        statusCode: 200,
        body: '{"link":"https://cdn.example.test/check.ja.srt"}',
      ),
      'GET /check.ja.srt': const OpenSubtitlesApiResponse(
        statusCode: 200,
        body: '1\n00:00:01,000 --> 00:00:02,000\nopensubtitles-check',
      ),
    },
  );
  final OpenSubtitlesProvider provider = OpenSubtitlesProvider(
    gateway: _CheckProviderGateway(),
    client: OpenSubtitlesApiClient(
      transport: transport,
      baseUri: Uri.parse('https://api.example.test'),
    ),
    config: const OpenSubtitlesApiConfig(apiKey: 'check-api-key'),
  );
  final SubtitleSearchQuery query = const SubtitleSearchQuery(
    title: 'Check',
    languageCode: 'ja',
    seasonNumber: 1,
    episodeNumber: 1,
  );

  final AcgProviderResult<List<SubtitleProviderCandidate>> search =
      await provider.searchSubtitles(query);
  _expect(search is AcgProviderSuccess<List<SubtitleProviderCandidate>>,
      'OpenSubtitles provider must search through a fake transport.');
  final SubtitleProviderCandidate candidate =
      (search as AcgProviderSuccess<List<SubtitleProviderCandidate>>)
          .value
          .single;
  _expect(candidate.reference == '1017',
      'OpenSubtitles provider must map file ids to candidate references.');
  _expect(
      transport.requests.first.headers[opensubtitlesApiKeyHeader] ==
          'check-api-key',
      'OpenSubtitles provider must send the configured API key.');

  final AcgProviderResult<RetrievedSubtitleFile> retrieve =
      await provider.retrieveSubtitle(candidate);
  _expect(retrieve is AcgProviderSuccess<RetrievedSubtitleFile>,
      'OpenSubtitles provider must retrieve subtitle file content.');
  final RetrievedSubtitleFile file =
      (retrieve as AcgProviderSuccess<RetrievedSubtitleFile>).value;
  _expect(file.content.contains('opensubtitles-check'),
      'OpenSubtitles provider must return parser-compatible subtitle content.');
  _expect(file.encodingHint == opensubtitlesDefaultEncodingHint,
      'OpenSubtitles provider must preserve its encoding hint.');
}

final class _CheckProviderGateway implements ProviderGateway {
  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) {
    return Future<void>.value();
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) async {
    return ProviderGatewayResponse<T>(
      value: await request.load(),
      source: ProviderGatewayResponseSource.network,
    );
  }
}

final class _CheckOpenSubtitlesTransport implements OpenSubtitlesApiTransport {
  _CheckOpenSubtitlesTransport({
    required Map<String, OpenSubtitlesApiResponse> responses,
  }) : _responses = responses;

  final Map<String, OpenSubtitlesApiResponse> _responses;
  final List<OpenSubtitlesApiRequest> requests = <OpenSubtitlesApiRequest>[];

  @override
  Future<OpenSubtitlesApiResponse> send(OpenSubtitlesApiRequest request) {
    requests.add(request);
    final OpenSubtitlesApiResponse? response = _responses[_requestKey(request)];
    if (response != null) {
      return Future<OpenSubtitlesApiResponse>.value(response);
    }
    return Future<OpenSubtitlesApiResponse>.value(
      const OpenSubtitlesApiResponse(
        statusCode: 404,
        body: '{"message":"missing fake response"}',
      ),
    );
  }

  String _requestKey(OpenSubtitlesApiRequest request) {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '${request.method} ${request.uri.path}$query';
  }
}
