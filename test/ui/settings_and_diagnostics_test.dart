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
  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    return <DiagnosticsEventProjection>[
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
    ];
  }

  @override
  Map<String, String> getCapabilitiesSupportStatus() {
    return <String, String>{
      'schemaRegistration': 'Supported',
      'snapshotQuery': 'Unsupported',
    };
  }

  @override
  Future<double> getLatestAvSyncDrift() async => 15.4;

  @override
  int getActiveMemoryUsageBytes() => 200 * 1024 * 1024;
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
      'DiagnosticsPage displays capability checklist, memory usage, drift and chronological log table',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime();

    await ElainaTestHarness.pumpThemedWidget(
      tester,
      child: Scaffold(
        body: DiagnosticsPage(diagnosticsRuntime: diagnosticsRuntime),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200.0 MB'), findsOneWidget);
    expect(find.text('15.4 ms'), findsOneWidget);

    expect(find.text('schemaRegistration'), findsOneWidget);
    expect(find.text('snapshotQuery'), findsOneWidget);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    expect(find.text('play_start'), findsOneWidget);
    expect(find.text('buffer_warning'), findsOneWidget);
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
