import '../lib/celesteria.dart';

Future<void> main() async {
  await _verifyUnsupportedMpvFacade();
  await _verifyBoundMpvFacadeDelegation();
  await _verifySourceCapabilityGating();
  _verifySurfaceStateFromCapabilities();
  _verifyUndeclaredCapabilitiesRemainUnsupported();
  await _verifyTrackRuntimeChecks();
}

Future<void> _verifyUnsupportedMpvFacade() async {
  const MpvPlayerAdapterFacade adapter = MpvPlayerAdapterFacade.unsupported();

  _expect(!adapter.capabilities.supports(PlaybackCapability.localFilePlayback), 'Unsupported MPV facade must not support local playback.');
  _expectFailureKind(await adapter.load(_localSource()), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.play(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.pause(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.seek(const Duration(seconds: 10)), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.stop(), PlaybackFailureKind.adapterUnavailable);
  _expectFailureKind(await adapter.dispose(), PlaybackFailureKind.adapterUnavailable);

  final TrackDiscoveryResult discovery = await adapter.discoverTracks();
  _expect(discovery.tracks.isEmpty, 'Unsupported MPV facade must not report concrete tracks.');
  _expect(!discovery.capabilityMatrix.supports(PlaybackCapability.audioTrackDiscovery), 'Unsupported track discovery must return unsupported capabilities.');

  final TrackSwitchResult switchResult = await adapter.switchTrack(const MediaTrackId('audio-main'));
  _expect(!switchResult.isSuccess, 'Unsupported MPV facade must reject track switching.');
}

Future<void> _verifyBoundMpvFacadeDelegation() async {
  final _InMemoryMpvBinding binding = _InMemoryMpvBinding(
    tracks: _tracks,
  );
  final PlaybackController controller = PlaybackController(
    adapterResolver: _StaticAdapterResolver(MpvPlayerAdapterFacade.bound(binding: binding)),
  );

  _expectSuccess(await controller.open(_localSource()));
  _expectSuccess(await controller.play());
  _expectSuccess(await controller.pause());
  _expectSuccess(await controller.seek(const Duration(seconds: 24)));
  _expectSuccess(await controller.stop());

  _expect(binding.loadedSource is LocalFilePlaybackSource, 'Bound facade must delegate load to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.play), 'Bound facade must delegate play to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.pause), 'Bound facade must delegate pause to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.seek), 'Bound facade must delegate seek to the binding.');
  _expect(binding.operations.contains(PlaybackOperation.stop), 'Bound facade must delegate stop to the binding.');

  final _InMemoryMpvBinding localOnlyBinding = _InMemoryMpvBinding(tracks: _tracks);
  final MpvPlayerAdapterFacade localOnlyFacade = MpvPlayerAdapterFacade.bound(
    binding: localOnlyBinding,
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackCommandResult gatedResult = await localOnlyFacade.load(
    HlsPlaybackSource(uri: Uri.parse('https://example.test/playlist.m3u8')),
  );
  _expectFailureKind(gatedResult, PlaybackFailureKind.unsupported);
  _expect(localOnlyBinding.loadedSource == null, 'MPV facade must gate unsupported sources before binding delegation.');
}

Future<void> _verifySourceCapabilityGating() async {
  final _ConfigurablePlayerAdapter adapter = _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackController controller = PlaybackController(adapterResolver: _StaticAdapterResolver(adapter));

  _expectSuccess(await controller.open(_localSource()));
  _expect(adapter.loadCount == 1, 'Supported source load must delegate once.');

  final PlaybackCommandResult result = await controller.open(HlsPlaybackSource(uri: Uri.parse('https://example.test/playlist.m3u8')));
  _expectFailureKind(result, PlaybackFailureKind.unsupported);
  _expect(adapter.loadCount == 1, 'Unsupported source load must not delegate to adapter.');
}

void _verifySurfaceStateFromCapabilities() {
  final PlaybackSurfaceState transportState = PlaybackController(
    adapterResolver: _StaticAdapterResolver(
      _ConfigurablePlayerAdapter(
        capabilities: PlaybackCapabilityMatrix(
          capabilities: <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.seek: CapabilityStatus.supported(),
            PlaybackCapability.stop: CapabilityStatus.supported(),
            PlaybackCapability.progressReporting: CapabilityStatus.supported(),
          },
        ),
      ),
    ),
  ).resolveSurfaceState();

  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.playPause), 'Transport state must expose play/pause.');
  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.seek), 'Transport state must expose seek.');
  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.stop), 'Transport state must expose stop.');
  _expect(transportState.visibleControls.contains(PlaybackSurfaceControl.progress), 'Transport state must expose progress.');
  _expect(!transportState.visibleControls.contains(PlaybackSurfaceControl.audioTracks), 'Transport-only state must hide audio tracks.');
  _expect(!transportState.visibleControls.contains(PlaybackSurfaceControl.subtitleTracks), 'Transport-only state must hide subtitle tracks.');
  _expect(transportState.availablePanels.isEmpty, 'Transport-only state must not expose secondary panels.');

  final PlaybackSurfaceState trackState = PlaybackController(
    adapterResolver: _StaticAdapterResolver(
      _ConfigurablePlayerAdapter(
        capabilities: PlaybackCapabilityMatrix(
          capabilities: <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
            PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
            PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
          },
        ),
      ),
    ),
  ).resolveSurfaceState();

  _expect(trackState.visibleControls.contains(PlaybackSurfaceControl.audioTracks), 'Track state must expose audio track control.');
  _expect(trackState.visibleControls.contains(PlaybackSurfaceControl.subtitleTracks), 'Track state must expose subtitle track control.');
  _expect(trackState.availablePanels.contains(PlaybackSurfacePanel.tracks), 'Track state must expose tracks panel.');
}

