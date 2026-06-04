import '../lib/celesteria.dart';

Future<void> main() async {
  await _verifyUnsupportedMpvFacade();
  await _verifyBoundMpvFacadeDelegation();
  await _verifySourceCapabilityGating();
  await _verifyPlaybackSourceHandoff();
  await _verifyLocalMediaScannerContract();
  await _verifyMediaLibraryPersistenceContract();
  _verifySurfaceStateFromCapabilities();
  _verifyPlaybackPageSurfaceContract();
  await _verifyPlaybackPageIntentContract();
  _verifyPlaybackStateContract();
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

Future<void> _verifyPlaybackSourceHandoff() async {
  const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
  final LocalMediaIdentity identity = LocalMediaIdentity(
    id: const LocalMediaId('runtime-local-media'),
    uri: Uri.file('D:/media/handoff.mkv'),
    basename: 'handoff.mkv',
  );

  final PlaybackSourceHandoffResult prepared = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(identity),
  );
  _expect(prepared.isSuccess, 'Local file handoff must prepare a playback source.');
  _expect(prepared.source is LocalFilePlaybackSource, 'Local file handoff must reuse LocalFilePlaybackSource.');

  final PlaybackSourceHandoffResult unsupported = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(
      LocalMediaIdentity(
        id: const LocalMediaId('remote-local-media'),
        uri: Uri.parse('https://example.test/media.mkv'),
        basename: 'media.mkv',
      ),
    ),
  );
  _expect(!unsupported.isSuccess, 'Unsupported source handoff must return a failure result.');
  _expect(
    unsupported.failure?.kind == PlaybackSourceHandoffFailureKind.unsupportedScheme,
    'Unsupported source handoff must report unsupportedScheme.',
  );

  final PlaybackSourceHandoffResult missingSource = handoff.prepare(
    PlaybackSourceHandoffInput.localMediaIdentity(
      LocalMediaIdentity(
        id: const LocalMediaId('missing-source-local-media'),
        uri: Uri.parse(''),
        basename: 'missing-source.mkv',
      ),
    ),
  );
  _expect(!missingSource.isSuccess, 'Missing source handoff must return a failure result.');
  _expect(
    missingSource.failure?.kind == PlaybackSourceHandoffFailureKind.missingSourceData,
    'Missing source handoff must report missingSourceData.',
  );

  final MockPlaybackController controller = MockPlaybackController(
    matrix: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      },
    ),
  );
  _expectSuccess(await controller.open(prepared.source!));
  _expect(controller.currentState.sourceUri == identity.uri, 'Controller must open the prepared handoff source.');
}

Future<void> _verifyLocalMediaScannerContract() async {
  const MediaScanId scanId = MediaScanId('runtime-local-scan');
  final MediaScanCandidate candidate = MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: const LocalMediaId('runtime-scanned-media'),
      uri: Uri.file('D:/media/scanned.mkv'),
      basename: 'scanned.mkv',
    ),
    sizeBytes: 84,
  );
  final DeterministicMediaLibraryScanner scanner = DeterministicMediaLibraryScanner(
    scanId: scanId,
    candidates: <MediaScanCandidate>[candidate],
  );

  final MediaScanResult result = await scanner.scan(
    MediaScanScope(
      roots: <Uri>[Uri.file('D:/media/')],
      extensions: const <String>{'.MKV'},
    ),
  );
  _expect(result.candidates.single == candidate, 'Local scanner must preserve Domain media candidates.');
  _expect(result.failures.isEmpty, 'Supported local scanner scope must not report failures.');

  final List<MediaScanEvent> events = await scanner.watch(scanId).toList();
  _expect(events.whereType<MediaScanCandidateDiscovered>().length == 1, 'Local scanner must publish discovery events.');
  _expect(events.whereType<MediaScanCompleted>().length == 1, 'Local scanner must publish completion events.');

  final PlaybackSourceHandoffResult handoff = const LocalPlaybackSourceHandoff().prepare(
    PlaybackSourceHandoffInput.mediaScanCandidate(result.candidates.single),
  );
  _expect(handoff.source is LocalFilePlaybackSource, 'Scanner-produced candidates must remain handoff-safe.');

  final MediaScanScopeNormalizationResult unsupported = normalizeMediaScanScope(
    MediaScanScope(
      roots: <Uri>[Uri.parse('https://example.test/media/')],
      extensions: const <String>{'mkv'},
    ),
  );
  _expect(!unsupported.isSuccess, 'Unsupported scanner roots must normalize to failures.');
  _expect(
    unsupported.failures.single.kind == MediaScanFailureKind.unsupportedScheme,
    'Unsupported scanner roots must report unsupportedScheme.',
  );

  const MediaScanId cancelledScanId = MediaScanId('runtime-cancelled-scan');
  final DeterministicMediaLibraryScanner cancelledScanner = DeterministicMediaLibraryScanner(scanId: cancelledScanId);
  await cancelledScanner.cancel(cancelledScanId);
  final MediaScanResult cancelledResult = await cancelledScanner.scan(
    MediaScanScope(
      roots: <Uri>[Uri.file('D:/media/')],
      extensions: const <String>{'mkv'},
    ),
  );
  _expect(cancelledResult.failures.single.kind == MediaScanFailureKind.cancelled, 'Cancelled scans must report typed cancellation.');
}

