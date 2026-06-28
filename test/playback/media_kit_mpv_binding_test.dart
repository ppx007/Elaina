import 'dart:async';
import 'dart:io';

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

  test('concrete binding maps HTTP sources to backend URI open', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final Uri uri = Uri.parse('https://example.invalid/video.mkv');

    final PlaybackCommandResult result =
        await binding.load(HttpPlaybackSource(uri: uri));

    expect(result.isSuccess, isTrue);
    expect(backend.openedUri, uri);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.load]);
  });

  test('concrete binding maps virtual stream sources to backend URI open',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
    final Uri uri = Uri.parse('http://127.0.0.1:49152/stream/1/0');

    final PlaybackCommandResult result = await binding.load(
      VirtualStreamPlaybackSource.fromValues(
        streamId: 'stream-1',
        contentUri: uri,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(backend.openedUri, uri);
    expect(backend.operations, <PlaybackOperation>[PlaybackOperation.load]);
  });

  test(
      'concrete binding rejects unsupported sources without backend delegation',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCommandResult result = await binding.load(
      _UnsupportedPlaybackSource(
        uri: Uri.parse('unsupported://example.invalid/video'),
      ),
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

  test('concrete binding discovers and switches media-kit tracks', () async {
    const MediaTrackDescriptor audioTrack = MediaTrackDescriptor(
      id: MediaTrackId('media-kit-audio:1'),
      type: MediaTrackType.audio,
      label: 'Japanese',
      languageCode: 'ja',
      isSelected: true,
    );
    const MediaTrackDescriptor subtitleTrack = MediaTrackDescriptor(
      id: MediaTrackId('media-kit-subtitle:2'),
      type: MediaTrackType.subtitle,
      label: 'Chinese',
      languageCode: 'zh',
    );
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      initialTelemetry: PlayerTelemetrySnapshot(
        tracks: const <MediaTrackDescriptor>[audioTrack, subtitleTrack],
        activeAudioTrackId: audioTrack.id,
      ),
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: backend,
    );

    final TrackDiscoveryResult discovery = await binding.discoverTracks();
    final TrackSwitchResult switchResult = await binding.switchTrack(
      subtitleTrack.id,
    );

    expect(discovery.tracks, const <MediaTrackDescriptor>[
      audioTrack,
      subtitleTrack,
    ]);
    expect(
      discovery.capabilityMatrix
          .supports(PlaybackCapability.audioTrackDiscovery),
      isTrue,
    );
    expect(switchResult.isSuccess, isTrue);
    expect(backend.switchedTrack, subtitleTrack);
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
      plan.commands
          .where((MpvEnhancementCommand command) =>
              command.kind == MpvEnhancementCommandKind.command)
          .map((MpvEnhancementCommand command) => command.arguments),
      <List<String>>[
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementClearOperation,
          mpvEnhancementClearValue,
        ],
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementAppendOperation,
          shader.toString(),
        ],
      ],
    );
  });

  test('enhancement planner clears stale shaders before preset append order',
      () {
    final Uri restore = Uri.parse('mpv-shader://anime4k/restore');
    final Uri upscale = Uri.parse('mpv-shader://anime4k/upscale');
    final MpvEnhancementPlanResult result = MpvEnhancementPlanner(
      anime4kShaderChainsByPreset: <Anime4kPresetIntent, List<Uri>>{
        Anime4kPresetIntent.restoreAndUpscale: <Uri>[restore, upscale],
      },
    ).build(
      _enhancementProfile(
        anime4kPreset: Anime4kPresetIntent.restoreAndUpscale,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.plan!.commands
          .where((MpvEnhancementCommand command) =>
              command.kind == MpvEnhancementCommandKind.command)
          .map((MpvEnhancementCommand command) => command.arguments),
      <List<String>>[
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementClearOperation,
          mpvEnhancementClearValue,
        ],
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementAppendOperation,
          restore.toString(),
        ],
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementAppendOperation,
          upscale.toString(),
        ],
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
      backend.commandCalls,
      <List<String>>[
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementClearOperation,
          mpvEnhancementClearValue,
        ],
        <String>[
          mpvEnhancementChangeListCommand,
          mpvEnhancementGlslShadersOption,
          mpvEnhancementAppendOperation,
          shader.toString(),
        ],
      ],
    );
    expect(backend.shaderList, <String>[shader.toString()]);
  });

  test('enhancement binding replaces stale Anime4K shader chain', () async {
    final Uri restore = Uri.parse('mpv-shader://anime4k/restore');
    final Uri upscale = Uri.parse('mpv-shader://anime4k/upscale');
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: backend,
      anime4kShaderChainsByPreset: <Anime4kPresetIntent, List<Uri>>{
        Anime4kPresetIntent.restore: <Uri>[restore],
        Anime4kPresetIntent.upscale: <Uri>[upscale],
      },
    );

    final EnhancementApplyOutcome restoreResult =
        await binding.applyEnhancement(_enhancementProfile());
    final EnhancementApplyOutcome upscaleResult =
        await binding.applyEnhancement(
      _enhancementProfile(anime4kPreset: Anime4kPresetIntent.upscale),
    );

    expect(restoreResult.isSuccess, isTrue);
    expect(upscaleResult.isSuccess, isTrue);
    expect(backend.shaderList, <String>[upscale.toString()]);
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

  test('adapter facade uses updated binding probe for Anime4K gating',
      () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('elaina-facade-shader-test');
    try {
      final File shader =
          File('${directory.path}${Platform.pathSeparator}restore.glsl');
      await shader.writeAsString('// shader');
      final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend();
      final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);
      final MpvPlayerAdapterFacade adapter = MpvPlayerAdapterFacade.bound(
        binding: binding,
        capabilities: binding.currentCapabilityProbe.capabilities,
      );

      expect(
        adapter.capabilities.supports(PlaybackCapability.anime4kPreset),
        isFalse,
      );
      final EnhancementApplyOutcome rejected =
          await adapter.applyEnhancement(_enhancementProfile());
      expect(rejected.isSuccess, isFalse);
      expect(rejected.failure?.kind,
          EnhancementPipelineFailureKind.capabilityUnsupported);
      expect(backend.commandCalls, isEmpty);

      binding.updateAnime4kShaderChains(
        shaderChainsByPreset: <Anime4kPresetIntent, List<Uri>>{
          Anime4kPresetIntent.restore: <Uri>[shader.uri],
        },
        source: anime4kShaderSourceOverride,
      );

      expect(
        adapter.capabilities.supports(PlaybackCapability.anime4kPreset),
        isTrue,
      );
      final EnhancementApplyOutcome applied =
          await adapter.applyEnhancement(_enhancementProfile());
      expect(applied.isSuccess, isTrue);
      expect(backend.commandCalls.last.last, shader.path);
      expect(backend.shaderList, <String>[shader.path]);
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
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

  test('media-kit capability probe reports native backend operations', () {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(),
    );

    final PlaybackCapabilityProbeSnapshot probe =
        binding.currentCapabilityProbe;
    final PlaybackCapabilityMatrix matrix = probe.capabilities;

    expect(probe.backendLabel, 'fake-media-kit/libmpv');
    expect(matrix.supports(PlaybackCapability.localFilePlayback), isTrue);
    expect(matrix.supports(PlaybackCapability.httpPlayback), isTrue);
    expect(matrix.supports(PlaybackCapability.hlsPlayback), isTrue);
    expect(matrix.supports(PlaybackCapability.playPause), isTrue);
    expect(matrix.supports(PlaybackCapability.seek), isTrue);
    expect(matrix.supports(PlaybackCapability.stop), isTrue);
    expect(matrix.supports(PlaybackCapability.progressReporting), isTrue);
    expect(matrix.supports(PlaybackCapability.audioTrackDiscovery), isTrue);
    expect(matrix.supports(PlaybackCapability.audioTrackSwitching), isTrue);
    expect(matrix.supports(PlaybackCapability.subtitleTrackDiscovery), isTrue);
    expect(matrix.supports(PlaybackCapability.subtitleTrackSwitching), isTrue);
    expect(matrix.supports(PlaybackCapability.videoEnhancement), isTrue);
    expect(matrix.supports(PlaybackCapability.hdrToneMapping), isTrue);
    expect(matrix.supports(PlaybackCapability.debandFiltering), isTrue);
    expect(matrix.supports(PlaybackCapability.dualSubtitles), isTrue);
    expect(matrix.supports(PlaybackCapability.pgsSubtitleRendering), isTrue);
    expect(matrix.supports(PlaybackCapability.assSubtitleEnhancement), isTrue);
    expect(matrix.supports(PlaybackCapability.matrixDanmaku), isFalse);
    expect(matrix.supports(PlaybackCapability.avSyncGuard), isTrue);
    expect(matrix.supports(PlaybackCapability.fallbackAdapter), isFalse);
    expect(probe.details['avSyncSampler'], 'true');
  });

  test(
      'media-kit capability probe rejects native MPV features without native backend',
      () {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(supportsNativeMpvCommands: false),
    );

    final PlaybackCapabilityMatrix matrix =
        binding.currentCapabilityProbe.capabilities;

    expect(matrix.supports(PlaybackCapability.videoEnhancement), isFalse);
    expect(matrix.supports(PlaybackCapability.hdrToneMapping), isFalse);
    expect(matrix.supports(PlaybackCapability.debandFiltering), isFalse);
    expect(matrix.supports(PlaybackCapability.avSyncGuard), isFalse);
    expect(matrix.supports(PlaybackCapability.dualSubtitles), isFalse);
    expect(matrix.supports(PlaybackCapability.pgsSubtitleRendering), isFalse);
    expect(matrix.supports(PlaybackCapability.assSubtitleEnhancement), isFalse);
    expect(
      matrix.statusOf(PlaybackCapability.videoEnhancement).reason,
      mediaKitMpvNativeBackendReason,
    );
  });

  test('AV sync sampling reads MPV drift and drop counter deltas', () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      properties: <String, String>{
        mpvAvSyncProperty: '0.125',
        mpvTimePositionProperty: '10',
        mpvFrameDropCountProperty: '2',
        mpvDecoderFrameDropCountProperty: '3',
        mpvVoDelayedFrameCountProperty: '4',
      },
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final AVSyncSampleReadResult first = await binding.sample();
    backend._properties[mpvAvSyncProperty] = '-0.080';
    backend._properties[mpvTimePositionProperty] = '20';
    backend._properties[mpvFrameDropCountProperty] = '3';
    backend._properties[mpvDecoderFrameDropCountProperty] = '4';
    backend._properties[mpvVoDelayedFrameCountProperty] = '5';
    final AVSyncSampleReadResult second = await binding.sample();

    expect(first.isSuccess, isTrue);
    expect(first.sample!.videoPosition, const Duration(seconds: 10));
    expect(first.sample!.audioPosition,
        const Duration(seconds: 10, milliseconds: 125));
    expect(first.sample!.absoluteDrift, const Duration(milliseconds: 125));
    expect(first.sample!.renderDelay, Duration.zero);
    expect(first.sample!.droppedFrames, 0);
    expect(second.isSuccess, isTrue);
    expect(second.sample!.videoPosition, const Duration(seconds: 20));
    expect(second.sample!.audioPosition,
        const Duration(seconds: 19, milliseconds: 920));
    expect(second.sample!.absoluteDrift, const Duration(milliseconds: 80));
    expect(second.sample!.droppedFrames, 3);
    expect(
      backend.propertyReadCalls,
      <String>[
        mpvAvSyncProperty,
        mpvTimePositionProperty,
        mpvFrameDropCountProperty,
        mpvDecoderFrameDropCountProperty,
        mpvVoDelayedFrameCountProperty,
        mpvAvSyncProperty,
        mpvTimePositionProperty,
        mpvFrameDropCountProperty,
        mpvDecoderFrameDropCountProperty,
        mpvVoDelayedFrameCountProperty,
      ],
    );
  });

  test('AV sync sampling fails when native property reads are unavailable',
      () async {
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      supportsPropertyRead: false,
    );
    final MediaKitMpvBinding binding = MediaKitMpvBinding(backend: backend);

    final PlaybackCapabilityMatrix matrix =
        binding.currentCapabilityProbe.capabilities;
    final AVSyncSampleReadResult result = await binding.sample();

    expect(matrix.supports(PlaybackCapability.avSyncGuard), isFalse);
    expect(
      matrix.statusOf(PlaybackCapability.avSyncGuard).reason,
      mediaKitMpvAvSyncGuardReason,
    );
    expect(result.isSuccess, isFalse);
    expect(result.failure!.kind,
        AVSyncSampleReadFailureKind.propertyReadUnavailable);
  });

  test('media-kit capability probe reflects URI track telemetry failures', () {
    final MediaKitMpvBinding binding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(
        supportsUriPlayback: false,
        supportsTrackDiscovery: false,
        supportsTrackSwitching: false,
        supportsTelemetry: false,
        resolvedLibMpvPath: r'C:\app\libmpv-2.dll',
      ),
    );

    final PlaybackCapabilityProbeSnapshot probe =
        binding.currentCapabilityProbe;
    final PlaybackCapabilityMatrix matrix = probe.capabilities;

    expect(matrix.supports(PlaybackCapability.localFilePlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.hlsPlayback), isFalse);
    expect(matrix.supports(PlaybackCapability.audioTrackDiscovery), isFalse);
    expect(matrix.supports(PlaybackCapability.subtitleTrackSwitching), isFalse);
    expect(matrix.supports(PlaybackCapability.progressReporting), isFalse);
    expect(probe.details['libmpvPath'], r'C:\app\libmpv-2.dll');
  });

  test('Anime4K capability requires an accessible shader file', () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('elaina-shader-test');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final File shader =
        File('${directory.path}${Platform.pathSeparator}a.glsl');
    await shader.writeAsString('// shader');

    final MediaKitMpvBinding missingShaderBinding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(),
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore:
            Uri.file('${directory.path}${Platform.pathSeparator}missing.glsl'),
      },
    );
    final MediaKitMpvBinding existingShaderBinding = MediaKitMpvBinding(
      backend: _FakeMediaKitMpvBackend(),
      anime4kShaderByPreset: <Anime4kPresetIntent, Uri>{
        Anime4kPresetIntent.restore: shader.uri,
      },
    );

    expect(
      missingShaderBinding.currentCapabilityProbe.capabilities
          .supports(PlaybackCapability.anime4kPreset),
      isFalse,
    );
    expect(
      existingShaderBinding.currentCapabilityProbe.capabilities
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
      isTrue,
    );
    expect(
      composition.capabilities.supports(PlaybackCapability.anime4kPreset),
      isFalse,
    );
    expect(composition.capabilityProbeSource, isA<MediaKitMpvBinding>());
  });

  test('composition exposes only verified UI-facing controls', () async {
    const MediaTrackDescriptor audioTrack = MediaTrackDescriptor(
      id: MediaTrackId('media-kit-audio:audio-main'),
      type: MediaTrackType.audio,
      label: 'Main Audio',
    );
    final _FakeMediaKitMpvBackend backend = _FakeMediaKitMpvBackend(
      initialTelemetry: PlayerTelemetrySnapshot(
        tracks: const <MediaTrackDescriptor>[audioTrack],
      ),
    );
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
    expect(surface.hasActiveControl(PlaybackPageControlId.progress), isTrue);
    expect(surface.hasActiveControl(PlaybackPageControlId.audioTracks), isTrue);
    expect(
        surface.hasActiveControl(PlaybackPageControlId.subtitleTracks), isTrue);
    expect(surface.hasActivePanel(PlaybackPagePanelId.tracks), isTrue);

    final PlaybackPageIntentResult panelResult =
        await page.dispatch(const PlaybackPageIntent.openPanel(
      PlaybackPagePanelId.tracks,
    ));
    final PlaybackPageIntentResult trackResult =
        await page.dispatch(PlaybackPageIntent.selectTrack(
      trackId: DomainMediaTrackId(audioTrack.id.value),
      trackType: DomainMediaTrackType.audio,
    ));

    expect(panelResult.outcome, PlaybackPageIntentOutcome.executed);
    expect(trackResult.outcome, PlaybackPageIntentOutcome.executed);
    expect(trackResult.trackSwitchResult?.isSuccess, isTrue);
    expect(backend.switchedTrack, audioTrack);
    expect(
        backend.operations, <PlaybackOperation>[PlaybackOperation.switchTrack]);

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

    expect(hlsResult.isSuccess, isTrue);
    expect(
      backend.operations,
      <PlaybackOperation>[
        PlaybackOperation.load,
        PlaybackOperation.play,
        PlaybackOperation.load,
      ],
    );

    await bootstrap.dispose();
  });
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
}

