import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'advanced_caption_rendering.dart';
import 'anime4k_shader_manifest.dart';
import 'av_sync_guard.dart';
import 'av_sync_sample_source.dart';
import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_adapter.dart';
import 'player_runtime_composition.dart';
import 'player_telemetry.dart';
import 'subtitle/subtitle_source.dart';
import 'subtitle_style.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';
import 'virtual_stream_playback_source.dart';

typedef MediaKitMpvBackendFactory = MediaKitMpvBackend Function();

const String windowsLibMpvFileName = 'libmpv-2.dll';
const String elainaLibMpvPathEnvironmentKey = 'CELESTERIA_LIBMPV_PATH';
const String mediaKitMpvProbeSource = 'media-kit-mpv-probe';
const String mediaKitMpvBackendLabel = 'media-kit/libmpv';
const String mediaKitMpvNativeBackendReason =
    'Native MPV command/property access is unavailable.';
const String mediaKitMpvUriPlaybackReason =
    'URI playback is unavailable from the current media-kit backend.';
const String mediaKitMpvTrackApiReason =
    'media-kit track discovery/switching API is unavailable.';
const String mediaKitMpvTelemetryReason =
    'media-kit telemetry streams are unavailable.';
const String mediaKitMpvMatrixDanmakuReason =
    'Matrix danmaku has no implemented renderer backend.';
const String mediaKitMpvAvSyncGuardReason =
    'Native MPV avsync property sampler is unavailable.';
const String mediaKitMpvFallbackReason =
    'No secondary playback backend is wired in this runtime.';
const String mediaKitMpvAnime4kShaderReason =
    'Anime4K requires an accessible MPV shader file.';
const String mpvEnhancementScaleProperty = 'scale';
const String mpvEnhancementChromaScaleProperty = 'cscale';
const String mpvEnhancementToneMappingProperty = 'tone-mapping';
const String mpvEnhancementDebandProperty = 'deband';
const String mpvEnhancementDebandIterationsProperty = 'deband-iterations';
const String mpvEnhancementGlslShadersOption = 'glsl-shaders';
const String mpvEnhancementChangeListCommand = 'change-list';
const String mpvEnhancementAppendOperation = 'append';
const String mpvEnhancementClearOperation = 'clr';
const String mpvEnhancementClearValue = '';
const String mpvEnhancementEnabledValue = 'yes';
const String mpvEnhancementDisabledValue = 'no';
const String mpvEnhancementAutoValue = 'auto';
const String mpvEnhancementSharpScalerValue = 'ewa_lanczossharp';
const String mpvEnhancementSmoothScalerValue = 'spline36';
const String mpvEnhancementToneMapToSdrValue = 'mobius';
const String mpvEnhancementHdrPassthroughValue = 'clip';
const String mpvEnhancementDebandLightIterations = '1';
const String mpvEnhancementDebandMediumIterations = '2';
const String mpvEnhancementDebandStrongIterations = '3';
const String mpvSubtitleAddCommand = 'sub-add';
const String mpvSubtitleRemoveCommand = 'sub-remove';
const String mpvSubtitlePrimaryProperty = 'sid';
const String mpvSubtitleSecondaryProperty = 'secondary-sid';
const String mpvSubtitleAssProperty = 'sub-ass';
const String mpvSubtitleSelectFlag = 'select';
const String mpvSubtitleAutoFlag = 'auto';
const String mpvSubtitleAutoValue = 'auto';
const String mpvSubtitleNoValue = 'no';
const String mpvSubtitleEnabledValue = 'yes';
const String mpvSubtitleDisabledValue = 'no';
const String mpvSubtitleFontProperty = 'sub-font';
const String mpvSubtitleFontSizeProperty = 'sub-font-size';
const String mpvSubtitleColorProperty = 'sub-color';
const String mpvSubtitleBorderColorProperty = 'sub-border-color';
const String mpvSubtitleBorderSizeProperty = 'sub-border-size';
const String mpvSubtitleBackColorProperty = 'sub-back-color';
const String mpvSubtitleBoldProperty = 'sub-bold';
const String mpvSubtitlePositionProperty = 'sub-pos';
const String mpvSubtitleAssOverrideProperty = 'sub-ass-override';
const String mpvSubtitleAssOverrideNoValue = 'no';
const String mpvSubtitleAssOverrideForceValue = 'force';
const String mpvSubtitleBoldEnabledValue = 'yes';
const String mpvSubtitleBoldDisabledValue = 'no';
const String mpvSubtitleTransparentColorValue = '#00000000';
const String mpvAvSyncProperty = 'avsync';
const String mpvTimePositionProperty = 'time-pos';
const String mpvFrameDropCountProperty = 'frame-drop-count';
const String mpvDecoderFrameDropCountProperty = 'decoder-frame-drop-count';
const String mpvVoDelayedFrameCountProperty = 'vo-delayed-frame-count';
const String mediaKitAudioTrackIdPrefix = 'media-kit-audio:';
const String mediaKitSubtitleTrackIdPrefix = 'media-kit-subtitle:';
const String _mediaKitAutoTrackId = 'auto';
const String _mediaKitNoTrackId = 'no';
const String _unknownTrackLabel = 'Unknown track';

abstract interface class MpvAdvancedSubtitleBinding {
  Future<CaptionRenderOutcome> renderMatrixDanmaku(
    MatrixDanmakuRequest request, {
    required AdvancedCaptionProfile profile,
  });

  Future<CaptionRenderOutcome> renderDualSubtitles(
    DualSubtitleRequest request, {
    required AdvancedCaptionProfile profile,
  });

  Future<CaptionRenderOutcome> renderAdvancedSubtitle(
    AdvancedSubtitleRequest request, {
    required AdvancedCaptionProfile profile,
  });

  Future<CaptionDisableOutcome> disableAdvancedSubtitles();
}

enum MpvSubtitleCommandKind {
  setProperty,
  command,
}

final class MpvSubtitleCommand {
  const MpvSubtitleCommand.setProperty({
    required String property,
    required String value,
  })  : kind = MpvSubtitleCommandKind.setProperty,
        property = property,
        value = value,
        arguments = const <String>[];

  MpvSubtitleCommand.command(Iterable<String> arguments)
      : kind = MpvSubtitleCommandKind.command,
        property = null,
        value = null,
        arguments = List<String>.unmodifiable(arguments);

  final MpvSubtitleCommandKind kind;
  final String? property;
  final String? value;
  final List<String> arguments;
}

final class MpvSubtitlePlan {
  MpvSubtitlePlan({
    required this.feature,
    required Iterable<MpvSubtitleCommand> commands,
  }) : commands = List<MpvSubtitleCommand>.unmodifiable(commands);

  final AdvancedCaptionFeature feature;
  final List<MpvSubtitleCommand> commands;

  static MpvSubtitlePlan disabled() {
    return MpvSubtitlePlan(
      feature: AdvancedCaptionFeature.dualSubtitles,
      commands: <MpvSubtitleCommand>[
        const MpvSubtitleCommand.setProperty(
          property: mpvSubtitlePrimaryProperty,
          value: mpvSubtitleNoValue,
        ),
        const MpvSubtitleCommand.setProperty(
          property: mpvSubtitleSecondaryProperty,
          value: mpvSubtitleNoValue,
        ),
        const MpvSubtitleCommand.setProperty(
          property: mpvSubtitleAssProperty,
          value: mpvSubtitleDisabledValue,
        ),
        MpvSubtitleCommand.command(<String>[mpvSubtitleRemoveCommand]),
      ],
    );
  }
}

