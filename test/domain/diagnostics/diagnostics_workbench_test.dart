import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/runtime_test_fakes.dart';

void main() {
  test('workbench aggregates playback details and provider settings', () async {
    final FakeSettingsRuntime settingsRuntime = FakeSettingsRuntime();
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.bangumiAccessToken,
      value: 'token-1',
    );
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.bangumiMirrorEnabled,
      value: BangumiMirrorSettings.enabledValue,
    );
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.bangumiMirrorApiBaseUrl,
      value: 'https://bgm-api.example.test',
    );
    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.bangumiMirrorImageBaseUrl,
      value: 'https://bgm-image.example.test',
    );
    await settingsRuntime.saveProxyUrl('http://127.0.0.1:8888');
    await settingsRuntime.saveDnsPolicy('https://dns.google/dns-query');

    final DefaultDiagnosticsWorkbenchRuntime workbench = _workbench(
      settingsRuntime: settingsRuntime,
      playbackController: MockPlaybackController(
        matrix: PlaybackCapabilityMatrix(
          capabilities: const <PlaybackCapability, CapabilityStatus>{
            PlaybackCapability.playPause: CapabilityStatus.supported(),
            PlaybackCapability.audioTrackDiscovery:
                CapabilityStatus.unsupported('No native track probe.'),
          },
        ),
        initialState: PlaybackStateSnapshot(
          status: PlaybackLifecycleStatus.playing,
          sourceUri: Uri.parse('file:///D:/Anime/workbench.mkv'),
          timeline: const PlaybackTimelineState(
            position: Duration(minutes: 2),
            duration: Duration(minutes: 24),
          ),
          buffering: const PlaybackBufferingState(bufferedFraction: 0.5),
          activeTracks: const ActivePlaybackTrackState(
            audioTrackId: DomainMediaTrackId('audio-jpn'),
            subtitleTrackId: DomainMediaTrackId('subtitle-zh'),
          ),
          subtitles: PlaybackSubtitleStateSnapshot(
            availableTracks: const <DomainSubtitleTrackDescriptor>[
              DomainSubtitleTrackDescriptor(id: 'subtitle-zh', format: 'ass'),
            ],
            selectedTrackId: 'subtitle-zh',
            activeCues: <DomainSubtitleCueDescriptor>[
              DomainSubtitleCueDescriptor(
                start: Duration(seconds: 1),
                end: Duration(seconds: 2),
                text: '主字幕',
              ),
            ],
          ),
          danmaku: PlaybackDanmakuStateSnapshot(
            matrix: PlaybackMatrixDanmakuStateSnapshot(
              clockPosition: const Duration(seconds: 1),
              comments: const <DomainMatrixDanmakuCommentDescriptor>[
                DomainMatrixDanmakuCommentDescriptor(
                  id: 'd1',
                  timestamp: Duration(seconds: 1),
                  text: '矩阵弹幕',
                  mode: DomainDanmakuMode.scrolling,
                ),
              ],
              rendererSource: 'flutter-custom-painter-overlay',
            ),
            lanes: <DomainDanmakuLaneDescriptor>[
              DomainDanmakuLaneDescriptor(
                mode: DomainDanmakuMode.scrolling,
                comments: const <DomainDanmakuCommentDescriptor>[
                  DomainDanmakuCommentDescriptor(
                    id: 'd1',
                    timestamp: Duration(seconds: 1),
                    text: '弹幕',
                    mode: DomainDanmakuMode.scrolling,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      backendProbeRuntime: _FakeBackendProbeRuntime(
        playback: PlaybackCapabilityProbeSnapshot(
          capabilities: PlaybackCapabilityMatrix(
            capabilities: const <PlaybackCapability, CapabilityStatus>{
              PlaybackCapability.playPause: CapabilityStatus.supported(),
              PlaybackCapability.audioTrackDiscovery:
                  CapabilityStatus.unsupported('No native track probe.'),
            },
          ),
          checkedAt: DateTime.utc(2026, 6, 27, 10),
          source: 'unit-probe',
          backendLabel: 'unit-backend',
          details: const <String, String>{
            'matrixDanmakuRenderer': 'flutter-custom-painter-overlay',
          },
        ),
      ),
    );

    final DiagnosticsWorkbenchSnapshot snapshot = await workbench.snapshot();

    expect(snapshot.playback!.sourceUri, 'file:///D:/Anime/workbench.mkv');
    expect(snapshot.playback!.activeAudioTrackId, 'audio-jpn');
    expect(snapshot.playback!.activeSubtitleCueCount, 1);
    expect(snapshot.playback!.visibleDanmakuCommentCount, 1);
    expect(snapshot.playback!.matrixDanmakuRenderedCommentCount, 1);
    expect(
      snapshot.playback!.matrixDanmakuRendererSource,
      'flutter-custom-painter-overlay',
    );
    expect(
      snapshot.playback!.capabilities
          .singleWhere((DiagnosticsCapabilityEntry entry) =>
              entry.id == PlaybackCapability.audioTrackDiscovery.name)
          .reason,
      'No native track probe.',
    );
    expect(snapshot.playback!.backendLabel, 'unit-backend');
    expect(
      snapshot.playback!.capabilities
          .singleWhere((DiagnosticsCapabilityEntry entry) =>
              entry.id == PlaybackCapability.audioTrackDiscovery.name)
          .source,
      'unit-probe',
    );
    expect(snapshot.providerNetwork!.bangumiTokenConfigured, isTrue);
    expect(snapshot.providerNetwork!.bangumiMirrorEnabled, isTrue);
    expect(snapshot.providerNetwork!.bangumiMirrorValid, isTrue);
    expect(snapshot.providerNetwork!.httpProxyUrl, 'http://127.0.0.1:8888');
  });

  test('workbench keeps other module snapshots when one module fails',
      () async {
    final DefaultDiagnosticsWorkbenchRuntime workbench = _workbench(
      settingsRuntime: _FailingSettingsRuntime(),
    );

    final DiagnosticsWorkbenchSnapshot snapshot = await workbench.snapshot();

    expect(snapshot.playback, isNotNull);
    expect(snapshot.downloads, isNotNull);
    expect(snapshot.providerNetwork, isNull);
    expect(
      snapshot.modules
          .singleWhere((DiagnosticsModuleSnapshot module) =>
              module.id == diagnosticsModuleProviderNetwork)
          .health,
      DiagnosticsModuleHealth.failed,
    );
  });

  test('workbench exposes AV sync monitor state in playback snapshot',
      () async {
    final DeterministicAVSyncGuardStore store = DeterministicAVSyncGuardStore();
    final AVSyncGuardRuntime guardRuntime = AVSyncGuardBootstrap(
      guardStore: store,
      guardByScope: <String, DeterministicAVSyncGuard>{
        avSyncGuardDefaultScopeId: DeterministicAVSyncGuard(
          policy: AVSyncPolicy(),
          guardStore: store,
          capabilities: _playbackCapabilities(),
          scopeId: avSyncGuardDefaultScopeId,
        ),
      },
      capabilitiesByScope: <String, PlaybackCapabilityMatrix>{
        avSyncGuardDefaultScopeId: _playbackCapabilities(),
      },
    ).createRuntime();
    final MockPlaybackController playbackController = MockPlaybackController(
      matrix: _playbackCapabilities(),
      initialState: PlaybackStateSnapshot(
        status: PlaybackLifecycleStatus.playing,
        sourceUri: Uri.parse('file:///D:/Anime/diagnostics.mkv'),
      ),
    );
    final AVSyncGuardMonitorRuntime monitor = AVSyncGuardMonitorRuntime(
      playbackController: playbackController,
      sampleSource: _SingleSampleSource(_sample(95)),
      guardRuntime: guardRuntime,
      now: () => DateTime.utc(2026, 6, 27, 11),
    );
    await monitor.tick();
    final DefaultDiagnosticsWorkbenchRuntime workbench = _workbench(
      playbackController: playbackController,
      avSyncGuardMonitorRuntime: monitor,
    );

    final DiagnosticsWorkbenchSnapshot snapshot = await workbench.snapshot();

    expect(snapshot.playback!.avSyncHealth, AVSyncHealth.warning);
    expect(snapshot.playback!.avSyncLatestDriftMillis, 95);
    expect(snapshot.playback!.avSyncSampleCount, 1);
    expect(
        snapshot.playback!.avSyncLastSampledAt, DateTime.utc(2026, 6, 27, 11));
    await monitor.dispose();
    await guardRuntime.dispose();
  });

  test('backend probe caches network checks inside ttl', () async {
    DateTime now = DateTime.utc(2026, 6, 27, 12);
    int providerChecks = 0;
    final DefaultDiagnosticsBackendProbeRuntime probe =
        DefaultDiagnosticsBackendProbeRuntime(
      playbackProbeSource: null,
      downloadRuntime: _StaticDownloadRuntime(),
      rssEngineRuntime: RssEngineRuntime(
        engine: _QuietRssEngine(),
        store: DeterministicRssFeedStore(),
        scheduler: const _QuietFeedScheduler(),
      ),
      mediaLibraryRuntime: _mediaLibraryRuntime(),
      settingsRuntime: FakeSettingsRuntime(),
      providerNetworkCheck: () async {
        providerChecks += 1;
        return const DiagnosticsProbeCheckResult.supported(
          message: 'provider ok',
        );
      },
      networkTtl: const Duration(seconds: 60),
      now: () => now,
    );

    final DiagnosticsBackendProbeSnapshot first = await probe.probe();
    final DiagnosticsBackendProbeSnapshot second = await probe.probe();
    now = now.add(const Duration(seconds: 61));
    final DiagnosticsBackendProbeSnapshot third = await probe.probe();

    expect(providerChecks, 2);
    expect(first.providerNetwork.cached, isFalse);
    expect(second.providerNetwork.cached, isTrue);
    expect(third.providerNetwork.cached, isFalse);
  });
}

DefaultDiagnosticsWorkbenchRuntime _workbench({
  SettingsRuntime? settingsRuntime,
  PlaybackControllerContract? playbackController,
  DownloadRuntime? downloadRuntime,
  DiagnosticsBackendProbeRuntime? backendProbeRuntime,
  AVSyncGuardMonitorRuntime? avSyncGuardMonitorRuntime,
}) {
  return DefaultDiagnosticsWorkbenchRuntime(
    diagnosticsRuntime: _StaticDiagnosticsRuntime(),
    playbackController: playbackController ??
        MockPlaybackController(
          matrix: PlaybackCapabilityMatrix(
            capabilities: const <PlaybackCapability, CapabilityStatus>{
              PlaybackCapability.playPause: CapabilityStatus.supported(),
            },
          ),
        ),
    downloadRuntime: downloadRuntime ?? _StaticDownloadRuntime(),
    rssEngineRuntime: RssEngineRuntime(
      engine: _QuietRssEngine(),
      store: DeterministicRssFeedStore(),
      scheduler: const _QuietFeedScheduler(),
    ),
    mediaLibraryRuntime: _mediaLibraryRuntime(),
    settingsRuntime: settingsRuntime ?? FakeSettingsRuntime(),
    backendProbeRuntime: backendProbeRuntime,
    avSyncGuardMonitorRuntime: avSyncGuardMonitorRuntime,
  );
}

PlaybackCapabilityMatrix _playbackCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: const <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.avSyncGuard: CapabilityStatus.supported(),
    },
  );
}

AVSyncSample _sample(int driftMillis) {
  return AVSyncSample(
    audioPosition: Duration(milliseconds: 1000 + driftMillis),
    videoPosition: const Duration(milliseconds: 1000),
    renderDelay: Duration.zero,
    droppedFrames: 0,
  );
}

final class _SingleSampleSource implements AVSyncSampleSource {
  const _SingleSampleSource(this._sample);

  final AVSyncSample _sample;

  @override
  Future<AVSyncSampleReadResult> sample() async {
    return AVSyncSampleReadResult.success(_sample);
  }
}

MediaLibraryRuntime _mediaLibraryRuntime() {
  final DeterministicMediaLibraryCatalogRepository repository =
      DeterministicMediaLibraryCatalogRepository();
  return MediaLibraryRuntime(
    scanner: DeterministicMediaLibraryScanner(
      scanId: const MediaScanId('diagnostics-test-scan'),
      candidates: const <MediaScanCandidate>[],
    ),
    catalogRepository: repository,
    importer: DeterministicMediaBatchImportContract(repository: repository),
    historyStore: DeterministicPlaybackHistoryStore(),
    bindingStore: DeterministicProviderBindingStore(),
    playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
    invalidationBus: RecordingCacheInvalidationBus(),
  );
}

final class _StaticDiagnosticsRuntime implements DiagnosticsRuntime {
  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    return <DiagnosticsEventProjection>[
      DiagnosticsEventProjection(
        id: 'provider-1',
        eventType: 'bangumi_request',
        severity: 'INFO',
        occurredAt: DateTime.utc(2026, 6, 23, 12),
        sourceModule: 'provider-gateway',
        correlationId: 'provider-1',
        payloadText: 'Bangumi gateway request',
      ),
    ];
  }

  @override
  Map<String, String> getCapabilitiesSupportStatus() {
    return const <String, String>{'snapshotQuery': 'Supported'};
  }

  @override
  Future<double> getLatestAvSyncDrift() async => 12;

  @override
  int getActiveMemoryUsageBytes() => 128 * 1024 * 1024;
}

