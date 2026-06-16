import '../../playback/danmaku/danmaku_event.dart';
import '../../playback/danmaku/danmaku_runtime_state.dart';
import '../../playback/player_clock.dart';
import '../../playback/subtitle/subtitle_parser.dart';
import '../../playback/subtitle/subtitle_runtime_state.dart';
import '../../provider/dandanplay/dandanplay_comments.dart';
import '../../provider/dandanplay/dandanplay_provider.dart';
import '../../provider/provider_result.dart';
import '../../provider/subtitle/subtitle_provider.dart';
import '../subtitle/basic_subtitle_state.dart';
import '../subtitle/subtitle_provider_runtime.dart';
import 'basic_danmaku_state.dart';
import 'playback_state.dart';

const String playbackMetadataSubtitleRuntimeUnavailable =
    'Subtitle playback runtime is unavailable.';
const String playbackMetadataSubtitleProviderUnavailable =
    'Subtitle provider runtime is unavailable.';
const String playbackMetadataDandanplayProviderUnavailable =
    'Dandanplay comment provider is unavailable.';

enum PlaybackMetadataBridgeStatus {
  idle,
  ready,
  failed,
  disposed,
}

enum PlaybackMetadataBridgeFailureKind {
  disposed,
  unavailable,
  providerFailure,
  subtitleLoadFailed,
  subtitleSelectionFailed,
  danmakuLoadFailed,
}

final class PlaybackMetadataBridgeFailure {
  const PlaybackMetadataBridgeFailure({
    required this.kind,
    required this.message,
  }) : assert(
          message != '',
          'Playback metadata bridge failure message must not be empty.',
        );

  final PlaybackMetadataBridgeFailureKind kind;
  final String message;
}

final class PlaybackMetadataBridgeResult<T> {
  const PlaybackMetadataBridgeResult._({this.value, this.failure});

  const PlaybackMetadataBridgeResult.success(T value) : this._(value: value);

  const PlaybackMetadataBridgeResult.failure(
    PlaybackMetadataBridgeFailure failure,
  ) : this._(failure: failure);

  final T? value;
  final PlaybackMetadataBridgeFailure? failure;

  bool get isSuccess => failure == null;
}

final class PlaybackMetadataBridgeSnapshot {
  PlaybackMetadataBridgeSnapshot({
    required this.status,
    this.subtitles = const PlaybackSubtitleStateSnapshot.none(),
    this.danmaku = const PlaybackDanmakuStateSnapshot.none(),
    Iterable<PlaybackMetadataBridgeFailure> failures =
        const <PlaybackMetadataBridgeFailure>[],
  }) : failures = List<PlaybackMetadataBridgeFailure>.unmodifiable(failures);

  const PlaybackMetadataBridgeSnapshot.idle()
      : status = PlaybackMetadataBridgeStatus.idle,
        subtitles = const PlaybackSubtitleStateSnapshot.none(),
        danmaku = const PlaybackDanmakuStateSnapshot.none(),
        failures = const <PlaybackMetadataBridgeFailure>[];

  final PlaybackMetadataBridgeStatus status;
  final PlaybackSubtitleStateSnapshot subtitles;
  final PlaybackDanmakuStateSnapshot danmaku;
  final List<PlaybackMetadataBridgeFailure> failures;

  PlaybackStateSnapshot applyTo(PlaybackStateSnapshot state) {
    return PlaybackStateSnapshot(
      status: state.status,
      timeline: state.timeline,
      buffering: state.buffering,
      activeTracks: state.activeTracks,
      subtitles: subtitles,
      danmaku: danmaku,
      sourceUri: state.sourceUri,
      failureReason: state.failureReason,
    );
  }
}