final class MpvSubtitlePlanner {
  const MpvSubtitlePlanner();

  MpvSubtitlePlan buildDualSubtitles(DualSubtitleRequest request) {
    return MpvSubtitlePlan(
      feature: AdvancedCaptionFeature.dualSubtitles,
      commands: <MpvSubtitleCommand>[
        ..._sourceCommands(
          request.primary,
          property: mpvSubtitlePrimaryProperty,
          externalFlag: mpvSubtitleSelectFlag,
        ),
        ..._sourceCommands(
          request.secondary,
          property: mpvSubtitleSecondaryProperty,
          externalFlag: mpvSubtitleAutoFlag,
        ),
      ],
    );
  }

  MpvSubtitlePlan buildAdvancedSubtitle(AdvancedSubtitleRequest request) {
    final AdvancedCaptionFeature feature = switch (request.intent) {
      AdvancedSubtitleRenderIntent.pgsImageSubtitle =>
        AdvancedCaptionFeature.pgsRendering,
      AdvancedSubtitleRenderIntent.assEnhancedLayout =>
        AdvancedCaptionFeature.assEnhancement,
    };
    return MpvSubtitlePlan(
      feature: feature,
      commands: <MpvSubtitleCommand>[
        if (request.intent == AdvancedSubtitleRenderIntent.assEnhancedLayout)
          const MpvSubtitleCommand.setProperty(
            property: mpvSubtitleAssProperty,
            value: mpvSubtitleEnabledValue,
          ),
        ..._sourceCommands(
          request.source,
          property: mpvSubtitlePrimaryProperty,
          externalFlag: mpvSubtitleSelectFlag,
        ),
      ],
    );
  }

  List<MpvSubtitleCommand> _sourceCommands(
    SubtitleSource source, {
    required String property,
    required String externalFlag,
  }) {
    return switch (source) {
      EmbeddedSubtitleSource(:final trackId) => <MpvSubtitleCommand>[
          MpvSubtitleCommand.setProperty(
            property: property,
            value: trackId,
          ),
        ],
      ExternalSubtitleSource(:final uri, :final title, :final languageCode) =>
        <MpvSubtitleCommand>[
          MpvSubtitleCommand.command(<String>[
            mpvSubtitleAddCommand,
            _subtitlePath(uri),
            externalFlag,
            title ?? source.id,
            if (languageCode != null) languageCode,
          ]),
          MpvSubtitleCommand.setProperty(
            property: property,
            value: mpvSubtitleAutoValue,
          ),
        ],
    };
  }

  static String _subtitlePath(Uri uri) {
    if (uri.scheme == 'file') return uri.toFilePath();
    return uri.toString();
  }
}

final class MpvSubtitleStylePlan {
  MpvSubtitleStylePlan(Iterable<MpvSubtitleCommand> commands)
      : commands = List<MpvSubtitleCommand>.unmodifiable(commands);

  final List<MpvSubtitleCommand> commands;
}

final class MpvSubtitleStylePlanner {
  const MpvSubtitleStylePlanner();

  MpvSubtitleStylePlan build(SubtitleStyleProfile profile) {
    return MpvSubtitleStylePlan(<MpvSubtitleCommand>[
      if (profile.fontFamily.trim().isNotEmpty)
        MpvSubtitleCommand.setProperty(
          property: mpvSubtitleFontProperty,
          value: profile.fontFamily.trim(),
        ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleFontSizeProperty,
        value: _mpvDouble(profile.fontSize),
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleColorProperty,
        value: _mpvColor(
          profile.textColorArgb,
          opacity: profile.textOpacity,
        ),
      ),
      const MpvSubtitleCommand.setProperty(
        property: mpvSubtitleBorderColorProperty,
        value: '#FF000000',
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleBorderSizeProperty,
        value: _mpvDouble(profile.outlineStrength),
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleBackColorProperty,
        value: profile.backgroundEnabled
            ? _mpvColor(0xFF000000, opacity: profile.backgroundOpacity)
            : mpvSubtitleTransparentColorValue,
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleBoldProperty,
        value: _mpvBoldValue(profile.fontWeight),
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitlePositionProperty,
        value: _mpvDouble(_mpvSubtitlePosition(profile.bottomInset)),
      ),
      MpvSubtitleCommand.setProperty(
        property: mpvSubtitleAssOverrideProperty,
        value: profile.forceOverrideEmbeddedStyle
            ? mpvSubtitleAssOverrideForceValue
            : mpvSubtitleAssOverrideNoValue,
      ),
    ]);
  }

  static String _mpvColor(int argb, {required double opacity}) {
    final int alpha = (((argb >> 24) & 0xFF) * opacity.clamp(0, 1)).round();
    final int red = (argb >> 16) & 0xFF;
    final int green = (argb >> 8) & 0xFF;
    final int blue = argb & 0xFF;
    return '#${_hex2(alpha)}${_hex2(red)}${_hex2(green)}${_hex2(blue)}';
  }

  static String _hex2(int value) {
    return value.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  static String _mpvDouble(double value) {
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
  }

  static String _mpvBoldValue(SubtitleStyleFontWeight weight) {
    return switch (weight) {
      SubtitleStyleFontWeight.normal => mpvSubtitleBoldDisabledValue,
      SubtitleStyleFontWeight.medium ||
      SubtitleStyleFontWeight.bold =>
        mpvSubtitleBoldEnabledValue,
    };
  }

  static double _mpvSubtitlePosition(double bottomInset) {
    const double minPosition = 70;
    const double maxPosition = 100;
    const double maxInset = 240;
    return (maxPosition -
            (bottomInset / maxInset * (maxPosition - minPosition)))
        .clamp(minPosition, maxPosition)
        .toDouble();
  }
}

abstract interface class MpvEnhancementBinding {
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile);

  Future<EnhancementDisableOutcome> disableEnhancement();
}

enum MpvEnhancementCommandKind {
  setProperty,
  command,
}

final class MpvEnhancementCommand {
  const MpvEnhancementCommand.setProperty({
    required String property,
    required String value,
  })  : kind = MpvEnhancementCommandKind.setProperty,
        property = property,
        value = value,
        arguments = const <String>[];

  MpvEnhancementCommand.command(Iterable<String> arguments)
      : kind = MpvEnhancementCommandKind.command,
        property = null,
        value = null,
        arguments = List<String>.unmodifiable(arguments);

  final MpvEnhancementCommandKind kind;
  final String? property;
  final String? value;
  final List<String> arguments;
}

final class MpvEnhancementPlan {
  MpvEnhancementPlan(Iterable<MpvEnhancementCommand> commands)
      : commands = List<MpvEnhancementCommand>.unmodifiable(commands);

  final List<MpvEnhancementCommand> commands;

  static MpvEnhancementPlan disabled() {
    return MpvEnhancementPlan(<MpvEnhancementCommand>[
      const MpvEnhancementCommand.setProperty(
        property: mpvEnhancementToneMappingProperty,
        value: mpvEnhancementAutoValue,
      ),
      const MpvEnhancementCommand.setProperty(
        property: mpvEnhancementDebandProperty,
        value: mpvEnhancementDisabledValue,
      ),
      MpvEnhancementCommand.command(<String>[
        mpvEnhancementChangeListCommand,
        mpvEnhancementGlslShadersOption,
        mpvEnhancementClearOperation,
        mpvEnhancementClearValue,
      ]),
    ]);
  }
}

