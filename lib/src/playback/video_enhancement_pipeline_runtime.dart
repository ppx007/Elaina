import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/video_enhancement_storage_contracts.dart';
import 'capability_matrix.dart';
import 'video_enhancement_pipeline.dart';

final class VideoEnhancementPipelineBootstrap {
  VideoEnhancementPipelineBootstrap({
    required this.profileStore,
    required Map<String, VideoEnhancementPipeline> runtimeByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  })  : runtimeByScope =
            Map<String, VideoEnhancementPipeline>.unmodifiable(runtimeByScope),
        capabilitiesByScope =
            Map<String, PlaybackCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _clock = clock ?? _defaultClock;

  final EnhancementProfileStore profileStore;
  final Map<String, VideoEnhancementPipeline> runtimeByScope;
  final Map<String, PlaybackCapabilityMatrix> capabilitiesByScope;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  VideoEnhancementPipelineRuntime createRuntime() {
    return VideoEnhancementPipelineRuntime(
      profileStore: profileStore,
      runtimeByScope: runtimeByScope,
      capabilitiesByScope: capabilitiesByScope,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: _clock,
    );
  }
}

enum VideoEnhancementPipelineRuntimeFailureKind {
  missingProfile,
  rejectedProfile,
  unsupportedCapabilities,
  unavailable,
  disposed,
}

final class VideoEnhancementPipelineRuntimeFailure implements Exception {
  const VideoEnhancementPipelineRuntimeFailure({
    required this.kind,
    required this.message,
  });

  final VideoEnhancementPipelineRuntimeFailureKind kind;
  final String message;
}

enum VideoEnhancementPipelineRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class VideoEnhancementPipelineRuntimeActionResult<T> {
  const VideoEnhancementPipelineRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const VideoEnhancementPipelineRuntimeActionResult.success(T value)
      : this._(
          kind: VideoEnhancementPipelineRuntimeActionResultKind.success,
          value: value,
        );

  const VideoEnhancementPipelineRuntimeActionResult.failed(
    VideoEnhancementPipelineRuntimeFailure failure,
  ) : this._(
          kind: VideoEnhancementPipelineRuntimeActionResultKind.failed,
          failure: failure,
        );

  const VideoEnhancementPipelineRuntimeActionResult.unavailable(
    VideoEnhancementPipelineRuntimeFailure failure,
  ) : this._(
          kind: VideoEnhancementPipelineRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  const VideoEnhancementPipelineRuntimeActionResult.disposed(
    VideoEnhancementPipelineRuntimeFailure failure,
  ) : this._(
          kind: VideoEnhancementPipelineRuntimeActionResultKind.disposed,
          failure: failure,
        );

  final VideoEnhancementPipelineRuntimeActionResultKind kind;
  final T? value;
  final VideoEnhancementPipelineRuntimeFailure? failure;

  bool get isSuccess =>
      kind == VideoEnhancementPipelineRuntimeActionResultKind.success;
}

final class EnhancementRuntimeDegradationRequest {
  EnhancementRuntimeDegradationRequest({
    required this.profileId,
    required this.renderBudget,
    Iterable<String> candidateTargetProfileIds = const <String>[],
  }) : candidateTargetProfileIds =
            List<String>.unmodifiable(candidateTargetProfileIds);

  final String profileId;
  final RenderBudgetInput renderBudget;
  final List<String> candidateTargetProfileIds;
}

final class VideoEnhancementPipelineStateProjection {
  const VideoEnhancementPipelineStateProjection({
    required this.scopeId,
    required this.state,
    required this.supported,
    required this.updatedAt,
    this.profileId,
    this.failureReason,
    this.budgetPressure,
    this.degradationTargetProfileId,
  });

  factory VideoEnhancementPipelineStateProjection.fromStored(
    StoredEnhancementPipelineStateRecord record,
  ) {
    return VideoEnhancementPipelineStateProjection(
      scopeId: record.scopeId,
      profileId: record.profileId,
      state: _pipelineStateFromStored(record.state),
      supported: record.supported,
      failureReason: record.failureReason,
      budgetPressure: record.budgetPressure,
      degradationTargetProfileId: record.degradationTargetProfileId,
      updatedAt: record.updatedAt,
    );
  }

