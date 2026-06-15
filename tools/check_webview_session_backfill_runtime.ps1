$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# --- Required files ---
$requiredFiles = @(
    "$root\lib\src\network\webview_session_backfill.dart"
    "$root\lib\src\network\webview_session_backfill_runtime.dart"
    "$root\lib\src\foundation\storage\webview_session_backfill_storage_contracts.dart"
    "$root\lib\src\foundation\cache_invalidation\cache_invalidation_bus.dart"
    "$root\test\network\webview_session_backfill_contract_test.dart"
    "$root\test\network\webview_session_backfill_runtime_test.dart"
    "$root\tools\webview_session_backfill_runtime_check.dart"
)
foreach ($f in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Missing required file: $f" }
}

# --- Run Dart smoke checker ---
dart run "$root\tools\webview_session_backfill_runtime_check.dart"
if ($LASTEXITCODE -ne 0) { throw "Dart smoke checker failed with exit code $LASTEXITCODE" }

# --- Required runtime terms ---
$runtime = "$root\lib\src\network\webview_session_backfill_runtime.dart"
$requiredTerms = @(
    'WebViewSessionBackfillRuntimeBootstrap',
    'WebViewSessionBackfillRuntime',
    'WebViewSessionBackfillRuntimeFailureKind',
    'WebViewSessionBackfillRuntimeFailure',
    'WebViewSessionBackfillRuntimeActionResultKind',
    'WebViewSessionBackfillRuntimeActionResult',
    'WebViewSessionBackfillRuntimeRestartProjection',
    'WebViewSessionBackfillRuntimeProjection',
    'snapshot(',
    'completeManually(',
    'prepareRetry(',
    'revokeArtifact(',
    'recordCapability(',
    'dispose(',
    'unavailable(',
    'WebViewSessionBackfillRuntimeFailureKind.capabilityUnsupported'
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
if ($barrelContent -notmatch "export 'src/network/webview_session_backfill.dart'") {
    throw "Missing barrel export for webview_session_backfill.dart"
}
if ($barrelContent -notmatch "export 'src/network/webview_session_backfill_runtime.dart'") {
    throw "Missing barrel export for webview_session_backfill_runtime.dart"
}

# --- Checker terms ---
$checker = "$root\tools\webview_session_backfill_runtime_check.dart"
$checkerContent = Get-Content -LiteralPath $checker -Raw
$checkerTerms = @(
    "import '../lib/celesteria.dart';",
    'DeterministicWebViewSessionBackfillStore',
    'StreamCacheInvalidationBus',
    'WebViewSessionBackfillRuntimeBootstrap',
    'WebViewSessionBackfillRuntimeFailureKind.rejectedOrigin',
    '.unavailable(',
    'dispose()',
    '_expect'
)
foreach ($term in $checkerTerms) {
    if ($checkerContent -notmatch [regex]::Escape($term)) {
        throw "Required checker term not found: $term"
    }
}

# --- Forbidden boundary terms in runtime, test, and checker ---
$forbiddenTerms = @(
    'package:webview_flutter',
    'InAppWebView',
    'MethodChannel',
    'EventChannel',
    'NetworkPolicy',
    'DiagnosticsCenter',
    'DiagnosticsEvent',
    'OnlineRuleRuntime',
    'RssAutoDownload',
    'BtTask',
    'libtorrent',
    'mpv',
    'vlc',
    'media-kit',
    'yuc.wiki',
    'dart:ffi',
    'DynamicLibrary',
    'automaticCaptchaSolving',
    'challengeBypass',
    'credentialGuessing',
    'botCompletion',
    'headlessAutomation',
    'hiddenBrowserInteraction',
    'sharedProfileCookieAccess'
)
$filesToScan = @(
    "$root\lib\src\network\webview_session_backfill_runtime.dart"
    "$root\test\network\webview_session_backfill_runtime_test.dart"
    "$root\tools\webview_session_backfill_runtime_check.dart"
)
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
    'package:webview_flutter',
    'player_adapter',
    'playback_controller',
    'mpv',
    'vlc',
    'media_kit',
    'shader',
    'native_renderer',
    'diagnostics_center',
    'online_rule',
    'rss_',
    'network_policy',
    'fallback_adapter',
    'bt_task',
    'rss_download_handoff'
)
foreach ($importLine in $runtimeImports) {
    foreach ($term in $forbiddenImports) {
        if ($importLine -match [regex]::Escape($term)) {
            throw "Forbidden import '$term' in runtime: $importLine"
        }
    }
}

Write-Host 'WebView session backfill runtime checks passed.'
