enum DiagnosticsCapability {
  schemaRegistration,
  redactedEventRecording,
  snapshotQuery,
  retentionEnforcement,
  localExportDescriptor,
  providerGatewayCorrelation,
}

enum DiagnosticsCapabilityState {
  supported,
  unsupported,
  disabled,
}

final class DiagnosticsCapabilityStatus {
  const DiagnosticsCapabilityStatus({required this.state, this.reason});

  const DiagnosticsCapabilityStatus.supported()
      : state = DiagnosticsCapabilityState.supported,
        reason = null;

  const DiagnosticsCapabilityStatus.unsupported([this.reason])
      : state = DiagnosticsCapabilityState.unsupported;

  const DiagnosticsCapabilityStatus.disabled([this.reason])
      : state = DiagnosticsCapabilityState.disabled;

  final DiagnosticsCapabilityState state;
  final String? reason;

  bool get isSupported => state == DiagnosticsCapabilityState.supported;
}

final class DiagnosticsCapabilityMatrix {
  DiagnosticsCapabilityMatrix({
    Map<DiagnosticsCapability, DiagnosticsCapabilityStatus> capabilities =
        const <DiagnosticsCapability, DiagnosticsCapabilityStatus>{},
  }) : _capabilities = Map<DiagnosticsCapability,
            DiagnosticsCapabilityStatus>.unmodifiable(capabilities);

  final Map<DiagnosticsCapability, DiagnosticsCapabilityStatus> _capabilities;

  DiagnosticsCapabilityStatus statusFor(DiagnosticsCapability capability) =>
      _capabilities[capability] ??
      const DiagnosticsCapabilityStatus.unsupported('Capability not declared.');

  bool supports(DiagnosticsCapability capability) =>
      statusFor(capability).isSupported;
}

enum DiagnosticsFailureKind {
  capabilityUnsupported,
  schemaNotRegistered,
  payloadMissingRequiredKey,
  exportUnavailable,
  retentionUnavailable,
}

final class DiagnosticsFailure {
  const DiagnosticsFailure({required this.kind, required this.message});

  final DiagnosticsFailureKind kind;
  final String message;
}

final class DiagnosticsOperationOutcome {
  const DiagnosticsOperationOutcome.success()
      : failure = null,
        affectedEventCount = 0;

  const DiagnosticsOperationOutcome.failure(this.failure)
      : affectedEventCount = 0;

  const DiagnosticsOperationOutcome.retentionApplied({
    required this.affectedEventCount,
  }) : failure = null;

  final DiagnosticsFailure? failure;
  final int affectedEventCount;

  bool get isSuccess => failure == null;
}

final class DiagnosticsEventType {
  const DiagnosticsEventType(this.value)
      : assert(value != '', 'Diagnostics event type must not be empty.');

  final String value;
}

final class DiagnosticsCorrelationId {
  const DiagnosticsCorrelationId(this.value)
      : assert(value != '', 'Diagnostics correlation id must not be empty.');

  final String value;
}

enum DiagnosticsCategory {
  playback,
  bt,
  provider,
  rss,
  onlineRule,
  networkPolicy,
  cache,
  storage,
  avSync,
}

enum DiagnosticsSeverity {
  trace,
  info,
  warning,
  error,
  critical,
}

final class DiagnosticsEventSchema {
  DiagnosticsEventSchema({
    required this.type,
    required this.category,
    required this.version,
    required this.defaultSeverity,
    Iterable<String> requiredPayloadKeys = const <String>[],
    this.capabilityArea,
  })  : assert(version > 0, 'Diagnostics event schema version must be positive.'),
        requiredPayloadKeys = List<String>.unmodifiable(requiredPayloadKeys);

  final DiagnosticsEventType type;
  final DiagnosticsCategory category;
  final int version;
  final DiagnosticsSeverity defaultSeverity;
  final List<String> requiredPayloadKeys;
  final DiagnosticsCapability? capabilityArea;
}

