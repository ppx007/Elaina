import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'advanced_caption_rendering.dart';
import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_adapter.dart';
import 'player_runtime_composition.dart';
import 'subtitle/subtitle_source.dart';
import 'track_management.dart';
import 'video_enhancement_pipeline.dart';

typedef MediaKitMpvBackendFactory = MediaKitMpvBackend Function();

const String windowsLibMpvFileName = 'libmpv-2.dll';
const String celesteriaLibMpvPathEnvironmentKey = 'CELESTERIA_LIBMPV_PATH';
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
  }) : _anime4kShaderByPreset =
            Map<Anime4kPresetIntent, Uri>.unmodifiable(anime4kShaderByPreset);

  final Map<Anime4kPresetIntent, Uri> _anime4kShaderByPreset;

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

  bool get supportsAnime4kPresets => _anime4kShaderByPreset.isNotEmpty;

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
    if (preset == Anime4kPresetIntent.off) return null;

    final Uri? shader = _anime4kShaderByPreset[preset];
    if (shader == null) {
      return const MpvEnhancementPlanResult.failure(
        failure: EnhancementPipelineFailure(
          kind: EnhancementPipelineFailureKind.capabilityUnsupported,
          message: 'Anime4K-style preset requires an explicit MPV shader path.',
        ),
      );
    }

    commands.add(MpvEnhancementCommand.command(<String>[
      mpvEnhancementChangeListCommand,
      mpvEnhancementGlslShadersOption,
      mpvEnhancementAppendOperation,
      _shaderPath(shader),
    ]));
    return null;
  }

  static String _shaderPath(Uri shader) {
    if (shader.scheme == 'file') return shader.toFilePath();
    return shader.toString();
  }
}

abstract interface class MediaKitMpvBackend {
  Future<void> openLocalFile(Uri uri);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> setProperty(String property, String value);

  Future<void> command(List<String> arguments);

  Future<void> dispose();
}

final class MediaKitMpvBackendAdapter implements MediaKitMpvBackend {
  MediaKitMpvBackendAdapter({
    Player? player,
    String? libmpvPath,
  }) {
    if (player != null) {
      _player = player;
      return;
    }
    MediaKit.ensureInitialized(
      libmpv: BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        explicitLibMpvPath: libmpvPath,
      ),
    );
    _player = Player();
  }

  late final Player _player;

  @override
  Future<void> openLocalFile(Uri uri) {
    return _player.open(Media(uri.toString()), play: false);
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
    await (_player.platform as dynamic).setProperty(property, value);
  }

  @override
  Future<void> command(List<String> arguments) async {
    await (_player.platform as dynamic).command(arguments);
  }

  @override
  Future<void> dispose() => _player.dispose();
}

final class MediaKitMpvBinding
    implements
        MpvAdapterBinding,
        MpvEnhancementBinding,
        MpvAdvancedSubtitleBinding {
  MediaKitMpvBinding({
    MediaKitMpvBackend? backend,
    MediaKitMpvBackendFactory? backendFactory,
    String? libmpvPath,
    Map<Anime4kPresetIntent, Uri> anime4kShaderByPreset =
        const <Anime4kPresetIntent, Uri>{},
  })  : assert(
          backend == null || backendFactory == null,
          'Provide either a backend instance or a backend factory, not both.',
        ),
        _backend = backend,
        _backendFactory = backendFactory ??
            (() => MediaKitMpvBackendAdapter(libmpvPath: libmpvPath)),
        _enhancementPlanner = MpvEnhancementPlanner(
          anime4kShaderByPreset: anime4kShaderByPreset,
        ),
        _subtitlePlanner = const MpvSubtitlePlanner();

  MediaKitMpvBackend? _backend;
  final MediaKitMpvBackendFactory _backendFactory;
  final MpvEnhancementPlanner _enhancementPlanner;
  final MpvSubtitlePlanner _subtitlePlanner;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.load);
    if (disposed != null) return disposed;
    if (source is! LocalFilePlaybackSource) {
      return _failure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.unsupported,
        message: 'MediaKit MPV binding supports local file playback only.',
      );
    }

    return _runBackendCommand(
      PlaybackOperation.load,
      (MediaKitMpvBackend backend) => backend.openLocalFile(source.uri),
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
    return TrackDiscoveryResult.unsupported(
      reason: 'Track discovery is not implemented by the concrete MPV binding.',
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    return const TrackSwitchResult.unsupported(
      'Track switching is not implemented by the concrete MPV binding.',
    );
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
      VideoEnhancementProfile profile) async {
    final EnhancementPipelineFailure? disposed = _rejectEnhancementIfDisposed();
    if (disposed != null) {
      return EnhancementApplyOutcome.rejected(failure: disposed);
    }

    final MpvEnhancementPlanResult planResult =
        _enhancementPlanner.build(profile);
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
      env[celesteriaLibMpvPathEnvironmentKey],
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
  bool anime4kShadersAvailable = false,
}) {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
      PlaybackCapability.videoEnhancement: CapabilityStatus.supported(),
      PlaybackCapability.hdrToneMapping: CapabilityStatus.supported(),
      PlaybackCapability.debandFiltering: CapabilityStatus.supported(),
      PlaybackCapability.dualSubtitles: CapabilityStatus.supported(),
      PlaybackCapability.pgsSubtitleRendering: CapabilityStatus.supported(),
      PlaybackCapability.assSubtitleEnhancement: CapabilityStatus.supported(),
      if (anime4kShadersAvailable)
        PlaybackCapability.anime4kPreset: CapabilityStatus.supported(),
    },
  );
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
}) {
  return PlayerRuntimeCompositionContract(
    binding: MediaKitMpvBinding(
      backend: backend,
      backendFactory: backendFactory,
      libmpvPath: libmpvPath,
      anime4kShaderByPreset: anime4kShaderByPreset,
    ),
    capabilities: mediaKitLocalFilePlaybackCapabilities(
      anime4kShadersAvailable: anime4kShaderByPreset.isNotEmpty,
    ),
  );
}