final class MpvEnhancementPlanResult {
  const MpvEnhancementPlanResult._({this.plan, this.failure});

  const MpvEnhancementPlanResult.success({required MpvEnhancementPlan plan})
      : this._(plan: plan);

  const MpvEnhancementPlanResult.failure({
    required EnhancementPipelineFailure failure,
  }) : this._(failure: failure);

  final MpvEnhancementPlan? plan;
  final EnhancementPipelineFailure? failure;

  bool get isSuccess => failure == null;
}

final class MpvEnhancementPlanner {
  MpvEnhancementPlanner({
    Map<Anime4kPresetIntent, Uri> anime4kShaderByPreset =
        const <Anime4kPresetIntent, Uri>{},
    Map<Anime4kPresetIntent, List<Uri>> anime4kShaderChainsByPreset =
        const <Anime4kPresetIntent, List<Uri>>{},
  }) : _anime4kShaderChainsByPreset = _normalizeAnime4kShaderChains(
          shaderByPreset: anime4kShaderByPreset,
          shaderChainsByPreset: anime4kShaderChainsByPreset,
        );

  final Map<Anime4kPresetIntent, List<Uri>> _anime4kShaderChainsByPreset;

  MpvEnhancementPlanResult build(VideoEnhancementProfile profile) {
    final List<MpvEnhancementCommand> commands = <MpvEnhancementCommand>[
      ..._scalerCommands(profile.scaler),
      ..._hdrCommands(profile.hdrHandling),
      ..._debandCommands(profile.deband),
    ];

    final MpvEnhancementPlanResult? shaderResult =
        _appendAnime4kShader(commands, profile.anime4kPreset);
    if (shaderResult != null) return shaderResult;

    return MpvEnhancementPlanResult.success(
      plan: MpvEnhancementPlan(commands),
    );
  }

  bool get supportsAnime4kPresets => _anime4kShaderChainsByPreset.isNotEmpty;

  List<MpvEnhancementCommand> _scalerCommands(VideoScalerIntent scaler) {
    final String? value = switch (scaler) {
      VideoScalerIntent.adapterDefault => null,
      VideoScalerIntent.sharp => mpvEnhancementSharpScalerValue,
      VideoScalerIntent.smooth => mpvEnhancementSmoothScalerValue,
      VideoScalerIntent.animeOptimized => mpvEnhancementSharpScalerValue,
    };
    if (value == null) return const <MpvEnhancementCommand>[];
    return <MpvEnhancementCommand>[
      MpvEnhancementCommand.setProperty(
        property: mpvEnhancementScaleProperty,
        value: value,
      ),
      MpvEnhancementCommand.setProperty(
        property: mpvEnhancementChromaScaleProperty,
        value: value,
      ),
    ];
  }

  List<MpvEnhancementCommand> _hdrCommands(HdrHandlingIntent intent) {
    final String? value = switch (intent) {
      HdrHandlingIntent.adapterDefault => null,
      HdrHandlingIntent.toneMapToSdr => mpvEnhancementToneMapToSdrValue,
      HdrHandlingIntent.passthrough => mpvEnhancementHdrPassthroughValue,
    };
    if (value == null) return const <MpvEnhancementCommand>[];
    return <MpvEnhancementCommand>[
      MpvEnhancementCommand.setProperty(
        property: mpvEnhancementToneMappingProperty,
        value: value,
      ),
    ];
  }

  List<MpvEnhancementCommand> _debandCommands(DebandIntent intent) {
    final String? iterations = switch (intent) {
      DebandIntent.off => null,
      DebandIntent.light => mpvEnhancementDebandLightIterations,
      DebandIntent.medium => mpvEnhancementDebandMediumIterations,
      DebandIntent.strong => mpvEnhancementDebandStrongIterations,
    };
    if (iterations == null) {
      return const <MpvEnhancementCommand>[
        MpvEnhancementCommand.setProperty(
          property: mpvEnhancementDebandProperty,
          value: mpvEnhancementDisabledValue,
        ),
      ];
    }
    return <MpvEnhancementCommand>[
      const MpvEnhancementCommand.setProperty(
        property: mpvEnhancementDebandProperty,
        value: mpvEnhancementEnabledValue,
      ),
      MpvEnhancementCommand.setProperty(
        property: mpvEnhancementDebandIterationsProperty,
        value: iterations,
      ),
    ];
  }

  MpvEnhancementPlanResult? _appendAnime4kShader(
    List<MpvEnhancementCommand> commands,
    Anime4kPresetIntent preset,
  ) {
    if (preset == Anime4kPresetIntent.off) {
      _clearAnime4kShaders(commands);
      return null;
    }

    final List<Uri>? shaders = _anime4kShaderChainsByPreset[preset];
    if (shaders == null || shaders.isEmpty) {
      return const MpvEnhancementPlanResult.failure(
        failure: EnhancementPipelineFailure(
          kind: EnhancementPipelineFailureKind.capabilityUnsupported,
          message: 'Anime4K-style preset requires an explicit MPV shader path.',
        ),
      );
    }

    _clearAnime4kShaders(commands);
    for (final Uri shader in shaders) {
      commands.add(MpvEnhancementCommand.command(<String>[
        mpvEnhancementChangeListCommand,
        mpvEnhancementGlslShadersOption,
        mpvEnhancementAppendOperation,
        _shaderPath(shader),
      ]));
    }
    return null;
  }

  void _clearAnime4kShaders(List<MpvEnhancementCommand> commands) {
    commands.add(MpvEnhancementCommand.command(<String>[
      mpvEnhancementChangeListCommand,
      mpvEnhancementGlslShadersOption,
      mpvEnhancementClearOperation,
      mpvEnhancementClearValue,
    ]));
  }

  static String _shaderPath(Uri shader) {
    if (shader.scheme == 'file') return shader.toFilePath();
    return shader.toString();
  }
}

Map<Anime4kPresetIntent, List<Uri>> _normalizeAnime4kShaderChains({
  required Map<Anime4kPresetIntent, Uri> shaderByPreset,
  required Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset,
}) {
  final Map<Anime4kPresetIntent, List<Uri>> normalized =
      <Anime4kPresetIntent, List<Uri>>{
    for (final MapEntry<Anime4kPresetIntent, Uri> entry
        in shaderByPreset.entries)
      entry.key: <Uri>[entry.value],
  };
  for (final MapEntry<Anime4kPresetIntent, List<Uri>> entry
      in shaderChainsByPreset.entries) {
    normalized[entry.key] = List<Uri>.unmodifiable(entry.value);
  }
  return Map<Anime4kPresetIntent, List<Uri>>.unmodifiable(normalized);
}

abstract interface class MediaKitMpvBackend {
  Player get player;

  String get backendLabel;

  bool get supportsUriPlayback;

  bool get supportsNativeMpvCommands;

  bool get supportsPropertyRead;

  bool get supportsTrackDiscovery;

  bool get supportsTrackSwitching;

  bool get supportsTelemetry;

  String? get resolvedLibMpvPath;

  PlayerTelemetrySnapshot get currentTelemetry;

  Stream<PlayerTelemetrySnapshot> get telemetry;

  Future<void> openLocalFile(Uri uri);

  Future<void> openUri(Uri uri, {Map<String, String> headers});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> setProperty(String property, String value);

  Future<String> getProperty(String property);

  Future<void> command(List<String> arguments);

  Future<TrackDiscoveryResult> discoverTracks();

  Future<void> switchTrack(MediaTrackDescriptor track);

  Future<void> dispose();
}

