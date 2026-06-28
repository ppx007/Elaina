// Player core runtime tests protect adapter lifecycle and capability-gated
// commands. UI pages should depend on this contract rather than adapter details.
// Add adapter quirks in adapter tests after the core command semantics are set.
import 'dart:async';

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

  test('runtime capability matrix follows latest probe snapshot', () async {
    final _MutableCapabilityProbeSource probe = _MutableCapabilityProbeSource(
      _matrix(<PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause:
            const CapabilityStatus.unsupported('probe says no playback'),
      }),
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(),
      capabilities: mediaKitLocalFilePlaybackCapabilities(),
      capabilityProbeSource: probe,
    );

    expect(
      runtime.controller.matrix.supports(PlaybackCapability.playPause),
      isFalse,
    );
    expect((await runtime.controller.play()).isSuccess, isFalse);

    probe.matrix = _matrix(<PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.playPause: const CapabilityStatus.supported(),
    });

    expect(
      runtime.controller.matrix.supports(PlaybackCapability.playPause),
      isTrue,
    );
    expect((await runtime.controller.play()).isSuccess, isTrue);

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

  test('runtime follows concrete telemetry for timeline and buffering',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(
        duration: const Duration(minutes: 24),
        bufferedPosition: const Duration(minutes: 2),
        observedAt: _telemetryObservedAt,
      ),
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(tracks: _tracks),
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );
    final _RecordingObserver observer = _RecordingObserver();
    runtime.controller.addPlaybackStateObserver(observer);

    telemetry.emit(
      PlayerTelemetrySnapshot(
        playing: true,
        position: const Duration(seconds: 12),
        duration: const Duration(minutes: 24),
        bufferedPosition: const Duration(minutes: 6),
        observedAt: _telemetryObservedAt,
      ),
    );

    expect(runtime.currentState.status, PlaybackLifecycleStatus.playing);
    expect(runtime.currentState.timeline.position, const Duration(seconds: 12));
    expect(runtime.currentState.timeline.duration, const Duration(minutes: 24));
    expect(runtime.currentState.timeline.observedAt, _telemetryObservedAt);
    expect(runtime.currentState.buffering.bufferedPosition,
        const Duration(minutes: 6));
    expect(runtime.currentState.buffering.bufferedFraction, 0.25);

    await runtime.controller.seek(const Duration(seconds: 30));
    telemetry.emit(
      PlayerTelemetrySnapshot(
        playing: true,
        position: const Duration(seconds: 36),
        duration: const Duration(minutes: 24),
        bufferedPosition: const Duration(minutes: 8),
        observedAt: _laterTelemetryObservedAt,
      ),
    );

    expect(runtime.currentState.timeline.position, const Duration(seconds: 36));
    expect(runtime.currentState.timeline.observedAt, _laterTelemetryObservedAt);
    expect(
      observer.snapshots
          .map((PlaybackStateSnapshot snapshot) => snapshot.status),
      contains(PlaybackLifecycleStatus.playing),
    );

    await runtime.dispose();
    await telemetry.close();
  });

  test('runtime uses injected clock for command-observed timeline updates',
      () async {
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(tracks: _tracks),
      capabilities: _fullPlayerCoreMatrix(),
      now: () => _commandObservedAt,
    );

    await runtime.controller.seek(const Duration(seconds: 30));

    expect(runtime.currentState.timeline.position, const Duration(seconds: 30));
    expect(runtime.currentState.timeline.observedAt, _commandObservedAt);

    await runtime.dispose();
  });

  test('runtime maps telemetry lifecycle and failure states', () async {
    final _FakeTelemetrySource telemetry =
        _FakeTelemetrySource(PlayerTelemetrySnapshot());
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(tracks: _tracks),
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );

    telemetry.emit(PlayerTelemetrySnapshot(buffering: true));
    expect(runtime.currentState.status, PlaybackLifecycleStatus.buffering);

    telemetry.emit(PlayerTelemetrySnapshot(completed: true));
    expect(runtime.currentState.status, PlaybackLifecycleStatus.ended);

    telemetry.emit(PlayerTelemetrySnapshot());
    expect(runtime.currentState.status, PlaybackLifecycleStatus.ended);

    telemetry.emit(PlayerTelemetrySnapshot(failureReason: 'decoder failed'));
    expect(runtime.currentState.status, PlaybackLifecycleStatus.failed);
    expect(runtime.currentState.failureReason, 'decoder failed');

    await runtime.dispose();
    await telemetry.close();
  });

  test('telemetry copyWith can clear active tracks', () {
    final PlayerTelemetrySnapshot snapshot = PlayerTelemetrySnapshot(
      activeAudioTrackId: const MediaTrackId('audio-main'),
      activeSubtitleTrackId: const MediaTrackId('subtitle-ja'),
      observedAt: _telemetryObservedAt,
    );

    final PlayerTelemetrySnapshot cleared = snapshot.copyWith(
      clearActiveAudioTrackId: true,
      clearActiveSubtitleTrackId: true,
    );

    expect(cleared.activeAudioTrackId, isNull);
    expect(cleared.activeSubtitleTrackId, isNull);
    expect(cleared.observedAt, _telemetryObservedAt);
  });

  test('runtime mirrors active subtitle telemetry into subtitle state',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(),
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: DeterministicMpvBinding(tracks: _multiSubtitleTracks),
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    telemetry.emit(
      PlayerTelemetrySnapshot(
        tracks: _multiSubtitleTracks,
        activeSubtitleTrackId: const MediaTrackId('subtitle-zh-hans'),
      ),
    );

    expect(
      runtime.currentState.activeTracks.subtitleTrackId?.value,
      'subtitle-zh-hans',
    );
    expect(
      runtime.currentState.subtitles.selectedTrackId,
      'subtitle-zh-hans',
    );

    telemetry.emit(
      PlayerTelemetrySnapshot(
        tracks: _multiSubtitleTracks,
      ),
    );
    expect(
      runtime.currentState.activeTracks.subtitleTrackId?.value,
      'subtitle-zh-hans',
    );
    expect(
      runtime.currentState.subtitles.selectedTrackId,
      'subtitle-zh-hans',
    );

    telemetry.emit(PlayerTelemetrySnapshot());
    expect(runtime.currentState.activeTracks.subtitleTrackId, isNull);
    expect(runtime.currentState.subtitles.selectedTrackId, isNull);

    await runtime.dispose();
    await telemetry.close();
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

    final TrackSwitchResult subtitleSwitch =
        await runtime.controller.switchTrack(
      const DomainMediaTrackId('subtitle-ja'),
      trackType: DomainMediaTrackType.subtitle,
    );
    expect(subtitleSwitch.isSuccess, isTrue);
    expect(runtime.currentState.activeTracks.subtitleTrackId?.value,
        'subtitle-ja');
    expect(runtime.currentState.subtitles.selectedTrackId, 'subtitle-ja');

    await runtime.dispose();
  });

  test('runtime auto-selects simplified Chinese subtitle once per source',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(),
    );
    final DeterministicMpvBinding binding = DeterministicMpvBinding(
      tracks: _multiSubtitleTracks,
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    telemetry.emit(PlayerTelemetrySnapshot(tracks: _multiSubtitleTracks));
    await Future<void>.delayed(Duration.zero);

    expect(binding.switchedTrackId?.value, 'subtitle-zh-hans');
    expect(
      runtime.controller.subtitleAutoSelection.rule,
      SubtitleAutoSelectionRule.simplifiedChinese,
    );
    expect(
      runtime.currentState.activeTracks.subtitleTrackId?.value,
      'subtitle-zh-hans',
    );
    expect(
      runtime.currentState.subtitles.selectedTrackId,
      'subtitle-zh-hans',
    );

    telemetry.emit(PlayerTelemetrySnapshot(tracks: _customRegexTracks));
    await Future<void>.delayed(Duration.zero);
    expect(binding.switchedTrackId?.value, 'subtitle-zh-hans');

    await runtime.dispose();
    await telemetry.close();
  });

  test('runtime custom subtitle regex has priority over built-in preference',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(),
    );
    final DeterministicMpvBinding binding = DeterministicMpvBinding(
      tracks: _customRegexTracks,
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
      subtitleAutoSelectPreferencesProvider: () async {
        return const SubtitleAutoSelectPreferences(
          customPattern: 'Signs',
        );
      },
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    telemetry.emit(PlayerTelemetrySnapshot(tracks: _customRegexTracks));
    await Future<void>.delayed(Duration.zero);

    expect(binding.switchedTrackId?.value, 'subtitle-signs');
    expect(
      runtime.controller.subtitleAutoSelection.rule,
      SubtitleAutoSelectionRule.customRegex,
    );

    await runtime.dispose();
    await telemetry.close();
  });

  test('runtime manual subtitle selection prevents later auto-selection',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(),
    );
    final DeterministicMpvBinding binding = DeterministicMpvBinding(
      tracks: _multiSubtitleTracks,
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    final TrackSwitchResult manual = await runtime.controller.switchTrack(
      const DomainMediaTrackId('subtitle-ja'),
      trackType: DomainMediaTrackType.subtitle,
    );
    expect(manual.isSuccess, isTrue);
    telemetry.emit(PlayerTelemetrySnapshot(tracks: _multiSubtitleTracks));
    await Future<void>.delayed(Duration.zero);

    expect(binding.switchedTrackId?.value, 'subtitle-ja');
    expect(
      runtime.controller.subtitleAutoSelection.status,
      SubtitleAutoSelectionStatus.manualOverride,
    );

    await runtime.dispose();
    await telemetry.close();
  });

  test('runtime replays subtitle style after source load and subtitle switch',
      () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding(
      tracks: _multiSubtitleTracks,
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );

    final PlaybackCommandResult styleResult =
        await runtime.controller.applySubtitleStyle(
      SubtitleStyleProfile.defaults.copyWith(fontSize: 30),
    );
    expect(styleResult.isSuccess, isTrue);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.applySubtitleStyle)
          .length,
      1,
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.applySubtitleStyle)
          .length,
      2,
    );
    expect(binding.appliedSubtitleStyle?.fontSize, 30);
    expect(
      runtime.controller.subtitleStyleApplication.status,
      DomainSubtitleStyleApplicationStatus.applied,
    );

    final TrackSwitchResult switched = await runtime.controller.switchTrack(
      const DomainMediaTrackId('subtitle-zh-hans'),
      trackType: DomainMediaTrackType.subtitle,
    );
    expect(switched.isSuccess, isTrue);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.applySubtitleStyle)
          .length,
      3,
    );

    await runtime.dispose();
  });

  test('runtime replays subtitle style when telemetry selects subtitle track',
      () async {
    final _FakeTelemetrySource telemetry = _FakeTelemetrySource(
      PlayerTelemetrySnapshot(),
    );
    final DeterministicMpvBinding binding = DeterministicMpvBinding(
      tracks: _multiSubtitleTracks,
    );
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
      telemetrySource: telemetry,
    );

    expect(
      (await runtime.controller.applySubtitleStyle(
        SubtitleStyleProfile.defaults.copyWith(fontSize: 32),
      ))
          .isSuccess,
      isTrue,
    );
    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.applySubtitleStyle)
          .length,
      2,
    );

    telemetry.emit(
      PlayerTelemetrySnapshot(
        tracks: _multiSubtitleTracks,
        activeSubtitleTrackId: const MediaTrackId('subtitle-zh-hans'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(binding.appliedSubtitleStyle?.fontSize, 32);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.applySubtitleStyle)
          .length,
      3,
    );

    await runtime.dispose();
    await telemetry.close();
  });

  test('runtime toggles native subtitle visibility through adapter', () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding();
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );

    expect(
      (await runtime.controller.setSubtitleVisibility(false)).isSuccess,
      isTrue,
    );

    expect(binding.subtitleVisible, isFalse);
    expect(
      binding.operations,
      contains(PlaybackOperation.setSubtitleVisibility),
    );

    await runtime.dispose();
  });

  test('runtime replays subtitle visibility after source load', () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding();
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _fullPlayerCoreMatrix(),
    );

    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);
    expect(binding.subtitleVisible, isTrue);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.setSubtitleVisibility)
          .length,
      1,
    );

    expect(
      (await runtime.controller.setSubtitleVisibility(false)).isSuccess,
      isTrue,
    );
    expect((await runtime.controller.open(_localSource())).isSuccess, isTrue);

    expect(binding.subtitleVisible, isFalse);
    expect(
      binding.operations
          .where((PlaybackOperation operation) =>
              operation == PlaybackOperation.setSubtitleVisibility)
          .length,
      3,
    );

    await runtime.dispose();
  });

  test('runtime applies and disables video enhancement through adapter',
      () async {
    final DeterministicMpvBinding binding = DeterministicMpvBinding();
    final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: _matrix(<PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.videoEnhancement: const CapabilityStatus.supported(),
        PlaybackCapability.anime4kPreset: const CapabilityStatus.supported(),
      }),
    );

    final DomainVideoEnhancementApplyResult applied =
        await runtime.controller.applyVideoEnhancement(
      const DomainVideoEnhancementProfileDescriptor(
        preset: VideoEnhancementPresetSelection.restoreAndUpscale,
      ),
    );

    expect(applied.isSuccess, isTrue);
    expect(binding.activeEnhancementProfile?.anime4kPreset,
        Anime4kPresetIntent.restoreAndUpscale);

    final DomainVideoEnhancementApplyResult disabled =
        await runtime.controller.disableVideoEnhancement();

    expect(disabled.isSuccess, isTrue);
    expect(binding.enhancementDisabled, isTrue);
    expect(binding.activeEnhancementProfile, isNull);
    expect(
      binding.operations,
      containsAll(<PlaybackOperation>[
        PlaybackOperation.applyEnhancement,
        PlaybackOperation.disableEnhancement,
      ]),
    );

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

    expect(unsupportedSourceResult.isSuccess, isTrue);
    expect(binding.operations, <PlaybackOperation>[
      PlaybackOperation.load,
      PlaybackOperation.setSubtitleVisibility,
    ]);
    expect(runtime.currentState.status, PlaybackLifecycleStatus.paused);
    expect(runtime.currentState.failureReason, isNull);
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
      PlaybackCapability.assSubtitleEnhancement: CapabilityStatus.supported(),
      PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
    },
  );
}

