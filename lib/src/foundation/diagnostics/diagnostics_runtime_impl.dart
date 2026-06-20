import 'dart:async';
import 'dart:convert';

import '../cache_invalidation/cache_invalidation_bus.dart';
import '../storage/diagnostics_storage_contracts.dart';
import 'diagnostics_center.dart';
import 'diagnostics_center_runtime.dart';

const String diagnosticsInvalidationEventType =
    'diagnostics.cacheInvalidationObserved';
const String diagnosticsInvalidationSourceModule = 'cache-invalidation-bus';
const String diagnosticsInvalidationCorrelationPrefix = 'cache-invalidation';
const String diagnosticsPayloadEventTypeKey = 'eventType';
const String diagnosticsPayloadOccurredAtKey = 'occurredAt';
const String diagnosticsExportSnapshotMissingMessage =
    'Diagnostics snapshot is not available for local export.';

enum DiagnosticsLocalCollectorFailureKind {
  disposed,
  runtimeRejected,
}

final class DiagnosticsLocalCollectorFailure {
  const DiagnosticsLocalCollectorFailure({
    required this.kind,
    required this.message,
    this.runtimeFailure,
  });

  final DiagnosticsLocalCollectorFailureKind kind;
  final String message;
  final DiagnosticsCenterRuntimeFailure? runtimeFailure;
}

final class DiagnosticsLocalCollectorOutcome {
  const DiagnosticsLocalCollectorOutcome._({this.failure});

  const DiagnosticsLocalCollectorOutcome.success() : this._();

  const DiagnosticsLocalCollectorOutcome.failure(
    DiagnosticsLocalCollectorFailure failure,
  ) : this._(failure: failure);

  final DiagnosticsLocalCollectorFailure? failure;

  bool get isSuccess => failure == null;
}

final class DiagnosticsInvalidationCollector {
  DiagnosticsInvalidationCollector({required DiagnosticsCenterRuntime runtime})
      : _runtime = runtime;

  final DiagnosticsCenterRuntime _runtime;
  bool _schemaRegistered = false;
  bool _disposed = false;
  int _sequence = 0;
  final List<StreamSubscription<CacheInvalidationEvent>> _subscriptions =
      <StreamSubscription<CacheInvalidationEvent>>[];

  Future<DiagnosticsLocalCollectorOutcome> start() async {
    if (_disposed) return _disposedFailure();
    if (_schemaRegistered) {
      return const DiagnosticsLocalCollectorOutcome.success();
    }

    final DiagnosticsCenterRuntimeActionResult<void> result =
        await _runtime.recordSchema(DiagnosticsEventSchema(
      type: const DiagnosticsEventType(diagnosticsInvalidationEventType),
      category: DiagnosticsCategory.cache,
      version: 1,
      defaultSeverity: DiagnosticsSeverity.info,
      requiredPayloadKeys: const <String>[
        diagnosticsPayloadEventTypeKey,
        diagnosticsPayloadOccurredAtKey,
      ],
      capabilityArea: DiagnosticsCapability.redactedEventRecording,
    ));
    if (!result.isSuccess) return _runtimeFailure(result.failure!);
    _schemaRegistered = true;
    return const DiagnosticsLocalCollectorOutcome.success();
  }

  StreamSubscription<CacheInvalidationEvent> attach(CacheInvalidationBus bus) {
    final StreamSubscription<CacheInvalidationEvent> subscription =
        bus.events.listen((CacheInvalidationEvent event) {
      observe(event);
    });
    // Track the subscription so dispose() can cancel it (cancel_subscriptions).
    _subscriptions.add(subscription);
    return subscription;
  }

  Future<DiagnosticsLocalCollectorOutcome> observe(
      CacheInvalidationEvent event) async {
    if (_disposed) return _disposedFailure();

    final DiagnosticsLocalCollectorOutcome started = await start();
    if (!started.isSuccess) return started;

    _sequence += 1;
    final DiagnosticsCenterRuntimeActionResult<void> result =
        await _runtime.recordEvent(DiagnosticsEvent(
      type: const DiagnosticsEventType(diagnosticsInvalidationEventType),
      schemaVersion: 1,
      category: DiagnosticsCategory.cache,
      severity: DiagnosticsSeverity.info,
      occurredAt: event.occurredAt,
      sourceModule: diagnosticsInvalidationSourceModule,
      correlationId: DiagnosticsCorrelationId(
        '$diagnosticsInvalidationCorrelationPrefix-$_sequence',
      ),
      payload: <String, Object?>{
        diagnosticsPayloadEventTypeKey: event.runtimeType.toString(),
        diagnosticsPayloadOccurredAtKey: event.occurredAt.toIso8601String(),
      },
      capabilityArea: DiagnosticsCapability.redactedEventRecording,
    ));
    if (!result.isSuccess) return _runtimeFailure(result.failure!);

    return const DiagnosticsLocalCollectorOutcome.success();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final StreamSubscription<CacheInvalidationEvent> subscription
        in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  DiagnosticsLocalCollectorOutcome _disposedFailure() {
    return const DiagnosticsLocalCollectorOutcome.failure(
      DiagnosticsLocalCollectorFailure(
        kind: DiagnosticsLocalCollectorFailureKind.disposed,
        message: 'Diagnostics invalidation collector has been disposed.',
      ),
    );
  }

  DiagnosticsLocalCollectorOutcome _runtimeFailure(
      DiagnosticsCenterRuntimeFailure failure) {
    return DiagnosticsLocalCollectorOutcome.failure(
      DiagnosticsLocalCollectorFailure(
        kind: DiagnosticsLocalCollectorFailureKind.runtimeRejected,
        message: failure.message,
        runtimeFailure: failure,
      ),
    );
  }
}

enum DiagnosticsLocalExportBundleFailureKind {
  snapshotNotFound,
  disposed,
}

final class DiagnosticsLocalExportBundleFailure {
  const DiagnosticsLocalExportBundleFailure({
    required this.kind,
    required this.message,
  });

