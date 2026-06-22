import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/profile/bangumi_login_domain.dart';
import 'package:elaina/src/domain/profile/profile_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
import 'package:elaina/src/provider/bangumi/bangumi_api_client.dart';
import 'package:elaina/src/ui/diagnostics/diagnostics_page.dart';
import 'package:elaina/src/ui/settings/settings_page.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testHost({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: ElainaTheme(
        data: ElainaThemeData.dark,
        mode: ElainaThemeMode.dark,
        onModeChanged: (_) {},
        child: Material(
          child: child,
        ),
      ),
    ),
  );
}

Widget _settingsHost({
  required FakeSettingsRuntime settingsRuntime,
  required Widget child,
}) {
  return MaterialApp(
    home: ElainaThemeProvider(
      initialMode: ElainaThemeMode.dark,
      settingsRuntime: settingsRuntime,
      child: Scaffold(
        body: Material(
          child: child,
        ),
      ),
    ),
  );
}

Future<void> _openSettingsSection(
  WidgetTester tester,
  String sectionLabel,
) async {
  final Finder sectionText = find.text(sectionLabel).first;
  final Finder compactChip = find.ancestor(
    of: sectionText,
    matching: find.byType(ChoiceChip),
  );
  if (tester.any(compactChip)) {
    await tester.tap(compactChip.first);
  } else {
    await tester.tap(sectionText);
  }
  await tester.pumpAndSettle();
}

class _MockDiagnosticsRuntime implements DiagnosticsRuntime {
  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    return <DiagnosticsEventProjection>[
      DiagnosticsEventProjection(
        id: '1',
        eventType: 'play_start',
        severity: 'INFO',
        occurredAt: DateTime(2026, 6, 20, 10, 0, 0),
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
  Future<double> getLatestAvSyncDrift() async {
    return 15.4;
  }

  @override
  int getActiveMemoryUsageBytes() {
    return 200 * 1024 * 1024;
  }
}

void main() {
  testWidgets(
      'SettingsPage exposes global settings and explicitly saves network preferences',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();

    await settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.themeMode,
      value: SettingsThemeModePreference.dark,
    );
    await settingsRuntime.saveProxyUrl('http://127.0.0.1:8888');
    await settingsRuntime.saveDnsPolicy('https://dns.google/dns-query');

    await tester.pumpWidget(_settingsHost(
      settingsRuntime: settingsRuntime,
      child: SettingsPage(settingsRuntime: settingsRuntime),
    ));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsWidgets);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('硬件加速'), findsNothing);
    expect(find.text('缓存管理'), findsNothing);

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(
      await settingsRuntime.getPreference(SettingsPreferenceKeys.themeMode),
      SettingsThemeModePreference.light,
    );

    await _openSettingsSection(tester, '网络');

    final Finder proxyField =
        find.byKey(const ValueKey<String>('settings-http-proxy'));
    await tester.enterText(proxyField, 'http://127.0.0.1:1080');
    await tester.pumpAndSettle();
    expect(await settingsRuntime.getProxyUrl(), 'http://127.0.0.1:8888');

