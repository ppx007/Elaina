import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/advanced_caption_storage_contracts.dart';
import 'av_sync_guard.dart';
import 'capability_matrix.dart';
import 'danmaku/danmaku_event.dart';
import 'subtitle/subtitle_source.dart';

enum AdvancedCaptionFeature {
  matrixDanmaku,
  dualSubtitles,
  pgsRendering,
  assEnhancement,
}

final class CaptionTransform4 {
  CaptionTransform4({required Iterable<double> values})
      : assert(
            values.length == 16, 'Matrix4 transform must contain 16 values.'),
        values = List<double>.unmodifiable(values);

  final List<double> values;
}

final class MatrixDanmakuRequest {
  MatrixDanmakuRequest(
      {required Iterable<DanmakuComment> comments, required this.transform})
      : comments = List<DanmakuComment>.unmodifiable(comments);

  final List<DanmakuComment> comments;
  final CaptionTransform4 transform;
}

final class DualSubtitleRequest {
  const DualSubtitleRequest({required this.primary, required this.secondary});

  final SubtitleSource primary;
  final SubtitleSource secondary;
}

enum AdvancedSubtitleRenderIntent {
  pgsImageSubtitle,
  assEnhancedLayout,
}

final class AdvancedSubtitleRequest {
  const AdvancedSubtitleRequest({required this.source, required this.intent});

  final SubtitleSource source;
  final AdvancedSubtitleRenderIntent intent;
}

final class AdvancedCaptionCapability {
  const AdvancedCaptionCapability(
      {required this.feature, required this.supported, this.reason});

  final AdvancedCaptionFeature feature;
  final bool supported;
  final String? reason;
}

final class AdvancedCaptionProfileId {
  const AdvancedCaptionProfileId(this.value)
      : assert(value != '', 'Advanced caption profile id must not be empty.');

  final String value;
}

final class AdvancedCaptionProfile {
  const AdvancedCaptionProfile({
    required this.id,
    required this.label,
    required this.matrixDanmakuEnabled,
    required this.dualSubtitlesEnabled,
    required this.pgsRenderingEnabled,
    required this.assEnhancementEnabled,
    this.primarySubtitleLanguageCode,
    this.secondarySubtitleLanguageCode,
  }) : assert(label != '', 'Advanced caption profile label must not be empty.');

  final AdvancedCaptionProfileId id;
  final String label;
  final bool matrixDanmakuEnabled;
  final bool dualSubtitlesEnabled;
  final bool pgsRenderingEnabled;
  final bool assEnhancementEnabled;
  final String? primarySubtitleLanguageCode;
  final String? secondarySubtitleLanguageCode;
}

enum AdvancedCaptionRendererState {
  disabled,
  evaluated,
  applied,
  rejected,
  degraded,
}

enum AdvancedCaptionFailureKind {
  featureDisabled,
  capabilityUnsupported,
  profileNotFound,
  dualSubtitleOrderRejected,
  staleEvaluation,
  avSyncDegradation,
}

final class AdvancedCaptionFailure implements Exception {
  const AdvancedCaptionFailure({required this.kind, required this.message});

  final AdvancedCaptionFailureKind kind;
  final String message;
}

final class CaptionEvaluationReport {
  CaptionEvaluationReport({
    required this.profile,
    required Iterable<AdvancedCaptionCapability> capabilities,
  }) : capabilities =
            List<AdvancedCaptionCapability>.unmodifiable(capabilities);

  final AdvancedCaptionProfile profile;
  final List<AdvancedCaptionCapability> capabilities;

  bool get supported => capabilities
      .every((AdvancedCaptionCapability capability) => capability.supported);

  String? get reason {
    final List<String> reasons = <String>[
      for (final AdvancedCaptionCapability capability in capabilities)
        if (!capability.supported && capability.reason != null)
          capability.reason!,
    ];
    return reasons.isEmpty ? null : reasons.join(' ');
  }
}