  final DiagnosticsLocalExportBundleFailureKind kind;
  final String message;
}

final class DiagnosticsLocalExportBundle {
  DiagnosticsLocalExportBundle({
    required this.snapshotId,
    required this.format,
    required this.createdAt,
    required Iterable<StoredDiagnosticsEventRecord> events,
  })  : events = List<StoredDiagnosticsEventRecord>.unmodifiable(events),
        jsonLines = List<String>.unmodifiable(
          events.map(_eventJsonLine),
        );

  final String snapshotId;
  final String format;
  final DateTime createdAt;
  final List<StoredDiagnosticsEventRecord> events;
  final List<String> jsonLines;

  int get eventCount => events.length;

  bool get redacted => events.every(
        (StoredDiagnosticsEventRecord event) => event.redacted,
      );
}

final class DiagnosticsLocalExportBundleOutcome {
  const DiagnosticsLocalExportBundleOutcome._({this.bundle, this.failure});

  const DiagnosticsLocalExportBundleOutcome.success({
    required DiagnosticsLocalExportBundle bundle,
  }) : this._(bundle: bundle);

  const DiagnosticsLocalExportBundleOutcome.failure({
    required DiagnosticsLocalExportBundleFailure failure,
  }) : this._(failure: failure);

  final DiagnosticsLocalExportBundle? bundle;
  final DiagnosticsLocalExportBundleFailure? failure;

  bool get isSuccess => failure == null;
}

final class DiagnosticsLocalExportBundleBuilder {
  DiagnosticsLocalExportBundleBuilder({required DiagnosticsStore store})
      : _store = store;

  final DiagnosticsStore _store;
  bool _disposed = false;

  Future<DiagnosticsLocalExportBundleOutcome> build({
    required String snapshotId,
    required String format,
    required DateTime createdAt,
  }) async {
    if (_disposed) {
      return const DiagnosticsLocalExportBundleOutcome.failure(
        failure: DiagnosticsLocalExportBundleFailure(
          kind: DiagnosticsLocalExportBundleFailureKind.disposed,
          message: 'Diagnostics local export bundle builder is disposed.',
        ),
      );
    }

    final StoredDiagnosticsSnapshotRecord? snapshot =
        await _store.snapshotById(snapshotId);
    if (snapshot == null) {
      return const DiagnosticsLocalExportBundleOutcome.failure(
        failure: DiagnosticsLocalExportBundleFailure(
          kind: DiagnosticsLocalExportBundleFailureKind.snapshotNotFound,
          message: diagnosticsExportSnapshotMissingMessage,
        ),
      );
    }

    final Set<String> eventIds = snapshot.eventIds.toSet();
    final List<StoredDiagnosticsEventRecord> events = (await _store.queryEvents(
      category: snapshot.category,
      minimumSeverity: snapshot.minimumSeverity,
      startedAt: snapshot.startedAt,
      endedAt: snapshot.endedAt,
      correlationId: snapshot.correlationId,
      sourceModule: snapshot.sourceModule,
      eventTypes: snapshot.eventTypes,
      capabilityAreas: snapshot.capabilityAreas,
    ))
        .where(
            (StoredDiagnosticsEventRecord event) => eventIds.contains(event.id))
        .toList();

    return DiagnosticsLocalExportBundleOutcome.success(
      bundle: DiagnosticsLocalExportBundle(
        snapshotId: snapshot.id,
        format: format,
        createdAt: createdAt,
        events: events,
      ),
    );
  }

  void dispose() {
    _disposed = true;
  }
}

String _eventJsonLine(StoredDiagnosticsEventRecord event) {
  return jsonEncode(<String, Object?>{
    'id': event.id,
    'eventType': event.eventType,
    'schemaVersion': event.schemaVersion,
    'category': event.category.name,
    'severity': event.severity.name,
    'occurredAt': event.occurredAt.toIso8601String(),
    'sourceModule': event.sourceModule,
    'correlationId': event.correlationId,
    'redacted': event.redacted,
    'payload': event.payload,
    if (event.capabilityArea != null)
      'capabilityArea': event.capabilityArea!.name,
  });
}
