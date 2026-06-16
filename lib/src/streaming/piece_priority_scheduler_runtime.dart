import 'dart:collection';

import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';
import 'piece_priority_scheduler.dart';
import 'virtual_media_stream.dart';

const int balancedProfileLookaheadBytes = 2048;
const int balancedProfileSeekLookaheadBytes = 1024;
const int balancedProfileEdgePieceCount = 1;

final class PiecePrioritySchedulerBootstrap {
  PiecePrioritySchedulerBootstrap({
    required this.btTaskStore,
    required this.streamStore,
    required this.schedulerStore,
    this.cacheInvalidationBus,
    Iterable<PiecePriorityStrategyProfile> profiles =
        const <PiecePriorityStrategyProfile>[
      PiecePrioritySchedulerRuntime.balancedProfile,
    ],
    DateTime Function()? clock,
  })  : profiles = List<PiecePriorityStrategyProfile>.unmodifiable(profiles),
        _clock = clock ?? _defaultClock;

  final BtTaskStore btTaskStore;
  final VirtualMediaStreamStore streamStore;
  final PiecePrioritySchedulerStore schedulerStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final List<PiecePriorityStrategyProfile> profiles;
  final DateTime Function() _clock;

  PiecePrioritySchedulerRuntime createRuntime({
    PiecePriorityPlanApplier? planApplier,
  }) {
    return PiecePrioritySchedulerRuntime(
      btTaskStore: btTaskStore,
      streamStore: streamStore,
      schedulerStore: schedulerStore,
      cacheInvalidationBus: cacheInvalidationBus,
      profiles: profiles,
      planApplier: planApplier,
      clock: _clock,
    );
  }
}

enum PiecePriorityRuntimeFailureKind {
  disposed,
  dependencyUnavailable,
  planNotFound,
  stalePlan,
  unsupportedProfile,
}

final class PiecePriorityRuntimeFailure implements Exception {
  const PiecePriorityRuntimeFailure(
      {required this.kind, required this.message});

  final PiecePriorityRuntimeFailureKind kind;
  final String message;
}

final class PiecePriorityProfileSelectionOutcome {
  const PiecePriorityProfileSelectionOutcome._({this.profile, this.failure});

  const PiecePriorityProfileSelectionOutcome.success(
      {required PiecePriorityStrategyProfile profile})
      : this._(profile: profile);

  const PiecePriorityProfileSelectionOutcome.failure(
      {required PiecePriorityRuntimeFailure failure})
      : this._(failure: failure);

  final PiecePriorityStrategyProfile? profile;
  final PiecePriorityRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

final class PiecePriorityPlanLookupOutcome {
  const PiecePriorityPlanLookupOutcome._({this.plan, this.failure});

  const PiecePriorityPlanLookupOutcome.success(
      {required PiecePriorityPlan plan})
      : this._(plan: plan);

  const PiecePriorityPlanLookupOutcome.failure(
      {required PiecePriorityRuntimeFailure failure})
      : this._(failure: failure);

  final PiecePriorityPlan? plan;
  final PiecePriorityRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

final class PiecePrioritySnapshotOutcome {
  const PiecePrioritySnapshotOutcome._({this.snapshot, this.failure});

  const PiecePrioritySnapshotOutcome.success(
      {required PiecePrioritySchedulerSnapshot snapshot})
      : this._(snapshot: snapshot);

  const PiecePrioritySnapshotOutcome.failure(
      {required PiecePriorityRuntimeFailure failure})
      : this._(failure: failure);

  final PiecePrioritySchedulerSnapshot? snapshot;
  final PiecePriorityRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

final class PiecePrioritySchedulerRuntime implements PiecePriorityScheduler {
  PiecePrioritySchedulerRuntime({
    required this.btTaskStore,
    required this.streamStore,
    required this.schedulerStore,
    this.cacheInvalidationBus,
    Iterable<PiecePriorityStrategyProfile> profiles =
        const <PiecePriorityStrategyProfile>[balancedProfile],
    this.planApplier,
    DateTime Function()? clock,
  })  : _clock = clock ?? _defaultClock,
        _profilesById = <String, PiecePriorityStrategyProfile>{
          for (final PiecePriorityStrategyProfile profile in profiles)
            profile.id: profile,
        };

