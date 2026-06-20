import '../diagnostics/diagnostics_center.dart';

enum StoredDiagnosticsCapabilityState {
  supported,
  unsupported,
  disabled,
}

enum StoredDiagnosticsExportState {
  requested,
  described,
  unavailable,
}

final class StoredDiagnosticsSchemaRecord {
  StoredDiagnosticsSchemaRecord({
    required this.eventType,
    required this.category,
    required this.version,
    required this.defaultSeverity,
    required this.registeredAt,
    Iterable<String> requiredPayloadKeys = const <String>[],
    this.capabilityArea,
  })  : assert(eventType != '',
            'Diagnostics schema event type must not be empty.'),
        assert(version > 0, 'Diagnostics schema version must be positive.'),
        requiredPayloadKeys = List<String>.unmodifiable(requiredPayloadKeys);

  final String eventType;
  final DiagnosticsCategory category;
  final int version;
  final DiagnosticsSeverity defaultSeverity;
  final List<String> requiredPayloadKeys;
  final DiagnosticsCapability? capabilityArea;
  final DateTime registeredAt;
}

final class StoredDiagnosticsEventRecord {
  StoredDiagnosticsEventRecord({
    required this.id,
    required this.eventType,
    required this.schemaVersion,
    required this.category,
    required this.severity,
    required this.occurredAt,
    required this.sourceModule,
    required this.correlationId,
    required this.redacted,
    Map<String, Object?> payload = const <String, Object?>{},
    this.capabilityArea,
  })  : assert(id != '', 'Diagnostics event id must not be empty.'),
        assert(eventType != '', 'Diagnostics event type must not be empty.'),
        assert(
            schemaVersion > 0, 'Diagnostics schema version must be positive.'),
        assert(
            sourceModule != '', 'Diagnostics source module must not be empty.'),
        assert(correlationId != '',
            'Diagnostics correlation id must not be empty.'),
        payload = Map<String, Object?>.unmodifiable(payload);

  final String id;
  final String eventType;
  final int schemaVersion;
  final DiagnosticsCategory category;
  final DiagnosticsSeverity severity;
  final DateTime occurredAt;
  final String sourceModule;
  final String correlationId;
  final Map<String, Object?> payload;
  final bool redacted;
  final DiagnosticsCapability? capabilityArea;
}

final class StoredDiagnosticsSnapshotRecord {
  StoredDiagnosticsSnapshotRecord({
    required this.id,
    required this.createdAt,
    required Iterable<String> eventIds,
    this.category,
    this.minimumSeverity,
    this.startedAt,
    this.endedAt,
    this.correlationId,
    this.sourceModule,
    Iterable<String> eventTypes = const <String>[],
    Iterable<DiagnosticsCapability> capabilityAreas =
        const <DiagnosticsCapability>[],
  })  : assert(id != '', 'Diagnostics snapshot id must not be empty.'),
        eventIds = List<String>.unmodifiable(eventIds),
        eventTypes = List<String>.unmodifiable(eventTypes),
        capabilityAreas =
            List<DiagnosticsCapability>.unmodifiable(capabilityAreas);

  final String id;
  final DateTime createdAt;
  final List<String> eventIds;
  final DiagnosticsCategory? category;
  final DiagnosticsSeverity? minimumSeverity;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? correlationId;
  final String? sourceModule;
  final List<String> eventTypes;
  final List<DiagnosticsCapability> capabilityAreas;
}

final class StoredDiagnosticsExportRequestRecord {
  const StoredDiagnosticsExportRequestRecord({
    required this.id,
    required this.snapshotId,
    required this.format,
    required this.requestedAt,
  })  : assert(id != '', 'Diagnostics export request id must not be empty.'),
        assert(snapshotId != '',
            'Diagnostics export snapshot id must not be empty.'),
        assert(format != '', 'Diagnostics export format must not be empty.');

  final String id;
  final String snapshotId;
  final String format;
  final DateTime requestedAt;
}

final class StoredDiagnosticsExportOutcomeRecord {
  const StoredDiagnosticsExportOutcomeRecord({
    required this.id,
    required this.requestId,
    required this.snapshotId,
    required this.format,
    required this.state,
    required this.recordedAt,
    required this.redacted,
    this.uri,
    this.reason,
  })  : assert(id != '', 'Diagnostics export outcome id must not be empty.'),
        assert(requestId != '',
            'Diagnostics export request id must not be empty.'),
        assert(snapshotId != '',
            'Diagnostics export snapshot id must not be empty.'),
        assert(format != '', 'Diagnostics export format must not be empty.');

  final String id;
  final String requestId;
  final String snapshotId;
  final String format;
  final StoredDiagnosticsExportState state;
  final DateTime recordedAt;
  final bool redacted;
  final Uri? uri;
  final String? reason;
}

