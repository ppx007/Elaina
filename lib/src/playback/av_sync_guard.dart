import 'dart:async';

import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/av_sync_guard_storage_contracts.dart';
import 'capability_matrix.dart';
import 'video_enhancement_pipeline.dart';

final class AVSyncSample {
  const AVSyncSample({
    required this.audioPosition,
    required this.videoPosition,
    required this.renderDelay,
    required this.droppedFrames,
    this.enhancementPressure,
  }) : assert(droppedFrames >= 0, 'droppedFrames must not be negative.');

  final Duration audioPosition;
  final Duration videoPosition;
  final Duration renderDelay;
  final int droppedFrames;
  final RenderBudgetInput? enhancementPressure;

  Duration get absoluteDrift {
    final int difference =
        audioPosition.inMicroseconds - videoPosition.inMicroseconds;
    return Duration(microseconds: difference.abs());
  }
}

final class AVSyncSampleWindow {
  const AVSyncSampleWindow({required this.samples})
      : assert(samples.length > 0, 'samples must not be empty.');

  final List<AVSyncSample> samples;

  Duration get averageDrift {
    final int totalMicros = samples.fold<int>(
      0,
      (int total, AVSyncSample sample) =>
          total + sample.absoluteDrift.inMicroseconds,
    );
    return Duration(microseconds: totalMicros ~/ samples.length);
  }

  AVSyncSample get latest => samples.last;
}

enum AVSyncHealth {
  target,
  warning,
  degraded,
}

enum AVSyncDegradationAction {
  keepCurrentProfile,
  reduceEnhancementIntensity,
  disableAdvancedCaptions,
  disableEnhancementProfile,
}

final class AVSyncPolicy {
  AVSyncPolicy({
    this.targetDrift = const Duration(milliseconds: 40),
    this.warningDrift = const Duration(milliseconds: 80),
    this.degradationDrift = const Duration(milliseconds: 120),
    this.recoveryDrift = const Duration(milliseconds: 60),
    this.sampleWindowSize = 3,
    Iterable<AVSyncDegradationAction> degradationOrder =
        const <AVSyncDegradationAction>[
      AVSyncDegradationAction.reduceEnhancementIntensity,
      AVSyncDegradationAction.disableAdvancedCaptions,
      AVSyncDegradationAction.disableEnhancementProfile,
    ],
  })  : assert(sampleWindowSize > 0, 'sampleWindowSize must be positive.'),
        degradationOrder =
            List<AVSyncDegradationAction>.unmodifiable(degradationOrder);

  final Duration targetDrift;
  final Duration warningDrift;
  final Duration degradationDrift;
  final Duration recoveryDrift;
  final int sampleWindowSize;
  final List<AVSyncDegradationAction> degradationOrder;
}

final class AVSyncDecision {
  const AVSyncDecision(
      {required this.health, required this.action, required this.reason});

  final AVSyncHealth health;
  final AVSyncDegradationAction action;
  final String reason;
}

enum AVSyncGuardFailureKind {
  capabilityUnsupported,
  insufficientSamples,
  policyNotConfigured,
}

final class AVSyncGuardFailure implements Exception {
  const AVSyncGuardFailure({required this.kind, required this.message});

  final AVSyncGuardFailureKind kind;
  final String message;
}

final class AVSyncEvaluationOutcome {
  const AVSyncEvaluationOutcome._({this.decision, this.failure});

  const AVSyncEvaluationOutcome.success({required AVSyncDecision decision})
      : this._(decision: decision);

  const AVSyncEvaluationOutcome.failure({required AVSyncGuardFailure failure})
      : this._(failure: failure);

  final AVSyncDecision? decision;
  final AVSyncGuardFailure? failure;

  bool get isSuccess => failure == null;
}

final class AVSyncHealthTransitionOutcome {
  const AVSyncHealthTransitionOutcome({
    required this.previousHealth,
    required this.newHealth,
    required this.decision,
  });

  final AVSyncHealth previousHealth;
  final AVSyncHealth newHealth;
  final AVSyncDecision decision;
}

final class AVSyncDegradationRequestOutcome {
  const AVSyncDegradationRequestOutcome._({this.decision, this.failure});

  const AVSyncDegradationRequestOutcome.accepted(
      {required AVSyncDecision decision})
      : this._(decision: decision);

  const AVSyncDegradationRequestOutcome.rejected(
      {required AVSyncGuardFailure failure})
      : this._(failure: failure);

  final AVSyncDecision? decision;
  final AVSyncGuardFailure? failure;

  bool get isSuccess => failure == null;
}

final class AVSyncRecoveryOutcome {
  const AVSyncRecoveryOutcome._({this.decision, this.failure});

  const AVSyncRecoveryOutcome.recovered({required AVSyncDecision decision})
      : this._(decision: decision);

  const AVSyncRecoveryOutcome.rejected({required AVSyncGuardFailure failure})
      : this._(failure: failure);