final class MediaKitMpvBackendAdapter implements MediaKitMpvBackend {
  MediaKitMpvBackendAdapter({
    Player? player,
    String? libmpvPath,
  }) {
    _resolvedLibMpvPath = BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
      explicitLibMpvPath: libmpvPath,
    );
    if (player != null) {
      _player = player;
      return;
    }
    MediaKit.ensureInitialized(
      libmpv: _resolvedLibMpvPath,
    );
    _player = Player();
  }

  late final Player _player;
  late final String? _resolvedLibMpvPath;
  final StreamController<PlayerTelemetrySnapshot> _telemetryController =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _telemetrySubscriptions =
      <StreamSubscription<dynamic>>[];
  String? _lastFailureReason;
  bool _telemetryClosed = false;

  @override
  Player get player => _player;

  @override
  String get backendLabel => mediaKitMpvBackendLabel;

  @override
  bool get supportsUriPlayback => true;

  @override
  bool get supportsNativeMpvCommands => _player.platform is NativePlayer;

  @override
  bool get supportsPropertyRead => _player.platform is NativePlayer;

  @override
  bool get supportsTrackDiscovery => true;

  @override
  bool get supportsTrackSwitching => true;

  @override
  bool get supportsTelemetry => true;

  @override
  String? get resolvedLibMpvPath => _resolvedLibMpvPath;

  @override
  PlayerTelemetrySnapshot get currentTelemetry {
    return _telemetryFromState(_player.state,
        failureReason: _lastFailureReason);
  }

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry {
    _ensureTelemetrySubscriptions();
    return _telemetryController.stream;
  }

  @override
  Future<void> openLocalFile(Uri uri) {
    _lastFailureReason = null;
    return openUri(uri);
  }

  @override
  Future<void> openUri(Uri uri, {Map<String, String> headers = const {}}) {
    _lastFailureReason = null;
    return _player.open(Media(uri.toString(), httpHeaders: headers),
        play: false);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setProperty(String property, String value) async {
    final PlatformPlayer? platform = _player.platform;
    if (platform is! NativePlayer) {
      throw StateError(
          'media_kit platform player does not support setProperty.');
    }
    await platform.setProperty(property, value);
  }

  @override
  Future<String> getProperty(String property) async {
    final PlatformPlayer? platform = _player.platform;
    if (platform is! NativePlayer) {
      throw StateError(
          'media_kit platform player does not support getProperty.');
    }
    return platform.getProperty(property);
  }

  @override
  Future<void> command(List<String> arguments) async {
    final PlatformPlayer? platform = _player.platform;
    if (platform is! NativePlayer) {
      throw StateError('media_kit platform player does not support command.');
    }
    await platform.command(arguments);
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return TrackDiscoveryResult(
      tracks: currentTelemetry.tracks,
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
    switch (track.type) {
      case MediaTrackType.audio:
        await _player.setAudioTrack(_audioTrackForDescriptor(track));
      case MediaTrackType.subtitle:
        await _player.setSubtitleTrack(_subtitleTrackForDescriptor(track));
    }
  }

  @override
  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> subscription
        in _telemetrySubscriptions) {
      await subscription.cancel();
    }
    _telemetrySubscriptions.clear();
    if (!_telemetryClosed) {
      _telemetryClosed = true;
      await _telemetryController.close();
    }
    await _player.dispose();
  }

  void _ensureTelemetrySubscriptions() {
    if (_telemetrySubscriptions.isNotEmpty) return;
    void watch<T>(Stream<T> stream) {
      _telemetrySubscriptions.add(
        stream.listen((_) => _emitTelemetry()),
      );
    }

    watch(_player.stream.playing);
    watch(_player.stream.completed);
    watch(_player.stream.position);
    watch(_player.stream.duration);
    watch(_player.stream.buffering);
    watch(_player.stream.buffer);
    watch(_player.stream.track);
    watch(_player.stream.tracks);
    _telemetrySubscriptions.add(
      _player.stream.error.listen((String error) {
        _lastFailureReason = error;
        _emitTelemetry();
      }),
    );
  }

  void _emitTelemetry() {
    if (_telemetryClosed) return;
    _telemetryController.add(currentTelemetry);
  }

  AudioTrack _audioTrackForDescriptor(MediaTrackDescriptor descriptor) {
    final String rawId = _stripTrackPrefix(
      descriptor.id.value,
      mediaKitAudioTrackIdPrefix,
    );
    for (final AudioTrack track in _player.state.tracks.audio) {
      if (track.id == rawId) return track;
    }
    throw StateError('Audio track is not available: ${descriptor.id.value}');
  }

  SubtitleTrack _subtitleTrackForDescriptor(MediaTrackDescriptor descriptor) {
    final String rawId = _stripTrackPrefix(
      descriptor.id.value,
      mediaKitSubtitleTrackIdPrefix,
    );
    for (final SubtitleTrack track in _player.state.tracks.subtitle) {
      if (track.id == rawId) return track;
    }
    throw StateError('Subtitle track is not available: ${descriptor.id.value}');
  }
}

PlayerTelemetrySnapshot _telemetryFromState(
  PlayerState state, {
  String? failureReason,
}) {
  final List<MediaTrackDescriptor> tracks = <MediaTrackDescriptor>[
    for (final AudioTrack track in state.tracks.audio)
      if (_isUserSelectableTrack(track.id))
        _audioDescriptor(track, selected: state.track.audio),
    for (final SubtitleTrack track in state.tracks.subtitle)
      if (_isUserSelectableTrack(track.id))
        _subtitleDescriptor(track, selected: state.track.subtitle),
  ];
  return PlayerTelemetrySnapshot(
    playing: state.playing,
    completed: state.completed,
    buffering: state.buffering,
    position: state.position,
    duration: state.duration,
    bufferedPosition: state.buffer,
    failureReason: failureReason,
    activeAudioTrackId: _activeAudioTrackId(state.track.audio),
    activeSubtitleTrackId: _activeSubtitleTrackId(state.track.subtitle),
    tracks: tracks,
  );
}

MediaTrackDescriptor _audioDescriptor(
  AudioTrack track, {
  required AudioTrack selected,
}) {
  return MediaTrackDescriptor(
    id: MediaTrackId('$mediaKitAudioTrackIdPrefix${track.id}'),
    type: MediaTrackType.audio,
    label: _trackLabel(track.title, track.language, track.id),
    languageCode: track.language,
    isSelected: track.id == selected.id,
  );
}

MediaTrackDescriptor _subtitleDescriptor(
  SubtitleTrack track, {
  required SubtitleTrack selected,
}) {
  return MediaTrackDescriptor(
    id: MediaTrackId('$mediaKitSubtitleTrackIdPrefix${track.id}'),
    type: MediaTrackType.subtitle,
    label: _trackLabel(track.title, track.language, track.id),
    languageCode: track.language,
    isSelected: track.id == selected.id,
  );
}

MediaTrackId? _activeAudioTrackId(AudioTrack track) {
  if (!_isUserSelectableTrack(track.id)) return null;
  return MediaTrackId('$mediaKitAudioTrackIdPrefix${track.id}');
}

MediaTrackId? _activeSubtitleTrackId(SubtitleTrack track) {
  if (!_isUserSelectableTrack(track.id)) return null;
  return MediaTrackId('$mediaKitSubtitleTrackIdPrefix${track.id}');
}

bool _isUserSelectableTrack(String id) {
  return id != _mediaKitAutoTrackId && id != _mediaKitNoTrackId;
}