    await tester.tap(find.byKey(const ValueKey<String>('settings-save-proxy')));
    await tester.pumpAndSettle();
    expect(await settingsRuntime.getProxyUrl(), 'http://127.0.0.1:1080');
  });

  testWidgets('SettingsPage validates Bangumi token and refreshes profile',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final _RecordingBangumiLoginController bangumiLoginController =
        _RecordingBangumiLoginController();
    int authRefreshes = 0;

    await tester.pumpWidget(_settingsHost(
      settingsRuntime: settingsRuntime,
      child: SettingsPage(
        settingsRuntime: settingsRuntime,
        bangumiLoginController: bangumiLoginController,
        onBangumiAuthChanged: () {
          authRefreshes++;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await _openSettingsSection(tester, 'Bangumi');

    final Finder tokenField =
        find.byKey(const ValueKey<String>('settings-bangumi-access-token'));
    final Finder loginButton =
        find.byKey(const ValueKey<String>('settings-bangumi-login'));
    await tester.enterText(tokenField, ' token-1 ');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(bangumiLoginController.submittedToken, 'token-1');
    expect(authRefreshes, 1);
    expect(find.text('Bangumi 已登录：Alice'), findsWidgets);
  });

  testWidgets('SettingsPage opens Bangumi OAuth authorization page',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final _RecordingBangumiLoginController bangumiLoginController =
        _RecordingBangumiLoginController();

    await tester.pumpWidget(_settingsHost(
      settingsRuntime: settingsRuntime,
      child: SettingsPage(
        settingsRuntime: settingsRuntime,
        bangumiLoginController: bangumiLoginController,
      ),
    ));
    await tester.pumpAndSettle();
    await _openSettingsSection(tester, 'Bangumi');

    final Finder oauthButton =
        find.byKey(const ValueKey<String>('settings-bangumi-oauth-login'));
    await tester.tap(oauthButton);
    await tester.pumpAndSettle();

    expect(bangumiLoginController.startLoginCalls, 1);
    expect(
      bangumiLoginController.openedUri,
      defaultBangumiOAuthAuthorizationPageUri,
    );
    expect(find.text('已打开 Bangumi OAuth 授权页'), findsWidgets);
  });

  testWidgets('SettingsPage stores valid Bangumi mirror settings',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();

    await tester.pumpWidget(_settingsHost(
      settingsRuntime: settingsRuntime,
      child: SettingsPage(settingsRuntime: settingsRuntime),
    ));
    await tester.pumpAndSettle();
    await _openSettingsSection(tester, 'Bangumi');

    final Finder mirrorSwitch =
        find.byKey(const ValueKey<String>('settings-bangumi-mirror'));
    tester.widget<Switch>(mirrorSwitch).onChanged!(true);
    await tester.pumpAndSettle();

    expect(
      await settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorEnabled),
      BangumiMirrorSettings.disabledValue,
    );
    expect(find.textContaining('required'), findsWidgets);

    final Finder apiField =
        find.byKey(const ValueKey<String>('settings-bangumi-mirror-api-url'));
    final Finder imageField =
        find.byKey(const ValueKey<String>('settings-bangumi-mirror-image-url'));
    await tester.enterText(apiField, ' https://mirror.test/api ');
    await tester.pumpAndSettle();
    await tester.enterText(imageField, 'https://mirror.test/image');
    await tester.pumpAndSettle();
    tester.widget<Switch>(mirrorSwitch).onChanged!(true);
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
    final _QueuedDirectoryPathPicker pathPicker = _QueuedDirectoryPathPicker(
      <String>['D:\\Anime', 'D:\\Media'],
    );

    await tester.pumpWidget(_settingsHost(
      settingsRuntime: settingsRuntime,
      child: SettingsPage(
        settingsRuntime: settingsRuntime,
        directoryPathPicker: pathPicker.pick,
      ),
    ));
    await tester.pumpAndSettle();
    await _openSettingsSection(tester, '本地媒体库');

    await tester
        .tap(find.byKey(const ValueKey<String>('settings-add-media-folder')));
    await tester.pumpAndSettle();

    final String? rawAfterAdd = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    expect(rawAfterAdd, isNotNull);
    expect(rawAfterAdd, contains('Anime'));

    await tester.tap(find.byTooltip('替换文件夹').first);
    await tester.pumpAndSettle();
    final String? rawAfterEdit = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    expect(rawAfterEdit, contains('Media'));
    expect(rawAfterEdit, isNot(contains('Anime')));

    await tester.tap(find.byTooltip('移除文件夹').first);
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

    await tester.pumpWidget(_testHost(
      child: DiagnosticsPage(diagnosticsRuntime: diagnosticsRuntime),
    ));
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

final class _RecordingBangumiLoginController implements BangumiLoginController {
  int startLoginCalls = 0;
  Uri? openedUri;
  String? submittedToken;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    startLoginCalls++;
    openedUri = defaultBangumiOAuthAuthorizationPageUri;
    return BangumiLoginStartResult.opened(openedUri!);
  }

  @override
  Future<BangumiTokenSignInResult> signInWithAccessToken(
    String accessToken,
  ) async {
    submittedToken = accessToken.trim();
    return const BangumiTokenSignInResult.signedIn(
      UserProfileSnapshot(displayName: 'Alice'),
    );
  }
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
