import '../cache_invalidation/cache_invalidation_bus.dart';
import '../storage/diagnostics_storage_contracts.dart';
import 'diagnostics_center.dart';

enum DiagnosticsCenterRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  missingSchema,
  recordFailure,
  snapshotFailure,
  retentionFailure,
  exportFailure,
}

final class DiagnosticsCenterRuntimeFailure {
  const DiagnosticsCenterRuntimeFailure({
    required this.kind,
    required this.message,
  }) : assert(message != '', 'Failure message must not be empty.');

  final DiagnosticsCenterRuntimeFailureKind kind;
  final String message;
}

enum DiagnosticsCenterRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class DiagnosticsCenterRuntimeActionResult<T> {
  const DiagnosticsCenterRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const DiagnosticsCenterRuntimeActionResult.success([T? value])
      : this._(
          kind: DiagnosticsCenterRuntimeActionResultKind.success,
          value: value,
        );

  DiagnosticsCenterRuntimeActionResult.failed(
      DiagnosticsCenterRuntimeFailure failure)
      : this._(
          kind: DiagnosticsCenterRuntimeActionResultKind.failed,
          failure: failure,
        );

  DiagnosticsCenterRuntimeActionResult.unavailable(String message)
      : this._(
          kind: DiagnosticsCenterRuntimeActionResultKind.unavailable,
          failure: DiagnosticsCenterRuntimeFailure(
            kind: DiagnosticsCenterRuntimeFailureKind.unavailable,
            message: message,
          ),
        );

  DiagnosticsCenterRuntimeActionResult.disposed()
      : this._(
          kind: DiagnosticsCenterRuntimeActionResultKind.disposed,
          failure: const DiagnosticsCenterRuntimeFailure(
            kind: DiagnosticsCenterRuntimeFailureKind.disposed,
            message: 'Diagnostics center runtime has been disposed.',
          ),
        );

  final DiagnosticsCenterRuntimeActionResultKind kind;
  final T? value;
  final DiagnosticsCenterRuntimeFailure? failure;

  bool get isSuccess =>
      kind == DiagnosticsCenterRuntimeActionResultKind.success;
}

final class DiagnosticsCenterRuntimeRestartProjection {
  const DiagnosticsCenterRuntimeRestartProjection({
    this.schemaCount = 0,
    this.eventCount = 0,
    this.latestSnapshotId,
    this.latestExportOutcomeId,
    this.latestRetentionStateId,
    this.latestCapability,
  });

  final int schemaCount;
  final int eventCount;
  final String? latestSnapshotId;
  final String? latestExportOutcomeId;
  final String? latestRetentionStateId;
  final StoredDiagnosticsCapabilityRecord? latestCapability;
}

final class DiagnosticsCenterRuntimeProjection {
  const DiagnosticsCenterRuntimeProjection({
    required this.restart,
    this.latestSnapshot,
    this.latestExportOutcome,
    this.latestRetentionState,
  });

  final DiagnosticsCenterRuntimeRestartProjection restart;
  final StoredDiagnosticsSnapshotRecord? latestSnapshot;
  final StoredDiagnosticsExportOutcomeRecord? latestExportOutcome;
  final StoredDiagnosticsRetentionStateRecord? latestRetentionState;
}

final class DiagnosticsCenterRuntimeBootstrap {
  DiagnosticsCenterRuntimeBootstrap({
    required this.store,
    required DiagnosticsEventRegistry registry,
    required this.retentionPolicy,
    required this.redactionPolicy,
    required this.capabilityMatrix,
    CacheInvalidationBus? bus,
  })  : _registry = registry,
        _bus = bus;

  final DiagnosticsStore store;
  final DiagnosticsEventRegistry _registry;
  final DiagnosticsRetentionPolicy retentionPolicy;
  final DiagnosticsRedactionPolicy redactionPolicy;
  final DiagnosticsCapabilityMatrix capabilityMatrix;
  final CacheInvalidationBus? _bus;

