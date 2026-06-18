$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_advanced_playback_core.ps1')
& (Join-Path $PSScriptRoot 'check_online_rule_test_harness.ps1')
& (Join-Path $PSScriptRoot 'check_automation_smoke_gate.ps1')

$requiredFiles = @(
  'lib/src/provider/rss/rss_auto_download_policy.dart',
  'lib/src/foundation/storage/rss_auto_download_policy_storage_contracts.dart',
  'lib/src/domain/automation/rss_download_handoff.dart',
  'lib/src/provider/online/online_rule_runtime.dart',
  'lib/src/provider/online/online_rule_test_harness.dart',
  'lib/src/foundation/storage/online_rule_runtime_storage_contracts.dart',
  'lib/src/network/webview_session_backfill.dart',
  'lib/src/network/network_policy.dart',
  'lib/src/foundation/storage/network_policy_storage_contracts.dart',
  'lib/src/foundation/diagnostics/diagnostics_center.dart',
  'lib/src/foundation/diagnostics/diagnostics_runtime_impl.dart',
  'lib/src/foundation/storage/diagnostics_storage_contracts.dart',
  'docs/phase6-automation-extension-core.md',
  'docs/online-rule-test-harness.md',
  'docs/automation-smoke-gate.md'
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
if ($rssAutomation -notmatch 'RssAutoDownloadPolicy' -or $rssAutomation -notmatch 'RssMatcherExpression' -or $rssAutomation -notmatch 'RssAutomationHistoryStore' -or $rssAutomation -notmatch 'RssDownloadCandidate' -or $rssAutomation -notmatch 'DeterministicRssAutoDownloadPolicyEvaluator' -or $rssAutomation -notmatch 'RssAutomationCapabilityMatrix') {
  throw 'RSS auto-download policy must define policy, matcher, history, candidate, deterministic evaluator, and capability contracts.'
}
foreach ($term in @('bt_task_core', 'DownloadEngineAdapter', 'libtorrent', 'FeedFetcher', 'FeedParser', 'yuc.wiki', 'WebView', 'runJavascript')) {
  if ($rssAutomation -match [regex]::Escape($term)) {
    throw "RSS automation must not depend on forbidden Step 26 term: $term"
  }
}

$rssAutomationStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/rss_auto_download_policy_storage_contracts.dart') -Raw
foreach ($term in @('StoredRssAutoDownloadPolicyRecord', 'StoredRssAutoDownloadMatcherRecord', 'StoredRssAutoDownloadEvaluationRecord', 'StoredRssAutoDownloadAcceptedCandidateRecord', 'StoredRssAutoDownloadRejectedCandidateRecord', 'StoredRssAutoDownloadDedupeRecord', 'StoredRssAutoDownloadEnqueueOutcomeRecord', 'RssAutoDownloadPolicyStore', 'DeterministicRssAutoDownloadPolicyStore')) {
  if ($rssAutomationStorage -notmatch [regex]::Escape($term)) {
    throw "RSS auto-download storage is missing contract term: $term"
  }
}
foreach ($term in @('DownloadEngineAdapter', 'FeedFetcher', 'FeedParser', 'libtorrent', 'WebView', 'runJavascript', 'yuc.wiki')) {
  if ($rssAutomationStorage -match [regex]::Escape($term)) {
    throw "RSS auto-download storage contains forbidden Step 26 dependency: $term"
  }
}

$cacheInvalidation = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart') -Raw
foreach ($term in @('RssAutoDownloadPolicyChanged', 'RssAutoDownloadFeedItemEvaluated', 'RssAutoDownloadCandidateAccepted', 'RssAutoDownloadCandidateRejected', 'RssAutoDownloadDedupeStateChanged', 'RssAutoDownloadEnqueueOutcomeRecorded')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing RSS automation event: $term"
  }
}

$handoff = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/automation/rss_download_handoff.dart') -Raw
if ($handoff -notmatch 'AutomationDownloadEnqueuer' -or $handoff -notmatch 'BtTaskCreateRequest' -or $handoff -notmatch 'RssDownloadCandidate') {
  throw 'Domain automation handoff must translate RSS candidates into BT task create requests.'
}

$onlineRuntimeStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/online_rule_runtime_storage_contracts.dart') -Raw
foreach ($term in @('StoredOnlineRuleManifestRecord', 'StoredOnlineRuleSetRecord', 'StoredOnlineExtractionOperationRecord', 'StoredOnlineRuleValidationIssueRecord', 'StoredOnlineRuleEvaluationSnapshotRecord', 'StoredOnlineRulePageRetrievalOutcomeRecord', 'StoredUnsupportedOnlineOperationRecord', 'StoredOnlineRuleSourceCapabilityRecord', 'OnlineRuleRuntimeStore', 'DeterministicOnlineRuleRuntimeStore')) {
  if ($onlineRuntimeStorage -notmatch [regex]::Escape($term)) {
    throw "Online rule runtime storage is missing contract term: $term"
  }
}
foreach ($term in @('WebView', 'runJavascript', 'eval(', 'Function.apply', 'dart:mirrors', 'package:flutter', 'captchaSolver', 'yuc.wiki', 'DnsClient', 'ProxyServer')) {
  if ($onlineRuntimeStorage -match [regex]::Escape($term)) {
    throw "Online rule runtime storage contains forbidden Step 27 dependency: $term"
  }
}

$onlineRuntime = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/online/online_rule_runtime.dart') -Raw
if ($onlineRuntime -notmatch 'OnlineRuleRuntime' -or $onlineRuntime -notmatch 'cssSelector' -or $onlineRuntime -notmatch 'xpath1' -or $onlineRuntime -notmatch 'regex' -or $onlineRuntime -notmatch 'UnsupportedOnlineOperationKind' -or $onlineRuntime -notmatch 'DeterministicOnlineRuleRuntime' -or $onlineRuntime -notmatch 'OnlineRuleCapabilityMatrix' -or $onlineRuntime -notmatch 'OnlineRuleGatewayRequestDescriptor' -or $onlineRuntime -notmatch 'OnlineRuleNetworkPolicyHandoff') {
  throw 'Online rule runtime must define declarative selector, deterministic runtime, capability, gateway, network-policy, and unsupported-operation contracts.'
}
foreach ($term in @('runJavascript', 'dart:mirrors', 'eval(', 'Function.apply', 'package:flutter', 'WebViewController', 'captchaSolver', 'headless', 'yuc.wiki', 'DnsClient', 'ProxyServer', 'Crawler', 'Scraper')) {
  if ($onlineRuntime -match [regex]::Escape($term)) {
    throw "Online rule runtime contains forbidden Step 27 term: $term"
  }
}

foreach ($term in @('OnlineRuleManifestChanged', 'OnlineRuleValidationStateChanged', 'OnlineRuleTargetEvaluated', 'OnlineRulePageRetrievalOutcomeRecorded', 'OnlineRuleUnsupportedOperationRecorded', 'OnlineRuleCapabilityChanged')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing online rule event: $term"
  }
}

$sessionBackfillStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/webview_session_backfill_storage_contracts.dart') -Raw
foreach ($term in @('StoredManualChallengeRequestRecord', 'StoredWebViewSessionArtifactRecord', 'StoredWebViewSessionBackfillAttemptRecord', 'StoredWebViewSessionCapabilityRecord', 'WebViewSessionBackfillStore', 'DeterministicWebViewSessionBackfillStore')) {
  if ($sessionBackfillStorage -notmatch [regex]::Escape($term)) {
    throw "WebView session backfill storage is missing contract term: $term"
  }
}
foreach ($term in @('package:flutter', 'WebViewController', 'runJavascript', 'captchaSolver', 'AutoSolve', 'headlessBrowser', 'globalBrowserCookie')) {
  if ($sessionBackfillStorage -match [regex]::Escape($term)) {
    throw "WebView session backfill storage contains forbidden automation term: $term"
  }
}