void _verifyUndeclaredCapabilitiesRemainUnsupported() {
  final PlaybackCapabilityMatrix matrix = PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.playPause: CapabilityStatus.supported(),
    },
  );

  final CapabilityStatus status = matrix.statusOf(PlaybackCapability.hlsPlayback);
  _expect(!status.isSupported, 'Undeclared capability must be unsupported.');
  _expect(status.reason != null && status.reason!.isNotEmpty, 'Undeclared capability must include a reason.');
}

Future<void> _verifyTrackRuntimeChecks() async {
  final _InMemoryMpvBinding binding = _InMemoryMpvBinding(tracks: _tracks);
  final PlaybackController controller = PlaybackController(
    adapterResolver: _StaticAdapterResolver(MpvPlayerAdapterFacade.bound(binding: binding)),
  );

  final TrackDiscoveryResult discovery = await controller.discoverTracks();
  _expect(discovery.tracks.length == 2, 'Bound adapter must report normalized audio and subtitle tracks.');
  _expect(discovery.tracks.first.id.value == 'audio-main', 'Audio track id must be stable.');
  _expect(discovery.tracks.first.type == MediaTrackType.audio, 'First track must be audio.');
  _expect(discovery.tracks.last.type == MediaTrackType.subtitle, 'Second track must be subtitle.');

  final TrackSwitchResult switchResult = await controller.switchTrack(const MediaTrackId('subtitle-ja'));
  _expect(switchResult.isSuccess, 'Known track switch must succeed.');
  _expect(binding.switchedTrackId?.value == 'subtitle-ja', 'Track switch must route through the binding.');

  final _ConfigurablePlayerAdapter unsupportedTrackAdapter = _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackController unsupportedTrackController = PlaybackController(
    adapterResolver: _StaticAdapterResolver(unsupportedTrackAdapter),
  );
  final PlaybackSurfaceState state = unsupportedTrackController.resolveSurfaceState();
  _expect(!state.visibleControls.contains(PlaybackSurfaceControl.audioTracks), 'Unsupported audio track switching must be hidden.');
  _expect(!state.visibleControls.contains(PlaybackSurfaceControl.subtitleTracks), 'Unsupported subtitle track switching must be hidden.');
  _expect(!state.availablePanels.contains(PlaybackSurfacePanel.tracks), 'Unsupported track switching must hide tracks panel.');

  final TrackSwitchResult unsupportedSwitch = await unsupportedTrackController.switchTrack(const MediaTrackId('subtitle-ja'));
  _expect(!unsupportedSwitch.isSuccess, 'Controller must reject unsupported track switching before adapter delegation.');
  _expect(unsupportedTrackAdapter.switchCount == 0, 'Controller must not delegate unsupported track switching.');
}

