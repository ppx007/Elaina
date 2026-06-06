import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/video_enhancement_storage_contracts.dart';
import 'capability_matrix.dart';

enum VideoScalerIntent {
  adapterDefault,
  sharp,
  smooth,
  animeOptimized,
}

enum HdrHandlingIntent {
  passthrough,
  toneMapToSdr,
  adapterDefault,
}

enum DebandIntent {
  off,
  light,
  medium,
  strong,
}

enum Anime4kPresetIntent {
  off,
  restore,
  upscale,
  restoreAndUpscale,
}

final class EnhancementProfileId {
  const EnhancementProfileId(this.value)
      : assert(value != '', 'Enhancement profile id must not be empty.');

  final String value;
}

final class VideoEnhancementProfile {
  const VideoEnhancementProfile({
    required this.id,
    required this.label,
    required this.scaler,
    required this.hdrHandling,
    required this.deband,
    required this.anime4kPreset,
  }) : assert(label != '', 'Enhancement profile label must not be empty.');

  final EnhancementProfileId id;
  final String label;
  final VideoScalerIntent scaler;
  final HdrHandlingIntent hdrHandling;
  final DebandIntent deband;
  final Anime4kPresetIntent anime4kPreset;
}

final class RenderBudgetInput {
  const RenderBudgetInput({
    required this.frameBudget,
    required this.estimatedRenderCost,
    required this.droppedFrames,
  }) : assert(droppedFrames >= 0, 'droppedFrames must not be negative.');

  final Duration frameBudget;
  final Duration estimatedRenderCost;
  final int droppedFrames;
}

final class EnhancementCapabilityReport {
  const EnhancementCapabilityReport({
    required this.profile,
    required this.supported,
    this.reason,
    this.unsupportedComponents = const <String>[],
  });

  final VideoEnhancementProfile profile;
  final bool supported;
  final String? reason;
  final List<String> unsupportedComponents;
}

enum EnhancementPipelineState {
  disabled,
  evaluated,
  applied,
  rejected,
  degraded,
}

enum EnhancementPipelineFailureKind {
  capabilityUnsupported,
  profileNotFound,
  staleEvaluation,
  adapterRejected,
  budgetExceeded,
}

final class EnhancementPipelineFailure implements Exception {
  const EnhancementPipelineFailure({required this.kind, required this.message});

  final EnhancementPipelineFailureKind kind;
  final String message;
}

final class EnhancementEvaluationOutcome {
  const EnhancementEvaluationOutcome._({this.report, this.failure});

  const EnhancementEvaluationOutcome.success(
      {required EnhancementCapabilityReport report})
      : this._(report: report);

  const EnhancementEvaluationOutcome.failure(
      {required EnhancementPipelineFailure failure})
      : this._(failure: failure);

  final EnhancementCapabilityReport? report;
  final EnhancementPipelineFailure? failure;

  bool get isSuccess => failure == null;
}

final class EnhancementApplyOutcome {
  const EnhancementApplyOutcome._({this.profile, this.failure});

  const EnhancementApplyOutcome.applied(
      {required VideoEnhancementProfile profile})
      : this._(profile: profile);

  const EnhancementApplyOutcome.rejected(
      {required EnhancementPipelineFailure failure})
      : this._(failure: failure);

  final VideoEnhancementProfile? profile;
  final EnhancementPipelineFailure? failure;

  bool get isSuccess => failure == null;
}

final class EnhancementDisableOutcome {
  const EnhancementDisableOutcome._({this.failure});

  const EnhancementDisableOutcome.disabled() : this._();

  const EnhancementDisableOutcome.rejected(
      {required EnhancementPipelineFailure failure})
      : this._(failure: failure);

  final EnhancementPipelineFailure? failure;

  bool get isSuccess => failure == null;
}

final class EnhancementBudgetPressureSnapshot {
  const EnhancementBudgetPressureSnapshot({
    required this.profile,
    required this.input,
    required this.isOverBudget,
    required this.pressureRatio,
    this.degradationTarget,
  }) : assert(pressureRatio >= 0, 'pressureRatio must not be negative.');

  final VideoEnhancementProfile profile;
  final RenderBudgetInput input;
  final bool isOverBudget;
  final double pressureRatio;
  final VideoEnhancementProfile? degradationTarget;
}

final class EnhancementDegradationRequest {
  const EnhancementDegradationRequest({
    required this.profile,
    required this.renderBudget,
    this.candidateTargets = const <VideoEnhancementProfile>[],
  });

  final VideoEnhancementProfile profile;
  final RenderBudgetInput renderBudget;
  final List<VideoEnhancementProfile> candidateTargets;
}

final class EnhancementDegradationOutcome {
  const EnhancementDegradationOutcome._({this.snapshot, this.failure});