$sessionBackfill = Get-Content -LiteralPath (Join-Path $root 'lib/src/network/webview_session_backfill.dart') -Raw
if ($sessionBackfill -notmatch 'ManualChallengeRequest' -or $sessionBackfill -notmatch 'ManualChallengeState' -or $sessionBackfill -notmatch 'SessionArtifactBundle' -or $sessionBackfill -notmatch 'SessionCookieArtifact' -or $sessionBackfill -notmatch 'ProviderSessionTokenArtifact' -or $sessionBackfill -notmatch 'WebViewSessionBackfillRetryDescriptor' -or $sessionBackfill -notmatch 'ProviderSessionBackfill' -or $sessionBackfill -notmatch 'WebViewSessionCapabilityMatrix' -or $sessionBackfill -notmatch 'UnsupportedWebViewSessionOperationKind' -or $sessionBackfill -notmatch 'WebViewSessionNetworkPolicyHandoff') {
  throw 'WebView session backfill must define manual challenge, normalized artifact, retry handoff, network handoff, unsupported-operation, and capability contracts.'
}
foreach ($term in @('AutoSolve', 'captchaSolver', 'headlessBrowser', 'runJavascript', 'WebViewController', 'package:flutter', 'globalBrowserCookie')) {
  if ($sessionBackfill -match [regex]::Escape($term)) {
    throw "WebView session backfill contains forbidden automation term: $term"
  }
}

foreach ($term in @('WebViewSessionChallengeChanged', 'WebViewSessionArtifactCaptured', 'WebViewSessionBackfillOutcomeRecorded', 'WebViewSessionArtifactStateChanged', 'WebViewSessionCapabilityChanged')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing WebView session event: $term"
  }
}

$networkPolicyStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/network_policy_storage_contracts.dart') -Raw
foreach ($term in @('StoredNetworkPolicyProfileRecord', 'StoredNetworkPolicyRuleRecord', 'StoredNetworkPolicyProviderAssignmentRecord', 'StoredNetworkPolicyEvaluationSnapshotRecord', 'StoredNetworkPolicyBlockOutcomeRecord', 'StoredNetworkPolicyCapabilityRecord', 'NetworkPolicyStore', 'DeterministicNetworkPolicyStore')) {
  if ($networkPolicyStorage -notmatch [regex]::Escape($term)) {
    throw "Network policy storage is missing contract term: $term"
  }
}
foreach ($term in @('DnsClient', 'DoHClient', 'DoTClient', 'ProxyServer', 'VpnService', 'TunInterface', 'PacketCapture', 'DpiEngine')) {
  if ($networkPolicyStorage -match [regex]::Escape($term)) {
    throw "Network policy storage contains forbidden concrete networking dependency: $term"
  }
}

$networkPolicy = Get-Content -LiteralPath (Join-Path $root 'lib/src/network/network_policy.dart') -Raw
foreach ($term in @('NetworkPolicyEvaluator', 'DeterministicNetworkPolicyEvaluator', 'NetworkPolicyFailureKind', 'loopbackAddress', 'privateNetworkAddress', 'NetworkPolicyCapabilityMatrix', 'dohIntent', 'dotIntent', 'ProviderNetworkPolicyHandoffDescriptor', 'NetworkPolicyFallbackBehavior')) {
  if ($networkPolicy -notmatch [regex]::Escape($term)) {
    throw "Network policy is missing contract term: $term"
  }
}
foreach ($term in @('VpnService', 'TunInterface', 'kernel filter', 'DpiEngine', 'PacketCapture', 'zeroLeak', 'DnsClient', 'DoHClient', 'DoTClient', 'ProxyServer')) {
  if ($networkPolicy -match [regex]::Escape($term)) {
    throw "Network policy contains forbidden system-routing promise term: $term"
  }
}

foreach ($term in @('NetworkPolicyProfileChanged', 'NetworkPolicyProviderAssignmentChanged', 'NetworkPolicyRuleChanged', 'NetworkPolicyEvaluationOutcomeRecorded', 'NetworkPolicyBlockDecisionRecorded', 'NetworkPolicyCapabilityChanged')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing network policy event: $term"
  }
}

