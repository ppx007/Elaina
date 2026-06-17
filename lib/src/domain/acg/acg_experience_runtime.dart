import '../../playback/player_clock.dart';
import '../../playback/subtitle/subtitle_source.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/dandanplay/dandanplay_provider.dart';
import '../../provider/provider_result.dart';
import '../../provider/subtitle/subtitle_provider.dart';
import '../playback/playback_metadata_bridge.dart';
import '../playback/playback_state.dart';
import '../subtitle/subtitle_discovery.dart';
import '../subtitle/subtitle_provider_runtime.dart';
import 'acg_data_controller.dart';

enum AcgExperienceRuntimeStatus {
  idle,
  ready,
  failed,
  disposed,
}

enum AcgExperienceFailureKind {
  disposed,
  bangumiSubjectFailed,
  dandanplayMatchFailed,
  dandanplayCommentsFailed,
  subtitleDiscoveryFailed,
  subtitleCandidateUnavailable,
  subtitleHandoffFailed,
  metadataResolveFailed,
}

final class AcgExperienceFailure {
  const AcgExperienceFailure({
    required this.kind,
    required this.message,
  }) : assert(
            message != '', 'ACG experience failure message must not be empty.');

  final AcgExperienceFailureKind kind;
  final String message;
}

final class AcgExperienceRequest {
  const AcgExperienceRequest({
    required this.media,
    required this.subtitleQuery,
    required this.dandanplayFilename,
    required this.clock,
    this.bangumiSubjectId,
    this.basePlaybackState =
        const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
  });

  final LocalMediaReference media;
  final SubtitleSearchQuery subtitleQuery;
  final String dandanplayFilename;
  final PlayerClockSnapshot clock;
  final BangumiSubjectId? bangumiSubjectId;
  final PlaybackStateSnapshot basePlaybackState;
}

final class AcgExperienceResult {
  AcgExperienceResult({
    required this.status,
    this.bangumiSubject,
    this.dandanplayMatch,
    this.subtitleCandidate,
    required this.metadata,
    required this.playbackState,
    Iterable<AcgExperienceFailure> failures = const <AcgExperienceFailure>[],
  }) : failures = List<AcgExperienceFailure>.unmodifiable(failures);

  final AcgExperienceRuntimeStatus status;
  final BangumiSubject? bangumiSubject;
  final DandanplayMatchCandidate? dandanplayMatch;
  final ProviderSubtitleDiscoveryCandidate? subtitleCandidate;
  final PlaybackMetadataBridgeSnapshot metadata;
  final PlaybackStateSnapshot playbackState;
  final List<AcgExperienceFailure> failures;

  bool get isSuccess => failures.isEmpty;
}

final class AcgExperienceRuntime {
  AcgExperienceRuntime({
    required AcgDataController controller,
    required SubtitleProviderRuntime subtitleProviderRuntime,
    required PlaybackMetadataBridge metadataBridge,
  })  : _controller = controller,
        _subtitleProviderRuntime = subtitleProviderRuntime,
        _metadataBridge = metadataBridge;

  final AcgDataController _controller;
  final SubtitleProviderRuntime _subtitleProviderRuntime;
  final PlaybackMetadataBridge _metadataBridge;
  AcgExperienceResult _currentResult = AcgExperienceResult(
    status: AcgExperienceRuntimeStatus.idle,
    metadata: const PlaybackMetadataBridgeSnapshot.idle(),
    playbackState:
        const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
  );
  bool _disposed = false;

  AcgExperienceResult get currentResult => _currentResult;

  bool get isDisposed => _disposed;

