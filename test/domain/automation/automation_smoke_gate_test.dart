import 'package:flutter_test/flutter_test.dart';

import '../../../tools/automation_smoke_gate.dart';

void main() {
  test('automation smoke gate composes RSS seasonal flow and online rules',
      () async {
    final AutomationSmokeGateResult result = await runAutomationSmokeGate();

    expect(result.acceptedFeedItemCount, 1);
    expect(result.catalogEntryCount, 1);
    expect(result.pendingMatchCount, 1);
    expect(result.firstCatalogTitle, 'Automation Smoke Episode 01');
    expect(result.onlineRuleTargetReportCount, 2);
    expect(result.onlineRuleNormalizedOutputCount, 2);
    expect(result.searchResultTitle, result.firstCatalogTitle);
    expect(result.detailTitle, result.firstCatalogTitle);
  });
}
