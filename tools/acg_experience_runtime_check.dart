import '../lib/elaina.dart';

Future<void> main() async {
  await verifyAcgExperienceRuntimeContract();
}

Future<void> verifyAcgExperienceRuntimeContract() async {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  final DeterministicProviderGateway gateway =
      DeterministicProviderGateway(storage: storage);
  const BangumiSubject subject = BangumiSubject(
    id: BangumiSubjectId('subject-check'),
    title: 'ACG Check',
  );
  const DandanplayMatchCandidate match = DandanplayMatchCandidate(
    animeId: DandanplayAnimeId('anime-check'),
    episodeId: DandanplayEpisodeId('episode-check'),
    title: 'ACG Check Episode',
    confidence: 0.99,
  );
  final BangumiProviderRuntime bangumi = BangumiProviderRuntime(
    gateway: gateway,
    subjects: const <BangumiSubject>[subject],
  );
  final DandanplayProviderRuntime dandanplay = DandanplayProviderRuntime(
    gateway: gateway,
    matchCandidatesByFilename: const <String, List<DandanplayMatchCandidate>>{
      'ACG Check - 01.mkv': <DandanplayMatchCandidate>[match],
    },
    commentsByEpisodeId: const <String, List<DandanplayComment>>{
      'episode-check': <DandanplayComment>[
        DandanplayComment(
          timestamp: Duration(seconds: 1),
          text: 'acg-check-danmaku',
          mode: DandanplayCommentMode.scrolling,
        ),
      ],
    },
  );
  final AcgDataController controller = AcgDataController(
    bangumiProvider: bangumi,
    bangumiAuthProvider: bangumi,
    dandanplayProvider: dandanplay,
    dandanplayCommentProvider: dandanplay,
  );
  final _SmokeSubtitleProvider subtitleProvider = _SmokeSubtitleProvider();
  final SubtitleProviderBootstrap subtitle = SubtitleProviderBootstrap(
    provider: subtitleProvider,
    cache: DeterministicSubtitleCacheStore(),
    clock: () => DateTime.utc(2026, 6, 17, 11),
  );
  final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
    subtitleRuntime: BasicSubtitleRuntime(),
    danmakuRuntime: BasicDanmakuRuntime(),
    subtitleProviderRuntime: subtitle.runtime,
    dandanplayCommentProvider: dandanplay,
  );
  final AcgExperienceRuntime runtime = AcgExperienceRuntime(
    controller: controller,
    subtitleProviderRuntime: subtitle.runtime,
    metadataBridge: bridge,
  );

  final AcgExperienceRequest request = AcgExperienceRequest(
    media: LocalMediaReference(
      uri: Uri.file('D:/media/acg-check-01.mkv'),
      basename: 'acg-check-01.mkv',
    ),
    subtitleQuery: const SubtitleSearchQuery(
      title: 'ACG Check',
      languageCode: 'ja',
      seasonNumber: 1,
      episodeNumber: 1,
    ),
    dandanplayFilename: 'ACG Check - 01.mkv',
    bangumiSubjectId: const BangumiSubjectId('subject-check'),
    clock: const PlayerClockSnapshot(
      position: Duration(seconds: 1),
      isPlaying: true,
      playbackSpeed: 1,
    ),
    basePlaybackState: PlaybackStateSnapshot(
      status: PlaybackLifecycleStatus.playing,
      sourceUri: Uri.file('D:/media/acg-check-01.mkv'),
    ),
  );

  final AcgExperienceResult first = await runtime.prepare(request);
  final AcgExperienceResult second = await runtime.prepare(request);
  _expect(
      first.isSuccess, 'ACG experience runtime must prepare full smoke path.');
  _expect(second.isSuccess,
      'ACG experience runtime must prepare repeated smoke path.');
  _expect(first.bangumiSubject?.title == 'ACG Check',
      'ACG experience runtime must include Bangumi metadata.');
  _expect(first.dandanplayMatch?.episodeId.value == 'episode-check',
      'ACG experience runtime must include Dandanplay match.');
  _expect(
      first.playbackState.subtitles.activeCues.single.text ==
          'acg-check-subtitle',
      'ACG experience runtime must project subtitles.');
  _expect(first.playbackState.danmaku.hasVisibleComments,
      'ACG experience runtime must project danmaku.');
  _expect(second.subtitleCandidate?.fromCache == true,
      'ACG experience runtime must reuse subtitle search cache.');
  _expect(subtitleProvider.searchCount == 1,
      'ACG experience runtime must not repeat cached subtitle searches.');
  _expect(subtitleProvider.retrieveCount == 1,
      'ACG experience runtime must not repeat cached subtitle retrieval.');

  runtime.dispose();
  final AcgExperienceResult disposed = await runtime.prepare(request);
  _expect(disposed.status == AcgExperienceRuntimeStatus.disposed,
      'ACG experience runtime must normalize disposed operations.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _SmokeSubtitleProvider implements SubtitleProvider {
  _SmokeSubtitleProvider()
      : candidate = const SubtitleProviderCandidate(
          id: 'acg-check-subtitle',
          providerId: SubtitleProviderId('opensubtitles'),
          title: 'ACG Check Japanese',
          format: ProviderSubtitleFormat.srt,
          reference: 'acg-check-subtitle-ref',
          confidence: 0.9,
          languageCode: 'ja',
        );

  final SubtitleProviderCandidate candidate;
  int searchCount = 0;
  int retrieveCount = 0;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
        searchTtl: const Duration(minutes: 10),
        fileTtl: const Duration(hours: 1),
      );

  @override
  String get displayName => 'ACG Check Subtitle Provider';

  @override
  ProviderGateway get gateway =>
      throw UnsupportedError('ACG smoke subtitle provider has no gateway.');

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
    return AcgProviderSuccess<RetrievedSubtitleFile>(
      RetrievedSubtitleFile(
        candidate: candidate,
        content: '1\n00:00:01,000 --> 00:00:02,000\nacg-check-subtitle',
        encodingHint: 'utf-8',
        cachedUri: Uri.parse('https://cdn.example.test/acg-check.srt'),
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
    SubtitleSearchQuery query,
  ) async {
    searchCount += 1;
    return AcgProviderSuccess<List<SubtitleProviderCandidate>>(
      <SubtitleProviderCandidate>[candidate],
    );
  }
}
