import '../player_clock.dart';
import 'danmaku_event.dart';
import 'danmaku_filter.dart';
import 'danmaku_renderer.dart';

const DanmakuDensityPolicy defaultBasicDanmakuDensityPolicy =
    DanmakuDensityPolicy(
  maxCommentsPerWindow: 50,
  window: const Duration(seconds: 8),
);

enum BasicDanmakuRuntimeStatus {
  idle,
  ready,
  failed,
  disposed,
}

enum BasicDanmakuRuntimeFailureKind {
  disposed,
  invalidComments,
}

final class BasicDanmakuRuntimeFailure {
  const BasicDanmakuRuntimeFailure({required this.kind, required this.message})
      : assert(
          message != '',
          'Danmaku runtime failure message must not be empty.',
        );

  final BasicDanmakuRuntimeFailureKind kind;
  final String message;
}

final class BasicDanmakuRuntimeSnapshot {
  BasicDanmakuRuntimeSnapshot({
    required this.status,
    Iterable<DanmakuComment> loadedComments = const <DanmakuComment>[],
    DanmakuRenderFrame? activeFrame,
    this.filter = const DanmakuFilter(),
    this.densityPolicy = defaultBasicDanmakuDensityPolicy,
    Iterable<String> warnings = const <String>[],
    this.failure,
  })  : loadedComments = List<DanmakuComment>.unmodifiable(loadedComments),
        activeFrame = activeFrame ??
            DanmakuRenderFrame(
              clock: const PlayerClockSnapshot(
                position: Duration.zero,
                isPlaying: false,
                playbackSpeed: 1,
              ),
              lanes: <DanmakuRenderLane>[
                for (final DanmakuMode mode in DanmakuMode.values)
                  DanmakuRenderLane(
                    mode: mode,
                    comments: const <DanmakuComment>[],
                  ),
              ],
            ),
        warnings = List<String>.unmodifiable(warnings);

  final BasicDanmakuRuntimeStatus status;
  final List<DanmakuComment> loadedComments;
  final DanmakuRenderFrame activeFrame;
  final DanmakuFilter filter;
  final DanmakuDensityPolicy densityPolicy;
  final List<String> warnings;
  final BasicDanmakuRuntimeFailure? failure;
}

final class BasicDanmakuLoadResult {
  const BasicDanmakuLoadResult._({required this.count, this.failure});

  const BasicDanmakuLoadResult.loaded(int count) : this._(count: count);

  const BasicDanmakuLoadResult.failure(BasicDanmakuRuntimeFailure failure)
      : this._(count: 0, failure: failure);

  final int count;
  final BasicDanmakuRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class BasicDanmakuRuntimeObserver {
  void onDanmakuRuntimeSnapshot(BasicDanmakuRuntimeSnapshot snapshot);
}

final class BasicDanmakuRuntime {
  BasicDanmakuRuntime({
    BasicDanmakuRenderer renderer = const DeterministicBasicDanmakuRenderer(),
    DanmakuFilter filter = const DanmakuFilter(),
    DanmakuDensityPolicy densityPolicy = defaultBasicDanmakuDensityPolicy,
  })  : _renderer = renderer,
        _snapshot = BasicDanmakuRuntimeSnapshot(
          status: BasicDanmakuRuntimeStatus.idle,
          filter: filter,
          densityPolicy: densityPolicy,
        );

  final BasicDanmakuRenderer _renderer;
  final List<BasicDanmakuRuntimeObserver> _observers =
      <BasicDanmakuRuntimeObserver>[];
  BasicDanmakuRuntimeSnapshot _snapshot;
  bool _disposed = false;

  BasicDanmakuRuntimeSnapshot get currentSnapshot => _snapshot;

  bool get isDisposed => _disposed;

  void addObserver(BasicDanmakuRuntimeObserver observer) {
    if (_disposed) {
      throw StateError('BasicDanmakuRuntime has been disposed.');
    }
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  void removeObserver(BasicDanmakuRuntimeObserver observer) {
    _observers.remove(observer);
  }

  BasicDanmakuLoadResult load(Iterable<DanmakuComment> comments) {
    if (_disposed) return BasicDanmakuLoadResult.failure(_disposedFailure());
    final List<DanmakuComment> loaded = List<DanmakuComment>.unmodifiable(
      comments,
    );
    _publish(
      _copySnapshot(
        status: BasicDanmakuRuntimeStatus.ready,
        loadedComments: loaded,
      ),
    );
    return BasicDanmakuLoadResult.loaded(loaded.length);
  }

  void setFilter(DanmakuFilter filter) {
    if (_disposed) return;
    _publish(_copySnapshot(filter: filter));
  }

  void setDensityPolicy(DanmakuDensityPolicy densityPolicy) {
    if (_disposed) return;
    _publish(_copySnapshot(densityPolicy: densityPolicy));
  }

  BasicDanmakuRuntimeSnapshot resolveFrame(PlayerClockSnapshot clock) {
    if (_disposed) {
      return _copySnapshot(
        status: BasicDanmakuRuntimeStatus.disposed,
        failure: _disposedFailure(),
      );
    }
    final DanmakuRenderFrame frame = _renderer.frameFor(
      clock: clock,
      comments: _snapshot.loadedComments,
      filter: _snapshot.filter,
      densityPolicy: _snapshot.densityPolicy,
    );
    _publish(_copySnapshot(
        status: BasicDanmakuRuntimeStatus.ready, activeFrame: frame));
    return _snapshot;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(
      _copySnapshot(
        status: BasicDanmakuRuntimeStatus.disposed,
        failure: _disposedFailure(),
      ),
    );
    _observers.clear();
  }

  BasicDanmakuRuntimeSnapshot _copySnapshot({
    BasicDanmakuRuntimeStatus? status,
    Iterable<DanmakuComment>? loadedComments,
    DanmakuRenderFrame? activeFrame,
    DanmakuFilter? filter,
    DanmakuDensityPolicy? densityPolicy,
    Iterable<String>? warnings,
    BasicDanmakuRuntimeFailure? failure,
  }) {
    return BasicDanmakuRuntimeSnapshot(
      status: status ?? _snapshot.status,
      loadedComments: loadedComments ?? _snapshot.loadedComments,
      activeFrame: activeFrame ?? _snapshot.activeFrame,
      filter: filter ?? _snapshot.filter,
      densityPolicy: densityPolicy ?? _snapshot.densityPolicy,
      warnings: warnings ?? _snapshot.warnings,
      failure: failure,
    );
  }

  BasicDanmakuRuntimeFailure _disposedFailure() {
    return const BasicDanmakuRuntimeFailure(
      kind: BasicDanmakuRuntimeFailureKind.disposed,
      message: 'BasicDanmakuRuntime has been disposed.',
    );
  }

  void _publish(BasicDanmakuRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    for (final BasicDanmakuRuntimeObserver observer
        in List<BasicDanmakuRuntimeObserver>.of(_observers)) {
      observer.onDanmakuRuntimeSnapshot(snapshot);
    }
  }
}