  final String scopeId;
  final String? profileId;
  final EnhancementPipelineState state;
  final bool supported;
  final String? failureReason;
  final double? budgetPressure;
  final String? degradationTargetProfileId;
  final DateTime updatedAt;
}

final class VideoEnhancementPipelineRuntimeRestartProjection {
  const VideoEnhancementPipelineRuntimeRestartProjection({
    required this.scopeId,
    this.activeProfileId,
    this.latestPipelineState,
  });

  final String scopeId;
  final String? activeProfileId;
  final StoredEnhancementPipelineStateRecord? latestPipelineState;

  String? get degradationTargetProfileId =>
      latestPipelineState?.degradationTargetProfileId;
}

final class VideoEnhancementPipelineRuntimeProjection {
  const VideoEnhancementPipelineRuntimeProjection({
    required this.scopeId,
    required this.restart,
    this.activeProfileId,
    this.latestPipelineState,
    this.latestCapabilityReport,
    this.latestBudgetPressure,
    this.degradationTargetProfileId,
    this.latestFailure,
  });

  final String scopeId;
  final String? activeProfileId;
  final VideoEnhancementPipelineStateProjection? latestPipelineState;
  final EnhancementCapabilityReport? latestCapabilityReport;
  final EnhancementBudgetPressureSnapshot? latestBudgetPressure;
  final String? degradationTargetProfileId;
  final VideoEnhancementPipelineRuntimeFailure? latestFailure;
  final VideoEnhancementPipelineRuntimeRestartProjection restart;
}

final class VideoEnhancementPipelineRuntime {
  VideoEnhancementPipelineRuntime({
    required EnhancementProfileStore profileStore,
    required Map<String, VideoEnhancementPipeline> runtimeByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _profileStore = profileStore,
        _runtimeByScope =
            Map<String, VideoEnhancementPipeline>.unmodifiable(runtimeByScope),
        _capabilitiesByScope =
            Map<String, PlaybackCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _clock = clock ?? _defaultClock,
        _unavailableReason = null;

  VideoEnhancementPipelineRuntime.unavailable({required String reason})
      : _profileStore = DeterministicEnhancementProfileStore(),
        _runtimeByScope = const <String, VideoEnhancementPipeline>{},
        _capabilitiesByScope = const <String, PlaybackCapabilityMatrix>{},
        _clock = _defaultClock,
        _unavailableReason = reason;

  final EnhancementProfileStore _profileStore;
  final Map<String, VideoEnhancementPipeline> _runtimeByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;
  final DateTime Function() _clock;
  final String? _unavailableReason;
  final Map<String, EnhancementCapabilityReport> _latestReportsByScope =
      <String, EnhancementCapabilityReport>{};
  final Map<String, EnhancementBudgetPressureSnapshot> _latestBudgetsByScope =
      <String, EnhancementBudgetPressureSnapshot>{};
  final Map<String, VideoEnhancementPipelineRuntimeFailure>
      _latestFailuresByScope = <String, VideoEnhancementPipelineRuntimeFailure>{};
  bool _disposed = false;

  Future<VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>> snapshot(String scopeId) async {
    final VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>? gated = _gate(scopeId);
    if (gated != null) return gated;
    return VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>> evaluate({
    required String scopeId,
    required VideoEnhancementProfile profile,
  }) async {
    final VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>? gated = _gate(scopeId);
    if (gated != null) return gated;

    final VideoEnhancementPipelineRuntimeFailure? unsupported =
        _unsupportedCapabilitiesFailure(scopeId, profile);
    if (unsupported != null) {
      return _failed(scopeId, unsupported);
    }

    final EnhancementEvaluationOutcome outcome =
        await _runtimeByScope[scopeId]!.evaluate(profile);
    if (!outcome.isSuccess) {
      return _failed(scopeId, _failureFromPipeline(outcome.failure!));
    }
    _latestReportsByScope[scopeId] = outcome.report!;
    _latestFailuresByScope.remove(scopeId);
    return VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>> apply({
    required String scopeId,
    required String profileId,
  }) async {
    final VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>? gated = _gate(scopeId);
    if (gated != null) return gated;

    final StoredEnhancementProfileRecord? storedProfile =
        await _profileStore.findProfileById(profileId);
    if (storedProfile == null) {
      return _failed(
        scopeId,
        const VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.missingProfile,
          message: 'Enhancement profile was not found.',
        ),
      );
    }

    final VideoEnhancementProfile profile = _profileFromStored(storedProfile);
    final EnhancementApplyOutcome outcome =
        await _runtimeByScope[scopeId]!.apply(profile);
    if (!outcome.isSuccess) {
      return _failed(
        scopeId,
        VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.rejectedProfile,
          message: outcome.failure?.message ?? 'Enhancement profile rejected.',
        ),
      );
    }
    _latestFailuresByScope.remove(scopeId);
    return VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>> requestDegradation({
    required String scopeId,
    required EnhancementRuntimeDegradationRequest request,
  }) async {
    final VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>? gated = _gate(scopeId);
    if (gated != null) return gated;

    final StoredEnhancementProfileRecord? storedProfile =
        await _profileStore.findProfileById(request.profileId);
    if (storedProfile == null) {
      return _failed(
        scopeId,
        const VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.missingProfile,
          message: 'Enhancement profile was not found.',
        ),
      );
    }
    final List<VideoEnhancementProfile> targets =
        <VideoEnhancementProfile>[];
    for (final String targetId in request.candidateTargetProfileIds) {
      final StoredEnhancementProfileRecord? target =
          await _profileStore.findProfileById(targetId);
      if (target != null) {
        targets.add(_profileFromStored(target));
      }
    }
    final EnhancementDegradationOutcome outcome =
        await _runtimeByScope[scopeId]!.requestDegradation(
      EnhancementDegradationRequest(
        profile: _profileFromStored(storedProfile),
        renderBudget: request.renderBudget,
        candidateTargets: targets,
      ),
    );
    if (!outcome.isSuccess) {
      return _failed(scopeId, _failureFromPipeline(outcome.failure!));
    }
    _latestBudgetsByScope[scopeId] = outcome.snapshot!;
    await _profileStore.recordPipelineState(StoredEnhancementPipelineStateRecord(
      scopeId: scopeId,
      profileId: request.profileId,
      state: outcome.snapshot!.isOverBudget
          ? StoredEnhancementPipelineStateKind.degraded
          : StoredEnhancementPipelineStateKind.applied,
      supported: true,
      budgetPressure: outcome.snapshot!.pressureRatio,
      degradationTargetProfileId:
          outcome.snapshot!.degradationTarget?.id.value,
      updatedAt: _clock(),
    ));
    _latestFailuresByScope.remove(scopeId);
    return VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>.success(
      await _projection(scopeId),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>? _gate(String scopeId) {
    if (_disposed) {
      return const VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection>.disposed(
        VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.disposed,
          message: 'Video enhancement pipeline runtime is disposed.',
        ),
      );
    }
    if (_unavailableReason != null) {
      return VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection>.unavailable(
        VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.unavailable,
          message: _unavailableReason,
        ),
      );
    }
    if (!_runtimeByScope.containsKey(scopeId) ||
        !_capabilitiesByScope.containsKey(scopeId)) {
      return VideoEnhancementPipelineRuntimeActionResult<
          VideoEnhancementPipelineRuntimeProjection>.unavailable(
        VideoEnhancementPipelineRuntimeFailure(
          kind: VideoEnhancementPipelineRuntimeFailureKind.unavailable,
          message: 'Video enhancement runtime is unavailable for $scopeId.',
        ),
      );
    }
    return null;
  }

  Future<VideoEnhancementPipelineRuntimeActionResult<
      VideoEnhancementPipelineRuntimeProjection>> _failed(
    String scopeId,
    VideoEnhancementPipelineRuntimeFailure failure,
  ) async {
    _latestFailuresByScope[scopeId] = failure;
    return VideoEnhancementPipelineRuntimeActionResult<
        VideoEnhancementPipelineRuntimeProjection>.failed(failure);
  }

  VideoEnhancementPipelineRuntimeFailure? _unsupportedCapabilitiesFailure(
    String scopeId,
    VideoEnhancementProfile profile,
  ) {
    final VideoEnhancementCapabilityStatus status =
        _capabilitiesByScope[scopeId]!.videoEnhancementStatus();
    final List<String> reasons = <String>[
      if (!status.videoEnhancement.isSupported)
        status.videoEnhancement.reason ?? 'Video enhancement is unsupported.',
      if (profile.hdrHandling != HdrHandlingIntent.adapterDefault &&
          !status.hdrToneMapping.isSupported)
        status.hdrToneMapping.reason ?? 'HDR tone mapping is unsupported.',
      if (profile.deband != DebandIntent.off &&
          !status.debandFiltering.isSupported)
        status.debandFiltering.reason ?? 'Deband filtering is unsupported.',
      if (profile.anime4kPreset != Anime4kPresetIntent.off &&
          !status.anime4kPreset.isSupported)
        status.anime4kPreset.reason ?? 'Anime4K-style presets are unsupported.',
    ];
    if (reasons.isEmpty) return null;
    return VideoEnhancementPipelineRuntimeFailure(
      kind: VideoEnhancementPipelineRuntimeFailureKind.unsupportedCapabilities,
      message: reasons.join(' '),
    );
  }

  VideoEnhancementPipelineRuntimeFailure _failureFromPipeline(
    EnhancementPipelineFailure failure,
  ) {
    return VideoEnhancementPipelineRuntimeFailure(
      kind: switch (failure.kind) {
        EnhancementPipelineFailureKind.capabilityUnsupported =>
          VideoEnhancementPipelineRuntimeFailureKind.unsupportedCapabilities,
        EnhancementPipelineFailureKind.profileNotFound =>
          VideoEnhancementPipelineRuntimeFailureKind.missingProfile,
        EnhancementPipelineFailureKind.staleEvaluation ||
        EnhancementPipelineFailureKind.adapterRejected ||
        EnhancementPipelineFailureKind.budgetExceeded =>
          VideoEnhancementPipelineRuntimeFailureKind.rejectedProfile,
      },
      message: failure.message,
    );
  }

  Future<VideoEnhancementPipelineRuntimeProjection> _projection(
      String scopeId) async {
    final StoredActiveEnhancementProfileRecord? active =
        await _profileStore.activeProfile(scopeId);
    final StoredEnhancementPipelineStateRecord? storedState =
        await _profileStore.latestPipelineState(scopeId);
    final VideoEnhancementPipelineStateProjection? pipelineState =
        storedState == null
            ? null
            : VideoEnhancementPipelineStateProjection.fromStored(storedState);
    return VideoEnhancementPipelineRuntimeProjection(
      scopeId: scopeId,
      activeProfileId: active?.profileId,
      latestPipelineState: pipelineState,
      latestCapabilityReport: _latestReportsByScope[scopeId],
      latestBudgetPressure: _latestBudgetsByScope[scopeId],
      degradationTargetProfileId: _latestBudgetsByScope[scopeId]
              ?.degradationTarget
              ?.id
              .value ??
          storedState?.degradationTargetProfileId,
      latestFailure: _latestFailuresByScope[scopeId] ??
          (storedState?.failureReason == null
              ? null
              : VideoEnhancementPipelineRuntimeFailure(
                  kind: VideoEnhancementPipelineRuntimeFailureKind
                      .rejectedProfile,
                  message: storedState!.failureReason!,
                )),
      restart: VideoEnhancementPipelineRuntimeRestartProjection(
        scopeId: scopeId,
        activeProfileId: active?.profileId,
        latestPipelineState: storedState,
      ),
    );
  }
}

VideoEnhancementProfile _profileFromStored(
  StoredEnhancementProfileRecord record,
) {
  return VideoEnhancementProfile(
    id: EnhancementProfileId(record.id),
    label: record.label,
    scaler: _enumByName(VideoScalerIntent.values, record.scalerIntent,
        VideoScalerIntent.adapterDefault),
    hdrHandling: _enumByName(HdrHandlingIntent.values, record.hdrHandlingIntent,
        HdrHandlingIntent.adapterDefault),
    deband: _enumByName(
        DebandIntent.values, record.debandIntent, DebandIntent.off),
    anime4kPreset: _enumByName(Anime4kPresetIntent.values,
        record.anime4kPresetIntent, Anime4kPresetIntent.off),
  );
}

T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

EnhancementPipelineState _pipelineStateFromStored(
  StoredEnhancementPipelineStateKind state,
) {
  return switch (state) {
    StoredEnhancementPipelineStateKind.disabled =>
      EnhancementPipelineState.disabled,
    StoredEnhancementPipelineStateKind.evaluated =>
      EnhancementPipelineState.evaluated,
    StoredEnhancementPipelineStateKind.applied => EnhancementPipelineState.applied,
    StoredEnhancementPipelineStateKind.rejected =>
      EnhancementPipelineState.rejected,
    StoredEnhancementPipelineStateKind.degraded =>
      EnhancementPipelineState.degraded,
  };
}

DateTime _defaultClock() => DateTime.now().toUtc();
