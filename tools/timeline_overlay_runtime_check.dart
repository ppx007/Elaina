import '../lib/celesteria.dart';

Future<void> main() async {
  await verifyTimelineOverlayRuntimeContract();
}

Future<void> verifyTimelineOverlayRuntimeContract() async {
  final _RuntimeHarness harness = await _harness();

  // Runtime bootstrap and full snapshot composition.
  final TimelineOverlayRuntime runtime = TimelineOverlayBootstrap(
    store: harness.store,
    composer: DeterministicTimelineOverlayComposer(clock: _now),
    cacheInvalidationBus: harness.bus,
    clock: _now,
  ).createRuntime();
  final Future<CacheInvalidationEvent> firstRefresh = harness.bus.events.first;
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      composed = await runtime.compose(_compositionRequest());
  _expect(
      composed.isSuccess, 'Timeline overlay runtime composition must pass.');
  _expect(composed.value?.snapshot.streamId.value == 'stream-1',
      'Runtime snapshot must project the stream id.');
  _expect(composed.value?.snapshot.position == const Duration(seconds: 10),
      'Runtime snapshot must project playback position.');
  _expect(composed.value?.snapshot.duration == const Duration(minutes: 1),
      'Runtime snapshot must project playback duration.');
  _expect(
      composed.value?.snapshot.buffered.single.end ==
          const Duration(seconds: 15),
      'Runtime snapshot must project ranges.');
  _expect(
      composed.value?.snapshot.pieces.single.state ==
          TimelinePieceState.buffered,
      'Runtime snapshot must project pieces.');
  _expect(
      composed.value?.snapshot.priorityWindows.single.priority == 'critical',
      'Runtime snapshot must project priority windows.');
  _expect(composed.value?.snapshot.markers.single.id == 'opening',
      'Runtime snapshot must project markers.');
  _expect(composed.value?.snapshot.heatValues.single.intensity == 0.75,
      'Runtime snapshot must project heat values.');
  _expect(composed.value?.snapshot.layers.length == 6,
      'Runtime snapshot must project stored profile layers.');
  _expect(composed.value?.activeProfileId == 'default-overlay',
      'Runtime projection must expose the active profile.');
  _expect(composed.value?.latestSnapshotMetadata?.layerCount == 6,
      'Runtime projection must persist snapshot metadata.');
  _expect(composed.value?.restart.activeProfileId == 'default-overlay',
      'Runtime projection must expose restart-visible profile state.');
  _expectThrowsUnsupported(
    () => composed.value!.snapshot.layers.add(_hiddenHeatLayer()),
    'Snapshot layers must be immutable to callers.',
  );
  _expect((await firstRefresh) is TimelineOverlaySnapshotRefreshed,
      'Runtime composition must publish a refresh invalidation.');

  // Profile/layer persistence and restart projection.
  final Future<List<CacheInvalidationEvent>> mutationEvents =
      harness.bus.events.take(3).toList();
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      selected = await runtime.selectProfile(
    streamId: const VirtualMediaStreamId('stream-1'),
    profileId: 'minimal-overlay',
  );
  _expect(selected.isSuccess, 'Runtime must select persisted profiles.');
  _expect(
      (await harness.store.activeProfile('stream-1'))?.profileId ==
          'minimal-overlay',
      'Profile selection must be storage-visible.');

  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      hidden = await runtime.setLayerVisibility(
    profileId: 'minimal-overlay',
    layerId: 'heat',
    visible: false,
  );
  _expect(hidden.isSuccess, 'Runtime must persist layer visibility.');
  _expect(
      (await harness.store.layersForProfile('minimal-overlay')).last.visible ==
          false,
      'Layer visibility must be storage-visible.');

  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      reordered = await runtime.reorderLayers(
    profileId: 'minimal-overlay',
    layerOrder: const <String>['progress', 'markers', 'heat'],
  );
  _expect(reordered.isSuccess, 'Runtime must persist layer order.');
  _expect(
    (await harness.store.layersForProfile('minimal-overlay'))
            .map((StoredTimelineOverlayLayerRecord layer) => layer.layerId)
            .join(',') ==
        'progress,markers,heat',
    'Layer order must be storage-visible.',
  );
  final List<CacheInvalidationEvent> deliveredMutations = await mutationEvents;
  _expect(
      deliveredMutations
              .whereType<TimelineOverlayLayerConfigurationChanged>()
              .length ==
          3,
      'Profile and layer changes must publish ordered invalidations.');

  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      minimalComposition = await runtime.compose(
    _compositionRequest(profileId: 'minimal-overlay'),
  );
  _expect(minimalComposition.isSuccess,
      'Runtime must compose from the selected layer profile.');
  final TimelineOverlayRuntime restarted = TimelineOverlayBootstrap(
    store: harness.store,
    composer: DeterministicTimelineOverlayComposer(clock: _now),
    cacheInvalidationBus: harness.bus,
    clock: _now,
  ).createRuntime();
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      restartSnapshot = await restarted.snapshot(
    const VirtualMediaStreamId('stream-1'),
  );
  _expect(restartSnapshot.isSuccess, 'Restart snapshot lookup must pass.');
  _expect(restartSnapshot.value?.activeProfileId == 'minimal-overlay',
      'Restart projection must restore active profile.');
  _expect(restartSnapshot.value?.layers.last.visible == false,
      'Restart projection must restore hidden layers.');
  _expect(
      restartSnapshot.value?.latestSnapshotMetadata?.positionMillis == 10000,
      'Restart projection must restore latest snapshot metadata.');

  final Future<List<CacheInvalidationEvent>> streamTwoEvents =
      harness.bus.events.take(2).toList();
  await runtime.selectProfile(
    streamId: const VirtualMediaStreamId('stream-2'),
    profileId: 'minimal-overlay',
  );
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      streamTwoMutation = await runtime.setLayerVisibility(
    streamId: const VirtualMediaStreamId('stream-2'),
    profileId: 'minimal-overlay',
    layerId: 'heat',
    visible: true,
  );
  _expect(streamTwoMutation.value?.restart.streamId.value == 'stream-2',
      'Layer mutations must project the requested active stream.');
  _expect(
      (await streamTwoEvents)
          .whereType<TimelineOverlayLayerConfigurationChanged>()
          .every((TimelineOverlayLayerConfigurationChanged event) =>
              event.streamId == 'stream-2'),
      'Layer mutation invalidations must use the requested active stream.');

  // Typed failures.
  await _expectFailure(
    runtime.compose(
        _compositionRequest(playback: _playback(duration: Duration.zero))),
    TimelineOverlayRuntimeFailureKind.missingDuration,
    'Missing duration must be typed.',
  );
  await _expectFailure(
    runtime.compose(_compositionRequest(stream: _descriptor(lengthBytes: 0))),
    TimelineOverlayRuntimeFailureKind.invalidStreamLength,
    'Invalid stream length must be typed.',
  );
  await _expectFailure(
    runtime.compose(_compositionRequest(layers: <TimelineOverlayLayer>[
      _progressLayer(id: 'duplicate'),
      _hiddenHeatLayer(id: 'duplicate'),
    ])),
    TimelineOverlayRuntimeFailureKind.duplicateLayerIdentifier,
    'Duplicate layer identifiers must be typed.',
  );
  await _expectFailure(
    runtime.selectProfile(
      streamId: const VirtualMediaStreamId('stream-1'),
      profileId: 'missing-overlay',
    ),
    TimelineOverlayRuntimeFailureKind.missingProfile,
    'Missing profiles must be typed.',
  );
  await _expectFailure(
    runtime.compose(
        _compositionRequest(stream: _descriptor(id: 'missing-stream'))),
    TimelineOverlayRuntimeFailureKind.unavailableStreamInput,
    'Unavailable stream input must be typed.',
  );
  final Future<CacheInvalidationEvent> rejectionEvent =
      harness.bus.events.first;
  await _expectFailure(
    runtime.compose(_compositionRequest(
      playback: _playback(position: const Duration(minutes: 2)),
    )),
    TimelineOverlayRuntimeFailureKind.rejectedComposition,
    'Rejected composition must be typed.',
  );
  _expect((await rejectionEvent) is TimelineOverlayCompositionRejected,
      'Rejected composition must publish an invalidation.');
  await _expectFailure(
    runtime.reorderLayers(
      profileId: 'default-overlay',
      layerOrder: const <String>['progress', 'progress'],
    ),
    TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
    'Invalid layer configuration must be typed.',
  );
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      rejectedProjection = await runtime.snapshot(
    const VirtualMediaStreamId('stream-1'),
  );
  _expect(
      rejectedProjection.value?.latestFailure?.kind ==
          TimelineOverlayRuntimeFailureKind.rejectedComposition,
      'Snapshot must expose latest rejected composition state.');
  final TimelineOverlayRuntime restartedAfterRejection =
      TimelineOverlayBootstrap(
    store: harness.store,
    composer: DeterministicTimelineOverlayComposer(clock: _now),
    cacheInvalidationBus: harness.bus,
    clock: _now,
  ).createRuntime();
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      replayedRejection = await restartedAfterRejection.snapshot(
    const VirtualMediaStreamId('stream-1'),
  );
  _expect(
      replayedRejection.value?.latestFailure?.kind ==
          TimelineOverlayRuntimeFailureKind.rejectedComposition,
      'Restart projection must replay persisted rejection state.');
  _expect(
      replayedRejection
              .value?.restart.latestCompositionRejection?.failureKind ==
          TimelineOverlayRuntimeFailureKind.rejectedComposition.name,
      'Restart projection must expose stored rejection metadata.');

  // Unavailable and disposed behavior.
  final TimelineOverlayRuntime unavailable = TimelineOverlayRuntime.unavailable(
      reason: 'Timeline overlay source missing.');
  await _expectFailure(
    unavailable.compose(_compositionRequest()),
    TimelineOverlayRuntimeFailureKind.unavailable,
    'Unavailable runtime must return a typed outcome.',
  );
  await runtime.dispose();
  await _expectFailure(
    runtime.compose(_compositionRequest()),
    TimelineOverlayRuntimeFailureKind.disposed,
    'Disposed runtime must reject composition.',
  );
  await _expectFailure(
    runtime.selectProfile(
      streamId: const VirtualMediaStreamId('stream-1'),
      profileId: 'default-overlay',
    ),
    TimelineOverlayRuntimeFailureKind.disposed,
    'Disposed runtime must reject profile selection.',
  );
  await _expectFailure(
    runtime.setLayerVisibility(
      profileId: 'default-overlay',
      layerId: 'heat',
      visible: true,
    ),
    TimelineOverlayRuntimeFailureKind.disposed,
    'Disposed runtime must reject visibility changes.',
  );
  await _expectFailure(
    runtime.reorderLayers(
      profileId: 'default-overlay',
      layerOrder: const <String>[
        'progress',
        'buffered',
        'pieces',
        'priority',
        'markers',
        'heat'
      ],
    ),
    TimelineOverlayRuntimeFailureKind.disposed,
    'Disposed runtime must reject layer reordering.',
  );
  await _expectFailure(
    runtime.snapshot(const VirtualMediaStreamId('stream-1')),
    TimelineOverlayRuntimeFailureKind.disposed,
    'Disposed runtime must reject snapshot lookup.',
  );

  await harness.close();
}

