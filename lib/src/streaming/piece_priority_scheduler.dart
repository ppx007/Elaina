import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/storage_contracts.dart';
import 'bt_task_core.dart';
import 'virtual_media_stream.dart';

enum DownloadPriority {
  off,
  low,
  normal,
  high,
  critical,
}

final class PiecePriorityPlanId {
  const PiecePriorityPlanId(this.value)
      : assert(value != '', 'Piece priority plan id must not be empty.');

  final String value;
}

final class PieceSpan {
  const PieceSpan({required this.first, required this.last});

  final BtPieceIndex first;
  final BtPieceIndex last;
}

final class FilePieceMap {
  const FilePieceMap({
    required this.fileIndex,
    required this.fileRange,
    required this.pieceSpan,
    required this.pieceLengthBytes,
  }) : assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.');

  final BtFileIndex fileIndex;
  final BtByteRange fileRange;
  final PieceSpan pieceSpan;
  final int pieceLengthBytes;
}

final class PlaybackWindow {
  const PlaybackWindow({
    required this.streamId,
    required this.currentByteOffset,
    required this.lookaheadBytes,
  })  : assert(
            currentByteOffset >= 0, 'currentByteOffset must not be negative.'),
        assert(lookaheadBytes >= 0, 'lookaheadBytes must not be negative.');

  final VirtualMediaStreamId streamId;
  final int currentByteOffset;
  final int lookaheadBytes;
}

final class SeekTarget {
  const SeekTarget({
    required this.streamId,
    required this.targetByteOffset,
    this.deadline,
  }) : assert(targetByteOffset >= 0, 'targetByteOffset must not be negative.');

  final VirtualMediaStreamId streamId;
  final int targetByteOffset;
  final Duration? deadline;
}

enum PiecePriorityRuleReason {
  firstPiece,
  tailPiece,
  playbackWindow,
  seekTarget,
  staleWindow,
}

final class PiecePriorityRule {
  const PiecePriorityRule({
    required this.pieceIndex,
    required this.priority,
    this.reason = PiecePriorityRuleReason.playbackWindow,
    this.deadline,
  });

  final BtPieceIndex pieceIndex;
  final DownloadPriority priority;
  final PiecePriorityRuleReason reason;
  final Duration? deadline;
}

final class PiecePriorityPlan {
  const PiecePriorityPlan({
    required this.id,
    required this.taskId,
    required this.streamId,
    required this.fileIndex,
    required this.profileId,
    required this.generatedAt,
    required this.rules,
  });

  final PiecePriorityPlanId id;
  final BtTaskId taskId;
  final VirtualMediaStreamId streamId;
  final BtFileIndex fileIndex;
  final String profileId;
  final DateTime generatedAt;
  final List<PiecePriorityRule> rules;
}

final class PiecePriorityStrategyProfile {
  const PiecePriorityStrategyProfile({
    required this.id,
    required this.firstPiecePriority,
    required this.tailPiecePriority,
    required this.playbackWindowPriority,
    required this.seekTargetPriority,
    required this.lookaheadBytes,
    this.displayName,
    this.staleWindowPriority = DownloadPriority.low,
    this.seekLookaheadBytes,
    this.edgePieceCount = 1,
  })  : assert(id != '', 'Strategy profile id must not be empty.'),
        assert(lookaheadBytes >= 0, 'lookaheadBytes must not be negative.'),
        assert(seekLookaheadBytes == null || seekLookaheadBytes >= 0,
            'seekLookaheadBytes must not be negative.'),
        assert(edgePieceCount >= 0, 'edgePieceCount must not be negative.');

  final String id;
  final String? displayName;
  final DownloadPriority firstPiecePriority;
  final DownloadPriority tailPiecePriority;
  final DownloadPriority playbackWindowPriority;
  final DownloadPriority seekTargetPriority;
  final DownloadPriority staleWindowPriority;
  final int lookaheadBytes;
  final int? seekLookaheadBytes;
  final int edgePieceCount;
}