final class DiagnosticsEvent {
  DiagnosticsEvent({
    required this.type,
    required this.schemaVersion,
    required this.category,
    required this.severity,
    required this.occurredAt,
    required this.sourceModule,
    required this.correlationId,
    Map<String, Object?> payload = const <String, Object?>{},
    this.capabilityArea,
  })  : assert(schemaVersion > 0, 'Diagnostics event schema version must be positive.'),
        assert(sourceModule != '', 'Diagnostics event source module must not be empty.'),
        payload = Map<String, Object?>.unmodifiable(payload);

  final DiagnosticsEventType type;
  final int schemaVersion;
  final DiagnosticsCategory category;
  final DiagnosticsSeverity severity;
  final DateTime occurredAt;
  final String sourceModule;
  final DiagnosticsCorrelationId correlationId;
  final Map<String, Object?> payload;
  final DiagnosticsCapability? capabilityArea;
}

final class DiagnosticsQuery {
  DiagnosticsQuery({
    this.category,
    this.minimumSeverity,
    this.startedAt,
    this.endedAt,
    this.correlationId,
    this.sourceModule,
    Iterable<DiagnosticsEventType> eventTypes = const <DiagnosticsEventType>[],
    Iterable<DiagnosticsCapability> capabilityAreas =
        const <DiagnosticsCapability>[],
  })  : eventTypes = List<DiagnosticsEventType>.unmodifiable(eventTypes),
        capabilityAreas =
            List<DiagnosticsCapability>.unmodifiable(capabilityAreas);

  final DiagnosticsCategory? category;
  final DiagnosticsSeverity? minimumSeverity;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DiagnosticsCorrelationId? correlationId;
  final String? sourceModule;
  final List<DiagnosticsEventType> eventTypes;
  final List<DiagnosticsCapability> capabilityAreas;
}

final class DiagnosticsSnapshot {
  DiagnosticsSnapshot({
    required this.id,
    required this.createdAt,
    required this.query,
    Iterable<DiagnosticsEvent> events = const <DiagnosticsEvent>[],
  }) : events = List<DiagnosticsEvent>.unmodifiable(events);

  final String id;
  final DateTime createdAt;
  final DiagnosticsQuery query;
  final List<DiagnosticsEvent> events;
}

final class DiagnosticsRetentionPolicy {
  const DiagnosticsRetentionPolicy({required this.maxEvents, required this.maxAge})
      : assert(maxEvents > 0, 'Diagnostics retention maxEvents must be positive.');

  final int maxEvents;
  final Duration maxAge;
}

final class DiagnosticsRetentionOutcome {
  const DiagnosticsRetentionOutcome({
    required this.enforcedAt,
    required this.removedEventCount,
    required this.remainingEventCount,
  })  : assert(removedEventCount >= 0, 'removedEventCount must not be negative.'),
        assert(remainingEventCount >= 0, 'remainingEventCount must not be negative.');

  final DateTime enforcedAt;
  final int removedEventCount;
  final int remainingEventCount;
}

final class DiagnosticsRedactionPolicy {
  DiagnosticsRedactionPolicy({Iterable<String> sensitivePayloadKeys = const <String>[]})
      : sensitivePayloadKeys = Set<String>.unmodifiable(sensitivePayloadKeys);

  final Set<String> sensitivePayloadKeys;
}

enum DiagnosticsExportState {
  described,
  unavailable,
}

final class DiagnosticsLocalExportDescriptor {
  const DiagnosticsLocalExportDescriptor({
    required this.id,
    required this.snapshotId,
    required this.format,
    required this.createdAt,
    required this.state,
    required this.redacted,
    this.uri,
    this.reason,
  })  : assert(id != '', 'Diagnostics export id must not be empty.'),
        assert(snapshotId != '', 'Diagnostics export snapshot id must not be empty.'),
        assert(format != '', 'Diagnostics export format must not be empty.');

  final String id;
  final String snapshotId;
  final String format;
  final DateTime createdAt;
  final DiagnosticsExportState state;
  final bool redacted;
  final Uri? uri;
  final String? reason;
}

abstract interface class DiagnosticsEventRegistry {
  Future<void> register(DiagnosticsEventSchema schema);