  final AVSyncDecision? decision;
  final AVSyncGuardFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class AVSyncGuard {
  AVSyncPolicy get policy;

  AVSyncDecision evaluate(AVSyncSample sample);

  Future<AVSyncEvaluationOutcome> ingestSample(AVSyncSample sample);

  Future<AVSyncDegradationRequestOutcome> requestDegradation(
      AVSyncSample sample);

  Future<AVSyncRecoveryOutcome> checkRecovery();

  Stream<AVSyncDecision> watchDecisions();
}

final class DeterministicAVSyncGuard implements AVSyncGuard {
  DeterministicAVSyncGuard({
    required this.policy,
    required this.guardStore,
    required this.capabilities,
    this.cacheInvalidationBus,
    this.scopeId = 'default',
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  @override
  final AVSyncPolicy policy;
  final AVSyncGuardStore guardStore;
  final PlaybackCapabilityMatrix capabilities;
  final CacheInvalidationBus? cacheInvalidationBus;
  final String scopeId;
  final DateTime Function() _clock;
  final StreamController<AVSyncDecision> _decisions =
      StreamController<AVSyncDecision>.broadcast(sync: true);
  final List<AVSyncSample> _samples = <AVSyncSample>[];
  AVSyncHealth _health = AVSyncHealth.target;
  int _sequence = 0;

  @override
  AVSyncDecision evaluate(AVSyncSample sample) {
    return _decisionForWindow(
        AVSyncSampleWindow(samples: <AVSyncSample>[sample]));
  }

  @override
  Future<AVSyncEvaluationOutcome> ingestSample(AVSyncSample sample) async {
    final CapabilityStatus status = capabilities.avSyncGuardStatus;
    if (!status.isSupported) {
      return AVSyncEvaluationOutcome.failure(
        failure: AVSyncGuardFailure(
          kind: AVSyncGuardFailureKind.capabilityUnsupported,
          message: status.reason ?? 'AVSyncGuard is unsupported.',
        ),
      );
    }
    _samples.add(sample);
    if (_samples.length > policy.sampleWindowSize) {
      _samples.removeAt(0);
    }
    final DateTime now = _clock();
    await guardStore.recordSampleMetadata(
      StoredAVSyncSampleHistoryMetadataRecord(
        scopeId: scopeId,
        sequence: _sequence++,
        audioPositionMillis: sample.audioPosition.inMilliseconds,
        videoPositionMillis: sample.videoPosition.inMilliseconds,
        driftMillis: sample.absoluteDrift.inMilliseconds,
        renderDelayMillis: sample.renderDelay.inMilliseconds,
        droppedFrames: sample.droppedFrames,
        recordedAt: now,
      ),
    );
    final AVSyncDecision decision = _samples.length < policy.sampleWindowSize
        ? evaluate(sample)
        : _decisionForWindow(
            AVSyncSampleWindow(samples: <AVSyncSample>[..._samples]));
    final AVSyncHealth previous = _health;
    _health = decision.health;
    await guardStore.recordHealth(_healthRecord(decision, sample, now));
    cacheInvalidationBus?.publish(AVSyncSampleIngested(
      occurredAt: now,
      scopeId: scopeId,
      driftMillis: sample.absoluteDrift.inMilliseconds,
      health: decision.health.name,
    ));
    if (previous != _health) {
      cacheInvalidationBus?.publish(AVSyncHealthTransitioned(
        occurredAt: now,
        scopeId: scopeId,
        previousHealth: previous.name,
        newHealth: _health.name,
        reason: decision.reason,
      ));
    }
    _publishDecision(decision);
    return AVSyncEvaluationOutcome.success(decision: decision);
  }

  @override
  Future<AVSyncDegradationRequestOutcome> requestDegradation(
      AVSyncSample sample) async {
    if (!capabilities.supports(PlaybackCapability.avSyncGuard)) {
      return const AVSyncDegradationRequestOutcome.rejected(
        failure: AVSyncGuardFailure(
          kind: AVSyncGuardFailureKind.capabilityUnsupported,
          message: 'AVSyncGuard capability is unsupported.',
        ),
      );
    }
    final AVSyncDecision decision = _degradationDecision(sample);
    final DateTime now = _clock();
    await guardStore.recordDegradationDecision(
      StoredAVSyncDegradationDecisionRecord(
        id: '$scopeId::${now.microsecondsSinceEpoch}',
        scopeId: scopeId,
        health: _storedHealth(decision.health),
        action: decision.action.name,
        reason: decision.reason,
        occurredAt: now,
      ),
    );
    cacheInvalidationBus?.publish(AVSyncDegradationDecisionRecorded(
      occurredAt: now,
      scopeId: scopeId,
      action: decision.action.name,
      health: decision.health.name,
      reason: decision.reason,
    ));
    _publishDecision(decision);
    return AVSyncDegradationRequestOutcome.accepted(decision: decision);
  }

  @override
  Future<AVSyncRecoveryOutcome> checkRecovery() async {
    if (_samples.isEmpty) {
      return const AVSyncRecoveryOutcome.rejected(
        failure: AVSyncGuardFailure(
          kind: AVSyncGuardFailureKind.insufficientSamples,
          message:
              'AVSyncGuard requires at least one sample to evaluate recovery.',
        ),
      );
    }
    final AVSyncDecision decision = _decisionForWindow(
        AVSyncSampleWindow(samples: <AVSyncSample>[..._samples]));
    if (decision.health == AVSyncHealth.degraded) {
      return const AVSyncRecoveryOutcome.rejected(
        failure: AVSyncGuardFailure(
          kind: AVSyncGuardFailureKind.insufficientSamples,
          message:
              'AV sync drift has not recovered below the recovery threshold.',
        ),
      );
    }
    final DateTime now = _clock();
    final AVSyncHealth previous = _health;
    _health = decision.health;
    await guardStore.recordHealth(_healthRecord(decision, _samples.last, now));
    cacheInvalidationBus?.publish(AVSyncRecoveryStateChanged(
      occurredAt: now,
      scopeId: scopeId,
      recoveredHealth: decision.health.name,
    ));
    if (previous != _health) {
      cacheInvalidationBus?.publish(AVSyncHealthTransitioned(
        occurredAt: now,
        scopeId: scopeId,
        previousHealth: previous.name,
        newHealth: _health.name,
        reason: decision.reason,
      ));
    }
    _publishDecision(decision);
    return AVSyncRecoveryOutcome.recovered(decision: decision);
  }

  @override
  Stream<AVSyncDecision> watchDecisions() => _decisions.stream;

  Future<void> close() => _decisions.close();

  AVSyncDecision _decisionForWindow(AVSyncSampleWindow window) {
    final Duration drift = window.averageDrift;
    if (drift >= policy.degradationDrift) {
      return AVSyncDecision(
        health: AVSyncHealth.degraded,
        action: _preferredDegradationAction(window.latest),
        reason: 'Average AV drift ${drift.inMilliseconds}ms exceeds red line.',
      );
    }
    if (drift >= policy.warningDrift) {
      return AVSyncDecision(
        health: AVSyncHealth.warning,
        action: AVSyncDegradationAction.keepCurrentProfile,
        reason:
            'Average AV drift ${drift.inMilliseconds}ms exceeds warning threshold.',
      );
    }
    if (drift <= policy.recoveryDrift) {
      return AVSyncDecision(
        health: AVSyncHealth.target,
        action: AVSyncDegradationAction.keepCurrentProfile,
        reason:
            'Average AV drift ${drift.inMilliseconds}ms is within recovery threshold.',
      );
    }
    return AVSyncDecision(
      health: _health,
      action: AVSyncDegradationAction.keepCurrentProfile,
      reason:
          'Average AV drift ${drift.inMilliseconds}ms preserves current guard health.',
    );
  }

  AVSyncDecision _degradationDecision(AVSyncSample sample) {
    final AVSyncDegradationAction action = _preferredDegradationAction(sample);
    return AVSyncDecision(
      health: AVSyncHealth.degraded,
      action: action,
      reason: 'AV sync degradation selected ${action.name}.',
    );
  }

  AVSyncDegradationAction _preferredDegradationAction(AVSyncSample sample) {
    final RenderBudgetInput? pressure = sample.enhancementPressure;
    final bool enhancementOverBudget = pressure != null &&
        (pressure.estimatedRenderCost > pressure.frameBudget ||
            pressure.droppedFrames > 0);
    if (enhancementOverBudget) {
      for (final AVSyncDegradationAction action in policy.degradationOrder) {
        if (action == AVSyncDegradationAction.reduceEnhancementIntensity ||
            action == AVSyncDegradationAction.disableEnhancementProfile) {
          return action;
        }
      }
    }
    return policy.degradationOrder.first;
  }

  StoredAVSyncHealthRecord _healthRecord(
      AVSyncDecision decision, AVSyncSample sample, DateTime now) {
    return StoredAVSyncHealthRecord(
      scopeId: scopeId,
      health: _storedHealth(decision.health),
      lastDriftMillis: sample.absoluteDrift.inMilliseconds,
      sampleCount: _samples.length,
      reason: decision.reason,
      updatedAt: now,
    );
  }

  StoredAVSyncHealthKind _storedHealth(AVSyncHealth health) {
    return switch (health) {
      AVSyncHealth.target => StoredAVSyncHealthKind.target,
      AVSyncHealth.warning => StoredAVSyncHealthKind.warning,
      AVSyncHealth.degraded => StoredAVSyncHealthKind.degraded,
    };
  }

  void _publishDecision(AVSyncDecision decision) {
    if (!_decisions.isClosed) {
      _decisions.add(decision);
    }
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();
