import '../lib/elaina.dart';

Future<void> main() async {
  final DeterministicDiagnosticsStore store = DeterministicDiagnosticsStore();
  final DeterministicDiagnosticsEventRegistry registry =
      DeterministicDiagnosticsEventRegistry();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();

  const DiagnosticsRetentionPolicy retentionPolicy = DiagnosticsRetentionPolicy(
    maxEvents: 10,
    maxAge: Duration(days: 30),
  );

  final DiagnosticsRedactionPolicy redactionPolicy = DiagnosticsRedactionPolicy(
    sensitivePayloadKeys: <String>['token', 'secret'],
  );

  final DiagnosticsCapabilityMatrix supportedCapabilities =
      DiagnosticsCapabilityMatrix(
    capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
      DiagnosticsCapability.schemaRegistration:
          const DiagnosticsCapabilityStatus.supported(),
      DiagnosticsCapability.redactedEventRecording:
          const DiagnosticsCapabilityStatus.supported(),
      DiagnosticsCapability.snapshotQuery:
          const DiagnosticsCapabilityStatus.supported(),
      DiagnosticsCapability.retentionEnforcement:
          const DiagnosticsCapabilityStatus.supported(),
      DiagnosticsCapability.localExportDescriptor:
          const DiagnosticsCapabilityStatus.supported(),
    },
  );

  final DiagnosticsEventSchema schema = DiagnosticsEventSchema(
    type: const DiagnosticsEventType('diagnostics-check-event'),
    category: DiagnosticsCategory.storage,
    version: 1,
    defaultSeverity: DiagnosticsSeverity.info,
    requiredPayloadKeys: <String>['detail'],
    capabilityArea: DiagnosticsCapability.schemaRegistration,
  );

  final DiagnosticsCenterRuntime runtime = DiagnosticsCenterRuntimeBootstrap(
    store: store,
    registry: registry,
    retentionPolicy: retentionPolicy,
    redactionPolicy: redactionPolicy,
    capabilityMatrix: supportedCapabilities,
    bus: bus,
  ).createRuntime();

  final Future<List<CacheInvalidationEvent>> schemaEventsFuture =
      bus.events.take(1).toList();
  await _expect((await runtime.recordSchema(schema)).isSuccess,
      'Schema registration must succeed.');

  final List<CacheInvalidationEvent> schemaEvents = await schemaEventsFuture;
  await _expect(schemaEvents.single is DiagnosticsSchemaRegistered,
      'Schema registration must publish invalidation.');

  final DiagnosticsEvent event = DiagnosticsEvent(
    type: schema.type,
    schemaVersion: 1,
    category: DiagnosticsCategory.storage,
    severity: DiagnosticsSeverity.info,
    occurredAt: DateTime.utc(2026, 6, 16, 12),
    sourceModule: 'diagnostics-check',
    correlationId: const DiagnosticsCorrelationId('diag-check-1'),
    payload: <String, Object?>{
      'detail': 'ok',
      'token': 'secret-token',
    },
    capabilityArea: DiagnosticsCapability.schemaRegistration,
  );

  final Future<List<CacheInvalidationEvent>> eventEventsFuture =
      bus.events.take(1).toList();
  final DiagnosticsCenterRuntimeActionResult<void> recordEventResult =
      await runtime.recordEvent(event);
  await _expect(
      recordEventResult.isSuccess, 'Redacted event recording must succeed.');
  final List<CacheInvalidationEvent> eventEvents = await eventEventsFuture;
  await _expect(eventEvents.single is DiagnosticsEventRecorded,
      'Event recording must publish invalidation.');

  final Future<List<CacheInvalidationEvent>> snapshotEventsFuture =
      bus.events.take(1).toList();
  final DiagnosticsCenterRuntimeActionResult<DiagnosticsCenterRuntimeProjection>
      snapshotResult = await runtime.querySnapshot(DiagnosticsQuery(
    category: DiagnosticsCategory.storage,
  ));
  await _expect(snapshotResult.isSuccess, 'Snapshot query must succeed.');
  await _expect(snapshotResult.value!.restart.eventCount == 1,
      'Snapshot projection must include one event.');
  await _expect(snapshotResult.value!.latestSnapshot != null,
      'Snapshot query must persist latest snapshot.');
  final List<CacheInvalidationEvent> snapshotEvents =
      await snapshotEventsFuture;
  await _expect(snapshotEvents.single is DiagnosticsSnapshotCreated,
      'Snapshot query must publish invalidation.');

  final DiagnosticsSnapshot snapshot = (await DeterministicDiagnosticsCenter(
    registry: registry,
    retentionPolicy: retentionPolicy,
    redactionPolicy: redactionPolicy,
    capabilityMatrix: supportedCapabilities,
  ).snapshot(DiagnosticsQuery(category: DiagnosticsCategory.storage)));

  final Future<List<CacheInvalidationEvent>> exportEventsFuture =
      bus.events.take(2).toList();
  final DiagnosticsCenterRuntimeActionResult<DiagnosticsLocalExportDescriptor>
      exportResult = await runtime.describeLocalExport(
    snapshot: snapshot,
    format: 'json',
  );
  await _expect(
      exportResult.isSuccess, 'Local export descriptor must succeed.');
  await _expect(exportResult.value!.state == DiagnosticsExportState.described,
      'Local export descriptor must be described.');
  final List<CacheInvalidationEvent> exportEvents = await exportEventsFuture;
  await _expect(
      exportEvents.whereType<DiagnosticsExportRequestRecorded>().length == 1,
      'Export request must publish invalidation.');
  await _expect(
      exportEvents.whereType<DiagnosticsExportOutcomeRecorded>().length == 1,
      'Export outcome must publish invalidation.');

  final Future<List<CacheInvalidationEvent>> retentionEventsFuture =
      bus.events.take(1).toList();
  await _expect((await runtime.enforceRetention()).isSuccess,
      'Retention enforcement must succeed.');
  final List<CacheInvalidationEvent> retentionEvents =
      await retentionEventsFuture;
  await _expect(retentionEvents.single is DiagnosticsRetentionEnforced,
      'Retention enforcement must publish invalidation.');

  final Future<List<CacheInvalidationEvent>> capabilityEventsFuture =
      bus.events.take(1).toList();
  await _expect(
      (await runtime.recordCapability(
        capability: DiagnosticsCapability.schemaRegistration,
        supported: true,
      ))
          .isSuccess,
      'Capability recording must succeed.');
  final List<CacheInvalidationEvent> capabilityEvents =
      await capabilityEventsFuture;
  await _expect(capabilityEvents.single is DiagnosticsCapabilityChanged,
      'Capability recording must publish invalidation.');

  final DiagnosticsCenterRuntime unsupportedRuntime =
      DiagnosticsCenterRuntimeBootstrap(
    store: DeterministicDiagnosticsStore(),
    registry: DeterministicDiagnosticsEventRegistry(),
    retentionPolicy: retentionPolicy,
    redactionPolicy: redactionPolicy,
    capabilityMatrix: DiagnosticsCapabilityMatrix(
      capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
        DiagnosticsCapability.schemaRegistration:
            const DiagnosticsCapabilityStatus.unsupported('Disabled.'),
        DiagnosticsCapability.redactedEventRecording:
            const DiagnosticsCapabilityStatus.supported(),
        DiagnosticsCapability.snapshotQuery:
            const DiagnosticsCapabilityStatus.supported(),
        DiagnosticsCapability.retentionEnforcement:
            const DiagnosticsCapabilityStatus.supported(),
        DiagnosticsCapability.localExportDescriptor:
            const DiagnosticsCapabilityStatus.supported(),
      },
    ),
  ).createRuntime();
  await _expect(
      (await unsupportedRuntime.recordSchema(schema)).failure?.kind ==
          DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
      'Unsupported capability must fail.');

  final List<DiagnosticsCenterRuntimeFailureKind> failureKinds =
      <DiagnosticsCenterRuntimeFailureKind>[
    DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported,
    DiagnosticsCenterRuntimeFailureKind.disposed,
    DiagnosticsCenterRuntimeFailureKind.unavailable,
    DiagnosticsCenterRuntimeFailureKind.missingSchema,
    DiagnosticsCenterRuntimeFailureKind.snapshotFailure,
    DiagnosticsCenterRuntimeFailureKind.retentionFailure,
    DiagnosticsCenterRuntimeFailureKind.exportFailure,
    DiagnosticsCenterRuntimeFailureKind.recordFailure,
  ];
  await _expect(
    failureKinds.length == DiagnosticsCenterRuntimeFailureKind.values.length,
    'Checker must reference all runtime failure kinds.',
  );

  final DiagnosticsCenterRuntime unavailableRuntime =
      DiagnosticsCenterRuntime.unavailable(reason: 'Unavailable for check.');
  await _expect(
      (await unavailableRuntime.snapshot()).failure?.kind ==
          DiagnosticsCenterRuntimeFailureKind.unavailable,
      'Unavailable runtime must fail.');

  runtime.dispose();
  await _expect(
      (await runtime.snapshot()).failure?.kind ==
          DiagnosticsCenterRuntimeFailureKind.disposed,
      'Disposed runtime must fail.');

  final DiagnosticsCenterRuntime freshRuntime =
      DiagnosticsCenterRuntimeBootstrap(
    store: store,
    registry: registry,
    retentionPolicy: retentionPolicy,
    redactionPolicy: redactionPolicy,
    capabilityMatrix: supportedCapabilities,
    bus: bus,
  ).createRuntime();
  final DiagnosticsCenterRuntimeActionResult<DiagnosticsCenterRuntimeProjection>
      freshSnapshot = await freshRuntime.snapshot();
  await _expect(
      freshSnapshot.isSuccess, 'Fresh runtime snapshot must succeed.');
  await _expect(freshSnapshot.value!.restart.schemaCount == 1,
      'Fresh runtime must replay stored schema count.');
  await _expect(freshSnapshot.value!.restart.eventCount == 1,
      'Fresh runtime must replay stored event count.');

  await bus.close();
  // ignore: avoid_print
  print('Diagnostics center runtime checks passed.');
}

Future<void> _expect(bool condition, String message) async {
  if (!condition) {
    throw StateError(message);
  }
}
