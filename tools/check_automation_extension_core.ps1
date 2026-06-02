$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_advanced_playback_core.ps1')

$requiredFiles = @(
  'lib/src/provider/rss/rss_auto_download_policy.dart',
  'lib/src/domain/automation/rss_download_handoff.dart',
  'lib/src/provider/online/online_rule_runtime.dart',
  'lib/src/network/webview_session_backfill.dart',
  'lib/src/network/network_policy.dart',
  'lib/src/foundation/diagnostics/diagnostics_center.dart',
  'docs/phase6-automation-extension-core.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required automation extension file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('rss_auto_download_policy', 'online_rule_runtime', 'webview_session_backfill', 'network_policy', 'diagnostics_center', 'DownloadEngineAdapter')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Phase 6 UI dependency '$term' found in $($file.FullName)"
    }
  }
}

$rssAutomation = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/rss/rss_auto_download_policy.dart') -Raw
if ($rssAutomation -notmatch 'RssAutoDownloadPolicy' -or $rssAutomation -notmatch 'RssMatcherExpression' -or $rssAutomation -notmatch 'RssAutomationHistoryStore' -or $rssAutomation -notmatch 'RssDownloadCandidate') {
  throw 'RSS auto-download policy must define policy, matcher, history, and candidate contracts.'
}
foreach ($term in @('bt_task_core', 'DownloadEngineAdapter', 'libtorrent')) {
  if ($rssAutomation -match [regex]::Escape($term)) {
    throw "RSS automation must not depend on streaming engine term: $term"
  }
}

$handoff = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/automation/rss_download_handoff.dart') -Raw
if ($handoff -notmatch 'AutomationDownloadEnqueuer' -or $handoff -notmatch 'BtTaskCreateRequest' -or $handoff -notmatch 'RssDownloadCandidate') {
  throw 'Domain automation handoff must translate RSS candidates into BT task create requests.'
}

$onlineRuntime = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/online/online_rule_runtime.dart') -Raw
if ($onlineRuntime -notmatch 'OnlineRuleRuntime' -or $onlineRuntime -notmatch 'cssSelector' -or $onlineRuntime -notmatch 'xpath1' -or $onlineRuntime -notmatch 'regex' -or $onlineRuntime -notmatch 'UnsupportedOnlineOperationKind') {
  throw 'Online rule runtime must define declarative selector and unsupported-operation contracts.'
}
foreach ($term in @('runJavascript', 'dart:mirrors', 'eval(', 'Function.apply', 'package:flutter')) {
  if ($onlineRuntime -match [regex]::Escape($term)) {
    throw "Online rule runtime contains forbidden executable rule term: $term"
  }
}

$sessionBackfill = Get-Content -LiteralPath (Join-Path $root 'lib/src/network/webview_session_backfill.dart') -Raw
if ($sessionBackfill -notmatch 'ManualChallengeRequest' -or $sessionBackfill -notmatch 'SessionArtifactBundle' -or $sessionBackfill -notmatch 'ProviderSessionBackfill' -or $sessionBackfill -notmatch 'WebViewSessionCapabilityMatrix') {
  throw 'WebView session backfill must define manual challenge, artifact, handoff, and capability contracts.'
}
foreach ($term in @('AutoSolve', 'captchaSolver', 'headless', 'runJavascript')) {
  if ($sessionBackfill -match [regex]::Escape($term)) {
    throw "WebView session backfill contains forbidden automation term: $term"
  }
}

$networkPolicy = Get-Content -LiteralPath (Join-Path $root 'lib/src/network/network_policy.dart') -Raw
if ($networkPolicy -notmatch 'NetworkPolicyEvaluator' -or $networkPolicy -notmatch 'NetworkPolicyFailureKind' -or $networkPolicy -notmatch 'loopbackAddress' -or $networkPolicy -notmatch 'privateNetworkAddress' -or $networkPolicy -notmatch 'NetworkPolicyCapabilityMatrix') {
  throw 'Network policy must define evaluator, SSRF failure kinds, and capability contracts.'
}
foreach ($term in @('VpnService', 'TUN', 'kernel', 'DPI', 'zeroLeak')) {
  if ($networkPolicy -match [regex]::Escape($term)) {
    throw "Network policy contains forbidden system-routing promise term: $term"
  }
}

$diagnostics = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/diagnostics/diagnostics_center.dart') -Raw
if ($diagnostics -notmatch 'DiagnosticsEventRegistry' -or $diagnostics -notmatch 'DiagnosticsCenter' -or $diagnostics -notmatch 'DiagnosticsSnapshot' -or $diagnostics -notmatch 'DiagnosticsRedactionPolicy') {
  throw 'Diagnostics center must define registry, center, snapshot, and redaction contracts.'
}
foreach ($term in @('pause(', 'resume(', 'remove(', 'selectFiles(', 'createTask(', 'setNetworkPolicy')) {
  if ($diagnostics -match [regex]::Escape($term)) {
    throw "Diagnostics center must remain read-only; forbidden operation found: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
  }
}

'Automation extension core checks passed.'
