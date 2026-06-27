import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/advanced_caption_storage_contracts.dart';
import 'advanced_caption_rendering.dart';
import 'av_sync_guard.dart';
import 'capability_matrix.dart';

/// Wires advanced caption rendering to profiles, capabilities, and storage.
///
/// Keeping bootstrap wiring centralized prevents app composition from applying
/// a renderer with a capability matrix from the wrong playback scope.
final class AdvancedCaptionRuntimeBootstrap {
  AdvancedCaptionRuntimeBootstrap({
    required this.captionStore,
    required Map<String, AdvancedCaptionRenderer> rendererByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    this.cacheInvalidationBus,
  })  : _rendererByScope =
            Map<String, AdvancedCaptionRenderer>.unmodifiable(rendererByScope),
        _capabilitiesByScope =
            Map<String, PlaybackCapabilityMatrix>.unmodifiable(
                capabilitiesByScope);

  final AdvancedCaptionStore captionStore;
  final Map<String, AdvancedCaptionRenderer> _rendererByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? cacheInvalidationBus;

  AdvancedCaptionRuntime createRuntime() {
    return AdvancedCaptionRuntime._(
      captionStore: captionStore,
      rendererByScope: _rendererByScope,
      capabilitiesByScope: _capabilitiesByScope,
      cacheInvalidationBus: cacheInvalidationBus,
    );
  }
}

enum AdvancedCaptionRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  featureDisabled,
  profileNotFound,
  dualSubtitleOrderRejected,
  staleEvaluation,
  adapterRejected,
  avSyncDegradation,
}

final class AdvancedCaptionRuntimeFailure implements Exception {
  const AdvancedCaptionRuntimeFailure({
    required this.kind,
    required this.message,
  });

  final AdvancedCaptionRuntimeFailureKind kind;
  final String message;
}

enum AdvancedCaptionRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class AdvancedCaptionRuntimeActionResult<T> {
  const AdvancedCaptionRuntimeActionResult.success(this.value)
      : failure = null,
        kind = AdvancedCaptionRuntimeActionResultKind.success;

  const AdvancedCaptionRuntimeActionResult.failed(this.failure)
      : value = null,
        kind = AdvancedCaptionRuntimeActionResultKind.failed;

  const AdvancedCaptionRuntimeActionResult.unavailable(this.failure)
      : value = null,
        kind = AdvancedCaptionRuntimeActionResultKind.unavailable;

  const AdvancedCaptionRuntimeActionResult.disposed(this.failure)
      : value = null,
        kind = AdvancedCaptionRuntimeActionResultKind.disposed;

  final T? value;
  final AdvancedCaptionRuntimeFailure? failure;
  final AdvancedCaptionRuntimeActionResultKind kind;

  bool get isSuccess => kind == AdvancedCaptionRuntimeActionResultKind.success;
}

final class AdvancedCaptionRuntimeRestartProjection {
  AdvancedCaptionRuntimeRestartProjection({
    required this.scopeId,
    this.activeProfileId,
    this.latestRendererState,
    this.latestDegradationReason,
    this.dualSubtitlePrimaryId,
    this.dualSubtitleSecondaryId,
  });

  final String scopeId;
  final String? activeProfileId;
  final StoredAdvancedCaptionRendererStateKind? latestRendererState;
  final String? latestDegradationReason;
  final String? dualSubtitlePrimaryId;
  final String? dualSubtitleSecondaryId;
}

final class AdvancedCaptionRuntimeProjection {
  AdvancedCaptionRuntimeProjection._({
    required this.scopeId,
    this.activeProfileId,
    this.latestRendererState,
    this.latestReport,
    this.latestDegradationReason,
    this.dualSubtitlePrimaryId,
    this.dualSubtitleSecondaryId,
    this.latestFailure,
    required this.restart,
  });

  final String scopeId;
  final String? activeProfileId;
  final StoredAdvancedCaptionRendererStateKind? latestRendererState;
  final CaptionEvaluationReport? latestReport;
  final String? latestDegradationReason;
  final String? dualSubtitlePrimaryId;
  final String? dualSubtitleSecondaryId;
  final AdvancedCaptionRuntimeFailure? latestFailure;
  final AdvancedCaptionRuntimeRestartProjection restart;
}