final class _StaticDownloadRuntime implements DownloadRuntime {
  @override
  DownloadRuntimeSnapshot get currentSnapshot {
    return DownloadRuntimeSnapshot(
      status: DownloadRuntimeStatus.ready,
      tasks: const <DownloadProjection>[],
      capabilities: const DownloadCapabilityProjection(
        taskManagementAvailable: true,
        metadataFetchingAvailable: true,
        backgroundDownloadAvailable: true,
        virtualStreamAvailable: false,
        virtualStreamReason: 'No virtual stream in unit test.',
      ),
    );
  }

  @override
  void addObserver(DownloadRuntimeObserver observer) {}

  @override
  void removeObserver(DownloadRuntimeObserver observer) {}

  @override
  Future<DownloadCreateResult> createTaskFromUri(
    String sourceUri, {
    DownloadCreateMode mode = DownloadCreateMode.quick,
  }) {
    return Future<DownloadCreateResult>.value(
      const DownloadCreateResult.failure('Not used by diagnostics.'),
    );
  }

  @override
  Future<DownloadCommandResult> selectFiles(
    DownloadTaskId taskId,
    Iterable<DownloadFileIndex> files,
  ) {
    return Future<DownloadCommandResult>.value(
      const DownloadCommandResult.success(),
    );
  }