final class _UnsupportedPlaybackSource extends PlaybackSource {
  const _UnsupportedPlaybackSource({required super.uri});
}

VideoEnhancementProfile _enhancementProfile({
  Anime4kPresetIntent anime4kPreset = Anime4kPresetIntent.restore,
}) {
  return VideoEnhancementProfile(
    id: EnhancementProfileId('anime-vivid'),
    label: 'Anime Vivid',
    scaler: VideoScalerIntent.animeOptimized,
    hdrHandling: HdrHandlingIntent.toneMapToSdr,
    deband: DebandIntent.medium,
    anime4kPreset: anime4kPreset,
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
  _FakeMediaKitMpvBackend({
    this.failOn,
    this.failOnProperty,
    this.supportsUriPlayback = true,
    this.supportsNativeMpvCommands = true,
    bool? supportsPropertyRead,
    this.supportsTrackDiscovery = true,
    this.supportsTrackSwitching = true,
    this.supportsTelemetry = true,
    this.resolvedLibMpvPath,
    Map<String, String> properties = const <String, String>{},
    PlayerTelemetrySnapshot? initialTelemetry,
  })  : supportsPropertyRead =
            supportsPropertyRead ?? supportsNativeMpvCommands,
        _properties = Map<String, String>.of(properties),
        _currentTelemetry = initialTelemetry ?? PlayerTelemetrySnapshot();

  @override
  Player get player =>
      throw UnimplementedError('Fake backend does not implement player getter');

  final PlaybackOperation? failOn;
  final String? failOnProperty;
  @override
  final bool supportsUriPlayback;
  @override
  final bool supportsNativeMpvCommands;
  @override
  final bool supportsPropertyRead;
  @override
  final bool supportsTrackDiscovery;
  @override
  final bool supportsTrackSwitching;
  @override
  final bool supportsTelemetry;
  @override
  final String? resolvedLibMpvPath;
  final StreamController<PlayerTelemetrySnapshot> _telemetryController =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);
  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  final List<_PropertyCall> propertyCalls = <_PropertyCall>[];
  final List<String> propertyReadCalls = <String>[];
  final List<List<String>> commandCalls = <List<String>>[];
  final List<String> shaderList = <String>[];
  final Map<String, String> _properties;
  PlayerTelemetrySnapshot _currentTelemetry;
  Uri? openedUri;
  Duration? seekPosition;
  MediaTrackDescriptor? switchedTrack;

  @override
  PlayerTelemetrySnapshot get currentTelemetry => _currentTelemetry;

  @override
  String get backendLabel => 'fake-media-kit/libmpv';

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => _telemetryController.stream;

  void emitTelemetry(PlayerTelemetrySnapshot snapshot) {
    _currentTelemetry = snapshot;
    _telemetryController.add(snapshot);
  }

  @override
  Future<void> openLocalFile(Uri uri) async {
    _record(PlaybackOperation.load);
    openedUri = uri;
  }

  @override
  Future<void> openUri(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (!supportsUriPlayback) {
      throw StateError('URI playback is unavailable');
    }
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
    if (!supportsNativeMpvCommands) {
      throw StateError('native MPV commands are unavailable');
    }
    propertyCalls.add(_PropertyCall(property, value));
    if (failOnProperty == property) {
      throw StateError('forced $property failure');
    }
  }

  @override
  Future<String> getProperty(String property) async {
    if (!supportsPropertyRead) {
      throw StateError('native MPV property reads are unavailable');
    }
    propertyReadCalls.add(property);
    final String? value = _properties[property];
    if (value == null) {
      throw StateError('missing MPV property $property');
    }
    return value;
  }

  @override
  Future<void> command(List<String> arguments) async {
    if (!supportsNativeMpvCommands) {
      throw StateError('native MPV commands are unavailable');
    }
    commandCalls.add(List<String>.unmodifiable(arguments));
    if (arguments.length >= 4 &&
        arguments[0] == mpvEnhancementChangeListCommand &&
        arguments[1] == mpvEnhancementGlslShadersOption) {
      switch (arguments[2]) {
        case mpvEnhancementClearOperation:
          shaderList.clear();
        case mpvEnhancementAppendOperation:
          shaderList.add(arguments[3]);
      }
    }
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return TrackDiscoveryResult(
      tracks: _currentTelemetry.tracks,
      capabilityMatrix: mediaKitLocalFilePlaybackCapabilities(
        supportsUriPlayback: supportsUriPlayback,
        supportsNativeMpvCommands: supportsNativeMpvCommands,
        supportsAvSyncSampling: supportsPropertyRead,
        supportsTrackApi: supportsTrackDiscovery && supportsTrackSwitching,
        supportsTelemetry: supportsTelemetry,
      ),
    );
  }

  @override
  Future<void> switchTrack(MediaTrackDescriptor track) async {
    switchedTrack = track;
    _record(PlaybackOperation.switchTrack);
  }

  @override
  Future<void> dispose() async {
    _record(PlaybackOperation.dispose);
    await _telemetryController.close();
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
