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
    );

    final DiagnosticsWorkbenchSnapshot snapshot = await workbench.snapshot();

    expect(snapshot.playback!.sourceUri, 'file:///D:/Anime/workbench.mkv');
    expect(snapshot.playback!.activeAudioTrackId, 'audio-jpn');
    expect(snapshot.playback!.activeSubtitleCueCount, 1);
    expect(snapshot.playback!.visibleDanmakuCommentCount, 1);
    expect(
      snapshot.playback!.capabilities
          .singleWhere((DiagnosticsCapabilityEntry entry) =>
              entry.id == PlaybackCapability.audioTrackDiscovery.name)
          .reason,
      'No native track probe.',
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
}

DefaultDiagnosticsWorkbenchRuntime _workbench({
  SettingsRuntime? settingsRuntime,
  PlaybackControllerContract? playbackController,
  DownloadRuntime? downloadRuntime,
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
  );
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
  void dispose() {}
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
