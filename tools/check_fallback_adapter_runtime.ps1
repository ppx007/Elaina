$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. Required file presence
# ---------------------------------------------------------------------------
$requiredFiles = @(
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/fallback_adapter_storage_contracts.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/fallback_adapter.dart',
  'lib/src/playback/fallback_adapter_runtime.dart',
  'test/playback/fallback_adapter_runtime_test.dart',
  'tools/fallback_adapter_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required fallback adapter runtime file: $file"
  }
}

# ---------------------------------------------------------------------------
# 2. Dart smoke check
# ---------------------------------------------------------------------------
& dart run (Join-Path $root 'tools/fallback_adapter_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Fallback adapter runtime Dart checker failed with exit code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# 3. Required-term checks in runtime surface
# ---------------------------------------------------------------------------
$runtimePath = Join-Path $root 'lib/src/playback/fallback_adapter_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
  'FallbackAdapterBootstrap',
  'FallbackAdapterRuntime',
  'FallbackAdapterRuntimeProjection',
  'FallbackAdapterRuntimeRestartProjection',
  'FallbackAdapterRuntimeFailure',
  'FallbackAdapterRuntimeFailureKind',
  'FallbackAdapterRuntimeActionResult',
  'registerCandidate(',
  'deregisterCandidate(',
  'selectFallback(',
  'disable(',
  'reevaluateCapabilities(',
  'snapshot(',
  'dispose(',
  'unavailable('
)
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Fallback adapter runtime missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 4. Barrel export check
# ---------------------------------------------------------------------------
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  "export 'src/playback/fallback_adapter.dart';",
  "export 'src/playback/fallback_adapter_runtime.dart';"
)) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public Dart contract barrel missing export: $export"
  }
}

# ---------------------------------------------------------------------------
# 5. Required-term checks in checker surface
# ---------------------------------------------------------------------------
$checkerPath = Join-Path $root 'tools/fallback_adapter_runtime_check.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw

foreach ($term in @(
  "import '../lib/celesteria.dart';",
  'DeterministicFallbackAdapterStore',
  'StreamCacheInvalidationBus',
  'DeterministicPlaybackFallbackStrategy',
  'FallbackAdapterBootstrap',
  'FallbackAdapterRuntimeFailureKind',
  'FallbackAdapterRuntime.unavailable',
  'dispose()',
  'DateTime.utc(2026, 6, 15, 12)'
)) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Fallback adapter runtime checker missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 6. Scope guard: forbidden boundary terms
# ---------------------------------------------------------------------------
$runtimeForbiddenTerms = @(
  'dart:io',
  'HttpServer',
  'HttpClient',
  'Socket',
  'RandomAccessFile',
  'PipeServer',
  'RangeServer',
  'package:flutter',
  'Widget',
  'RenderObject',
  'Canvas',
  'CustomPainter',
  'GestureDetector',
  'MouseRegion',
  'Tooltip',
  'package:flutter/material',
  'package:flutter/widgets',
  'package:flutter/cupertino',
  'package:flutter/rendering',
  'package:flutter/services',
  'seekTo',
  'executeSeek',
  'pausePlayback',
  'resumePlayback',
  'PlaybackController',
  'NativePlayer',
  'Mpv',
  'Vlc',
  'media-kit',
  'platform channel',
  'MethodChannel',
  'EventChannel',
  'dart:ffi',
  'DynamicLibrary',
  'Pointer<',
  'ShaderBundle',
  'ShaderGraph',
  'compileShader',
  'NativeRenderer',
  'RendererBinding',
  'VlcFallback',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $runtimeForbiddenTerms) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden fallback adapter runtime boundary term '$term' found in fallback_adapter_runtime.dart"
  }
}

$runtimeTestPath = Join-Path $root 'test/playback/fallback_adapter_runtime_test.dart'
$runtimeTest = Get-Content -LiteralPath $runtimeTestPath -Raw

# Tests may import flutter_test; reject only concrete UI/runtime Flutter imports.
# Note: PlayerAdapter is NOT forbidden in test/checker since FallbackAdapterCandidate requires it.
$testAndCheckerForbiddenTerms = @(
  'dart:io',
  'HttpServer',
  'HttpClient',
  'Socket',
  'RandomAccessFile',
  'PipeServer',
  'RangeServer',
  'package:flutter/material',
  'package:flutter/widgets',
  'package:flutter/cupertino',
  'package:flutter/rendering',
  'package:flutter/services',
  'Widget',
  'RenderObject',
  'Canvas',
  'CustomPainter',
  'GestureDetector',
  'MouseRegion',
  'Tooltip',
  'seekTo',
  'executeSeek',
  'pausePlayback',
  'resumePlayback',
  'PlaybackController',
  'NativePlayer',
  'media-kit',
  'platform channel',
  'MethodChannel',
  'EventChannel',
  'dart:ffi',
  'DynamicLibrary',
  'Pointer<',
  'ShaderBundle',
  'ShaderGraph',
  'compileShader',
  'NativeRenderer',
  'RendererBinding',
  'VlcFallback',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $testAndCheckerForbiddenTerms) {
  if ($runtimeTest -match [regex]::Escape($term)) {
    throw "Forbidden fallback adapter boundary term '$term' found in fallback_adapter_runtime_test.dart"
  }
  if ($checker -match [regex]::Escape($term)) {
    throw "Forbidden fallback adapter boundary term '$term' found in fallback_adapter_runtime_check.dart"
  }
}

# ---------------------------------------------------------------------------
# 7. Scope guard: runtime imports stay within Step 25 contracts
# ---------------------------------------------------------------------------
$runtimeImports = Get-Content -LiteralPath $runtimePath | Where-Object { $_ -match '^import ' }
$forbiddenImports = @(
  'dart:io',
  'dart:ffi',
  'package:flutter',
  'playback_controller',
  'mpv',
  'vlc',
  'media_kit',
  'shader',
  'native_renderer',
  'diagnostics_center',
  'rss_auto_download',
  'online_rule_runtime',
  'network_policy',
  'advanced_caption',
  'av_sync_guard',
  'video_enhancement'
)
foreach ($import in $forbiddenImports) {
  if ($runtimeImports -match [regex]::Escape($import)) {
    throw "Fallback adapter runtime must not import boundary surface: $import"
  }
}

Write-Output 'Fallback adapter runtime checks passed.'
