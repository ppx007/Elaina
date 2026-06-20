import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/domain/profile/bangumi_login_domain.dart';
import 'package:elaina/src/domain/profile/profile_domain.dart';
import 'package:elaina/src/domain/settings/settings_domain.dart';
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
      'SettingsPage allows editing and auto-saves preferences and proxy/dns',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();

    await settingsRuntime.setPreference(
        key: 'hardware_acceleration', value: 'true');
    await settingsRuntime.setPreference(
        key: 'layout_preference', value: 'default');
    await settingsRuntime.setPreference(
        key: 'cache_size_limit_mb', value: '512');
    await settingsRuntime.saveProxyUrl('http://127.0.0.1:8888');
    await settingsRuntime.saveDnsPolicy('https://dns.google/dns-query');

    await tester.pumpWidget(_testHost(
      child: SettingsPage(settingsRuntime: settingsRuntime),
    ));
    await tester.pumpAndSettle();

    expect(find.text('设置中心'), findsOneWidget);
    expect(find.text('硬件加速'), findsOneWidget);

    // Toggle hardware acceleration
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(
        await settingsRuntime.getPreference('hardware_acceleration'), 'false');

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-http-proxy')).last,
      'http://127.0.0.1:1080',
    );
    await tester.pumpAndSettle();
    expect(await settingsRuntime.getProxyUrl(), 'http://127.0.0.1:1080');
  });

  testWidgets('SettingsPage validates Bangumi token and refreshes profile',
      (WidgetTester tester) async {
    final settingsRuntime = FakeSettingsRuntime();
    final _RecordingBangumiLoginController bangumiLoginController =
        _RecordingBangumiLoginController();
    int authRefreshes = 0;

    await tester.pumpWidget(_testHost(
      child: SettingsPage(
        settingsRuntime: settingsRuntime,
        bangumiLoginController: bangumiLoginController,
        onBangumiAuthChanged: () {
          authRefreshes++;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-bangumi-access-token')),
      ' token-1 ',
    );
    await tester
        .tap(find.byKey(const ValueKey<String>('settings-bangumi-login')));
    await tester.pumpAndSettle();

    expect(bangumiLoginController.submittedToken, 'token-1');
    expect(authRefreshes, 1);
    expect(find.text('Bangumi 已登录：Alice'), findsWidgets);
  });

  testWidgets(
      'DiagnosticsPage displays capability checklist, memory usage, drift and chronological log table',
      (WidgetTester tester) async {
    final diagnosticsRuntime = _MockDiagnosticsRuntime();

    await tester.pumpWidget(_testHost(
      child: DiagnosticsPage(diagnosticsRuntime: diagnosticsRuntime),
    ));
    await tester.pumpAndSettle();

    expect(find.text('诊断中心'), findsOneWidget);
    expect(find.text('200.0 MB'), findsOneWidget);
    expect(find.text('15.4 ms'), findsOneWidget);

    expect(find.text('schemaRegistration'), findsOneWidget);
    expect(find.text('snapshotQuery'), findsOneWidget);

    // Switch tab to logs
    await tester.tap(find.text('时序日志事件'));
    await tester.pumpAndSettle();

    expect(find.text('play_start'), findsOneWidget);
    expect(find.text('buffer_warning'), findsOneWidget);
  });
}

final class _RecordingBangumiLoginController implements BangumiLoginController {
  String? submittedToken;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    return BangumiLoginStartResult.opened(
      Uri.parse('https://bgm.tv/oauth/authorize'),
    );
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
