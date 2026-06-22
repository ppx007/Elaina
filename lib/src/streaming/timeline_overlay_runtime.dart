import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/timeline_overlay_storage_contracts.dart';
import 'timeline_overlay.dart';
import 'virtual_media_stream.dart';

final class TimelineOverlayBootstrap {
  TimelineOverlayBootstrap({
    required this.store,
    required this.composer,
    this.cacheInvalidationBus,
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  final TimelineOverlayStore store;
  final TimelineOverlayComposer composer;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function() _clock;

  TimelineOverlayRuntime createRuntime() {
    return TimelineOverlayRuntime(
      store: store,
      composer: composer,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: _clock,
    );
  }
}

enum TimelineOverlayRuntimeFailureKind {
  missingDuration,
  invalidStreamLength,
  duplicateLayerIdentifier,
  missingProfile,
  unavailableStreamInput,
  rejectedComposition,
  invalidLayerConfiguration,
  disposed,
  unavailable,
}

final class TimelineOverlayRuntimeFailure implements Exception {
  const TimelineOverlayRuntimeFailure(
      {required this.kind, required this.message});

  final TimelineOverlayRuntimeFailureKind kind;
  final String message;
}

enum TimelineOverlayRuntimeActionResultKind {
  success,
  failed,
  disposed,
  unavailable,
}

final class TimelineOverlayRuntimeActionResult<T> {
  const TimelineOverlayRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const TimelineOverlayRuntimeActionResult.success(T value)
      : this._(
          kind: TimelineOverlayRuntimeActionResultKind.success,
          value: value,
        );

  const TimelineOverlayRuntimeActionResult.failed(
    TimelineOverlayRuntimeFailure failure,
  ) : this._(
          kind: TimelineOverlayRuntimeActionResultKind.failed,
          failure: failure,
        );

  const TimelineOverlayRuntimeActionResult.disposed(
    TimelineOverlayRuntimeFailure failure,
  ) : this._(
          kind: TimelineOverlayRuntimeActionResultKind.disposed,
          failure: failure,
        );

  const TimelineOverlayRuntimeActionResult.unavailable(
    TimelineOverlayRuntimeFailure failure,
  ) : this._(
          kind: TimelineOverlayRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  final TimelineOverlayRuntimeActionResultKind kind;
  final T? value;
  final TimelineOverlayRuntimeFailure? failure;

  bool get isSuccess => kind == TimelineOverlayRuntimeActionResultKind.success;
}

final class TimelineOverlayRuntimeCompositionRequest {
  TimelineOverlayRuntimeCompositionRequest({
    required this.profileId,
    required this.stream,
    required this.playback,
    Iterable<StreamBufferedRange> bufferedRanges =
        const <StreamBufferedRange>[],
    Iterable<TimelinePieceSegment> pieces = const <TimelinePieceSegment>[],
    Iterable<TimelinePriorityWindow> priorityWindows =
        const <TimelinePriorityWindow>[],
    Iterable<TimelineMarker> markers = const <TimelineMarker>[],
    Iterable<TimelineHeatValue> heatValues = const <TimelineHeatValue>[],
    Iterable<TimelineOverlayLayer> layers = const <TimelineOverlayLayer>[],
  })  : bufferedRanges = List<StreamBufferedRange>.unmodifiable(bufferedRanges),
        pieces = List<TimelinePieceSegment>.unmodifiable(pieces),
        priorityWindows =
            List<TimelinePriorityWindow>.unmodifiable(priorityWindows),
        markers = List<TimelineMarker>.unmodifiable(markers),
        heatValues = List<TimelineHeatValue>.unmodifiable(heatValues),
        layers = List<TimelineOverlayLayer>.unmodifiable(layers);

  final String profileId;
  final VirtualMediaStreamDescriptor stream;
  final TimelinePlaybackSnapshot playback;
  final List<StreamBufferedRange> bufferedRanges;
  final List<TimelinePieceSegment> pieces;
  final List<TimelinePriorityWindow> priorityWindows;
  final List<TimelineMarker> markers;
  final List<TimelineHeatValue> heatValues;
  final List<TimelineOverlayLayer> layers;
}

final class TimelineOverlayRuntimeRestartProjection {
  const TimelineOverlayRuntimeRestartProjection({
    required this.streamId,
    this.activeProfileId,
    this.latestSnapshotMetadata,
    this.latestCompositionRejection,
  });

  final VirtualMediaStreamId streamId;
  final String? activeProfileId;
  final StoredTimelineOverlaySnapshotMetadataRecord? latestSnapshotMetadata;
  final StoredTimelineOverlayCompositionRejectionRecord?
      latestCompositionRejection;
}

final class TimelineOverlayRuntimeProjection {
  TimelineOverlayRuntimeProjection({
    required this.snapshot,
    required this.restart,
    required Iterable<TimelineOverlayLayer> layers,
    this.activeProfileId,
    this.latestSnapshotMetadata,
    this.latestFailure,
  }) : layers = List<TimelineOverlayLayer>.unmodifiable(layers);

  final TimelineOverlaySnapshot snapshot;
  final String? activeProfileId;
  final List<TimelineOverlayLayer> layers;
  final StoredTimelineOverlaySnapshotMetadataRecord? latestSnapshotMetadata;
  final TimelineOverlayRuntimeFailure? latestFailure;
  final TimelineOverlayRuntimeRestartProjection restart;
}

/// Runtime for composing and persisting playback timeline overlays.
///
/// It keeps overlay profiles, latest snapshots, and rejection records outside
/// the player UI so buffering/piece/marker visualizations can be rebuilt after
/// restart without re-running playback.
final class TimelineOverlayRuntime {
  TimelineOverlayRuntime({
    required TimelineOverlayStore store,
    required TimelineOverlayComposer composer,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _store = store,
        _composer = composer,
        _cacheInvalidationBus = cacheInvalidationBus,
        _clock = clock ?? _defaultClock,
        _unavailableReason = null;

  TimelineOverlayRuntime.unavailable({required String reason})
      : _store = DeterministicTimelineOverlayStore(),
        _composer = DeterministicTimelineOverlayComposer(),
        _cacheInvalidationBus = null,
        _clock = _defaultClock,
        _unavailableReason = reason;

  final TimelineOverlayStore _store;
  final TimelineOverlayComposer _composer;
  final CacheInvalidationBus? _cacheInvalidationBus;
  final DateTime Function() _clock;
  final String? _unavailableReason;
  final Map<String, TimelineOverlayRuntimeFailure> _latestFailuresByStream =
      <String, TimelineOverlayRuntimeFailure>{};
  bool _disposed = false;

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      compose(TimelineOverlayRuntimeCompositionRequest request) async {
    final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>?
        gated = _gate<TimelineOverlayRuntimeProjection>();
    if (gated != null) return gated;

    final TimelineOverlayRuntimeFailure? preflight =
        await _compositionPreflight(request);
    if (preflight != null) {
      return _failed(preflight, streamId: request.stream.id.value);
    }

    final List<TimelineOverlayLayer> layers = request.layers.isEmpty
        ? await _layersForProfile(request.profileId)
        : request.layers;
    final TimelineOverlayCompositionOutcome outcome = _safeComposer().compose(
      TimelineOverlayCompositionInput(
        stream: request.stream,
        playback: request.playback,
        bufferedRanges: request.bufferedRanges,
        pieces: request.pieces,
        priorityWindows: request.priorityWindows,
        markers: request.markers,
        heatValues: request.heatValues,
        layers: layers,
      ),
    );
    if (!outcome.isSuccess) {
      final TimelineOverlayRuntimeFailure failure =
          _mapCompositionFailure(outcome.failure!);
      _latestFailuresByStream[request.stream.id.value] = failure;
      await _store.recordCompositionRejection(
        StoredTimelineOverlayCompositionRejectionRecord(
          streamId: request.stream.id.value,
          profileId: request.profileId,
          failureKind: failure.kind.name,
          message: failure.message,
          rejectedAt: _clock(),
        ),
      );
      _cacheInvalidationBus?.publish(TimelineOverlayCompositionRejected(
        occurredAt: _clock(),
        streamId: request.stream.id.value,
        failureKind: failure.kind.name,
      ));
      return TimelineOverlayRuntimeActionResult<
          TimelineOverlayRuntimeProjection>.failed(failure);
    }

    final TimelineOverlaySnapshot snapshot =
        _immutableSnapshot(outcome.snapshot!);
    final DateTime now = _clock();
    await _store.setActiveProfile(StoredActiveTimelineOverlayProfileRecord(
      streamId: request.stream.id.value,
      profileId: request.profileId,
      selectedAt: now,
    ));
    await _store.storeLayers(
      profileId: request.profileId,
      layers: <StoredTimelineOverlayLayerRecord>[
        for (final TimelineOverlayLayer layer in snapshot.layers)
          _storedLayer(request.profileId, layer, now),
      ],
    );
    final StoredTimelineOverlaySnapshotMetadataRecord metadata =
        StoredTimelineOverlaySnapshotMetadataRecord(
      streamId: request.stream.id.value,
      profileId: request.profileId,
      positionMillis: snapshot.position.inMilliseconds,
      durationMillis: snapshot.duration.inMilliseconds,
      layerCount: snapshot.layers.length,
      composedAt: snapshot.composedAt ?? now,
    );
    await _store.recordSnapshotMetadata(metadata);
    await _store.clearCompositionRejection(request.stream.id.value);
    _latestFailuresByStream.remove(request.stream.id.value);
    final TimelineOverlayRuntimeProjection projection =
        TimelineOverlayRuntimeProjection(
      snapshot: snapshot,
      activeProfileId: request.profileId,
      layers: snapshot.layers,
      latestSnapshotMetadata: metadata,
      restart: TimelineOverlayRuntimeRestartProjection(
        streamId: request.stream.id,
        activeProfileId: request.profileId,
        latestSnapshotMetadata: metadata,
      ),
    );
    _cacheInvalidationBus?.publish(TimelineOverlaySnapshotRefreshed(
      occurredAt: metadata.composedAt,
      streamId: request.stream.id.value,
      layerCount: snapshot.layers.length,
    ));
    return TimelineOverlayRuntimeActionResult<
        TimelineOverlayRuntimeProjection>.success(projection);
  }

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      selectProfile({
    required VirtualMediaStreamId streamId,
    required String profileId,
  }) async {
    final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>?
        gated = _gate<TimelineOverlayRuntimeProjection>();
    if (gated != null) return gated;
    final StoredTimelineOverlayProfileRecord? profile =
        await _store.findProfileById(profileId);
    if (profile == null) {
      return _failed(const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.missingProfile,
        message: 'Timeline overlay profile was not found.',
      ));
    }
    final DateTime now = _clock();
    await _store.setActiveProfile(StoredActiveTimelineOverlayProfileRecord(
      streamId: streamId.value,
      profileId: profileId,
      selectedAt: now,
    ));
    final TimelineOverlayRuntimeProjection projection =
        await _projectionFromStore(streamId);
    _cacheInvalidationBus?.publish(TimelineOverlayLayerConfigurationChanged(
      occurredAt: now,
      streamId: streamId.value,
      profileId: profileId,
    ));
    return TimelineOverlayRuntimeActionResult<
        TimelineOverlayRuntimeProjection>.success(projection);
  }

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      setLayerVisibility({
    VirtualMediaStreamId? streamId,
    required String profileId,
    required String layerId,
    required bool visible,
  }) async {
    return _mutateLayers(
      streamId: streamId,
      profileId: profileId,
      mutate: (List<StoredTimelineOverlayLayerRecord> layers, DateTime now) {
        return <StoredTimelineOverlayLayerRecord>[
          for (final StoredTimelineOverlayLayerRecord layer in layers)
            layer.layerId == layerId
                ? _storedLayerFromRecord(layer,
                    visible: visible, updatedAt: now)
                : layer,
        ];
      },
    );
  }

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      reorderLayers({
    VirtualMediaStreamId? streamId,
    required String profileId,
    required Iterable<String> layerOrder,
  }) async {
    final List<String> orderedIds = <String>[...layerOrder];
    if (orderedIds.toSet().length != orderedIds.length) {
      return _failed(const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
        message: 'Layer order contains duplicate layer identifiers.',
      ));
    }
    return _mutateLayers(
      streamId: streamId,
      profileId: profileId,
      mutate: (List<StoredTimelineOverlayLayerRecord> layers, DateTime now) {
        final Map<String, StoredTimelineOverlayLayerRecord> byId =
            <String, StoredTimelineOverlayLayerRecord>{
          for (final StoredTimelineOverlayLayerRecord layer in layers)
            layer.layerId: layer,
        };
        if (orderedIds.any((String layerId) => !byId.containsKey(layerId)) ||
            orderedIds.length != byId.length) {
          throw const TimelineOverlayRuntimeFailure(
            kind: TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
            message:
                'Layer order must contain every stored layer exactly once.',
          );
        }
        return <StoredTimelineOverlayLayerRecord>[
          for (int index = 0; index < orderedIds.length; index += 1)
            _storedLayerFromRecord(byId[orderedIds[index]]!,
                order: index, updatedAt: now),
        ];
      },
    );
  }

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      snapshot(VirtualMediaStreamId streamId) async {
    final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>?
        gated = _gate<TimelineOverlayRuntimeProjection>();
    if (gated != null) return gated;
    return TimelineOverlayRuntimeActionResult<
            TimelineOverlayRuntimeProjection>.success(
        await _projectionFromStore(streamId));
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  Future<TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>>
      _mutateLayers({
    VirtualMediaStreamId? streamId,
    required String profileId,
    required List<StoredTimelineOverlayLayerRecord> Function(
      List<StoredTimelineOverlayLayerRecord> layers,
      DateTime now,
    ) mutate,
  }) async {
    final TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection>?
        gated = _gate<TimelineOverlayRuntimeProjection>();
    if (gated != null) return gated;
    if (await _store.findProfileById(profileId) == null) {
      return _failed(const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.missingProfile,
        message: 'Timeline overlay profile was not found.',
      ));
    }
    final DateTime now = _clock();
    final List<StoredTimelineOverlayLayerRecord> layers =
        await _store.layersForProfile(profileId);
    late final List<StoredTimelineOverlayLayerRecord> updated;
    try {
      updated = mutate(layers, now);
    } on TimelineOverlayRuntimeFailure catch (failure) {
      return _failed(failure);
    }
    if (_hasDuplicateStoredLayers(updated)) {
      return _failed(const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
        message: 'Layer configuration contains duplicate layer identifiers.',
      ));
    }
    final List<StoredActiveTimelineOverlayProfileRecord> activeStreams =
        await _store.activeProfilesForProfile(profileId);
    final List<StoredActiveTimelineOverlayProfileRecord> targetStreams =
        streamId == null
            ? activeStreams
            : <StoredActiveTimelineOverlayProfileRecord>[
                for (final StoredActiveTimelineOverlayProfileRecord active
                    in activeStreams)
                  if (active.streamId == streamId.value) active,
              ];
    if (targetStreams.isEmpty) {
      return _failed(const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
        message: 'Layer profile is not active for the requested stream.',
      ));
    }
    await _store.storeLayers(profileId: profileId, layers: updated);
    final VirtualMediaStreamId projectionStreamId =
        VirtualMediaStreamId(targetStreams.first.streamId);
    final TimelineOverlayRuntimeProjection projection =
        await _projectionFromStore(projectionStreamId,
            profileIdOverride: profileId);
    for (final StoredActiveTimelineOverlayProfileRecord active
        in targetStreams) {
      _cacheInvalidationBus?.publish(TimelineOverlayLayerConfigurationChanged(
        occurredAt: now,
        streamId: active.streamId,
        profileId: profileId,
      ));
    }
    return TimelineOverlayRuntimeActionResult<
        TimelineOverlayRuntimeProjection>.success(projection);
  }

  TimelineOverlayRuntimeActionResult<T>? _gate<T>() {
    if (_disposed) {
      return TimelineOverlayRuntimeActionResult<T>.disposed(
        const TimelineOverlayRuntimeFailure(
          kind: TimelineOverlayRuntimeFailureKind.disposed,
          message: 'Timeline overlay runtime is disposed.',
        ),
      );
    }
    if (_unavailableReason != null) {
      return TimelineOverlayRuntimeActionResult<T>.unavailable(
        TimelineOverlayRuntimeFailure(
          kind: TimelineOverlayRuntimeFailureKind.unavailable,
          message: _unavailableReason,
        ),
      );
    }
    return null;
  }

  Future<TimelineOverlayRuntimeFailure?> _compositionPreflight(
    TimelineOverlayRuntimeCompositionRequest request,
  ) async {
    if (request.playback.duration == Duration.zero) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.missingDuration,
        message: 'Timeline overlay requires playback duration.',
      );
    }
    if (request.stream.lengthBytes <= 0) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.invalidStreamLength,
        message: 'Timeline overlay requires a positive stream length.',
      );
    }
    if (_hasDuplicateLayers(request.layers)) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.duplicateLayerIdentifier,
        message: 'Timeline overlay layers contain duplicate identifiers.',
      );
    }
    if (!_streamInputsMatch(request)) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.unavailableStreamInput,
        message: 'Timeline overlay input does not belong to the stream.',
      );
    }
    if (await _store.findProfileById(request.profileId) == null) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.missingProfile,
        message: 'Timeline overlay profile was not found.',
      );
    }
    if (_hasDuplicateLayers(await _layersForProfile(request.profileId))) {
      return const TimelineOverlayRuntimeFailure(
        kind: TimelineOverlayRuntimeFailureKind.duplicateLayerIdentifier,
        message:
            'Timeline overlay stored layers contain duplicate identifiers.',
      );
    }
    return null;
  }

  TimelineOverlayRuntimeActionResult<TimelineOverlayRuntimeProjection> _failed(
    TimelineOverlayRuntimeFailure failure, {
    String? streamId,
  }) {
    if (streamId != null) {
      _latestFailuresByStream[streamId] = failure;
    }
    return TimelineOverlayRuntimeActionResult<
        TimelineOverlayRuntimeProjection>.failed(failure);
  }

  TimelineOverlayComposer _safeComposer() {
    if (_composer is DeterministicTimelineOverlayComposer) {
      return DeterministicTimelineOverlayComposer(clock: _clock);
    }
    return _composer;
  }

  Future<List<TimelineOverlayLayer>> _layersForProfile(String profileId) async {
    return <TimelineOverlayLayer>[
      for (final StoredTimelineOverlayLayerRecord record
          in await _store.layersForProfile(profileId))
        _layerFromStored(record),
    ];
  }

  Future<TimelineOverlayRuntimeProjection> _projectionFromStore(
    VirtualMediaStreamId streamId, {
    String? profileIdOverride,
  }) async {
    final StoredActiveTimelineOverlayProfileRecord? active =
        await _store.activeProfile(streamId.value);
    final String? profileId = profileIdOverride ?? active?.profileId;
    final List<TimelineOverlayLayer> layers = profileId == null
        ? const <TimelineOverlayLayer>[]
        : await _layersForProfile(profileId);
    final StoredTimelineOverlaySnapshotMetadataRecord? metadata =
        await _store.latestSnapshotMetadata(streamId.value);
    final StoredTimelineOverlayCompositionRejectionRecord? rejection =
        await _store.latestCompositionRejection(streamId.value);
    final TimelineOverlayRuntimeFailure? latestFailure =
        _latestFailuresByStream[streamId.value] ??
            (rejection == null ? null : _failureFromStored(rejection));
    final TimelineOverlaySnapshot snapshot = TimelineOverlaySnapshot(
      streamId: streamId,
      duration: Duration(milliseconds: metadata?.durationMillis ?? 0),
      position: Duration(milliseconds: metadata?.positionMillis ?? 0),
      buffered: const <TimelineTimeRange>[],
      pieces: const <TimelinePieceSegment>[],
      layers: List<TimelineOverlayLayer>.unmodifiable(layers),
      composedAt: metadata?.composedAt,
    );
    return TimelineOverlayRuntimeProjection(
      snapshot: snapshot,
      activeProfileId: profileId,
      layers: layers,
      latestSnapshotMetadata: metadata,
      latestFailure: latestFailure,
      restart: TimelineOverlayRuntimeRestartProjection(
        streamId: streamId,
        activeProfileId: profileId,
        latestSnapshotMetadata: metadata,
        latestCompositionRejection: rejection,
      ),
    );
  }

  TimelineOverlayRuntimeFailure _mapCompositionFailure(
    TimelineOverlayCompositionFailure failure,
  ) {
    return TimelineOverlayRuntimeFailure(
      kind: switch (failure.kind) {
        TimelineOverlayCompositionFailureKind.durationUnavailable =>
          TimelineOverlayRuntimeFailureKind.missingDuration,
        TimelineOverlayCompositionFailureKind.streamUnavailable =>
          TimelineOverlayRuntimeFailureKind.invalidStreamLength,
        TimelineOverlayCompositionFailureKind.invalidLayerConfiguration =>
          TimelineOverlayRuntimeFailureKind.invalidLayerConfiguration,
        TimelineOverlayCompositionFailureKind.playbackUnavailable ||
        TimelineOverlayCompositionFailureKind.positionOutOfRange =>
          TimelineOverlayRuntimeFailureKind.rejectedComposition,
      },
      message: failure.message,
    );
  }

  TimelineOverlayRuntimeFailure _failureFromStored(
    StoredTimelineOverlayCompositionRejectionRecord rejection,
  ) {
    return TimelineOverlayRuntimeFailure(
      kind: _failureKindFromName(rejection.failureKind),
      message: rejection.message,
    );
  }

  TimelineOverlayRuntimeFailureKind _failureKindFromName(String name) {
    for (final TimelineOverlayRuntimeFailureKind kind
        in TimelineOverlayRuntimeFailureKind.values) {
      if (kind.name == name) return kind;
    }
    return TimelineOverlayRuntimeFailureKind.rejectedComposition;
  }
}

