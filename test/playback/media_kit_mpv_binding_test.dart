import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

// Native playback boundary tests.
//
// The libmpv resolver and media-kit binding are tested with injected filesystem
// and player doubles so CI does not need to launch a native player process.
void main() {
  group('bundled libmpv resolver', () {
    test('prefers explicit dll path when it exists', () {
      const String dll = r'C:\app\libmpv-2.dll';

      final String? resolved =
          BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        explicitLibMpvPath: dll,
        isWindows: true,
        fileExists: (String path) => path == dll,
        directoryExists: (_) => false,
      );

      expect(resolved, dll);
    });

    test('accepts explicit directory containing libmpv dll', () {
      const String directory = r'C:\app';
      const String dll = r'C:\app\libmpv-2.dll';

      final String? resolved =
          BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        explicitLibMpvPath: directory,
        isWindows: true,
        fileExists: (String path) => path == dll,
        directoryExists: (String path) => path == directory,
      );

      expect(resolved, dll);
    });

    test('uses environment dll path before executable directory', () {
      const String envDll = r'C:\portable\libmpv-2.dll';
      const String exeDll = r'C:\release\libmpv-2.dll';

      final String? resolved =
          BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        environment: const <String, String>{
          elainaLibMpvPathEnvironmentKey: envDll,
        },
        executablePath: r'C:\release\Elaina.exe',
        isWindows: true,
        fileExists: (String path) => path == envDll || path == exeDll,
        directoryExists: (_) => false,
      );

      expect(resolved, envDll);
    });

    test('uses dll beside executable for unzip-and-run release', () {
      const String exeDll = r'C:\release\libmpv-2.dll';

      final String? resolved =
          BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        environment: const <String, String>{},
        executablePath: r'C:\release\Elaina.exe',
        isWindows: true,
        fileExists: (String path) => path == exeDll,
        directoryExists: (_) => false,
      );

      expect(resolved, exeDll);
    });

    test('returns null for non-windows platforms and missing candidates', () {
      expect(
        BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
          explicitLibMpvPath: r'C:\missing\libmpv-2.dll',
          isWindows: false,
          fileExists: (_) => true,
          directoryExists: (_) => true,
        ),
        isNull,
      );
      expect(
        BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
          explicitLibMpvPath: r'C:\missing\libmpv-2.dll',
          environment: const <String, String>{},
          executablePath: r'C:\release\Elaina.exe',
          isWindows: true,
          fileExists: (_) => false,
          directoryExists: (_) => false,
        ),
        isNull,
      );
    });
  });

  test('concrete binding maps local file commands to backend operations',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final LocalFilePlaybackSource source = _localSource();

    expect((await binding.load(source)).isSuccess, isTrue);
    expect((await binding.play()).isSuccess, isTrue);
    expect((await binding.pause()).isSuccess, isTrue);
    expect((await binding.seek(const Duration(seconds: 42))).isSuccess, isTrue);
    expect((await binding.stop()).isSuccess, isTrue);
    expect((await binding.dispose()).isSuccess, isTrue);

    expect(backend.openedUri, source.uri);
    expect(backend.seekPosition, const Duration(seconds: 42));
    expect(
      backend.operations,
      <PlaybackOperation>[
        PlaybackOperation.load,
        PlaybackOperation.play,
        PlaybackOperation.pause,
        PlaybackOperation.seek,
        PlaybackOperation.stop,
        PlaybackOperation.dispose,
      ],
    );
    expect(binding.isDisposed, isTrue);
  });

  test('concrete binding rejects non-local sources without backend delegation',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCommandResult result = await binding.load(
      HttpPlaybackSource(uri: Uri.parse('https://example.invalid/video.mkv')),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.unsupported);
    expect(backend.operations, isEmpty);
  });

  test('concrete binding normalizes backend operation failures', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      failOn: PlaybackOperation.play,
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCommandResult result = await binding.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.play);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.play]);
  });

  test('concrete binding normalizes backend construction failures', () async {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backendFactory: () => throw StateError('native player unavailable'),
    );

    final PlaybackCommandResult result = await binding.play();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.play);
    expect(result.failure?.kind, PlaybackFailureKind.operationFailed);
  });

  test('concrete binding rejects commands after dispose', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    expect((await binding.dispose()).isSuccess, isTrue);
    final PlaybackCommandResult result = await binding.stop();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.operation, PlaybackOperation.stop);
    expect(result.failure?.kind, PlaybackFailureKind.disposed);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.dispose]);
  });

  test('concrete binding leaves tracks unsupported until mapped', () async {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(),
    );

    final TrackDiscoveryResult discovery = await binding.discoverTracks();
    final TrackSwitchResult switchResult = await binding.switchTrack(
      const MediaTrackId('subtitle-ja'),
    );

    expect(discovery.tracks, isEmpty);
    expect(
      discovery.capabilityMatrix
          .supports(PlaybackCapability.audioTrackDiscovery),
      isFalse,
    );
    expect(switchResult.isSuccess, isFalse);
  });

  test('enhancement planner maps profile intent to MPV property commands', () {
    final Uri shader = Uri.parse('mpv-shader://anime4k/restore');
    final MpvEnhancementPlanResult result = MpvEnhancementPlanner(
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore: shader,
      },
    ).build(_enhancementProfile());

    expect(result.isSuccess, isTrue);
    final MpvEnhancementPlan plan = result.plan!;
    expect(
      plan.commands
          .where((MpvEnhancementCommand command) =>
              command.kind == MpvEnhancementCommandKind.setProperty)
          .map((MpvEnhancementCommand command) => command.property),
      <String>[
        mpvEnhancementScaleProperty,
        mpvEnhancementChromaScaleProperty,
        mpvEnhancementToneMappingProperty,
        mpvEnhancementDebandProperty,
        mpvEnhancementDebandIterationsProperty,
      ],
    );
    expect(
      plan.commands.last.arguments,
      <String>[
        mpvEnhancementChangeListCommand,
        mpvEnhancementGlslShadersOption,
        mpvEnhancementAppendOperation,
        shader.toString(),
      ],
    );
  });

  test('enhancement binding applies profile through backend commands',
      () async {
    final Uri shader = Uri.parse('mpv-shader://anime4k/restore');
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: backend,
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore: shader,
      },
    );

    final EnhancementApplyOutcome result =
        await binding.applyEnhancement(_enhancementProfile());

    expect(result.isSuccess, isTrue);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => <String>[call.property, call.value]),
      <List<String>>[
        <String>[
          mpvEnhancementScaleProperty,
          mpvEnhancementSharpScalerValue,
        ],
        <String>[
          mpvEnhancementChromaScaleProperty,
          mpvEnhancementSharpScalerValue,
        ],
        <String>[
          mpvEnhancementToneMappingProperty,
          mpvEnhancementToneMapToSdrValue,
        ],
        <String>[
          mpvEnhancementDebandProperty,
          mpvEnhancementEnabledValue,
        ],
        <String>[
          mpvEnhancementDebandIterationsProperty,
          mpvEnhancementDebandMediumIterations,
        ],
      ],
    );
    expect(
      backend.commandCalls.single,
      <String>[
        mpvEnhancementChangeListCommand,
        mpvEnhancementGlslShadersOption,
        mpvEnhancementAppendOperation,
        shader.toString(),
      ],
    );
  });

  test('enhancement binding rejects Anime4K intent without shader path',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final EnhancementApplyOutcome result =
        await binding.applyEnhancement(_enhancementProfile());

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind,
        EnhancementPipelineFailureKind.capabilityUnsupported);
    expect(backend.propertyCalls, isEmpty);
    expect(backend.commandCalls, isEmpty);
  });

  test('enhancement binding normalizes backend failures', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      failOnProperty: mpvEnhancementToneMappingProperty,
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: backend,
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore: Uri.parse('mpv-shader://anime4k/restore'),
      },
    );

    final EnhancementApplyOutcome result =
        await binding.applyEnhancement(_enhancementProfile());

    expect(result.isSuccess, isFalse);
    expect(
        result.failure?.kind, EnhancementPipelineFailureKind.adapterRejected);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => call.property)
          .contains(mpvEnhancementToneMappingProperty),
      isTrue,
    );
  });

  test('enhancement binding disables deband tone mapping and shaders',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final EnhancementDisableOutcome result = await binding.disableEnhancement();

    expect(result.isSuccess, isTrue);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => <String>[call.property, call.value]),
      <List<String>>[
        <String>[
          mpvEnhancementToneMappingProperty,
          mpvEnhancementAutoValue,
        ],
        <String>[
          mpvEnhancementDebandProperty,
          mpvEnhancementDisabledValue,
        ],
      ],
    );
    expect(
      backend.commandCalls.single,
      <String>[
        mpvEnhancementChangeListCommand,
        mpvEnhancementGlslShadersOption,
        mpvEnhancementClearOperation,
        mpvEnhancementClearValue,
      ],
    );
  });

  test('subtitle planner maps ordered embedded dual subtitles', () {
    final MpvSubtitlePlan plan = const MpvSubtitlePlanner().buildDualSubtitles(
      DualSubtitleRequest(
        primary: _embeddedSubtitle('primary', trackId: 'sid-primary'),
        secondary: _embeddedSubtitle('secondary', trackId: 'sid-secondary'),
      ),
    );

    expect(plan.feature, AdvancedCaptionFeature.dualSubtitles);
    expect(
      plan.commands.map((MpvSubtitleCommand command) =>
          <String>[command.property!, command.value!]),
      <List<String>>[
        <String>[mpvSubtitlePrimaryProperty, 'sid-primary'],
        <String>[mpvSubtitleSecondaryProperty, 'sid-secondary'],
      ],
    );
  });

  test('subtitle bridge applies ordered dual subtitles through backend',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final CaptionRenderOutcome result = await binding.renderDualSubtitles(
      DualSubtitleRequest(
        primary: _embeddedSubtitle('primary', trackId: 'sid-primary'),
        secondary: _embeddedSubtitle('secondary', trackId: 'sid-secondary'),
      ),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isTrue);
    expect(result.feature, AdvancedCaptionFeature.dualSubtitles);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => <String>[call.property, call.value]),
      <List<String>>[
        <String>[mpvSubtitlePrimaryProperty, 'sid-primary'],
        <String>[mpvSubtitleSecondaryProperty, 'sid-secondary'],
      ],
    );
  });

  test('subtitle bridge rejects duplicate dual subtitle selection', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final EmbeddedSubtitleSource subtitle =
        _embeddedSubtitle('same', trackId: 'sid-same');

    final CaptionRenderOutcome result = await binding.renderDualSubtitles(
      DualSubtitleRequest(primary: subtitle, secondary: subtitle),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind,
        AdvancedCaptionFailureKind.dualSubtitleOrderRejected);
    expect(backend.propertyCalls, isEmpty);
    expect(backend.commandCalls, isEmpty);
  });

  test('subtitle bridge applies ASS external subtitle intent', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final ExternalSubtitleSource source = _externalSubtitle(
      'ass-ja',
      uri: Uri.file('D:/media/episode.ja.ass'),
      format: SubtitleFormat.ass,
      languageCode: 'ja',
      title: 'Japanese ASS',
    );

    final CaptionRenderOutcome result = await binding.renderAdvancedSubtitle(
      AdvancedSubtitleRequest(
        source: source,
        intent: AdvancedSubtitleRenderIntent.assEnhancedLayout,
      ),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isTrue);
    expect(result.feature, AdvancedCaptionFeature.assEnhancement);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => <String>[call.property, call.value]),
      <List<String>>[
        <String>[mpvSubtitleAssProperty, mpvSubtitleEnabledValue],
        <String>[mpvSubtitlePrimaryProperty, mpvSubtitleAutoValue],
      ],
    );
    expect(
      backend.commandCalls.single,
      <String>[
        mpvSubtitleAddCommand,
        source.uri.toFilePath(),
        mpvSubtitleSelectFlag,
        'Japanese ASS',
        'ja',
      ],
    );
  });

  test('subtitle bridge applies PGS external subtitle intent', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final ExternalSubtitleSource source = _externalSubtitle(
      'pgs-main',
      uri: Uri.parse('https://media.example.test/subtitle.sup'),
      format: SubtitleFormat.srt,
    );

    final CaptionRenderOutcome result = await binding.renderAdvancedSubtitle(
      AdvancedSubtitleRequest(
        source: source,
        intent: AdvancedSubtitleRenderIntent.pgsImageSubtitle,
      ),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isTrue);
    expect(result.feature, AdvancedCaptionFeature.pgsRendering);
    expect(
      backend.commandCalls.single,
      <String>[
        mpvSubtitleAddCommand,
        source.uri.toString(),
        mpvSubtitleSelectFlag,
        source.id,
      ],
    );
    expect(
      backend.propertyCalls.single.value,
      mpvSubtitleAutoValue,
    );
  });

  test('subtitle bridge disables subtitle properties and removes active track',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final CaptionDisableOutcome result =
        await binding.disableAdvancedSubtitles();

    expect(result.isSuccess, isTrue);
    expect(
      backend.propertyCalls
          .map((_PropertyCall call) => <String>[call.property, call.value]),
      <List<String>>[
        <String>[mpvSubtitlePrimaryProperty, mpvSubtitleNoValue],
        <String>[mpvSubtitleSecondaryProperty, mpvSubtitleNoValue],
        <String>[mpvSubtitleAssProperty, mpvSubtitleDisabledValue],
      ],
    );
    expect(backend.commandCalls.single, <String>[mpvSubtitleRemoveCommand]);
  });

  test('subtitle bridge normalizes backend failures', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      failOnProperty: mpvSubtitleSecondaryProperty,
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final CaptionRenderOutcome result = await binding.renderDualSubtitles(
      DualSubtitleRequest(
        primary: _embeddedSubtitle('primary', trackId: 'sid-primary'),
        secondary: _embeddedSubtitle('secondary', trackId: 'sid-secondary'),
      ),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, AdvancedCaptionFailureKind.adapterRejected);
  });

  test('subtitle bridge reports Matrix4 danmaku unsupported', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final CaptionRenderOutcome result = await binding.renderMatrixDanmaku(
      MatrixDanmakuRequest(
        comments: const <DanmakuComment>[],
        transform: CaptionTransform4(values: _identityTransform()),
      ),
      profile: _captionProfile(),
    );

    expect(result.isSuccess, isFalse);
    expect(
        result.failure?.kind, AdvancedCaptionFailureKind.capabilityUnsupported);
    expect(backend.propertyCalls, isEmpty);
    expect(backend.commandCalls, isEmpty);
  });

  test('local file capability matrix declares only verified operations', () {
    final PlaybackCapabilityMatrix matrix =
        mediaKitLocalFilePlaybackCapabilities();

    expect(matrix.supports(PlaybackCapability.localFilePlayback), isTrue);
    expect(matrix.supports(PlaybackCapability.playPause), isTrue);
    expect(matrix.supports(PlaybackCapability.seek), isTrue);
    expect(matrix.supports(PlaybackCapability.stop), isTrue);
    expect(matrix.supports(PlaybackCapability.httpPlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.hlsPlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.audioTrackDiscovery), isFalse);
    expect(matrix.supports(PlaybackCapability.subtitleTrackSwitching), isFalse);
    expect(matrix.supports(PlaybackCapability.videoEnhancement), isTrue);
    expect(matrix.supports(PlaybackCapability.hdrToneMapping), isTrue);
    expect(matrix.supports(PlaybackCapability.debandFiltering), isTrue);
    expect(matrix.supports(PlaybackCapability.anime4kPreset), isFalse);
    expect(matrix.supports(PlaybackCapability.dualSubtitles), isTrue);
    expect(matrix.supports(PlaybackCapability.pgsSubtitleRendering), isTrue);
    expect(matrix.supports(PlaybackCapability.assSubtitleEnhancement), isTrue);
    expect(matrix.supports(PlaybackCapability.matrixDanmaku), isFalse);
    expect(
      mediaKitLocalFilePlaybackCapabilities(anime4kShadersAvailable: true)
          .supports(PlaybackCapability.anime4kPreset),
      isTrue,
    );
  });

  test('composition factory returns binding with verified capabilities', () {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final PlayerRuntimeCompositionContract composition =
        mediaKitLocalFilePlayerRuntimeComposition(
      backend: backend,
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore: Uri.parse('mpv-shader://anime4k/restore'),
      },
    );

    expect(composition.binding, isA<MediaKitMpvBinding>());
    expect(
      composition.capabilities.supports(PlaybackCapability.localFilePlayback),
      isTrue,
    );
    expect(
      composition.capabilities.supports(PlaybackCapability.hlsPlayback),
      isFalse,
    );
    expect(
      composition.capabilities.supports(PlaybackCapability.anime4kPreset),
      isTrue,
    );
  });

  test('composition exposes only verified UI-facing controls', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final PlayerCoreBootstrap bootstrap = PlayerCoreBootstrap.withComposition(
      composition: mediaKitLocalFilePlayerRuntimeComposition(backend: backend),
    );
    final PlaybackPageContract page = PlaybackPageContract(
      controller: bootstrap.controller,
    );

    final PlaybackPageSurfaceDescriptor surface = page.resolveSurface();

    expect(surface.hasActiveControl(PlaybackPageControlId.playPause), isTrue);
    expect(surface.hasActiveControl(PlaybackPageControlId.seek), isTrue);
    expect(surface.hasActiveControl(PlaybackPageControlId.stop), isTrue);
    expect(surface.hasActiveControl(PlaybackPageControlId.progress), isFalse);
    expect(
        surface.hasActiveControl(PlaybackPageControlId.audioTracks), isFalse);
    expect(surface.hasActiveControl(PlaybackPageControlId.subtitleTracks),
        isFalse);
    expect(surface.hasActivePanel(PlaybackPagePanelId.tracks), isFalse);

    final PlaybackPageIntentResult panelResult =
        await page.dispatch(const PlaybackPageIntent.openPanel(
      PlaybackPagePanelId.tracks,
    ));
    final PlaybackPageIntentResult trackResult =
        await page.dispatch(const PlaybackPageIntent.selectTrack(
      trackId: DomainMediaTrackId('audio-main'),
      trackType: DomainMediaTrackType.audio,
    ));

    expect(panelResult.outcome, PlaybackPageIntentOutcome.unsupported);
    expect(trackResult.outcome, PlaybackPageIntentOutcome.unsupported);
    expect(backend.operations, isEmpty);

    await bootstrap.dispose();
  });

  test('bootstrap can wire concrete binding with verified capabilities',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final PlayerRuntimeCompositionContract composition =
        mediaKitLocalFilePlayerRuntimeComposition(backend: backend);
    final PlayerCoreBootstrap bootstrap = PlayerCoreBootstrap.withComposition(
      composition: composition,
    );

    expect(
      bootstrap.runtime.capabilityMatrix
          .supports(PlaybackCapability.localFilePlayback),
      isTrue,
    );
    expect((await bootstrap.controller.open(_localSource())).isSuccess, isTrue);
    expect((await bootstrap.controller.play()).isSuccess, isTrue);

    final PlaybackCommandResult hlsResult = await bootstrap.controller.open(
      HlsPlaybackSource(
          uri: Uri.parse('https://example.invalid/playlist.m3u8')),
    );

    expect(hlsResult.isSuccess, isFalse);
    expect(hlsResult.failure?.kind, PlaybackFailureKind.unsupported);
    expect(
      backend.operations,
      <PlaybackOperation>[
        PlaybackOperation.load,
        PlaybackOperation.play,
      ],
    );

    await bootstrap.dispose();
  });
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
}