Future<void> _verifyMediaLibraryPersistenceContract() async {
  final DeterministicMediaLibraryCatalogRepository repository = DeterministicMediaLibraryCatalogRepository();
  final MediaScanCandidate candidate = MediaScanCandidate(
    identity: LocalMediaIdentity(
      id: const LocalMediaId('runtime-import-media'),
      uri: Uri.file('D:/media/imported.mkv'),
      basename: 'imported.mkv',
      fingerprint: const MediaFileFingerprint(algorithm: 'sha256', value: 'runtime-fingerprint'),
    ),
    sizeBytes: 128,
    duration: const Duration(minutes: 24),
  );
  final DeterministicMediaBatchImportContract importer = DeterministicMediaBatchImportContract(repository: repository);

  final MediaImportResult imported = await importer.importBatch(<MediaScanCandidate>[candidate]);
  final MediaImportResult duplicated = await importer.importBatch(<MediaScanCandidate>[candidate]);
  _expect(imported.importedCount == 1, 'Media library import must create catalog items.');
  _expect(duplicated.skippedDuplicateCount == 1, 'Media library import must skip duplicate candidates.');
  _expect(await repository.count() == 1, 'Media library repository must retain one imported item.');
  _expect((await repository.findByUri(candidate.identity.uri)) != null, 'Media library repository must find items by URI.');

  final DeterministicPlaybackHistoryStore history = DeterministicPlaybackHistoryStore();
  await history.record(
    PlaybackHistoryEntry(
      id: const PlaybackHistoryEntryId('runtime-history'),
      mediaId: candidate.identity.id,
      position: const Duration(minutes: 8),
      duration: const Duration(minutes: 16),
      updatedAt: DateTime.utc(2026, 6, 4, 12),
    ),
  );
  _expect((await history.latestFor(candidate.identity.id)) != null, 'Playback history must return latest entries.');
  _expect((await history.continueWatching()).single.progress == 0.5, 'Playback history must derive continue-watching progress.');

  final DeterministicProviderBindingStore bindings = DeterministicProviderBindingStore();
  final ProviderBinding userConfirmed = ProviderBinding(
    id: const ProviderBindingId('runtime-binding'),
    localMediaId: candidate.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('subject-runtime'),
    authority: ProviderBindingAuthority.userConfirmed,
    confidence: 0.2,
    createdAt: DateTime.utc(2026, 6, 4, 12),
  );
  final ProviderBinding automatic = ProviderBinding(
    id: const ProviderBindingId('runtime-automatic-binding'),
    localMediaId: candidate.identity.id,
    providerId: 'bangumi',
    subjectId: const ProviderSubjectId('subject-runtime-auto'),
    authority: ProviderBindingAuthority.automatic,
    confidence: 1,
    createdAt: DateTime.utc(2026, 6, 4, 12),
  );
  await bindings.saveUserConfirmed(userConfirmed);
  _expect(await bindings.saveAutomaticIfAllowed(automatic) == userConfirmed, 'User-confirmed bindings must outrank automatic matches.');
  _expect((await bindings.bindingFor(candidate.identity.id)) == userConfirmed, 'Binding store must expose strongest binding.');

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final Future<List<CacheInvalidationEvent>> events = bus.events.take(2).toList();
  bus.publish(
    LibraryItemAdded(
      occurredAt: DateTime.utc(2026, 6, 4, 12),
      mediaLibraryItemId: imported.imported.single.id.value,
      localMediaId: candidate.identity.id.value,
    ),
  );
  bus.publish(HistoryRecorded(occurredAt: DateTime.utc(2026, 6, 4, 12), localMediaId: candidate.identity.id.value));
  final List<CacheInvalidationEvent> delivered = await events;
  await bus.close();
  _expect(delivered.whereType<LibraryItemAdded>().single.changeKind == MediaLibraryChangeKind.created, 'Library add event must preserve change kind.');
  _expect(delivered.whereType<HistoryRecorded>().single.localMediaId == candidate.identity.id.value, 'History event must preserve local media id.');
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

void _verifyPlaybackPageSurfaceContract() {
  final PlaybackPageSurfaceDescriptor transportSurface = PlaybackPageContract(
    controller: PlaybackController(
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
    ),
  ).resolveSurface();

  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.playPause), 'Playback page surface must expose active play/pause control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.seek), 'Playback page surface must expose active seek control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.stop), 'Playback page surface must expose active stop control.');
  _expect(transportSurface.hasActiveControl(PlaybackPageControlId.progress), 'Playback page surface must expose active progress control.');
  _expect(!transportSurface.hasActiveControl(PlaybackPageControlId.audioTracks), 'Playback page surface must hide unsupported audio track control.');
  _expect(!transportSurface.hasActiveControl(PlaybackPageControlId.subtitleTracks), 'Playback page surface must hide unsupported subtitle track control.');
  _expect(!transportSurface.hasActivePanel(PlaybackPagePanelId.tracks), 'Playback page surface must hide unsupported tracks panel.');

  final PlaybackPageSurfaceDescriptor trackSurface = PlaybackPageContract(
    controller: PlaybackController(
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
    ),
  ).resolveSurface();

  _expect(trackSurface.hasActiveControl(PlaybackPageControlId.audioTracks), 'Playback page surface must expose supported audio track control.');
  _expect(trackSurface.hasActiveControl(PlaybackPageControlId.subtitleTracks), 'Playback page surface must expose supported subtitle track control.');
  _expect(trackSurface.hasActivePanel(PlaybackPagePanelId.tracks), 'Playback page surface must expose supported tracks panel.');
}