  @override
  Future<void> listTasks() async {}

  @override
  Future<DownloadCommandResult> pause(DownloadTaskId taskId) async {
    return const DownloadCommandResult.success();
  }

  @override
  Future<DownloadCommandResult> resume(DownloadTaskId taskId) async {
    return const DownloadCommandResult.success();
  }

  @override
  Future<DownloadCommandResult> remove(DownloadTaskId taskId) async {
    return const DownloadCommandResult.success();
  }

  @override
  Future<DownloadCommandResult> pauseAll() async {
    return const DownloadCommandResult.success();
  }

  @override
  Future<DownloadCommandResult> resumeAll() async {
    return const DownloadCommandResult.success();
  }

  @override
  Future<DownloadPlaybackPrepareResult> preparePlayback(
    DownloadTaskId taskId,
    DownloadFileIndex fileIndex,
  ) async {
    return const DownloadPlaybackPrepareResult.failure(
      kind: DownloadPlaybackPrepareFailureKind.capabilityUnsupported,
      message: 'Playback preparation is not configured in this fake.',
    );
  }

  @override
  void dispose() {}
}

final class _FakeBackendProbeRuntime implements DiagnosticsBackendProbeRuntime {
  _FakeBackendProbeRuntime({this.playback});

  final PlaybackCapabilityProbeSnapshot? playback;

