// Subtitle provider cache contract tests protect cache identity and invalidation
// separately from provider HTTP and parser behavior.
// Parser warnings belong in subtitle parser tests.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle cache returns non-expired records and evicts expired records',
      () async {
    final DeterministicSubtitleCacheStore cache =
        DeterministicSubtitleCacheStore();
    final DateTime cachedAt = DateTime.utc(2026, 6, 4, 12);

    await cache.storeSearchResults(
      StoredSubtitleSearchCacheRecord(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|file:///d:/media/frieren.mkv',
        candidates: <StoredSubtitleSearchCandidateRecord>[_storedCandidate()],
        cachedAt: cachedAt,
        expiresAt: cachedAt.add(const Duration(minutes: 10)),
      ),
    );
    await cache.storeContent(
      StoredSubtitleContentCacheRecord(
        providerId: 'opensubtitles',
        candidateReference: 'provider-ref-1',
        content: '1\n00:00:01,000 --> 00:00:02,000\nSousou no Frieren',
        encodingHint: 'shift_jis',
        cachedUri: Uri.parse('file:///D:/cache/frieren.srt'),
        cachedAt: cachedAt,
        expiresAt: cachedAt.add(const Duration(hours: 1)),
      ),
    );

    expect(
      await cache.searchResults(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|file:///d:/media/frieren.mkv',
        now: cachedAt.add(const Duration(minutes: 5)),
      ),
      isNotNull,
    );
    expect(
      await cache.searchResults(
        providerId: 'opensubtitles',
        queryKey: 'frieren|ja|1|1|file:///d:/media/frieren.mkv',
        now: cachedAt.add(const Duration(minutes: 10)),
      ),
      isNull,
    );
    expect(
      (await cache.content(
        providerId: 'opensubtitles',
        candidateReference: 'provider-ref-1',
        now: cachedAt.add(const Duration(minutes: 30)),
      ))
          ?.encodingHint,
      'shift_jis',
    );
    expect(
      await cache.content(
        providerId: 'opensubtitles',
        candidateReference: 'provider-ref-1',
        now: cachedAt.add(const Duration(hours: 1)),
      ),
      isNull,
    );
  });

  test(
      'discovery composes local scanner results with cache-backed provider candidates',
      () async {
    final DeterministicSubtitleCacheStore cache =
        DeterministicSubtitleCacheStore();
    final _FakeSubtitleProvider provider = _FakeSubtitleProvider(
        candidates: <SubtitleProviderCandidate>[_providerCandidate()]);
    final _FakeLocalSubtitleScanner scanner = _FakeLocalSubtitleScanner(
      candidates: <ExternalSubtitleCandidate>[
        ExternalSubtitleCandidate(
          source: ExternalSubtitleSource(
            id: 'local-ja',
            format: SubtitleFormat.srt,
            languageCode: 'ja',
            uri: Uri.parse('file:///D:/media/frieren.ja.srt'),
            title: 'Local Japanese',
          ),
          matchConfidence: 0.9,
        ),
      ],
    );
    final DeterministicSubtitleDiscoveryContract discovery =
        DeterministicSubtitleDiscoveryContract(
      provider: provider,
      cache: cache,
      localScanner: scanner,
      clock: () => DateTime.utc(2026, 6, 4, 12),
    );

    final SubtitleDiscoveryResult first = await discovery.discover(_request());
    final SubtitleDiscoveryResult second = await discovery.discover(_request());

    expect(first.localCandidates.single.candidate.source.id, 'local-ja');
    expect(
        first.providerCandidates.single.candidate.reference, 'provider-ref-1');
    expect(first.providerCandidates.single.fromCache, isFalse);
    expect(second.providerCandidates.single.fromCache, isTrue);
    expect(provider.searchCount, 1);
    expect(scanner.scanCount, 2);
  });

  test(
      'provider retrieval handoff preserves source metadata content and encoding hints',
      () async {
    final DeterministicSubtitleCacheStore cache =
        DeterministicSubtitleCacheStore();
    final SubtitleProviderCandidate candidate = _providerCandidate();
    final _FakeSubtitleProvider provider = _FakeSubtitleProvider(
      candidates: <SubtitleProviderCandidate>[candidate],
      retrievedFile: RetrievedSubtitleFile(
        candidate: candidate,
        content: 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nFrieren',
        encodingHint: 'utf-8',
        cachedUri: Uri.parse('file:///D:/cache/frieren.vtt'),
      ),
    );
    final DeterministicSubtitleDiscoveryContract discovery =
        DeterministicSubtitleDiscoveryContract(
      provider: provider,
      cache: cache,
      clock: () => DateTime.utc(2026, 6, 4, 12),
    );

    final SubtitleProviderHandoffResult first =
        await discovery.prepareProviderSubtitle(candidate);
    final SubtitleProviderHandoffResult second =
        await discovery.prepareProviderSubtitle(candidate);

    final ExternalSubtitleSource source =
        first.parseRequest!.source as ExternalSubtitleSource;
    expect(first.isSuccess, isTrue);
    expect(first.fromCache, isFalse);
    expect(source.id, candidate.id);
    expect(source.format, SubtitleFormat.vtt);
    expect(source.languageCode, 'ja');
    expect(source.uri, Uri.parse('file:///D:/cache/frieren.vtt'));
    expect(first.parseRequest?.content, contains('Frieren'));
    expect(first.parseRequest?.encodingHint, 'utf-8');
    expect(second.fromCache, isTrue);
    expect(second.parseRequest?.encodingHint, 'utf-8');
    expect(provider.retrieveCount, 1);
  });
}