Future<void> _verifyPlaybackPageIntentContract() async {
  final _ConfigurablePlayerAdapter supportedAdapter = _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
        PlaybackCapability.seek: CapabilityStatus.supported(),
        PlaybackCapability.stop: CapabilityStatus.supported(),
        PlaybackCapability.audioTrackSwitching: CapabilityStatus.supported(),
        PlaybackCapability.secondaryPanels: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackPageContract supportedContract = PlaybackPageContract(
    controller: PlaybackController(adapterResolver: _StaticAdapterResolver(supportedAdapter)),
  );

  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.play()),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.pause()),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.seek(Duration(seconds: 32))),
    PlaybackPageIntentOutcome.executed,
  );
  _expectIntentOutcome(
    await supportedContract.dispatch(const PlaybackPageIntent.stop()),
    PlaybackPageIntentOutcome.executed,
  );

  final PlaybackPageIntentResult panelResult = await supportedContract.dispatch(
    const PlaybackPageIntent.openPanel(PlaybackPagePanelId.tracks),
  );
  _expectIntentOutcome(panelResult, PlaybackPageIntentOutcome.executed);
  _expect(panelResult.panelId == PlaybackPagePanelId.tracks, 'Open-panel intent must preserve panel id.');

  final PlaybackPageIntentResult trackResult = await supportedContract.dispatch(
    const PlaybackPageIntent.selectTrack(
      trackId: DomainMediaTrackId('audio-main'),
      trackType: DomainMediaTrackType.audio,
    ),
  );
  _expectIntentOutcome(trackResult, PlaybackPageIntentOutcome.executed);
  _expect(trackResult.trackSwitchResult?.isSuccess ?? false, 'Track intent must preserve switch result.');

  _expect(supportedAdapter.playCount == 1, 'Play intent must dispatch through PlaybackController.play.');
  _expect(supportedAdapter.pauseCount == 1, 'Pause intent must dispatch through PlaybackController.pause.');
  _expect(supportedAdapter.seekCount == 1, 'Seek intent must dispatch through PlaybackController.seek.');
  _expect(supportedAdapter.stopCount == 1, 'Stop intent must dispatch through PlaybackController.stop.');
  _expect(supportedAdapter.switchCount == 1, 'Track intent must dispatch through PlaybackController.switchTrack.');
  _expect(supportedAdapter.switchedTrackId?.value == 'audio-main', 'Track intent must use Domain-facing track id.');

  final _ConfigurablePlayerAdapter unsupportedAdapter = _ConfigurablePlayerAdapter(
    capabilities: PlaybackCapabilityMatrix(
      capabilities: <PlaybackCapability, CapabilityStatus>{
        PlaybackCapability.playPause: CapabilityStatus.supported(),
      },
    ),
  );
  final PlaybackPageContract unsupportedContract = PlaybackPageContract(
    controller: PlaybackController(adapterResolver: _StaticAdapterResolver(unsupportedAdapter)),
  );

  _expectIntentOutcome(
    await unsupportedContract.dispatch(const PlaybackPageIntent.seek(Duration(seconds: 4))),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(const PlaybackPageIntent.openPanel(PlaybackPagePanelId.tracks)),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(
      const PlaybackPageIntent.selectTrack(
        trackId: DomainMediaTrackId('subtitle-ja'),
        trackType: DomainMediaTrackType.subtitle,
      ),
    ),
    PlaybackPageIntentOutcome.unsupported,
  );
  _expectIntentOutcome(
    await unsupportedContract.dispatch(const PlaybackPageIntent.noop()),
    PlaybackPageIntentOutcome.ignored,
  );

  _expect(unsupportedAdapter.seekCount == 0, 'Unsupported seek intent must not delegate to adapter.');
  _expect(unsupportedAdapter.switchCount == 0, 'Unsupported track intent must not delegate to adapter.');
}