DateTime _defaultClock() => DateTime.now().toUtc();

bool _hasDuplicateLayers(Iterable<TimelineOverlayLayer> layers) {
  final Set<String> ids = <String>{};
  for (final TimelineOverlayLayer layer in layers) {
    if (!ids.add(layer.id)) return true;
  }
  return false;
}

bool _hasDuplicateStoredLayers(
    Iterable<StoredTimelineOverlayLayerRecord> layers) {
  final Set<String> ids = <String>{};
  for (final StoredTimelineOverlayLayerRecord layer in layers) {
    if (!ids.add(layer.layerId)) return true;
  }
  return false;
}

bool _streamInputsMatch(TimelineOverlayRuntimeCompositionRequest request) {
  final String streamId = request.stream.id.value;
  return request.bufferedRanges
          .every((StreamBufferedRange range) => range.mediaId == streamId) &&
      request.pieces.every((TimelinePieceSegment piece) =>
          piece.byteRange == null ||
          piece.byteRange!.streamId.value == streamId) &&
      request.priorityWindows.every((TimelinePriorityWindow window) =>
          window.byteRange.streamId.value == streamId);
}

TimelineOverlaySnapshot _immutableSnapshot(TimelineOverlaySnapshot snapshot) {
  return TimelineOverlaySnapshot(
    streamId: snapshot.streamId,
    duration: snapshot.duration,
    position: snapshot.position,
    buffered: List<TimelineTimeRange>.unmodifiable(snapshot.buffered),
    pieces: List<TimelinePieceSegment>.unmodifiable(snapshot.pieces),
    layers: List<TimelineOverlayLayer>.unmodifiable(snapshot.layers),
    priorityWindows:
        List<TimelinePriorityWindow>.unmodifiable(snapshot.priorityWindows),
    markers: List<TimelineMarker>.unmodifiable(snapshot.markers),
    heatValues: List<TimelineHeatValue>.unmodifiable(snapshot.heatValues),
    composedAt: snapshot.composedAt,
  );
}

