$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# --- Required files ---
$requiredFiles = @(
    "$root\lib\src\foundation\cache_invalidation\cache_invalidation_bus.dart"
    "$root\lib\src\foundation\storage\rss_auto_download_policy_storage_contracts.dart"
    "$root\lib\src\provider\rss\feed_contracts.dart"
    "$root\lib\src\provider\rss\rss_auto_download_policy.dart"
    "$root\lib\src\provider\rss\rss_auto_download_runtime.dart"
    "$root\test\provider\rss\rss_auto_download_runtime_test.dart"
    "$root\tools\rss_auto_download_runtime_check.dart"
)
foreach ($f in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Missing required file: $f" }
}

# --- Run Dart smoke checker ---
dart run "$root\tools\rss_auto_download_runtime_check.dart"
if ($LASTEXITCODE -ne 0) { throw "Dart smoke checker failed with exit code $LASTEXITCODE" }

# --- Required runtime terms ---
$runtime = "$root\lib\src\provider\rss\rss_auto_download_runtime.dart"
$requiredTerms = @(
    'RssAutoDownloadPolicyRuntimeBootstrap',
    'RssAutoDownloadPolicyRuntime',
    'RssAutoDownloadPolicyRuntimeFailureKind',
    'RssAutoDownloadPolicyRuntimeFailure',
    'RssAutoDownloadPolicyRuntimeActionResultKind',
    'RssAutoDownloadPolicyRuntimeActionResult',
    'RssAutoDownloadPolicyRuntimeRestartProjection',
    'RssAutoDownloadPolicyRuntimeProjection',
    'evaluate(',
    'handoff(',
    'disable(',
    'reenable(',
    'snapshot(',
    'dispose(',
    'unavailable(',
    'RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported'
)
foreach ($term in $requiredTerms) {
    $content = Get-Content -LiteralPath $runtime -Raw
    if ($content -notmatch [regex]::Escape($term)) {
        throw "Required runtime term not found: $term"
    }
}

# --- Barrel exports ---
$barrel = "$root\lib\celesteria.dart"
$barrelContent = Get-Content -LiteralPath $barrel -Raw
if ($barrelContent -notmatch "export 'src/provider/rss/rss_auto_download_policy.dart'") {
    throw "Missing barrel export for rss_auto_download_policy.dart"
}
if ($barrelContent -notmatch "export 'src/provider/rss/rss_auto_download_runtime.dart'") {
    throw "Missing barrel export for rss_auto_download_runtime.dart"
}

# --- Checker terms ---
$checker = "$root\tools\rss_auto_download_runtime_check.dart"
$checkerContent = Get-Content -LiteralPath $checker -Raw
$checkerTerms = @(
    "import '../lib/celesteria.dart';",
    'DeterministicRssAutoDownloadPolicyStore',
    'DeterministicRssAutomationHistoryStore',
    'StreamCacheInvalidationBus',
    'DeterministicRssAutoDownloadPolicyEvaluator',
    'RssAutoDownloadPolicyRuntimeBootstrap',
    'RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported',
    '.unavailable(',
    'dispose()',
    'DateTime.utc(2026, 6, 15, 12)'
)
foreach ($term in $checkerTerms) {
    if ($checkerContent -notmatch [regex]::Escape($term)) {
        throw "Required checker term not found: $term"
    }
}

# --- Forbidden boundary terms in runtime ---
$forbiddenTerms = @(
    'FeedFetcher',
    'FeedParser',
    'libtorrent',
    'WebView',
    'captcha',
    'DiagnosticsCenter',
    'DiagnosticsEvent',
    'RssAutoDownloadFeedScheduler',
    'OnlineRuleRuntime',
    'NetworkPolicy',
    'FlutterWidget',
    'package:flutter/material',
    'dart:ffi',
    'DynamicLibrary',
    'MethodChannel',
    'EventChannel',
    'bt_task_core',
    'rss_download_handoff',
    'MpvAdapter',
    'VlcAdapter',
    'media-kit'
)
$filesToScan = @($runtime, "$root\test\provider\rss\rss_auto_download_runtime_test.dart", $checker)
foreach ($f in $filesToScan) {
    $content = Get-Content -LiteralPath $f -Raw
    foreach ($term in $forbiddenTerms) {
        if ($content -match [regex]::Escape($term)) {
            throw "Forbidden boundary term '$term' found in $f"
        }
    }
}

# --- Runtime import guards ---
$runtimeImports = Get-Content -LiteralPath $runtime | Where-Object { $_ -match '^import ' }
$forbiddenImports = @(
    'dart:io',
    'dart:ffi',
    'package:flutter',
    'player_adapter',
    'playback_controller',
    'mpv',
    'vlc',
    'media_kit',
    'shader',
    'native_renderer',
    'diagnostics_center',
    'rss_auto_download_feed_scheduler',
    'online_rule_runtime',
    'network_policy',
    'fallback_adapter',
    'bt_task_core',
    'rss_download_handoff'
)
foreach ($importLine in $runtimeImports) {
    foreach ($term in $forbiddenImports) {
        if ($importLine -match [regex]::Escape($term)) {
            throw "Forbidden import '$term' in runtime: $importLine"
        }
    }
}

Write-Host 'RSS auto-download policy runtime checks passed.'
