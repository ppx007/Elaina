import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime discovers local and provider candidates with cache snapshots', () async {
    final DateTime now = DateTime.utc(2026, 6, 11, 10);
    final SubtitleProviderCandidate candidate = _providerCandidate(format: ProviderSubtitleFormat.srt);
    final DeterministicSubtitleCacheStore cache = DeterministicSubtitleCacheStore();
    final _FakeSubtitleProvider provider = _FakeSubtitleProvider(candidates: <SubtitleProviderCandidate>[candidate]);
    final SubtitleProviderRuntime runtime = SubtitleProviderRuntime(
      discovery: DeterministicSubtitleDiscoveryContract(
        provider: provider,
        cache: cache,
        localScanner: _FakeLocalSubtitleScanner(candidates: <ExternalSubtitleCandidate>[_localCandidate()]),
        clock: () => now,
      ),
    );
    final _RuntimeObserver observer = _RuntimeObserver();
    runtime.addObserver(observer);

    final SubtitleProviderActionResult<SubtitleDiscoveryResult> first = await runtime.discover(_request());
    final SubtitleProviderActionResult<SubtitleDiscoveryResult> second = await runtime.discover(_request());

    expect(first.isSuccess, isTrue);
    expect(first.value?.localCandidates.single.candidate.source.id, 'local-ja');
    expect(first.value?.providerCandidates.single.candidate.id, candidate.id);
    expect(first.value?.providerCandidates.single.fromCache, isFalse);
    expect(second.value?.providerCandidates.single.fromCache, isTrue);
    expect(provider.searchCount, 1);
    expect(runtime.currentSnapshot.status, SubtitleProviderRuntimeStatus.ready);
    expect(runtime.currentSnapshot.providerCandidates.single.fromCache, isTrue);
    expect(observer.snapshots.map((SubtitleProviderRuntimeSnapshot snapshot) => snapshot.status), contains(SubtitleProviderRuntimeStatus.searching));
  });

  test('runtime retrieves provider subtitle and returns parser handoff from cache', () async {
    final DateTime now = DateTime.utc(2026, 6, 11, 11);
    final SubtitleProviderCandidate candidate = _providerCandidate(format: ProviderSubtitleFormat.vtt);
    final _FakeSubtitleProvider provider = _FakeSubtitleProvider(
      candidates: <SubtitleProviderCandidate>[candidate],
      retrievedFile: RetrievedSubtitleFile(
        candidate: candidate,
        content: 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nFrieren',
        encodingHint: 'utf-8',
        cachedUri: Uri.parse('file:///D:/cache/frieren.vtt'),
      ),
    );
    final SubtitleProviderBootstrap bootstrap = SubtitleProviderBootstrap(
      provider: provider,
      cache: DeterministicSubtitleCacheStore(),
      clock: () => now,
    );

    final SubtitleProviderActionResult<SubtitleProviderHandoffResult> first = await bootstrap.prepareProviderSubtitle(candidate);
    final SubtitleProviderActionResult<SubtitleParseRequest> parser = await bootstrap.prepareParserRequest(candidate);

    expect(first.isSuccess, isTrue);
    expect(first.value?.fromCache, isFalse);
    expect(first.value?.file?.encodingHint, 'utf-8');
    expect(first.value?.parseRequest?.content, contains('Frieren'));
    expect((first.value?.parseRequest?.source as ExternalSubtitleSource?)?.format, SubtitleFormat.vtt);
    expect(parser.isSuccess, isTrue);
    expect(parser.value?.encodingHint, 'utf-8');
    expect(bootstrap.runtime.currentSnapshot.handoff?.fromCache, isTrue);
    expect(provider.retrieveCount, 1);
  });

  test('runtime normalizes provider failures and disposed outcomes', () async {
    final _FakeSubtitleProvider provider = _FakeSubtitleProvider(
      candidates: const <SubtitleProviderCandidate>[],
      searchFailure: const AcgProviderFailure<List<SubtitleProviderCandidate>>(
        kind: AcgProviderFailureKind.retryable,
        message: 'Provider unavailable.',
      ),
      retrieveFailure: const AcgProviderFailure<RetrievedSubtitleFile>(
        kind: AcgProviderFailureKind.notFound,
        message: 'Subtitle file missing.',
      ),
    );
    final SubtitleProviderRuntime runtime = SubtitleProviderRuntime(
      discovery: DeterministicSubtitleDiscoveryContract(
        provider: provider,
        cache: DeterministicSubtitleCacheStore(),
      ),
    );

    final SubtitleProviderActionResult<SubtitleDiscoveryResult> search = await runtime.discover(_request());
    final SubtitleProviderActionResult<SubtitleProviderHandoffResult> retrieve = await runtime.prepareProviderSubtitle(_providerCandidate(format: ProviderSubtitleFormat.ass));
    runtime.dispose();
    final SubtitleProviderActionResult<SubtitleDiscoveryResult> disposed = await runtime.discover(_request());

    expect(search.value?.providerFailures.single.kind, AcgProviderFailureKind.retryable);
    expect(runtime.currentSnapshot.failures.single.kind, SubtitleProviderRuntimeFailureKind.disposed);
    expect(retrieve.kind, SubtitleProviderActionResultKind.failed);
    expect(retrieve.failure?.kind, SubtitleProviderRuntimeFailureKind.retrievalFailed);
    expect(disposed.kind, SubtitleProviderActionResultKind.failed);
    expect(disposed.failure?.kind, SubtitleProviderRuntimeFailureKind.disposed);
  });
}