final class PiecePriorityPlanRequest {
  const PiecePriorityPlanRequest({
    required this.taskId,
    required this.streamId,
    required this.profile,
    this.playbackWindow,
    this.seekTarget,
  });

  final BtTaskId taskId;
  final VirtualMediaStreamId streamId;
  final PiecePriorityStrategyProfile profile;
  final PlaybackWindow? playbackWindow;
  final SeekTarget? seekTarget;
}

enum PiecePriorityPlanFailureKind {
  dependenciesUnavailable,
  metadataUnavailable,
  fileMapUnavailable,
  streamUnavailable,
  streamClosed,
  streamFailed,
  unsupportedProfile,
  rangeOutOfBounds,
  noSchedulablePieces,
  disposed,
}

final class PiecePriorityPlanFailure implements Exception {
  const PiecePriorityPlanFailure({required this.kind, required this.message});

  final PiecePriorityPlanFailureKind kind;
  final String message;
}

final class PiecePriorityPlanOutcome {
  const PiecePriorityPlanOutcome._({this.plan, this.failure});

  const PiecePriorityPlanOutcome.success({required PiecePriorityPlan plan})
      : this._(plan: plan);

  const PiecePriorityPlanOutcome.failure(
      {required PiecePriorityPlanFailure failure})
      : this._(failure: failure);

  final PiecePriorityPlan? plan;
  final PiecePriorityPlanFailure? failure;

  bool get isSuccess => failure == null;
}

enum PiecePriorityApplicationFailureKind {
  planNotFound,
  applierUnavailable,
  adapterRejected,
  stalePlan,
  disposed,
}

final class PiecePriorityApplicationFailure implements Exception {
  const PiecePriorityApplicationFailure({
    required this.kind,
    required this.message,
  });

  final PiecePriorityApplicationFailureKind kind;
  final String message;
}

final class PiecePriorityApplicationOutcome {
  const PiecePriorityApplicationOutcome._(
      {this.failure, required this.accepted});

  const PiecePriorityApplicationOutcome.accepted() : this._(accepted: true);

  const PiecePriorityApplicationOutcome.rejected(
      {required PiecePriorityApplicationFailure failure})
      : this._(accepted: false, failure: failure);

  const PiecePriorityApplicationOutcome.unavailable(
      {required PiecePriorityApplicationFailure failure})
      : this._(accepted: false, failure: failure);

  final bool accepted;
  final PiecePriorityApplicationFailure? failure;

  bool get isSuccess => accepted;
}

abstract interface class PiecePriorityScheduler {
  Future<PiecePriorityPlanOutcome> plan(PiecePriorityPlanRequest request);
}

abstract interface class PiecePriorityPlanApplier {
  Future<PiecePriorityApplicationOutcome> apply(PiecePriorityPlan plan);
}

