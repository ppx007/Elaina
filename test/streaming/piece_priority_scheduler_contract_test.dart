import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduler store persists profiles plans rules and application events',
      () async {
    final DeterministicPiecePrioritySchedulerStore store =
        DeterministicPiecePrioritySchedulerStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);

    await store.storeProfile(_storedProfile(observedAt));
    await store.setActiveProfile(StoredActivePiecePriorityProfileRecord(
      taskId: 'task-1',
      streamId: 'stream-1',
      profileId: 'balanced',
      selectedAt: observedAt,
    ));
    await store.storePlan(StoredPiecePriorityPlanRecord(
      id: 'plan-1',
      taskId: 'task-1',
      streamId: 'stream-1',
      fileIndex: 0,
      profileId: 'balanced',
      pieceLengthBytes: 1024,
      generatedAt: observedAt,
    ));
    await store.storePlanRules(
      planId: 'plan-1',
      rules: const <StoredPiecePriorityPlanRuleRecord>[
        StoredPiecePriorityPlanRuleRecord(
          planId: 'plan-1',
          pieceIndex: 1,
          priority: 'high',
          reason: 'playbackWindow',
          order: 1,
        ),
        StoredPiecePriorityPlanRuleRecord(
          planId: 'plan-1',
          pieceIndex: 0,
          priority: 'critical',
          reason: 'firstPiece',
          order: 0,
        ),
      ],
    );
    await store.recordApplicationEvent(
      StoredPiecePriorityPlanApplicationEventRecord(
        planId: 'plan-1',
        taskId: 'task-1',
        streamId: 'stream-1',
        profileId: 'balanced',
        outcome: StoredPiecePriorityApplicationOutcomeKind.accepted,
        occurredAt: observedAt,
      ),
    );

    expect((await store.findProfileById('balanced'))?.lookaheadBytes, 2048);
    expect(
        (await store.activeProfile(taskId: 'task-1', streamId: 'stream-1'))
            ?.profileId,
        'balanced');
    expect(
        (await store.latestPlanForStream(
                taskId: 'task-1', streamId: 'stream-1'))
            ?.id,
        'plan-1');
    expect((await store.rulesForPlan('plan-1')).first.pieceIndex, 0);
    expect((await store.latestApplicationEvent('plan-1'))?.outcome,
        StoredPiecePriorityApplicationOutcomeKind.accepted);
  });

  test('derives file piece maps from persisted BT file metadata', () {
    final FilePieceMap map = deriveFilePieceMap(
      file: const StoredBtTaskFileRecord(
        taskId: 'task-1',
        index: 1,
        path: 'Episode 2.mkv',
        lengthBytes: 2048,
        offsetBytes: 1024,
        selectionState: StoredBtFileSelectionState.selected,
      ),
      pieceLengthBytes: 1024,
    );

    expect(map.fileIndex.value, 1);
    expect(map.fileRange.start, 1024);
    expect(map.fileRange.endInclusive, 3071);
    expect(map.pieceSpan.first.value, 1);
    expect(map.pieceSpan.last.value, 2);
  });

  test('scheduler generates playback and seek priority plans', () async {
    final _SchedulerHarness harness = await _harness();
    final Future<List<CacheInvalidationEvent>> events =
        harness.bus.events.take(2).toList();

    final PiecePriorityPlanOutcome outcome = await harness.scheduler.plan(
      PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'),
        streamId: const VirtualMediaStreamId('task-1::1'),
        profile: _profile(),
        playbackWindow: const PlaybackWindow(
          streamId: VirtualMediaStreamId('task-1::1'),
          currentByteOffset: 0,
          lookaheadBytes: 2048,
        ),
        seekTarget: const SeekTarget(
          streamId: VirtualMediaStreamId('task-1::1'),
          targetByteOffset: 3072,
          deadline: Duration(seconds: 2),
        ),
      ),
    );
    final List<CacheInvalidationEvent> delivered = await events;

    expect(outcome.isSuccess, isTrue);
    expect(
        outcome.plan?.rules
            .map((PiecePriorityRule rule) => rule.pieceIndex.value),
        containsAll(<int>[1, 2, 4]));
    expect(
        outcome.plan?.rules
            .where((PiecePriorityRule rule) =>
                rule.reason == PiecePriorityRuleReason.seekTarget)
            .single
            .priority,
        DownloadPriority.critical);
    expect(
        (await harness.schedulerStore.rulesForPlan(outcome.plan!.id.value))
            .isNotEmpty,
        isTrue);
    expect(delivered.whereType<PiecePriorityProfileChanged>().length, 1);
    expect(delivered.whereType<PiecePriorityPlanGenerated>().length, 1);
    await harness.bus.close();
  });

  test('scheduler avoids fully buffered pieces', () async {
    final _SchedulerHarness harness = await _harness(bufferedRangeEnd: 1023);

    final PiecePriorityPlanOutcome outcome = await harness.scheduler.plan(
      PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'),
        streamId: const VirtualMediaStreamId('task-1::1'),
        profile: _profile(),
        playbackWindow: const PlaybackWindow(
          streamId: VirtualMediaStreamId('task-1::1'),
          currentByteOffset: 0,
          lookaheadBytes: 2048,
        ),
      ),
    );

    expect(outcome.isSuccess, isTrue);
    expect(
        outcome.plan?.rules
            .map((PiecePriorityRule rule) => rule.pieceIndex.value),
        isNot(contains(1)));
    await harness.bus.close();
  });

  test('scheduler rejects missing metadata with typed failure', () async {
    final DeterministicBtTaskStore btStore = DeterministicBtTaskStore();
    final DeterministicVirtualMediaStreamStore streamStore =
        DeterministicVirtualMediaStreamStore();
    await streamStore.storeStream(_streamRecord());
    final DeterministicPiecePriorityScheduler scheduler =
        DeterministicPiecePriorityScheduler(
      btTaskStore: btStore,
      streamStore: streamStore,
      schedulerStore: DeterministicPiecePrioritySchedulerStore(),
    );

    final PiecePriorityPlanOutcome outcome = await scheduler.plan(
      PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'),
        streamId: const VirtualMediaStreamId('task-1::1'),
        profile: _profile(),
      ),
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind,
        PiecePriorityPlanFailureKind.metadataUnavailable);
  });

  test('plan recorder persists accepted and rejected application events',
      () async {
    final _SchedulerHarness harness = await _harness();
    final PiecePriorityPlanOutcome planned = await harness.scheduler.plan(
      PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'),
        streamId: const VirtualMediaStreamId('task-1::1'),
        profile: _profile(),
        playbackWindow: const PlaybackWindow(
          streamId: VirtualMediaStreamId('task-1::1'),
          currentByteOffset: 0,
          lookaheadBytes: 1024,
        ),
      ),
    );
    final DeterministicPiecePriorityPlanApplicationRecorder recorder =
        DeterministicPiecePriorityPlanApplicationRecorder(
      schedulerStore: harness.schedulerStore,
      cacheInvalidationBus: harness.bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    );
    final Future<List<CacheInvalidationEvent>> events =
        harness.bus.events.take(2).toList();

    final PiecePriorityApplicationOutcome accepted =
        await recorder.applyAndRecord(
      planId: planned.plan!.id,
      applier: const _AcceptingApplier(),
    );
    final PiecePriorityApplicationOutcome rejected =
        await recorder.applyAndRecord(
      planId: planned.plan!.id,
      applier: const _RejectingApplier(),
    );
    final List<CacheInvalidationEvent> delivered = await events;

    expect(accepted.isSuccess, isTrue);
    expect(rejected.isSuccess, isFalse);
    expect(
        (await harness.schedulerStore
                .latestApplicationEvent(planned.plan!.id.value))
            ?.outcome,
        StoredPiecePriorityApplicationOutcomeKind.rejected);
    expect(delivered.whereType<PiecePriorityPlanApplied>().length, 1);
    expect(delivered.whereType<PiecePriorityPlanRejected>().length, 1);
    await harness.bus.close();
  });
}