final class PlaybackMetadataBridge {
  PlaybackMetadataBridge({
    required BasicSubtitleRuntime subtitleRuntime,
    required BasicDanmakuRuntime danmakuRuntime,
    SubtitleProviderRuntime? subtitleProviderRuntime,
    DandanplayCommentProvider? dandanplayCommentProvider,
  })  : _subtitleRuntime = subtitleRuntime,
        _danmakuRuntime = danmakuRuntime,
        _subtitleProviderRuntime = subtitleProviderRuntime,
        _dandanplayCommentProvider = dandanplayCommentProvider;

  final BasicSubtitleRuntime _subtitleRuntime;
  final BasicDanmakuRuntime _danmakuRuntime;
  final SubtitleProviderRuntime? _subtitleProviderRuntime;
  final DandanplayCommentProvider? _dandanplayCommentProvider;
  PlaybackMetadataBridgeSnapshot _snapshot =
      const PlaybackMetadataBridgeSnapshot.idle();
  bool _disposed = false;

  PlaybackMetadataBridgeSnapshot get currentSnapshot => _snapshot;

  bool get isDisposed => _disposed;

  Future<PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>>
      loadProviderSubtitle(SubtitleProviderCandidate candidate) async {
    if (_disposed) return _disposedResult<PlaybackSubtitleStateSnapshot>();
    final SubtitleProviderRuntime? runtime = _subtitleProviderRuntime;
    if (runtime == null) {
      return _fail<PlaybackSubtitleStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.unavailable,
        playbackMetadataSubtitleProviderUnavailable,
      );
    }
    final SubtitleProviderActionResult<SubtitleParseRequest> handoff =
        await runtime.prepareParserRequest(candidate);
    final SubtitleParseRequest? parseRequest = handoff.value;
    if (!handoff.isSuccess || parseRequest == null) {
      return _fail<PlaybackSubtitleStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.providerFailure,
        handoff.failure?.message ?? 'Subtitle provider handoff failed.',
      );
    }
    return loadPreparedSubtitle(parseRequest);
  }

  Future<PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>>
      loadPreparedSubtitle(SubtitleParseRequest request) async {
    if (_disposed) return _disposedResult<PlaybackSubtitleStateSnapshot>();
    final BasicSubtitleLoadResult load = await _subtitleRuntime.load(request);
    final BasicSubtitleRuntimeFailure? loadFailure = load.failure;
    if (loadFailure != null) {
      return _fail<PlaybackSubtitleStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.subtitleLoadFailed,
        loadFailure.message,
      );
    }
    final BasicSubtitleSelectionResult selection =
        _subtitleRuntime.select(request.source);
    final BasicSubtitleRuntimeFailure? selectionFailure = selection.failure;
    if (selectionFailure != null) {
      return _fail<PlaybackSubtitleStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.subtitleSelectionFailed,
        selectionFailure.message,
      );
    }
    final PlaybackSubtitleStateSnapshot subtitles =
        playbackSubtitleStateFromRuntimeSnapshot(
      _subtitleRuntime.currentSnapshot,
    );
    _publish(
      PlaybackMetadataBridgeSnapshot(
        status: PlaybackMetadataBridgeStatus.ready,
        subtitles: subtitles,
        danmaku: _snapshot.danmaku,
      ),
    );
    return PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>.success(
      subtitles,
    );
  }

  Future<PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>>
      loadDandanplayComments(
    DandanplayEpisodeId episodeId,
  ) async {
    if (_disposed) return _disposedResult<PlaybackDanmakuStateSnapshot>();
    final DandanplayCommentProvider? provider = _dandanplayCommentProvider;
    if (provider == null) {
      return _fail<PlaybackDanmakuStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.unavailable,
        playbackMetadataDandanplayProviderUnavailable,
      );
    }
    final AcgProviderResult<List<DandanplayComment>> result =
        await provider.commentsForEpisode(episodeId);
    switch (result) {
      case AcgProviderFailure<List<DandanplayComment>>(:final message):
        return _fail<PlaybackDanmakuStateSnapshot>(
          PlaybackMetadataBridgeFailureKind.providerFailure,
          message,
        );
      case AcgProviderSuccess<List<DandanplayComment>>(:final value):
        return loadDandanplayCommentValues(
          value,
          idPrefix: episodeId.value,
        );
    }
  }

  PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>
      loadDandanplayCommentValues(
    Iterable<DandanplayComment> comments, {
    required String idPrefix,
  }) {
    if (_disposed) return _disposedResult<PlaybackDanmakuStateSnapshot>();
    final List<DanmakuComment> normalized = danmakuCommentsFromDandanplay(
      comments,
      idPrefix: idPrefix,
    );
    final BasicDanmakuLoadResult load = _danmakuRuntime.load(normalized);
    final BasicDanmakuRuntimeFailure? loadFailure = load.failure;
    if (loadFailure != null) {
      return _fail<PlaybackDanmakuStateSnapshot>(
        PlaybackMetadataBridgeFailureKind.danmakuLoadFailed,
        loadFailure.message,
      );
    }
    final PlaybackDanmakuStateSnapshot danmaku =
        playbackDanmakuStateFromRuntimeSnapshot(
      _danmakuRuntime.currentSnapshot,
    );
    _publish(
      PlaybackMetadataBridgeSnapshot(
        status: PlaybackMetadataBridgeStatus.ready,
        subtitles: _snapshot.subtitles,
        danmaku: danmaku,
      ),
    );
    return PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>.success(
      danmaku,
    );
  }

  PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot> resolve(
    PlayerClockSnapshot clock,
  ) {
    if (_disposed) return _disposedResult<PlaybackMetadataBridgeSnapshot>();
    final PlaybackSubtitleStateSnapshot subtitles =
        playbackSubtitleStateFromRuntimeSnapshot(
      _subtitleRuntime.resolveActiveCues(clock),
    );
    final PlaybackDanmakuStateSnapshot danmaku =
        playbackDanmakuStateFromRuntimeSnapshot(
      _danmakuRuntime.resolveFrame(clock),
    );
    final PlaybackMetadataBridgeSnapshot snapshot =
        PlaybackMetadataBridgeSnapshot(
      status: PlaybackMetadataBridgeStatus.ready,
      subtitles: subtitles,
      danmaku: danmaku,
    );
    _publish(snapshot);
    return PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot>.success(
      snapshot,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(
      PlaybackMetadataBridgeSnapshot(
        status: PlaybackMetadataBridgeStatus.disposed,
        subtitles: _snapshot.subtitles,
        danmaku: _snapshot.danmaku,
        failures: <PlaybackMetadataBridgeFailure>[_disposedFailure()],
      ),
    );
  }

  PlaybackMetadataBridgeResult<T> _fail<T>(
    PlaybackMetadataBridgeFailureKind kind,
    String message,
  ) {
    final PlaybackMetadataBridgeFailure failure =
        PlaybackMetadataBridgeFailure(kind: kind, message: message);
    _publish(
      PlaybackMetadataBridgeSnapshot(
        status: PlaybackMetadataBridgeStatus.failed,
        subtitles: _snapshot.subtitles,
        danmaku: _snapshot.danmaku,
        failures: <PlaybackMetadataBridgeFailure>[failure],
      ),
    );
    return PlaybackMetadataBridgeResult<T>.failure(failure);
  }

  PlaybackMetadataBridgeResult<T> _disposedResult<T>() {
    return PlaybackMetadataBridgeResult<T>.failure(_disposedFailure());
  }

  PlaybackMetadataBridgeFailure _disposedFailure() {
    return const PlaybackMetadataBridgeFailure(
      kind: PlaybackMetadataBridgeFailureKind.disposed,
      message: 'PlaybackMetadataBridge has been disposed.',
    );
  }

  void _publish(PlaybackMetadataBridgeSnapshot snapshot) {
    _snapshot = snapshot;
  }
}