  @override
  Future<DiagnosticsBackendProbeSnapshot> probe() async {
    final DateTime checkedAt = DateTime.utc(2026, 6, 27, 10);
    DiagnosticsBackendProbeModuleSnapshot module(String id, String label) {
      return DiagnosticsBackendProbeModuleSnapshot(
        id: id,
        label: label,
        supported: true,
        message: '$label ok',
        checkedAt: checkedAt,
        source: 'unit-probe',
      );
    }

    return DiagnosticsBackendProbeSnapshot(
      playback: playback,
      downloads: module(diagnosticsModuleDownloads, 'downloads'),
      rss: module(diagnosticsModuleRss, 'rss'),
      mediaLibrary: module(diagnosticsModuleMediaLibrary, 'media'),
      providerNetwork: module(diagnosticsModuleProviderNetwork, 'provider'),
    );
  }
}

final class _QuietRssEngine implements RssEngineContract {
  @override
  Future<void> registerSource(FeedSource source) async {}

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    return RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: const <FeedItem>[],
    );
  }

  @override
  Stream<FeedItem> get updates => const Stream<FeedItem>.empty();
}

final class _QuietFeedScheduler implements FeedScheduler {
  const _QuietFeedScheduler();

  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

final class _FailingSettingsRuntime implements SettingsRuntime {
  @override
  Future<String?> getPreference(String key) {
    throw StateError('settings unavailable');
  }

  @override
  Future<void> setPreference({required String key, required String value}) {
    throw StateError('settings unavailable');
  }

  @override
  Future<String?> getProxyUrl() {
    throw StateError('settings unavailable');
  }

  @override
  Future<void> saveProxyUrl(String proxyUrl) {
    throw StateError('settings unavailable');
  }

  @override
  Future<String?> getDnsPolicy() {
    throw StateError('settings unavailable');
  }

  @override
  Future<void> saveDnsPolicy(String dnsPolicy) {
    throw StateError('settings unavailable');
  }
}