  DiagnosticsEventSchema? schemaFor(DiagnosticsEventType type);
}

abstract interface class DiagnosticsCenter {
  DiagnosticsRetentionPolicy get retentionPolicy;
  DiagnosticsRedactionPolicy get redactionPolicy;
  DiagnosticsCapabilityMatrix get capabilityMatrix;

  Future<DiagnosticsOperationOutcome> record(DiagnosticsEvent event);

  Stream<DiagnosticsEvent> watch(DiagnosticsQuery query);

  Future<DiagnosticsSnapshot> snapshot(DiagnosticsQuery query);

  Future<DiagnosticsRetentionOutcome> enforceRetention(DateTime now);

  Future<DiagnosticsLocalExportDescriptor> describeLocalExport({
    required DiagnosticsSnapshot snapshot,
    required String format,
    required DateTime now,
  });
}

abstract interface class DiagnosticsExporter {
  Future<DiagnosticsLocalExportDescriptor> describeLocalExport({
    required DiagnosticsSnapshot snapshot,
    required String format,
    required DateTime now,
  });
}

final class DeterministicDiagnosticsEventRegistry
    implements DiagnosticsEventRegistry {
  final Map<String, DiagnosticsEventSchema> _schemas =
      <String, DiagnosticsEventSchema>{};

  @override
  Future<void> register(DiagnosticsEventSchema schema) {
    _schemas[schema.type.value] = schema;
    return Future<void>.value();
  }

  @override
  DiagnosticsEventSchema? schemaFor(DiagnosticsEventType type) =>
      _schemas[type.value];
}

final class DeterministicDiagnosticsCenter implements DiagnosticsCenter {
  DeterministicDiagnosticsCenter({
    required DiagnosticsEventRegistry registry,
    required this.retentionPolicy,
    required this.redactionPolicy,
    required this.capabilityMatrix,
  }) : _registry = registry;

  final DiagnosticsEventRegistry _registry;
  final List<DiagnosticsEvent> _events = <DiagnosticsEvent>[];

  @override
  final DiagnosticsRetentionPolicy retentionPolicy;

  @override
  final DiagnosticsRedactionPolicy redactionPolicy;

  @override
  final DiagnosticsCapabilityMatrix capabilityMatrix;

  @override
  Future<DiagnosticsOperationOutcome> record(DiagnosticsEvent event) {
    if (!capabilityMatrix.supports(DiagnosticsCapability.redactedEventRecording)) {
      return Future<DiagnosticsOperationOutcome>.value(
        const DiagnosticsOperationOutcome.failure(DiagnosticsFailure(
          kind: DiagnosticsFailureKind.capabilityUnsupported,
          message: 'Diagnostics event recording is unavailable.',
        )),
      );
    }
    final DiagnosticsEventSchema? schema = _registry.schemaFor(event.type);
    if (schema == null) {
      return Future<DiagnosticsOperationOutcome>.value(
        const DiagnosticsOperationOutcome.failure(DiagnosticsFailure(
          kind: DiagnosticsFailureKind.schemaNotRegistered,
          message: 'Diagnostics event schema is not registered.',
        )),
      );
    }
    for (final String key in schema.requiredPayloadKeys) {
      if (!event.payload.containsKey(key)) {
        return Future<DiagnosticsOperationOutcome>.value(
          DiagnosticsOperationOutcome.failure(DiagnosticsFailure(
            kind: DiagnosticsFailureKind.payloadMissingRequiredKey,
            message: 'Diagnostics event payload is missing required key: $key.',
          )),
        );
      }
    }
    _events.add(_redact(event));
    return Future<DiagnosticsOperationOutcome>.value(
        const DiagnosticsOperationOutcome.success());
  }

  @override
  Stream<DiagnosticsEvent> watch(DiagnosticsQuery query) =>
      Stream<DiagnosticsEvent>.fromIterable(_filter(query));