  static const PiecePriorityStrategyProfile balancedProfile =
      PiecePriorityStrategyProfile(
    id: 'balanced',
    displayName: 'Balanced',
    firstPiecePriority: DownloadPriority.critical,
    tailPiecePriority: DownloadPriority.high,
    playbackWindowPriority: DownloadPriority.high,
    seekTargetPriority: DownloadPriority.critical,
    staleWindowPriority: DownloadPriority.low,
    lookaheadBytes: balancedProfileLookaheadBytes,
    seekLookaheadBytes: balancedProfileSeekLookaheadBytes,
    edgePieceCount: balancedProfileEdgePieceCount,
  );

  final BtTaskStore btTaskStore;
  final VirtualMediaStreamStore streamStore;
  final PiecePrioritySchedulerStore schedulerStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final PiecePriorityPlanApplier? planApplier;
  final DateTime Function() _clock;
  final Map<String, PiecePriorityStrategyProfile> _profilesById;
  bool _disposed = false;

  List<PiecePriorityStrategyProfile> get profiles =>
      List<PiecePriorityStrategyProfile>.unmodifiable(_profilesById.values);

  Future<void> dispose() async {
    _disposed = true;
  }

  Future<PiecePriorityProfileSelectionOutcome> selectProfile({
    required BtTaskId taskId,
    required VirtualMediaStreamId streamId,
    required String profileId,
  }) async {
    final PiecePriorityRuntimeFailure? disposed = _disposedFailure();
    if (disposed != null) {
      return PiecePriorityProfileSelectionOutcome.failure(failure: disposed);
    }
    final PiecePriorityStrategyProfile? profile = _profilesById[profileId];
    if (profile == null) {
      return const PiecePriorityProfileSelectionOutcome.failure(
        failure: PiecePriorityRuntimeFailure(
          kind: PiecePriorityRuntimeFailureKind.unsupportedProfile,
          message: 'Strategy profile is not registered.',
        ),
      );
    }
    final DateTime now = _clock();
    await schedulerStore.storeProfile(_storedProfile(profile, now));
    await schedulerStore
        .setActiveProfile(StoredActivePiecePriorityProfileRecord(
      taskId: taskId.value,
      streamId: streamId.value,
      profileId: profile.id,
      selectedAt: now,
    ));
    cacheInvalidationBus?.publish(PiecePriorityProfileChanged(
      occurredAt: now,
      taskId: taskId.value,
      streamId: streamId.value,
      profileId: profile.id,
    ));
    return PiecePriorityProfileSelectionOutcome.success(profile: profile);
  }

  @override
  Future<PiecePriorityPlanOutcome> plan(
      PiecePriorityPlanRequest request) async {
    final PiecePriorityPlanFailure? preflight = await _planPreflight(request);
    if (preflight != null) {
      await _recordPlanningFailure(request, preflight);
      return PiecePriorityPlanOutcome.failure(failure: preflight);
    }
    final DeterministicPiecePriorityScheduler scheduler =
        DeterministicPiecePriorityScheduler(
      btTaskStore: btTaskStore,
      streamStore: streamStore,
      schedulerStore: schedulerStore,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: _clock,
    );
    return scheduler.plan(request);
  }