  DiagnosticsCenterRuntime createRuntime() {
    return DiagnosticsCenterRuntime._(
      store: store,
      center: DeterministicDiagnosticsCenter(
        registry: _registry,
        retentionPolicy: retentionPolicy,
        redactionPolicy: redactionPolicy,
        capabilityMatrix: capabilityMatrix,
      ),
      registry: _registry,
      capabilityMatrix: capabilityMatrix,
      bus: _bus,
    );
  }
}

final class DiagnosticsCenterRuntime {
  DiagnosticsCenterRuntime._({
    required DiagnosticsStore store,
    required DeterministicDiagnosticsCenter center,
    required DiagnosticsEventRegistry registry,
    required DiagnosticsCapabilityMatrix capabilityMatrix,
    CacheInvalidationBus? bus,
  })  : _store = store,
        _center = center,
        _registry = registry,
        _capabilityMatrix = capabilityMatrix,
        _bus = bus,
        _unavailableReason = null;

  DiagnosticsCenterRuntime.unavailable({required String reason})
      : _store = null,
        _center = null,
        _registry = null,
        _capabilityMatrix = null,
        _bus = null,
        _unavailableReason = reason;

  final DiagnosticsStore? _store;
  final DeterministicDiagnosticsCenter? _center;
  final DiagnosticsEventRegistry? _registry;
  final DiagnosticsCapabilityMatrix? _capabilityMatrix;
  final CacheInvalidationBus? _bus;
  final String? _unavailableReason;
  bool _disposed = false;

  int _eventSeq = 0;

  DiagnosticsStore _requireStore() {
    final DiagnosticsStore? store = _store;
    if (store == null) throw StateError('Store required but unavailable.');
    return store;
  }

  DeterministicDiagnosticsCenter _requireCenter() {
    final DeterministicDiagnosticsCenter? center = _center;
    if (center == null) throw StateError('Center required but unavailable.');
    return center;
  }

  DiagnosticsEventRegistry _requireRegistry() {
    final DiagnosticsEventRegistry? registry = _registry;
    if (registry == null) {
      throw StateError('Registry required but unavailable.');
    }
    return registry;
  }

  DiagnosticsCapabilityMatrix _requireCapabilityMatrix() {
    final DiagnosticsCapabilityMatrix? matrix = _capabilityMatrix;
    if (matrix == null) {
      throw StateError('Capability matrix required but unavailable.');
    }
    return matrix;
  }

  DateTime _now() => DateTime.now().toUtc();

  DiagnosticsCenterRuntimeActionResult<void>? _gate() {
    if (_disposed) {
      return DiagnosticsCenterRuntimeActionResult<void>.disposed();
    }
    final String? unavailableReason = _unavailableReason;
    if (unavailableReason != null) {
      return DiagnosticsCenterRuntimeActionResult<void>.unavailable(
          unavailableReason);
    }
    return null;
  }

  DiagnosticsCenterRuntimeActionResult<T> _castFail<T>(
      DiagnosticsCenterRuntimeActionResult<void> fail) {
    return DiagnosticsCenterRuntimeActionResult<T>._(
      kind: fail.kind,
      failure: fail.failure,
    );
  }

  void _publishEvent(CacheInvalidationEvent event) {
    _bus?.publish(event);
  }

  Future<DiagnosticsCenterRuntimeActionResult<void>> recordSchema(
      DiagnosticsEventSchema schema) async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return gate;

