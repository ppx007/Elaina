import '../lib/celesteria.dart';

Future<void> main() async {
  await verifyPiecePrioritySchedulerRuntimeContract();
}

Future<void> verifyPiecePrioritySchedulerRuntimeContract() async {
  final DeterministicBtTaskStore btTaskStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore virtualMediaStreamStore =
      DeterministicVirtualMediaStreamStore();
  final DeterministicPiecePrioritySchedulerStore schedulerStore =
      DeterministicPiecePrioritySchedulerStore();
  final StreamCacheInvalidationBus cacheInvalidationBus =
      StreamCacheInvalidationBus();

  // Seed a BT task with one streaming file for all checks.
  final DateTime now = _now();
  await btTaskStore.storeTask(StoredBtTaskRecord(
    id: 'c-task-1',
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:ctask1',
    lifecycleState: StoredBtTaskLifecycleState.ready,
    createdAt: now,
    updatedAt: now,
  ));
  await btTaskStore.storeMetadata(const StoredBtTaskMetadataRecord(
    taskId: 'c-task-1',
    infoHash: 'c-hash-1',
    name: 'C Pack',
    totalSizeBytes: 6144,
    pieceLengthBytes: 1024,
  ));
  await btTaskStore.storeFiles(
    taskId: 'c-task-1',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'c-task-1',
        index: 1,
        path: 'C1.mkv',
        lengthBytes: 4096,
        offsetBytes: 1024,
        selectionState: StoredBtFileSelectionState.streamingTarget,
      ),
    ],
  );
  await virtualMediaStreamStore.storeStream(StoredVirtualMediaStreamRecord(
    id: 'c-task-1::1',
    taskId: 'c-task-1',
    fileIndex: 1,
    lengthBytes: 4096,
    lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
    createdAt: now,
    updatedAt: now,
  ));

  // 1. Creation/bootstrap via PiecePrioritySchedulerBootstrap
  final PiecePrioritySchedulerBootstrap bootstrap =
      PiecePrioritySchedulerBootstrap(
    btTaskStore: btTaskStore,
    streamStore: virtualMediaStreamStore,
    schedulerStore: schedulerStore,
    cacheInvalidationBus: cacheInvalidationBus,
    profiles: <PiecePriorityStrategyProfile>[
      PiecePrioritySchedulerRuntime.balancedProfile,
    ],
    clock: _now,
  );
  _expect(bootstrap.profiles.length == 1,
      'Bootstrap must expose the default balanced profile.');
  final PiecePrioritySchedulerRuntime runtime = bootstrap.createRuntime();
  _expect(runtime.profiles.length == 1,
      'Runtime must expose the default balanced profile after bootstrap.');

  // 2. Plan generation from persisted state
  final Future<List<CacheInvalidationEvent>> planEvents =
      cacheInvalidationBus.events.take(2).toList();
  final PiecePriorityPlanOutcome planOutcome = await runtime.plan(
    PiecePriorityPlanRequest(
      taskId: const BtTaskId('c-task-1'),
      streamId: const VirtualMediaStreamId('c-task-1::1'),
      profile: PiecePrioritySchedulerRuntime.balancedProfile,
      playbackWindow: const PlaybackWindow(
        streamId: VirtualMediaStreamId('c-task-1::1'),
        currentByteOffset: 0,
        lookaheadBytes: 2048,
      ),
      seekTarget: const SeekTarget(
        streamId: VirtualMediaStreamId('c-task-1::1'),
        targetByteOffset: 3072,
        deadline: Duration(seconds: 2),
      ),
    ),
  );
  _expect(planOutcome.isSuccess, 'Runtime plan must succeed.');
  _expect(planOutcome.plan!.rules.isNotEmpty,
      'Runtime plan must produce priority rules.');
  final PiecePriorityRule seekRule = planOutcome.plan!.rules
      .where((PiecePriorityRule r) =>
          r.reason == PiecePriorityRuleReason.seekTarget)
      .single;
  _expect(seekRule.priority == DownloadPriority.critical,
      'Runtime plan must mark seek target pieces as critical priority.');
  final List<CacheInvalidationEvent> planDelivered = await planEvents;
  _expect(planDelivered.whereType<PiecePriorityProfileChanged>().length == 1,
      'Runtime plan must publish a profile-changed invalidation.');
  _expect(planDelivered.whereType<PiecePriorityPlanGenerated>().length == 1,
      'Runtime plan must publish a plan-generated invalidation.');

  // 3. Buffered-piece avoidance
  final DeterministicVirtualMediaStreamStore bufferedStreamStore =
      DeterministicVirtualMediaStreamStore();
  await bufferedStreamStore.storeStream(StoredVirtualMediaStreamRecord(
    id: 'c-task-1::1',
    taskId: 'c-task-1',
    fileIndex: 1,
    lengthBytes: 4096,
    lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
    createdAt: now,
    updatedAt: now,
  ));
  await bufferedStreamStore.recordBufferedRange(
    StoredVirtualStreamBufferedRangeRecord(
      streamId: 'c-task-1::1',
      startByte: 0,
      endByte: 1023,
      observedAt: now,
    ),
  );
  final PiecePrioritySchedulerRuntime bufferedRuntime =
      PiecePrioritySchedulerRuntime(
    btTaskStore: btTaskStore,
    streamStore: bufferedStreamStore,
    schedulerStore: DeterministicPiecePrioritySchedulerStore(),
    cacheInvalidationBus: StreamCacheInvalidationBus(),
    profiles: <PiecePriorityStrategyProfile>[
      PiecePrioritySchedulerRuntime.balancedProfile,
    ],
    clock: _now,
  );
  final PiecePriorityPlanOutcome bufferedOutcome = await bufferedRuntime.plan(
    PiecePriorityPlanRequest(
      taskId: const BtTaskId('c-task-1'),
      streamId: const VirtualMediaStreamId('c-task-1::1'),
      profile: PiecePrioritySchedulerRuntime.balancedProfile,
      playbackWindow: const PlaybackWindow(
        streamId: VirtualMediaStreamId('c-task-1::1'),
        currentByteOffset: 0,
        lookaheadBytes: 2048,
      ),
    ),
  );
  _expect(bufferedOutcome.isSuccess, 'Buffered plan must succeed.');
  final List<int> bufferedPieceIndexes = bufferedOutcome.plan!.rules
      .map((PiecePriorityRule r) => r.pieceIndex.value)
      .toList();
  _expect(!bufferedPieceIndexes.contains(1),
      'Buffered piece 1 must be excluded from the generated plan.');

  // 4. Typed planning failure (metadata unavailable)
  final DeterministicBtTaskStore emptyBtTaskStore =
      DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore emptyStreamStore =
      DeterministicVirtualMediaStreamStore();
  await emptyStreamStore.storeStream(StoredVirtualMediaStreamRecord(
    id: 'c-task-1::1',
    taskId: 'c-task-1',
    fileIndex: 1,
    lengthBytes: 4096,
    lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
    createdAt: now,
    updatedAt: now,
  ));
  final PiecePrioritySchedulerRuntime emptyRuntime =
      PiecePrioritySchedulerRuntime(
    btTaskStore: emptyBtTaskStore,
    streamStore: emptyStreamStore,
    schedulerStore: DeterministicPiecePrioritySchedulerStore(),
    clock: _now,
  );
  final PiecePriorityPlanOutcome missingMetadataOutcome =
      await emptyRuntime.plan(PiecePriorityPlanRequest(
    taskId: const BtTaskId('c-task-1'),
    streamId: const VirtualMediaStreamId('c-task-1::1'),
    profile: PiecePrioritySchedulerRuntime.balancedProfile,
  ));
  _expect(!missingMetadataOutcome.isSuccess,
      'Missing metadata must produce a planning failure.');
  _expect(
      missingMetadataOutcome.failure!.kind ==
          PiecePriorityPlanFailureKind.metadataUnavailable,
      'Missing metadata must surface metadataUnavailable failure kind.');

  // 5. Application recording (accepted, rejected, unavailable)
  final DeterministicPiecePriorityPlanApplicationRecorder recorder =
      DeterministicPiecePriorityPlanApplicationRecorder(
    schedulerStore: schedulerStore,
    cacheInvalidationBus: cacheInvalidationBus,
    clock: _now,
  );
  final Future<List<CacheInvalidationEvent>> acceptedEvents =
      cacheInvalidationBus.events.take(1).toList();
  final PiecePriorityApplicationOutcome acceptedOutcome =
      await recorder.applyAndRecord(
    planId: planOutcome.plan!.id,
    applier: const _AcceptingApplier(),
  );
  _expect(acceptedOutcome.isSuccess, 'Accepted application must succeed.');
  final StoredPiecePriorityPlanApplicationEventRecord? acceptedStored =
      await schedulerStore.latestApplicationEvent(planOutcome.plan!.id.value);
  _expect(
      acceptedStored?.outcome ==
          StoredPiecePriorityApplicationOutcomeKind.accepted,
      'Scheduler store must persist accepted outcome.');
  final List<CacheInvalidationEvent> acceptedDelivered =
      await acceptedEvents;
  _expect(acceptedDelivered.whereType<PiecePriorityPlanApplied>().length == 1,
      'Accepted application must publish a plan-applied invalidation.');

  final PiecePriorityApplicationOutcome rejectedOutcome =
      await recorder.applyAndRecord(
    planId: planOutcome.plan!.id,
    applier: const _RejectingApplier(),
  );
  _expect(!rejectedOutcome.isSuccess,
      'Rejected application must not succeed.');
  final StoredPiecePriorityPlanApplicationEventRecord? rejectedStored =
      await schedulerStore.latestApplicationEvent(planOutcome.plan!.id.value);
  _expect(
      rejectedStored?.outcome ==
          StoredPiecePriorityApplicationOutcomeKind.rejected,
      'Scheduler store must persist rejected outcome.');

  final PiecePriorityApplicationOutcome unavailableOutcome =
      await recorder.applyAndRecord(
    planId: planOutcome.plan!.id,
  );
  _expect(!unavailableOutcome.isSuccess,
      'Unavailable applier must not succeed.');
  _expect(unavailableOutcome.failure!.kind ==
      PiecePriorityApplicationFailureKind.applierUnavailable,
      'Unavailable applier must surface applierUnavailable failure kind.');

  // 6. Restart projection via snapshot
  final PiecePrioritySnapshotOutcome snapshotOutcome = await runtime.snapshot(
    taskId: const BtTaskId('c-task-1'),
    streamId: const VirtualMediaStreamId('c-task-1::1'),
  );
  _expect(snapshotOutcome.isSuccess, 'Snapshot must succeed.');
  _expect(snapshotOutcome.snapshot!.activeProfile != null,
      'Snapshot must project the active profile after plan generation.');
  _expect(snapshotOutcome.snapshot!.activeProfile!.profileId == 'balanced',
      'Snapshot must project the balanced profile id.');
  _expect(snapshotOutcome.snapshot!.latestPlan != null,
      'Snapshot must project the latest plan summary.');
  _expect(snapshotOutcome.snapshot!.orderedRules.isNotEmpty,
      'Snapshot must project ordered priority rules.');
  _expect(snapshotOutcome.snapshot!.restartVisible,
      'Snapshot must be restart-visible after plan generation.');

  // 7. Invalidation ordering: profile-changed before plan-generated
  final StreamCacheInvalidationBus orderingBus =
      StreamCacheInvalidationBus();
  final PiecePrioritySchedulerRuntime orderingRuntime =
      PiecePrioritySchedulerRuntime(
    btTaskStore: btTaskStore,
    streamStore: virtualMediaStreamStore,
    schedulerStore: DeterministicPiecePrioritySchedulerStore(),
    cacheInvalidationBus: orderingBus,
    profiles: <PiecePriorityStrategyProfile>[
      PiecePrioritySchedulerRuntime.balancedProfile,
    ],
    clock: _now,
  );
  final Future<List<CacheInvalidationEvent>> orderingEvents =
      orderingBus.events.take(2).toList();
  await orderingRuntime.plan(PiecePriorityPlanRequest(
    taskId: const BtTaskId('c-task-1'),
    streamId: const VirtualMediaStreamId('c-task-1::1'),
    profile: PiecePrioritySchedulerRuntime.balancedProfile,
  ));
  final List<CacheInvalidationEvent> orderingDelivered =
      await orderingEvents;
  _expect(orderingDelivered.length == 2,
      'Plan must publish exactly two invalidation events.');
  _expect(orderingDelivered[0] is PiecePriorityProfileChanged,
      'First invalidation must be PiecePriorityProfileChanged.');
  _expect(orderingDelivered[1] is PiecePriorityPlanGenerated,
      'Second invalidation must be PiecePriorityPlanGenerated.');

  // 8. Disposed state surfaces typed runtime failures
  await runtime.dispose();
  final PiecePriorityProfileSelectionOutcome disposedProfile =
      await runtime.selectProfile(
    taskId: const BtTaskId('c-task-1'),
    streamId: const VirtualMediaStreamId('c-task-1::1'),
    profileId: 'balanced',
  );
  _expect(!disposedProfile.isSuccess,
      'Disposed runtime must reject profile selection.');
  _expect(disposedProfile.failure!.kind ==
      PiecePriorityRuntimeFailureKind.disposed,
      'Disposed runtime must surface disposed failure kind.');

  final PiecePriorityPlanLookupOutcome disposedLookup =
      await runtime.lookupPlan(planOutcome.plan!.id);
  _expect(!disposedLookup.isSuccess,
      'Disposed runtime must reject plan lookup.');
  _expect(disposedLookup.failure!.kind ==
      PiecePriorityRuntimeFailureKind.disposed,
      'Disposed runtime must surface disposed failure kind on lookup.');

  final PiecePrioritySnapshotOutcome disposedSnapshot = await runtime.snapshot(
    taskId: const BtTaskId('c-task-1'),
    streamId: const VirtualMediaStreamId('c-task-1::1'),
  );
  _expect(!disposedSnapshot.isSuccess,
      'Disposed runtime must reject snapshot.');
  _expect(disposedSnapshot.failure!.kind ==
      PiecePriorityRuntimeFailureKind.disposed,
      'Disposed runtime must surface disposed failure kind on snapshot.');

  await cacheInvalidationBus.close();
  await orderingBus.close();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

DateTime _now() => DateTime.utc(2026, 6, 12, 12);

final class _AcceptingApplier implements PiecePriorityPlanApplier {
  const _AcceptingApplier();

  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) =>
      Future<PiecePriorityApplicationOutcome>.value(
          const PiecePriorityApplicationOutcome.accepted());
}

final class _RejectingApplier implements PiecePriorityPlanApplier {
  const _RejectingApplier();

  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) =>
      Future<PiecePriorityApplicationOutcome>.value(
        const PiecePriorityApplicationOutcome.rejected(
          failure: PiecePriorityApplicationFailure(
            kind: PiecePriorityApplicationFailureKind.adapterRejected,
            message: 'Adapter rejected plan.',
          ),
        ),
      );
}
