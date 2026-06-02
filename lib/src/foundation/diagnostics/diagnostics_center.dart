final class DiagnosticsEventType {
  const DiagnosticsEventType(this.value) : assert(value != '', 'Diagnostics event type must not be empty.');

  final String value;
}

final class DiagnosticsCorrelationId {
  const DiagnosticsCorrelationId(this.value) : assert(value != '', 'Diagnostics correlation id must not be empty.');

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
  })  : assert(version > 0, 'Diagnostics event schema version must be positive.'),
        requiredPayloadKeys = List<String>.unmodifiable(requiredPayloadKeys);

  final DiagnosticsEventType type;
  final DiagnosticsCategory category;
  final int version;
  final DiagnosticsSeverity defaultSeverity;
  final List<String> requiredPayloadKeys;
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
  }) : eventTypes = List<DiagnosticsEventType>.unmodifiable(eventTypes);

  final DiagnosticsCategory? category;
  final DiagnosticsSeverity? minimumSeverity;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DiagnosticsCorrelationId? correlationId;
  final String? sourceModule;
  final List<DiagnosticsEventType> eventTypes;
}

final class DiagnosticsSnapshot {
  DiagnosticsSnapshot({
    required this.createdAt,
    required this.query,
    Iterable<DiagnosticsEvent> events = const <DiagnosticsEvent>[],
  }) : events = List<DiagnosticsEvent>.unmodifiable(events);

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

final class DiagnosticsRedactionPolicy {
  DiagnosticsRedactionPolicy({Iterable<String> sensitivePayloadKeys = const <String>[]})
      : sensitivePayloadKeys = Set<String>.unmodifiable(sensitivePayloadKeys);

  final Set<String> sensitivePayloadKeys;
}

abstract interface class DiagnosticsEventRegistry {
  Future<void> register(DiagnosticsEventSchema schema);

  DiagnosticsEventSchema? schemaFor(DiagnosticsEventType type);
}

abstract interface class DiagnosticsCenter {
  DiagnosticsRetentionPolicy get retentionPolicy;
  DiagnosticsRedactionPolicy get redactionPolicy;

  Future<void> record(DiagnosticsEvent event);

  Stream<DiagnosticsEvent> watch(DiagnosticsQuery query);

  Future<DiagnosticsSnapshot> snapshot(DiagnosticsQuery query);
}

abstract interface class DiagnosticsExporter {
  Future<String> export(DiagnosticsSnapshot snapshot);
}
