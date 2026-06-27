// Playback metadata bridge tests verify optional provider enrichment never
// blocks core playback state updates.
// Provider failures should remain metadata failures, not transport failures.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge loads provider subtitle into playback subtitle projection',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 16, 13);
    final SubtitleProviderCandidate candidate = _subtitleCandidate();
    final SubtitleProviderBootstrap bootstrap = SubtitleProviderBootstrap(
      provider: _FakeSubtitleProvider(
        candidates: <SubtitleProviderCandidate>[candidate],
        retrievedFile: RetrievedSubtitleFile(
          candidate: candidate,
          content: '1\n00:00:01,000 --> 00:00:03,000\nProvider subtitle',
          encodingHint: 'utf-8',
          cachedUri: Uri.parse('https://cdn.example.test/subtitle.srt'),
        ),
      ),
      cache: DeterministicSubtitleCacheStore(),
      clock: () => now,
    );
    final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
      subtitleProviderRuntime: bootstrap.runtime,
    );

    final PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot> load =
        await bridge.loadProviderSubtitle(candidate);
    final PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot>
        resolved = bridge.resolve(
      const PlayerClockSnapshot(
        position: Duration(seconds: 2),
        isPlaying: true,
        playbackSpeed: 1,
      ),
    );

    expect(load.isSuccess, isTrue);
    expect(load.value?.selectedTrackId, candidate.id);
    expect(resolved.isSuccess, isTrue);
    expect(
        resolved.value?.subtitles.activeCues.single.text, 'Provider subtitle');
    expect(bridge.currentSnapshot.subtitles.activeCues.single.text,
        'Provider subtitle');
  });

  test('bridge loads Dandanplay comments into playback danmaku projection',
      () async {
    final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
      dandanplayCommentProvider: const _FakeDandanplayCommentProvider(
        comments: <DandanplayComment>[
          DandanplayComment(
            timestamp: Duration(seconds: 2),
            text: 'provider comment',
            mode: DandanplayCommentMode.scrolling,
            colorArgb: 0x00ffffff,
          ),
        ],
      ),
    );

    final PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot> load =
        await bridge.loadDandanplayComments(const DandanplayEpisodeId('7'));
    final PlaybackMetadataBridgeSnapshot snapshot = bridge
        .resolve(
          const PlayerClockSnapshot(
            position: Duration(seconds: 2),
            isPlaying: true,
            playbackSpeed: 1,
          ),
        )
        .value!;

    expect(load.isSuccess, isTrue);
    expect(snapshot.danmaku.hasVisibleComments, isTrue);
    final DomainDanmakuCommentDescriptor comment = snapshot.danmaku.lanes
        .singleWhere(
          (DomainDanmakuLaneDescriptor lane) =>
              lane.mode == DomainDanmakuMode.scrolling,
        )
        .comments
        .single;
    expect(comment.text, 'provider comment');
    expect(comment.id, startsWith('7:2000:0:'));
  });

  test('bridge projects resolved danmaku through Matrix4 overlay renderer',
      () async {
    final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
      matrixDanmakuRenderer: _matrixRenderer(),
      dandanplayCommentProvider: const _FakeDandanplayCommentProvider(
        comments: <DandanplayComment>[
          DandanplayComment(
            timestamp: Duration(seconds: 2),
            text: 'matrix provider comment',
            mode: DandanplayCommentMode.scrolling,
            colorArgb: 0x00ffffff,
          ),
        ],
      ),
    );

    await bridge.loadDandanplayComments(const DandanplayEpisodeId('matrix'));
    final PlaybackMetadataBridgeSnapshot snapshot = bridge
        .resolve(
          const PlayerClockSnapshot(
            position: Duration(seconds: 2),
            isPlaying: true,
            playbackSpeed: 1,
          ),
        )
        .value!;

    expect(snapshot.danmaku.matrix.hasVisibleComments, isTrue);
    expect(snapshot.danmaku.matrix.rendererSource,
        matrixDanmakuFlutterOverlayRendererSource);
    expect(snapshot.danmaku.matrix.renderedCommentCount, 1);
    expect(snapshot.danmaku.matrix.comments.single.text,
        'matrix provider comment');
  });

  test('bridge applies metadata projection to playback state', () async {
    final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
    );
    await bridge.loadPreparedSubtitle(
      SubtitleParseRequest(
        source: ExternalSubtitleSource(
          id: 'local-subtitle',
          format: SubtitleFormat.srt,
          uri: Uri.file('D:/media/local.srt'),
        ),
        content: '1\n00:00:01,000 --> 00:00:02,000\nLocal subtitle',
      ),
    );
    bridge.loadDandanplayCommentValues(
      const <DandanplayComment>[
        DandanplayComment(
          timestamp: Duration(seconds: 1),
          text: 'inline comment',
          mode: DandanplayCommentMode.top,
        ),
      ],
      idPrefix: 'inline',
    );
    final PlaybackMetadataBridgeSnapshot metadata = bridge
        .resolve(
          const PlayerClockSnapshot(
            position: Duration(seconds: 1),
            isPlaying: true,
            playbackSpeed: 1,
          ),
        )
        .value!;

    final PlaybackStateSnapshot state = metadata.applyTo(
      PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.playing,
        sourceUri: Uri.file('D:/media/video.mkv'),
      ),
    );

    expect(state.status, PlaybackLifecycleStatus.playing);
    expect(state.subtitles.activeCues.single.text, 'Local subtitle');
    expect(state.danmaku.hasVisibleComments, isTrue);
    expect(state.sourceUri, Uri.file('D:/media/video.mkv'));
  });

  test('bridge normalizes provider failures unavailable and disposed outcomes',
      () async {
    final SubtitleProviderCandidate candidate = _subtitleCandidate();
    final PlaybackMetadataBridge unavailable = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
    );

    final PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>
        missingSubtitleProvider =
        await unavailable.loadProviderSubtitle(candidate);
    final PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>
        missingDanmakuProvider = await unavailable
            .loadDandanplayComments(const DandanplayEpisodeId('missing'));

    expect(missingSubtitleProvider.failure?.kind,
        PlaybackMetadataBridgeFailureKind.unavailable);
    expect(missingDanmakuProvider.failure?.kind,
        PlaybackMetadataBridgeFailureKind.unavailable);

    final SubtitleProviderBootstrap bootstrap = SubtitleProviderBootstrap(
      provider: _FakeSubtitleProvider(
        candidates: const <SubtitleProviderCandidate>[],
        retrieveFailure: const AcgProviderFailure<RetrievedSubtitleFile>(
          kind: AcgProviderFailureKind.retryable,
          message: 'subtitle provider failed',
        ),
      ),
      cache: DeterministicSubtitleCacheStore(),
    );
    final PlaybackMetadataBridge failing = PlaybackMetadataBridge(
      subtitleRuntime: BasicSubtitleRuntime(),
      danmakuRuntime: BasicDanmakuRuntime(),
      subtitleProviderRuntime: bootstrap.runtime,
      dandanplayCommentProvider: const _FakeDandanplayCommentProvider(
        failure: AcgProviderFailure<List<DandanplayComment>>(
          kind: AcgProviderFailureKind.throttled,
          message: 'dandanplay throttled',
        ),
      ),
    );

    final PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>
        subtitleFailure = await failing.loadProviderSubtitle(candidate);
    final PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>
        danmakuFailure =
        await failing.loadDandanplayComments(const DandanplayEpisodeId('7'));
    failing.dispose();
    final PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot>
        disposed = failing.resolve(
      const PlayerClockSnapshot(
        position: Duration.zero,
        isPlaying: false,
        playbackSpeed: 1,
      ),
    );

    expect(subtitleFailure.failure?.kind,
        PlaybackMetadataBridgeFailureKind.providerFailure);
    expect(danmakuFailure.failure?.kind,
        PlaybackMetadataBridgeFailureKind.providerFailure);
    expect(disposed.failure?.kind, PlaybackMetadataBridgeFailureKind.disposed);
    expect(
        failing.currentSnapshot.status, PlaybackMetadataBridgeStatus.disposed);
  });
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