String _trackLabel(String? title, String? language, String fallbackId) {
  final String? trimmedTitle = _trimToNull(title);
  if (trimmedTitle != null) return trimmedTitle;
  final String? trimmedLanguage = _trimToNull(language);
  if (trimmedLanguage != null) return trimmedLanguage;
  final String? trimmedFallback = _trimToNull(fallbackId);
  return trimmedFallback ?? _unknownTrackLabel;
}

String? _trimToNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _stripTrackPrefix(String value, String prefix) {
  if (!value.startsWith(prefix)) {
    throw StateError('Track id does not use expected prefix $prefix: $value');
  }
  return value.substring(prefix.length);
}

MediaTrackDescriptor? _trackById(
  Iterable<MediaTrackDescriptor> tracks,
  MediaTrackId id,
) {
  for (final MediaTrackDescriptor track in tracks) {
    if (track.id.value == id.value) return track;
  }
  return null;
}

final class _MpvPropertyParseException implements Exception {
  const _MpvPropertyParseException(this.message);

  final String message;
}

final class MediaKitMpvBinding
    implements
        MpvAdapterBinding,
        PlayerTelemetrySource,
        AVSyncSampleSource,
        PlaybackCapabilityProbeSource,
        MpvEnhancementBinding,
        MpvAdvancedSubtitleBinding {
  MediaKitMpvBinding({
    MediaKitMpvBackend? backend,
    MediaKitMpvBackendFactory? backendFactory,
    String? libmpvPath,
    Map<Anime4kPresetIntent, Uri> anime4kShaderByPreset =
        const <Anime4kPresetIntent, Uri>{},
    Map<Anime4kPresetIntent, List<Uri>> anime4kShaderChainsByPreset =
        const <Anime4kPresetIntent, List<Uri>>{},
    String anime4kShaderSource = anime4kShaderSourceUnavailable,
  })  : assert(
          backend == null || backendFactory == null,
          'Provide either a backend instance or a backend factory, not both.',
        ),
        _backend = backend,
        _backendFactory = backendFactory ??
            (() => MediaKitMpvBackendAdapter(libmpvPath: libmpvPath)),
        _anime4kShaderChainsByPreset = _normalizeAnime4kShaderChains(
          shaderByPreset: anime4kShaderByPreset,
          shaderChainsByPreset: anime4kShaderChainsByPreset,
        ),
        _anime4kShaderSource = anime4kShaderSource,
        _subtitlePlanner = const MpvSubtitlePlanner(),
        _subtitleStylePlanner = const MpvSubtitleStylePlanner();

  MediaKitMpvBackend? _backend;
  final MediaKitMpvBackendFactory _backendFactory;
  Map<Anime4kPresetIntent, List<Uri>> _anime4kShaderChainsByPreset;
  String _anime4kShaderSource;
  final MpvSubtitlePlanner _subtitlePlanner;
  final MpvSubtitleStylePlanner _subtitleStylePlanner;
  int? _previousAvSyncDropCounterTotal;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  MediaKitMpvBackend get backend => _backend ??= _backendFactory();

  void updateAnime4kShaderChains({
    required Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset,
    required String source,
  }) {
    _anime4kShaderChainsByPreset = _normalizeAnime4kShaderChains(
      shaderByPreset: const <Anime4kPresetIntent, Uri>{},
      shaderChainsByPreset: shaderChainsByPreset,
    );
    _anime4kShaderSource = source;
  }

  @override
  PlayerTelemetrySnapshot get currentTelemetry => backend.currentTelemetry;

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => backend.telemetry;

  @override
  Future<AVSyncSampleReadResult> sample() async {
    if (_disposed) {
      return const AVSyncSampleReadResult.failure(
        AVSyncSampleReadFailure(
          kind: AVSyncSampleReadFailureKind.disposed,
          message: 'MediaKit MPV binding has been disposed.',
        ),
      );
    }
    final MediaKitMpvBackend currentBackend = backend;
    if (!currentBackend.supportsPropertyRead) {
      return const AVSyncSampleReadResult.failure(
        AVSyncSampleReadFailure(
          kind: AVSyncSampleReadFailureKind.propertyReadUnavailable,
          message: mediaKitMpvAvSyncGuardReason,
        ),
      );
    }

    try {
      final double driftSeconds = _parseMpvSeconds(
        property: mpvAvSyncProperty,
        value: await currentBackend.getProperty(mpvAvSyncProperty),
      );
      final double videoSeconds = _parseMpvSeconds(
        property: mpvTimePositionProperty,
        value: await currentBackend.getProperty(mpvTimePositionProperty),
      );
      final int droppedFrames = _droppedFrameDelta(
        _parseMpvCounter(
              property: mpvFrameDropCountProperty,
              value: await currentBackend.getProperty(
                mpvFrameDropCountProperty,
              ),
            ) +
            _parseMpvCounter(
              property: mpvDecoderFrameDropCountProperty,
              value: await currentBackend.getProperty(
                mpvDecoderFrameDropCountProperty,
              ),
            ) +
            _parseMpvCounter(
              property: mpvVoDelayedFrameCountProperty,
              value: await currentBackend.getProperty(
                mpvVoDelayedFrameCountProperty,
              ),
            ),
      );
      final Duration videoPosition = _durationFromSeconds(videoSeconds);
      final Duration drift = _durationFromSeconds(driftSeconds);
      return AVSyncSampleReadResult.success(
        AVSyncSample(
          audioPosition: videoPosition + drift,
          videoPosition: videoPosition,
          renderDelay: Duration.zero,
          droppedFrames: droppedFrames,
        ),
      );
    } on _MpvPropertyParseException catch (error) {
      return AVSyncSampleReadResult.failure(
        AVSyncSampleReadFailure(
          kind: AVSyncSampleReadFailureKind.invalidPropertyValue,
          message: error.message,
        ),
      );
    } on Object catch (error) {
      return AVSyncSampleReadResult.failure(
        AVSyncSampleReadFailure(
          kind: AVSyncSampleReadFailureKind.backendFailure,
          message: 'Failed to read MPV AV sync properties: $error',
        ),
      );
    }
  }

  double _parseMpvSeconds({
    required String property,
    required String value,
  }) {
    final String normalized = value.trim();
    final double? parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) {
      throw _MpvPropertyParseException(
        'MPV property $property is not a finite seconds value: $value',
      );
    }
    return parsed;
  }

  int _parseMpvCounter({
    required String property,
    required String value,
  }) {
    final String normalized = value.trim();
    final double? parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw _MpvPropertyParseException(
        'MPV property $property is not a non-negative counter: $value',
      );
    }
    return parsed.round();
  }

  Duration _durationFromSeconds(double seconds) {
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  int _droppedFrameDelta(int currentTotal) {
    final int? previousTotal = _previousAvSyncDropCounterTotal;
    _previousAvSyncDropCounterTotal = currentTotal;
    if (previousTotal == null || currentTotal <= previousTotal) {
      return 0;
    }
    return currentTotal - previousTotal;
  }

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    final DateTime checkedAt = DateTime.now();
    if (_disposed) {
      return PlaybackCapabilityProbeSnapshot(
        capabilities: PlaybackCapabilityMatrix.unsupported(
          reason: 'MediaKit MPV binding has been disposed.',
        ),
        checkedAt: checkedAt,
        source: mediaKitMpvProbeSource,
        backendLabel: mediaKitMpvBackendLabel,
        details: const <String, String>{'binding': 'disposed'},
      );
    }

    try {
      final MediaKitMpvBackend currentBackend = backend;
      final bool trackApi = currentBackend.supportsTrackDiscovery &&
          currentBackend.supportsTrackSwitching;
      final bool avSyncSampler = currentBackend.supportsPropertyRead;
      final bool anime4kShadersAvailable = _allAnime4kShadersAreAccessible(
        _anime4kShaderChainsByPreset.values.expand((List<Uri> chain) => chain),
      );
      return PlaybackCapabilityProbeSnapshot(
        capabilities: mediaKitLocalFilePlaybackCapabilities(
          supportsUriPlayback: currentBackend.supportsUriPlayback,
          supportsNativeMpvCommands: currentBackend.supportsNativeMpvCommands,
          supportsAvSyncSampling: avSyncSampler,
          supportsTrackApi: trackApi,
          supportsTelemetry: currentBackend.supportsTelemetry,
          anime4kShadersAvailable: anime4kShadersAvailable,
        ),
        checkedAt: checkedAt,
        source: mediaKitMpvProbeSource,
        backendLabel: currentBackend.backendLabel,
        details: <String, String>{
          'backend': currentBackend.backendLabel,
          'uriPlayback': currentBackend.supportsUriPlayback.toString(),
          'nativeMpvCommands':
              currentBackend.supportsNativeMpvCommands.toString(),
          'avSyncSampler': avSyncSampler.toString(),
          'trackApi': trackApi.toString(),
          'telemetry': currentBackend.supportsTelemetry.toString(),
          'anime4kShadersAccessible': anime4kShadersAvailable.toString(),
          'anime4kShaderSource': _anime4kShaderSource,
          'anime4kShaderMap':
              _anime4kShaderMapSummary(_anime4kShaderChainsByPreset),
          'libmpvPath': currentBackend.resolvedLibMpvPath ?? 'default',
        },
      );
    } on Object catch (error) {
      return PlaybackCapabilityProbeSnapshot(
        capabilities: PlaybackCapabilityMatrix.unsupported(
          reason: 'MediaKit MPV backend probe failed: $error',
        ),
        checkedAt: checkedAt,
        source: mediaKitMpvProbeSource,
        backendLabel: mediaKitMpvBackendLabel,
        details: <String, String>{'probeFailure': error.toString()},
      );
    }
  }

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.load);
    if (disposed != null) return disposed;
    if (source is! LocalFilePlaybackSource &&
        source is! HttpPlaybackSource &&
        source is! HlsPlaybackSource &&
        source is! VirtualStreamPlaybackSource) {
      return _failure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.unsupported,
        message:
            'MediaKit MPV binding supports local, HTTP, HLS, and virtual stream playback only.',
      );
    }

    return _runBackendCommand(
      PlaybackOperation.load,
      (MediaKitMpvBackend backend) =>
          backend.openUri(source.uri, headers: source.headers),
    );
  }

  @override
  Future<PlaybackCommandResult> play() {
    return _recordCommand(
        PlaybackOperation.play, (MediaKitMpvBackend backend) => backend.play());
  }

  @override
  Future<PlaybackCommandResult> pause() {
    return _recordCommand(PlaybackOperation.pause,
        (MediaKitMpvBackend backend) => backend.pause());
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.seek);
    if (disposed != null) return disposed;
    return _runBackendCommand(
      PlaybackOperation.seek,
      (MediaKitMpvBackend backend) => backend.seek(position),
    );
  }

  @override
  Future<PlaybackCommandResult> stop() {
    return _recordCommand(
        PlaybackOperation.stop, (MediaKitMpvBackend backend) => backend.stop());
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    if (_disposed) return _disposedFailure(PlaybackOperation.dispose);
    final MediaKitMpvBackend? backend = _backend;
    if (backend != null) {
      final PlaybackCommandResult result = await _runBackendCommand(
        PlaybackOperation.dispose,
        (MediaKitMpvBackend backend) => backend.dispose(),
      );
      if (!result.isSuccess) return result;
    }
    _disposed = true;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    if (_disposed) {
      return TrackDiscoveryResult.unsupported(
        reason: 'MediaKit MPV binding has been disposed.',
      );
    }
    try {
      return await backend.discoverTracks();
    } on Object catch (error) {
      return TrackDiscoveryResult.unsupported(
        reason: 'Track discovery failed: $error',
      );
    }
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    if (_disposed) {
      return const TrackSwitchResult.unsupported(
        'MediaKit MPV binding has been disposed.',
      );
    }
    final MediaTrackDescriptor? track = _trackById(
      backend.currentTelemetry.tracks,
      trackId,
    );
    if (track == null) {
      return TrackSwitchResult.unsupported(
        'Track is not available: ${trackId.value}',
      );
    }
    try {
      await backend.switchTrack(track);
      return const TrackSwitchResult.success();
    } on Object catch (error) {
      return TrackSwitchResult.unsupported('Track switch failed: $error');
    }
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile) async {
    final EnhancementPipelineFailure? disposed = _rejectEnhancementIfDisposed();
    if (disposed != null) {
      return EnhancementApplyOutcome.rejected(failure: disposed);
    }

    final MpvEnhancementPlanResult planResult = MpvEnhancementPlanner(
      anime4kShaderChainsByPreset: _anime4kShaderChainsByPreset,
    ).build(profile);
    if (!planResult.isSuccess) {
      return EnhancementApplyOutcome.rejected(failure: planResult.failure!);
    }

    final EnhancementPipelineFailure? failure =
        await _runEnhancementPlan(planResult.plan!);
    if (failure != null) {
      return EnhancementApplyOutcome.rejected(failure: failure);
    }
    return EnhancementApplyOutcome.applied(profile: profile);
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() async {
    final EnhancementPipelineFailure? disposed = _rejectEnhancementIfDisposed();
    if (disposed != null) {
      return EnhancementDisableOutcome.rejected(failure: disposed);
    }

    final EnhancementPipelineFailure? failure =
        await _runEnhancementPlan(MpvEnhancementPlan.disabled());
    if (failure != null) {
      return EnhancementDisableOutcome.rejected(failure: failure);
    }
    return const EnhancementDisableOutcome.disabled();
  }

  @override
  Future<PlaybackCommandResult> applySubtitleStyle(
    SubtitleStyleProfile profile,
  ) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.applySubtitleStyle);
    if (disposed != null) return disposed;

    final CapabilityStatus subtitleStyling =
        currentCapabilityProbe.capabilities.statusOf(
      PlaybackCapability.assSubtitleEnhancement,
    );
    if (!subtitleStyling.isSupported) {
      return _failure(
        operation: PlaybackOperation.applySubtitleStyle,
        kind: PlaybackFailureKind.unsupported,
        message:
            subtitleStyling.reason ?? 'MPV subtitle styling is unsupported.',
      );
    }

    try {
      final MediaKitMpvBackend backend = _backend ??= _backendFactory();
      final MpvSubtitleStylePlan plan = _subtitleStylePlanner.build(profile);
      for (final MpvSubtitleCommand command in plan.commands) {
        await backend.setProperty(command.property!, command.value!);
      }
      return const PlaybackCommandResult.success();
    } on Object catch (error) {
      return _failure(
        operation: PlaybackOperation.applySubtitleStyle,
        kind: PlaybackFailureKind.operationFailed,
        message: 'Concrete MPV subtitle style operation failed: $error',
      );
    }
  }

  @override
  Future<CaptionRenderOutcome> renderMatrixDanmaku(
    MatrixDanmakuRequest request, {
    required AdvancedCaptionProfile profile,
  }) async {
    return const CaptionRenderOutcome.rejected(
      failure: AdvancedCaptionFailure(
        kind: AdvancedCaptionFailureKind.capabilityUnsupported,
        message:
            'MediaKit MPV binding does not implement Matrix4 danmaku rendering.',
      ),
    );
  }

  @override
  Future<CaptionRenderOutcome> renderDualSubtitles(
    DualSubtitleRequest request, {
    required AdvancedCaptionProfile profile,
  }) async {
    if (request.primary.id == request.secondary.id) {
      return const CaptionRenderOutcome.rejected(
        failure: AdvancedCaptionFailure(
          kind: AdvancedCaptionFailureKind.dualSubtitleOrderRejected,
          message: 'Primary and secondary subtitles must be distinct.',
        ),
      );
    }
    return _applySubtitlePlan(
      _subtitlePlanner.buildDualSubtitles(request),
      profile: profile,
    );
  }

  @override
  Future<CaptionRenderOutcome> renderAdvancedSubtitle(
    AdvancedSubtitleRequest request, {
    required AdvancedCaptionProfile profile,
  }) async {
    return _applySubtitlePlan(
      _subtitlePlanner.buildAdvancedSubtitle(request),
      profile: profile,
    );
  }

  @override
  Future<CaptionDisableOutcome> disableAdvancedSubtitles() async {
    final AdvancedCaptionFailure? disposed = _rejectCaptionIfDisposed();
    if (disposed != null) {
      return CaptionDisableOutcome.rejected(failure: disposed);
    }

    final AdvancedCaptionFailure? failure =
        await _runSubtitlePlan(MpvSubtitlePlan.disabled());
    if (failure != null) {
      return CaptionDisableOutcome.rejected(failure: failure);
    }
    return const CaptionDisableOutcome.disabled();
  }

  Future<PlaybackCommandResult> _recordCommand(
    PlaybackOperation operation,
    Future<void> Function(MediaKitMpvBackend backend) command,
  ) async {
    final PlaybackCommandResult? disposed = _rejectIfDisposed(operation);
    if (disposed != null) return disposed;
    return _runBackendCommand(operation, command);
  }

  Future<PlaybackCommandResult> _runBackendCommand(
    PlaybackOperation operation,
    Future<void> Function(MediaKitMpvBackend backend) command,
  ) async {
    try {
      final MediaKitMpvBackend backend = _backend ??= _backendFactory();
      await command(backend);
      return const PlaybackCommandResult.success();
    } catch (error) {
      return _failure(
        operation: operation,
        kind: PlaybackFailureKind.operationFailed,
        message: 'Concrete MPV operation failed: $error',
      );
    }
  }

  Future<EnhancementPipelineFailure?> _runEnhancementPlan(
      MpvEnhancementPlan plan) async {
    try {
      final MediaKitMpvBackend backend = _backend ??= _backendFactory();
      for (final MpvEnhancementCommand command in plan.commands) {
        switch (command.kind) {
          case MpvEnhancementCommandKind.setProperty:
            await backend.setProperty(command.property!, command.value!);
          case MpvEnhancementCommandKind.command:
            await backend.command(command.arguments);
        }
      }
      return null;
    } catch (error) {
      return EnhancementPipelineFailure(
        kind: EnhancementPipelineFailureKind.adapterRejected,
        message: 'Concrete MPV enhancement operation failed: $error',
      );
    }
  }

  EnhancementPipelineFailure? _rejectEnhancementIfDisposed() {
    if (!_disposed) return null;
    return const EnhancementPipelineFailure(
      kind: EnhancementPipelineFailureKind.adapterRejected,
      message: 'MediaKit MPV binding has been disposed.',
    );
  }

  Future<CaptionRenderOutcome> _applySubtitlePlan(
    MpvSubtitlePlan plan, {
    required AdvancedCaptionProfile profile,
  }) async {
    final AdvancedCaptionFailure? disposed = _rejectCaptionIfDisposed();
    if (disposed != null) {
      return CaptionRenderOutcome.rejected(failure: disposed);
    }

    final AdvancedCaptionFailure? failure = await _runSubtitlePlan(plan);
    if (failure != null) {
      return CaptionRenderOutcome.rejected(failure: failure);
    }
    return CaptionRenderOutcome.rendered(
      profile: profile,
      feature: plan.feature,
    );
  }

  Future<AdvancedCaptionFailure?> _runSubtitlePlan(MpvSubtitlePlan plan) async {
    try {
      final MediaKitMpvBackend backend = _backend ??= _backendFactory();
      for (final MpvSubtitleCommand command in plan.commands) {
        switch (command.kind) {
          case MpvSubtitleCommandKind.setProperty:
            await backend.setProperty(command.property!, command.value!);
          case MpvSubtitleCommandKind.command:
            await backend.command(command.arguments);
        }
      }
      return null;
    } catch (error) {
      return AdvancedCaptionFailure(
        kind: AdvancedCaptionFailureKind.adapterRejected,
        message: 'Concrete MPV subtitle operation failed: $error',
      );
    }
  }

  AdvancedCaptionFailure? _rejectCaptionIfDisposed() {
    if (!_disposed) return null;
    return const AdvancedCaptionFailure(
      kind: AdvancedCaptionFailureKind.adapterRejected,
      message: 'MediaKit MPV binding has been disposed.',
    );
  }

  PlaybackCommandResult? _rejectIfDisposed(PlaybackOperation operation) {
    if (!_disposed) return null;
    return _disposedFailure(operation);
  }

  PlaybackCommandResult _disposedFailure(PlaybackOperation operation) {
    return _failure(
      operation: operation,
      kind: PlaybackFailureKind.disposed,
      message: 'MediaKit MPV binding has been disposed.',
    );
  }

  PlaybackCommandResult _failure({
    required PlaybackOperation operation,
    required PlaybackFailureKind kind,
    required String message,
  }) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: kind,
        message: message,
      ),
    );
  }
}

