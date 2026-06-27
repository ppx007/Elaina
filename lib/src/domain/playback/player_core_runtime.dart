import 'dart:async';

import '../../playback/capability_matrix.dart';
import '../../playback/mpv_adapter_facade.dart';
import '../../playback/player_adapter.dart';
import '../../playback/player_clock.dart';
import '../../playback/player_telemetry.dart';
import '../../playback/track_management.dart';
import 'playback_controller.dart';
import 'playback_state.dart';

const double _bufferFractionMin = 0;
const double _bufferFractionMax = 1;

/// Lifecycle-managed Phase 1 player-core runtime.
///
/// Composes Step 5-8 playback surfaces without owning Flutter widgets,
/// provider systems, storage internals, streaming engines, network clients, or
/// concrete native player bindings.
final class PlayerCoreRuntime implements ActivePlayerAdapterResolver {
  PlayerCoreRuntime({
    required PlayerAdapter activeAdapter,
    Object? foundationDependency,
    PlayerClock? clock,
    PlayerTelemetrySource? telemetrySource,
    PlaybackCapabilityProbeSource? capabilityProbeSource,
    DateTime Function()? now,
  })  : _activeAdapter = activeAdapter,
        _foundationDependency = foundationDependency,
        _clock = clock ?? DeterministicPlayerClock(),
        _telemetrySource = telemetrySource,
        _capabilityProbeSource = capabilityProbeSource,
        _now = now ?? DateTime.now {
    _controller = _RuntimePlaybackController(this);
    final PlayerTelemetrySource? source = _telemetrySource;
    if (source != null) {
      _controller.applyTelemetry(source.currentTelemetry);
      _telemetrySubscription = source.telemetry.listen(
        _controller.applyTelemetry,
      );
    }
  }

  factory PlayerCoreRuntime.unsupported({
    Object? foundationDependency,
    String reason = 'MPV binding is unavailable.',
  }) {
    return PlayerCoreRuntime(
      activeAdapter: MpvPlayerAdapterFacade.unsupported(reason: reason),
      foundationDependency: foundationDependency,
    );
  }

  factory PlayerCoreRuntime.bound({
    required MpvAdapterBinding binding,
    PlaybackCapabilityMatrix? capabilities,
    Object? foundationDependency,
    PlayerTelemetrySource? telemetrySource,
    PlaybackCapabilityProbeSource? capabilityProbeSource,
    DateTime Function()? now,
  }) {
    return PlayerCoreRuntime(
      activeAdapter: MpvPlayerAdapterFacade.bound(
        binding: binding,
        capabilities: capabilities,
      ),
      foundationDependency: foundationDependency,
      telemetrySource: telemetrySource,
      capabilityProbeSource: capabilityProbeSource,
      now: now,
    );
  }

  final PlayerAdapter _activeAdapter;
  final Object? _foundationDependency;
  final PlayerClock _clock;
  final PlayerTelemetrySource? _telemetrySource;
  final PlaybackCapabilityProbeSource? _capabilityProbeSource;
  final DateTime Function() _now;
  StreamSubscription<PlayerTelemetrySnapshot>? _telemetrySubscription;
  late final _RuntimePlaybackController _controller;
  bool _disposed = false;

  @override
  PlayerAdapter get activeAdapter {
    _checkNotDisposed();
    return _activeAdapter;
  }

  Object? get foundationDependency => _foundationDependency;

  PlaybackCapabilityMatrix get capabilityMatrix {
    _checkNotDisposed();
    return _capabilityProbeSource?.currentCapabilityProbe.capabilities ??
        _activeAdapter.capabilities;
  }

  PlaybackCapabilityProbeSnapshot? get currentCapabilityProbe {
    _checkNotDisposed();
    return _capabilityProbeSource?.currentCapabilityProbe;
  }

  PlaybackControllerContract get controller {
    _checkNotDisposed();
    return _controller;
  }

  PlayerClock get clock {
    _checkNotDisposed();
    return _clock;
  }

  PlaybackStateSnapshot get currentState => _controller.currentState;

