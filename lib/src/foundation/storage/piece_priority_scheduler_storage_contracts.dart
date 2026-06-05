enum StoredPiecePriorityApplicationOutcomeKind {
  accepted,
  rejected,
  unavailable,
}

final class StoredPiecePriorityStrategyProfileRecord {
  const StoredPiecePriorityStrategyProfileRecord({
    required this.id,
    required this.displayName,
    required this.firstPiecePriority,
    required this.tailPiecePriority,
    required this.playbackWindowPriority,
    required this.seekTargetPriority,
    required this.staleWindowPriority,
    required this.lookaheadBytes,
    required this.seekLookaheadBytes,
    required this.edgePieceCount,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  })  : assert(id != '', 'Strategy profile id must not be empty.'),
        assert(displayName != '',
            'Strategy profile displayName must not be empty.'),
        assert(lookaheadBytes >= 0, 'lookaheadBytes must not be negative.'),
        assert(seekLookaheadBytes >= 0,
            'seekLookaheadBytes must not be negative.'),
        assert(edgePieceCount >= 0, 'edgePieceCount must not be negative.');

  final String id;
  final String displayName;
  final String firstPiecePriority;
  final String tailPiecePriority;
  final String playbackWindowPriority;
  final String seekTargetPriority;
  final String staleWindowPriority;
  final int lookaheadBytes;
  final int seekLookaheadBytes;
  final int edgePieceCount;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class StoredActivePiecePriorityProfileRecord {
  const StoredActivePiecePriorityProfileRecord({
    required this.taskId,
    required this.streamId,
    required this.profileId,
    required this.selectedAt,
  })  : assert(taskId != '', 'BT task id must not be empty.'),
        assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(profileId != '', 'Strategy profile id must not be empty.');

  final String taskId;
  final String streamId;
  final String profileId;
  final DateTime selectedAt;
}

final class StoredPiecePriorityPlanRecord {
  const StoredPiecePriorityPlanRecord({
    required this.id,
    required this.taskId,
    required this.streamId,
    required this.fileIndex,
    required this.profileId,
    required this.pieceLengthBytes,
    required this.generatedAt,
    this.metadataInfoHash,
    this.playbackStartByte,
    this.playbackEndByte,
    this.seekTargetByte,
  })  : assert(id != '', 'Piece priority plan id must not be empty.'),
        assert(taskId != '', 'BT task id must not be empty.'),
        assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(fileIndex >= 0, 'BT file index must not be negative.'),
        assert(profileId != '', 'Strategy profile id must not be empty.'),
        assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.'),
        assert(playbackStartByte == null || playbackStartByte >= 0,
            'playbackStartByte must not be negative.'),
        assert(playbackEndByte == null || playbackStartByte != null,
            'playbackEndByte requires playbackStartByte.'),
        assert(
            playbackEndByte == null ||
                (playbackStartByte != null &&
                    playbackEndByte >= playbackStartByte),
            'playbackEndByte must be greater than or equal to playbackStartByte.'),
        assert(seekTargetByte == null || seekTargetByte >= 0,
            'seekTargetByte must not be negative.');

  final String id;
  final String taskId;
  final String streamId;
  final int fileIndex;
  final String profileId;
  final String? metadataInfoHash;
  final int pieceLengthBytes;
  final int? playbackStartByte;
  final int? playbackEndByte;
  final int? seekTargetByte;
  final DateTime generatedAt;
}

final class StoredPiecePriorityPlanRuleRecord {
  const StoredPiecePriorityPlanRuleRecord({
    required this.planId,
    required this.pieceIndex,
    required this.priority,
    required this.reason,
    required this.order,
    this.deadlineMillis,
  })  : assert(planId != '', 'Piece priority plan id must not be empty.'),
        assert(pieceIndex >= 0, 'pieceIndex must not be negative.'),
        assert(priority != '', 'priority must not be empty.'),
        assert(reason != '', 'reason must not be empty.'),
        assert(order >= 0, 'order must not be negative.'),
        assert(deadlineMillis == null || deadlineMillis >= 0,
            'deadlineMillis must not be negative.');