VideoEnhancementProfile _enhancementProfile() {
  return const VideoEnhancementProfile(
    id: EnhancementProfileId('anime-vivid'),
    label: 'Anime Vivid',
    scaler: VideoScalerIntent.animeOptimized,
    hdrHandling: HdrHandlingIntent.toneMapToSdr,
    deband: DebandIntent.medium,
    anime4kPreset: Anime4kPresetIntent.restore,
  );
}

AdvancedCaptionProfile _captionProfile() {
  return const AdvancedCaptionProfile(
    id: AdvancedCaptionProfileId('caption-vivid'),
    label: 'Caption Vivid',
    matrixDanmakuEnabled: false,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
  );
}

EmbeddedSubtitleSource _embeddedSubtitle(
  String id, {
  required String trackId,
}) {
  return EmbeddedSubtitleSource(
    id: id,
    format: SubtitleFormat.srt,
    trackId: trackId,
  );
}

ExternalSubtitleSource _externalSubtitle(
  String id, {
  required Uri uri,
  required SubtitleFormat format,
  String? languageCode,
  String? title,
}) {
  return ExternalSubtitleSource(
    id: id,
    format: format,
    uri: uri,
    languageCode: languageCode,
    title: title,
  );
}

List<double> _identityTransform() {
  return <double>[
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ];
}