final class CaptionEvaluationOutcome {
  const CaptionEvaluationOutcome._({this.report, this.failure});

  const CaptionEvaluationOutcome.success(
      {required CaptionEvaluationReport report})
      : this._(report: report);

  const CaptionEvaluationOutcome.failure(
      {required AdvancedCaptionFailure failure})
      : this._(failure: failure);

  final CaptionEvaluationReport? report;
  final AdvancedCaptionFailure? failure;

  bool get isSuccess => failure == null;
}

final class CaptionRenderOutcome {
  const CaptionRenderOutcome._({this.profile, this.feature, this.failure});

  const CaptionRenderOutcome.rendered(
      {required AdvancedCaptionProfile profile,
      required AdvancedCaptionFeature feature})
      : this._(profile: profile, feature: feature);

  const CaptionRenderOutcome.rejected({required AdvancedCaptionFailure failure})
      : this._(failure: failure);

  final AdvancedCaptionProfile? profile;
  final AdvancedCaptionFeature? feature;
  final AdvancedCaptionFailure? failure;

  bool get isSuccess => failure == null;
}

final class CaptionDisableOutcome {
  const CaptionDisableOutcome._({this.failure});

  const CaptionDisableOutcome.disabled() : this._();

  const CaptionDisableOutcome.rejected(
      {required AdvancedCaptionFailure failure})
      : this._(failure: failure);

  final AdvancedCaptionFailure? failure;

  bool get isSuccess => failure == null;
}

final class CaptionDegradationOutcome {
  const CaptionDegradationOutcome._({this.profile, this.reason, this.failure});

  const CaptionDegradationOutcome.degraded(
      {required AdvancedCaptionProfile profile, required String reason})
      : this._(profile: profile, reason: reason);

  const CaptionDegradationOutcome.rejected(
      {required AdvancedCaptionFailure failure})
      : this._(failure: failure);