  Future<PiecePriorityPlanOutcome> planWithProfileId({
    required BtTaskId taskId,
    required VirtualMediaStreamId streamId,
    required String profileId,
    PlaybackWindow? playbackWindow,
    SeekTarget? seekTarget,
  }) async {
    final PiecePriorityStrategyProfile? profile = _profilesById[profileId];
    if (profile == null) {
      final PiecePriorityPlanRequest request = PiecePriorityPlanRequest(
        taskId: taskId,
        streamId: streamId,
        profile: balancedProfile,
        playbackWindow: playbackWindow,
        seekTarget: seekTarget,
      );
      final PiecePriorityPlanFailure failure = PiecePriorityPlanFailure(
        kind: PiecePriorityPlanFailureKind.unsupportedProfile,
        message: 'Strategy profile $profileId is not registered.',
      );
      await _recordPlanningFailure(request, failure);
      return PiecePriorityPlanOutcome.failure(failure: failure);
    }
    return plan(PiecePriorityPlanRequest(
      taskId: taskId,
      streamId: streamId,
      profile: profile,
      playbackWindow: playbackWindow,
      seekTarget: seekTarget,
    ));
  }

  Future<PiecePriorityPlanLookupOutcome> lookupPlan(
      PiecePriorityPlanId planId) async {
    final PiecePriorityRuntimeFailure? disposed = _disposedFailure();
    if (disposed != null) {
      return PiecePriorityPlanLookupOutcome.failure(failure: disposed);
    }
    final StoredPiecePriorityPlanRecord? record =
        await schedulerStore.findPlanById(planId.value);
    if (record == null) {
      return const PiecePriorityPlanLookupOutcome.failure(
        failure: PiecePriorityRuntimeFailure(
          kind: PiecePriorityRuntimeFailureKind.planNotFound,
          message: 'Piece priority plan was not found.',
        ),
      );
    }
    return PiecePriorityPlanLookupOutcome.success(
      plan: await _planFromRecord(record),
    );
  }

  Future<PiecePriorityApplicationOutcome> applyPlan({
    required PiecePriorityPlanId planId,
    PiecePriorityPlanApplier? applier,
    bool requireLatest = true,
  }) async {
    if (_disposed) {
      return const PiecePriorityApplicationOutcome.unavailable(
        failure: PiecePriorityApplicationFailure(
          kind: PiecePriorityApplicationFailureKind.disposed,
          message: 'Piece priority scheduler runtime is disposed.',
        ),
      );
    }
    final StoredPiecePriorityPlanRecord? plan =
        await schedulerStore.findPlanById(planId.value);
    if (plan == null) {
      return DeterministicPiecePriorityPlanApplicationRecorder(
        schedulerStore: schedulerStore,
        cacheInvalidationBus: cacheInvalidationBus,
        clock: _clock,
      ).applyAndRecord(planId: planId, applier: applier ?? planApplier);
    }
    if (requireLatest) {
      final StoredPiecePriorityPlanRecord? latest =
          await schedulerStore.latestPlanForStream(
        taskId: plan.taskId,
        streamId: plan.streamId,
      );
      if (latest != null && latest.id != plan.id) {
        return _recordStaleApplication(plan);
      }
    }
    return DeterministicPiecePriorityPlanApplicationRecorder(
      schedulerStore: schedulerStore,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: _clock,
    ).applyAndRecord(planId: planId, applier: applier ?? planApplier);
  }