final class BundledMpvLibraryResolver {
  const BundledMpvLibraryResolver._();

  static String? resolveWindowsLibMpvPath({
    String? explicitLibMpvPath,
    Map<String, String>? environment,
    String? executablePath,
    bool? isWindows,
    bool Function(String path)? fileExists,
    bool Function(String path)? directoryExists,
  }) {
    final bool runsOnWindows = isWindows ?? Platform.isWindows;
    if (!runsOnWindows) return null;

    final bool Function(String path) doesFileExist =
        fileExists ?? (String path) => File(path).existsSync();
    final bool Function(String path) doesDirectoryExist =
        directoryExists ?? (String path) => Directory(path).existsSync();

    final String? explicit = _resolveCandidate(
      explicitLibMpvPath,
      fileExists: doesFileExist,
      directoryExists: doesDirectoryExist,
    );
    if (explicit != null) return explicit;

    final Map<String, String> env = environment ?? Platform.environment;
    final String? envCandidate = _resolveCandidate(
      env[elainaLibMpvPathEnvironmentKey],
      fileExists: doesFileExist,
      directoryExists: doesDirectoryExist,
    );
    if (envCandidate != null) return envCandidate;

    final String resolvedExecutable =
        executablePath ?? Platform.resolvedExecutable;
    final String executableDirectory = _parentPath(resolvedExecutable);
    if (executableDirectory.isEmpty) return null;

    final String bundledCandidate = _joinPath(
      executableDirectory,
      windowsLibMpvFileName,
    );
    if (doesFileExist(bundledCandidate)) return bundledCandidate;

    return null;
  }