  final String planId;
  final int pieceIndex;
  final String priority;
  final String reason;
  final int order;
  final int? deadlineMillis;
}

final class StoredPiecePriorityPlanApplicationEventRecord {
  const StoredPiecePriorityPlanApplicationEventRecord({
    required this.planId,
    required this.taskId,
    required this.streamId,
    required this.profileId,
    required this.outcome,
    required this.occurredAt,
    this.failureKind,
    this.message,
  })  : assert(planId != '', 'Piece priority plan id must not be empty.'),
        assert(taskId != '', 'BT task id must not be empty.'),
        assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(profileId != '', 'Strategy profile id must not be empty.');

  final String planId;
  final String taskId;
  final String streamId;
  final String profileId;
  final StoredPiecePriorityApplicationOutcomeKind outcome;
  final String? failureKind;
  final String? message;
  final DateTime occurredAt;
}

abstract interface class PiecePrioritySchedulerStore {
  Future<StoredPiecePriorityStrategyProfileRecord> storeProfile(
      StoredPiecePriorityStrategyProfileRecord profile);

  Future<StoredPiecePriorityStrategyProfileRecord?> findProfileById(
      String profileId);

  Future<List<StoredPiecePriorityStrategyProfileRecord>> listProfiles();

  Future<void> setActiveProfile(StoredActivePiecePriorityProfileRecord active);

  Future<StoredActivePiecePriorityProfileRecord?> activeProfile({
    required String taskId,
    required String streamId,
  });

  Future<StoredPiecePriorityPlanRecord> storePlan(
      StoredPiecePriorityPlanRecord plan);

  Future<StoredPiecePriorityPlanRecord?> findPlanById(String planId);

  Future<StoredPiecePriorityPlanRecord?> latestPlanForStream({
    required String taskId,
    required String streamId,
    String? profileId,
  });

  Future<void> storePlanRules({
    required String planId,
    required Iterable<StoredPiecePriorityPlanRuleRecord> rules,
  });

  Future<List<StoredPiecePriorityPlanRuleRecord>> rulesForPlan(String planId);

  Future<void> recordApplicationEvent(
      StoredPiecePriorityPlanApplicationEventRecord event);