  Future<PiecePrioritySnapshotOutcome> snapshot({
    required BtTaskId taskId,
    required VirtualMediaStreamId streamId,
  }) async {
    final PiecePriorityRuntimeFailure? disposed = _disposedFailure();
    if (disposed != null) {
      return PiecePrioritySnapshotOutcome.failure(failure: disposed);
    }
    final StoredActivePiecePriorityProfileRecord? active =
        await schedulerStore.activeProfile(
      taskId: taskId.value,
      streamId: streamId.value,
    );
    final StoredPiecePriorityPlanRecord? latest =
        await schedulerStore.latestPlanForStream(
      taskId: taskId.value,
      streamId: streamId.value,
      profileId: active?.profileId,
    );
    final List<StoredPiecePriorityPlanRuleRecord> rules = latest == null
        ? const <StoredPiecePriorityPlanRuleRecord>[]
        : await schedulerStore.rulesForPlan(latest.id);
    final StoredPiecePriorityPlanApplicationEventRecord? application =
        latest == null
            ? null
            : await schedulerStore.latestApplicationEvent(latest.id);
    final StoredPiecePriorityPlanningFailureRecord? planningFailure =
        await schedulerStore.latestPlanningFailure(
      taskId: taskId.value,
      streamId: streamId.value,
    );
    final StoredPiecePriorityStrategyProfileRecord? profile = active == null
        ? null
        : await schedulerStore.findProfileById(active.profileId);
    return PiecePrioritySnapshotOutcome.success(
      snapshot: PiecePrioritySchedulerSnapshot(
        taskId: taskId.value,
        streamId: streamId.value,
        activeProfile: active == null || profile == null
            ? null
            : PiecePriorityProfileProjection(
                profileId: active.profileId,
                displayName: profile.displayName,
                selectedAt: active.selectedAt,
              ),
        latestPlan: latest == null
            ? null
            : PiecePriorityGeneratedPlanSummary.fromStored(latest),
        orderedRules: <PiecePriorityRuleProjection>[
          for (final StoredPiecePriorityPlanRuleRecord rule in rules)
            PiecePriorityRuleProjection.fromStored(
              rule,
              pieceLengthBytes: latest!.pieceLengthBytes,
            ),
        ],
        latestApplicationOutcome: application == null
            ? null
            : PiecePriorityApplicationProjection.fromStored(application),
        latestPlanningFailure: planningFailure == null
            ? null
            : PiecePriorityPlanningFailureProjection.fromStored(
                planningFailure),
        restartVisible: active != null || latest != null || application != null,
      ),
    );
  }

  Future<PiecePriorityPlanFailure?> _planPreflight(
      PiecePriorityPlanRequest request) async {
    if (_disposed) {
      return const PiecePriorityPlanFailure(
        kind: PiecePriorityPlanFailureKind.disposed,
        message: 'Piece priority scheduler runtime is disposed.',
      );
    }
    if (!_profilesById.containsKey(request.profile.id)) {
      return PiecePriorityPlanFailure(
        kind: PiecePriorityPlanFailureKind.unsupportedProfile,
        message: 'Strategy profile ${request.profile.id} is not registered.',
      );
    }
    final StoredVirtualMediaStreamRecord? stream =
        await streamStore.findStreamById(request.streamId.value);
    if (stream != null &&
        stream.taskId == request.taskId.value &&
        stream.lifecycleState ==
            StoredVirtualMediaStreamLifecycleState.failed) {
      return PiecePriorityPlanFailure(
        kind: PiecePriorityPlanFailureKind.streamFailed,
        message: stream.message ??
            'Virtual stream ${request.streamId.value} failed.',
      );
    }
    return null;
  }

  PiecePriorityRuntimeFailure? _disposedFailure() {
    if (!_disposed) {
      return null;
    }
    return const PiecePriorityRuntimeFailure(
      kind: PiecePriorityRuntimeFailureKind.disposed,
      message: 'Piece priority scheduler runtime is disposed.',
    );
  }

  Future<void> _recordPlanningFailure(
    PiecePriorityPlanRequest request,
    PiecePriorityPlanFailure failure,
  ) async {
    final DateTime now = _clock();
    await schedulerStore.recordPlanningFailure(
      StoredPiecePriorityPlanningFailureRecord(
        taskId: request.taskId.value,
        streamId: request.streamId.value,
        profileId: request.profile.id,
        failureKind: failure.kind.name,
        message: failure.message,
        occurredAt: now,
      ),
    );
    cacheInvalidationBus?.publish(PiecePriorityPlanRejected(
      occurredAt: now,
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      planId: '${request.taskId.value}::${request.streamId.value}::rejected',
      profileId: request.profile.id,
      failureKind: failure.kind.name,
    ));
  }

