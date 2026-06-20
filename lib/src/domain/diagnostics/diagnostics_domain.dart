import 'dart:async';

import 'dart:io';

import '../../foundation/diagnostics/diagnostics_center.dart';
import '../../foundation/diagnostics/diagnostics_center_runtime.dart';
import '../../foundation/storage/av_sync_guard_storage_contracts.dart';
import '../../foundation/storage/diagnostics_storage_contracts.dart';

abstract interface class DiagnosticsRuntime {
  Future<List<DiagnosticsEventProjection>> queryEvents();
  Map<String, String> getCapabilitiesSupportStatus();
  Future<double> getLatestAvSyncDrift();
  int getActiveMemoryUsageBytes();
}

final class DiagnosticsEventProjection {
  const DiagnosticsEventProjection({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.occurredAt,
    required this.sourceModule,
    required this.correlationId,
    required this.payloadText,
  });

  final String id;
  final String eventType;
  final String severity;
  final DateTime occurredAt;
  final String sourceModule;
  final String correlationId;
  final String payloadText;
}

final class DiagnosticsRuntimeAdapter implements DiagnosticsRuntime {
  DiagnosticsRuntimeAdapter({
    required DiagnosticsCenterRuntime centerRuntime,
    required DiagnosticsStore store,
    required DiagnosticsCapabilityMatrix capabilityMatrix,
    required AVSyncGuardStore avSyncGuardStore,
  })  : _centerRuntime = centerRuntime,
        _store = store,
        _capabilityMatrix = capabilityMatrix,
        _avSyncGuardStore = avSyncGuardStore;

  // ignore: unused_field
  final DiagnosticsCenterRuntime _centerRuntime;
  final DiagnosticsStore _store;
  final DiagnosticsCapabilityMatrix _capabilityMatrix;
  final AVSyncGuardStore _avSyncGuardStore;

  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    final DiagnosticsCenterRuntimeActionResult<
            DiagnosticsCenterRuntimeProjection> snapshot =
        await _centerRuntime.snapshot();
    if (!snapshot.isSuccess) {
      final DiagnosticsCenterRuntimeFailure? failure = snapshot.failure;
      throw StateError(
          failure?.message ?? 'Diagnostics center snapshot is unavailable.');
    }

    final List<StoredDiagnosticsEventRecord> events =
        await _store.queryEvents();
    return events
        .map((StoredDiagnosticsEventRecord e) => DiagnosticsEventProjection(
              id: e.id,
              eventType: e.eventType,
              severity: e.severity.name,
              occurredAt: e.occurredAt,
              sourceModule: e.sourceModule,
              correlationId: e.correlationId,
              payloadText: e.payload.toString(),
            ))
        .toList();
  }

  @override
  Map<String, String> getCapabilitiesSupportStatus() {
    final Map<String, String> statusMap = <String, String>{};
    for (final DiagnosticsCapability cap in DiagnosticsCapability.values) {
      final bool supported = _capabilityMatrix.supports(cap);
      statusMap[cap.name] = supported ? 'Supported' : 'Unsupported';
    }
    return statusMap;
  }

  @override
  Future<double> getLatestAvSyncDrift() async {
    try {
      final List<StoredAVSyncSampleHistoryMetadataRecord> samples =
          await _avSyncGuardStore.sampleHistory('default-scope', limit: 1);
      if (samples.isEmpty) return 0.0;
      return samples.first.driftMillis.toDouble();
    } catch (e, stack) {
      // Rather than swallow silently, let caller know there's an issue with the metrics store
      Error.throwWithStackTrace(
          StateError('Failed to query AV sync drift: $e'), stack);
    }
  }

  @override
  int getActiveMemoryUsageBytes() {
    return ProcessInfo.currentRss;
  }
}

final class FakeDiagnosticsRuntime implements DiagnosticsRuntime {
  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async =>
      const <DiagnosticsEventProjection>[];

  @override
  Map<String, String> getCapabilitiesSupportStatus() =>
      const <String, String>{};

  @override
  Future<double> getLatestAvSyncDrift() async => 0.0;

  @override
  int getActiveMemoryUsageBytes() => 0;
}
