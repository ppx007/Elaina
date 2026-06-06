enum StoredTimelineOverlayLayerKind {
  playbackProgress,
  bufferedRanges,
  pieceMap,
  priorityWindow,
  marker,
  heat,
}

final class StoredTimelineOverlayLayerRecord {
  const StoredTimelineOverlayLayerRecord({
    required this.profileId,
    required this.layerId,
    required this.kind,
    required this.visible,
    required this.order,
    required this.updatedAt,
  })  : assert(
            profileId != '', 'Timeline overlay profile id must not be empty.'),
        assert(layerId != '', 'Timeline overlay layer id must not be empty.'),
        assert(
            order >= 0, 'Timeline overlay layer order must not be negative.');

  final String profileId;
  final String layerId;
  final StoredTimelineOverlayLayerKind kind;
  final bool visible;
  final int order;
  final DateTime updatedAt;
}

final class StoredTimelineOverlayProfileRecord {
  const StoredTimelineOverlayProfileRecord({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  })  : assert(id != '', 'Timeline overlay profile id must not be empty.'),
        assert(displayName != '',
            'Timeline overlay profile displayName must not be empty.');

  final String id;
  final String displayName;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class StoredActiveTimelineOverlayProfileRecord {
  const StoredActiveTimelineOverlayProfileRecord({
    required this.streamId,
    required this.profileId,
    required this.selectedAt,
  })  : assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(
            profileId != '', 'Timeline overlay profile id must not be empty.');

  final String streamId;
  final String profileId;
  final DateTime selectedAt;
}

final class StoredTimelineOverlaySnapshotMetadataRecord {
  const StoredTimelineOverlaySnapshotMetadataRecord({
    required this.streamId,
    required this.profileId,
    required this.positionMillis,
    required this.durationMillis,
    required this.layerCount,
    required this.composedAt,
  })  : assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(
            profileId != '', 'Timeline overlay profile id must not be empty.'),
        assert(positionMillis >= 0, 'positionMillis must not be negative.'),
        assert(durationMillis >= 0, 'durationMillis must not be negative.'),
        assert(layerCount >= 0, 'layerCount must not be negative.');

  final String streamId;
  final String profileId;
  final int positionMillis;
  final int durationMillis;
  final int layerCount;
  final DateTime composedAt;
}

abstract interface class TimelineOverlayStore {
  Future<StoredTimelineOverlayProfileRecord> storeProfile(
      StoredTimelineOverlayProfileRecord profile);

  Future<StoredTimelineOverlayProfileRecord?> findProfileById(String profileId);

  Future<List<StoredTimelineOverlayProfileRecord>> listProfiles();

  Future<void> setActiveProfile(
      StoredActiveTimelineOverlayProfileRecord active);

  Future<StoredActiveTimelineOverlayProfileRecord?> activeProfile(
      String streamId);

  Future<void> storeLayers(
      {required String profileId,
      required Iterable<StoredTimelineOverlayLayerRecord> layers});

  Future<List<StoredTimelineOverlayLayerRecord>> layersForProfile(
      String profileId);

  Future<void> recordSnapshotMetadata(
      StoredTimelineOverlaySnapshotMetadataRecord metadata);

  Future<StoredTimelineOverlaySnapshotMetadataRecord?> latestSnapshotMetadata(
      String streamId);
}

final class DeterministicTimelineOverlayStore implements TimelineOverlayStore {
  DeterministicTimelineOverlayStore(
      {Iterable<StoredTimelineOverlayProfileRecord> seedProfiles =
          const <StoredTimelineOverlayProfileRecord>[]}) {
    for (final StoredTimelineOverlayProfileRecord profile in seedProfiles) {
      _profilesById[profile.id] = profile;
    }
  }

  final Map<String, StoredTimelineOverlayProfileRecord> _profilesById =
      <String, StoredTimelineOverlayProfileRecord>{};
  final Map<String, StoredActiveTimelineOverlayProfileRecord> _activeByStream =
      <String, StoredActiveTimelineOverlayProfileRecord>{};
  final Map<String, List<StoredTimelineOverlayLayerRecord>> _layersByProfileId =
      <String, List<StoredTimelineOverlayLayerRecord>>{};
  final Map<String, StoredTimelineOverlaySnapshotMetadataRecord>
      _latestSnapshotByStream =
      <String, StoredTimelineOverlaySnapshotMetadataRecord>{};

  @override
  Future<StoredActiveTimelineOverlayProfileRecord?> activeProfile(
      String streamId) {
    return Future<StoredActiveTimelineOverlayProfileRecord?>.value(
        _activeByStream[streamId]);
  }

  @override
  Future<StoredTimelineOverlayProfileRecord?> findProfileById(
      String profileId) {
    return Future<StoredTimelineOverlayProfileRecord?>.value(
        _profilesById[profileId]);
  }

  @override
  Future<StoredTimelineOverlaySnapshotMetadataRecord?> latestSnapshotMetadata(
      String streamId) {
    return Future<StoredTimelineOverlaySnapshotMetadataRecord?>.value(
        _latestSnapshotByStream[streamId]);
  }

  @override
  Future<List<StoredTimelineOverlayLayerRecord>> layersForProfile(
      String profileId) {
    return Future<List<StoredTimelineOverlayLayerRecord>>.value(
      <StoredTimelineOverlayLayerRecord>[...?_layersByProfileId[profileId]]
        ..sort((StoredTimelineOverlayLayerRecord left,
                StoredTimelineOverlayLayerRecord right) =>
            left.order.compareTo(right.order)),
    );
  }

  @override
  Future<List<StoredTimelineOverlayProfileRecord>> listProfiles() {
    return Future<List<StoredTimelineOverlayProfileRecord>>.value(
        <StoredTimelineOverlayProfileRecord>[..._profilesById.values]);
  }

  @override
  Future<void> recordSnapshotMetadata(
      StoredTimelineOverlaySnapshotMetadataRecord metadata) {
    _latestSnapshotByStream[metadata.streamId] = metadata;
    return Future<void>.value();
  }

  @override
  Future<void> setActiveProfile(
      StoredActiveTimelineOverlayProfileRecord active) {
    _activeByStream[active.streamId] = active;
    return Future<void>.value();
  }

  @override
  Future<void> storeLayers(
      {required String profileId,
      required Iterable<StoredTimelineOverlayLayerRecord> layers}) {
    _layersByProfileId[profileId] = <StoredTimelineOverlayLayerRecord>[
      ...layers
    ]..sort((StoredTimelineOverlayLayerRecord left,
            StoredTimelineOverlayLayerRecord right) =>
        left.order.compareTo(right.order));
    return Future<void>.value();
  }

  @override
  Future<StoredTimelineOverlayProfileRecord> storeProfile(
      StoredTimelineOverlayProfileRecord profile) {
    _profilesById[profile.id] = profile;
    return Future<StoredTimelineOverlayProfileRecord>.value(profile);
  }
}