MatrixDanmakuOverlayRenderer _matrixRenderer() {
  final PlaybackCapabilityMatrix matrix = _matrix();
  return MatrixDanmakuOverlayRenderer(
    captionRenderer: DeterministicAdvancedCaptionRenderer(
      captionStore: DeterministicAdvancedCaptionStore(),
      capabilityMatrix: matrix,
      profile: playbackMetadataMatrixDanmakuProfile,
    ),
    capabilityMatrix: matrix,
  );
}

PlaybackCapabilityMatrix _matrix() {
  return PlaybackCapabilityMatrix(
    capabilities: const <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.danmakuRendering: CapabilityStatus.supported(),
      PlaybackCapability.matrixDanmaku: CapabilityStatus.supported(),
      PlaybackCapability.dualSubtitles: CapabilityStatus.unsupported(
        'Dual subtitles are not part of this bridge test.',
      ),
      PlaybackCapability.pgsSubtitleRendering: CapabilityStatus.unsupported(
        'PGS rendering is not part of this bridge test.',
      ),
      PlaybackCapability.assSubtitleEnhancement: CapabilityStatus.unsupported(
        'ASS enhancement is not part of this bridge test.',
      ),
    },
  );
}

final class _FakeSubtitleProvider implements SubtitleProvider {
  const _FakeSubtitleProvider({
    required this.candidates,
    this.retrievedFile,
    this.retrieveFailure,
  });

