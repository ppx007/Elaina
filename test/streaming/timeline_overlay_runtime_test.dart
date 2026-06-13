import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1.1 - runtime composition projection', () {
    test(
        'composes playback stream ranges pieces priorities markers heat profile',
        () async {
      final _RuntimeHarness h = await _harness();

      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          outcome = await h.runtime.compose(_compositionRequest());

      expect(outcome.isSuccess, isTrue);
      expect(outcome.failure, isNull);
      expect(outcome.value?.snapshot.streamId.value, 'stream-1');
      expect(outcome.value?.snapshot.position, const Duration(seconds: 10));
      expect(outcome.value?.snapshot.duration, const Duration(minutes: 1));
      expect(outcome.value?.snapshot.buffered.single.end,
          const Duration(seconds: 15));
      expect(outcome.value?.snapshot.pieces.single.state,
          TimelinePieceState.buffered);
      expect(
          outcome.value?.snapshot.priorityWindows.single.priority, 'critical');
      expect(outcome.value?.snapshot.markers.single.id, 'opening');
      expect(outcome.value?.snapshot.heatValues.single.intensity, 0.75);
      expect(outcome.value?.activeProfileId, 'default-overlay');
      expect(outcome.value?.latestSnapshotMetadata?.layerCount, 6);
      expect(outcome.value?.restart.streamId.value, 'stream-1');
      expect(outcome.value?.restart.activeProfileId, 'default-overlay');
      expect(
        outcome.value?.snapshot.layers
            .map((TimelineOverlayLayer layer) => layer.kind),
        containsAll(<TimelineOverlayLayerKind>[
          TimelineOverlayLayerKind.playbackProgress,
          TimelineOverlayLayerKind.bufferedRanges,
          TimelineOverlayLayerKind.pieceMap,
          TimelineOverlayLayerKind.priorityWindow,
          TimelineOverlayLayerKind.marker,
          TimelineOverlayLayerKind.heat,
        ]),
      );
      expect(
        () => outcome.value!.snapshot.layers.add(_hiddenHeatLayer()),
        throwsUnsupportedError,
      );
      expect(
        () => outcome.value!.snapshot.buffered.add(
          TimelineTimeRange(
            start: Duration.zero,
            end: Duration(seconds: 1),
          ),
        ),
        throwsUnsupportedError,
      );

      await h.close();
    });
  });

  group('Task 1.2 - profile selection and restart projection replay', () {
    test('restores active profile layers hidden order and latest metadata',
        () async {
      final _RuntimeHarness h = await _harness();

      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          selected = await h.runtime.selectProfile(
        streamId: const VirtualMediaStreamId('stream-1'),
        profileId: 'minimal-overlay',
      );
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          visibility = await h.runtime.setLayerVisibility(
        profileId: 'minimal-overlay',
        layerId: 'heat',
        visible: false,
      );
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          ordered = await h.runtime.reorderLayers(
        profileId: 'minimal-overlay',
        layerOrder: const <String>['progress', 'markers', 'heat'],
      );
      await h.runtime
          .compose(_compositionRequest(profileId: 'minimal-overlay'));

      final TimelineOverlayRuntime restored = TimelineOverlayBootstrap(
        store: h.store,
        composer: DeterministicTimelineOverlayComposer(clock: _now),
        cacheInvalidationBus: h.bus,
        clock: _now,
      ).createRuntime();
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          snapshot = await restored.snapshot(
        const VirtualMediaStreamId('stream-1'),
      );

      expect(selected.isSuccess, isTrue, reason: selected.failure?.message);
      expect(visibility.isSuccess, isTrue, reason: visibility.failure?.message);
      expect(ordered.isSuccess, isTrue, reason: ordered.failure?.message);
      expect(snapshot.value?.activeProfileId, 'minimal-overlay');
      expect(
          snapshot.value?.layers.map((TimelineOverlayLayer layer) => layer.id),
          <String>['progress', 'markers', 'heat']);
      expect(snapshot.value?.layers.last.visible, isFalse);
      expect(
          snapshot.value?.latestSnapshotMetadata?.profileId, 'minimal-overlay');
      expect(snapshot.value?.latestSnapshotMetadata?.positionMillis, 10000);
      expect(
        () => snapshot.value!.layers.add(_hiddenHeatLayer()),
        throwsUnsupportedError,
      );

      await h.close();
    });

    test('maps layer mutations to the actual active stream', () async {
      final _RuntimeHarness h = await _harness();
      final Future<List<CacheInvalidationEvent>> events =
          h.bus.events.take(2).toList();

      await h.runtime.selectProfile(
        streamId: const VirtualMediaStreamId('stream-2'),
        profileId: 'minimal-overlay',
      );
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          visibility = await h.runtime.setLayerVisibility(
        streamId: const VirtualMediaStreamId('stream-2'),
        profileId: 'minimal-overlay',
        layerId: 'heat',
        visible: false,
      );

      expect(visibility.isSuccess, isTrue);
      expect(visibility.value?.restart.streamId.value, 'stream-2');
      expect(
        (await events)
            .whereType<TimelineOverlayLayerConfigurationChanged>()
            .map((TimelineOverlayLayerConfigurationChanged event) =>
                event.streamId),
        <String>['stream-2', 'stream-2'],
      );

      await h.close();
    });
  });

  group('Task 1.3 - typed runtime failures', () {
    test(
        'normalizes composition profile input rejection and lifecycle failures',
        () async {
      final _RuntimeHarness h = await _harness();

      final missingDuration = await h.runtime.compose(
        _compositionRequest(playback: _playback(duration: Duration.zero)),
      );
      final invalidLength = await h.runtime.compose(
        _compositionRequest(stream: _descriptor(lengthBytes: 0)),
      );
      final duplicateLayers = await h.runtime.compose(
        _compositionRequest(layers: <TimelineOverlayLayer>[
          _progressLayer(id: 'duplicate'),
          _hiddenHeatLayer(id: 'duplicate'),
        ]),
      );
      final missingProfile = await h.runtime.selectProfile(
        streamId: const VirtualMediaStreamId('stream-1'),
        profileId: 'missing-overlay',
      );
      final unavailableInput = await h.runtime.compose(
        _compositionRequest(stream: _descriptor(id: 'missing-stream')),
      );
      final rejected = await h.runtime.compose(
        _compositionRequest(
            playback: _playback(position: Duration(minutes: 2))),
      );
      final invalidLayerConfiguration = await h.runtime.reorderLayers(
        profileId: 'default-overlay',
        layerOrder: const <String>['progress', 'progress'],
      );

      await h.runtime.dispose();
      final disposed = await h.runtime.compose(_compositionRequest());
      final TimelineOverlayRuntime unavailable =
          TimelineOverlayRuntime.unavailable(reason: 'Overlay source missing.');
      final unavailableRuntime =
          await unavailable.compose(_compositionRequest());

      expect(missingDuration.failure?.kind,
          TimelineOverlayRuntimeFailureKind.missingDuration);
      expect(invalidLength.failure?.kind,
          TimelineOverlayRuntimeFailureKind.invalidStreamLength);
      expect(duplicateLayers.failure?.kind,
          TimelineOverlayRuntimeFailureKind.duplicateLayerIdentifier);
      expect(missingProfile.failure?.kind,
          TimelineOverlayRuntimeFailureKind.missingProfile);
      expect(unavailableInput.failure?.kind,
          TimelineOverlayRuntimeFailureKind.unavailableStreamInput);
      expect(rejected.failure?.kind,
          TimelineOverlayRuntimeFailureKind.rejectedComposition);
      expect(invalidLayerConfiguration.failure?.kind,
          TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration);
      expect(
          disposed.failure?.kind, TimelineOverlayRuntimeFailureKind.disposed);
      expect(unavailableRuntime.failure?.kind,
          TimelineOverlayRuntimeFailureKind.unavailable);

      await h.close();
    });
  });

  group('Task 1.4 - invalidations after storage-visible mutations', () {
    test('publishes profile layer snapshot and rejection events after storage',
        () async {
      final _RuntimeHarness h = await _harness();
      final Future<List<CacheInvalidationEvent>> events =
          h.bus.events.take(4).toList();

      await h.runtime.selectProfile(
        streamId: const VirtualMediaStreamId('stream-1'),
        profileId: 'minimal-overlay',
      );
      expect((await h.store.activeProfile('stream-1'))?.profileId,
          'minimal-overlay');

      await h.runtime.setLayerVisibility(
        profileId: 'minimal-overlay',
        layerId: 'heat',
        visible: false,
      );
      expect((await h.store.layersForProfile('minimal-overlay')).last.visible,
          isFalse);

      await h.runtime
          .compose(_compositionRequest(profileId: 'minimal-overlay'));
      expect((await h.store.latestSnapshotMetadata('stream-1'))?.layerCount, 3);

      await h.runtime.compose(
        _compositionRequest(
            playback: _playback(position: Duration(minutes: 2))),
      );
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          rejectedProjection = await h.runtime.snapshot(
        const VirtualMediaStreamId('stream-1'),
      );
      expect(rejectedProjection.value?.latestFailure?.kind,
          TimelineOverlayRuntimeFailureKind.rejectedComposition);
      final TimelineOverlayRuntime restored = TimelineOverlayBootstrap(
        store: h.store,
        composer: DeterministicTimelineOverlayComposer(clock: _now),
        cacheInvalidationBus: h.bus,
        clock: _now,
      ).createRuntime();
      final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>
          restoredProjection = await restored.snapshot(
        const VirtualMediaStreamId('stream-1'),
      );
      expect(restoredProjection.value?.latestFailure?.kind,
          TimelineOverlayRuntimeFailureKind.rejectedComposition);
      expect(
        restoredProjection
            .value?.restart.latestCompositionRejection?.failureKind,
        TimelineOverlayRuntimeFailureKind.rejectedComposition.name,
      );
      expect(
        (await h.store.latestCompositionRejection('stream-1'))?.failureKind,
        TimelineOverlayRuntimeFailureKind.rejectedComposition.name,
      );

      final List<CacheInvalidationEvent> delivered = await events;
      expect(
          delivered
              .whereType<TimelineOverlayLayerConfigurationChanged>()
              .length,
          2);
      expect(delivered.whereType<TimelineOverlaySnapshotRefreshed>().length, 1);
      expect(
          delivered.whereType<TimelineOverlayCompositionRejected>().length, 1);

      await h.close();
    });
  });
}

final class _RuntimeHarness {
  _RuntimeHarness({required this.store, required this.bus}) {
    runtime = TimelineOverlayBootstrap(
      store: store,
      composer: DeterministicTimelineOverlayComposer(
        cacheInvalidationBus: bus,
        clock: _now,
      ),
      cacheInvalidationBus: bus,
      clock: _now,
    ).createRuntime();
  }

  final DeterministicTimelineOverlayStore store;
  final StreamCacheInvalidationBus bus;
  late final TimelineOverlayRuntime runtime;

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
          id: 'opening', position: Duration(seconds: 10), label: 'OP'),
    ],
    heatValues: <TimelineHeatValue>[
      TimelineHeatValue(
        id: 'heat-1',
        range: TimelineTimeRange(
          start: Duration(seconds: 10),
          end: Duration(seconds: 20),
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

StoredTimelineOverlayProfileRecord _profile(
  String id, {
  bool isDefault = false,
}) {
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