final class StoredDiagnosticsRetentionStateRecord {
  const StoredDiagnosticsRetentionStateRecord({
    required this.id,
    required this.enforcedAt,
    required this.maxEvents,
    required this.maxAge,
    required this.removedEventCount,
    required this.remainingEventCount,
  })  : assert(id != '', 'Diagnostics retention state id must not be empty.'),
        assert(
            maxEvents > 0, 'Diagnostics retention maxEvents must be positive.'),
        assert(
            removedEventCount >= 0, 'removedEventCount must not be negative.'),
        assert(remainingEventCount >= 0,
            'remainingEventCount must not be negative.');

  final String id;
  final DateTime enforcedAt;
  final int maxEvents;
  final Duration maxAge;
  final int removedEventCount;
  final int remainingEventCount;
}

final class StoredDiagnosticsCapabilityRecord {
  const StoredDiagnosticsCapabilityRecord({
    required this.capability,
    required this.state,
    required this.updatedAt,
    this.reason,
  });

  final DiagnosticsCapability capability;
  final StoredDiagnosticsCapabilityState state;
  final DateTime updatedAt;
  final String? reason;
}

abstract interface class DiagnosticsStore {
  Future<void> storeSchema(StoredDiagnosticsSchemaRecord schema);

  Future<StoredDiagnosticsSchemaRecord?> schemaByEventType(String eventType);

  Future<void> recordEvent(StoredDiagnosticsEventRecord event);

  Future<List<StoredDiagnosticsEventRecord>> queryEvents({
    DiagnosticsCategory? category,
    DiagnosticsSeverity? minimumSeverity,
    DateTime? startedAt,
    DateTime? endedAt,
    String? correlationId,
    String? sourceModule,
    Iterable<String> eventTypes = const <String>[],
    Iterable<DiagnosticsCapability> capabilityAreas =
        const <DiagnosticsCapability>[],
  });

  Future<void> storeSnapshot(StoredDiagnosticsSnapshotRecord snapshot);

  Future<StoredDiagnosticsSnapshotRecord?> snapshotById(String id);

  Future<void> recordExportRequest(
      StoredDiagnosticsExportRequestRecord request);

  Future<void> recordExportOutcome(
      StoredDiagnosticsExportOutcomeRecord outcome);

  Future<StoredDiagnosticsExportOutcomeRecord?> exportOutcomeById(String id);

  Future<void> recordRetentionState(
      StoredDiagnosticsRetentionStateRecord state);

  Future<StoredDiagnosticsRetentionStateRecord?> latestRetentionState();

  Future<void> storeCapability(StoredDiagnosticsCapabilityRecord capability);

  Future<StoredDiagnosticsCapabilityRecord?> capability(
      DiagnosticsCapability capability);

  Future<int> schemaCount();

  Future<StoredDiagnosticsSnapshotRecord?> latestSnapshot();

  Future<StoredDiagnosticsExportOutcomeRecord?> latestExportOutcome();
}

final class DeterministicDiagnosticsStore implements DiagnosticsStore {
  final Map<String, StoredDiagnosticsSchemaRecord> _schemasByType =
      <String, StoredDiagnosticsSchemaRecord>{};
  final Map<String, StoredDiagnosticsEventRecord> _eventsById =
      <String, StoredDiagnosticsEventRecord>{};
  final Map<String, StoredDiagnosticsSnapshotRecord> _snapshotsById =
      <String, StoredDiagnosticsSnapshotRecord>{};
  final Map<String, StoredDiagnosticsExportRequestRecord> _exportRequestsById =
      <String, StoredDiagnosticsExportRequestRecord>{};
  final Map<String, StoredDiagnosticsExportOutcomeRecord> _exportOutcomesById =
      <String, StoredDiagnosticsExportOutcomeRecord>{};
  final List<StoredDiagnosticsRetentionStateRecord> _retentionStates =
      <StoredDiagnosticsRetentionStateRecord>[];
  final Map<DiagnosticsCapability, StoredDiagnosticsCapabilityRecord>
      _capabilities =
      <DiagnosticsCapability, StoredDiagnosticsCapabilityRecord>{};

  @override
  Future<StoredDiagnosticsCapabilityRecord?> capability(
      DiagnosticsCapability capability) {
    return Future<StoredDiagnosticsCapabilityRecord?>.value(
        _capabilities[capability]);
  }

  @override
  Future<StoredDiagnosticsExportOutcomeRecord?> exportOutcomeById(String id) {
    return Future<StoredDiagnosticsExportOutcomeRecord?>.value(
        _exportOutcomesById[id]);
  }

  @override
  Future<StoredDiagnosticsRetentionStateRecord?> latestRetentionState() {
    return Future<StoredDiagnosticsRetentionStateRecord?>.value(
        _retentionStates.isEmpty ? null : _retentionStates.last);
  }