$diagnostics = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/diagnostics/diagnostics_center.dart') -Raw
foreach ($term in @('DiagnosticsCapabilityMatrix', 'DiagnosticsCapabilityStatus', 'DiagnosticsFailureKind', 'DiagnosticsOperationOutcome', 'DiagnosticsEventRegistry', 'DeterministicDiagnosticsEventRegistry', 'DiagnosticsCenter', 'DeterministicDiagnosticsCenter', 'DiagnosticsSnapshot', 'DiagnosticsRedactionPolicy', 'DiagnosticsRetentionOutcome', 'DiagnosticsLocalExportDescriptor', 'capabilityAreas')) {
  if ($diagnostics -notmatch [regex]::Escape($term)) {
    throw "Diagnostics center is missing contract term: $term"
  }
}
foreach ($term in @('pause(', 'resume(', 'remove(', 'selectFiles(', 'createTask(', 'setNetworkPolicy', 'remoteTelemetry', 'CrashReporter', 'AnalyticsClient', 'cloudUpload', 'supportBundleUpload', 'WebViewController')) {
  if ($diagnostics -match [regex]::Escape($term)) {
    throw "Diagnostics center must remain read-only; forbidden operation found: $term"
  }
}

$diagnosticsImpl = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/diagnostics/diagnostics_runtime_impl.dart') -Raw
foreach ($term in @('DiagnosticsInvalidationCollector', 'DiagnosticsLocalExportBundleBuilder', 'CacheInvalidationEvent', 'DiagnosticsStore', 'DiagnosticsCenterRuntime', 'jsonLines')) {
  if ($diagnosticsImpl -notmatch [regex]::Escape($term)) {
    throw "Diagnostics runtime implementation missing term: $term"
  }
}
foreach ($term in @('remoteTelemetry', 'CrashReporter', 'AnalyticsClient', 'cloudUpload', 'supportBundleUpload', 'package:flutter', 'WebViewController', 'createTask(', 'setNetworkPolicy', 'dart:io', 'dart:ffi', 'MethodChannel')) {
  if ($diagnosticsImpl -match [regex]::Escape($term)) {
    throw "Diagnostics runtime implementation contains forbidden remote/control term: $term"
  }
}

$diagnosticsStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/diagnostics_storage_contracts.dart') -Raw
foreach ($term in @('StoredDiagnosticsSchemaRecord', 'StoredDiagnosticsEventRecord', 'StoredDiagnosticsSnapshotRecord', 'StoredDiagnosticsExportRequestRecord', 'StoredDiagnosticsExportOutcomeRecord', 'StoredDiagnosticsRetentionStateRecord', 'StoredDiagnosticsCapabilityRecord', 'DiagnosticsStore', 'DeterministicDiagnosticsStore')) {
  if ($diagnosticsStorage -notmatch [regex]::Escape($term)) {
    throw "Diagnostics storage is missing contract term: $term"
  }
}
foreach ($term in @('remoteTelemetry', 'CrashReporter', 'AnalyticsClient', 'cloudUpload', 'supportBundleUpload', 'package:flutter', 'WebViewController', 'createTask(', 'setNetworkPolicy')) {
  if ($diagnosticsStorage -match [regex]::Escape($term)) {
    throw "Diagnostics storage contains forbidden remote/control term: $term"
  }
}

foreach ($term in @('DiagnosticsSchemaRegistered', 'DiagnosticsEventRecorded', 'DiagnosticsSnapshotCreated', 'DiagnosticsExportRequestRecorded', 'DiagnosticsExportOutcomeRecorded', 'DiagnosticsRetentionEnforced', 'DiagnosticsCapabilityChanged')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing diagnostics event: $term"
  }
}

$gateway = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/gateway/provider_gateway.dart') -Raw
foreach ($term in @('ProviderDiagnosticsCorrelationDescriptor', 'ProviderRequestKey', 'ProviderCachePolicy', 'ProviderFailureKind', 'networkPolicyFailureKind', 'correlationId')) {
  if ($gateway -notmatch [regex]::Escape($term)) {
    throw "Provider gateway missing diagnostics correlation term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
  }
}


