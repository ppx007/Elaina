// ACG experience runtime tests cover the coordinator across Bangumi,
// dandanplay, subtitles, and playback metadata instead of retesting providers.
// Provider wire cases belong in provider-specific runtime tests.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime prepares full ACG playback enrichment smoke path', () async {
    final _ExperienceHarness harness = _ExperienceHarness();

    final AcgExperienceResult result =
        await harness.runtime.prepare(harness.request());

    expect(result.isSuccess, isTrue);
    expect(result.status, AcgExperienceRuntimeStatus.ready);
    expect(result.bangumiSubject?.title, 'Frieren');
    expect(result.dandanplayMatch?.episodeId.value, 'episode-1');
    expect(result.subtitleCandidate?.candidate.id, 'subtitle-ja');
    expect(result.subtitleCandidate?.fromCache, isFalse);
    expect(result.playbackState.status, PlaybackLifecycleStatus.playing);
    expect(result.playbackState.subtitles.activeCues.single.text,
        'Provider subtitle');
    expect(result.playbackState.danmaku.hasVisibleComments, isTrue);
  });

  test('runtime reuses subtitle search and content cache on repeated smoke',
      () async {
    final _ExperienceHarness harness = _ExperienceHarness();

    final AcgExperienceResult first =
        await harness.runtime.prepare(harness.request());
    final AcgExperienceResult second =
        await harness.runtime.prepare(harness.request());

    expect(first.isSuccess, isTrue);
    expect(second.isSuccess, isTrue);
    expect(second.subtitleCandidate?.fromCache, isTrue);
    expect(harness.subtitleProvider.searchCount, 1);
    expect(harness.subtitleProvider.retrieveCount, 1);
  });

  test('runtime normalizes partial provider failures', () async {
    final _ExperienceHarness harness = _ExperienceHarness(
      subjects: const <BangumiSubject>[],
      matchCandidatesByFilename: const <String,
          List<DandanplayMatchCandidate>>{},
      subtitleProvider: _FakeSubtitleProvider(
        candidates: const <SubtitleProviderCandidate>[],
        searchFailure:
            const AcgProviderFailure<List<SubtitleProviderCandidate>>(
          kind: AcgProviderFailureKind.throttled,
          message: 'subtitle throttled',
        ),
      ),
    );

    final AcgExperienceResult result =
        await harness.runtime.prepare(harness.request());

    expect(result.status, AcgExperienceRuntimeStatus.failed);
    expect(result.isSuccess, isFalse);
    expect(
      result.failures.map((AcgExperienceFailure failure) => failure.kind),
      containsAll(<AcgExperienceFailureKind>{
        AcgExperienceFailureKind.bangumiSubjectFailed,
        AcgExperienceFailureKind.dandanplayMatchFailed,
        AcgExperienceFailureKind.subtitleDiscoveryFailed,
        AcgExperienceFailureKind.subtitleCandidateUnavailable,
      }),
    );
    expect(result.playbackState.subtitles.activeCues, isEmpty);
    expect(result.playbackState.danmaku.hasVisibleComments, isFalse);
  });

  test('runtime normalizes subtitle handoff failures', () async {
    final _ExperienceHarness harness = _ExperienceHarness(
      subtitleProvider: _FakeSubtitleProvider(
        candidates: <SubtitleProviderCandidate>[_subtitleCandidate()],
        retrieveFailure: const AcgProviderFailure<RetrievedSubtitleFile>(
          kind: AcgProviderFailureKind.unavailable,
          message: 'subtitle file unavailable',
        ),
      ),
    );

    final AcgExperienceResult result =
        await harness.runtime.prepare(harness.request());

    expect(result.status, AcgExperienceRuntimeStatus.failed);
    expect(
      result.failures.map((AcgExperienceFailure failure) => failure.kind),
      contains(AcgExperienceFailureKind.subtitleHandoffFailed),
    );
    expect(result.playbackState.subtitles.activeCues, isEmpty);
    expect(result.playbackState.danmaku.hasVisibleComments, isTrue);
  });

  test('runtime publishes disposed result without throwing raw errors',
      () async {
    final _ExperienceHarness harness = _ExperienceHarness();
    harness.runtime.dispose();

    final AcgExperienceResult result =
        await harness.runtime.prepare(harness.request());

    expect(result.status, AcgExperienceRuntimeStatus.disposed);
    expect(result.failures.single.kind, AcgExperienceFailureKind.disposed);
    expect(harness.runtime.currentResult.status,
        AcgExperienceRuntimeStatus.disposed);
  });
}