/// Runtime facade for matrix danmaku, dual subtitles, and advanced subtitle use.
///
/// It persists only decisions and projection state; actual rendering remains in
/// [AdvancedCaptionRenderer] so the UI never talks to native caption backends.
final class AdvancedCaptionRuntime {
  AdvancedCaptionRuntime._({
    required AdvancedCaptionStore captionStore,
    required Map<String, AdvancedCaptionRenderer> rendererByScope,
    required Map<String, PlaybackCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? cacheInvalidationBus,
  })  : _captionStore = captionStore,
        _rendererByScope = rendererByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _unavailableReason = null;

  AdvancedCaptionRuntime.unavailable({required String reason})
      : _captionStore = DeterministicAdvancedCaptionStore(),
        _rendererByScope = const <String, AdvancedCaptionRenderer>{},
        _capabilitiesByScope = const <String, PlaybackCapabilityMatrix>{},
        _unavailableReason = reason;

  final AdvancedCaptionStore _captionStore;
  final Map<String, AdvancedCaptionRenderer> _rendererByScope;
  final Map<String, PlaybackCapabilityMatrix> _capabilitiesByScope;
  final String? _unavailableReason;
  bool _disposed = false;
  CaptionEvaluationReport? _latestReport;
  AdvancedCaptionRuntimeFailure? _latestFailure;