# Foundation bootstrap boundary validation
$bootstrap = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/foundation_bootstrap.dart') -Raw
$bootstrapForbiddenPhase6 = @(
  'package:flutter', 'WebViewController', 'runJavascript', 'eval(', 'Function.apply',
  'dart:mirrors', 'dart:ffi', 'captchaSolver', 'yuc.wiki', 'DnsClient', 'ProxyServer',
  'HttpClient(', 'SQLite', 'sqlite', 'dart:io'
)
foreach ($term in $bootstrapForbiddenPhase6) {
  if ($bootstrap -match [regex]::Escape($term)) {
    throw "Foundation bootstrap contains forbidden Phase 6 dependency: $term"
  }
}
foreach ($term in @('FoundationBootstrap', 'DeterministicStorageFoundation', 'FoundationRuntime', 'LayerBoundaryChecker', 'foundationBootstrapForbiddenDependencies')) {
  if ($bootstrap -notmatch [regex]::Escape($term)) {
    throw "Foundation bootstrap missing required contract surface: $term"
  }
}
'Automation extension core checks passed.'

# Extended Step 27 online rule runtime positive terms
foreach ($term in @('OnlineRuleManifest', 'OnlineRuleSourceId', 'OnlineRuleManifestVersion', 'OnlineRuleValidationResult', 'OnlineRuleEvaluationRequest', 'OnlineRuleEvaluationOutcome', 'OnlineExtractionOperation', 'OnlineRuleSet', 'GatewayBoundProvider')) {
  if ($onlineRuntime -notmatch [regex]::Escape($term)) {
    throw "Online rule runtime missing extended contract term: $term"
  }
}

# Extended Step 27 forbidden terms (actual code execution, not enum values)
$extendedForbiddenTerms = @('runJavascript', 'dart:js', 'package:js', 'js_interop', 'Function(', 'dart:ffi', 'dart:mirrors')
foreach ($term in $extendedForbiddenTerms) {
  if ($onlineRuntime -match [regex]::Escape($term)) {
    throw "Online rule runtime contains forbidden Step 27 extended term: $term"
  }
  if ($onlineRuntimeStorage -match [regex]::Escape($term)) {
    throw "Online rule runtime storage contains forbidden Step 27 extended term: $term"
  }
}

# Scope isolation: Phase 6 foundation files must not import playback/streaming/UI
$phaseFoundationDirs = @(
  'lib/src/foundation/cache_invalidation',
  'lib/src/foundation/diagnostics',
  'lib/src/foundation/gateway',
  'lib/src/foundation/layers',
  'lib/src/foundation/storage'
)
$scopeIsolationForbiddenLayers = @('playback', 'streaming', 'ui')
foreach ($dir in $phaseFoundationDirs) {
  $dirPath = Join-Path $root $dir
  if (-not (Test-Path -LiteralPath $dirPath)) {
    continue
  }
  $files = Get-ChildItem -LiteralPath $dirPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $files) {
    $fileContent = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($layer in $scopeIsolationForbiddenLayers) {
      $singleQuotePattern = "../$layer/"
      $packagePattern = "package:celesteria/src/$layer/"
      if ($fileContent.Contains($singleQuotePattern) -or $fileContent.Contains($packagePattern)) {
        throw "Phase 6 foundation file $($file.Name) imports forbidden layer: $layer"
      }
    }
  }
}

# GatewayBoundProvider must exist in provider layer
$gatewayBoundPath = Join-Path $root 'lib/src/provider/gateway_bound_provider.dart'
if (-not (Test-Path -LiteralPath $gatewayBoundPath)) {
  throw 'Missing required GatewayBoundProvider file.'
}
$gatewayBound = Get-Content -LiteralPath $gatewayBoundPath -Raw
foreach ($term in @('GatewayBoundProvider', 'ProviderGateway')) {
  if ($gatewayBound -notmatch [regex]::Escape($term)) {
    throw "GatewayBoundProvider missing required term: $term"
  }
}
foreach ($term in @('HttpClient(', 'DnsClient', 'ProxyServer', 'package:flutter', 'runJavascript')) {
  if ($gatewayBound -match [regex]::Escape($term)) {
    throw "GatewayBoundProvider contains forbidden dependency: $term"
  }
}
