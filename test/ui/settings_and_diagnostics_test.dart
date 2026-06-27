// Settings/diagnostics UI tests focus on persisted global options and
// read-only diagnostic projections, not individual provider internals.
// Provider-specific settings should still be verified through their runtimes.
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_workbench.dart';
import 'package:elaina/src/domain/download/download_domain.dart';
import 'package:elaina/src/domain/media/media_library_folder_preferences.dart';
import 'package:elaina/src/domain/media/media_library_runtime.dart';
import 'package:elaina/src/domain/playback/playback_state.dart';
import 'package:elaina/src/domain/profile/bangumi_login_domain.dart';
import 'package:elaina/src/domain/rss/rss_engine_runtime.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
import 'package:elaina/src/playback/av_sync_guard.dart';
import 'package:elaina/src/provider/bangumi/bangumi_api_client.dart';
import 'package:elaina/src/ui/diagnostics/diagnostics_page.dart';
import 'package:elaina/src/ui/settings/settings_page.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/elaina_test_framework.dart';

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  required FakeSettingsRuntime settingsRuntime,
  BangumiLoginController? bangumiLoginController,
  VoidCallback? onBangumiAuthChanged,
  Future<void> Function()? onAnime4kSettingsChanged,
  SettingsDirectoryPathPicker? directoryPathPicker,
}) {
  final SettingsPage page = directoryPathPicker == null
      ? SettingsPage(
          settingsRuntime: settingsRuntime,
          bangumiLoginController: bangumiLoginController,
          onBangumiAuthChanged: onBangumiAuthChanged,
          onAnime4kSettingsChanged: onAnime4kSettingsChanged,
        )
      : SettingsPage(
          settingsRuntime: settingsRuntime,
          bangumiLoginController: bangumiLoginController,
          onBangumiAuthChanged: onBangumiAuthChanged,
          onAnime4kSettingsChanged: onAnime4kSettingsChanged,
          directoryPathPicker: directoryPathPicker,
        );
  return ElainaTestHarness.pumpSettingsWidget(
    tester,
    settingsRuntime: settingsRuntime,
    child: page,
  );
}

final class _MockDiagnosticsRuntime implements DiagnosticsRuntime {
  _MockDiagnosticsRuntime({
    List<List<DiagnosticsEventProjection>>? eventSnapshots,
    List<double>? driftSnapshots,
    List<int>? memorySnapshots,
    Map<String, String>? capabilities,
    this.failQueryAtCall,
  })  : _eventSnapshots = eventSnapshots ?? _defaultEventSnapshots,
        _driftSnapshots = driftSnapshots ?? const <double>[15.4],
        _memorySnapshots = memorySnapshots ?? const <int>[200 * 1024 * 1024],
        _capabilities = capabilities ??
            const <String, String>{
              'schemaRegistration': 'Supported',
              'snapshotQuery': 'Unsupported',
            };

  static final List<List<DiagnosticsEventProjection>> _defaultEventSnapshots =
      <List<DiagnosticsEventProjection>>[
    <DiagnosticsEventProjection>[
      DiagnosticsEventProjection(
        id: '1',
        eventType: 'play_start',
        severity: 'INFO',
        occurredAt: DateTime(2026, 6, 20, 10),
        sourceModule: 'playback',
        correlationId: 'corr-1',
        payloadText: 'Started playing cyber_overload.mp4',
      ),
      DiagnosticsEventProjection(
        id: '2',
        eventType: 'buffer_warning',
        severity: 'WARNING',
        occurredAt: DateTime(2026, 6, 20, 10, 1, 30),
        sourceModule: 'streaming',
        correlationId: 'corr-1',
        payloadText: 'Buffer low, speed: 10KB/s',
      ),
    ],
  ];

  final List<List<DiagnosticsEventProjection>> _eventSnapshots;
  final List<double> _driftSnapshots;
  final List<int> _memorySnapshots;
  final Map<String, String> _capabilities;
  final int? failQueryAtCall;