  Future<PiecePriorityPlan> _planFromRecord(
      StoredPiecePriorityPlanRecord record) async {
    final List<StoredPiecePriorityPlanRuleRecord> rules =
        await schedulerStore.rulesForPlan(record.id);
    return PiecePriorityPlan(
      id: PiecePriorityPlanId(record.id),
      taskId: BtTaskId(record.taskId),
      streamId: VirtualMediaStreamId(record.streamId),
      fileIndex: BtFileIndex(record.fileIndex),
      profileId: record.profileId,
      generatedAt: record.generatedAt,
      rules: <PiecePriorityRule>[
        for (final StoredPiecePriorityPlanRuleRecord rule in rules)
          PiecePriorityRule(
            pieceIndex: BtPieceIndex(rule.pieceIndex),
            priority: _priorityFromName(rule.priority),
            reason: _reasonFromName(rule.reason),
            deadline: rule.deadlineMillis == null
                ? null
                : Duration(milliseconds: rule.deadlineMillis!),
          ),
      ],
    );
  }

  Future<PiecePriorityApplicationOutcome> _recordStaleApplication(
      StoredPiecePriorityPlanRecord plan) async {
    final DateTime now = _clock();
    const PiecePriorityApplicationFailure failure =
        PiecePriorityApplicationFailure(
      kind: PiecePriorityApplicationFailureKind.stalePlan,
      message: 'Piece priority plan is stale for the stream.',
    );
    await schedulerStore.recordApplicationEvent(
      StoredPiecePriorityPlanApplicationEventRecord(
        planId: plan.id,
        taskId: plan.taskId,
        streamId: plan.streamId,
        profileId: plan.profileId,
        outcome: StoredPiecePriorityApplicationOutcomeKind.rejected,
        occurredAt: now,
        failureKind: failure.kind.name,
        message: failure.message,
      ),
    );
    cacheInvalidationBus?.publish(PiecePriorityPlanRejected(
      occurredAt: now,
      taskId: plan.taskId,
      streamId: plan.streamId,
      planId: plan.id,
      profileId: plan.profileId,
      failureKind: failure.kind.name,
    ));
    return const PiecePriorityApplicationOutcome.rejected(failure: failure);
  }
}

final class PiecePrioritySchedulerSnapshot {
  PiecePrioritySchedulerSnapshot({
    required this.taskId,
    required this.streamId,
    required this.activeProfile,
    required this.latestPlan,
    required Iterable<PiecePriorityRuleProjection> orderedRules,
    required this.latestApplicationOutcome,
    required this.latestPlanningFailure,
    required this.restartVisible,
  }) : orderedRules = UnmodifiableListView<PiecePriorityRuleProjection>(
            <PiecePriorityRuleProjection>[...orderedRules]);

  final String taskId;
  final String streamId;
  final PiecePriorityProfileProjection? activeProfile;
  final PiecePriorityGeneratedPlanSummary? latestPlan;
  final UnmodifiableListView<PiecePriorityRuleProjection> orderedRules;
  final PiecePriorityApplicationProjection? latestApplicationOutcome;
  final PiecePriorityPlanningFailureProjection? latestPlanningFailure;
  final bool restartVisible;
}

final class PiecePriorityProfileProjection {
  const PiecePriorityProfileProjection({
    required this.profileId,
    required this.displayName,
    required this.selectedAt,
  });

  final String profileId;
  final String displayName;
  final DateTime selectedAt;
}

final class PiecePriorityGeneratedPlanSummary {
  const PiecePriorityGeneratedPlanSummary({
    required this.planId,
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
  });

  factory PiecePriorityGeneratedPlanSummary.fromStored(
      StoredPiecePriorityPlanRecord record) {
    return PiecePriorityGeneratedPlanSummary(
      planId: record.id,
      taskId: record.taskId,
      streamId: record.streamId,
      fileIndex: record.fileIndex,
      profileId: record.profileId,
      metadataInfoHash: record.metadataInfoHash,
      pieceLengthBytes: record.pieceLengthBytes,
      playbackStartByte: record.playbackStartByte,
      playbackEndByte: record.playbackEndByte,
      seekTargetByte: record.seekTargetByte,
      generatedAt: record.generatedAt,
    );
  }

  final String planId;
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

final class PiecePriorityRuleProjection {
  const PiecePriorityRuleProjection({
    required this.planId,
    required this.pieceIndex,
    required this.priority,
    required this.reason,
    required this.order,
    required this.startByte,
    required this.endByteInclusive,
    this.deadline,
  });

