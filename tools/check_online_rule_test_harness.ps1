$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  'lib/src/provider/online/online_rule_test_harness.dart',
  'test/provider/online/online_rule_test_harness_test.dart',
  'tools/online_rule_test_harness_check.dart',
  'docs/online-rule-test-harness.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required online rule test harness file: $file"
  }
}

$harness = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/online/online_rule_test_harness.dart') -Raw
foreach ($term in @(
  'OnlineRuleTestDocument',
  'OnlineRuleTestPlan',
  'OnlineRuleTestTargetReport',
  'OnlineRuleTestReport',
  'OnlineRuleTestHarness',
  'DeterministicOnlineRuleRuntime',
  'OnlineRuleEvaluationOutcome',
  'OnlineRuleNormalizedOutput',
  'validateManifest',
  'evaluateTyped',
  'normalize'
)) {
  if ($harness -notmatch [regex]::Escape($term)) {
    throw "Online rule test harness missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/provider/online/online_rule_test_harness.dart';")) {
  throw 'Public Dart contract barrel missing online rule test harness export.'
}

$checker = Get-Content -LiteralPath (Join-Path $root 'tools/online_rule_test_harness_check.dart') -Raw
foreach ($term in @(
  'OnlineRuleTestHarness',
  'OnlineRuleTestPlan',
  'OnlineRuleTestDocument',
  'OnlineRuleSearchOutput',
  'OnlineRuleDetailOutput',
  'UnsupportedOnlineOperationKind.unsupportedSelector',
  'OnlineRuleFailureKind.requiredOutputMissing'
)) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Online rule test harness checker missing required term: $term"
  }
}

$filesToScan = @(
  'lib/src/provider/online/online_rule_test_harness.dart',
  'test/provider/online/online_rule_test_harness_test.dart',
  'tools/online_rule_test_harness_check.dart'
)

$forbiddenTerms = @(
  'HttpClient',
  'package:flutter/',
  'WebViewController',
  'runJavascript',
  'dart:js',
  'package:js',
  'js_interop',
  'dart:ffi',
  'dart:mirrors',
  'package:html',
  'package:webview',
  'Crawler',
  'Scraper',
  'libtorrent',
  'rss_auto_download',
  'yuc.wiki',
  'DiagnosticsCenter'
)

foreach ($file in $filesToScan) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 49 boundary term '$term' found in $file"
    }
  }
}

& dart (Join-Path $root 'tools/online_rule_test_harness_check.dart')

Write-Output 'Online rule test harness checks passed.'