  int queryEventsCalls = 0;
  int driftCalls = 0;
  int memoryCalls = 0;

  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    queryEventsCalls += 1;
    final int? failingCall = failQueryAtCall;
    if (failingCall != null && queryEventsCalls >= failingCall) {
      throw StateError('diagnostics unavailable');
    }
    return _eventSnapshots[
        _snapshotIndex(queryEventsCalls, _eventSnapshots.length)];
  }

  @override
  Map<String, String> getCapabilitiesSupportStatus() {
    return _capabilities;
  }

  @override
  Future<double> getLatestAvSyncDrift() async {
    driftCalls += 1;
    return _driftSnapshots[_snapshotIndex(driftCalls, _driftSnapshots.length)];
  }

  @override
  int getActiveMemoryUsageBytes() {
    memoryCalls += 1;
    return _memorySnapshots[
        _snapshotIndex(memoryCalls, _memorySnapshots.length)];
  }

  int _snapshotIndex(int callCount, int snapshotCount) {
    return (callCount - 1).clamp(0, snapshotCount - 1);
  }
}

final class _MockDiagnosticsWorkbenchRuntime
    implements DiagnosticsWorkbenchRuntime {
  const _MockDiagnosticsWorkbenchRuntime(this.diagnosticsRuntime);

  final DiagnosticsRuntime diagnosticsRuntime;

  @override
  Future<DiagnosticsWorkbenchSnapshot> snapshot() async {
    final List<DiagnosticsEventProjection> events =
        await diagnosticsRuntime.queryEvents();
    final DiagnosticsTelemetrySample sample = DiagnosticsTelemetrySample(
      sampledAt: DateTime(2026, 6, 20, 10, 2),
      memoryUsageBytes: diagnosticsRuntime.getActiveMemoryUsageBytes(),
      avSyncDriftMillis: await diagnosticsRuntime.getLatestAvSyncDrift(),
    );
    final DiagnosticsPlaybackSnapshot playback = DiagnosticsPlaybackSnapshot(
      backendLabel: 'unit-backend',
      probeSource: 'unit-probe',
      probeCheckedAt: DateTime(2026, 6, 20, 10, 2),
      probeCached: false,
      probeDetails: const <String, String>{
        'nativeMpvCommands': 'true',
        'telemetry': 'true',
        'avSyncSampler': 'true',
        'anime4kShadersAccessible': 'true',
        'anime4kShaderSource': 'bundled',
        'anime4kShaderMap': 'restore=Anime4K_Restore_CNN_M.glsl',
      },
      status: PlaybackLifecycleStatus.playing,
      position: const Duration(minutes: 3, seconds: 12),
      duration: const Duration(minutes: 24),
      isBuffering: false,
      bufferedFraction: 0.42,
      sourceUri: 'file:///D:/Anime/cyber_overload.mp4',
      failureReason: null,
      activeAudioTrackId: 'audio-jpn',
      activeSubtitleTrackId: 'subtitle-zh',
      subtitleTrackCount: 2,
      activeSubtitleCueCount: 1,
      subtitleOffset: const Duration(milliseconds: 250),
      subtitleWarnings: const <String>['字幕时间轴存在轻微偏移'],
      subtitleFailure: null,
      danmakuClockPosition: const Duration(minutes: 3, seconds: 12),
      danmakuLaneCount: 3,
      visibleDanmakuCommentCount: 18,
      matrixDanmakuRendererSource: 'flutter-custom-painter-overlay',
      matrixDanmakuRenderedCommentCount: 6,
      danmakuWarnings: const <String>['弹幕密度接近上限'],
      danmakuFailure: null,
      matrixDanmakuFailure: null,
      avSyncHealth: AVSyncHealth.warning,
      avSyncLatestDriftMillis: 92,
      avSyncSampleCount: 4,
      avSyncLatestDegradationAction:
          AVSyncDegradationAction.keepCurrentProfile.name,
      avSyncLastSampledAt: DateTime(2026, 6, 20, 10, 2),
      capabilities: const <DiagnosticsCapabilityEntry>[
        DiagnosticsCapabilityEntry(
          id: 'playPause',
          label: '播放/暂停',
          supported: true,
        ),
        DiagnosticsCapabilityEntry(
          id: 'audioTrackDiscovery',
          label: '音轨发现',
          supported: false,
          reason: '当前测试后端未声明音轨发现。',
        ),
      ],
    );
    final DiagnosticsDownloadSnapshot downloads = DiagnosticsDownloadSnapshot(
      status: DownloadRuntimeStatus.ready,
      totalTasks: 1,
      activeTasks: 1,
      pausedTasks: 0,
      completedTasks: 0,
      failedTasks: 0,
      totalDownloadRateBytesPerSecond: 512 * 1024,
      totalUploadRateBytesPerSecond: 64 * 1024,
      totalPeers: 9,
      capabilities: const <DiagnosticsCapabilityEntry>[
        DiagnosticsCapabilityEntry(
          id: 'taskManagement',
          label: '任务管理',
          supported: true,
        ),
      ],
      tasks: const <DiagnosticsDownloadTaskSnapshot>[
        DiagnosticsDownloadTaskSnapshot(
          name: 'Cyber Overload 01',
          state: DownloadLifecycleState.downloading,
          progress: 0.58,
          downloadRateBytesPerSecond: 512 * 1024,
          uploadRateBytesPerSecond: 64 * 1024,
          connectedPeers: 9,
          totalSizeBytes: 1024 * 1024 * 1024,
          selectedFileCount: 1,
          fileCount: 2,
        ),
      ],
    );
    final DiagnosticsRssSnapshot rss = DiagnosticsRssSnapshot(
      status: RssEngineRuntimeStatus.ready,
      sourceCount: 2,
      dueSourceCount: 1,
      acceptedItemCount: 5,
      latestRefreshCount: 2,
      refreshFailureCount: 0,
      autoRuleCount: 3,
      failures: const <String>[],
    );
    final DiagnosticsMediaLibrarySnapshot mediaLibrary =
        DiagnosticsMediaLibrarySnapshot(
      status: MediaLibraryRuntimeStatus.ready,
      catalogItemCount: 12,
      continueWatchingCount: 4,
      bangumiBoundCount: 8,
      scanEventCount: 6,
      failureMessages: const <String>[],
    );
    const DiagnosticsProviderNetworkSnapshot providerNetwork =
        DiagnosticsProviderNetworkSnapshot(
      bangumiTokenConfigured: true,
      bangumiMirrorEnabled: true,
      bangumiMirrorApiBaseUrl: 'https://bgm-api.example.test',
      bangumiMirrorImageBaseUrl: 'https://bgm-img.example.test',
      bangumiMirrorValid: true,
      httpProxyUrl: 'http://127.0.0.1:8888',
      dnsPolicy: 'https://dns.google/dns-query',
      providerNetworkEventCount: 1,
    );
    return DiagnosticsWorkbenchSnapshot(
      sample: sample,
      events: events.reversed.toList(growable: false),
      diagnosticsCapabilities:
          diagnosticsRuntime.getCapabilitiesSupportStatus(),
      modules: <DiagnosticsModuleSnapshot>[
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleOverview,
          label: '总览',
          health: DiagnosticsModuleHealth.warning,
          summary: '2 条事件',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModulePlayback,
          label: '播放',
          health: DiagnosticsModuleHealth.healthy,
          summary: 'playing',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleDownloads,
          label: '下载',
          health: DiagnosticsModuleHealth.healthy,
          summary: '1 个任务',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleRss,
          label: 'RSS',
          health: DiagnosticsModuleHealth.healthy,
          summary: '2 个订阅',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleMediaLibrary,
          label: '本地媒体库',
          health: DiagnosticsModuleHealth.healthy,
          summary: '12 个索引',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleProviderNetwork,
          label: 'Provider/网络',
          health: DiagnosticsModuleHealth.healthy,
          summary: '镜像开启',
        ),
        DiagnosticsModuleSnapshot(
          id: diagnosticsModuleEvents,
          label: '事件日志',
          health: DiagnosticsModuleHealth.healthy,
          summary: '2 条事件',
        ),
      ],
      playback: playback,
      downloads: downloads,
      rss: rss,
      mediaLibrary: mediaLibrary,
      providerNetwork: providerNetwork,
    );
  }
}