  Future<StoredPiecePriorityPlanApplicationEventRecord?> latestApplicationEvent(
      String planId);
}

final class DeterministicPiecePrioritySchedulerStore
    implements PiecePrioritySchedulerStore {
  DeterministicPiecePrioritySchedulerStore({
    Iterable<StoredPiecePriorityStrategyProfileRecord> seedProfiles =
        const <StoredPiecePriorityStrategyProfileRecord>[],
  }) {
    for (final StoredPiecePriorityStrategyProfileRecord profile
        in seedProfiles) {
      _profilesById[profile.id] = profile;
    }
  }

  final Map<String, StoredPiecePriorityStrategyProfileRecord> _profilesById =
      <String, StoredPiecePriorityStrategyProfileRecord>{};
  final Map<String, StoredActivePiecePriorityProfileRecord> _activeByStream =
      <String, StoredActivePiecePriorityProfileRecord>{};
  final Map<String, StoredPiecePriorityPlanRecord> _plansById =
      <String, StoredPiecePriorityPlanRecord>{};
  final Map<String, List<StoredPiecePriorityPlanRuleRecord>> _rulesByPlanId =
      <String, List<StoredPiecePriorityPlanRuleRecord>>{};
  final Map<String, StoredPiecePriorityPlanApplicationEventRecord>
      _applicationEventsByPlanId =
      <String, StoredPiecePriorityPlanApplicationEventRecord>{};

  @override
  Future<StoredActivePiecePriorityProfileRecord?> activeProfile({
    required String taskId,
    required String streamId,
  }) {
    return Future<StoredActivePiecePriorityProfileRecord?>.value(
        _activeByStream[_streamKey(taskId, streamId)]);
  }

  @override
  Future<StoredPiecePriorityStrategyProfileRecord?> findProfileById(
      String profileId) {
    return Future<StoredPiecePriorityStrategyProfileRecord?>.value(
        _profilesById[profileId]);
  }

  @override
  Future<StoredPiecePriorityPlanRecord?> findPlanById(String planId) {
    return Future<StoredPiecePriorityPlanRecord?>.value(_plansById[planId]);
  }

  @override
  Future<StoredPiecePriorityPlanApplicationEventRecord?> latestApplicationEvent(
      String planId) {
    return Future<StoredPiecePriorityPlanApplicationEventRecord?>.value(
        _applicationEventsByPlanId[planId]);
  }

  @override
  Future<StoredPiecePriorityPlanRecord?> latestPlanForStream({
    required String taskId,
    required String streamId,
    String? profileId,
  }) {
    StoredPiecePriorityPlanRecord? latest;
    for (final StoredPiecePriorityPlanRecord plan in _plansById.values) {
      if (plan.taskId != taskId || plan.streamId != streamId) {
        continue;
      }
      if (profileId != null && plan.profileId != profileId) {
        continue;
      }
      if (latest == null || plan.generatedAt.isAfter(latest.generatedAt)) {
        latest = plan;
      }
    }
    return Future<StoredPiecePriorityPlanRecord?>.value(latest);
  }

  @override
  Future<List<StoredPiecePriorityStrategyProfileRecord>> listProfiles() {
    return Future<List<StoredPiecePriorityStrategyProfileRecord>>.value(
        <StoredPiecePriorityStrategyProfileRecord>[..._profilesById.values]);
  }

  @override
  Future<void> recordApplicationEvent(
      StoredPiecePriorityPlanApplicationEventRecord event) {
    _applicationEventsByPlanId[event.planId] = event;
    return Future<void>.value();
  }

  @override
  Future<List<StoredPiecePriorityPlanRuleRecord>> rulesForPlan(String planId) {
    return Future<List<StoredPiecePriorityPlanRuleRecord>>.value(
      <StoredPiecePriorityPlanRuleRecord>[...?_rulesByPlanId[planId]]..sort(
          (StoredPiecePriorityPlanRuleRecord left,
                  StoredPiecePriorityPlanRuleRecord right) =>
              left.order.compareTo(right.order)),
    );
  }

  @override
  Future<void> setActiveProfile(StoredActivePiecePriorityProfileRecord active) {
    _activeByStream[_streamKey(active.taskId, active.streamId)] = active;
    return Future<void>.value();
  }

  @override
  Future<StoredPiecePriorityPlanRecord> storePlan(
      StoredPiecePriorityPlanRecord plan) {
    _plansById[plan.id] = plan;
    return Future<StoredPiecePriorityPlanRecord>.value(plan);
  }

  @override
  Future<StoredPiecePriorityStrategyProfileRecord> storeProfile(
      StoredPiecePriorityStrategyProfileRecord profile) {
    _profilesById[profile.id] = profile;
    return Future<StoredPiecePriorityStrategyProfileRecord>.value(profile);
  }

  @override
  Future<void> storePlanRules({
    required String planId,
    required Iterable<StoredPiecePriorityPlanRuleRecord> rules,
  }) {
    _rulesByPlanId[planId] = <StoredPiecePriorityPlanRuleRecord>[...rules]
      ..sort((StoredPiecePriorityPlanRuleRecord left,
              StoredPiecePriorityPlanRuleRecord right) =>
          left.order.compareTo(right.order));
    return Future<void>.value();
  }

  static String _streamKey(String taskId, String streamId) =>
      '$taskId::$streamId';
}