  @override
  Future<DiagnosticsSnapshot> snapshot(DiagnosticsQuery query) {
    final DateTime createdAt = DateTime.now().toUtc();
    return Future<DiagnosticsSnapshot>.value(DiagnosticsSnapshot(
      id: 'diagnostics-snapshot-${createdAt.microsecondsSinceEpoch}',
      createdAt: createdAt,
      query: query,
      events: _filter(query),
    ));
  }

  @override
  Future<DiagnosticsRetentionOutcome> enforceRetention(DateTime now) {
    final int before = _events.length;
    final DateTime oldestAllowed = now.subtract(retentionPolicy.maxAge);
    _events.removeWhere((DiagnosticsEvent event) => event.occurredAt.isBefore(oldestAllowed));
    if (_events.length > retentionPolicy.maxEvents) {
      _events.sort((DiagnosticsEvent left, DiagnosticsEvent right) =>
          left.occurredAt.compareTo(right.occurredAt));
      _events.removeRange(0, _events.length - retentionPolicy.maxEvents);
    }
    return Future<DiagnosticsRetentionOutcome>.value(DiagnosticsRetentionOutcome(
      enforcedAt: now,
      removedEventCount: before - _events.length,
      remainingEventCount: _events.length,
    ));
  }

  @override
  Future<DiagnosticsLocalExportDescriptor> describeLocalExport({
    required DiagnosticsSnapshot snapshot,
    required String format,
    required DateTime now,
  }) {
    if (!capabilityMatrix.supports(DiagnosticsCapability.localExportDescriptor)) {
      return Future<DiagnosticsLocalExportDescriptor>.value(
        DiagnosticsLocalExportDescriptor(
          id: 'diagnostics-export-${now.microsecondsSinceEpoch}',
          snapshotId: snapshot.id,
          format: format,
          createdAt: now,
          state: DiagnosticsExportState.unavailable,
          redacted: true,
          reason: 'Diagnostics local export descriptors are unavailable.',
        ),
      );
    }
    return Future<DiagnosticsLocalExportDescriptor>.value(
      DiagnosticsLocalExportDescriptor(
        id: 'diagnostics-export-${now.microsecondsSinceEpoch}',
        snapshotId: snapshot.id,
        format: format,
        createdAt: now,
        state: DiagnosticsExportState.described,
        redacted: true,
        uri: Uri.parse('diagnostics://local/${snapshot.id}'),
      ),
    );
  }

  DiagnosticsEvent _redact(DiagnosticsEvent event) {
    final Map<String, Object?> redacted = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in event.payload.entries) {
      redacted[entry.key] = redactionPolicy.sensitivePayloadKeys.contains(entry.key)
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

  List<DiagnosticsEvent> _filter(DiagnosticsQuery query) {
    final List<DiagnosticsEvent> matching = <DiagnosticsEvent>[
      for (final DiagnosticsEvent event in _events)
        if (_matches(query, event)) event,
    ];
    matching.sort((DiagnosticsEvent left, DiagnosticsEvent right) =>
        left.occurredAt.compareTo(right.occurredAt));
    return matching;
  }

  static bool _matches(DiagnosticsQuery query, DiagnosticsEvent event) {
    if (query.category != null && event.category != query.category) {
      return false;
    }
    if (query.minimumSeverity != null &&
        event.severity.index < query.minimumSeverity!.index) {
      return false;
    }
    if (query.startedAt != null && event.occurredAt.isBefore(query.startedAt!)) {
      return false;
    }
    if (query.endedAt != null && event.occurredAt.isAfter(query.endedAt!)) {
      return false;
    }
    if (query.correlationId != null &&
        event.correlationId.value != query.correlationId!.value) {
      return false;
    }
    if (query.sourceModule != null && event.sourceModule != query.sourceModule) {
      return false;
    }
    if (query.eventTypes.isNotEmpty &&
        !query.eventTypes.any((DiagnosticsEventType type) => type.value == event.type.value)) {
      return false;
    }
    if (query.capabilityAreas.isNotEmpty &&
        (event.capabilityArea == null ||
            !query.capabilityAreas.contains(event.capabilityArea))) {
      return false;
    }
    return true;
  }
}