  final List<SubtitleProviderCandidate> candidates;
  final RetrievedSubtitleFile? retrievedFile;
  final AcgProviderFailure<RetrievedSubtitleFile>? retrieveFailure;

  @override
  SubtitleProviderCachePolicy get cachePolicy => SubtitleProviderCachePolicy(
        searchTtl: const Duration(minutes: 10),
        fileTtl: const Duration(hours: 1),
      );

  @override
  String get displayName => 'Bridge Subtitle Provider';

  @override
  ProviderGateway get gateway => throw UnsupportedError(
        'Bridge test provider does not expose a gateway.',
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
    final AcgProviderFailure<RetrievedSubtitleFile>? failure = retrieveFailure;
    if (failure != null) return failure;
    return AcgProviderSuccess<RetrievedSubtitleFile>(
      retrievedFile ??
          RetrievedSubtitleFile(
            candidate: candidate,
            content: '1\n00:00:01,000 --> 00:00:02,000\nBridge subtitle',
            encodingHint: 'utf-8',
          ),
    );
  }

  @override
  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
    SubtitleSearchQuery query,
  ) async {
    return AcgProviderSuccess<List<SubtitleProviderCandidate>>(candidates);
  }
}

final class _FakeDandanplayCommentProvider
    implements DandanplayCommentProvider {
  const _FakeDandanplayCommentProvider({
    this.comments = const <DandanplayComment>[],
    this.failure,
  });

  final List<DandanplayComment> comments;
  final AcgProviderFailure<List<DandanplayComment>>? failure;

  @override
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
    DandanplayEpisodeId episodeId,
  ) async {
    final AcgProviderFailure<List<DandanplayComment>>? currentFailure = failure;
    if (currentFailure != null) return currentFailure;
    return AcgProviderSuccess<List<DandanplayComment>>(comments);
  }

  @override
  Future<AcgProviderResult<void>> postComment(DandanplayCommentPost post) {
    return Future<AcgProviderResult<void>>.value(
      const AcgProviderSuccess<void>(null),
    );
  }
}
