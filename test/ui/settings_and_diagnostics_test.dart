// Settings/diagnostics UI tests focus on persisted global options and
// read-only diagnostic projections, not individual provider internals.
// Provider-specific settings should still be verified through their runtimes.
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/media/media_library_folder_preferences.dart';
import 'package:elaina/src/domain/profile/bangumi_login_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
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
  SettingsDirectoryPathPicker? directoryPathPicker,
}) {
  final SettingsPage page = directoryPathPicker == null
      ? SettingsPage(
          settingsRuntime: settingsRuntime,
          bangumiLoginController: bangumiLoginController,
          onBangumiAuthChanged: onBangumiAuthChanged,
        )
      : SettingsPage(
          settingsRuntime: settingsRuntime,
          bangumiLoginController: bangumiLoginController,
          onBangumiAuthChanged: onBangumiAuthChanged,
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

  testWidgets('SettingsPage shows about and reference repository information',
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

    await tester.ensureVisible(ElainaFinders.settingsReferenceRepositories);
    await tester.pumpAndSettle();
    expect(ElainaFinders.settingsReferenceRepositories, findsOneWidget);
    expect(find.text('Bangumi API'), findsOneWidget);
    expect(find.text('https://github.com/bangumi/api'), findsOneWidget);
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.text('https://github.com/media-kit/media-kit'), findsOneWidget);

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
        body: DiagnosticsPage(diagnosticsRuntime: diagnosticsRuntime),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('诊断中心'), findsOneWidget);
    expect(ElainaFinders.diagnosticsAutoRefreshStatus, findsOneWidget);
    expect(ElainaFinders.diagnosticsMemoryChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsDriftChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsSeverityChart, findsOneWidget);
    expect(ElainaFinders.diagnosticsModuleChart, findsOneWidget);
    expect(find.text('200.0 MB'), findsWidgets);
    expect(find.text('15.4 ms'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(ElainaFinders.diagnosticsCapabilityChart, findsWidgets);
    expect(find.textContaining('schemaRegistration'), findsOneWidget);
    expect(find.textContaining('snapshotQuery'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(ElainaFinders.diagnosticsEventTable, findsWidgets);
    expect(find.text('play_start'), findsOneWidget);
    expect(find.text('buffer_warning'), findsOneWidget);
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
          diagnosticsRuntime: diagnosticsRuntime,
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
          diagnosticsRuntime: diagnosticsRuntime,
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
          diagnosticsRuntime: diagnosticsRuntime,
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
          diagnosticsRuntime: diagnosticsRuntime,
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
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