final class _SchedulerHarness {
  const _SchedulerHarness({
    required this.scheduler,
    required this.schedulerStore,
    required this.bus,
  });

  final DeterministicPiecePriorityScheduler scheduler;
  final DeterministicPiecePrioritySchedulerStore schedulerStore;
  final StreamCacheInvalidationBus bus;
}

Future<_SchedulerHarness> _harness({int? bufferedRangeEnd}) async {
  final DeterministicBtTaskStore btStore = DeterministicBtTaskStore();
  final DeterministicVirtualMediaStreamStore streamStore =
      DeterministicVirtualMediaStreamStore();
  final DeterministicPiecePrioritySchedulerStore schedulerStore =
      DeterministicPiecePrioritySchedulerStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  await btStore.storeTask(_taskRecord());
  await btStore.storeMetadata(
    const StoredBtTaskMetadataRecord(
      taskId: 'task-1',
      infoHash: 'abc',
      name: 'Episode Pack',
      totalSizeBytes: 6144,
      pieceLengthBytes: 1024,
    ),
  );
  await btStore.storeFiles(
    taskId: 'task-1',
    files: const <StoredBtTaskFileRecord>[
      StoredBtTaskFileRecord(
        taskId: 'task-1',
        index: 1,
        path: 'Episode 2.mkv',
        lengthBytes: 4096,
        offsetBytes: 1024,
        selectionState: StoredBtFileSelectionState.streamingTarget,
      ),
    ],
  );
  await streamStore.storeStream(_streamRecord());
  if (bufferedRangeEnd != null) {
    await streamStore.recordBufferedRange(
      StoredVirtualStreamBufferedRangeRecord(
        streamId: 'task-1::1',
        startByte: 0,
        endByte: bufferedRangeEnd,
        observedAt: DateTime.utc(2026, 6, 5, 12),
      ),
    );
  }
  return _SchedulerHarness(
    scheduler: DeterministicPiecePriorityScheduler(
      btTaskStore: btStore,
      streamStore: streamStore,
      schedulerStore: schedulerStore,
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 5, 12),
    ),
    schedulerStore: schedulerStore,
    bus: bus,
  );
}