final class _FakeMediaKitMpvBackend implements MediaKitMpvBackend {
  _FakeMediaKitMpvBackend({this.failOn, this.failOnProperty});

  @override
  Player get player =>
      throw UnimplementedError('Fake backend does not implement player getter');

  final PlaybackOperation? failOn;
  final String? failOnProperty;
  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  final List<_PropertyCall> propertyCalls = <_PropertyCall>[];
  final List<List<String>> commandCalls = <List<String>>[];
  Uri? openedUri;
  Duration? seekPosition;

  @override
  Future<void> openLocalFile(Uri uri) async {
    _record(PlaybackOperation.load);
    openedUri = uri;
  }

  @override
  Future<void> play() async {
    _record(PlaybackOperation.play);
  }

  @override
  Future<void> pause() async {
    _record(PlaybackOperation.pause);
  }

  @override
  Future<void> seek(Duration position) async {
    _record(PlaybackOperation.seek);
    seekPosition = position;
  }

  @override
  Future<void> stop() async {
    _record(PlaybackOperation.stop);
  }

  @override
  Future<void> setProperty(String property, String value) async {
    propertyCalls.add(_PropertyCall(property, value));
    if (failOnProperty == property) {
      throw StateError('forced $property failure');
    }
  }

  @override
  Future<void> command(List<String> arguments) async {
    commandCalls.add(List<String>.unmodifiable(arguments));
  }

  @override
  Future<void> dispose() async {
    _record(PlaybackOperation.dispose);
  }

  void _record(PlaybackOperation operation) {
    operations.add(operation);
    if (failOn == operation) {
      throw StateError('forced $operation failure');
    }
  }
}

final class _PropertyCall {
  const _PropertyCall(this.property, this.value);

  final String property;
  final String value;
}
