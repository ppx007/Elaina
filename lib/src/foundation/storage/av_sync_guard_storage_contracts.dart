// Stored AV-sync records preserve drift measurements and degradation decisions.
// Live timing policy remains in AVSyncGuardRuntime.
// Store implementations should not reinterpret drift thresholds.
import '../baseline_defaults.dart';

enum StoredAVSyncHealthKind {
  target,
  warning,
  degraded,
}

final class StoredAVSyncPolicyRecord {
  const StoredAVSyncPolicyRecord({
    required this.id,
    required this.targetDriftMillis,
    required this.warningDriftMillis,
    required this.degradationDriftMillis,
    required this.recoveryDriftMillis,
    required this.sampleWindowSize,
    required this.degradationOrder,
    required this.updatedAt,
  })  : assert(id != '', 'AV sync policy id must not be empty.'),
        assert(
            targetDriftMillis >= 0, 'targetDriftMillis must not be negative.'),
        assert(warningDriftMillis >= 0,
            'warningDriftMillis must not be negative.'),
        assert(degradationDriftMillis >= 0,
            'degradationDriftMillis must not be negative.'),
        assert(recoveryDriftMillis >= 0,
            'recoveryDriftMillis must not be negative.'),
        assert(sampleWindowSize > 0, 'sampleWindowSize must be positive.'),
        assert(
            degradationOrder.length > 0, 'degradationOrder must not be empty.');

  final String id;
  final int targetDriftMillis;
  final int warningDriftMillis;
  final int degradationDriftMillis;
  final int recoveryDriftMillis;
  final int sampleWindowSize;
  final List<String> degradationOrder;
  final DateTime updatedAt;