final class _ExperienceHarness {
  _ExperienceHarness({
    Iterable<BangumiSubject> subjects = _defaultSubjects,
    Map<String, List<DandanplayMatchCandidate>> matchCandidatesByFilename =
        _defaultMatches,
    _FakeSubtitleProvider? subtitleProvider,
  }) : subtitleProvider = subtitleProvider ?? _FakeSubtitleProvider.standard() {
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: storage);
    final BangumiProviderRuntime bangumi = BangumiProviderRuntime(
      gateway: gateway,
      subjects: subjects,
      episodes: _defaultEpisodes,
    );
    final DandanplayProviderRuntime dandanplay = DandanplayProviderRuntime(
      gateway: gateway,
      matchCandidatesByFilename: matchCandidatesByFilename,
      commentsByEpisodeId: _defaultComments,
    );
    final AcgDataController controller = AcgDataController(
      bangumiProvider: bangumi,
      bangumiAuthProvider: bangumi,
      dandanplayProvider: dandanplay,
      dandanplayCommentProvider: dandanplay,
    );
    final SubtitleProviderBootstrap subtitleBootstrap =
        SubtitleProviderBootstrap(
      provider: this.subtitleProvider,
      cache: DeterministicSubtitleCacheStore(),
      clock: () => DateTime.utc(2026, 6, 17, 10),
    );
    final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
      subtitleProviderRuntime: subtitleBootstrap.runtime,
      dandanplayCommentProvider: dandanplay,
    );
    runtime = AcgExperienceRuntime(
      controller: controller,
      subtitleProviderRuntime: subtitleBootstrap.runtime,
      metadataBridge: bridge,
    );
  }

  final _FakeSubtitleProvider subtitleProvider;
  late final AcgExperienceRuntime runtime;

  AcgExperienceRequest request() {
    return AcgExperienceRequest(
      media: LocalMediaReference(
        uri: Uri.file('D:/media/frieren-01.mkv'),
        basename: 'frieren-01.mkv',
      ),
      subtitleQuery: const SubtitleSearchQuery(
        title: 'Frieren',
        languageCode: 'ja',
        seasonNumber: 1,
        episodeNumber: 1,
      ),
      dandanplayFilename: 'Frieren - 01.mkv',
      bangumiSubjectId: const BangumiSubjectId('subject-1'),
      clock: const PlayerClockSnapshot(
        position: Duration(seconds: 1),
        isPlaying: true,
        playbackSpeed: 1,
      ),
      basePlaybackState: PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.playing,
        sourceUri: Uri.file('D:/media/frieren-01.mkv'),
      ),
    );
  }
}

const List<BangumiSubject> _defaultSubjects = <BangumiSubject>[
  BangumiSubject(
    id: BangumiSubjectId('subject-1'),
    title: 'Frieren',
    summary: 'Journey beyond the end.',
  ),
];

const List<BangumiEpisode> _defaultEpisodes = <BangumiEpisode>[
  BangumiEpisode(
    id: BangumiEpisodeId('bangumi-episode-1'),
    subjectId: BangumiSubjectId('subject-1'),
    index: 1,
    title: 'The Journey Begins',
  ),
];

const DandanplayMatchCandidate _defaultMatch = DandanplayMatchCandidate(
  animeId: DandanplayAnimeId('anime-1'),
  episodeId: DandanplayEpisodeId('episode-1'),
  title: 'Frieren - 01',
  confidence: 0.98,
);

const Map<String, List<DandanplayMatchCandidate>> _defaultMatches =
    <String, List<DandanplayMatchCandidate>>{
  'Frieren - 01.mkv': <DandanplayMatchCandidate>[_defaultMatch],
};

const Map<String, List<DandanplayComment>> _defaultComments =
    <String, List<DandanplayComment>>{
  'episode-1': <DandanplayComment>[
    DandanplayComment(
      timestamp: Duration(seconds: 1),
      text: 'provider danmaku',
      mode: DandanplayCommentMode.scrolling,
    ),
  ],
};

final class _FakeSubtitleProvider implements SubtitleProvider {
  _FakeSubtitleProvider({
    required this.candidates,
    this.searchFailure,
    this.retrieveFailure,
    RetrievedSubtitleFile? retrievedFile,
  }) : _retrievedFile = retrievedFile;

  factory _FakeSubtitleProvider.standard() {
    final SubtitleProviderCandidate candidate = _subtitleCandidate();
    return _FakeSubtitleProvider(
      candidates: <SubtitleProviderCandidate>[candidate],
      retrievedFile: RetrievedSubtitleFile(
        candidate: candidate,
        content: '1\n00:00:01,000 --> 00:00:02,000\nProvider subtitle',
        encodingHint: 'utf-8',
        cachedUri: Uri.parse('https://cdn.example.test/frieren-01.srt'),
      ),
    );
  }

  final List<SubtitleProviderCandidate> candidates;
  final AcgProviderFailure<List<SubtitleProviderCandidate>>? searchFailure;
  final AcgProviderFailure<RetrievedSubtitleFile>? retrieveFailure;
  final RetrievedSubtitleFile? _retrievedFile;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
        searchTtl: const Duration(minutes: 10),
        fileTtl: const Duration(hours: 1),
      );

  @override
  String get displayName => 'ACG Experience Subtitle Provider';

  @override
  ProviderGateway get gateway => throw UnsupportedError(
        'ACG experience fake subtitle provider does not expose a gateway.',
      );

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
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    return ProviderGatewayResponse<T>(
      value: await load(),
      source: ProviderGatewayResponseSource.network,
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) => ProviderRequestKey(
        providerId: const ProviderId('opensubtitles'),
        cacheKey: cacheKey,
      );

  @override
  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
    SubtitleProviderCandidate candidate,
  ) async {
    retrieveCount += 1;
    final AcgProviderFailure<RetrievedSubtitleFile>? failure = retrieveFailure;
    if (failure != null) return failure;
    return AcgProviderSuccess<RetrievedSubtitleFile>(
      _retrievedFile ??
          RetrievedSubtitleFile(
            candidate: candidate,
            content: '1\n00:00:01,000 --> 00:00:02,000\nSubtitle',
            encodingHint: 'utf-8',
          ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
    SubtitleSearchQuery query,
  ) async {
    searchCount += 1;
    final AcgProviderFailure<List<SubtitleProviderCandidate>>? failure =
        searchFailure;
    if (failure != null) return failure;
    return AcgProviderSuccess<List<SubtitleProviderCandidate>>(candidates);
  }
}

SubtitleProviderCandidate _subtitleCandidate() {
  return const SubtitleProviderCandidate(
    id: 'subtitle-ja',
    providerId: SubtitleProviderId('opensubtitles'),
    title: 'Japanese',
    format: ProviderSubtitleFormat.srt,
    reference: 'subtitle-ref',
    confidence: 0.9,
    languageCode: 'ja',
  );
}
