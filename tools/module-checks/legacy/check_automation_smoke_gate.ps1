$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'tools/automation_smoke_gate.dart',
  'tools/check_automation_smoke_gate.ps1',
  'test/domain/automation/automation_smoke_gate_test.dart',
  'docs/automation-smoke-gate.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Step 50 automation smoke gate file: $file"
  }
}

$tool = Get-Content -LiteralPath (Join-Path $root 'tools/automation_smoke_gate.dart') -Raw
foreach ($term in @(
  'runAutomationSmokeGate',
  'AutomationSmokeGateResult',
  'SeasonalFeedFlowBootstrap',
  'HttpFeedFetcher',
  'RssXmlFeedParser',
  'FeedItemSeasonalAnimeConsumer',
  'OnlineRuleTestHarness',
  'OnlineRuleTestPlan',
  'OnlineRuleSearchOutput',
  'OnlineRuleDetailOutput',
  'defaultFeedAcceptHeader',
  'stdout.writeln'
)) {
  if ($tool -notmatch [regex]::Escape($term)) {
    throw "Automation smoke gate tool missing required term: $term"
  }
}

foreach ($term in @(
  'package:flutter',
  'dart:ui',
  'lib/src/ui',
  'lib/main.dart',
  'windows/',
  'media_kit',
  'libmpv',
  'MpvPlayer',
  'Vlc',
  'BangumiApiClient',
  'DandanplayApiClient',
  'OpenSubtitlesApiClient',
  'HttpClient(',
  'WebView',
  'runJavascript',
  'captcha',
  'Crawler',
  'Scraper',
  'RssAutoDownloadPolicy',
  'AutomationDownloadEnqueuer',
  'DownloadEngineAdapter',
  'BtTaskCreateRequest',
  'libtorrent',
  'DiagnosticsCenter'
)) {
  if ($tool -match [regex]::Escape($term)) {
    throw "Forbidden Step 50 dependency '$term' found in automation smoke gate tool."
  }
}

$doc = Get-Content -LiteralPath (Join-Path $root 'docs/automation-smoke-gate.md') -Raw
foreach ($term in @(
  'Step 50',
  'RSS fetch/parse -> seasonal catalog -> Bangumi match queue',
  'supplied online rule documents -> rule-source test report',
  'non-UI',
  'SeasonalFeedFlowBootstrap',
  'OnlineRuleTestHarness',
  'UI Boundary'
)) {
  if ($doc -notmatch [regex]::Escape($term)) {
    throw "Automation smoke gate doc missing required term: $term"
  }
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'AutomationSmokeGate|automation_smoke_gate|SeasonalFeedFlowBootstrap|OnlineRuleTestHarness|HttpFeedFetcher|RssXmlFeedParser'
    if ($matches) {
      throw "Step 50 automation smoke gate details leaked into $path"
    }
  }
}

$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('AutomationSmokeGate', 'automation_smoke_gate', 'SeasonalFeedFlowBootstrap', 'OnlineRuleTestHarness', 'HttpFeedFetcher', 'RssXmlFeedParser')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 50 automation smoke gate detail '$term' leaked into lib/main.dart"
    }
  }
}

& flutter test (Join-Path $root 'test/domain/automation/automation_smoke_gate_test.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'Automation smoke gate focused test failed.'
}

& dart (Join-Path $root 'tools/automation_smoke_gate.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'Automation smoke gate Dart tool failed.'
}

Write-Output 'Automation smoke gate checks passed.'

