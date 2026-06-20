import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'registry center redaction filtering retention and local export are deterministic',
      () async {
    final DateTime base = DateTime.utc(2026, 6, 11, 12);
    final DeterministicDiagnosticsEventRegistry registry =
        DeterministicDiagnosticsEventRegistry();
    await registry.register(DiagnosticsEventSchema(
      type: const DiagnosticsEventType('provider.failure'),
      category: DiagnosticsCategory.provider,
      version: 1,
      defaultSeverity: DiagnosticsSeverity.error,
      requiredPayloadKeys: const <String>['message', 'token'],
      capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
    ));
    final DeterministicDiagnosticsCenter center =
        DeterministicDiagnosticsCenter(
      registry: registry,
      retentionPolicy: const DiagnosticsRetentionPolicy(
          maxEvents: 1, maxAge: Duration(days: 1)),
      redactionPolicy: DiagnosticsRedactionPolicy(
          sensitivePayloadKeys: const <String>['token']),
      capabilityMatrix: DiagnosticsCapabilityMatrix(
        capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
          for (final DiagnosticsCapability capability
              in DiagnosticsCapability.values)
            capability: const DiagnosticsCapabilityStatus.supported(),
        },
      ),
    );

    final DiagnosticsOperationOutcome recorded = await center.record(
      DiagnosticsEvent(
        type: const DiagnosticsEventType('provider.failure'),
        schemaVersion: 1,
        category: DiagnosticsCategory.provider,
        severity: DiagnosticsSeverity.error,
        occurredAt: base,
        sourceModule: 'provider-gateway',
        correlationId: const DiagnosticsCorrelationId('corr-a'),
        capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
        payload: const <String, Object?>{
          'message': 'Provider failed.',
          'token': 'secret-token',
        },
      ),
    );
    await center.record(
      DiagnosticsEvent(
        type: const DiagnosticsEventType('provider.failure'),
        schemaVersion: 1,
        category: DiagnosticsCategory.provider,
        severity: DiagnosticsSeverity.warning,
        occurredAt: base.add(const Duration(minutes: 1)),
        sourceModule: 'provider-gateway',
        correlationId: const DiagnosticsCorrelationId('corr-b'),
        capabilityArea: DiagnosticsCapability.providerGatewayCorrelation,
        payload: const <String, Object?>{
          'message': 'Provider recovered.',
          'token': 'second-secret',
        },
      ),
    );

    final DiagnosticsSnapshot snapshot = await center.snapshot(DiagnosticsQuery(
      category: DiagnosticsCategory.provider,
      minimumSeverity: DiagnosticsSeverity.error,
      startedAt: base.subtract(const Duration(minutes: 1)),
      endedAt: base.add(const Duration(minutes: 2)),
      correlationId: const DiagnosticsCorrelationId('corr-a'),
      sourceModule: 'provider-gateway',
      eventTypes: const <DiagnosticsEventType>[
        DiagnosticsEventType('provider.failure')
      ],
      capabilityAreas: const <DiagnosticsCapability>[
        DiagnosticsCapability.providerGatewayCorrelation
      ],
    ));
    final DiagnosticsRetentionOutcome retention = await center.enforceRetention(
      base.add(const Duration(minutes: 2)),
    );
    final DiagnosticsLocalExportDescriptor descriptor =
        await center.describeLocalExport(
      snapshot: snapshot,
      format: 'jsonl',
      now: base,
    );

    expect(recorded.isSuccess, isTrue);
    expect(snapshot.events.single.payload['token'], '<redacted>');
    expect(snapshot.events.single.correlationId.value, 'corr-a');
    expect(retention.removedEventCount, 1);
    expect(retention.remainingEventCount, 1);
    expect(descriptor.state, DiagnosticsExportState.described);
    expect(descriptor.redacted, isTrue);
  });

  test(
      'storage persists redacted records snapshots exports retention and capabilities',
      () async {
    final DateTime observedAt = DateTime.utc(2026, 6, 11, 12);
    final DeterministicDiagnosticsStore store = DeterministicDiagnosticsStore();

    await store.storeSchema(StoredDiagnosticsSchemaRecord(
      eventType: 'network.blocked',
      category: DiagnosticsCategory.networkPolicy,
      version: 1,
      defaultSeverity: DiagnosticsSeverity.warning,
      registeredAt: observedAt,
      requiredPayloadKeys: const <String>['reason'],
      capabilityArea: DiagnosticsCapability.redactedEventRecording,
    ));
    await store.recordEvent(StoredDiagnosticsEventRecord(
      id: 'event-a',
      eventType: 'network.blocked',
      schemaVersion: 1,
      category: DiagnosticsCategory.networkPolicy,
      severity: DiagnosticsSeverity.warning,
      occurredAt: observedAt,
      sourceModule: 'network-policy',
      correlationId: 'corr-network',
      redacted: true,
      payload: const <String, Object?>{'reason': 'loopback'},
      capabilityArea: DiagnosticsCapability.redactedEventRecording,
    ));
    await store.storeSnapshot(StoredDiagnosticsSnapshotRecord(
      id: 'snapshot-a',
      createdAt: observedAt,
      eventIds: const <String>['event-a'],
      category: DiagnosticsCategory.networkPolicy,
      minimumSeverity: DiagnosticsSeverity.warning,
      correlationId: 'corr-network',
      sourceModule: 'network-policy',
      eventTypes: const <String>['network.blocked'],
      capabilityAreas: const <DiagnosticsCapability>[
        DiagnosticsCapability.redactedEventRecording
      ],
    ));
    await store.recordExportRequest(StoredDiagnosticsExportRequestRecord(
      id: 'export-request-a',
      snapshotId: 'snapshot-a',
      format: 'jsonl',
      requestedAt: observedAt,
    ));
    await store.recordExportOutcome(StoredDiagnosticsExportOutcomeRecord(
      id: 'export-outcome-a',
      requestId: 'export-request-a',
      snapshotId: 'snapshot-a',
      format: 'jsonl',
      state: StoredDiagnosticsExportState.described,
      recordedAt: observedAt,
      redacted: true,
      uri: Uri.parse('diagnostics://local/snapshot-a'),
    ));
    await store.recordRetentionState(StoredDiagnosticsRetentionStateRecord(
      id: 'retention-a',
      enforcedAt: observedAt,
      maxEvents: 100,
      maxAge: const Duration(days: 7),
      removedEventCount: 2,
      remainingEventCount: 10,
    ));
    await store.storeCapability(StoredDiagnosticsCapabilityRecord(
      capability: DiagnosticsCapability.snapshotQuery,
      state: StoredDiagnosticsCapabilityState.supported,
      updatedAt: observedAt,
    ));

    expect((await store.schemaByEventType('network.blocked'))?.version, 1);
    expect(
        (await store.queryEvents(correlationId: 'corr-network'))
            .single
            .redacted,
        isTrue);
    expect(
        (await store.snapshotById('snapshot-a'))?.eventIds.single, 'event-a');
    expect(
        (await store.exportOutcomeById('export-outcome-a'))?.redacted, isTrue);
    expect((await store.latestRetentionState())?.removedEventCount, 2);
    expect((await store.capability(DiagnosticsCapability.snapshotQuery))?.state,
        StoredDiagnosticsCapabilityState.supported);
  });

  test(
      'invalidation events capability fallback and gateway correlation are read only',
      () async {
    final DateTime observedAt = DateTime.utc(2026, 6, 11, 12);
    final DeterministicDiagnosticsEventRegistry registry =
        DeterministicDiagnosticsEventRegistry();
    final DeterministicDiagnosticsCenter disabledCenter =
        DeterministicDiagnosticsCenter(
      registry: registry,
      retentionPolicy: const DiagnosticsRetentionPolicy(
          maxEvents: 10, maxAge: Duration(days: 1)),
      redactionPolicy: DiagnosticsRedactionPolicy(),
      capabilityMatrix: DiagnosticsCapabilityMatrix(),
    );

    final DiagnosticsOperationOutcome failed = await disabledCenter.record(
      DiagnosticsEvent(
        type: const DiagnosticsEventType('missing'),
        schemaVersion: 1,
        category: DiagnosticsCategory.provider,
        severity: DiagnosticsSeverity.error,
        occurredAt: observedAt,
        sourceModule: 'provider-gateway',
        correlationId: const DiagnosticsCorrelationId('corr-a'),
      ),
    );
    final ProviderDiagnosticsCorrelationDescriptor descriptor =
        ProviderDiagnosticsCorrelationDescriptor(
      providerId: const ProviderId('provider-a'),
      requestKey: ProviderRequestKey(
        providerId: const ProviderId('provider-a'),
        cacheKey: 'provider-a::request',
      ),
      cachePolicy: ProviderCachePolicy.networkFirst,
      correlationId: 'corr-a',
      failureKind: ProviderFailureKind.terminal,
      failureMessage: 'Provider failed.',
      networkPolicyFailureKind: NetworkPolicyFailureKind.loopbackAddress.name,
      networkPolicyEvaluationId: 'evaluation-a',
    );
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(7).toList();
    bus.publish(DiagnosticsSchemaRegistered(
      occurredAt: observedAt,
      eventType: 'provider.failure',
      category: DiagnosticsCategory.provider.name,
      version: 1,
    ));
    bus.publish(DiagnosticsEventRecorded(
      occurredAt: observedAt,
      eventId: 'event-a',
      eventType: 'provider.failure',
      sourceModule: 'provider-gateway',
      correlationId: 'corr-a',
    ));
    bus.publish(DiagnosticsSnapshotCreated(
      occurredAt: observedAt,
      snapshotId: 'snapshot-a',
      eventCount: 1,
    ));
    bus.publish(DiagnosticsExportRequestRecorded(
      occurredAt: observedAt,
      requestId: 'export-request-a',
      snapshotId: 'snapshot-a',
      format: 'jsonl',
    ));
    bus.publish(DiagnosticsExportOutcomeRecorded(
      occurredAt: observedAt,
      outcomeId: 'export-outcome-a',
      requestId: 'export-request-a',
      snapshotId: 'snapshot-a',
      state: StoredDiagnosticsExportState.described.name,
    ));
    bus.publish(DiagnosticsRetentionEnforced(
      occurredAt: observedAt,
      retentionStateId: 'retention-a',
      removedEventCount: 1,
      remainingEventCount: 3,
    ));
    bus.publish(DiagnosticsCapabilityChanged(
      occurredAt: observedAt,
      capability: DiagnosticsCapability.snapshotQuery.name,
      supported: true,
    ));
    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(failed.failure?.kind, DiagnosticsFailureKind.capabilityUnsupported);
    expect(descriptor.requestKey.cacheKey, 'provider-a::request');
    expect(descriptor.networkPolicyFailureKind,
        NetworkPolicyFailureKind.loopbackAddress.name);
    expect(delivered.whereType<DiagnosticsSchemaRegistered>().length, 1);
    expect(delivered.whereType<DiagnosticsEventRecorded>().length, 1);
    expect(delivered.whereType<DiagnosticsSnapshotCreated>().length, 1);
    expect(delivered.whereType<DiagnosticsExportRequestRecorded>().length, 1);
    expect(delivered.whereType<DiagnosticsExportOutcomeRecorded>().length, 1);
    expect(delivered.whereType<DiagnosticsRetentionEnforced>().length, 1);
    expect(delivered.whereType<DiagnosticsCapabilityChanged>().length, 1);
  });
}