final class DeterministicPiecePriorityScheduler
    implements PiecePriorityScheduler {
  DeterministicPiecePriorityScheduler({
    required this.btTaskStore,
    required this.streamStore,
    required this.schedulerStore,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final BtTaskStore btTaskStore;
  final VirtualMediaStreamStore streamStore;
  final PiecePrioritySchedulerStore schedulerStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  @override
  Future<PiecePriorityPlanOutcome> plan(
      PiecePriorityPlanRequest request) async {
    final StoredPiecePriorityStrategyProfileRecord profileRecord =
        _storedProfile(request.profile, _clock());
    await schedulerStore.storeProfile(profileRecord);
    await schedulerStore
        .setActiveProfile(StoredActivePiecePriorityProfileRecord(
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      profileId: request.profile.id,
      selectedAt: _clock(),
    ));
    cacheInvalidationBus?.publish(PiecePriorityProfileChanged(
      occurredAt: _clock(),
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      profileId: request.profile.id,
    ));

    final StoredBtTaskMetadataRecord? metadata =
        await btTaskStore.metadataFor(request.taskId.value);
    if (metadata == null) {
      return _rejected(
          request,
          PiecePriorityPlanFailureKind.metadataUnavailable,
          'BT task ${request.taskId.value} metadata is unavailable.');
    }
    final StoredVirtualMediaStreamRecord? stream =
        await streamStore.findStreamById(request.streamId.value);
    if (stream == null || stream.taskId != request.taskId.value) {
      return _rejected(request, PiecePriorityPlanFailureKind.streamUnavailable,
          'Virtual stream ${request.streamId.value} is unavailable.');
    }
    if (stream.lifecycleState ==
        StoredVirtualMediaStreamLifecycleState.closed) {
      return _rejected(request, PiecePriorityPlanFailureKind.streamClosed,
          'Virtual stream ${request.streamId.value} is closed.');
    }
    final List<StoredBtTaskFileRecord> files =
        await btTaskStore.filesFor(request.taskId.value);
    final StoredBtTaskFileRecord? file = _fileFor(files, stream.fileIndex);
    if (file == null ||
        file.selectionState == StoredBtFileSelectionState.skipped) {
      return _rejected(request, PiecePriorityPlanFailureKind.fileMapUnavailable,
          'BT task ${request.taskId.value} file ${stream.fileIndex} is unavailable.');
    }
    if (request.profile.id.isEmpty) {
      return _rejected(request, PiecePriorityPlanFailureKind.unsupportedProfile,
          'Strategy profile id is unavailable.');
    }
    if (file.lengthBytes <= 0 || metadata.pieceLengthBytes <= 0) {
      return _rejected(
          request,
          PiecePriorityPlanFailureKind.noSchedulablePieces,
          'No schedulable pieces are available.');
    }

    final FilePieceMap fileMap = deriveFilePieceMap(
      file: file,
      pieceLengthBytes: metadata.pieceLengthBytes,
    );
    final PiecePriorityPlanFailure? rangeFailure = _validateRanges(
      request: request,
      streamLengthBytes: stream.lengthBytes,
    );
    if (rangeFailure != null) {
      return _rejected(request, rangeFailure.kind, rangeFailure.message);
    }

    final Set<int> bufferedPieces = _fullyBufferedPieces(
      ranges: await streamStore.bufferedRangesFor(request.streamId.value),
      fileOffsetBytes: file.offsetBytes,
      pieceLengthBytes: metadata.pieceLengthBytes,
    );
    final List<PiecePriorityRule> rules = _planRules(
      request: request,
      fileMap: fileMap,
      streamLengthBytes: stream.lengthBytes,
      fileOffsetBytes: file.offsetBytes,
      pieceLengthBytes: metadata.pieceLengthBytes,
      bufferedPieces: bufferedPieces,
    );
    if (rules.isEmpty) {
      return _rejected(
          request,
          PiecePriorityPlanFailureKind.noSchedulablePieces,
          'No unbuffered schedulable pieces are available.');
    }

    final DateTime now = _clock();
    final PiecePriorityPlan plan = PiecePriorityPlan(
      id: PiecePriorityPlanId(_planId(request, now)),
      taskId: request.taskId,
      streamId: request.streamId,
      fileIndex: BtFileIndex(stream.fileIndex),
      profileId: request.profile.id,
      generatedAt: now,
      rules: rules,
    );
    await schedulerStore.storePlan(StoredPiecePriorityPlanRecord(
      id: plan.id.value,
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      fileIndex: stream.fileIndex,
      profileId: request.profile.id,
      metadataInfoHash: metadata.infoHash,
      pieceLengthBytes: metadata.pieceLengthBytes,
      playbackStartByte: request.playbackWindow?.currentByteOffset,
      playbackEndByte: _playbackEnd(request, stream.lengthBytes),
      seekTargetByte: request.seekTarget?.targetByteOffset,
      generatedAt: now,
    ));
    await schedulerStore.storePlanRules(
      planId: plan.id.value,
      rules: <StoredPiecePriorityPlanRuleRecord>[
        for (int index = 0; index < rules.length; index += 1)
          _storedRule(plan.id.value, rules[index], index),
      ],
    );
    cacheInvalidationBus?.publish(PiecePriorityPlanGenerated(
      occurredAt: now,
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      planId: plan.id.value,
      profileId: request.profile.id,
    ));
    return PiecePriorityPlanOutcome.success(plan: plan);
  }

  Future<PiecePriorityPlanOutcome> _rejected(
    PiecePriorityPlanRequest request,
    PiecePriorityPlanFailureKind kind,
    String message,
  ) async {
    await schedulerStore.recordPlanningFailure(
      StoredPiecePriorityPlanningFailureRecord(
        taskId: request.taskId.value,
        streamId: request.streamId.value,
        profileId: request.profile.id,
        failureKind: kind.name,
        message: message,
        occurredAt: _clock(),
      ),
    );
    cacheInvalidationBus?.publish(PiecePriorityPlanRejected(
      occurredAt: _clock(),
      taskId: request.taskId.value,
      streamId: request.streamId.value,
      planId: '${request.taskId.value}::${request.streamId.value}::rejected',
      profileId: request.profile.id,
      failureKind: kind.name,
    ));
    return PiecePriorityPlanOutcome.failure(
      failure: PiecePriorityPlanFailure(kind: kind, message: message),
    );
  }
}

final class DeterministicPiecePriorityPlanApplicationRecorder {
  DeterministicPiecePriorityPlanApplicationRecorder({
    required this.schedulerStore,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final PiecePrioritySchedulerStore schedulerStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  Future<PiecePriorityApplicationOutcome> applyAndRecord({
    required PiecePriorityPlanId planId,
    PiecePriorityPlanApplier? applier,
  }) async {
    final StoredPiecePriorityPlanRecord? storedPlan =
        await schedulerStore.findPlanById(planId.value);
    if (storedPlan == null) {
      return _recordUnavailable(
        planId: planId.value,
        taskId: 'unknown',
        streamId: 'unknown',
        profileId: 'unknown',
        failure: const PiecePriorityApplicationFailure(
          kind: PiecePriorityApplicationFailureKind.planNotFound,
          message: 'Piece priority plan was not found.',
        ),
      );
    }
    final List<StoredPiecePriorityPlanRuleRecord> storedRules =
        await schedulerStore.rulesForPlan(planId.value);
    final PiecePriorityPlan plan = PiecePriorityPlan(
      id: planId,
      taskId: BtTaskId(storedPlan.taskId),
      streamId: VirtualMediaStreamId(storedPlan.streamId),
      fileIndex: BtFileIndex(storedPlan.fileIndex),
      profileId: storedPlan.profileId,
      generatedAt: storedPlan.generatedAt,
      rules: <PiecePriorityRule>[
        for (final StoredPiecePriorityPlanRuleRecord rule in storedRules)
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
    if (applier == null) {
      return _recordUnavailable(
        planId: storedPlan.id,
        taskId: storedPlan.taskId,
        streamId: storedPlan.streamId,
        profileId: storedPlan.profileId,
        failure: const PiecePriorityApplicationFailure(
          kind: PiecePriorityApplicationFailureKind.applierUnavailable,
          message: 'Piece priority plan applier is unavailable.',
        ),
      );
    }
    final PiecePriorityApplicationOutcome outcome = await applier.apply(plan);
    final DateTime now = _clock();
    if (outcome.isSuccess) {
      await schedulerStore.recordApplicationEvent(
        StoredPiecePriorityPlanApplicationEventRecord(
          planId: storedPlan.id,
          taskId: storedPlan.taskId,
          streamId: storedPlan.streamId,
          profileId: storedPlan.profileId,
          outcome: StoredPiecePriorityApplicationOutcomeKind.accepted,
          occurredAt: now,
        ),
      );
      cacheInvalidationBus?.publish(PiecePriorityPlanApplied(
        occurredAt: now,
        taskId: storedPlan.taskId,
        streamId: storedPlan.streamId,
        planId: storedPlan.id,
        profileId: storedPlan.profileId,
      ));
      return outcome;
    }
    await schedulerStore.recordApplicationEvent(
      StoredPiecePriorityPlanApplicationEventRecord(
        planId: storedPlan.id,
        taskId: storedPlan.taskId,
        streamId: storedPlan.streamId,
        profileId: storedPlan.profileId,
        outcome: StoredPiecePriorityApplicationOutcomeKind.rejected,
        occurredAt: now,
        failureKind: outcome.failure?.kind.name,
        message: outcome.failure?.message,
      ),
    );
    cacheInvalidationBus?.publish(PiecePriorityPlanRejected(
      occurredAt: now,
      taskId: storedPlan.taskId,
      streamId: storedPlan.streamId,
      planId: storedPlan.id,
      profileId: storedPlan.profileId,
      failureKind: outcome.failure?.kind.name,
    ));
    return outcome;
  }

  Future<PiecePriorityApplicationOutcome> _recordUnavailable({
    required String planId,
    required String taskId,
    required String streamId,
    required String profileId,
    required PiecePriorityApplicationFailure failure,
  }) async {
    final DateTime now = _clock();
    if (taskId != 'unknown' &&
        streamId != 'unknown' &&
        profileId != 'unknown') {
      await schedulerStore.recordApplicationEvent(
        StoredPiecePriorityPlanApplicationEventRecord(
          planId: planId,
          taskId: taskId,
          streamId: streamId,
          profileId: profileId,
          outcome: StoredPiecePriorityApplicationOutcomeKind.unavailable,
          occurredAt: now,
          failureKind: failure.kind.name,
          message: failure.message,
        ),
      );
    }
    cacheInvalidationBus?.publish(PiecePriorityPlanRejected(
      occurredAt: now,
      taskId: taskId,
      streamId: streamId,
      planId: planId,
      profileId: profileId,
      failureKind: failure.kind.name,
    ));
    cacheInvalidationBus?.publish(PiecePriorityPlanUnavailable(
      occurredAt: now,
      taskId: taskId,
      streamId: streamId,
      planId: planId,
      profileId: profileId,
      failureKind: failure.kind.name,
    ));
    return PiecePriorityApplicationOutcome.unavailable(failure: failure);
  }
}

FilePieceMap deriveFilePieceMap({
  required StoredBtTaskFileRecord file,
  required int pieceLengthBytes,
}) {
  assert(pieceLengthBytes > 0, 'pieceLengthBytes must be positive.');
  final int fileStart = file.offsetBytes;
  final int fileEndInclusive = file.offsetBytes + file.lengthBytes - 1;
  return FilePieceMap(
    fileIndex: BtFileIndex(file.index),
    fileRange: BtByteRange(start: fileStart, endInclusive: fileEndInclusive),
    pieceSpan: PieceSpan(
      first: BtPieceIndex(fileStart ~/ pieceLengthBytes),
      last: BtPieceIndex(fileEndInclusive ~/ pieceLengthBytes),
    ),
    pieceLengthBytes: pieceLengthBytes,
  );
}

DateTime _defaultClock() => DateTime.now().toUtc();

StoredBtTaskFileRecord? _fileFor(
    Iterable<StoredBtTaskFileRecord> files, int fileIndex) {
  for (final StoredBtTaskFileRecord file in files) {
    if (file.index == fileIndex) {
      return file;
    }
  }
  return null;
}

PiecePriorityPlanFailure? _validateRanges({
  required PiecePriorityPlanRequest request,
  required int streamLengthBytes,
}) {
  if (request.playbackWindow != null &&
      request.playbackWindow!.streamId.value != request.streamId.value) {
    return const PiecePriorityPlanFailure(
      kind: PiecePriorityPlanFailureKind.streamUnavailable,
      message: 'Playback window targets a different virtual stream.',
    );
  }
  if (request.seekTarget != null &&
      request.seekTarget!.streamId.value != request.streamId.value) {
    return const PiecePriorityPlanFailure(
      kind: PiecePriorityPlanFailureKind.streamUnavailable,
      message: 'Seek target targets a different virtual stream.',
    );
  }
  if (request.playbackWindow != null &&
      request.playbackWindow!.currentByteOffset >= streamLengthBytes) {
    return const PiecePriorityPlanFailure(
      kind: PiecePriorityPlanFailureKind.rangeOutOfBounds,
      message: 'Playback window starts beyond virtual stream length.',
    );
  }
  if (request.seekTarget != null &&
      request.seekTarget!.targetByteOffset >= streamLengthBytes) {
    return const PiecePriorityPlanFailure(
      kind: PiecePriorityPlanFailureKind.rangeOutOfBounds,
      message: 'Seek target starts beyond virtual stream length.',
    );
  }
  return null;
}

List<PiecePriorityRule> _planRules({
  required PiecePriorityPlanRequest request,
  required FilePieceMap fileMap,
  required int streamLengthBytes,
  required int fileOffsetBytes,
  required int pieceLengthBytes,
  required Set<int> bufferedPieces,
}) {
  final Map<int, PiecePriorityRule> byPiece = <int, PiecePriorityRule>{};
  void addRule(
      int piece, DownloadPriority priority, PiecePriorityRuleReason reason,
      {Duration? deadline}) {
    if (piece < fileMap.pieceSpan.first.value ||
        piece > fileMap.pieceSpan.last.value ||
        bufferedPieces.contains(piece)) {
      return;
    }
    final PiecePriorityRule candidate = PiecePriorityRule(
      pieceIndex: BtPieceIndex(piece),
      priority: priority,
      reason: reason,
      deadline: deadline,
    );
    final PiecePriorityRule? existing = byPiece[piece];
    if (existing == null || _ruleRank(candidate) > _ruleRank(existing)) {
      byPiece[piece] = candidate;
    }
  }

  final int edgeCount = request.profile.edgePieceCount;
  for (int offset = 0; offset < edgeCount; offset += 1) {
    addRule(fileMap.pieceSpan.first.value + offset,
        request.profile.firstPiecePriority, PiecePriorityRuleReason.firstPiece);
    addRule(fileMap.pieceSpan.last.value - offset,
        request.profile.tailPiecePriority, PiecePriorityRuleReason.tailPiece);
  }
  if (request.playbackWindow != null) {
    final int end = _clampEnd(
      request.playbackWindow!.currentByteOffset +
          _max(request.playbackWindow!.lookaheadBytes,
              request.profile.lookaheadBytes),
      streamLengthBytes,
    );
    _addWindowRules(
      addRule: addRule,
      startByte: request.playbackWindow!.currentByteOffset,
      endByte: end,
      fileOffsetBytes: fileOffsetBytes,
      pieceLengthBytes: pieceLengthBytes,
      priority: request.profile.playbackWindowPriority,
      reason: PiecePriorityRuleReason.playbackWindow,
    );
  }
  if (request.seekTarget != null) {
    final int end = _clampEnd(
      request.seekTarget!.targetByteOffset +
          (request.profile.seekLookaheadBytes ??
              request.profile.lookaheadBytes),
      streamLengthBytes,
    );
    _addWindowRules(
      addRule: addRule,
      startByte: request.seekTarget!.targetByteOffset,
      endByte: end,
      fileOffsetBytes: fileOffsetBytes,
      pieceLengthBytes: pieceLengthBytes,
      priority: request.profile.seekTargetPriority,
      reason: PiecePriorityRuleReason.seekTarget,
      deadline: request.seekTarget!.deadline,
    );
  }
  return <PiecePriorityRule>[...byPiece.values]
    ..sort((PiecePriorityRule left, PiecePriorityRule right) {
      final int priorityCompare =
          _priorityRank(right.priority).compareTo(_priorityRank(left.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return left.pieceIndex.value.compareTo(right.pieceIndex.value);
    });
}

void _addWindowRules({
  required void Function(
          int piece, DownloadPriority priority, PiecePriorityRuleReason reason,
          {Duration? deadline})
      addRule,
  required int startByte,
  required int endByte,
  required int fileOffsetBytes,
  required int pieceLengthBytes,
  required DownloadPriority priority,
  required PiecePriorityRuleReason reason,
  Duration? deadline,
}) {
  final int startPiece = (fileOffsetBytes + startByte) ~/ pieceLengthBytes;
  final int endPiece = (fileOffsetBytes + endByte) ~/ pieceLengthBytes;
  for (int piece = startPiece; piece <= endPiece; piece += 1) {
    addRule(piece, priority, reason, deadline: deadline);
  }
}

Set<int> _fullyBufferedPieces({
  required Iterable<StoredVirtualStreamBufferedRangeRecord> ranges,
  required int fileOffsetBytes,
  required int pieceLengthBytes,
}) {
  final Set<int> pieces = <int>{};
  for (final StoredVirtualStreamBufferedRangeRecord range in ranges) {
    final int startPiece =
        (fileOffsetBytes + range.startByte) ~/ pieceLengthBytes;
    final int endPiece = (fileOffsetBytes + range.endByte) ~/ pieceLengthBytes;
    if ((fileOffsetBytes + range.startByte) % pieceLengthBytes == 0 &&
        (fileOffsetBytes + range.endByte + 1) % pieceLengthBytes == 0) {
      for (int piece = startPiece; piece <= endPiece; piece += 1) {
        pieces.add(piece);
      }
    }
  }
  return pieces;
}

int? _playbackEnd(PiecePriorityPlanRequest request, int streamLengthBytes) {
  if (request.playbackWindow == null) {
    return null;
  }
  return _clampEnd(
    request.playbackWindow!.currentByteOffset +
        _max(request.playbackWindow!.lookaheadBytes,
            request.profile.lookaheadBytes),
    streamLengthBytes,
  );
}

int _clampEnd(int value, int streamLengthBytes) {
  final int maxEnd = streamLengthBytes - 1;
  return value > maxEnd ? maxEnd : value;
}

int _max(int left, int right) => left > right ? left : right;

int _ruleRank(PiecePriorityRule rule) {
  return (_reasonRank(rule.reason) * 10) + _priorityRank(rule.priority);
}

int _reasonRank(PiecePriorityRuleReason reason) {
  return switch (reason) {
    PiecePriorityRuleReason.staleWindow => 0,
    PiecePriorityRuleReason.tailPiece => 1,
    PiecePriorityRuleReason.firstPiece => 2,
    PiecePriorityRuleReason.playbackWindow => 3,
    PiecePriorityRuleReason.seekTarget => 4,
  };
}

int _priorityRank(DownloadPriority priority) {
  return switch (priority) {
    DownloadPriority.off => 0,
    DownloadPriority.low => 1,
    DownloadPriority.normal => 2,
    DownloadPriority.high => 3,
    DownloadPriority.critical => 4,
  };
}

StoredPiecePriorityStrategyProfileRecord _storedProfile(
    PiecePriorityStrategyProfile profile, DateTime now) {
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
    isDefault: false,
  );
}

StoredPiecePriorityPlanRuleRecord _storedRule(
    String planId, PiecePriorityRule rule, int order) {
  return StoredPiecePriorityPlanRuleRecord(
    planId: planId,
    pieceIndex: rule.pieceIndex.value,
    priority: rule.priority.name,
    reason: rule.reason.name,
    order: order,
    deadlineMillis: rule.deadline?.inMilliseconds,
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

String _planId(PiecePriorityPlanRequest request, DateTime generatedAt) {
  return '${request.taskId.value}::${request.streamId.value}::${request.profile.id}::${generatedAt.microsecondsSinceEpoch}';
}