  static String? _resolveCandidate(
    String? candidate, {
    required bool Function(String path) fileExists,
    required bool Function(String path) directoryExists,
  }) {
    final String? normalized = _normalizeCandidate(candidate);
    if (normalized == null) return null;
    if (fileExists(normalized)) return normalized;
    if (directoryExists(normalized)) {
      final String dllPath = _joinPath(normalized, windowsLibMpvFileName);
      if (fileExists(dllPath)) return dllPath;
    }
    return null;
  }

  static String? _normalizeCandidate(String? candidate) {
    final String? trimmed = candidate?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _parentPath(String path) {
    final int slash = path.lastIndexOf('/');
    final int backslash = path.lastIndexOf('\\');
    final int index = slash > backslash ? slash : backslash;
    if (index <= 0) return '';
    return path.substring(0, index);
  }

  static String _joinPath(String directory, String fileName) {
    if (directory.endsWith('/') || directory.endsWith('\\')) {
      return '$directory$fileName';
    }
    final String separator = directory.contains('\\') ? '\\' : '/';
    return '$directory$separator$fileName';
  }
}

PlaybackCapabilityMatrix mediaKitLocalFilePlaybackCapabilities({
  bool supportsUriPlayback = true,
  bool supportsNativeMpvCommands = true,
  bool supportsAvSyncSampling = false,
  bool supportsTrackApi = true,
  bool supportsTelemetry = true,
  bool anime4kShadersAvailable = false,
}) {
  final CapabilityStatus uriPlayback = supportsUriPlayback
      ? const CapabilityStatus.supported()
      : const CapabilityStatus.unsupported(mediaKitMpvUriPlaybackReason);
  final CapabilityStatus nativeCommands = supportsNativeMpvCommands
      ? const CapabilityStatus.supported()
      : const CapabilityStatus.unsupported(mediaKitMpvNativeBackendReason);
  final CapabilityStatus trackApi = supportsTrackApi
      ? const CapabilityStatus.supported()
      : const CapabilityStatus.unsupported(mediaKitMpvTrackApiReason);
  final CapabilityStatus telemetry = supportsTelemetry
      ? const CapabilityStatus.supported()
      : const CapabilityStatus.unsupported(mediaKitMpvTelemetryReason);
  final CapabilityStatus anime4k =
      supportsNativeMpvCommands && anime4kShadersAvailable
          ? const CapabilityStatus.supported()
          : CapabilityStatus.unsupported(
              supportsNativeMpvCommands
                  ? mediaKitMpvAnime4kShaderReason
                  : mediaKitMpvNativeBackendReason,
            );
  final CapabilityStatus avSyncGuard = supportsNativeMpvCommands
      ? (supportsAvSyncSampling
          ? const CapabilityStatus.supported()
          : const CapabilityStatus.unsupported(mediaKitMpvAvSyncGuardReason))
      : const CapabilityStatus.unsupported(mediaKitMpvNativeBackendReason);
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: uriPlayback,
      PlaybackCapability.httpPlayback: uriPlayback,
      PlaybackCapability.hlsPlayback: uriPlayback,
      PlaybackCapability.playPause: uriPlayback,
      PlaybackCapability.seek: uriPlayback,
      PlaybackCapability.stop: uriPlayback,
      PlaybackCapability.progressReporting: telemetry,
      PlaybackCapability.audioTrackDiscovery: trackApi,
      PlaybackCapability.audioTrackSwitching: trackApi,
      PlaybackCapability.subtitleTrackDiscovery: trackApi,
      PlaybackCapability.subtitleTrackSwitching: trackApi,
      PlaybackCapability.danmakuRendering: const CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: const CapabilityStatus.supported(),
      PlaybackCapability.videoEnhancement: nativeCommands,
      PlaybackCapability.hdrToneMapping: nativeCommands,
      PlaybackCapability.debandFiltering: nativeCommands,
      PlaybackCapability.anime4kPreset: anime4k,
      PlaybackCapability.avSyncGuard: avSyncGuard,
      PlaybackCapability.matrixDanmaku:
          const CapabilityStatus.unsupported(mediaKitMpvMatrixDanmakuReason),
      PlaybackCapability.dualSubtitles: nativeCommands,
      PlaybackCapability.pgsSubtitleRendering: nativeCommands,
      PlaybackCapability.assSubtitleEnhancement: nativeCommands,
      PlaybackCapability.fallbackAdapter:
          const CapabilityStatus.unsupported(mediaKitMpvFallbackReason),
    },
  );
}

