import 'dart:async';

import '../../playback/av_sync_guard.dart';
import '../../playback/av_sync_guard_runtime.dart';
import '../../playback/av_sync_sample_source.dart';
import 'playback_controller.dart';
import 'playback_state.dart';

const String avSyncGuardDefaultScopeId = 'default-scope';
const Duration avSyncGuardDefaultSampleInterval = Duration(seconds: 1);

final class AVSyncGuardMonitorSnapshot {
  const AVSyncGuardMonitorSnapshot({
    required this.scopeId,
    this.running = false,
    this.inFlight = false,
    this.health,
    this.latestDriftMillis,
    this.sampleCount,
    this.latestDegradationAction,
    this.latestSampleFailure,
    this.latestGuardFailure,
    this.lastSampledAt,
  });

  final String scopeId;
  final bool running;
  final bool inFlight;
  final AVSyncHealth? health;
  final int? latestDriftMillis;
  final int? sampleCount;
  final String? latestDegradationAction;
  final AVSyncSampleReadFailure? latestSampleFailure;
  final AVSyncGuardRuntimeFailure? latestGuardFailure;
  final DateTime? lastSampledAt;
}

/// Samples the active player and feeds the deterministic guard without
/// executing the suggested degradation action.
///
/// The monitor is intentionally read-only. It records when the current backend
/// would need degradation, but does not mutate playback features; actual
/// downgrade execution requires a separate command port.
final class AVSyncGuardMonitorRuntime {
  AVSyncGuardMonitorRuntime({
    required PlaybackControllerContract playbackController,
    required AVSyncSampleSource sampleSource,
    required AVSyncGuardRuntime guardRuntime,
    String scopeId = avSyncGuardDefaultScopeId,
    Duration sampleInterval = avSyncGuardDefaultSampleInterval,
    DateTime Function()? now,
  })  : _playbackController = playbackController,
        _sampleSource = sampleSource,
        _guardRuntime = guardRuntime,
        _scopeId = scopeId,
        _sampleInterval = sampleInterval,
        _now = now ?? DateTime.now,
        _snapshot = AVSyncGuardMonitorSnapshot(scopeId: scopeId);

  final PlaybackControllerContract _playbackController;
  final AVSyncSampleSource _sampleSource;
  final AVSyncGuardRuntime _guardRuntime;
  final String _scopeId;
  final Duration _sampleInterval;
  final DateTime Function() _now;
  Timer? _timer;
  bool _disposed = false;
  bool _inFlight = false;
  AVSyncGuardMonitorSnapshot _snapshot;

  AVSyncGuardMonitorSnapshot get snapshot => _snapshot;

  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(_sampleInterval, (_) {
      unawaited(tick());
    });
    _snapshot = _copySnapshot(running: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _snapshot = _copySnapshot(running: false, inFlight: _inFlight);
  }

  Future<void> tick() async {
    if (_disposed || _inFlight) return;
    if (!_shouldSample(_playbackController.currentState)) return;

    _inFlight = true;
    _snapshot = _copySnapshot(inFlight: true);
    try {
      final AVSyncSampleReadResult read = await _sampleSource.sample();
      if (!read.isSuccess) {
        _snapshot = _copySnapshot(
          inFlight: false,
          latestSampleFailure: read.failure,
        );
        return;
      }

      final AVSyncSample sample = read.sample!;
      AVSyncGuardRuntimeActionResult<AVSyncGuardRuntimeProjection> result =
          await _guardRuntime.ingestSample(_scopeId, sample);
      if (result.isSuccess && result.value!.health == AVSyncHealth.degraded) {
        result = await _guardRuntime.requestDegradation(_scopeId, sample);
      }
      if (!result.isSuccess) {
        _snapshot = _copySnapshot(
          inFlight: false,
          latestGuardFailure: result.failure,
        );
        return;
      }

      _snapshot = _snapshotFromProjection(
        result.value!,
        running: _timer != null,
        inFlight: false,
        sampledAt: _now(),
      );
    } finally {
      _inFlight = false;
      if (_snapshot.inFlight) {
        _snapshot = _copySnapshot(inFlight: false);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stop();
  }

  bool _shouldSample(PlaybackStateSnapshot state) {
    if (state.sourceUri == null) return false;
    return switch (state.status) {
      PlaybackLifecycleStatus.playing ||
      PlaybackLifecycleStatus.buffering =>
        true,
      PlaybackLifecycleStatus.idle ||
      PlaybackLifecycleStatus.opening ||
      PlaybackLifecycleStatus.paused ||
      PlaybackLifecycleStatus.ended ||
      PlaybackLifecycleStatus.failed =>
        false,
    };
  }

  AVSyncGuardMonitorSnapshot _snapshotFromProjection(
    AVSyncGuardRuntimeProjection projection, {
    required bool running,
    required bool inFlight,
    required DateTime sampledAt,
  }) {
    return AVSyncGuardMonitorSnapshot(
      scopeId: projection.scopeId,
      running: running,
      inFlight: inFlight,
      health: projection.health,
      latestDriftMillis: projection.latestDriftMillis,
      sampleCount: projection.sampleCount,
      latestDegradationAction: projection.latestDegradationAction,
      latestSampleFailure: null,
      latestGuardFailure: projection.latestFailure,
      lastSampledAt: sampledAt,
    );
  }

  AVSyncGuardMonitorSnapshot _copySnapshot({
    bool? running,
    bool? inFlight,
    AVSyncSampleReadFailure? latestSampleFailure,
    AVSyncGuardRuntimeFailure? latestGuardFailure,
  }) {
    return AVSyncGuardMonitorSnapshot(
      scopeId: _snapshot.scopeId,
      running: running ?? _snapshot.running,
      inFlight: inFlight ?? _snapshot.inFlight,
      health: _snapshot.health,
      latestDriftMillis: _snapshot.latestDriftMillis,
      sampleCount: _snapshot.sampleCount,
      latestDegradationAction: _snapshot.latestDegradationAction,
      latestSampleFailure: latestSampleFailure ?? _snapshot.latestSampleFailure,
      latestGuardFailure: latestGuardFailure ?? _snapshot.latestGuardFailure,
      lastSampledAt: _snapshot.lastSampledAt,
    );
  }
}