Future<void> _expectFailure(
  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      action,
  TimelineOverlayRuntimeFailureKind kind,
  String message,
) async {
  final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
      result = await action;
  _expect(!result.isSuccess, message);
  _expect(result.failure?.kind == kind, message);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectThrowsUnsupported(void Function() action, String message) {
  try {
    action();
  } on UnsupportedError {
    return;
  }
  throw StateError(message);
}

final class _RuntimeHarness {
  _RuntimeHarness({required this.store, required this.bus});

  final DeterministicTimelineOverlayStore store;
  final StreamCacheInvalidationBus bus;

  Future<void> close() => bus.close();
}

Future<_RuntimeHarness> _harness() async {
  final DeterministicTimelineOverlayStore store =
      DeterministicTimelineOverlayStore(
    seedProfiles: <StoredTimelineOverlayProfileRecord>[
      _profile('default-overlay', isDefault: true),
      _profile('minimal-overlay'),
    ],
  );
  await store.setActiveProfile(StoredActiveTimelineOverlayProfileRecord(
    streamId: 'stream-1',
    profileId: 'default-overlay',
    selectedAt: _now(),
  ));
  await store.storeLayers(
    profileId: 'default-overlay',
    layers: <StoredTimelineOverlayLayerRecord>[
      _storedLayer('default-overlay', 'progress',
          StoredTimelineOverlayLayerKind.playbackProgress, 0),
      _storedLayer('default-overlay', 'buffered',
          StoredTimelineOverlayLayerKind.bufferedRanges, 1),
      _storedLayer('default-overlay', 'pieces',
          StoredTimelineOverlayLayerKind.pieceMap, 2),
      _storedLayer('default-overlay', 'priority',
          StoredTimelineOverlayLayerKind.priorityWindow, 3),
      _storedLayer('default-overlay', 'markers',
          StoredTimelineOverlayLayerKind.marker, 4),
      _storedLayer(
          'default-overlay', 'heat', StoredTimelineOverlayLayerKind.heat, 5),
    ],
  );
  await store.storeLayers(
    profileId: 'minimal-overlay',
    layers: <StoredTimelineOverlayLayerRecord>[
      _storedLayer('minimal-overlay', 'progress',
          StoredTimelineOverlayLayerKind.playbackProgress, 0),
      _storedLayer('minimal-overlay', 'markers',
          StoredTimelineOverlayLayerKind.marker, 1),
      _storedLayer(
          'minimal-overlay', 'heat', StoredTimelineOverlayLayerKind.heat, 2),
    ],
  );
  return _RuntimeHarness(store: store, bus: StreamCacheInvalidationBus());
}

TimelineOverlayRuntimeCompositionRequest _compositionRequest({
  VirtualMediaStreamDescriptor? stream,
  TimelinePlaybackSnapshot? playback,
  String profileId = 'default-overlay',
  List<TimelineOverlayLayer>? layers,
}) {
  return TimelineOverlayRuntimeCompositionRequest(
    profileId: profileId,
    stream: stream ?? _descriptor(),
    playback: playback ?? _playback(),
    bufferedRanges: const <StreamBufferedRange>[
      StreamBufferedRange(
        mediaId: 'stream-1',
        range: BufferedRange(startByte: 0, endByte: 1023),
      ),
    ],
    pieces: const <TimelinePieceSegment>[
      TimelinePieceSegment(
        pieceIndex: BtPieceIndex(0),
        state: TimelinePieceState.buffered,
        byteRange: TimelineByteRange(
          streamId: VirtualMediaStreamId('stream-1'),
          range: BtByteRange(start: 0, endInclusive: 1023),
        ),
      ),
    ],
    priorityWindows: const <TimelinePriorityWindow>[
      TimelinePriorityWindow(
        id: 'priority-0',
        pieceIndex: BtPieceIndex(0),
        byteRange: TimelineByteRange(
          streamId: VirtualMediaStreamId('stream-1'),
          range: BtByteRange(start: 0, endInclusive: 1023),
        ),
        priority: 'critical',
        reason: 'playbackWindow',
      ),
    ],
    markers: const <TimelineMarker>[
      TimelineMarker(
        id: 'opening',
        position: Duration(seconds: 10),
        label: 'OP',
      ),
    ],
    heatValues: <TimelineHeatValue>[
      TimelineHeatValue(
        id: 'heat-1',
        range: TimelineTimeRange(
          start: const Duration(seconds: 10),
          end: const Duration(seconds: 20),
        ),
        intensity: 0.75,
      ),
    ],
    layers: layers ?? const <TimelineOverlayLayer>[],
  );
}

VirtualMediaStreamDescriptor _descriptor({
  String id = 'stream-1',
  int lengthBytes = 4096,
}) {
  return VirtualMediaStreamDescriptor(
    id: VirtualMediaStreamId(id),
    taskId: const BtTaskId('task-1'),
    fileIndex: const BtFileIndex(0),
    lengthBytes: lengthBytes,
  );
}

TimelinePlaybackSnapshot _playback({
  Duration position = const Duration(seconds: 10),
  Duration duration = const Duration(minutes: 1),
}) {
  return TimelinePlaybackSnapshot(position: position, duration: duration);
}

TimelineOverlayLayer _progressLayer({String id = 'progress'}) {
  return TimelineOverlayLayer(
    id: id,
    kind: TimelineOverlayLayerKind.playbackProgress,
    visible: true,
    order: 0,
  );
}

TimelineOverlayLayer _hiddenHeatLayer({String id = 'heat'}) {
  return TimelineOverlayLayer(
    id: id,
    kind: TimelineOverlayLayerKind.heat,
    visible: false,
    order: 1,
  );
}

StoredTimelineOverlayProfileRecord _profile(String id,
    {bool isDefault = false}) {
  return StoredTimelineOverlayProfileRecord(
    id: id,
    displayName: id,
    isDefault: isDefault,
    createdAt: _now(),
    updatedAt: _now(),
  );
}

StoredTimelineOverlayLayerRecord _storedLayer(
  String profileId,
  String layerId,
  StoredTimelineOverlayLayerKind kind,
  int order, {
  bool visible = true,
}) {
  return StoredTimelineOverlayLayerRecord(
    profileId: profileId,
    layerId: layerId,
    kind: kind,
    visible: visible,
    order: order,
    updatedAt: _now(),
  );
}

DateTime _now() => DateTime.utc(2026, 6, 13, 12);