  factory PiecePriorityRuleProjection.fromStored(
    StoredPiecePriorityPlanRuleRecord record, {
    required int pieceLengthBytes,
  }) {
    return PiecePriorityRuleProjection(
      planId: record.planId,
      pieceIndex: record.pieceIndex,
      priority: record.priority,
      reason: record.reason,
      order: record.order,
      startByte: record.pieceIndex * pieceLengthBytes,
      endByteInclusive: ((record.pieceIndex + 1) * pieceLengthBytes) - 1,
      deadline: record.deadlineMillis == null
          ? null
          : Duration(milliseconds: record.deadlineMillis!),
    );
  }

  final String planId;
  final int pieceIndex;
  final String priority;
  final String reason;
  final int order;
  final int startByte;
  final int endByteInclusive;
  final Duration? deadline;
}

final class PiecePriorityApplicationProjection {
  const PiecePriorityApplicationProjection({
    required this.planId,
    required this.taskId,
    required this.streamId,
    required this.profileId,
    required this.outcome,
    required this.occurredAt,
    this.failureKind,
    this.message,
  });

  factory PiecePriorityApplicationProjection.fromStored(
      StoredPiecePriorityPlanApplicationEventRecord record) {
    return PiecePriorityApplicationProjection(
      planId: record.planId,
      taskId: record.taskId,
      streamId: record.streamId,
      profileId: record.profileId,
      outcome: record.outcome.name,
      failureKind: record.failureKind,
      message: record.message,
      occurredAt: record.occurredAt,
    );
  }

  final String planId;
  final String taskId;
  final String streamId;
  final String profileId;
  final String outcome;
  final String? failureKind;
  final String? message;
  final DateTime occurredAt;
}

final class PiecePriorityPlanningFailureProjection {
  const PiecePriorityPlanningFailureProjection({
    required this.taskId,
    required this.streamId,
    required this.profileId,
    required this.failureKind,
    required this.message,
    required this.occurredAt,
  });

  factory PiecePriorityPlanningFailureProjection.fromStored(
      StoredPiecePriorityPlanningFailureRecord record) {
    return PiecePriorityPlanningFailureProjection(
      taskId: record.taskId,
      streamId: record.streamId,
      profileId: record.profileId,
      failureKind: record.failureKind,
      message: record.message,
      occurredAt: record.occurredAt,
    );
  }

  final String taskId;
  final String streamId;
  final String profileId;
  final String failureKind;
  final String message;
  final DateTime occurredAt;
}

DateTime _defaultClock() => DateTime.now().toUtc();

StoredPiecePriorityStrategyProfileRecord _storedProfile(
  PiecePriorityStrategyProfile profile,
  DateTime now,
) {
  return StoredPiecePriorityStrategyProfileRecord(
    id: profile.id,
    displayName: profile.displayName ?? profile.id,
    firstPiecePriority: profile.firstPiecePriority.name,
    tailPiecePriority: profile.tailPiecePriority.name,
    playbackWindowPriority: profile.playbackWindowPriority.name,
    seekTargetPriority: profile.seekTargetPriority.name,
    staleWindowPriority: profile.staleWindowPriority.name,
    lookaheadBytes: profile.lookaheadBytes,
    seekLookaheadBytes: profile.seekLookaheadBytes ?? profile.lookaheadBytes,
    edgePieceCount: profile.edgePieceCount,
    createdAt: now,
    updatedAt: now,
  );
}

DownloadPriority _priorityFromName(String name) {
  for (final DownloadPriority priority in DownloadPriority.values) {
    if (priority.name == name) {
      return priority;
    }
  }
  return DownloadPriority.normal;
}

PiecePriorityRuleReason _reasonFromName(String name) {
  for (final PiecePriorityRuleReason reason in PiecePriorityRuleReason.values) {
    if (reason.name == name) {
      return reason;
    }
  }
  return PiecePriorityRuleReason.playbackWindow;
}