SubtitleDiscoveryRequest _request() {
  return SubtitleDiscoveryRequest(
    media: LocalMediaReference(uri: Uri.parse('file:///D:/media/frieren.mkv'), basename: 'frieren.mkv'),
    providerQuery: const SubtitleSearchQuery(
      title: 'Frieren',
      languageCode: 'ja',
      seasonNumber: 1,
      episodeNumber: 1,
    ),
  );
}

ExternalSubtitleCandidate _localCandidate() {
  return ExternalSubtitleCandidate(
    source: ExternalSubtitleSource(
      id: 'local-ja',
      format: SubtitleFormat.srt,
      languageCode: 'ja',
      uri: Uri.parse('file:///D:/media/frieren.ja.srt'),
      title: 'Local Japanese',
    ),
    matchConfidence: 0.9,
  );
}

SubtitleProviderCandidate _providerCandidate({required ProviderSubtitleFormat format}) {
  return SubtitleProviderCandidate(
    id: 'provider-candidate-${format.name}',
    providerId: const SubtitleProviderId('opensubtitles'),
    title: 'Provider Japanese ${format.name}',
    format: format,
    reference: 'provider-ref-${format.name}',
    confidence: 0.8,
    languageCode: 'ja',
    sourceUri: Uri.parse('https://subtitles.example.test/frieren.${format.name}'),
  );
}

final class _RuntimeObserver implements SubtitleProviderRuntimeObserver {
  final List<SubtitleProviderRuntimeSnapshot> snapshots = <SubtitleProviderRuntimeSnapshot>[];

  @override
  void onSubtitleProviderRuntimeSnapshot(SubtitleProviderRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}

final class _FakeLocalSubtitleScanner implements LocalExternalSubtitleScanner {
  _FakeLocalSubtitleScanner({required this.candidates});

  final List<ExternalSubtitleCandidate> candidates;

  @override
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request) => Future<List<ExternalSubtitleCandidate>>.value(candidates);
}

final class _FakeSubtitleProvider implements SubtitleProvider {
  _FakeSubtitleProvider({
    required this.candidates,
    RetrievedSubtitleFile? retrievedFile,
    this.searchFailure,
    this.retrieveFailure,
  }) : _retrievedFile = retrievedFile;

  final List<SubtitleProviderCandidate> candidates;
  final RetrievedSubtitleFile? _retrievedFile;
  final AcgProviderFailure<List<SubtitleProviderCandidate>>? searchFailure;
  final AcgProviderFailure<RetrievedSubtitleFile>? retrieveFailure;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(searchTtl: const Duration(minutes: 10), fileTtl: const Duration(hours: 1));

  @override
  String get displayName => 'OpenSubtitles Test Provider';

  @override
  ProviderGateway get gateway => _UnsupportedProviderGateway();

  @override
  String get id => 'opensubtitles';

  @override
  ProviderKind get kind => ProviderKind.subtitle;

  @override
  ProviderRegistration get registration => subtitleProviderRegistration(providerId: const SubtitleProviderId('opensubtitles'));

  @override
  SubtitleProviderId get subtitleProviderId => const SubtitleProviderId('opensubtitles');

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    return ProviderGatewayResponse<T>(value: await load(), source: ProviderGatewayResponseSource.network);
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(providerId: const ProviderId('opensubtitles'), cacheKey: cacheKey);

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(SubtitleProviderCandidate candidate) {
    retrieveCount += 1;
    final AcgProviderFailure<RetrievedSubtitleFile>? failure = retrieveFailure;
    if (failure != null) return Future<AcgProviderResult<RetrievedSubtitleFile>>.value(failure);
    return Future<AcgProviderResult<RetrievedSubtitleFile>>.value(
      AcgProviderSuccess<RetrievedSubtitleFile>(
        _retrievedFile ?? RetrievedSubtitleFile(candidate: candidate, content: '1\n00:00:01,000 --> 00:00:02,000\nFrieren', encodingHint: 'utf-8'),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(SubtitleSearchQuery query) {
    searchCount += 1;
    final AcgProviderFailure<List<SubtitleProviderCandidate>>? failure = searchFailure;
    if (failure != null) return Future<AcgProviderResult<List<SubtitleProviderCandidate>>>.value(failure);
    return Future<AcgProviderResult<List<SubtitleProviderCandidate>>>.value(AcgProviderSuccess<List<SubtitleProviderCandidate>>(candidates));
  }
}

final class _UnsupportedProviderGateway implements ProviderGateway {
  @override
  StorageFoundation get storage => throw StateError('Storage is not used by this test gateway.');

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(ProviderGatewayRequest<T> request) async {
    return ProviderGatewayResponse<T>(value: await request.load(), source: ProviderGatewayResponseSource.network);
  }

  @override
  Future<void> registerProvider(ProviderRegistration registration) => Future<void>.value();
}