  Future<AcgExperienceResult> prepare(AcgExperienceRequest request) async {
    if (_disposed) {
      return _publish(
        _resultFor(
          request: request,
          failures: <AcgExperienceFailure>[_disposedFailure()],
        ),
      );
    }

    final List<AcgExperienceFailure> failures = <AcgExperienceFailure>[];
    BangumiSubject? subject;
    DandanplayMatchCandidate? dandanplayMatch;
    ProviderSubtitleDiscoveryCandidate? subtitleCandidate;

    final BangumiSubjectId? subjectId = request.bangumiSubjectId;
    if (subjectId != null) {
      final AcgProviderResult<BangumiSubject> result =
          await _controller.bangumiSubject(subjectId);
      switch (result) {
        case AcgProviderSuccess<BangumiSubject>(:final value):
          subject = value;
        case AcgProviderFailure<BangumiSubject>(:final message):
          failures.add(
            AcgExperienceFailure(
              kind: AcgExperienceFailureKind.bangumiSubjectFailed,
              message: message,
            ),
          );
      }
    }

    final AcgProviderResult<List<DandanplayMatchCandidate>> matchResult =
        await _controller.matchDandanplay(request.dandanplayFilename);
    switch (matchResult) {
      case AcgProviderSuccess<List<DandanplayMatchCandidate>>(:final value):
        dandanplayMatch = _firstOrNull(value);
        if (dandanplayMatch == null) {
          failures.add(
            const AcgExperienceFailure(
              kind: AcgExperienceFailureKind.dandanplayMatchFailed,
              message: 'Dandanplay match returned no candidates.',
            ),
          );
        } else {
          final PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot>
              danmaku = await _metadataBridge.loadDandanplayComments(
            dandanplayMatch.episodeId,
          );
          final PlaybackMetadataBridgeFailure? failure = danmaku.failure;
          if (failure != null) {
            failures.add(
              AcgExperienceFailure(
                kind: AcgExperienceFailureKind.dandanplayCommentsFailed,
                message: failure.message,
              ),
            );
          }
        }
      case AcgProviderFailure<List<DandanplayMatchCandidate>>(:final message):
        failures.add(
          AcgExperienceFailure(
            kind: AcgExperienceFailureKind.dandanplayMatchFailed,
            message: message,
          ),
        );
    }

    final SubtitleProviderActionResult<SubtitleDiscoveryResult> subtitles =
        await _subtitleProviderRuntime.discover(
      SubtitleDiscoveryRequest(
        media: request.media,
        providerQuery: request.subtitleQuery,
        includeLocal: false,
      ),
    );
    final SubtitleProviderRuntimeFailure? subtitleFailure = subtitles.failure;
    if (!subtitles.isSuccess || subtitles.value == null) {
      failures.add(
        AcgExperienceFailure(
          kind: AcgExperienceFailureKind.subtitleDiscoveryFailed,
          message:
              subtitleFailure?.message ?? 'Subtitle provider discovery failed.',
        ),
      );
    } else {
      final SubtitleDiscoveryResult discovery = subtitles.value!;
      for (final SubtitleDiscoveryProviderFailure failure
          in discovery.providerFailures) {
        failures.add(
          AcgExperienceFailure(
            kind: AcgExperienceFailureKind.subtitleDiscoveryFailed,
            message: failure.message,
          ),
        );
      }
      subtitleCandidate = _firstOrNull(discovery.providerCandidates);
      if (subtitleCandidate == null) {
        failures.add(
          const AcgExperienceFailure(
            kind: AcgExperienceFailureKind.subtitleCandidateUnavailable,
            message: 'Subtitle provider discovery returned no candidates.',
          ),
        );
      } else {
        final PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot>
            subtitle = await _metadataBridge.loadProviderSubtitle(
          subtitleCandidate.candidate,
        );
        final PlaybackMetadataBridgeFailure? failure = subtitle.failure;
        if (failure != null) {
          failures.add(
            AcgExperienceFailure(
              kind: AcgExperienceFailureKind.subtitleHandoffFailed,
              message: failure.message,
            ),
          );
        }
      }
    }

    final PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot>
        metadataResult = _metadataBridge.resolve(request.clock);
    PlaybackMetadataBridgeSnapshot metadata =
        metadataResult.value ?? _metadataBridge.currentSnapshot;
    final PlaybackMetadataBridgeFailure? metadataFailure =
        metadataResult.failure;
    if (metadataFailure != null) {
      failures.add(
        AcgExperienceFailure(
          kind: AcgExperienceFailureKind.metadataResolveFailed,
          message: metadataFailure.message,
        ),
      );
      metadata = _metadataBridge.currentSnapshot;
    }

    return _publish(
      AcgExperienceResult(
        status: failures.isEmpty
            ? AcgExperienceRuntimeStatus.ready
            : AcgExperienceRuntimeStatus.failed,
        bangumiSubject: subject,
        dandanplayMatch: dandanplayMatch,
        subtitleCandidate: subtitleCandidate,
        metadata: metadata,
        playbackState: metadata.applyTo(request.basePlaybackState),
        failures: failures,
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(
      AcgExperienceResult(
        status: AcgExperienceRuntimeStatus.disposed,
        bangumiSubject: _currentResult.bangumiSubject,
        dandanplayMatch: _currentResult.dandanplayMatch,
        subtitleCandidate: _currentResult.subtitleCandidate,
        metadata: _currentResult.metadata,
        playbackState: _currentResult.playbackState,
        failures: <AcgExperienceFailure>[_disposedFailure()],
      ),
    );
  }

  AcgExperienceResult _resultFor({
    required AcgExperienceRequest request,
    required Iterable<AcgExperienceFailure> failures,
  }) {
    final PlaybackMetadataBridgeSnapshot metadata =
        _metadataBridge.currentSnapshot;
    return AcgExperienceResult(
      status: AcgExperienceRuntimeStatus.disposed,
      metadata: metadata,
      playbackState: metadata.applyTo(request.basePlaybackState),
      failures: failures,
    );
  }

  AcgExperienceFailure _disposedFailure() {
    return const AcgExperienceFailure(
      kind: AcgExperienceFailureKind.disposed,
      message: 'AcgExperienceRuntime has been disposed.',
    );
  }

  AcgExperienceResult _publish(AcgExperienceResult result) {
    _currentResult = result;
    return result;
  }
}

T? _firstOrNull<T>(Iterable<T> values) {
  final Iterator<T> iterator = values.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