TimelineOverlayLayer _layerFromStored(StoredTimelineOverlayLayerRecord record) {
  return TimelineOverlayLayer(
    id: record.layerId,
    kind: switch (record.kind) {
      StoredTimelineOverlayLayerKind.playbackProgress =>
        TimelineOverlayLayerKind.playbackProgress,
      StoredTimelineOverlayLayerKind.bufferedRanges =>
        TimelineOverlayLayerKind.bufferedRanges,
      StoredTimelineOverlayLayerKind.pieceMap =>
        TimelineOverlayLayerKind.pieceMap,
      StoredTimelineOverlayLayerKind.priorityWindow =>
        TimelineOverlayLayerKind.priorityWindow,
      StoredTimelineOverlayLayerKind.marker => TimelineOverlayLayerKind.marker,
      StoredTimelineOverlayLayerKind.heat => TimelineOverlayLayerKind.heat,
    },
    visible: record.visible,
    order: record.order,
  );
}

StoredTimelineOverlayLayerRecord _storedLayer(
  String profileId,
  TimelineOverlayLayer layer,
  DateTime now,
) {
  return StoredTimelineOverlayLayerRecord(
    profileId: profileId,
    layerId: layer.id,
    kind: switch (layer.kind) {
      TimelineOverlayLayerKind.playbackProgress =>
        StoredTimelineOverlayLayerKind.playbackProgress,
      TimelineOverlayLayerKind.bufferedRanges =>
        StoredTimelineOverlayLayerKind.bufferedRanges,
      TimelineOverlayLayerKind.pieceMap =>
        StoredTimelineOverlayLayerKind.pieceMap,
      TimelineOverlayLayerKind.priorityWindow =>
        StoredTimelineOverlayLayerKind.priorityWindow,
      TimelineOverlayLayerKind.marker => StoredTimelineOverlayLayerKind.marker,
      TimelineOverlayLayerKind.heat => StoredTimelineOverlayLayerKind.heat,
    },
    visible: layer.visible,
    order: layer.order,
    updatedAt: now,
  );
}

StoredTimelineOverlayLayerRecord _storedLayerFromRecord(
  StoredTimelineOverlayLayerRecord record, {
  bool? visible,
  int? order,
  required DateTime updatedAt,
}) {
  return StoredTimelineOverlayLayerRecord(
    profileId: record.profileId,
    layerId: record.layerId,
    kind: record.kind,
    visible: visible ?? record.visible,
    order: order ?? record.order,
    updatedAt: updatedAt,
  );
}
