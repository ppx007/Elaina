// Timeline overlay contract tests define projection composition semantics
// before runtime storage and widget rendering are involved.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeline overlay store persists profiles layers and snapshot metadata',
      () async {
    final DeterministicTimelineOverlayStore store =
        DeterministicTimelineOverlayStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 6, 12);

    await store.storeProfile(StoredTimelineOverlayProfileRecord(
      id: 'default-overlay',
      displayName: 'Default Overlay',
      isDefault: true,
      createdAt: observedAt,
      updatedAt: observedAt,
    ));
    await store.setActiveProfile(StoredActiveTimelineOverlayProfileRecord(
      streamId: 'stream-1',
      profileId: 'default-overlay',
      selectedAt: observedAt,
    ));
    await store.storeLayers(
      profileId: 'default-overlay',
      layers: <StoredTimelineOverlayLayerRecord>[
        StoredTimelineOverlayLayerRecord(
          profileId: 'default-overlay',
          layerId: 'priority-windows',
          kind: StoredTimelineOverlayLayerKind.priorityWindow,
          visible: true,
          order: 2,
          updatedAt: observedAt,
        ),
        StoredTimelineOverlayLayerRecord(
          profileId: 'default-overlay',
          layerId: 'playback-progress',
          kind: StoredTimelineOverlayLayerKind.playbackProgress,
          visible: true,
          order: 0,
          updatedAt: observedAt,
        ),
      ],
    );
    await store
        .recordSnapshotMetadata(StoredTimelineOverlaySnapshotMetadataRecord(
      streamId: 'stream-1',
      profileId: 'default-overlay',
      positionMillis: 1000,
      durationMillis: 60000,
      layerCount: 2,
      composedAt: observedAt,
    ));

    expect((await store.findProfileById('default-overlay'))?.isDefault, isTrue);
    expect(
        (await store.activeProfile('stream-1'))?.profileId, 'default-overlay');
    expect((await store.layersForProfile('default-overlay')).first.layerId,
        'playback-progress');
    expect((await store.latestSnapshotMetadata('stream-1'))?.layerCount, 2);
  });

  test(
      'composer creates layered snapshot from buffered and priority projections',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicTimelineOverlayComposer composer =
        DeterministicTimelineOverlayComposer(
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );
    final Future<CacheInvalidationEvent> event = bus.events.first;

    final TimelineOverlayCompositionOutcome outcome =
        composer.compose(_input());
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isTrue);
    expect(outcome.snapshot?.streamId.value, 'stream-1');
    expect(outcome.snapshot?.buffered.single.end, const Duration(seconds: 15));
    expect(outcome.snapshot?.pieces.single.state, TimelinePieceState.buffered);
    expect(outcome.snapshot?.priorityWindows.single.priority, 'critical');
    expect(
      outcome.snapshot?.layers.map((TimelineOverlayLayer layer) => layer.kind),
      containsAll(<TimelineOverlayLayerKind>[
        TimelineOverlayLayerKind.playbackProgress,
        TimelineOverlayLayerKind.bufferedRanges,
        TimelineOverlayLayerKind.pieceMap,
        TimelineOverlayLayerKind.priorityWindow,
        TimelineOverlayLayerKind.marker,
        TimelineOverlayLayerKind.heat,
      ]),
    );
    expect(delivered, isA<TimelineOverlaySnapshotRefreshed>());
    await bus.close();
  });

  test('composer keeps explicit layer visibility and ordering independent', () {
    final DeterministicTimelineOverlayComposer composer =
        DeterministicTimelineOverlayComposer(
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );

    final TimelineOverlayCompositionOutcome outcome =
        composer.compose(TimelineOverlayCompositionInput(
      stream: _descriptor(),
      playback: TimelinePlaybackSnapshot(
        position: Duration(seconds: 5),
        duration: Duration(minutes: 1),
      ),
      layers: const <TimelineOverlayLayer>[
        TimelineOverlayLayer(
            id: 'heat',
            kind: TimelineOverlayLayerKind.heat,
            visible: false,
            order: 2),
        TimelineOverlayLayer(
            id: 'progress',
            kind: TimelineOverlayLayerKind.playbackProgress,
            visible: true,
            order: 0),
      ],
    ));

    expect(outcome.isSuccess, isTrue);
    expect(outcome.snapshot?.layers.first.id, 'progress');
    expect(outcome.snapshot?.layers.last.visible, isFalse);
  });

  test('composer rejects missing duration with typed failure and invalidation',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DeterministicTimelineOverlayComposer composer =
        DeterministicTimelineOverlayComposer(
      cacheInvalidationBus: bus,
      clock: () => DateTime.utc(2026, 6, 6, 12),
    );
    final Future<CacheInvalidationEvent> event = bus.events.first;

    final TimelineOverlayCompositionOutcome outcome =
        composer.compose(TimelineOverlayCompositionInput(
      stream: _descriptor(),
      playback: TimelinePlaybackSnapshot(
          position: Duration.zero, duration: Duration.zero),
    ));
    final CacheInvalidationEvent delivered = await event;

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.kind,
        TimelineOverlayCompositionFailureKind.durationUnavailable);
    expect(delivered, isA<TimelineOverlayCompositionRejected>());
    await bus.close();
  });

  test('cache invalidation bus supports timeline layer configuration events',
      () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final Future<CacheInvalidationEvent> event = bus.events.first;

    bus.publish(TimelineOverlayLayerConfigurationChanged(
      occurredAt: DateTime.utc(2026, 6, 6, 12),
      streamId: 'stream-1',
      profileId: 'default-overlay',
    ));

    expect(await event, isA<TimelineOverlayLayerConfigurationChanged>());
    await bus.close();
  });
}

TimelineOverlayCompositionInput _input() {
  return TimelineOverlayCompositionInput(
    stream: _descriptor(),
    playback: TimelinePlaybackSnapshot(
      position: Duration(seconds: 10),
      duration: Duration(minutes: 1),
    ),
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
            start: Duration(seconds: 10), end: Duration(seconds: 20)),
        intensity: 0.75,
      ),
    ],
  );
}

VirtualMediaStreamDescriptor _descriptor() {
  return const VirtualMediaStreamDescriptor(
    id: VirtualMediaStreamId('stream-1'),
    taskId: BtTaskId('task-1'),
    fileIndex: BtFileIndex(0),
    lengthBytes: 4096,
  );
}