  final AdvancedCaptionProfile? profile;
  final String? reason;
  final AdvancedCaptionFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class AdvancedCaptionRenderer {
  List<AdvancedCaptionCapability> get capabilities;

  Future<CaptionEvaluationOutcome> evaluate(AdvancedCaptionProfile profile);

  Future<CaptionRenderOutcome> renderMatrixDanmaku(
      MatrixDanmakuRequest request);

  Future<CaptionRenderOutcome> renderDualSubtitles(DualSubtitleRequest request);

  Future<CaptionRenderOutcome> renderAdvancedSubtitle(
      AdvancedSubtitleRequest request);

  Future<CaptionDisableOutcome> disable();

  Future<CaptionDegradationOutcome> acceptDegradation(
      AVSyncDegradationAction action,
      {required String reason});
}

final class DeterministicAdvancedCaptionRenderer
    implements AdvancedCaptionRenderer {
  DeterministicAdvancedCaptionRenderer({
    required this.captionStore,
    required this.capabilityMatrix,
    required AdvancedCaptionProfile profile,
    this.cacheInvalidationBus,
    this.scopeId = 'default',
    DateTime Function()? clock,
  })  : _activeProfile = profile,
        _clock = clock ?? _defaultClock;

  final AdvancedCaptionStore captionStore;
  final PlaybackCapabilityMatrix capabilityMatrix;
  final CacheInvalidationBus? cacheInvalidationBus;
  final String scopeId;
  final DateTime Function() _clock;

  AdvancedCaptionProfile _activeProfile;
  CaptionEvaluationReport? _latestReport;
  AdvancedCaptionRendererState _state = AdvancedCaptionRendererState.disabled;

  @override
  List<AdvancedCaptionCapability> get capabilities =>
      _evaluateCapabilities(_activeProfile);

  @override
  Future<CaptionEvaluationOutcome> evaluate(
      AdvancedCaptionProfile profile) async {
    _activeProfile = profile;
    final CaptionEvaluationReport report = CaptionEvaluationReport(
      profile: profile,
      capabilities: _evaluateCapabilities(profile),
    );
    _latestReport = report;
    final bool supported = report.supported;
    final AdvancedCaptionRendererState nextState = supported
        ? AdvancedCaptionRendererState.evaluated
        : AdvancedCaptionRendererState.rejected;
    await _recordTransition(
      previousState: _state,
      newState: nextState,
      profile: profile,
      supported: supported,
      failureReason: report.reason,
      failureKind: supported
          ? null
          : AdvancedCaptionFailureKind.capabilityUnsupported.name,
    );
    cacheInvalidationBus?.publish(AdvancedCaptionCapabilityReevaluated(
      occurredAt: _clock(),
      profileId: profile.id.value,
      supported: supported,
      reason: report.reason,
    ));
    return CaptionEvaluationOutcome.success(report: report);
  }

  @override
  Future<CaptionRenderOutcome> renderMatrixDanmaku(
      MatrixDanmakuRequest request) async {
    return _renderFeature(AdvancedCaptionFeature.matrixDanmaku);
  }

  @override
  Future<CaptionRenderOutcome> renderDualSubtitles(
      DualSubtitleRequest request) async {
    if (request.primary.id == request.secondary.id) {
      final AdvancedCaptionFailure failure = AdvancedCaptionFailure(
        kind: AdvancedCaptionFailureKind.dualSubtitleOrderRejected,
        message: 'Primary and secondary subtitles must be distinct.',
      );
      await _recordTransition(
        previousState: _state,
        newState: AdvancedCaptionRendererState.rejected,
        profile: _activeProfile,
        supported: false,
        failureReason: failure.message,
        failureKind: failure.kind.name,
        feature: AdvancedCaptionFeature.dualSubtitles,
      );
      return CaptionRenderOutcome.rejected(failure: failure);
    }
    final DateTime now = _clock();
    await captionStore.setDualSubtitleSelection(
      StoredAdvancedCaptionDualSubtitleSelectionRecord(
        scopeId: scopeId,
        profileId: _activeProfile.id.value,
        primarySubtitleId: request.primary.id,
        secondarySubtitleId: request.secondary.id,
        primaryLanguageCode: request.primary.languageCode,
        secondaryLanguageCode: request.secondary.languageCode,
        selectedAt: now,
      ),
    );
    cacheInvalidationBus?.publish(AdvancedCaptionDualSubtitleSelectionChanged(
      occurredAt: now,
      scopeId: scopeId,
      profileId: _activeProfile.id.value,
      primarySubtitleId: request.primary.id,
      secondarySubtitleId: request.secondary.id,
      primaryLanguageCode: request.primary.languageCode,
      secondaryLanguageCode: request.secondary.languageCode,
    ));
    return _renderFeature(AdvancedCaptionFeature.dualSubtitles);
  }

  @override
  Future<CaptionRenderOutcome> renderAdvancedSubtitle(
      AdvancedSubtitleRequest request) async {
    final AdvancedCaptionFeature feature = switch (request.intent) {
      AdvancedSubtitleRenderIntent.pgsImageSubtitle =>
        AdvancedCaptionFeature.pgsRendering,
      AdvancedSubtitleRenderIntent.assEnhancedLayout =>
        AdvancedCaptionFeature.assEnhancement,
    };
    return _renderFeature(feature);
  }

  @override
  Future<CaptionDisableOutcome> disable() async {
    await _recordTransition(
      previousState: _state,
      newState: AdvancedCaptionRendererState.disabled,
      profile: _activeProfile,
      supported: true,
    );
    return const CaptionDisableOutcome.disabled();
  }

  @override
  Future<CaptionDegradationOutcome> acceptDegradation(
      AVSyncDegradationAction action,
      {required String reason}) async {
    if (action != AVSyncDegradationAction.disableAdvancedCaptions) {
      return CaptionDegradationOutcome.rejected(
        failure: AdvancedCaptionFailure(
          kind: AdvancedCaptionFailureKind.avSyncDegradation,
          message: 'Unsupported caption degradation action ${action.name}.',
        ),
      );
    }
    await _recordTransition(
      previousState: _state,
      newState: AdvancedCaptionRendererState.degraded,
      profile: _activeProfile,
      supported: true,
      degradationReason: reason,
    );
    cacheInvalidationBus?.publish(AdvancedCaptionDegradationStateChanged(
      occurredAt: _clock(),
      scopeId: scopeId,
      profileId: _activeProfile.id.value,
      degraded: true,
      reason: reason,
    ));
    return CaptionDegradationOutcome.degraded(
      profile: _activeProfile,
      reason: reason,
    );
  }

  Future<CaptionRenderOutcome> _renderFeature(
      AdvancedCaptionFeature feature) async {
    final CaptionEvaluationReport report =
        _latestReport?.profile.id.value == _activeProfile.id.value
            ? _latestReport!
            : (await evaluate(_activeProfile)).report!;
    final AdvancedCaptionCapability capability = report.capabilities.firstWhere(
      (AdvancedCaptionCapability capability) => capability.feature == feature,
      orElse: () => AdvancedCaptionCapability(
        feature: feature,
        supported: false,
        reason: 'Advanced caption feature ${feature.name} is disabled.',
      ),
    );
    if (!capability.supported) {
      final AdvancedCaptionFailure failure = AdvancedCaptionFailure(
        kind: _featureEnabled(_activeProfile, feature)
            ? AdvancedCaptionFailureKind.capabilityUnsupported
            : AdvancedCaptionFailureKind.featureDisabled,
        message: capability.reason ??
            'Advanced caption feature ${feature.name} is unsupported.',
      );
      await _recordTransition(
        previousState: _state,
        newState: AdvancedCaptionRendererState.rejected,
        profile: _activeProfile,
        supported: false,
        failureReason: failure.message,
        failureKind: failure.kind.name,
        feature: feature,
      );
      return CaptionRenderOutcome.rejected(failure: failure);
    }
    final DateTime now = _clock();
    await captionStore.storeProfile(_storedProfile(_activeProfile, now));
    await captionStore.setActiveProfile(
      StoredActiveAdvancedCaptionProfileRecord(
        scopeId: scopeId,
        profileId: _activeProfile.id.value,
        selectedAt: now,
      ),
    );
    cacheInvalidationBus?.publish(AdvancedCaptionProfileChanged(
      occurredAt: now,
      profileId: _activeProfile.id.value,
      changeKind: AdvancedCaptionProfileChangeKind.activated,
      scopeId: scopeId,
    ));
    await _recordTransition(
      previousState: _state,
      newState: AdvancedCaptionRendererState.applied,
      profile: _activeProfile,
      supported: true,
      feature: feature,
    );
    return CaptionRenderOutcome.rendered(
      profile: _activeProfile,
      feature: feature,
    );
  }

  List<AdvancedCaptionCapability> _evaluateCapabilities(
      AdvancedCaptionProfile profile) {
    return <AdvancedCaptionCapability>[
      _capability(
        feature: AdvancedCaptionFeature.matrixDanmaku,
        playbackCapability: PlaybackCapability.matrixDanmaku,
        enabled: profile.matrixDanmakuEnabled,
        disabledReason: 'Matrix4 danmaku is disabled by profile.',
      ),
      _capability(
        feature: AdvancedCaptionFeature.dualSubtitles,
        playbackCapability: PlaybackCapability.dualSubtitles,
        enabled: profile.dualSubtitlesEnabled,
        disabledReason: 'Dual subtitles are disabled by profile.',
      ),
      _capability(
        feature: AdvancedCaptionFeature.pgsRendering,
        playbackCapability: PlaybackCapability.pgsSubtitleRendering,
        enabled: profile.pgsRenderingEnabled,
        disabledReason: 'PGS subtitle rendering is disabled by profile.',
      ),
      _capability(
        feature: AdvancedCaptionFeature.assEnhancement,
        playbackCapability: PlaybackCapability.assSubtitleEnhancement,
        enabled: profile.assEnhancementEnabled,
        disabledReason: 'ASS subtitle enhancement is disabled by profile.',
      ),
    ];
  }

  AdvancedCaptionCapability _capability({
    required AdvancedCaptionFeature feature,
    required PlaybackCapability playbackCapability,
    required bool enabled,
    required String disabledReason,
  }) {
    if (!enabled) {
      return AdvancedCaptionCapability(
        feature: feature,
        supported: false,
        reason: disabledReason,
      );
    }
    final CapabilityStatus status =
        capabilityMatrix.statusOf(playbackCapability);
    return AdvancedCaptionCapability(
      feature: feature,
      supported: status.isSupported,
      reason: status.reason,
    );
  }

  bool _featureEnabled(
      AdvancedCaptionProfile profile, AdvancedCaptionFeature feature) {
    return switch (feature) {
      AdvancedCaptionFeature.matrixDanmaku => profile.matrixDanmakuEnabled,
      AdvancedCaptionFeature.dualSubtitles => profile.dualSubtitlesEnabled,
      AdvancedCaptionFeature.pgsRendering => profile.pgsRenderingEnabled,
      AdvancedCaptionFeature.assEnhancement => profile.assEnhancementEnabled,
    };
  }

  Future<void> _recordTransition({
    required AdvancedCaptionRendererState previousState,
    required AdvancedCaptionRendererState newState,
    required bool supported,
    AdvancedCaptionProfile? profile,
    AdvancedCaptionFeature? feature,
    String? failureReason,
    String? failureKind,
    String? degradationReason,
  }) async {
    _state = newState;
    await captionStore.recordRendererState(
      StoredAdvancedCaptionRendererStateRecord(
        scopeId: scopeId,
        profileId: profile?.id.value,
        feature: feature?.name,
        state: _storedState(newState),
        supported: supported,
        failureReason: failureReason,
        degradationReason: degradationReason,
        updatedAt: _clock(),
      ),
    );
    cacheInvalidationBus?.publish(AdvancedCaptionRendererStateChanged(
      occurredAt: _clock(),
      scopeId: scopeId,
      previousState: previousState.name,
      newState: newState.name,
      profileId: profile?.id.value,
      feature: feature?.name,
      failureKind: failureKind,
    ));
  }

  StoredAdvancedCaptionProfileRecord _storedProfile(
      AdvancedCaptionProfile profile, DateTime now) {
    return StoredAdvancedCaptionProfileRecord(
      id: profile.id.value,
      label: profile.label,
      matrixDanmakuEnabled: profile.matrixDanmakuEnabled,
      dualSubtitlesEnabled: profile.dualSubtitlesEnabled,
      pgsRenderingEnabled: profile.pgsRenderingEnabled,
      assEnhancementEnabled: profile.assEnhancementEnabled,
      primarySubtitleLanguageCode: profile.primarySubtitleLanguageCode,
      secondarySubtitleLanguageCode: profile.secondarySubtitleLanguageCode,
      createdAt: now,
      updatedAt: now,
    );
  }

  StoredAdvancedCaptionRendererStateKind _storedState(
      AdvancedCaptionRendererState state) {
    return switch (state) {
      AdvancedCaptionRendererState.disabled =>
        StoredAdvancedCaptionRendererStateKind.disabled,
      AdvancedCaptionRendererState.evaluated =>
        StoredAdvancedCaptionRendererStateKind.evaluated,
      AdvancedCaptionRendererState.applied =>
        StoredAdvancedCaptionRendererStateKind.applied,
      AdvancedCaptionRendererState.rejected =>
        StoredAdvancedCaptionRendererStateKind.rejected,
      AdvancedCaptionRendererState.degraded =>
        StoredAdvancedCaptionRendererStateKind.degraded,
    };
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();