  const EnhancementDegradationOutcome.requested(
      {required EnhancementBudgetPressureSnapshot snapshot})
      : this._(snapshot: snapshot);

  const EnhancementDegradationOutcome.rejected(
      {required EnhancementPipelineFailure failure})
      : this._(failure: failure);

  final EnhancementBudgetPressureSnapshot? snapshot;
  final EnhancementPipelineFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class VideoEnhancementPipeline {
  Future<EnhancementEvaluationOutcome> evaluate(
      VideoEnhancementProfile profile);

  Future<EnhancementApplyOutcome> apply(VideoEnhancementProfile profile);

  Future<EnhancementDisableOutcome> disable();

  Future<EnhancementDegradationOutcome> requestDegradation(
      EnhancementDegradationRequest request);
}

final class DeterministicVideoEnhancementPipeline
    implements VideoEnhancementPipeline {
  DeterministicVideoEnhancementPipeline({
    required this.profileStore,
    required this.capabilities,
    this.cacheInvalidationBus,
    this.scopeId = 'default',
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final EnhancementProfileStore profileStore;
  final PlaybackCapabilityMatrix capabilities;
  final CacheInvalidationBus? cacheInvalidationBus;
  final String scopeId;
  final DateTime Function() _clock;

  EnhancementCapabilityReport? _latestReport;
  EnhancementPipelineState _state = EnhancementPipelineState.disabled;

  @override
  Future<EnhancementEvaluationOutcome> evaluate(
      VideoEnhancementProfile profile) async {
    final List<String> unsupported = _unsupportedComponents(profile);
    final bool supported = unsupported.isEmpty;
    final EnhancementCapabilityReport report = EnhancementCapabilityReport(
      profile: profile,
      supported: supported,
      reason: supported ? null : unsupported.join(' '),
      unsupportedComponents: unsupported,
    );
    _latestReport = report;
    _state = supported
        ? EnhancementPipelineState.evaluated
        : EnhancementPipelineState.rejected;
    await profileStore.recordPipelineState(_stateRecord(
      state: _state,
      profileId: profile.id.value,
      supported: supported,
      failureReason: report.reason,
    ));
    cacheInvalidationBus?.publish(EnhancementCapabilityReevaluated(
      occurredAt: _clock(),
      profileId: profile.id.value,
      supported: supported,
      reason: report.reason,
    ));
    return EnhancementEvaluationOutcome.success(report: report);
  }

  @override
  Future<EnhancementApplyOutcome> apply(VideoEnhancementProfile profile) async {
    final EnhancementCapabilityReport report =
        _latestReport?.profile.id.value == profile.id.value
            ? _latestReport!
            : (await evaluate(profile)).report!;
    if (!report.supported) {
      final EnhancementPipelineFailure failure = EnhancementPipelineFailure(
        kind: EnhancementPipelineFailureKind.capabilityUnsupported,
        message: report.reason ?? 'Enhancement profile is unsupported.',
      );
      await _recordTransition(
        previousState: _state,
        newState: EnhancementPipelineState.rejected,
        profile: profile,
        failureKind: failure.kind.name,
        failureReason: failure.message,
      );
      return EnhancementApplyOutcome.rejected(failure: failure);
    }
    final DateTime now = _clock();
    await profileStore.storeProfile(_storedProfile(profile, now));
    await profileStore.setActiveProfile(StoredActiveEnhancementProfileRecord(
      scopeId: scopeId,
      profileId: profile.id.value,
      selectedAt: now,
    ));
    cacheInvalidationBus?.publish(EnhancementProfileChanged(
      occurredAt: now,
      profileId: profile.id.value,
      changeKind: EnhancementProfileChangeKind.activated,
      scopeId: scopeId,
    ));
    await _recordTransition(
      previousState: _state,
      newState: EnhancementPipelineState.applied,
      profile: profile,
    );
    return EnhancementApplyOutcome.applied(profile: profile);
  }

  @override
  Future<EnhancementDisableOutcome> disable() async {
    await _recordTransition(
      previousState: _state,
      newState: EnhancementPipelineState.disabled,
    );
    return const EnhancementDisableOutcome.disabled();
  }

  @override
  Future<EnhancementDegradationOutcome> requestDegradation(
      EnhancementDegradationRequest request) async {
    final EnhancementBudgetPressureSnapshot snapshot =
        _budgetPressureSnapshot(request);
    await profileStore.recordPipelineState(_stateRecord(
      state: snapshot.isOverBudget
          ? EnhancementPipelineState.degraded
          : EnhancementPipelineState.applied,
      profileId: request.profile.id.value,
      supported: true,
      budgetPressure: snapshot.pressureRatio,
      degradationTargetProfileId: snapshot.degradationTarget?.id.value,
    ));
    if (snapshot.isOverBudget) {
      await _recordTransition(
        previousState: _state,
        newState: EnhancementPipelineState.degraded,
        profile: request.profile,
      );
    }
    return EnhancementDegradationOutcome.requested(snapshot: snapshot);
  }

  List<String> _unsupportedComponents(VideoEnhancementProfile profile) {
    final List<String> reasons = <String>[];
    final CapabilityStatus enhancement =
        capabilities.statusOf(PlaybackCapability.videoEnhancement);
    if (!enhancement.isSupported) {
      reasons.add(enhancement.reason ?? 'Video enhancement is unsupported.');
    }
    if (profile.hdrHandling != HdrHandlingIntent.adapterDefault &&
        !capabilities.supports(PlaybackCapability.hdrToneMapping)) {
      reasons.add(
          capabilities.statusOf(PlaybackCapability.hdrToneMapping).reason ??
              'HDR tone mapping is unsupported.');
    }
    if (profile.deband != DebandIntent.off &&
        !capabilities.supports(PlaybackCapability.debandFiltering)) {
      reasons.add(
          capabilities.statusOf(PlaybackCapability.debandFiltering).reason ??
              'Deband filtering is unsupported.');
    }
    if (profile.anime4kPreset != Anime4kPresetIntent.off &&
        !capabilities.supports(PlaybackCapability.anime4kPreset)) {
      reasons.add(
          capabilities.statusOf(PlaybackCapability.anime4kPreset).reason ??
              'Anime4K-style presets are unsupported.');
    }
    return reasons;
  }

  EnhancementBudgetPressureSnapshot _budgetPressureSnapshot(
      EnhancementDegradationRequest request) {
    final int budgetMicros = request.renderBudget.frameBudget.inMicroseconds;
    final int costMicros =
        request.renderBudget.estimatedRenderCost.inMicroseconds;
    final double pressureRatio =
        budgetMicros == 0 ? 0 : costMicros / budgetMicros;
    final bool isOverBudget =
        costMicros > budgetMicros || request.renderBudget.droppedFrames > 0;
    return EnhancementBudgetPressureSnapshot(
      profile: request.profile,
      input: request.renderBudget,
      isOverBudget: isOverBudget,
      pressureRatio: pressureRatio,
      degradationTarget: isOverBudget && request.candidateTargets.isNotEmpty
          ? request.candidateTargets.first
          : null,
    );
  }

  Future<void> _recordTransition({
    required EnhancementPipelineState previousState,
    required EnhancementPipelineState newState,
    VideoEnhancementProfile? profile,
    String? failureKind,
    String? failureReason,
  }) async {
    _state = newState;
    await profileStore.recordPipelineState(_stateRecord(
      state: newState,
      profileId: profile?.id.value,
      supported: failureKind == null,
      failureReason: failureReason,
    ));
    cacheInvalidationBus?.publish(EnhancementPipelineStateChanged(
      occurredAt: _clock(),
      scopeId: scopeId,
      previousState: previousState.name,
      newState: newState.name,
      profileId: profile?.id.value,
      failureKind: failureKind,
    ));
  }

  StoredEnhancementPipelineStateRecord _stateRecord({
    required EnhancementPipelineState state,
    required bool supported,
    String? profileId,
    String? failureReason,
    double? budgetPressure,
    String? degradationTargetProfileId,
  }) {
    return StoredEnhancementPipelineStateRecord(
      scopeId: scopeId,
      profileId: profileId,
      state: _storedState(state),
      supported: supported,
      failureReason: failureReason,
      budgetPressure: budgetPressure,
      degradationTargetProfileId: degradationTargetProfileId,
      updatedAt: _clock(),
    );
  }

  StoredEnhancementProfileRecord _storedProfile(
      VideoEnhancementProfile profile, DateTime now) {
    return StoredEnhancementProfileRecord(
      id: profile.id.value,
      label: profile.label,
      scalerIntent: profile.scaler.name,
      hdrHandlingIntent: profile.hdrHandling.name,
      debandIntent: profile.deband.name,
      anime4kPresetIntent: profile.anime4kPreset.name,
      createdAt: now,
      updatedAt: now,
    );
  }

  StoredEnhancementPipelineStateKind _storedState(
      EnhancementPipelineState state) {
    return switch (state) {
      EnhancementPipelineState.disabled =>
        StoredEnhancementPipelineStateKind.disabled,
      EnhancementPipelineState.evaluated =>
        StoredEnhancementPipelineStateKind.evaluated,
      EnhancementPipelineState.applied =>
        StoredEnhancementPipelineStateKind.applied,
      EnhancementPipelineState.rejected =>
        StoredEnhancementPipelineStateKind.rejected,
      EnhancementPipelineState.degraded =>
        StoredEnhancementPipelineStateKind.degraded,
    };
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();