void main() {
  testWidgets(
      'SettingsPage exposes global settings and explicitly saves network preferences',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final settings = SettingsRobot(tester);

    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.themeMode,
      value: SettingsThemeModePreference.dark,
    );
    await settingsRuntime.saveProxyUrl('http://127.0.0.1:8888');
    await settingsRuntime.saveDnsPolicy('https://dns.google/dns-query');

    await _pumpSettingsPage(tester, settingsRuntime: settingsRuntime);
    await tester.pumpAndSettle();

    expect(ElainaFinders.settingsSectionAppearance, findsOneWidget);
    expect(ElainaFinders.settingsSectionPlayback, findsOneWidget);
    expect(ElainaFinders.settingsThemeMode, findsOneWidget);

    tester
        .widget<SegmentedButton<ElainaThemeMode>>(
          ElainaFinders.settingsThemeMode,
        )
        .onSelectionChanged!(<ElainaThemeMode>{ElainaThemeMode.light});
    await tester.pumpAndSettle();
    expect(
      await settingsRuntime.getPreference(SettingsPreferenceKeys.themeMode),
      SettingsThemeModePreference.light,
    );

    await settings.openNetwork();

    await tester.enterText(
      ElainaFinders.settingsHttpProxy,
      'http://127.0.0.1:1080',
    );
    await tester.pumpAndSettle();
    expect(await settingsRuntime.getProxyUrl(), 'http://127.0.0.1:8888');

    await settings.saveProxy('http://127.0.0.1:1080');
    expect(await settingsRuntime.getProxyUrl(), 'http://127.0.0.1:1080');
  });

  testWidgets('SettingsPage shows about and open source license information',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final settings = SettingsRobot(tester);

    await _pumpSettingsPage(tester, settingsRuntime: settingsRuntime);
    await tester.pumpAndSettle();

    expect(ElainaFinders.settingsSectionAbout, findsOneWidget);
    await settings.openAbout();

    expect(ElainaFinders.settingsAboutAppInfo, findsOneWidget);
    expect(find.text('Elaina'), findsOneWidget);
    expect(find.text('1017'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('https://github.com/ppx007/Elaina'), findsOneWidget);
    expect(find.text('项目许可证'), findsOneWidget);
    expect(find.textContaining('GPL-3.0-only'), findsOneWidget);

    await tester.ensureVisible(ElainaFinders.settingsOpenSourceLicenses);
    await tester.pumpAndSettle();
    expect(ElainaFinders.settingsOpenSourceLicenses, findsOneWidget);
    expect(find.text('引用项目与协议'), findsOneWidget);
    expect(find.text('Bangumi API'), findsOneWidget);
    expect(find.text('https://github.com/bangumi/api'), findsWidgets);
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.text('https://github.com/media-kit/media-kit'), findsOneWidget);
    expect(find.text('许可证：MIT License'), findsWidgets);
    expect(find.text('libtorrent_flutter'), findsOneWidget);
    expect(find.text('许可证：GPL-3.0'), findsOneWidget);
    expect(find.text('Dandanplay'), findsOneWidget);
    expect(find.text('许可证：需查看官方条款'), findsOneWidget);
    expect(find.text('Anime4K'), findsOneWidget);
    expect(find.text('https://github.com/bloc97/Anime4K'), findsOneWidget);
    expect(find.text('许可证：MIT License'), findsWidgets);
    expect(find.textContaining('assets/anime4k/LICENSE'), findsWidgets);

    await tester.ensureVisible(ElainaFinders.settingsReferenceRepositories);
    await tester.pumpAndSettle();
    expect(ElainaFinders.settingsReferenceRepositories, findsOneWidget);
    expect(ElainaFinders.settingsThirdPartyLicensesButton, findsOneWidget);
    await tester.tap(ElainaFinders.settingsThirdPartyLicensesButton);
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);

    expect(
      await settingsRuntime.getPreference(SettingsPreferenceKeys.themeMode),
      isNull,
    );
    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiAccessToken),
      isNull,
    );
    expect(await settingsRuntime.getProxyUrl(), isNull);
  });

  testWidgets('SettingsPage stores Anime4K shader preferences',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    int reconfigureCalls = 0;

    await _pumpSettingsPage(
      tester,
      settingsRuntime: settingsRuntime,
      onAnime4kSettingsChanged: () async {
        reconfigureCalls += 1;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(ElainaFinders.settingsSectionVideoEnhancement.first);
    await tester.pumpAndSettle();
    await tester.enterText(
      ElainaFinders.settingsAnime4kShaderOverrideDirectory,
      'D:\\Anime4K\\Shaders',
    );
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          ElainaFinders.settingsAnime4kDefaultPreset,
        )
        .onChanged!(Anime4kPresetSettings.restoreAndUpscale);
    await tester.pumpAndSettle();
    await tester.tap(ElainaFinders.settingsAnime4kSave);
    await tester.pumpAndSettle();

    expect(
      await settingsRuntime.getPreference(
        SettingsPreferenceKeys.anime4kShaderOverrideDirectory,
      ),
      'D:\\Anime4K\\Shaders',
    );
    expect(
      await settingsRuntime.getPreference(
        SettingsPreferenceKeys.anime4kDefaultPreset,
      ),
      Anime4kPresetSettings.restoreAndUpscale,
    );
    expect(reconfigureCalls, 1);
  });

  testWidgets('SettingsPage validates Bangumi token and refreshes profile',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final RecordingBangumiLoginController bangumiLoginController =
        RecordingBangumiLoginController();
    final settings = SettingsRobot(tester);
    int authRefreshes = 0;

    await _pumpSettingsPage(
      tester,
      settingsRuntime: settingsRuntime,
      bangumiLoginController: bangumiLoginController,
      onBangumiAuthChanged: () {
        authRefreshes++;
      },
    );
    await tester.pumpAndSettle();
    await settings.openBangumi();

    await settings.saveBangumiToken(' token-1 ');

    expect(bangumiLoginController.submittedToken, 'token-1');
    expect(authRefreshes, 1);
  });

  testWidgets('SettingsPage opens Bangumi OAuth authorization page',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final RecordingBangumiLoginController bangumiLoginController =
        RecordingBangumiLoginController();
    final settings = SettingsRobot(tester);

    await _pumpSettingsPage(
      tester,
      settingsRuntime: settingsRuntime,
      bangumiLoginController: bangumiLoginController,
    );
    await tester.pumpAndSettle();
    await settings.openBangumi();

    await settings.openBangumiOAuth();

    expect(bangumiLoginController.startLoginCalls, 1);
    expect(
      bangumiLoginController.openedUri,
      defaultBangumiOAuthAuthorizationPageUri,
    );
  });

  testWidgets('SettingsPage stores valid Bangumi mirror settings',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final settings = SettingsRobot(tester);

    await _pumpSettingsPage(tester, settingsRuntime: settingsRuntime);
    await tester.pumpAndSettle();
    await settings.openBangumi();

    tester.widget<Switch>(ElainaFinders.settingsBangumiMirror).onChanged!(true);
    await tester.pumpAndSettle();

    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorEnabled),
      BangumiMirrorSettings.disabledValue,
    );
    expect(find.textContaining('required'), findsWidgets);

    await tester.enterText(
      ElainaFinders.settingsBangumiMirrorApiUrl,
      ' https://mirror.test/api ',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      ElainaFinders.settingsBangumiMirrorImageUrl,
      'https://mirror.test/image',
    );
    await tester.pumpAndSettle();
    tester.widget<Switch>(ElainaFinders.settingsBangumiMirror).onChanged!(true);
    await tester.pumpAndSettle();

    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorApiBaseUrl),
      'https://mirror.test/api',
    );
    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorImageBaseUrl),
      'https://mirror.test/image',
    );
    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorEnabled),
      BangumiMirrorSettings.enabledValue,
    );
  });

  testWidgets('SettingsPage manages media library folder preferences',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    const MediaLibraryFolderPreferenceCodec folderCodec =
        MediaLibraryFolderPreferenceCodec();
    final _QueuedDirectoryPathPicker pathPicker = _QueuedDirectoryPathPicker(
      <String>['D:\\Anime', 'D:\\Media'],
    );
    final settings = SettingsRobot(tester);

    await _pumpSettingsPage(
      tester,
      settingsRuntime: settingsRuntime,
      directoryPathPicker: pathPicker.pick,
    );
    await tester.pumpAndSettle();
    await settings.openMediaLibrary();

    await settings.addMediaFolder();

    final String? rawAfterAdd = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    expect(rawAfterAdd, isNotNull);
    expect(rawAfterAdd, contains('Anime'));

    await tester.tap(ElainaFinders.settingsEditMediaFolder(
      folderCodec.directoryUriFromPath('D:\\Anime')!,
    ));
    await tester.pumpAndSettle();
    final String? rawAfterEdit = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    expect(rawAfterEdit, contains('Media'));
    expect(rawAfterEdit, isNot(contains('Anime')));

    await tester.tap(ElainaFinders.settingsRemoveMediaFolder(
      folderCodec.directoryUriFromPath('D:\\Media')!,
    ));
    await tester.pumpAndSettle();
    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.mediaLibraryRoots),
      '[]',
    );
  });

  testWidgets(
      'DiagnosticsPage displays auto-refresh dashboard charts and event table',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime();

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(
          diagnosticsWorkbenchRuntime:
              _MockDiagnosticsWorkbenchRuntime(diagnosticsRuntime),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('诊断工作台'), findsOneWidget);
    expect(ElainaFinders.diagnosticsAutoRefreshStatus, findsOneWidget);
    expect(ElainaFinders.diagnosticsModuleNav, findsOneWidget);
    expect(ElainaFinders.diagnosticsOverviewPanel, findsOneWidget);
    expect(ElainaFinders.diagnosticsMemoryChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsDriftChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsSeverityChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsModuleChart, findsOneWidget);
    expect(find.text('200.0 MB'), findsWidgets);
    expect(find.text('15.4 ms'), findsWidgets);

    await tester.tap(find.text('播放').first);
    await tester.pumpAndSettle();
    expect(ElainaFinders.diagnosticsCapabilityChart, findsWidgets);
    expect(ElainaFinders.diagnosticsPlaybackPanel, findsOneWidget);
    expect(find.text('播放诊断'), findsOneWidget);
    expect(find.text('file:///D:/Anime/cyber_overload.mp4'), findsOneWidget);
    expect(find.text('audio-jpn'), findsOneWidget);
    expect(find.text('subtitle-zh'), findsOneWidget);
    expect(find.text('AV 同步采样'), findsOneWidget);
    expect(find.text('警告'), findsOneWidget);
    expect(find.text('92 ms'), findsOneWidget);
    expect(find.text('Anime4K shader'), findsOneWidget);
    expect(find.text('可访问'), findsOneWidget);
    expect(find.text('Anime4K 来源'), findsOneWidget);
    expect(find.text('bundled'), findsOneWidget);
    expect(find.text('Anime4K 映射'), findsOneWidget);
    expect(find.text('restore=Anime4K_Restore_CNN_M.glsl'), findsOneWidget);
    expect(find.textContaining('弹幕密度接近上限'), findsOneWidget);
    expect(find.text('音轨发现'), findsOneWidget);

    await tester.tap(find.text('事件日志').first);
    await tester.pumpAndSettle();
    expect(ElainaFinders.diagnosticsEventTable, findsWidgets);
    expect(ElainaFinders.diagnosticsEventFilter, findsOneWidget);
    expect(find.text('play_start'), findsOneWidget);
    expect(find.text('buffer_warning'), findsOneWidget);
    await tester.ensureVisible(find.text('buffer_warning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buffer_warning'));
    await tester.pumpAndSettle();
    expect(ElainaFinders.diagnosticsEventPayload, findsOneWidget);
    expect(find.textContaining('Buffer low'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DiagnosticsPage auto refreshes visible telemetry',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime(
      memorySnapshots: <int>[200 * 1024 * 1024, 240 * 1024 * 1024],
      driftSnapshots: const <double>[15.4, 42.0],
    );

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(
          diagnosticsWorkbenchRuntime:
              _MockDiagnosticsWorkbenchRuntime(diagnosticsRuntime),
          refreshInterval: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200.0 MB'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(diagnosticsRuntime.queryEventsCalls, greaterThanOrEqualTo(2));
    expect(find.text('240.0 MB'), findsWidgets);
    expect(find.text('42.0 ms'), findsWidgets);
  });

  testWidgets(
      'DiagnosticsPage pauses refresh while inactive and refreshes when active',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime(
      memorySnapshots: <int>[200 * 1024 * 1024, 260 * 1024 * 1024],
    );

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(
          diagnosticsWorkbenchRuntime:
              _MockDiagnosticsWorkbenchRuntime(diagnosticsRuntime),
          isActive: false,
          refreshInterval: const Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final int callsWhileInactive = diagnosticsRuntime.queryEventsCalls;

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(diagnosticsRuntime.queryEventsCalls, callsWhileInactive);

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(
          diagnosticsWorkbenchRuntime:
              _MockDiagnosticsWorkbenchRuntime(diagnosticsRuntime),
          refreshInterval: const Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
        diagnosticsRuntime.queryEventsCalls, greaterThan(callsWhileInactive));
    expect(find.text('200.0 MB'), findsWidgets);
  });

  testWidgets('DiagnosticsPage keeps last snapshot when refresh fails',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime(
      failQueryAtCall: 2,
    );

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(
          diagnosticsWorkbenchRuntime:
              _MockDiagnosticsWorkbenchRuntime(diagnosticsRuntime),
          refreshInterval: const Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200.0 MB'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(ElainaFinders.diagnosticsErrorBanner, findsOneWidget);
    expect(find.text('200.0 MB'), findsWidgets);
    await tester.tap(find.text('事件日志').first);
    await tester.pumpAndSettle();
    expect(find.text('play_start'), findsOneWidget);
  });
}

final class _QueuedDirectoryPathPicker {
  _QueuedDirectoryPathPicker(List<String> paths) : _paths = paths;

  final List<String> _paths;
  int _index = 0;

  Future<String?> pick() async {
    if (_index >= _paths.length) return null;
    final String path = _paths[_index];
    _index += 1;
    return path;
  }
}
