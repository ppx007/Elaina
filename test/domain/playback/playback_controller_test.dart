import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock controller dispatches page intents and notifies observers', () async {
    final MockPlaybackController controller = MockPlaybackController(
      matrix: _matrix(),
      initialState: const PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.paused,
        timeline: PlaybackTimelineState(position: Duration(seconds: 5), duration: Duration(minutes: 2)),
      ),
    );
    final PlaybackPageContract pageContract = PlaybackPageContract(controller: controller);
    final _StateRecorder recorder = _StateRecorder();
    controller.addPlaybackStateObserver(recorder);

    final PlaybackPageIntentResult playResult = await pageContract.dispatch(const PlaybackPageIntent.play());

    expect(playResult.isExecuted, isTrue);
    expect(controller.currentState.status, PlaybackLifecycleStatus.playing);
    expect(recorder.snapshots.single.status, PlaybackLifecycleStatus.playing);

    final PlaybackPageIntentResult seekResult = await pageContract.dispatch(
      const PlaybackPageIntent.seek(Duration(seconds: 42)),
    );

    expect(seekResult.isExecuted, isTrue);
    expect(controller.currentState.timeline.position, const Duration(seconds: 42));
    expect(recorder.snapshots.last.timeline.position, const Duration(seconds: 42));

    final PlaybackPageIntentResult trackResult = await pageContract.dispatch(
      const PlaybackPageIntent.selectTrack(
        trackId: DomainMediaTrackId('audio-main'),
        trackType: DomainMediaTrackType.audio,
      ),
    );

    expect(trackResult.isExecuted, isTrue);
    expect(controller.currentState.activeTracks.audioTrackId?.value, 'audio-main');
  });

  test('mock controller rejects unsupported direct track type switches', () async {
    final MockPlaybackController controller = MockPlaybackController(
      matrix: PlaybackCapabilityMatrix(
        capabilities: const <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
        },
      ),
    );

    final DomainTrackSwitchResult audioResult = await controller.switchTrack(
      const DomainMediaTrackId('audio-main'),
      trackType: DomainMediaTrackType.audio,
    );
    final DomainTrackSwitchResult subtitleResult = await controller.switchTrack(
      const DomainMediaTrackId('subtitle-ja'),
      trackType: DomainMediaTrackType.subtitle,
    );

    expect(audioResult.isSuccess, isFalse);
    expect(subtitleResult.isSuccess, isTrue);
    expect(controller.currentState.activeTracks.audioTrackId, isNull);
    expect(controller.currentState.activeTracks.subtitleTrackId?.value, 'subtitle-ja');
  });
}

PlaybackCapabilityMatrix _matrix() {
  return PlaybackCapabilityMatrix(
    capabilities: const <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
      PlaybackCapability.progressReporting: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
    },
  );
}

final class _StateRecorder implements PlaybackStateObserver {
  final List<PlaybackStateSnapshot> snapshots = <PlaybackStateSnapshot>[];

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
