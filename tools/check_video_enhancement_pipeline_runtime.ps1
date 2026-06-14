$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. Required file presence
# ---------------------------------------------------------------------------
$requiredFiles = @(
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/video_enhancement_storage_contracts.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/video_enhancement_pipeline.dart',
  'lib/src/playback/video_enhancement_pipeline_runtime.dart',
  'test/playback/video_enhancement_pipeline_runtime_test.dart',
  'tools/video_enhancement_pipeline_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required video enhancement pipeline runtime file: $file"
  }
}

# ---------------------------------------------------------------------------
# 2. Dart smoke check
# ---------------------------------------------------------------------------
& dart run (Join-Path $root 'tools/video_enhancement_pipeline_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Video enhancement pipeline runtime Dart checker failed with exit code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# 3. Required-term checks in runtime surface
# ---------------------------------------------------------------------------
$runtimePath = Join-Path $root 'lib/src/playback/video_enhancement_pipeline_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
  'VideoEnhancementPipelineBootstrap',
  'VideoEnhancementPipelineRuntime',
  'EnhancementRuntimeDegradationRequest',
  'VideoEnhancementPipelineRuntimeProjection',
  'VideoEnhancementPipelineRuntimeRestartProjection',
  'VideoEnhancementPipelineRuntimeFailure',
  'VideoEnhancementPipelineRuntimeFailureKind',
  'VideoEnhancementPipelineRuntimeActionResult',
  'evaluate(',
  'apply(',
  'requestDegradation(',
  'snapshot(',
  'dispose(',
  'unavailable('
)
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Video enhancement pipeline runtime missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 4. Barrel export check
# ---------------------------------------------------------------------------
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  "export 'src/playback/video_enhancement_pipeline.dart';",
  "export 'src/playback/video_enhancement_pipeline_runtime.dart';"
)) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public Dart contract barrel missing export: $export"
  }
}

# ---------------------------------------------------------------------------
# 5. Required-term checks in checker surface
# ---------------------------------------------------------------------------
$checkerPath = Join-Path $root 'tools/video_enhancement_pipeline_runtime_check.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw

foreach ($term in @(
  "import '../lib/celesteria.dart';",
  'DeterministicEnhancementProfileStore',
  'StreamCacheInvalidationBus',
  'DeterministicVideoEnhancementPipeline',
  'VideoEnhancementPipelineBootstrap',
  'EnhancementRuntimeDegradationRequest',
  'VideoEnhancementPipelineRuntimeFailureKind',
  'VideoEnhancementPipelineRuntime.unavailable',
  'dispose()',
  'DateTime.utc(2026, 6, 14, 12)'
)) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Video enhancement pipeline runtime checker missing required term: $term"
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
  'PlayerAdapter',
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
  'driftThreshold',
  'guardHealth',
  'orderedDegradation',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'CaptionRendering',
  'AdvancedCaption',
  'FallbackAdapter',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $runtimeForbiddenTerms) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden video enhancement runtime boundary term '$term' found in video_enhancement_pipeline_runtime.dart"
  }
}

$runtimeTestPath = Join-Path $root 'test/playback/video_enhancement_pipeline_runtime_test.dart'
$runtimeTest = Get-Content -LiteralPath $runtimeTestPath -Raw

# Tests may import flutter_test; reject only concrete UI/runtime Flutter imports.
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
  'PlayerAdapter',
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
  'driftThreshold',
  'guardHealth',
  'orderedDegradation',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'CaptionRendering',
  'AdvancedCaption',
  'FallbackAdapter',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $testAndCheckerForbiddenTerms) {
  if ($runtimeTest -match [regex]::Escape($term)) {
    throw "Forbidden video enhancement boundary term '$term' found in video_enhancement_pipeline_runtime_test.dart"
  }
  if ($checker -match [regex]::Escape($term)) {
    throw "Forbidden video enhancement boundary term '$term' found in video_enhancement_pipeline_runtime_check.dart"
  }
}

# ---------------------------------------------------------------------------
# 7. Scope guard: runtime imports stay on Step 22 contracts
# ---------------------------------------------------------------------------
$runtimeImports = Get-Content -LiteralPath $runtimePath | Where-Object { $_ -match '^import ' }
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
  'av_sync_guard',
  'diagnostics_center',
  'rss_auto_download',
  'online_rule_runtime',
  'network_policy',
  'caption',
  'fallback'
)
foreach ($import in $forbiddenImports) {
  if ($runtimeImports -match [regex]::Escape($import)) {
    throw "Video enhancement pipeline runtime must not import boundary surface: $import"
  }
}

Write-Output 'Video enhancement pipeline runtime checks passed.'