void _verifyPlaybackStateContract() {
  final DateTime observedAt = DateTime.utc(2026, 6, 3, 10, 0);
  final PlaybackStateSnapshot pausedSnapshot = PlaybackStateSnapshot(
    status: PlaybackLifecycleStatus.paused,
    timeline: PlaybackTimelineState(
      position: const Duration(minutes: 12, seconds: 4),
      duration: const Duration(minutes: 24),
      observedAt: observedAt,
    ),
    activeTracks: const ActivePlaybackTrackState(
      audioTrackId: DomainMediaTrackId('audio-main'),
      subtitleTrackId: DomainMediaTrackId('subtitle-ja'),
    ),
    sourceUri: Uri.parse('file:///D:/media/example.mkv'),
  );

  _expect(pausedSnapshot.status == PlaybackLifecycleStatus.paused, 'Playback state must preserve lifecycle status.');
  _expect(pausedSnapshot.timeline.position == const Duration(minutes: 12, seconds: 4), 'Playback state must preserve timeline position.');
  _expect(pausedSnapshot.timeline.duration == const Duration(minutes: 24), 'Playback state must preserve timeline duration.');
  _expect(pausedSnapshot.timeline.observedAt == observedAt, 'Playback state must preserve timeline observation timestamp.');
  _expect(pausedSnapshot.activeTracks.audioTrackId?.value == 'audio-main', 'Playback state must preserve active audio track id.');
  _expect(pausedSnapshot.activeTracks.subtitleTrackId?.value == 'subtitle-ja', 'Playback state must preserve active subtitle track id.');

  const PlaybackStateSnapshot bufferingSnapshot = PlaybackStateSnapshot(
    status: PlaybackLifecycleStatus.buffering,
    buffering: PlaybackBufferingState(
      isBuffering: true,
      bufferedPosition: Duration(minutes: 14),
      bufferedFraction: 0.58,
    ),
  );
  _expect(bufferingSnapshot.buffering.isBuffering, 'Playback state must represent buffering as data.');
  _expect(bufferingSnapshot.buffering.bufferedPosition == const Duration(minutes: 14), 'Playback state must preserve buffered position.');
  _expect(bufferingSnapshot.buffering.bufferedFraction == 0.58, 'Playback state must preserve buffered fraction.');

  final _ManualPlaybackStateObservable observable = _ManualPlaybackStateObservable(
    initialState: const PlaybackStateSnapshot(status: PlaybackLifecycleStatus.idle),
  );
  final _RecordingPlaybackStateObserver observer = _RecordingPlaybackStateObserver();
  observable.addPlaybackStateObserver(observer);
  observable.publish(pausedSnapshot);
  _expect(observable.currentState == pausedSnapshot, 'Playback state observable must expose the current snapshot.');
  _expect(observer.snapshots.single == pausedSnapshot, 'Playback state observer must receive published snapshots.');

  observable.removePlaybackStateObserver(observer);
  observable.publish(bufferingSnapshot);
  _expect(observer.snapshots.length == 1, 'Removed playback state observer must not receive snapshots.');
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

  final TrackSwitchResult switchResult = await controller.switchTrack(const DomainMediaTrackId('subtitle-ja'));
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

  final TrackSwitchResult unsupportedSwitch = await unsupportedTrackController.switchTrack(const DomainMediaTrackId('subtitle-ja'));
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
  int playCount = 0;
  int pauseCount = 0;
  int seekCount = 0;
  int stopCount = 0;
  int switchCount = 0;
  MediaTrackId? switchedTrackId;

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
  Future<PlaybackCommandResult> play() async {
    playCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    pauseCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    seekCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> stop() async {
    stopCount += 1;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<PlaybackCommandResult> dispose() async => const PlaybackCommandResult.success();

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return _discoveryResult ?? TrackDiscoveryResult.unsupported(reason: 'Track discovery is unsupported.');
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    switchCount += 1;
    switchedTrackId = trackId;
    return _switchResult ?? const TrackSwitchResult.success();
  }
}

final class _RecordingPlaybackStateObserver implements PlaybackStateObserver {
  final List<PlaybackStateSnapshot> snapshots = <PlaybackStateSnapshot>[];

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}

final class _ManualPlaybackStateObservable implements PlaybackStateObservable {
  _ManualPlaybackStateObservable({required PlaybackStateSnapshot initialState}) : _currentState = initialState;

  PlaybackStateSnapshot _currentState;
  final List<PlaybackStateObserver> _observers = <PlaybackStateObserver>[];

  @override
  PlaybackStateSnapshot get currentState => _currentState;

  @override
  void addPlaybackStateObserver(PlaybackStateObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  @override
  void removePlaybackStateObserver(PlaybackStateObserver observer) {
    _observers.remove(observer);
  }

  void publish(PlaybackStateSnapshot snapshot) {
    _currentState = snapshot;
    for (final PlaybackStateObserver observer in List<PlaybackStateObserver>.of(_observers)) {
      observer.onPlaybackState(snapshot);
    }
  }
}

void _expectIntentOutcome(PlaybackPageIntentResult result, PlaybackPageIntentOutcome outcome) {
  _expect(result.outcome == outcome, 'Expected playback page intent outcome $outcome, got ${result.outcome}.');
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