  Future<AdvancedCaptionRuntimeActionResult<AdvancedCaptionRuntimeProjection>>
      snapshot(String scopeId) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<
          AdvancedCaptionRuntimeProjection>.failed(gate);
    }
    final AdvancedCaptionRuntimeProjection projection =
        await _buildProjection(scopeId);
    return AdvancedCaptionRuntimeActionResult<
        AdvancedCaptionRuntimeProjection>.success(projection);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>> evaluate(
      String scopeId, AdvancedCaptionProfile profile) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<
          CaptionEvaluationOutcome>.failed(gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionEvaluationOutcome outcome = await renderer.evaluate(profile);
    _latestReport = outcome.report;
    return AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>.success(
        outcome);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>>
      renderMatrixDanmaku(String scopeId, MatrixDanmakuRequest request) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.failed(
          gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionRenderOutcome outcome =
        await renderer.renderMatrixDanmaku(request);
    if (!outcome.isSuccess) {
      _latestFailure = AdvancedCaptionRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
    }
    return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.success(
        outcome);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>>
      renderDualSubtitles(String scopeId, DualSubtitleRequest request) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.failed(
          gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionRenderOutcome outcome =
        await renderer.renderDualSubtitles(request);
    if (!outcome.isSuccess) {
      _latestFailure = AdvancedCaptionRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
    }
    return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.success(
        outcome);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>>
      renderAdvancedSubtitle(
          String scopeId, AdvancedSubtitleRequest request) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.failed(
          gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionRenderOutcome outcome =
        await renderer.renderAdvancedSubtitle(request);
    if (!outcome.isSuccess) {
      _latestFailure = AdvancedCaptionRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
    }
    return AdvancedCaptionRuntimeActionResult<CaptionRenderOutcome>.success(
        outcome);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>> disable(
      String scopeId) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>.failed(
          gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionDisableOutcome outcome = await renderer.disable();
    return AdvancedCaptionRuntimeActionResult<CaptionDisableOutcome>.success(
        outcome);
  }

  Future<AdvancedCaptionRuntimeActionResult<CaptionDegradationOutcome>>
      acceptDegradation(
    String scopeId,
    AVSyncDegradationAction action, {
    required String reason,
  }) async {
    final AdvancedCaptionRuntimeFailure? gate = _gate(scopeId);
    if (gate != null) {
      return AdvancedCaptionRuntimeActionResult<
          CaptionDegradationOutcome>.failed(gate);
    }
    final AdvancedCaptionRenderer renderer = _rendererByScope[scopeId]!;
    final CaptionDegradationOutcome outcome =
        await renderer.acceptDegradation(action, reason: reason);
    if (!outcome.isSuccess) {
      _latestFailure = AdvancedCaptionRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
    }
    return AdvancedCaptionRuntimeActionResult<
        CaptionDegradationOutcome>.success(outcome);
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  AdvancedCaptionRuntimeFailure? _gate(String scopeId) {
    if (_disposed) {
      return AdvancedCaptionRuntimeFailure(
        kind: AdvancedCaptionRuntimeFailureKind.disposed,
        message: 'AdvancedCaptionRuntime is disposed.',
      );
    }
    if (_unavailableReason != null) {
      return AdvancedCaptionRuntimeFailure(
        kind: AdvancedCaptionRuntimeFailureKind.unavailable,
        message: _unavailableReason,
      );
    }
    if (!_rendererByScope.containsKey(scopeId)) {
      return AdvancedCaptionRuntimeFailure(
        kind: AdvancedCaptionRuntimeFailureKind.capabilityUnsupported,
        message: 'No renderer for scope $scopeId.',
      );
    }
    final PlaybackCapabilityMatrix? capabilities =
        _capabilitiesByScope[scopeId];
    if (capabilities == null) {
      return AdvancedCaptionRuntimeFailure(
        kind: AdvancedCaptionRuntimeFailureKind.capabilityUnsupported,
        message: 'No capabilities for scope $scopeId.',
      );
    }
    final bool hasSupported = <PlaybackCapability>[
      PlaybackCapability.matrixDanmaku,
      PlaybackCapability.dualSubtitles,
      PlaybackCapability.pgsSubtitleRendering,
      PlaybackCapability.assSubtitleEnhancement,
    ].any((PlaybackCapability cap) => capabilities.statusOf(cap).isSupported);
    if (!hasSupported) {
      return AdvancedCaptionRuntimeFailure(
        kind: AdvancedCaptionRuntimeFailureKind.capabilityUnsupported,
        message: 'No supported advanced caption capability for scope $scopeId.',
      );
    }
    return null;
  }

  Future<AdvancedCaptionRuntimeProjection> _buildProjection(
      String scopeId) async {
    final StoredActiveAdvancedCaptionProfileRecord? active =
        await _captionStore.activeProfile(scopeId);
    final StoredAdvancedCaptionRendererStateRecord? state =
        await _captionStore.latestRendererState(scopeId);
    final StoredAdvancedCaptionDualSubtitleSelectionRecord? dual =
        await _captionStore.dualSubtitleSelection(scopeId);
    final AdvancedCaptionRuntimeRestartProjection restart =
        AdvancedCaptionRuntimeRestartProjection(
      scopeId: scopeId,
      activeProfileId: active?.profileId,
      latestRendererState: state?.state,
      latestDegradationReason: state?.degradationReason,
      dualSubtitlePrimaryId: dual?.primarySubtitleId,
      dualSubtitleSecondaryId: dual?.secondarySubtitleId,
    );
    return AdvancedCaptionRuntimeProjection._(
      scopeId: scopeId,
      activeProfileId: active?.profileId,
      latestRendererState: state?.state,
      latestReport: _latestReport,
      latestDegradationReason: state?.degradationReason,
      dualSubtitlePrimaryId: dual?.primarySubtitleId,
      dualSubtitleSecondaryId: dual?.secondarySubtitleId,
      latestFailure: _latestFailure,
      restart: restart,
    );
  }

  AdvancedCaptionRuntimeFailureKind _mapFailureKind(
      AdvancedCaptionFailureKind kind) {
    return switch (kind) {
      AdvancedCaptionFailureKind.featureDisabled =>
        AdvancedCaptionRuntimeFailureKind.featureDisabled,
      AdvancedCaptionFailureKind.capabilityUnsupported =>
        AdvancedCaptionRuntimeFailureKind.capabilityUnsupported,
      AdvancedCaptionFailureKind.profileNotFound =>
        AdvancedCaptionRuntimeFailureKind.profileNotFound,
      AdvancedCaptionFailureKind.dualSubtitleOrderRejected =>
        AdvancedCaptionRuntimeFailureKind.dualSubtitleOrderRejected,
      AdvancedCaptionFailureKind.staleEvaluation =>
        AdvancedCaptionRuntimeFailureKind.staleEvaluation,
      AdvancedCaptionFailureKind.adapterRejected =>
        AdvancedCaptionRuntimeFailureKind.adapterRejected,
      AdvancedCaptionFailureKind.avSyncDegradation =>
        AdvancedCaptionRuntimeFailureKind.avSyncDegradation,
    };
  }
}