    if (!_requireCapabilityMatrix()
        .supports(DiagnosticsCapability.schemaRegistration)) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
          message: 'Schema registration capability is not supported.',
        ),
      );
    }

    await _requireRegistry().register(schema);

    final DateTime now = _now();
    await _requireStore().storeSchema(StoredDiagnosticsSchemaRecord(
      eventType: schema.type.value,
      category: schema.category,
      version: schema.version,
      defaultSeverity: schema.defaultSeverity,
      requiredPayloadKeys: schema.requiredPayloadKeys,
      capabilityArea: schema.capabilityArea,
      registeredAt: now,
    ));

    _publishEvent(DiagnosticsSchemaRegistered(
      occurredAt: now,
      eventType: schema.type.value,
      category: schema.category.name,
      version: schema.version,
    ));

    return const DiagnosticsCenterRuntimeActionResult<void>.success();
  }

  Future<DiagnosticsCenterRuntimeActionResult<void>> recordEvent(
      DiagnosticsEvent event) async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return gate;

    if (!_requireCapabilityMatrix()
        .supports(DiagnosticsCapability.redactedEventRecording)) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
          message: 'Redacted event recording capability is not supported.',
        ),
      );
    }

    final DiagnosticsEventSchema? schema =
        _requireRegistry().schemaFor(event.type);
    if (schema == null) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.missingSchema,
          message: 'Diagnostics event schema is not registered.',
        ),
      );
    }

    final DiagnosticsOperationOutcome outcome =
        await _requireCenter().record(event);
    if (!outcome.isSuccess) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        DiagnosticsCenterRuntimeFailure(
          kind: _mapFailureKind(outcome.failure!.kind),
          message: outcome.failure!.message,
        ),
      );
    }

    final DateTime now = _now();
    _eventSeq += 1;
    final String eventId =
        'diag-event-${now.millisecondsSinceEpoch}-${_eventSeq}';

    final DiagnosticsEvent redacted = _applyRedaction(event);

    await _requireStore().recordEvent(StoredDiagnosticsEventRecord(
      id: eventId,
      eventType: redacted.type.value,
      schemaVersion: redacted.schemaVersion,
      category: redacted.category,
      severity: redacted.severity,
      occurredAt: redacted.occurredAt,
      sourceModule: redacted.sourceModule,
      correlationId: redacted.correlationId.value,
      redacted: true,
      payload: redacted.payload,
      capabilityArea: redacted.capabilityArea,
    ));

    _publishEvent(DiagnosticsEventRecorded(
      occurredAt: now,
      eventId: eventId,
      eventType: redacted.type.value,
      sourceModule: redacted.sourceModule,
      correlationId: redacted.correlationId.value,
    ));

    return const DiagnosticsCenterRuntimeActionResult<void>.success();
  }

  Future<
      DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>> querySnapshot(
      DiagnosticsQuery query) async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return _castFail(gate);

    if (!_requireCapabilityMatrix()
        .supports(DiagnosticsCapability.snapshotQuery)) {
      return DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
          message: 'Snapshot query capability is not supported.',
        ),
      );
    }

    try {
      final DiagnosticsSnapshot diagnosticsSnapshot =
          await _requireCenter().snapshot(query);

      final DateTime now = _now();
      final String snapshotId = 'diag-snapshot-${now.millisecondsSinceEpoch}';

      final List<String> eventIds = (await _requireStore().queryEvents(
        category: query.category,
        minimumSeverity: query.minimumSeverity,
        startedAt: query.startedAt,
        endedAt: query.endedAt,
        correlationId: query.correlationId?.value,
        sourceModule: query.sourceModule,
        eventTypes: query.eventTypes.map((DiagnosticsEventType t) => t.value),
        capabilityAreas: query.capabilityAreas,
      ))
          .map((StoredDiagnosticsEventRecord event) => event.id)
          .toList();

      await _requireStore().storeSnapshot(StoredDiagnosticsSnapshotRecord(
        id: snapshotId,
        createdAt: now,
        eventIds: eventIds,
        category: query.category,
        minimumSeverity: query.minimumSeverity,
        startedAt: query.startedAt,
        endedAt: query.endedAt,
        correlationId: query.correlationId?.value,
        sourceModule: query.sourceModule,
        eventTypes:
            query.eventTypes.map((DiagnosticsEventType t) => t.value).toList(),
        capabilityAreas: query.capabilityAreas,
      ));

      _publishEvent(DiagnosticsSnapshotCreated(
        occurredAt: now,
        snapshotId: snapshotId,
        eventCount: diagnosticsSnapshot.events.length,
      ));
    } catch (e) {
      return DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>.failed(
        DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.snapshotFailure,
          message: 'Snapshot query failed: $e',
        ),
      );
    }

    return _projection();
  }

  Future<DiagnosticsCenterRuntimeActionResult<void>> enforceRetention() async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return gate;

    if (!_requireCapabilityMatrix()
        .supports(DiagnosticsCapability.retentionEnforcement)) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
          message: 'Retention enforcement capability is not supported.',
        ),
      );
    }

    final DateTime now = _now();
    DiagnosticsRetentionOutcome outcome;
    try {
      outcome = await _requireCenter().enforceRetention(now);
    } catch (e) {
      return DiagnosticsCenterRuntimeActionResult<void>.failed(
        DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.retentionFailure,
          message: 'Retention enforcement failed: $e',
        ),
      );
    }

    final String retentionId = 'diag-retention-${now.millisecondsSinceEpoch}';

    await _requireStore()
        .recordRetentionState(StoredDiagnosticsRetentionStateRecord(
      id: retentionId,
      enforcedAt: outcome.enforcedAt,
      maxEvents: _requireCenter().retentionPolicy.maxEvents,
      maxAge: _requireCenter().retentionPolicy.maxAge,
      removedEventCount: outcome.removedEventCount,
      remainingEventCount: outcome.remainingEventCount,
    ));

    _publishEvent(DiagnosticsRetentionEnforced(
      occurredAt: now,
      retentionStateId: retentionId,
      removedEventCount: outcome.removedEventCount,
      remainingEventCount: outcome.remainingEventCount,
    ));

    return const DiagnosticsCenterRuntimeActionResult<void>.success();
  }

  Future<DiagnosticsCenterRuntimeActionResult<DiagnosticsLocalExportDescriptor>>
      describeLocalExport({
    required DiagnosticsSnapshot snapshot,
    required String format,
  }) async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return _castFail(gate);

    if (!_requireCapabilityMatrix()
        .supports(DiagnosticsCapability.localExportDescriptor)) {
      return DiagnosticsCenterRuntimeActionResult<
          DiagnosticsLocalExportDescriptor>.failed(
        const DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.exportFailure,
          message: 'Local export descriptor capability is not supported.',
        ),
      );
    }

    final DateTime now = _now();
    final String requestId = 'diag-export-req-${now.millisecondsSinceEpoch}';

    await _requireStore()
        .recordExportRequest(StoredDiagnosticsExportRequestRecord(
      id: requestId,
      snapshotId: snapshot.id,
      format: format,
      requestedAt: now,
    ));

    _publishEvent(DiagnosticsExportRequestRecorded(
      occurredAt: now,
      requestId: requestId,
      snapshotId: snapshot.id,
      format: format,
    ));

    DiagnosticsLocalExportDescriptor descriptor;
    try {
      descriptor = await _requireCenter().describeLocalExport(
        snapshot: snapshot,
        format: format,
        now: now,
      );
    } catch (e) {
      return DiagnosticsCenterRuntimeActionResult<
          DiagnosticsLocalExportDescriptor>.failed(
        DiagnosticsCenterRuntimeFailure(
          kind: DiagnosticsCenterRuntimeFailureKind.exportFailure,
          message: 'Local export description failed: $e',
        ),
      );
    }

    final String outcomeId =
        'diag-export-outcome-${now.millisecondsSinceEpoch}';
    final StoredDiagnosticsExportState storedState =
        descriptor.state == DiagnosticsExportState.described
            ? StoredDiagnosticsExportState.described
            : StoredDiagnosticsExportState.unavailable;

    await _requireStore()
        .recordExportOutcome(StoredDiagnosticsExportOutcomeRecord(
      id: outcomeId,
      requestId: requestId,
      snapshotId: snapshot.id,
      format: format,
      state: storedState,
      recordedAt: now,
      redacted: descriptor.redacted,
      uri: descriptor.uri,
      reason: descriptor.reason,
    ));

    _publishEvent(DiagnosticsExportOutcomeRecorded(
      occurredAt: now,
      outcomeId: outcomeId,
      requestId: requestId,
      snapshotId: snapshot.id,
      state: storedState.name,
    ));

    return DiagnosticsCenterRuntimeActionResult<
        DiagnosticsLocalExportDescriptor>.success(descriptor);
  }

  Future<
      DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>> recordCapability({
    required DiagnosticsCapability capability,
    required bool supported,
  }) async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return _castFail(gate);

    final DateTime now = _now();
    final StoredDiagnosticsCapabilityState state = supported
        ? StoredDiagnosticsCapabilityState.supported
        : StoredDiagnosticsCapabilityState.unsupported;

    await _requireStore().storeCapability(StoredDiagnosticsCapabilityRecord(
      capability: capability,
      state: state,
      updatedAt: now,
    ));

    _publishEvent(DiagnosticsCapabilityChanged(
      occurredAt: now,
      capability: capability.name,
      supported: supported,
    ));

    return _projection();
  }

  Future<
      DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>> snapshot() async {
    final DiagnosticsCenterRuntimeActionResult<void>? gate = _gate();
    if (gate != null) return _castFail(gate);
    return _projection();
  }

  void dispose() {
    _disposed = true;
  }

  Future<
      DiagnosticsCenterRuntimeActionResult<
          DiagnosticsCenterRuntimeProjection>> _projection() async {
    final int schemaCount = await _requireStore().schemaCount();
    final List<StoredDiagnosticsEventRecord> events =
        await _requireStore().queryEvents();

    final StoredDiagnosticsRetentionStateRecord? retentionState =
        await _requireStore().latestRetentionState();

    final StoredDiagnosticsSnapshotRecord? latestSnapshot =
        await _requireStore().latestSnapshot();

    final StoredDiagnosticsExportOutcomeRecord? latestExportOutcome =
        await _requireStore().latestExportOutcome();

    final StoredDiagnosticsCapabilityRecord? latestCap = await _requireStore()
        .capability(DiagnosticsCapability.schemaRegistration);

    final DiagnosticsCenterRuntimeRestartProjection restart =
        DiagnosticsCenterRuntimeRestartProjection(
      schemaCount: schemaCount,
      eventCount: events.length,
      latestSnapshotId: latestSnapshot?.id,
      latestExportOutcomeId: latestExportOutcome?.id,
      latestRetentionStateId: retentionState?.id,
      latestCapability: latestCap,
    );

    return DiagnosticsCenterRuntimeActionResult<
        DiagnosticsCenterRuntimeProjection>.success(
      DiagnosticsCenterRuntimeProjection(
        restart: restart,
        latestSnapshot: latestSnapshot,
        latestExportOutcome: latestExportOutcome,
        latestRetentionState: retentionState,
      ),
    );
  }

  DiagnosticsEvent _applyRedaction(DiagnosticsEvent event) {
    final DiagnosticsRedactionPolicy policy = _requireCenter().redactionPolicy;
    final Map<String, Object?> redacted = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in event.payload.entries) {
      redacted[entry.key] = policy.sensitivePayloadKeys.contains(entry.key)
          ? '<redacted>'
          : entry.value;
    }
    return DiagnosticsEvent(
      type: event.type,
      schemaVersion: event.schemaVersion,
      category: event.category,
      severity: event.severity,
      occurredAt: event.occurredAt,
      sourceModule: event.sourceModule,
      correlationId: event.correlationId,
      payload: redacted,
      capabilityArea: event.capabilityArea,
    );
  }

  static DiagnosticsCenterRuntimeFailureKind _mapFailureKind(
      DiagnosticsFailureKind kind) {
    return switch (kind) {
      DiagnosticsFailureKind.capabilityUnsupported =>
        DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
      DiagnosticsFailureKind.schemaNotRegistered =>
        DiagnosticsCenterRuntimeFailureKind.missingSchema,
      DiagnosticsFailureKind.payloadMissingRequiredKey =>
        DiagnosticsCenterRuntimeFailureKind.recordFailure,
      DiagnosticsFailureKind.exportUnavailable =>
        DiagnosticsCenterRuntimeFailureKind.exportFailure,
      DiagnosticsFailureKind.retentionUnavailable =>
        DiagnosticsCenterRuntimeFailureKind.retentionFailure,
    };
  }
}