SubtitleDiscoveryRequest _request() {
  return SubtitleDiscoveryRequest(
    media: LocalMediaReference(
        uri: Uri.parse('file:///D:/media/frieren.mkv'),
        basename: 'frieren.mkv'),
    providerQuery: const SubtitleSearchQuery(
      title: 'Frieren',
      languageCode: 'ja',
      seasonNumber: 1,
      episodeNumber: 1,
      localMediaUri: null,
    ),
  );
}

SubtitleProviderCandidate _providerCandidate() {
  return SubtitleProviderCandidate(
    id: 'provider-candidate-1',
    providerId: const SubtitleProviderId('opensubtitles'),
    title: 'Provider Japanese',
    format: ProviderSubtitleFormat.vtt,
    reference: 'provider-ref-1',
    confidence: 0.8,
    languageCode: 'ja',
    sourceUri: Uri.parse('https://subtitles.example.test/frieren.vtt'),
  );
}

StoredSubtitleSearchCandidateRecord _storedCandidate() {
  final SubtitleProviderCandidate candidate = _providerCandidate();
  return StoredSubtitleSearchCandidateRecord(
    id: candidate.id,
    providerId: candidate.providerId.value,
    title: candidate.title,
    format: candidate.format.name,
    reference: candidate.reference,
    confidence: candidate.confidence,
    languageCode: candidate.languageCode,
    sourceUri: candidate.sourceUri,
  );
}

final class _FakeLocalSubtitleScanner implements LocalExternalSubtitleScanner {
  _FakeLocalSubtitleScanner({required this.candidates});

  final List<ExternalSubtitleCandidate> candidates;
  int scanCount = 0;

  @override
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request) {
    scanCount += 1;
    return Future<List<ExternalSubtitleCandidate>>.value(candidates);
  }
}

final class _FakeSubtitleProvider implements SubtitleProvider {
  _FakeSubtitleProvider(
      {required this.candidates, RetrievedSubtitleFile? retrievedFile})
      : _retrievedFile = retrievedFile;

  final List<SubtitleProviderCandidate> candidates;
  final RetrievedSubtitleFile? _retrievedFile;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
        searchTtl: const Duration(minutes: 10),
        fileTtl: const Duration(hours: 1),
      );

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'opensubtitles';

  @override
  ProviderKind get kind => ProviderKind.subtitle;

  @override
  ProviderRegistration get registration => subtitleProviderRegistration(
      providerId: const SubtitleProviderId('opensubtitles'));

  @override
  SubtitleProviderId get subtitleProviderId =>
      const SubtitleProviderId('opensubtitles');

  @override
  String get displayName => 'OpenSubtitles Test Provider';

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return load().then(
      (T value) => ProviderGatewayResponse<T>(
          value: value, source: ProviderGatewayResponseSource.network),
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: const ProviderId('opensubtitles'), cacheKey: cacheKey);
  }

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
      SubtitleProviderCandidate candidate) {
    retrieveCount += 1;
    return Future<AcgProviderResult<RetrievedSubtitleFile>>.value(
      AcgProviderSuccess<RetrievedSubtitleFile>(
        _retrievedFile ??
            RetrievedSubtitleFile(
              candidate: candidate,
              content: '1\n00:00:01,000 --> 00:00:02,000\nFrieren',
              encodingHint: 'utf-8',
              cachedUri: Uri.parse('file:///D:/cache/default.srt'),
            ),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
      SubtitleSearchQuery query) {
    searchCount += 1;
    return Future<AcgProviderResult<List<SubtitleProviderCandidate>>>.value(
      AcgProviderSuccess<List<SubtitleProviderCandidate>>(candidates),
    );
  }
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage =>
      throw StateError('Storage is not used by this test gateway.');

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) async {
    return ProviderGatewayResponse<T>(
        value: await request.load(),
        source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<void> registerProvider(ProviderRegistration registration) =>
      Future<void>.value();
}
