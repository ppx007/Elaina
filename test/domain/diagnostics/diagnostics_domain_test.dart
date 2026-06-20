import 'package:elaina/elaina.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter queries stored events through diagnostics center gate',
      () async {
    final DeterministicDiagnosticsStore store = DeterministicDiagnosticsStore();
    await store.recordEvent(_event(id: 'event-1'));

    final DiagnosticsRuntimeAdapter adapter = _adapter(
      centerRuntime: _runtime(store),
      store: store,
    );

    final List<DiagnosticsEventProjection> events = await adapter.queryEvents();

    expect(events, hasLength(1));
    expect(events.single.id, 'event-1');
    expect(events.single.eventType, 'player-event');
    expect(events.single.severity, DiagnosticsSeverity.info.name);
    expect(events.single.payloadText, contains('ok'));
  });

  test('adapter rejects event queries when diagnostics center is unavailable',
      () async {
    final DeterministicDiagnosticsStore store = DeterministicDiagnosticsStore();
    await store.recordEvent(_event(id: 'event-1'));

    final DiagnosticsRuntimeAdapter adapter = _adapter(
      centerRuntime:
          DiagnosticsCenterRuntime.unavailable(reason: 'Diagnostics disabled.'),
      store: store,
    );

    expect(adapter.queryEvents, throwsA(isA<StateError>()));
  });
}

DiagnosticsRuntimeAdapter _adapter({
  required DiagnosticsCenterRuntime centerRuntime,
  required DiagnosticsStore store,
}) {
  return DiagnosticsRuntimeAdapter(
    centerRuntime: centerRuntime,
    store: store,
    capabilityMatrix: _capabilities(),
    avSyncGuardStore: DeterministicAVSyncGuardStore(),
  );
}

DiagnosticsCenterRuntime _runtime(DeterministicDiagnosticsStore store) {
  return DiagnosticsCenterRuntimeBootstrap(
    store: store,
    registry: DeterministicDiagnosticsEventRegistry(),
    retentionPolicy: const DiagnosticsRetentionPolicy(
      maxEvents: 100,
      maxAge: Duration(days: 7),
    ),
    redactionPolicy: DiagnosticsRedactionPolicy(),
    capabilityMatrix: _capabilities(),
  ).createRuntime();
}

DiagnosticsCapabilityMatrix _capabilities() {
  return DiagnosticsCapabilityMatrix(
    capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
      for (final DiagnosticsCapability capability
          in DiagnosticsCapability.values)
        capability: const DiagnosticsCapabilityStatus.supported(),
    },
  );
}

StoredDiagnosticsEventRecord _event({required String id}) {
  return StoredDiagnosticsEventRecord(
    id: id,
    eventType: 'player-event',
    schemaVersion: 1,
    category: DiagnosticsCategory.playback,
    severity: DiagnosticsSeverity.info,
    occurredAt: DateTime.utc(2026, 6, 20, 12),
    sourceModule: 'playback',
    correlationId: 'corr-1',
    redacted: true,
    payload: const <String, Object?>{'detail': 'ok'},
  );
}
