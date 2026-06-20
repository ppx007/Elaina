import 'dart:convert';

import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diagnostics runtime implementation', () {
    late DeterministicDiagnosticsStore store;
    late DeterministicDiagnosticsEventRegistry registry;
    late DiagnosticsCenterRuntime runtime;

    setUp(() {
      store = DeterministicDiagnosticsStore();
      registry = DeterministicDiagnosticsEventRegistry();
      runtime = DiagnosticsCenterRuntimeBootstrap(
        store: store,
        registry: registry,
        retentionPolicy: const DiagnosticsRetentionPolicy(
          maxEvents: 100,
          maxAge: Duration(days: 30),
        ),
        redactionPolicy: DiagnosticsRedactionPolicy(
          sensitivePayloadKeys: const <String>['token'],
        ),
        capabilityMatrix: _supportedCapabilities(),
      ).createRuntime();
    });

    test('collector records cache invalidation observation', () async {
      final DiagnosticsInvalidationCollector collector =
          DiagnosticsInvalidationCollector(runtime: runtime);

      final DiagnosticsLocalCollectorOutcome result = await collector.observe(
        DiagnosticsCapabilityChanged(
          occurredAt: DateTime.utc(2026, 6, 18, 12),
          capability: DiagnosticsCapability.snapshotQuery.name,
          supported: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(await store.schemaCount(), 1);

      final List<StoredDiagnosticsEventRecord> events = await store.queryEvents(
        eventTypes: const <String>[diagnosticsInvalidationEventType],
      );
      expect(events, hasLength(1));
      expect(events.single.sourceModule, diagnosticsInvalidationSourceModule);
      expect(events.single.payload[diagnosticsPayloadEventTypeKey],
          'DiagnosticsCapabilityChanged');
    });

    test('collector rejects observations after dispose', () async {
      final DiagnosticsInvalidationCollector collector =
          DiagnosticsInvalidationCollector(runtime: runtime);

      await collector.dispose();
      final DiagnosticsLocalCollectorOutcome result = await collector.observe(
        DiagnosticsCapabilityChanged(
          occurredAt: DateTime.utc(2026, 6, 18, 12),
          capability: DiagnosticsCapability.snapshotQuery.name,
          supported: true,
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(
          result.failure?.kind, DiagnosticsLocalCollectorFailureKind.disposed);
      expect(await store.schemaCount(), 0);
    });

    test('collector preserves runtime rejection as typed failure', () async {
      final DiagnosticsCenterRuntime unsupportedRuntime =
          DiagnosticsCenterRuntimeBootstrap(
        store: DeterministicDiagnosticsStore(),
        registry: DeterministicDiagnosticsEventRegistry(),
        retentionPolicy: const DiagnosticsRetentionPolicy(
          maxEvents: 100,
          maxAge: Duration(days: 30),
        ),
        redactionPolicy: DiagnosticsRedactionPolicy(),
        capabilityMatrix: DiagnosticsCapabilityMatrix(
          capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
            DiagnosticsCapability.schemaRegistration:
                const DiagnosticsCapabilityStatus.unsupported('disabled'),
          },
        ),
      ).createRuntime();
      final DiagnosticsInvalidationCollector collector =
          DiagnosticsInvalidationCollector(runtime: unsupportedRuntime);

      final DiagnosticsLocalCollectorOutcome result = await collector.start();

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          DiagnosticsLocalCollectorFailureKind.runtimeRejected);
      expect(result.failure?.runtimeFailure?.kind,
          DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported);
    });

    test('export bundle builder emits redacted json lines from stored snapshot',
        () async {
      await runtime.recordSchema(DiagnosticsEventSchema(
        type: const DiagnosticsEventType('runtime.impl.event'),
        category: DiagnosticsCategory.cache,
        version: 1,
        defaultSeverity: DiagnosticsSeverity.info,
        requiredPayloadKeys: const <String>['detail'],
      ));
      await runtime.recordEvent(DiagnosticsEvent(
        type: const DiagnosticsEventType('runtime.impl.event'),
        schemaVersion: 1,
        category: DiagnosticsCategory.cache,
        severity: DiagnosticsSeverity.info,
        occurredAt: DateTime.utc(2026, 6, 18, 12),
        sourceModule: 'diagnostics-runtime-impl-test',
        correlationId: const DiagnosticsCorrelationId('corr-runtime-impl'),
        payload: const <String, Object?>{
          'detail': 'stored',
          'token': 'secret-token',
        },
      ));
      final DiagnosticsCenterRuntimeActionResult<
              DiagnosticsCenterRuntimeProjection> snapshotResult =
          await runtime.querySnapshot(DiagnosticsQuery(
        eventTypes: const <DiagnosticsEventType>[
          DiagnosticsEventType('runtime.impl.event'),
        ],
      ));
      final String snapshotId = snapshotResult.value!.latestSnapshot!.id;
      final DiagnosticsLocalExportBundleBuilder builder =
          DiagnosticsLocalExportBundleBuilder(store: store);

      final DiagnosticsLocalExportBundleOutcome result = await builder.build(
        snapshotId: snapshotId,
        format: 'jsonl',
        createdAt: DateTime.utc(2026, 6, 18, 12, 1),
      );

      expect(result.isSuccess, isTrue);
      expect(result.bundle?.eventCount, 1);
      expect(result.bundle?.redacted, isTrue);

      final Map<String, Object?> line =
          jsonDecode(result.bundle!.jsonLines.single) as Map<String, Object?>;
      expect(line['eventType'], 'runtime.impl.event');
      expect((line['payload'] as Map<String, Object?>)['token'], '<redacted>');
    });

    test('export bundle builder reports missing snapshot and disposed state',
        () async {
      final DiagnosticsLocalExportBundleBuilder builder =
          DiagnosticsLocalExportBundleBuilder(store: store);

      final DiagnosticsLocalExportBundleOutcome missing = await builder.build(
        snapshotId: 'missing-snapshot',
        format: 'jsonl',
        createdAt: DateTime.utc(2026, 6, 18, 12),
      );

      builder.dispose();
      final DiagnosticsLocalExportBundleOutcome disposed = await builder.build(
        snapshotId: 'missing-snapshot',
        format: 'jsonl',
        createdAt: DateTime.utc(2026, 6, 18, 12),
      );

      expect(missing.isSuccess, isFalse);
      expect(missing.failure?.kind,
          DiagnosticsLocalExportBundleFailureKind.snapshotNotFound);
      expect(disposed.isSuccess, isFalse);
      expect(disposed.failure?.kind,
          DiagnosticsLocalExportBundleFailureKind.disposed);
    });
  });
}

DiagnosticsCapabilityMatrix _supportedCapabilities() {
  return DiagnosticsCapabilityMatrix(
    capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
      for (final DiagnosticsCapability capability
          in DiagnosticsCapability.values)
        capability: const DiagnosticsCapabilityStatus.supported(),
    },
  );
}