PlaybackCapabilityMatrix _matrix(
  Map<PlaybackCapability, CapabilityStatus> capabilities,
) {
  return PlaybackCapabilityMatrix(capabilities: capabilities);
}

final class _MutableCapabilityProbeSource
    implements PlaybackCapabilityProbeSource {
  _MutableCapabilityProbeSource(this.matrix);

  PlaybackCapabilityMatrix matrix;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    return PlaybackCapabilityProbeSnapshot(
      capabilities: matrix,
      checkedAt: DateTime.utc(2026, 6, 27, 12),
      source: 'test-probe',
      backendLabel: 'test-backend',
    );
  }
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

const List<MediaTrackDescriptor> _multiSubtitleTracks = <MediaTrackDescriptor>[
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
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-zh-hant'),
    type: MediaTrackType.subtitle,
    label: '繁体中文',
    languageCode: 'zh-Hant',
  ),
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-zh-hans'),
    type: MediaTrackType.subtitle,
    label: '简体中文 CHS',
    languageCode: 'zh-Hans',
  ),
];

const List<MediaTrackDescriptor> _customRegexTracks = <MediaTrackDescriptor>[
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-zh-hans'),
    type: MediaTrackType.subtitle,
    label: '简体中文',
    languageCode: 'zh-Hans',
  ),
  MediaTrackDescriptor(
    id: MediaTrackId('subtitle-signs'),
    type: MediaTrackType.subtitle,
    label: 'Signs and Songs',
    languageCode: 'en',
  ),
];

final DateTime _telemetryObservedAt = DateTime.utc(2026, 6, 27, 9);
final DateTime _laterTelemetryObservedAt = DateTime.utc(2026, 6, 27, 9, 1);
final DateTime _commandObservedAt = DateTime.utc(2026, 6, 27, 9, 2);

final class _RecordingObserver implements PlaybackStateObserver {
  final List<PlaybackStateSnapshot> snapshots = <PlaybackStateSnapshot>[];

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}

final class _FakeTelemetrySource implements PlayerTelemetrySource {
  _FakeTelemetrySource(this._currentTelemetry);

  final StreamController<PlayerTelemetrySnapshot> _controller =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);
  PlayerTelemetrySnapshot _currentTelemetry;

  @override
  PlayerTelemetrySnapshot get currentTelemetry => _currentTelemetry;

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => _controller.stream;

  void emit(PlayerTelemetrySnapshot snapshot) {
    _currentTelemetry = snapshot;
    _controller.add(snapshot);
  }

  Future<void> close() => _controller.close();
}
