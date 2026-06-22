import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/framework/elaina_test_framework.dart';
import '../test/support/widget_test_waiters.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop app starts and primary pages are reachable',
      (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpApp(tester);
    addTearDown(fixture.dispose);

    expect(ElainaFinders.pageHome, findsOneWidget);

    await fixture.robot.shell.openSettings();
    await tester.pumpUntilFound(ElainaFinders.pageSettings);
    expect(ElainaFinders.settingsSectionBangumi, findsOneWidget);

    await fixture.robot.shell.openLocalLibrary();
    await tester.pumpUntilFound(ElainaFinders.pageLocalLibrary);

    await fixture.robot.shell.openDownloads();
    await tester.pumpUntilFound(ElainaFinders.pageDownloads);

    await fixture.robot.shell.openRss();
    await tester.pumpUntilFound(ElainaFinders.pageRss);
  });
}