  @override
  Future<List<StoredDiagnosticsEventRecord>> queryEvents({
    DiagnosticsCategory? category,
    DiagnosticsSeverity? minimumSeverity,
    DateTime? startedAt,
    DateTime? endedAt,
    String? correlationId,
    String? sourceModule,
    Iterable<String> eventTypes = const <String>[],
    Iterable<DiagnosticsCapability> capabilityAreas =
        const <DiagnosticsCapability>[],
  }) {
    final Set<String> eventTypeSet = eventTypes.toSet();
    final Set<DiagnosticsCapability> capabilityAreaSet =
        capabilityAreas.toSet();
    final List<StoredDiagnosticsEventRecord> events =
        <StoredDiagnosticsEventRecord>[
      for (final StoredDiagnosticsEventRecord event in _eventsById.values)
        if ((category == null || event.category == category) &&
            (minimumSeverity == null ||
                event.severity.index >= minimumSeverity.index) &&
            (startedAt == null || !event.occurredAt.isBefore(startedAt)) &&
            (endedAt == null || !event.occurredAt.isAfter(endedAt)) &&
            (correlationId == null || event.correlationId == correlationId) &&
            (sourceModule == null || event.sourceModule == sourceModule) &&
            (eventTypeSet.isEmpty || eventTypeSet.contains(event.eventType)) &&
            (capabilityAreaSet.isEmpty ||
                (event.capabilityArea != null &&
                    capabilityAreaSet.contains(event.capabilityArea))))
          event,
    ];
    events.sort((StoredDiagnosticsEventRecord left,
            StoredDiagnosticsEventRecord right) =>
        left.occurredAt.compareTo(right.occurredAt));
    return Future<List<StoredDiagnosticsEventRecord>>.value(events);
  }

  @override
  Future<void> recordEvent(StoredDiagnosticsEventRecord event) {
    _eventsById[event.id] = event;
    return Future<void>.value();
  }

  @override
  Future<void> recordExportOutcome(
      StoredDiagnosticsExportOutcomeRecord outcome) {
    _exportOutcomesById[outcome.id] = outcome;
    return Future<void>.value();
  }

  @override
  Future<void> recordExportRequest(
      StoredDiagnosticsExportRequestRecord request) {
    _exportRequestsById[request.id] = request;
    return Future<void>.value();
  }

  @override
  Future<void> recordRetentionState(
      StoredDiagnosticsRetentionStateRecord state) {
    _retentionStates.add(state);
    return Future<void>.value();
  }

  @override
  Future<StoredDiagnosticsSchemaRecord?> schemaByEventType(String eventType) {
    return Future<StoredDiagnosticsSchemaRecord?>.value(
        _schemasByType[eventType]);
  }

  @override
  Future<StoredDiagnosticsSnapshotRecord?> snapshotById(String id) {
    return Future<StoredDiagnosticsSnapshotRecord?>.value(_snapshotsById[id]);
  }

  @override
  Future<void> storeCapability(StoredDiagnosticsCapabilityRecord capability) {
    _capabilities[capability.capability] = capability;
    return Future<void>.value();
  }

  @override
  Future<void> storeSchema(StoredDiagnosticsSchemaRecord schema) {
    _schemasByType[schema.eventType] = schema;
    return Future<void>.value();
  }

  @override
  Future<void> storeSnapshot(StoredDiagnosticsSnapshotRecord snapshot) {
    _snapshotsById[snapshot.id] = snapshot;
    return Future<void>.value();
  }

  @override
  Future<int> schemaCount() {
    return Future<int>.value(_schemasByType.length);
  }

  @override
  Future<StoredDiagnosticsSnapshotRecord?> latestSnapshot() {
    if (_snapshotsById.isEmpty) {
      return Future<StoredDiagnosticsSnapshotRecord?>.value(null);
    }
    final List<StoredDiagnosticsSnapshotRecord> sorted = _snapshotsById.values
        .toList()
      ..sort((StoredDiagnosticsSnapshotRecord left,
              StoredDiagnosticsSnapshotRecord right) =>
          left.createdAt.compareTo(right.createdAt));
    return Future<StoredDiagnosticsSnapshotRecord?>.value(sorted.last);
  }

  @override
  Future<StoredDiagnosticsExportOutcomeRecord?> latestExportOutcome() {
    if (_exportOutcomesById.isEmpty) {
      return Future<StoredDiagnosticsExportOutcomeRecord?>.value(null);
    }
    final List<StoredDiagnosticsExportOutcomeRecord> sorted =
        _exportOutcomesById.values.toList()
          ..sort((StoredDiagnosticsExportOutcomeRecord left,
                  StoredDiagnosticsExportOutcomeRecord right) =>
              left.recordedAt.compareTo(right.recordedAt));
    return Future<StoredDiagnosticsExportOutcomeRecord?>.value(sorted.last);
  }
}
