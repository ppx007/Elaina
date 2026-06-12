import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// PiecePriorityScheduler Runtime Acceptance Tests (Step 20 / Group A)
// ---------------------------------------------------------------------------

void main() {
  group('Task 1.1 - plan generation from persisted state', () {
    test('full plan from metadata, files, streams, buffers, windows, seeks, profiles', () async {
      final h = await _harness();
      // profileChanged + planGenerated + planRejected (rejected plan from _rejected pathway generates a rejection event)
      final f = h.bus.events.take(2).toList();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'),
        streamId: const VirtualMediaStreamId('task-1::1'),
        profile: _prof(),
        playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 2048),
        seekTarget: const SeekTarget(streamId: VirtualMediaStreamId('task-1::1'), targetByteOffset: 3072, deadline: Duration(seconds: 2)),
      ));
      final d = await f;
      expect(o.isSuccess, isTrue);
      expect(o.plan!.taskId.value, 'task-1');
      expect(o.plan!.streamId.value, 'task-1::1');
      expect(o.plan!.fileIndex.value, 1);
      expect(o.plan!.profileId, 'balanced');
      expect(o.plan!.rules.map((r) => r.pieceIndex.value), containsAll([1,2,4]));
      expect(o.plan!.rules.where((r) => r.reason == PiecePriorityRuleReason.seekTarget).single.priority, DownloadPriority.critical);
      final sp = await h.ss.findPlanById(o.plan!.id.value);
      expect(sp, isNotNull);
      expect(sp!.taskId, 'task-1');
      final sr = await h.ss.rulesForPlan(o.plan!.id.value);
      expect(sr, isNotEmpty);
      expect((await h.ss.activeProfile(taskId: 'task-1', streamId: 'task-1::1'))?.profileId, 'balanced');
      expect(d.whereType<PiecePriorityProfileChanged>().length, 1);
      expect(d.whereType<PiecePriorityPlanGenerated>().length, 1);
      await h.bus.close();
    });

    test('avoids fully buffered pieces', () async {
      final h = await _harness(bufferedRangeEnd: 1023);
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(),
        playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 2048),
      ));
      expect(o.isSuccess, isTrue);
      expect(o.plan!.rules.map((r) => r.pieceIndex.value), isNot(contains(1)));
      await h.bus.close();
    });

    test('seek only', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(),
        seekTarget: const SeekTarget(streamId: VirtualMediaStreamId('task-1::1'), targetByteOffset: 2048, deadline: Duration(seconds: 5)),
      ));
      expect(o.isSuccess, isTrue);
      expect(o.plan!.rules.where((r) => r.reason == PiecePriorityRuleReason.seekTarget).isNotEmpty, isTrue);
      await h.bus.close();
    });

    test('playback only', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(),
        playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 512, lookaheadBytes: 1024),
      ));
      expect(o.isSuccess, isTrue);
      expect(o.plan!.rules.where((r) => r.reason == PiecePriorityRuleReason.playbackWindow).isNotEmpty, isTrue);
      await h.bus.close();
    });

    test('alt profile', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'),
        profile: const PiecePriorityStrategyProfile(id: 'aggressive', displayName: 'Aggressive', firstPiecePriority: DownloadPriority.critical, tailPiecePriority: DownloadPriority.critical, playbackWindowPriority: DownloadPriority.critical, seekTargetPriority: DownloadPriority.critical, staleWindowPriority: DownloadPriority.normal, lookaheadBytes: 4096, seekLookaheadBytes: 2048, edgePieceCount: 2),
      ));
      expect(o.isSuccess, isTrue);
      expect(o.plan!.profileId, 'aggressive');
      expect(o.plan!.rules.every((r) => r.priority == DownloadPriority.critical), isTrue);
      await h.bus.close();
    });

    test('derive file-piece map', () {
      final m = deriveFilePieceMap(file: const StoredBtTaskFileRecord(taskId: 'task-1', index: 2, path: 'E3.mkv', lengthBytes: 3072, offsetBytes: 2048, selectionState: StoredBtFileSelectionState.streamingTarget), pieceLengthBytes: 1024);
      expect(m.fileIndex.value, 2);
      expect(m.fileRange.start, 2048);
      expect(m.fileRange.endInclusive, 5119);
      expect(m.pieceSpan.first.value, 2);
      expect(m.pieceSpan.last.value, 4);
    });

    test('buffered pieces excluded', () async {
      final h = await _harness(bufferedRangeEnd: 2047);
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(
        taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(),
        playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 2048),
      ));
      expect(o.isSuccess, isTrue);
      final p = o.plan!.rules.map((r) => r.pieceIndex.value).toList();
      expect(p, isNot(contains(1)));
      expect(p, isNot(contains(2)));
      expect(p, contains(4));
      await h.bus.close();
    });
  });

  group('Task 1.2 - typed planning failures', () {
    test('metadataUnavailable', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await ss.storeStream(_sr());
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.metadataUnavailable);
    });

    test('fileMapUnavailable when missing', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await ss.storeStream(_sr());
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.fileMapUnavailable);
    });

    test('fileMapUnavailable when skipped', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await bt.storeFiles(taskId: 'task-1', files: const [StoredBtTaskFileRecord(taskId: 'task-1', index: 1, path: 'E2.mkv', lengthBytes: 4096, offsetBytes: 1024, selectionState: StoredBtFileSelectionState.skipped)]);
      await ss.storeStream(_sr());
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.fileMapUnavailable);
    });

    test('streamUnavailable when missing', () async {
      final bt = DeterministicBtTaskStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamUnavailable);
    });

    test('streamUnavailable when taskId mismatch', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await ss.storeStream(StoredVirtualMediaStreamRecord(id: 'task-1::1', taskId: 'task-999', fileIndex: 1, lengthBytes: 4096, lifecycleState: StoredVirtualMediaStreamLifecycleState.active, createdAt: _dt(), updatedAt: _dt()));
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamUnavailable);
    });

    test('streamClosed', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await ss.storeStream(StoredVirtualMediaStreamRecord(id: 'task-1::1', taskId: 'task-1', fileIndex: 1, lengthBytes: 4096, lifecycleState: StoredVirtualMediaStreamLifecycleState.closed, createdAt: _dt(), updatedAt: _dt()));
      final s = DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore());
      final o = await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamClosed);
    });

    test('streamFailed via runtime plan', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await bt.storeFiles(taskId: 'task-1', files: const [StoredBtTaskFileRecord(taskId: 'task-1', index: 1, path: 'E2.mkv', lengthBytes: 4096, offsetBytes: 1024, selectionState: StoredBtFileSelectionState.streamingTarget)]);
      await ss.storeStream(StoredVirtualMediaStreamRecord(id: 'task-1::1', taskId: 'task-1', fileIndex: 1, lengthBytes: 4096, lifecycleState: StoredVirtualMediaStreamLifecycleState.failed, createdAt: _dt(), updatedAt: _dt()));
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore(), profiles: [_prof()], clock: () => _dt());
      final o = await rt.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamFailed);
    });

    test('streamFailed via runtime planWithProfileId', () async {
      final bt = DeterministicBtTaskStore();
      final ss = DeterministicVirtualMediaStreamStore();
      await bt.storeTask(_tr());
      await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await bt.storeFiles(taskId: 'task-1', files: const [StoredBtTaskFileRecord(taskId: 'task-1', index: 1, path: 'E2.mkv', lengthBytes: 4096, offsetBytes: 1024, selectionState: StoredBtFileSelectionState.streamingTarget)]);
      await ss.storeStream(StoredVirtualMediaStreamRecord(id: 'task-1::1', taskId: 'task-1', fileIndex: 1, lengthBytes: 4096, lifecycleState: StoredVirtualMediaStreamLifecycleState.failed, createdAt: _dt(), updatedAt: _dt()));
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: bt, streamStore: ss, schedulerStore: DeterministicPiecePrioritySchedulerStore(), profiles: [_prof()], clock: () => _dt());
      final o = await rt.planWithProfileId(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profileId: 'balanced');
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamFailed);
    });

    test('unsupportedProfile via planWithProfileId', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      // planWithProfileId rejects unknown profile ids through the runtime.
      final o = await rt.planWithProfileId(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profileId: 'nonexistent');
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.unsupportedProfile);
      await h.bus.close();
    });

    test('unsupportedProfile via plan with unregistered profile', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      // plan() with a profile not in the runtime's registry also rejects.
      final o = await rt.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: const PiecePriorityStrategyProfile(id: 'unknown', displayName: 'Unknown', firstPiecePriority: DownloadPriority.critical, tailPiecePriority: DownloadPriority.high, playbackWindowPriority: DownloadPriority.high, seekTargetPriority: DownloadPriority.critical, lookaheadBytes: 2048, edgePieceCount: 1)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.unsupportedProfile);
      await h.bus.close();
    });

    test('rangeOutOfBounds playback', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 4096, lookaheadBytes: 1024)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.rangeOutOfBounds);
      await h.bus.close();
    });

    test('rangeOutOfBounds seek', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), seekTarget: const SeekTarget(streamId: VirtualMediaStreamId('task-1::1'), targetByteOffset: 5000)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.rangeOutOfBounds);
      await h.bus.close();
    });

    test('wrong stream playback window', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::999'), currentByteOffset: 0, lookaheadBytes: 1024)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamUnavailable);
      await h.bus.close();
    });

    test('noSchedulablePieces', () async {
      final h = await _harness(bufferedRangeEnd: 4095);
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 2048)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.noSchedulablePieces);
      await h.bus.close();
    });

    test('wrong seek stream', () async {
      final h = await _harness();
      final o = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), seekTarget: const SeekTarget(streamId: VirtualMediaStreamId('task-1::888'), targetByteOffset: 1024)));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.streamUnavailable);
      await h.bus.close();
    });

    test('publishes rejection on failure', () async {
      final bus = StreamCacheInvalidationBus();
      final s = DeterministicPiecePriorityScheduler(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: DeterministicPiecePrioritySchedulerStore(), cacheInvalidationBus: bus);
      final f = bus.events.take(2).toList();
      await s.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      final d = await f;
      expect(d.whereType<PiecePriorityProfileChanged>().length, 1);
      final r = d.whereType<PiecePriorityPlanRejected>().single;
      expect(r.taskId, 'task-1');
      expect(r.failureKind, isNotNull);
      await bus.close();
    });

    test('disposed runtime rejects plan', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      await rt.dispose();
      final o = await rt.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityPlanFailureKind.disposed);
      await h.bus.close();
    });

    test('disposed runtime rejects selectProfile', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      await rt.dispose();
      final o = await rt.selectProfile(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profileId: 'balanced');
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityRuntimeFailureKind.disposed);
      await h.bus.close();
    });

    test('disposed runtime rejects lookupPlan', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      await rt.dispose();
      final o = await rt.lookupPlan(const PiecePriorityPlanId('any-plan'));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityRuntimeFailureKind.disposed);
      await h.bus.close();
    });

    test('disposed runtime rejects snapshot', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      await rt.dispose();
      final o = await rt.snapshot(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'));
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityRuntimeFailureKind.disposed);
      await h.bus.close();
    });

    test('disposed runtime rejects applyPlan', () async {
      final h = await _harness();
      final rt = PiecePrioritySchedulerRuntime(btTaskStore: DeterministicBtTaskStore(), streamStore: DeterministicVirtualMediaStreamStore(), schedulerStore: h.ss, profiles: [_prof()], clock: () => _dt());
      await rt.dispose();
      final o = await rt.applyPlan(planId: const PiecePriorityPlanId('any-plan'), applier: const _AcceptingApplier());
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityApplicationFailureKind.disposed);
      await h.bus.close();
    });
  });

  group('Task 1.3 - adapter-neutral application outcomes', () {
    test('accepted', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      final rec = DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, cacheInvalidationBus: h.bus, clock: () => _dt());
      final f = h.bus.events.take(1).toList();
      final a = await rec.applyAndRecord(planId: pl.plan!.id, applier: const _AcceptingApplier());
      final d = await f;
      expect(a.isSuccess, isTrue);
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.accepted);
      expect(d.whereType<PiecePriorityPlanApplied>().length, 1);
      await h.bus.close();
    });

    test('rejected', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      final rec = DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, cacheInvalidationBus: h.bus, clock: () => _dt());
      final f = h.bus.events.take(1).toList();
      final r = await rec.applyAndRecord(planId: pl.plan!.id, applier: const _RejectingApplier());
      final d = await f;
      expect(r.isSuccess, isFalse);
      expect(r.failure!.kind, PiecePriorityApplicationFailureKind.adapterRejected);
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.rejected);
      expect(d.whereType<PiecePriorityPlanRejected>().length, 1);
      await h.bus.close();
    });

    test('unavailable applier', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      final rec = DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, cacheInvalidationBus: h.bus, clock: () => _dt());
      final u = await rec.applyAndRecord(planId: pl.plan!.id);
      expect(u.isSuccess, isFalse);
      expect(u.failure!.kind, PiecePriorityApplicationFailureKind.applierUnavailable);
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.unavailable);
      await h.bus.close();
    });

    test('planNotFound', () async {
      final s = DeterministicPiecePrioritySchedulerStore();
      final rec = DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: s, clock: () => _dt());
      final o = await rec.applyAndRecord(planId: const PiecePriorityPlanId('nonexistent'), applier: const _AcceptingApplier());
      expect(o.isSuccess, isFalse);
      expect(o.failure!.kind, PiecePriorityApplicationFailureKind.planNotFound);
    });

    test('replayable after restart', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      await DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => _dt()).applyAndRecord(planId: pl.plan!.id, applier: const _AcceptingApplier());
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.accepted);
      await DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => DateTime.utc(2026, 6, 5, 12, 1)).applyAndRecord(planId: pl.plan!.id, applier: const _RejectingApplier());
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.rejected);
      await h.bus.close();
    });

    test('latest overwrites', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      final rec = DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => _dt());
      await rec.applyAndRecord(planId: pl.plan!.id, applier: const _AcceptingApplier());
      await rec.applyAndRecord(planId: pl.plan!.id, applier: const _RejectingApplier());
      expect((await h.ss.latestApplicationEvent(pl.plan!.id.value))?.outcome, StoredPiecePriorityApplicationOutcomeKind.rejected);
      await h.bus.close();
    });
  });

  group('Task 1.4 - immutable snapshots and restart projections', () {
    test('active profile reconstructable', () async {
      final h = await _harness();
      await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      final a = await h.ss.activeProfile(taskId: 'task-1', streamId: 'task-1::1');
      expect(a, isNotNull);
      expect(a!.profileId, 'balanced');
      await h.bus.close();
    });

    test('latest plan reconstructable', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      final s = await h.ss.findPlanById(pl.plan!.id.value);
      expect(s, isNotNull);
      expect(s!.taskId, 'task-1');
      expect(s.streamId, 'task-1::1');
      expect(s.profileId, 'balanced');
      await h.bus.close();
    });

    test('ordered rules reconstructable', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof(), playbackWindow: const PlaybackWindow(streamId: VirtualMediaStreamId('task-1::1'), currentByteOffset: 0, lookaheadBytes: 1024)));
      final r = await h.ss.rulesForPlan(pl.plan!.id.value);
      expect(r, isNotEmpty);
      for (var i = 1; i < r.length; i++) { expect(r[i].order, greaterThanOrEqualTo(r[i-1].order)); }
      await h.bus.close();
    });

    test('latest app event reconstructable', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      await DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => _dt()).applyAndRecord(planId: pl.plan!.id, applier: const _AcceptingApplier());
      final e = await h.ss.latestApplicationEvent(pl.plan!.id.value);
      expect(e, isNotNull);
      expect(e!.outcome, StoredPiecePriorityApplicationOutcomeKind.accepted);
      await h.bus.close();
    });

    test('rejected plan reconstructable', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      await DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => _dt()).applyAndRecord(planId: pl.plan!.id, applier: const _RejectingApplier());
      final e = await h.ss.latestApplicationEvent(pl.plan!.id.value);
      expect(e, isNotNull);
      expect(e!.outcome, StoredPiecePriorityApplicationOutcomeKind.rejected);
      await h.bus.close();
    });

    test('unavailable state reconstructable', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      await DeterministicPiecePriorityPlanApplicationRecorder(schedulerStore: h.ss, clock: () => _dt()).applyAndRecord(planId: pl.plan!.id);
      final e = await h.ss.latestApplicationEvent(pl.plan!.id.value);
      expect(e, isNotNull);
      expect(e!.outcome, StoredPiecePriorityApplicationOutcomeKind.unavailable);
      await h.bus.close();
    });

    test('multi-plan projection', () async {
      final h = await _harness();
      // Generate two plans with different timestamps.
      final p1 = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      // Create a new scheduler with an advanced clock for the second plan.
      final bt2 = DeterministicBtTaskStore();
      await bt2.storeTask(_tr());
      await bt2.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Episode Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
      await bt2.storeFiles(taskId: 'task-1', files: const [StoredBtTaskFileRecord(taskId: 'task-1', index: 1, path: 'Episode 2.mkv', lengthBytes: 4096, offsetBytes: 1024, selectionState: StoredBtFileSelectionState.streamingTarget)]);
      final ss2 = DeterministicVirtualMediaStreamStore();
      await ss2.storeStream(_sr());
      final s2 = DeterministicPiecePriorityScheduler(btTaskStore: bt2, streamStore: ss2, schedulerStore: h.ss, clock: () => DateTime.utc(2026, 6, 5, 13));
      await s2.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: const PiecePriorityStrategyProfile(id: 'seq', displayName: 'Seq', firstPiecePriority: DownloadPriority.high, tailPiecePriority: DownloadPriority.low, playbackWindowPriority: DownloadPriority.high, seekTargetPriority: DownloadPriority.normal, lookaheadBytes: 1024, edgePieceCount: 1)));
      final l = await h.ss.latestPlanForStream(taskId: 'task-1', streamId: 'task-1::1');
      expect(l?.profileId, 'seq');
      final e = await h.ss.findPlanById(p1.plan!.id.value);
      expect(e?.profileId, 'balanced');
      final a = await h.ss.activeProfile(taskId: 'task-1', streamId: 'task-1::1');
      expect(a?.profileId, 'seq');
      await h.bus.close();
    });

    test('no plan for empty stream', () async {
      final s = DeterministicPiecePrioritySchedulerStore();
      expect(await s.latestPlanForStream(taskId: 't', streamId: 's'), isNull);
    });

    test('no profile for empty stream', () async {
      final s = DeterministicPiecePrioritySchedulerStore();
      expect(await s.activeProfile(taskId: 't', streamId: 's'), isNull);
    });

    test('no app event for unapplied plan', () async {
      final h = await _harness();
      final pl = await h.scheduler.plan(PiecePriorityPlanRequest(taskId: const BtTaskId('task-1'), streamId: const VirtualMediaStreamId('task-1::1'), profile: _prof()));
      expect(await h.ss.latestApplicationEvent(pl.plan!.id.value), isNull);
      await h.bus.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final class _RuntimeHarness {
  const _RuntimeHarness({required this.scheduler, required this.ss, required this.bus});
  final DeterministicPiecePriorityScheduler scheduler;
  final DeterministicPiecePrioritySchedulerStore ss;
  final StreamCacheInvalidationBus bus;
}

DateTime _dt() => DateTime.utc(2026, 6, 5, 12);

Future<_RuntimeHarness> _harness({int? bufferedRangeEnd}) async {
  final bt = DeterministicBtTaskStore();
  final ss = DeterministicVirtualMediaStreamStore();
  final sc = DeterministicPiecePrioritySchedulerStore();
  final bus = StreamCacheInvalidationBus();
  await bt.storeTask(_tr());
  await bt.storeMetadata(const StoredBtTaskMetadataRecord(taskId: 'task-1', infoHash: 'abc', name: 'Episode Pack', totalSizeBytes: 6144, pieceLengthBytes: 1024));
  await bt.storeFiles(taskId: 'task-1', files: const [StoredBtTaskFileRecord(taskId: 'task-1', index: 1, path: 'Episode 2.mkv', lengthBytes: 4096, offsetBytes: 1024, selectionState: StoredBtFileSelectionState.streamingTarget)]);
  await ss.storeStream(_sr());
  if (bufferedRangeEnd != null) {
    await ss.recordBufferedRange(StoredVirtualStreamBufferedRangeRecord(streamId: 'task-1::1', startByte: 0, endByte: bufferedRangeEnd, observedAt: _dt()));
  }
  return _RuntimeHarness(scheduler: DeterministicPiecePriorityScheduler(btTaskStore: bt, streamStore: ss, schedulerStore: sc, cacheInvalidationBus: bus, clock: () => _dt()), ss: sc, bus: bus);
}

PiecePriorityStrategyProfile _prof() => const PiecePriorityStrategyProfile(id: 'balanced', displayName: 'Balanced', firstPiecePriority: DownloadPriority.critical, tailPiecePriority: DownloadPriority.high, playbackWindowPriority: DownloadPriority.high, seekTargetPriority: DownloadPriority.critical, staleWindowPriority: DownloadPriority.low, lookaheadBytes: 2048, seekLookaheadBytes: 1024, edgePieceCount: 1);

StoredBtTaskRecord _tr() => StoredBtTaskRecord(id: 'task-1', sourceKind: StoredBtTaskSourceKind.magnet, sourceUri: 'magnet:?xt=urn:btih:abc', lifecycleState: StoredBtTaskLifecycleState.ready, createdAt: _dt(), updatedAt: _dt());

StoredVirtualMediaStreamRecord _sr() => StoredVirtualMediaStreamRecord(id: 'task-1::1', taskId: 'task-1', fileIndex: 1, lengthBytes: 4096, lifecycleState: StoredVirtualMediaStreamLifecycleState.active, createdAt: _dt(), updatedAt: _dt());

final class _AcceptingApplier implements PiecePriorityPlanApplier {
  const _AcceptingApplier();
  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) => Future.value(const PiecePriorityApplicationOutcome.accepted());
}

final class _RejectingApplier implements PiecePriorityPlanApplier {
  const _RejectingApplier();
  @override
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan) => Future.value(const PiecePriorityApplicationOutcome.rejected(failure: PiecePriorityApplicationFailure(kind: PiecePriorityApplicationFailureKind.adapterRejected, message: 'rejected')));
}