LocalFilePlaybackSource _localSource() {
  return LocalFilePlaybackSource(uri: Uri.file('D:/media/example.mkv'));
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

final class _StaticAdapterResolver implements ActivePlayerAdapterResolver {
  const _StaticAdapterResolver(this.activeAdapter);

  @override
  final PlayerAdapter activeAdapter;
}

final class _InMemoryMpvBinding implements MpvAdapterBinding {
  _InMemoryMpvBinding({required List<MediaTrackDescriptor> tracks}) : _tracks = tracks;

  final List<MediaTrackDescriptor> _tracks;
  final List<PlaybackOperation> operations = <PlaybackOperation>[];
  PlaybackSource? loadedSource;
  MediaTrackId? switchedTrackId;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    operations.add(PlaybackOperation.load);
    loadedSource = source;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async {
    operations.add(PlaybackOperation.play);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    operations.add(PlaybackOperation.pause);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    operations.add(PlaybackOperation.seek);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    operations.add(PlaybackOperation.stop);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    operations.add(PlaybackOperation.dispose);
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    operations.add(PlaybackOperation.discoverTracks);
    return TrackDiscoveryResult(
      tracks: _tracks,
      capabilityMatrix: PlaybackCapabilityMatrix(
        capabilities: <PlaybackCapability, CapabilityStatus>{
          PlaybackCapability.audioTrackDiscovery: CapabilityStatus.supported(),
          PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackDiscovery: CapabilityStatus.supported(),
          PlaybackCapability.subtitleTrackSwitching: CapabilityStatus.supported(),
        },
      ),
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    operations.add(PlaybackOperation.switchTrack);
    switchedTrackId = trackId;
    return const TrackSwitchResult.success();
  }
}

final class _ConfigurablePlayerAdapter implements PlayerAdapter {
  _ConfigurablePlayerAdapter({
    required this.capabilities,
    TrackDiscoveryResult? discoveryResult,
    TrackSwitchResult? switchResult,
  })  : _discoveryResult = discoveryResult,
        _switchResult = switchResult;

  @override
  final PlaybackCapabilityMatrix capabilities;
  final TrackDiscoveryResult? _discoveryResult;
  final TrackSwitchResult? _switchResult;
  int loadCount = 0;
  int switchCount = 0;

  @override
  String get id => 'configurable-player-adapter';

  @override
  String get displayName => 'Configurable Player Adapter';

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    loadCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> play() async => const PlaybackCommandResult.success();

  @override
  Future<PlaybackCommandResult> pause() async => const PlaybackCommandResult.success();

  @override
  Future<PlaybackCommandResult> seek(Duration position) async => const PlaybackCommandResult.success();

  @override
  Future<PlaybackCommandResult> stop() async => const PlaybackCommandResult.success();

  @override
  Future<PlaybackCommandResult> dispose() async => const PlaybackCommandResult.success();

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return _discoveryResult ?? TrackDiscoveryResult.unsupported(reason: 'Track discovery is unsupported.');
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    switchCount += 1;
    return _switchResult ?? const TrackSwitchResult.success();
  }
}

void _expectSuccess(PlaybackCommandResult result) {
  _expect(result.isSuccess, 'Expected playback command to succeed, got ${result.failure?.message}.');
}

void _expectFailureKind(PlaybackCommandResult result, PlaybackFailureKind kind) {
  final PlaybackFailure? failure = result.failure;
  _expect(failure != null, 'Expected playback command to fail.');
  _expect(failure!.kind == kind, 'Expected failure kind $kind, got ${failure.kind}.');
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
