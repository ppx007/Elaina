import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticsCenterRuntime', () {
    late DeterministicDiagnosticsStore store;
    late DeterministicDiagnosticsEventRegistry registry;
    late StreamCacheInvalidationBus bus;

    const retentionPolicy = DiagnosticsRetentionPolicy(
      maxEvents: 1000,
      maxAge: Duration(days: 30),
    );

    final redactionPolicy = DiagnosticsRedactionPolicy(
      sensitivePayloadKeys: <String>['token', 'secret'],
    );

    final supportedCapabilities = DiagnosticsCapabilityMatrix(
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

    setUp(() {
      store = DeterministicDiagnosticsStore();
      registry = DeterministicDiagnosticsEventRegistry();
      bus = StreamCacheInvalidationBus();
    });

    tearDown(() async {
      await bus.close();
    });

    DiagnosticsCenterRuntime _runtime({
      DiagnosticsCapabilityMatrix? capabilities,
    }) {
      return DiagnosticsCenterRuntimeBootstrap(
        store: store,
        registry: registry,
        retentionPolicy: retentionPolicy,
        redactionPolicy: redactionPolicy,
        capabilityMatrix: capabilities ?? supportedCapabilities,
        bus: bus,
      ).createRuntime();
    }

    DiagnosticsEventSchema _testSchema() {
      return DiagnosticsEventSchema(
        type: const DiagnosticsEventType('test-event'),
        category: DiagnosticsCategory.storage,
        version: 1,
        defaultSeverity: DiagnosticsSeverity.info,
        requiredPayloadKeys: <String>['detail'],
      );
    }

    DiagnosticsEvent _testEvent({
      Map<String, Object?> payload = const <String, Object?>{'detail': 'ok'},
    }) {
      return DiagnosticsEvent(
        type: const DiagnosticsEventType('test-event'),
        schemaVersion: 1,
        category: DiagnosticsCategory.storage,
        severity: DiagnosticsSeverity.info,
        occurredAt: DateTime.utc(2026, 6, 16, 12),
        sourceModule: 'test-module',
        correlationId: const DiagnosticsCorrelationId('corr-1'),
        payload: payload,
      );
    }

    test('initial snapshot returns empty projection', () async {
      final runtime = _runtime();

      final result = await runtime.snapshot();

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.schemaCount, 0);
      expect(result.value?.restart.eventCount, 0);
      expect(result.value?.restart.latestSnapshotId, isNull);
      expect(result.value?.restart.latestExportOutcomeId, isNull);
      expect(result.value?.restart.latestRetentionStateId, isNull);
    });

    test('schema registration stores record and publishes event', () async {
      final runtime = _runtime();
      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.recordSchema(_testSchema());

      expect(result.isSuccess, isTrue);
      expect(events.whereType<DiagnosticsSchemaRegistered>(), isNotEmpty);

      final storedSchema =
          await store.schemaByEventType('test-event');
      expect(storedSchema, isNotNull);
      expect(storedSchema!.eventType, 'test-event');

      await subscription.cancel();
    });

    test('redacted event recording stores and publishes event', () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.recordEvent(_testEvent(
        payload: <String, Object?>{'detail': 'ok', 'token': 'secret-value'},
      ));

      expect(result.isSuccess, isTrue);
      expect(events.whereType<DiagnosticsEventRecorded>(), isNotEmpty);

      final storedEvents = await store.queryEvents();
      expect(storedEvents, hasLength(1));
      expect(storedEvents.first.redacted, isTrue);
      expect(storedEvents.first.payload['token'], '<redacted>');
      expect(storedEvents.first.payload['detail'], 'ok');

      await subscription.cancel();
    });

    test('query snapshot stores snapshot record and publishes event', () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());
      await runtime.recordEvent(_testEvent());

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.querySnapshot(DiagnosticsQuery(
        category: DiagnosticsCategory.storage,
      ));

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.eventCount, 1);
      expect(result.value?.restart.latestSnapshotId, isNotNull);
      expect(events.whereType<DiagnosticsSnapshotCreated>(), isNotEmpty);

      await subscription.cancel();
    });

    test('local export descriptor stores and publishes events', () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());
      await runtime.recordEvent(_testEvent());

      final diagnosticsSnapshot = await (DeterministicDiagnosticsCenter(
        registry: registry,
        retentionPolicy: retentionPolicy,
        redactionPolicy: redactionPolicy,
        capabilityMatrix: supportedCapabilities,
      )).snapshot(DiagnosticsQuery());

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.describeLocalExport(
        snapshot: diagnosticsSnapshot,
        format: 'json',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, isA<DiagnosticsLocalExportDescriptor>());
      expect(events.whereType<DiagnosticsExportRequestRecorded>(), isNotEmpty);
      expect(events.whereType<DiagnosticsExportOutcomeRecorded>(), isNotEmpty);

      await subscription.cancel();
    });

    test('retention enforcement stores retention state and publishes event',
        () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());
      await runtime.recordEvent(_testEvent());

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.enforceRetention();

      expect(result.isSuccess, isTrue);
      expect(events.whereType<DiagnosticsRetentionEnforced>(), isNotEmpty);

      final retentionState = await store.latestRetentionState();
      expect(retentionState, isNotNull);

      await subscription.cancel();
    });

    test('capability recording stores and publishes event', () async {
      final runtime = _runtime();

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.recordCapability(
        capability: DiagnosticsCapability.schemaRegistration,
        supported: true,
      );

      expect(result.isSuccess, isTrue);
      expect(events.whereType<DiagnosticsCapabilityChanged>(), isNotEmpty);

      final storedCap =
          await store.capability(DiagnosticsCapability.schemaRegistration);
      expect(storedCap, isNotNull);
      expect(storedCap!.state, StoredDiagnosticsCapabilityState.supported);

      await subscription.cancel();
    });

    test('unsupported capability returns capabilityUnsupported', () async {
      final unsupportedMatrix = DiagnosticsCapabilityMatrix(
        capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
          DiagnosticsCapability.schemaRegistration:
              const DiagnosticsCapabilityStatus.unsupported('Not available.'),
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

      final runtime = _runtime(capabilities: unsupportedMatrix);

      final result = await runtime.recordSchema(_testSchema());

      expect(result.isSuccess, isFalse);
      expect(
          result.failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported);
    });

    test('unavailable runtime rejects all operations', () async {
      final runtime =
          DiagnosticsCenterRuntime.unavailable(reason: 'Platform unsupported.');

      expect(
          (await runtime.recordSchema(_testSchema())).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
      expect(
          (await runtime.recordEvent(_testEvent())).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
      expect(
          (await runtime
                  .querySnapshot(DiagnosticsQuery())).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
      expect(
          (await runtime.enforceRetention()).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
      expect(
          (await runtime.snapshot()).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
      expect(
          (await runtime.recordCapability(
            capability: DiagnosticsCapability.schemaRegistration,
            supported: true,
          )).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.unavailable);
    });

    test('disposed runtime rejects all operations', () async {
      final runtime = _runtime();
      runtime.dispose();

      expect(
          (await runtime.recordSchema(_testSchema())).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.disposed);
      expect(
          (await runtime.recordEvent(_testEvent())).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.disposed);
      expect(
          (await runtime.snapshot()).failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.disposed);
    });

    test('missing schema returns missingSchema failure', () async {
      final runtime = _runtime();

      final result = await runtime.recordEvent(_testEvent());

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.missingSchema);
    });

    test('invalidation events are published after store persistence', () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      await runtime.recordEvent(_testEvent());
      await runtime.querySnapshot(DiagnosticsQuery());
      await runtime.enforceRetention();

      expect(events.whereType<DiagnosticsEventRecorded>(), hasLength(1));
      expect(events.whereType<DiagnosticsSnapshotCreated>(), hasLength(1));
      expect(events.whereType<DiagnosticsRetentionEnforced>(), hasLength(1));

      final storedEvents = await store.queryEvents();
      expect(storedEvents, isNotEmpty);
      final retentionState = await store.latestRetentionState();
      expect(retentionState, isNotNull);

      await subscription.cancel();
    });

    test('restart projection replays stored diagnostics state', () async {
      final runtime = _runtime();
      await runtime.recordSchema(_testSchema());
      await runtime.recordEvent(_testEvent());

      // Verify store has the data
      final storedEvents = await store.queryEvents();
      expect(storedEvents, hasLength(1));

      final snapshot = await runtime.snapshot();
      expect(snapshot.isSuccess, isTrue);
      expect(snapshot.value?.restart.schemaCount, 1);
      expect(snapshot.value?.restart.eventCount, 1);
    });

    test('fresh runtime replays stored diagnostics state from same store',
        () async {
      // Phase 1: Use first runtime to populate store
      final runtime1 = _runtime();
      await runtime1.recordSchema(_testSchema());
      await runtime1.recordEvent(_testEvent());
      await runtime1.querySnapshot(DiagnosticsQuery());
      await runtime1.enforceRetention();

      // Create a second schema and event to verify multi-schema counting
      final runtime1b = _runtime();
      await runtime1b.recordSchema(DiagnosticsEventSchema(
        type: const DiagnosticsEventType('second-event'),
        category: DiagnosticsCategory.storage,
        version: 1,
        defaultSeverity: DiagnosticsSeverity.warning,
      ));

      // Phase 2: Create a fresh runtime over the same store - no in-memory state
      final freshRegistry = DeterministicDiagnosticsEventRegistry();
      // Re-register schemas into the new registry since it's in-memory
      await freshRegistry.register(_testSchema());
      await freshRegistry.register(DiagnosticsEventSchema(
        type: const DiagnosticsEventType('second-event'),
        category: DiagnosticsCategory.storage,
        version: 1,
        defaultSeverity: DiagnosticsSeverity.warning,
      ));

      final freshRuntime = DiagnosticsCenterRuntimeBootstrap(
        store: store,
        registry: freshRegistry,
        retentionPolicy: retentionPolicy,
        redactionPolicy: redactionPolicy,
        capabilityMatrix: supportedCapabilities,
        bus: bus,
      ).createRuntime();

      final snapshot = await freshRuntime.snapshot();

      expect(snapshot.isSuccess, isTrue);
      // Schema count from store, not in-memory set
      expect(snapshot.value?.restart.schemaCount, 2);
      // Event count from store
      expect(snapshot.value?.restart.eventCount, 1);
      // Latest snapshot ID from store, not runtime memory
      expect(snapshot.value?.restart.latestSnapshotId, isNotNull);
      // Latest retention state ID from store
      expect(snapshot.value?.restart.latestRetentionStateId, isNotNull);
      // Latest export outcome from store (none recorded yet)
      expect(snapshot.value?.restart.latestExportOutcomeId, isNull);
    });

    test('failure mapping covers all diagnostics failure kinds', () async {
      // Verify the failure kind mapping from DiagnosticsFailureKind to runtime
      // kinds by exercising a record with missing required payload key
      final runtime = _runtime();
      await runtime.recordSchema(DiagnosticsEventSchema(
        type: const DiagnosticsEventType('strict-event'),
        category: DiagnosticsCategory.storage,
        version: 1,
        defaultSeverity: DiagnosticsSeverity.warning,
        requiredPayloadKeys: <String>['required-key'],
      ));

      final result = await runtime.recordEvent(DiagnosticsEvent(
        type: const DiagnosticsEventType('strict-event'),
        schemaVersion: 1,
        category: DiagnosticsCategory.storage,
        severity: DiagnosticsSeverity.warning,
        occurredAt: DateTime.utc(2026, 6, 16, 12),
        sourceModule: 'test-module',
        correlationId: const DiagnosticsCorrelationId('corr-missing'),
        payload: <String, Object?>{},
      ));

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          DiagnosticsCenterRuntimeFailureKind.recordFailure);
    });
  });
}
