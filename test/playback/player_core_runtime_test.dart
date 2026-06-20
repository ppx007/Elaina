import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player core bootstrap constructs unsupported deterministic runtime',
      () async {
    final FoundationBootstrap foundation = FoundationBootstrap();
    final PlayerCoreBootstrap bootstrap = PlayerCoreBootstrap(
      foundationDependency: foundation,
    );

    expect(bootstrap.runtime.foundationDependency, same(foundation));
    expect(bootstrap.activeAdapter, isA<MpvPlayerAdapterFacade>());
    expect(
      bootstrap.runtime.capabilityMatrix
          .supports(PlaybackCapability.localFilePlayback),
      isFalse,
    );

    final PlaybackCommandResult result =
        await bootstrap.controller.open(_localSource());
    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, PlaybackFailureKind.unsupported);

    await bootstrap.dispose();
    await foundation.dispose();
  });

  test('bound deterministic runtime gates capabilities and records operations',
      () async {
    final DeterministicMpvBinding binding =
        DeterministicMpvBinding(tracks: _tracks);
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );

    expect(
        runtime.capabilityMatrix.supports(PlaybackCapability.localFilePlayback),
        isTrue);

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    expect((await runtime.controller.play()).isSuccess, isTrue);
    expect((await runtime.controller.pause()).isSuccess, isTrue);
    expect(
        (await runtime.controller.seek(const Duration(seconds: 12))).isSuccess,
        isTrue);
    expect((await runtime.controller.stop()).isSuccess, isTrue);

    expect(binding.loadedSource, isA<LocalFilePlaybackSource>());
    expect(
        binding.operations,
        containsAll(<PlaybackOperation>[
          PlaybackOperation.load,
          PlaybackOperation.play,
          PlaybackOperation.pause,
          PlaybackOperation.seek,
          PlaybackOperation.stop,
        ]));
    expect((runtime.clock as DeterministicPlayerClock).current.position,
        const Duration(seconds: 12));

    await runtime.dispose();
  });

  test('runtime capability matrix drives playback page descriptors', () async {
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(tracks: _tracks),
      capabilities: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
          PlaybackCapability.playPause: CapabilityStatus.supported(),
          PlaybackCapability.seek: CapabilityStatus.supported(),
          PlaybackCapability.progressReporting: CapabilityStatus.supported(),
        },
      ),
    );

    final PlaybackPageContract page = PlaybackPageContract(
      controller: runtime.controller,
    );
    final PlaybackPageSurfaceDescriptor surface = page.resolveSurface();

    expect(surface.hasActiveControl(PlaybackPageControlId.playPause), isTrue);
    expect(surface.hasActiveControl(PlaybackPageControlId.seek), isTrue);
    expect(
        surface.hasActiveControl(PlaybackPageControlId.audioTracks), isFalse);
    expect(surface.hasActivePanel(PlaybackPagePanelId.tracks), isFalse);

    final PlaybackPageIntentResult panelResult = await page.dispatch(
        const PlaybackPageIntent.openPanel(PlaybackPagePanelId.tracks));
    expect(panelResult.outcome, PlaybackPageIntentOutcome.unsupported);

    await runtime.dispose();
  });

  test('runtime publishes immutable playback state snapshots', () async {
    final DeterministicMpvBinding binding =
        DeterministicMpvBinding(tracks: _tracks);
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );
    final _RecordingObserver observer = _RecordingObserver();
    runtime.controller.addPlaybackStateObserver(observer);

    await runtime.controller.open(_localSource());
    await runtime.controller.play();
    await runtime.controller.seek(const Duration(seconds: 30));
    await runtime.controller.switchTrack(
      const DomainMediaTrackId('subtitle-ja'),
      trackType: DomainMediaTrackType.subtitle,
    );

    expect(
        observer.snapshots.map((PlaybackStateSnapshot s) => s.status),
        containsAll(<PlaybackLifecycleStatus>[
          PlaybackLifecycleStatus.opening,
          PlaybackLifecycleStatus.paused,
          PlaybackLifecycleStatus.playing,
        ]));
    expect(runtime.currentState.timeline.position, const Duration(seconds: 30));
    expect(runtime.currentState.activeTracks.subtitleTrackId?.value,
        'subtitle-ja');

    await runtime.dispose();
  });

  test('runtime discovers and switches normalized tracks', () async {
    final DeterministicMpvBinding binding =
        DeterministicMpvBinding(tracks: _tracks);
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );

    final TrackDiscoveryResult discovery =
        await runtime.controller.discoverTracks();
    expect(discovery.tracks, hasLength(2));
    expect(discovery.tracks.first.type, MediaTrackType.audio);
    expect(discovery.tracks.last.type, MediaTrackType.subtitle);

    final TrackSwitchResult switchResult = await runtime.controller.switchTrack(
      const DomainMediaTrackId('audio-main'),
      trackType: DomainMediaTrackType.audio,
    );
    expect(switchResult.isSuccess, isTrue);
    expect(binding.switchedTrackId?.value, 'audio-main');
    expect(runtime.currentState.activeTracks.audioTrackId?.value, 'audio-main');

    await runtime.dispose();
  });

  test('runtime rejects unsupported and disposed operations deterministically',
      () async {
    final DeterministicMpvBinding binding =
        DeterministicMpvBinding(tracks: _tracks);
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
        },
      ),
    );
    final PlaybackControllerContract controller = runtime.controller;

    final PlaybackCommandResult playResult = await controller.play();
    expect(playResult.isSuccess, isFalse);
    expect(playResult.failure?.kind, PlaybackFailureKind.unsupported);
    expect(binding.operations, isNot(contains(PlaybackOperation.play)));

    await runtime.dispose();
    expect(runtime.isDisposed, isTrue);
    expect(binding.isDisposed, isTrue);
    expect(() => runtime.activeAdapter, throwsStateError);
    final PlaybackCommandResult disposedResult = await controller.play();
    expect(disposedResult.failure?.kind, PlaybackFailureKind.disposed);
  });

  test('ui integration flow prepares source observes lifecycle and disposes',
      () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding();
    final PlayerCoreBootstrap bootstrap = PlayerCoreBootstrap.withBinding(
      binding: binding,
      capabilities: mediaKitLocalFilePlaybackCapabilities(),
    );
    final PlaybackControllerContract controller = bootstrap.controller;
    final _RecordingObserver observer = _RecordingObserver();
    controller.addPlaybackStateObserver(observer);

    final PlaybackSourceHandoffResult prepared =
        const LocalPlaybackSourceHandoff().prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(
        LocalMediaIdentity(
          id: LocalMediaId('ui-selected-local-file'),
          uri: Uri.file('D:/media/ui-selected.mkv'),
          basename: 'ui-selected.mkv',
        ),
      ),
    );

    expect(prepared.isSuccess, isTrue);
    expect(prepared.source, isA<LocalFilePlaybackSource>());
    expect((await controller.open(prepared.source!)).isSuccess, isTrue);
    expect((await controller.play()).isSuccess, isTrue);

    expect(binding.loadedSource, same(prepared.source));
    expect(
      observer.snapshots
          .map((PlaybackStateSnapshot snapshot) => snapshot.status),
      containsAll(<PlaybackLifecycleStatus>[
        PlaybackLifecycleStatus.opening,
        PlaybackLifecycleStatus.paused,
        PlaybackLifecycleStatus.playing,
      ]),
    );
    expect(
        bootstrap.runtime.currentState.status, PlaybackLifecycleStatus.playing);

    await bootstrap.dispose();
    final PlaybackCommandResult disposed = await controller.pause();
    expect(disposed.failure?.kind, PlaybackFailureKind.disposed);
  });

  test('ui integration flow preserves normalized source and runtime errors',
      () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding();
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: mediaKitLocalFilePlaybackCapabilities(),
    );
    final _RecordingObserver observer = _RecordingObserver();
    runtime.controller.addPlaybackStateObserver(observer);

    final PlaybackSourceHandoffResult handoffFailure =
        const LocalPlaybackSourceHandoff().prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(
        LocalMediaIdentity(
          id: LocalMediaId('ui-remote-local-file'),
          uri: Uri.parse('https://example.invalid/video.mkv'),
          basename: 'video.mkv',
        ),
      ),
    );
    expect(handoffFailure.isSuccess, isFalse);
    expect(
      handoffFailure.failure?.kind,
      PlaybackSourceHandoffFailureKind.unsupportedScheme,
    );

    final PlaybackCommandResult unsupportedSourceResult =
        await runtime.controller.open(
      HlsPlaybackSource(
          uri: Uri.parse('https://example.invalid/playlist.m3u8')),
    );

    expect(unsupportedSourceResult.isSuccess, isFalse);
    expect(
      unsupportedSourceResult.failure?.kind,
      PlaybackFailureKind.unsupported,
    );
    expect(binding.operations, isEmpty);
    expect(runtime.currentState.status, PlaybackLifecycleStatus.failed);
    expect(runtime.currentState.failureReason, isNotEmpty);
    expect(
      observer.snapshots.last.failureReason,
      unsupportedSourceResult.failure?.message,
    );

    await runtime.dispose();
  });
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
}

PlaybackCapabilityMatrix _fullPlayerCoreMatrix() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      PlaybackCapability.httpPlayback: CapabilityStatus.supported(),
      PlaybackCapability.hlsPlayback: CapabilityStatus.supported(),
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
      PlaybackCapability.progressReporting: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
      PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackDiscovery: CapabilityStatus.supported(),
      PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
    },
  );
}

const List<MediaTrackDescriptor> _tracks = <MediaTrackDescriptor>[
  MediaTrackDescriptor(
    id: MediaTrackId('audio-main'),
    type: MediaTrackType.audio,
    label: 'Main Audio',
    languageCode: 'ja',
    isSelected: true,
  ),
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-ja'),
    type: MediaTrackType.subtitle,
    label: 'Japanese Subtitle',
    languageCode: 'ja',
  ),
];

final class _RecordingObserver implements PlaybackStateObserver {
  final List<PlaybackStateSnapshot> snapshots = <PlaybackStateSnapshot>[];

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
