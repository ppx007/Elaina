$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# ---------------------------------------------------------------------------
# 1. Required file presence
# ---------------------------------------------------------------------------
$requiredFiles = @(
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/advanced_caption_storage_contracts.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/advanced_caption_rendering.dart',
  'lib/src/playback/advanced_caption_rendering_runtime.dart',
  'lib/src/playback/media_kit_mpv_binding.dart',
  'test/playback/advanced_caption_rendering_runtime_test.dart',
  'tools/runtime_checks/advanced_caption_rendering_runtime_contract.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required advanced caption rendering runtime file: $file"
  }
}

# ---------------------------------------------------------------------------
# 2. Dart smoke check
# ---------------------------------------------------------------------------
& dart run (Join-Path $root 'tools/runtime_checks/advanced_caption_rendering_runtime_contract.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Advanced caption rendering runtime Dart checker failed with exit code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# 3. Required-term checks in runtime surface
# ---------------------------------------------------------------------------
$runtimePath = Join-Path $root 'lib/src/playback/advanced_caption_rendering_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
  'AdvancedCaptionRuntimeBootstrap',
  'AdvancedCaptionRuntime',
  'AdvancedCaptionRuntimeProjection',
  'AdvancedCaptionRuntimeRestartProjection',
  'AdvancedCaptionRuntimeFailure',
  'AdvancedCaptionRuntimeFailureKind',
  'AdvancedCaptionRuntimeActionResult',
  'evaluate(',
  'renderMatrixDanmaku(',
  'renderDualSubtitles(',
  'renderAdvancedSubtitle(',
  'disable(',
  'acceptDegradation(',
  'snapshot(',
  'dispose(',
  'unavailable('
)
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Advanced caption rendering runtime missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 4. Barrel export check
# ---------------------------------------------------------------------------
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  "export 'src/playback/advanced_caption_rendering.dart';",
  "export 'src/playback/advanced_caption_rendering_runtime.dart';"
)) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public Dart contract barrel missing export: $export"
  }
}

# ---------------------------------------------------------------------------
# 5. Required-term checks in checker surface
# ---------------------------------------------------------------------------
$checkerPath = Join-Path $root 'tools/runtime_checks/advanced_caption_rendering_runtime_contract.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw

foreach ($term in @(
  "import '../../lib/elaina.dart';",
  'DeterministicAdvancedCaptionStore',
  'StreamCacheInvalidationBus',
  'DeterministicAdvancedCaptionRenderer',
  'AdvancedCaptionRuntimeBootstrap',
  'AdvancedCaptionRuntimeFailureKind',
  'AdvancedCaptionRuntime.unavailable',
  'dispose()',
  'DateTime.utc(2026, 6, 15, 12)'
)) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Advanced caption rendering runtime checker missing required term: $term"
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
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'FallbackAdapter',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $runtimeForbiddenTerms) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden advanced caption rendering runtime boundary term '$term' found in advanced_caption_rendering_runtime.dart"
  }
}

$runtimeTestPath = Join-Path $root 'test/playback/advanced_caption_rendering_runtime_test.dart'
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
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'WebView',
  'Captcha',
  'FallbackAdapter',
  'FallbackOrchestrator',
  'NetworkPolicy',
  'StorageMigration',
  'MigrationRunner'
)

foreach ($term in $testAndCheckerForbiddenTerms) {
  if ($runtimeTest -match [regex]::Escape($term)) {
    throw "Forbidden advanced caption rendering boundary term '$term' found in advanced_caption_rendering_runtime_test.dart"
  }
  if ($checker -match [regex]::Escape($term)) {
    throw "Forbidden advanced caption rendering boundary term '$term' found in advanced_caption_rendering_runtime_contract.dart"
  }
}

# ---------------------------------------------------------------------------
# 7. Scope guard: runtime imports stay on Step 24 contracts
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
  'diagnostics_center',
  'rss_auto_download',
  'online_rule_runtime',
  'network_policy',
  'fallback'
)
foreach ($import in $forbiddenImports) {
  if ($runtimeImports -match [regex]::Escape($import)) {
    throw "Advanced caption rendering runtime must not import boundary surface: $import"
  }
}

# ---------------------------------------------------------------------------
# 8. Step 57 concrete MPV subtitle bridge stays in approved Playback binding
# ---------------------------------------------------------------------------
$mediaKitBindingPath = Join-Path $root 'lib/src/playback/media_kit_mpv_binding.dart'
$mediaKitBinding = Get-Content -LiteralPath $mediaKitBindingPath -Raw
$requiredMpvSubtitleTerms = @(
  'MpvAdvancedSubtitleBinding',
  'MpvSubtitlePlanner',
  'MpvSubtitlePlan',
  'MpvSubtitleCommand',
  'mpvSubtitleAddCommand',
  'mpvSubtitlePrimaryProperty',
  'mpvSubtitleSecondaryProperty',
  'mpvSubtitleAssProperty',
  'renderDualSubtitles',
  'renderAdvancedSubtitle',
  'disableAdvancedSubtitles',
  'AdvancedCaptionFailureKind.adapterRejected'
)
foreach ($term in $requiredMpvSubtitleTerms) {
  if ($mediaKitBinding -notmatch [regex]::Escape($term)) {
    throw "Concrete MPV subtitle bridge missing required term: $term"
  }
}

$approvedConcretePlayerImportFiles = @(
  'lib/src/playback/media_kit_mpv_binding.dart'
)
$sourceDartFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $sourceDartFiles) {
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $content = Get-Content -LiteralPath $file.FullName -Raw
  if ($content -match [regex]::Escape('package:media_kit/')) {
    if ($approvedConcretePlayerImportFiles -notcontains $relativePath) {
      throw "Concrete player package import is only allowed in approved Playback binding files: $($file.FullName)"
    }
  }
}

Write-Output 'Advanced caption rendering runtime checks passed.'