PiecePriorityStrategyProfile _profile() {
  return const PiecePriorityStrategyProfile(
    id: 'balanced',
    displayName: 'Balanced',
    firstPiecePriority: DownloadPriority.critical,
    tailPiecePriority: DownloadPriority.high,
    playbackWindowPriority: DownloadPriority.high,
    seekTargetPriority: DownloadPriority.critical,
    staleWindowPriority: DownloadPriority.low,
    lookaheadBytes: 2048,
    seekLookaheadBytes: 1024,
    edgePieceCount: 1,
  );
}

StoredPiecePriorityStrategyProfileRecord _storedProfile(DateTime observedAt) {
  return StoredPiecePriorityStrategyProfileRecord(
    id: 'balanced',
    displayName: 'Balanced',
    firstPiecePriority: 'critical',
    tailPiecePriority: 'high',
    playbackWindowPriority: 'high',
    seekTargetPriority: 'critical',
    staleWindowPriority: 'low',
    lookaheadBytes: 2048,
    seekLookaheadBytes: 1024,
    edgePieceCount: 1,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}

StoredBtTaskRecord _taskRecord() {
  final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
  return StoredBtTaskRecord(
    id: 'task-1',
    sourceKind: StoredBtTaskSourceKind.magnet,
    sourceUri: 'magnet:?xt=urn:btih:abc',
    lifecycleState: StoredBtTaskLifecycleState.ready,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}

StoredVirtualMediaStreamRecord _streamRecord() {
  final DateTime observedAt = DateTime.utc(2026, 6, 5, 12);
  return StoredVirtualMediaStreamRecord(
    id: 'task-1::1',
    taskId: 'task-1',
    fileIndex: 1,
    lengthBytes: 4096,
    lifecycleState: StoredVirtualMediaStreamLifecycleState.active,
    createdAt: observedAt,
    updatedAt: observedAt,
  );
}

final class _AcceptingApplier implements PiecePriorityPlanApplier {
  const _AcceptingApplier();

  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) {
    return Future<PiecePriorityApplicationOutcome>.value(
        const PiecePriorityApplicationOutcome.accepted());
  }
}

final class _RejectingApplier implements PiecePriorityPlanApplier {
  const _RejectingApplier();

  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) {
    return Future<PiecePriorityApplicationOutcome>.value(
      const PiecePriorityApplicationOutcome.rejected(
        failure: PiecePriorityApplicationFailure(
          kind: PiecePriorityApplicationFailureKind.adapterRejected,
          message: 'Adapter rejected plan.',
        ),
      ),
    );
  }
}