  StoredAVSyncPolicyRecord copyWith({
    int? targetDriftMillis,
    int? warningDriftMillis,
    int? degradationDriftMillis,
    int? recoveryDriftMillis,
    int? sampleWindowSize,
    List<String>? degradationOrder,
    DateTime? updatedAt,
  }) {
    return StoredAVSyncPolicyRecord(
      id: id,
      targetDriftMillis: targetDriftMillis ?? this.targetDriftMillis,
      warningDriftMillis: warningDriftMillis ?? this.warningDriftMillis,
      degradationDriftMillis:
          degradationDriftMillis ?? this.degradationDriftMillis,
      recoveryDriftMillis: recoveryDriftMillis ?? this.recoveryDriftMillis,
      sampleWindowSize: sampleWindowSize ?? this.sampleWindowSize,
      degradationOrder: degradationOrder ?? this.degradationOrder,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class StoredAVSyncHealthRecord {
  const StoredAVSyncHealthRecord({
    required this.scopeId,
    required this.health,
    required this.lastDriftMillis,
    required this.sampleCount,
    required this.updatedAt,
    this.reason,
  })  : assert(scopeId != '', 'AV sync health scope id must not be empty.'),
        assert(lastDriftMillis >= 0, 'lastDriftMillis must not be negative.'),
        assert(sampleCount >= 0, 'sampleCount must not be negative.'),
        assert(reason == null || reason != '',
            'AV sync reason must not be empty.');

  final String scopeId;
  final StoredAVSyncHealthKind health;
  final int lastDriftMillis;
  final int sampleCount;
  final String? reason;
  final DateTime updatedAt;
}

final class StoredAVSyncSampleHistoryMetadataRecord {
  const StoredAVSyncSampleHistoryMetadataRecord({
    required this.scopeId,
    required this.sequence,
    required this.audioPositionMillis,
    required this.videoPositionMillis,
    required this.driftMillis,
    required this.renderDelayMillis,
    required this.droppedFrames,
    required this.recordedAt,
  })  : assert(scopeId != '', 'AV sync sample scope id must not be empty.'),
        assert(sequence >= 0, 'sequence must not be negative.'),
        assert(audioPositionMillis >= 0,
            'audioPositionMillis must not be negative.'),
        assert(videoPositionMillis >= 0,
            'videoPositionMillis must not be negative.'),
        assert(driftMillis >= 0, 'driftMillis must not be negative.'),
        assert(
            renderDelayMillis >= 0, 'renderDelayMillis must not be negative.'),
        assert(droppedFrames >= 0, 'droppedFrames must not be negative.');

  final String scopeId;
  final int sequence;
  final int audioPositionMillis;
  final int videoPositionMillis;
  final int driftMillis;
  final int renderDelayMillis;
  final int droppedFrames;
  final DateTime recordedAt;
}

final class StoredAVSyncDegradationDecisionRecord {
  const StoredAVSyncDegradationDecisionRecord({
    required this.id,
    required this.scopeId,
    required this.health,
    required this.action,
    required this.reason,
    required this.occurredAt,
  })  : assert(id != '', 'AV sync degradation decision id must not be empty.'),
        assert(
            scopeId != '', 'AV sync degradation scope id must not be empty.'),
        assert(action != '', 'AV sync degradation action must not be empty.'),
        assert(reason != '', 'AV sync degradation reason must not be empty.');

  final String id;
  final String scopeId;
  final StoredAVSyncHealthKind health;
  final String action;
  final String reason;
  final DateTime occurredAt;
}

abstract interface class AVSyncGuardStore {
  Future<StoredAVSyncPolicyRecord> storePolicy(StoredAVSyncPolicyRecord policy);

  Future<StoredAVSyncPolicyRecord?> activePolicy(String policyId);

  Future<void> recordHealth(StoredAVSyncHealthRecord health);

  Future<StoredAVSyncHealthRecord?> latestHealth(String scopeId);

  Future<void> recordSampleMetadata(
      StoredAVSyncSampleHistoryMetadataRecord sample);

  Future<List<StoredAVSyncSampleHistoryMetadataRecord>> sampleHistory(
      String scopeId,
      {int limit = defaultRecentListLimit});

  Future<void> recordDegradationDecision(
      StoredAVSyncDegradationDecisionRecord decision);

  Future<List<StoredAVSyncDegradationDecisionRecord>> degradationHistory(
      String scopeId,
      {int limit = defaultRecentListLimit});
}

final class DeterministicAVSyncGuardStore implements AVSyncGuardStore {
  DeterministicAVSyncGuardStore({
    Iterable<StoredAVSyncPolicyRecord> seedPolicies =
        const <StoredAVSyncPolicyRecord>[],
    Iterable<StoredAVSyncHealthRecord> seedHealth =
        const <StoredAVSyncHealthRecord>[],
    Iterable<StoredAVSyncSampleHistoryMetadataRecord> seedSamples =
        const <StoredAVSyncSampleHistoryMetadataRecord>[],
    Iterable<StoredAVSyncDegradationDecisionRecord> seedDecisions =
        const <StoredAVSyncDegradationDecisionRecord>[],
  }) {
    for (final StoredAVSyncPolicyRecord policy in seedPolicies) {
      _policiesById[policy.id] = policy;
    }
    for (final StoredAVSyncHealthRecord health in seedHealth) {
      _healthByScope[health.scopeId] = health;
    }
    for (final StoredAVSyncSampleHistoryMetadataRecord sample in seedSamples) {
      _samplesByScope
          .putIfAbsent(
              sample.scopeId, () => <StoredAVSyncSampleHistoryMetadataRecord>[])
          .add(sample);
    }
    for (final StoredAVSyncDegradationDecisionRecord decision
        in seedDecisions) {
      _decisionsByScope
          .putIfAbsent(
              decision.scopeId, () => <StoredAVSyncDegradationDecisionRecord>[])
          .add(decision);
    }
  }

  final Map<String, StoredAVSyncPolicyRecord> _policiesById =
      <String, StoredAVSyncPolicyRecord>{};
  final Map<String, StoredAVSyncHealthRecord> _healthByScope =
      <String, StoredAVSyncHealthRecord>{};
  final Map<String, List<StoredAVSyncSampleHistoryMetadataRecord>>
      _samplesByScope =
      <String, List<StoredAVSyncSampleHistoryMetadataRecord>>{};
  final Map<String, List<StoredAVSyncDegradationDecisionRecord>>
      _decisionsByScope =
      <String, List<StoredAVSyncDegradationDecisionRecord>>{};

  @override
  Future<StoredAVSyncPolicyRecord?> activePolicy(String policyId) {
    return Future<StoredAVSyncPolicyRecord?>.value(_policiesById[policyId]);
  }

  @override
  Future<List<StoredAVSyncDegradationDecisionRecord>> degradationHistory(
      String scopeId,
      {int limit = defaultRecentListLimit}) {
    final List<StoredAVSyncDegradationDecisionRecord> decisions =
        <StoredAVSyncDegradationDecisionRecord>[
      ...?_decisionsByScope[scopeId],
    ]..sort((StoredAVSyncDegradationDecisionRecord left,
                StoredAVSyncDegradationDecisionRecord right) =>
            right.occurredAt.compareTo(left.occurredAt));
    return Future<List<StoredAVSyncDegradationDecisionRecord>>.value(
        decisions.take(limit).toList(growable: false));
  }

  @override
  Future<StoredAVSyncHealthRecord?> latestHealth(String scopeId) {
    return Future<StoredAVSyncHealthRecord?>.value(_healthByScope[scopeId]);
  }

  @override
  Future<void> recordDegradationDecision(
      StoredAVSyncDegradationDecisionRecord decision) {
    _decisionsByScope
        .putIfAbsent(
            decision.scopeId, () => <StoredAVSyncDegradationDecisionRecord>[])
        .add(decision);
    return Future<void>.value();
  }

  @override
  Future<void> recordHealth(StoredAVSyncHealthRecord health) {
    _healthByScope[health.scopeId] = health;
    return Future<void>.value();
  }

  @override
  Future<void> recordSampleMetadata(
      StoredAVSyncSampleHistoryMetadataRecord sample) {
    _samplesByScope
        .putIfAbsent(
            sample.scopeId, () => <StoredAVSyncSampleHistoryMetadataRecord>[])
        .add(sample);
    return Future<void>.value();
  }

  @override
  Future<List<StoredAVSyncSampleHistoryMetadataRecord>> sampleHistory(
      String scopeId,
      {int limit = defaultRecentListLimit}) {
    final List<StoredAVSyncSampleHistoryMetadataRecord> samples =
        <StoredAVSyncSampleHistoryMetadataRecord>[...?_samplesByScope[scopeId]]
          ..sort((StoredAVSyncSampleHistoryMetadataRecord left,
                  StoredAVSyncSampleHistoryMetadataRecord right) =>
              right.sequence.compareTo(left.sequence));
    return Future<List<StoredAVSyncSampleHistoryMetadataRecord>>.value(
        samples.take(limit).toList(growable: false));
  }

  @override
  Future<StoredAVSyncPolicyRecord> storePolicy(
      StoredAVSyncPolicyRecord policy) {
    _policiesById[policy.id] = policy;
    return Future<StoredAVSyncPolicyRecord>.value(policy);
  }
}