  bool get isDisposed => _disposed;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _telemetrySubscription?.cancel();
    await _activeAdapter.dispose();
    final PlayerClock clock = _clock;
    if (clock is DeterministicPlayerClock) {
      await clock.close();
    }
    _controller.close();
  }

  PlaybackCommandResult disposedCommandResult(PlaybackOperation operation) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: PlaybackFailureKind.disposed,
        message: 'PlayerCoreRuntime has been disposed.',
      ),
    );
  }

  TrackSwitchResult disposedTrackResult() {
    return const TrackSwitchResult.unsupported(
        'PlayerCoreRuntime has been disposed.');
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('PlayerCoreRuntime has been disposed.');
    }
  }
}

final class _RuntimePlaybackController implements PlaybackControllerContract {
  _RuntimePlaybackController(this._runtime);

  final PlayerCoreRuntime _runtime;
  final List<PlaybackStateObserver> _observers = <PlaybackStateObserver>[];
  PlaybackStateSnapshot _currentState =
      const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle);
  bool _closed = false;

  @override
  PlaybackCapabilityMatrix get matrix => _runtime.capabilityMatrix;

  @override
  PlaybackStateSnapshot get currentState => _currentState;

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {
    if (_closed) {
      throw StateError('PlayerCoreRuntime has been disposed.');
    }
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {
    _observers.remove(observer);
  }

  @override
  PlaybackSurfaceState resolveSurfaceState() {
    _ensureOpen();
    return playbackSurfaceStateForCapabilities(matrix);
  }

  @override
  DomainPlaybackCapabilitySummary resolveCapabilitySummary() {
    _ensureOpen();
    return domainPlaybackCapabilitySummaryFromMatrix(matrix);
  }

  @override
  Future<PlaybackCommandResult> open(PlaybackSource source) async {
    if (_closed) return _runtime.disposedCommandResult(PlaybackOperation.load);
    _publish(_snapshotWith(
        status: PlaybackLifecycleStatus.opening, sourceUri: source.uri));
    final PlaybackCommandResult sourceSupport = playbackSourceSupportResult(
      source: source,
      capabilityMatrix: matrix,
    );
    if (!sourceSupport.isSuccess) {
      _publishFailure(sourceSupport);
      return sourceSupport;
    }
    final PlaybackCommandResult result =
        await _runtime._activeAdapter.load(source);
    if (result.isSuccess) {
      _publish(_snapshotWith(
          status: PlaybackLifecycleStatus.paused, sourceUri: source.uri));
    } else {
      _publishFailure(result);
    }
    return result;
  }

  @override
  Future<PlaybackCommandResult> play() {
    return _runCommand(
      operation: PlaybackOperation.play,
      capability: PlaybackCapability.playPause,
      execute: _runtime._activeAdapter.play,
      successStatus: PlaybackLifecycleStatus.playing,
    );
  }

  @override
  Future<PlaybackCommandResult> pause() {
    return _runCommand(
      operation: PlaybackOperation.pause,
      capability: PlaybackCapability.playPause,
      execute: _runtime._activeAdapter.pause,
      successStatus: PlaybackLifecycleStatus.paused,
    );
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    if (_closed) return _runtime.disposedCommandResult(PlaybackOperation.seek);
    final PlaybackCommandResult support = _capabilitySupport(
      operation: PlaybackOperation.seek,
      capability: PlaybackCapability.seek,
    );
    if (!support.isSuccess) return support;
    final PlaybackCommandResult result =
        await _runtime._activeAdapter.seek(position);
    if (result.isSuccess) {
      await _runtime._clock.seek(position);
      _publish(
        _snapshotWith(
          timeline: PlaybackTimelineState(
            position: position,
            duration: currentState.timeline.duration,
            observedAt: _runtime._now(),
          ),
        ),
      );
    } else {
      _publishFailure(result);
    }
    return result;
  }

  void applyTelemetry(PlayerTelemetrySnapshot telemetry) {
    if (_closed) return;
    final Duration? duration =
        telemetry.duration > Duration.zero ? telemetry.duration : null;
    final Duration? bufferedPosition =
        telemetry.bufferedPosition > Duration.zero
            ? telemetry.bufferedPosition
            : null;
    _publish(
      _snapshotWith(
        status: _statusFromTelemetry(telemetry),
        timeline: PlaybackTimelineState(
          position: telemetry.position,
          duration: duration,
          observedAt: telemetry.observedAt,
        ),
        buffering: PlaybackBufferingState(
          isBuffering: telemetry.buffering,
          bufferedPosition: bufferedPosition,
          bufferedFraction: _bufferedFraction(
            bufferedPosition: bufferedPosition,
            duration: duration,
          ),
        ),
        activeTracks: ActivePlaybackTrackState(
          audioTrackId: telemetry.activeAudioTrackId == null
              ? null
              : DomainMediaTrackId(telemetry.activeAudioTrackId!.value),
          subtitleTrackId: telemetry.activeSubtitleTrackId == null
              ? null
              : DomainMediaTrackId(telemetry.activeSubtitleTrackId!.value),
        ),
        failureReason: telemetry.failureReason,
      ),
    );
  }

  @override
  Future<PlaybackCommandResult> stop() {
    return _runCommand(
      operation: PlaybackOperation.stop,
      capability: PlaybackCapability.stop,
      execute: _runtime._activeAdapter.stop,
      successStatus: PlaybackLifecycleStatus.ended,
    );
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    _ensureOpen();
    final bool supportsDiscovery =
        matrix.supports(PlaybackCapability.audioTrackDiscovery) ||
            matrix.supports(PlaybackCapability.subtitleTrackDiscovery);
    if (!supportsDiscovery) {
      return TrackDiscoveryResult.unsupported(
          reason: 'Track discovery is unsupported by the active adapter.');
    }
    return _runtime._activeAdapter.discoverTracks();
  }

  @override
  Future<DomainTrackDiscoveryResult> discoverDomainTracks() async {
    return domainTrackDiscoveryResultFromPlayback(await discoverTracks());
  }

  @override
  Future<TrackSwitchResult> switchTrack(DomainMediaTrackId trackId,
      {DomainMediaTrackType? trackType}) async {
    if (_closed) return _runtime.disposedTrackResult();
    final TrackSwitchResult support = playbackTrackSwitchSupportResult(
      capabilityMatrix: matrix,
      trackType: trackType,
    );
    if (!support.isSuccess) return support;
    final TrackSwitchResult result =
        await _runtime._activeAdapter.switchTrack(MediaTrackId(trackId.value));
    if (result.isSuccess && trackType != null) {
      _publish(
        _snapshotWith(
          activeTracks: switch (trackType) {
            DomainMediaTrackType.audio => ActivePlaybackTrackState(
                audioTrackId: trackId,
                subtitleTrackId: currentState.activeTracks.subtitleTrackId,
              ),
            DomainMediaTrackType.subtitle => ActivePlaybackTrackState(
                audioTrackId: currentState.activeTracks.audioTrackId,
                subtitleTrackId: trackId,
              ),
          },
        ),
      );
    }
    return result;
  }

  Future<PlaybackCommandResult> _runCommand({
    required PlaybackOperation operation,
    required PlaybackCapability capability,
    required Future<PlaybackCommandResult> Function() execute,
    required PlaybackLifecycleStatus successStatus,
  }) async {
    if (_closed) return _runtime.disposedCommandResult(operation);
    final PlaybackCommandResult support = _capabilitySupport(
      operation: operation,
      capability: capability,
    );
    if (!support.isSuccess) return support;
    final PlaybackCommandResult result = await execute();
    if (result.isSuccess) {
      _publish(_snapshotWith(status: successStatus));
    } else {
      _publishFailure(result);
    }
    return result;
  }

  PlaybackCommandResult _capabilitySupport({
    required PlaybackOperation operation,
    required PlaybackCapability capability,
  }) {
    final CapabilityStatus status = matrix.statusOf(capability);
    if (status.isSupported) return const PlaybackCommandResult.success();
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: PlaybackFailureKind.unsupported,
        message: status.reason ?? 'Playback capability is unsupported.',
      ),
    );
  }

  PlaybackStateSnapshot _snapshotWith({
    PlaybackLifecycleStatus? status,
    PlaybackTimelineState? timeline,
    PlaybackBufferingState? buffering,
    ActivePlaybackTrackState? activeTracks,
    Uri? sourceUri,
    String? failureReason,
  }) {
    return PlaybackStateSnapshot(
      status: status ?? currentState.status,
      timeline: timeline ?? currentState.timeline,
      buffering: buffering ?? currentState.buffering,
      activeTracks: activeTracks ?? currentState.activeTracks,
      subtitles: currentState.subtitles,
      danmaku: currentState.danmaku,
      sourceUri: sourceUri ?? currentState.sourceUri,
      failureReason: failureReason,
    );
  }

  PlaybackLifecycleStatus _statusFromTelemetry(
    PlayerTelemetrySnapshot telemetry,
  ) {
    final String? failureReason = telemetry.failureReason;
    if (failureReason != null && failureReason.trim().isNotEmpty) {
      return PlaybackLifecycleStatus.failed;
    }
    if (currentState.status == PlaybackLifecycleStatus.ended &&
        !telemetry.playing &&
        !telemetry.buffering &&
        !telemetry.completed) {
      return PlaybackLifecycleStatus.ended;
    }
    if (telemetry.completed) return PlaybackLifecycleStatus.ended;
    if (telemetry.buffering) return PlaybackLifecycleStatus.buffering;
    if (telemetry.playing) return PlaybackLifecycleStatus.playing;
    if (currentState.sourceUri != null ||
        currentState.status != PlaybackLifecycleStatus.idle) {
      return PlaybackLifecycleStatus.paused;
    }
    return PlaybackLifecycleStatus.idle;
  }

  double? _bufferedFraction({
    required Duration? bufferedPosition,
    required Duration? duration,
  }) {
    if (bufferedPosition == null || duration == null) return null;
    final int durationMillis = duration.inMilliseconds;
    if (durationMillis <= 0) return null;
    return (bufferedPosition.inMilliseconds / durationMillis)
        .clamp(_bufferFractionMin, _bufferFractionMax)
        .toDouble();
  }

  void _publishFailure(PlaybackCommandResult result) {
    _publish(
      _snapshotWith(
        status: PlaybackLifecycleStatus.failed,
        failureReason: result.failure?.message,
      ),
    );
  }

  void _publish(PlaybackStateSnapshot snapshot) {
    _currentState = snapshot;
    for (final PlaybackStateObserver observer
        in List<PlaybackStateObserver>.of(_observers)) {
      observer.onPlaybackState(snapshot);
    }
  }

  void close() {
    _closed = true;
    _observers.clear();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PlayerCoreRuntime has been disposed.');
    }
  }
}

/// Deterministic [PlayerClock] for Phase 1 runtime tests.
final class DeterministicPlayerClock implements PlayerClock {
  DeterministicPlayerClock({
    PlayerClockSnapshot initialSnapshot = const PlayerClockSnapshot(
      position: Duration.zero,
      isPlaying: false,
      playbackSpeed: 1,
    ),
  }) : _current = initialSnapshot;

  final StreamController<PlayerClockSnapshot> _controller =
      StreamController<PlayerClockSnapshot>.broadcast(sync: true);
  PlayerClockSnapshot _current;
  bool _closed = false;

  @override
  Stream<PlayerClockSnapshot> get snapshots => _controller.stream;

  @override
  PlayerClockSnapshot get current => _current;

  @override
  Future<void> seek(Duration position) async {
    if (_closed) {
      throw StateError('DeterministicPlayerClock has been closed.');
    }
    _current = PlayerClockSnapshot(
      position: position,
      isPlaying: _current.isPlaying,
      playbackSpeed: _current.playbackSpeed,
    );
    _controller.add(_current);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}