bool _allAnime4kShadersAreAccessible(Iterable<Uri> shaders) {
  final List<Uri> shaderList = List<Uri>.of(shaders);
  if (shaderList.isEmpty) return false;
  for (final Uri shader in shaderList) {
    if (shader.scheme != 'file') return false;
    if (!File(shader.toFilePath()).existsSync()) return false;
  }
  return true;
}

String _anime4kShaderMapSummary(
  Map<Anime4kPresetIntent, List<Uri>> shaderChainsByPreset,
) {
  if (shaderChainsByPreset.isEmpty) return '';
  return shaderChainsByPreset.entries
      .map((MapEntry<Anime4kPresetIntent, List<Uri>> entry) {
    final String chain = entry.value.map(_shaderSummarySegment).join(' + ');
    return '${entry.key.name}=$chain';
  }).join('; ');
}

String _shaderSummarySegment(Uri uri) {
  if (uri.scheme == 'file') {
    final String path = uri.toFilePath();
    final int slash = path.lastIndexOf('/');
    final int backslash = path.lastIndexOf('\\');
    final int index = slash > backslash ? slash : backslash;
    if (index >= 0 && index < path.length - 1) {
      return path.substring(index + 1);
    }
    return path;
  }
  return uri.toString();
}

/// Creates the concrete Playback-side inputs needed by app composition roots.
///
/// UI/app-shell code should pass the returned descriptor into
/// `PlayerCoreBootstrap.withComposition(...)` or into equivalent application
/// composition code. The optional [libmpvPath] may point to `libmpv-2.dll` or
/// a directory containing it for smoke tests and packaged release checks.
PlayerRuntimeCompositionContract mediaKitLocalFilePlayerRuntimeComposition({
  String? libmpvPath,
  MediaKitMpvBackend? backend,
  MediaKitMpvBackendFactory? backendFactory,
  Map<Anime4kPresetIntent, Uri> anime4kShaderByPreset =
      const <Anime4kPresetIntent, Uri>{},
  Map<Anime4kPresetIntent, List<Uri>> anime4kShaderChainsByPreset =
      const <Anime4kPresetIntent, List<Uri>>{},
  String anime4kShaderSource = anime4kShaderSourceUnavailable,
}) {
  final MediaKitMpvBinding binding = MediaKitMpvBinding(
    backend: backend,
    backendFactory: backendFactory,
    libmpvPath: libmpvPath,
    anime4kShaderByPreset: anime4kShaderByPreset,
    anime4kShaderChainsByPreset: anime4kShaderChainsByPreset,
    anime4kShaderSource: anime4kShaderSource,
  );
  return PlayerRuntimeCompositionContract(
    adapter: MpvPlayerAdapterFacade.bound(
      binding: binding,
      capabilities: binding.currentCapabilityProbe.capabilities,
    ),
    capabilities: binding.currentCapabilityProbe.capabilities,
    binding: binding,
    telemetrySource: binding,
    capabilityProbeSource: binding,
    avSyncSampleSource: binding,
  );
}
