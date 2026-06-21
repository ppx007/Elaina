$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# ---------------------------------------------------------------------------
# 1. Required file presence
# ---------------------------------------------------------------------------
$requiredFiles = @(
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/timeline_overlay_storage_contracts.dart',
  'lib/src/streaming/timeline_overlay.dart',
  'lib/src/streaming/timeline_overlay_runtime.dart',
  'lib/src/streaming/virtual_media_stream.dart',
  'test/streaming/timeline_overlay_runtime_test.dart',
  'tools/runtime_checks/timeline_overlay_runtime_contract.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required timeline overlay runtime file: $file"
  }
}

# ---------------------------------------------------------------------------
# 2. Dart smoke check
# ---------------------------------------------------------------------------
& dart run (Join-Path $root 'tools/runtime_checks/timeline_overlay_runtime_contract.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Timeline overlay runtime Dart checker failed with exit code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# 3. Required-term checks in runtime surface
# ---------------------------------------------------------------------------
$runtimePath = Join-Path $root 'lib/src/streaming/timeline_overlay_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
  'TimelineOverlayBootstrap',
  'TimelineOverlayRuntime',
  'TimelineOverlayRuntimeCompositionRequest',
  'TimelineOverlayRuntimeProjection',
  'TimelineOverlayRuntimeRestartProjection',
  'TimelineOverlayRuntimeFailure',
  'TimelineOverlayRuntimeFailureKind',
  'TimelineOverlayRuntimeActionResult',
  'compose(',
  'selectProfile(',
  'setLayerVisibility(',
  'reorderLayers(',
  'snapshot(',
  'dispose(',
  'unavailable('
)
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Timeline overlay runtime missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 4. Barrel export check
# ---------------------------------------------------------------------------
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  "export 'src/streaming/timeline_overlay.dart';",
  "export 'src/streaming/timeline_overlay_runtime.dart';"
)) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public Dart contract barrel missing export: $export"
  }
}

# ---------------------------------------------------------------------------
# 5. Required-term checks in checker surface
# ---------------------------------------------------------------------------
$checkerPath = Join-Path $root 'tools/runtime_checks/timeline_overlay_runtime_contract.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw

foreach ($term in @(
  "import '../../lib/elaina.dart';",
  'DeterministicTimelineOverlayStore',
  'StreamCacheInvalidationBus',
  'DeterministicTimelineOverlayComposer',
  'TimelineOverlayBootstrap',
  'TimelineOverlayRuntimeCompositionRequest',
  'TimelineOverlayRuntimeFailureKind',
  'TimelineOverlayRuntime.unavailable',
  'dispose()',
  'DateTime.utc(2026, 6, 13, 12)'
)) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Timeline overlay runtime checker missing required term: $term"
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
  'libtorrent',
  'ffi',
  'TorrentEngine',
  'startDownload',
  'stopDownload',
  'removeTorrent',
  'BtTaskRuntime',
  'generatePlan(',
  'applyPlan(',
  'PiecePrioritySchedulerRuntime',
  'PiecePriorityPlanApplier',
  'serveBytes',
  'openRange',
  'closeStream(',
  'failStream(',
  'dart:async/zone',
  'dart:io/File',
  'dart:io/Directory',
  'Http',
  'ServerSocket',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'Anime4K',
  'VideoEnhancement',
  'AVSync',
  'AvSyncGuard',
  'CaptionRendering',
  'AdvancedCaption',
  'StorageMigration',
  'MigrationRunner',
  'Phase5'
)

foreach ($term in $runtimeForbiddenTerms) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden timeline overlay runtime boundary term '$term' found in timeline_overlay_runtime.dart"
  }
}

$runtimeTestPath = Join-Path $root 'test/streaming/timeline_overlay_runtime_test.dart'
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
  'libtorrent',
  'ffi',
  'TorrentEngine',
  'startDownload',
  'stopDownload',
  'removeTorrent',
  'BtTaskRuntime',
  'generatePlan(',
  'applyPlan(',
  'PiecePrioritySchedulerRuntime',
  'PiecePriorityPlanApplier',
  'serveBytes',
  'openRange',
  'closeStream(',
  'failStream(',
  'dart:io/File',
  'dart:io/Directory',
  'ServerSocket',
  'DiagnosticsCenter',
  'DiagnosticsEvent',
  'RssAutoDownload',
  'OnlineRule',
  'Anime4K',
  'VideoEnhancement',
  'AVSync',
  'AvSyncGuard',
  'CaptionRendering',
  'AdvancedCaption',
  'StorageMigration',
  'MigrationRunner',
  'Phase5'
)

foreach ($term in $testAndCheckerForbiddenTerms) {
  if ($runtimeTest -match [regex]::Escape($term)) {
    throw "Forbidden timeline overlay boundary term '$term' found in timeline_overlay_runtime_test.dart"
  }
  if ($checker -match [regex]::Escape($term)) {
    throw "Forbidden timeline overlay boundary term '$term' found in timeline_overlay_runtime_contract.dart"
  }
}

# ---------------------------------------------------------------------------
# 7. Scope guard: runtime imports stay on timeline overlay read-model contracts
# ---------------------------------------------------------------------------
$runtimeImports = $runtime | Select-String -Pattern '^import ' -AllMatches
$forbiddenImports = @(
  'dart:io',
  'package:flutter',
  'piece_priority_scheduler_runtime',
  'bt_task_core_runtime',
  'virtual_media_stream_runtime',
  'player_adapter',
  'playback_controller',
  'mpv',
  'vlc',
  'video_enhancement',
  'av_sync',
  'advanced_caption',
  'diagnostics_center',
  'rss_auto_download',
  'online_rule_runtime',
  'network_policy'
)
foreach ($import in $forbiddenImports) {
  if ($runtimeImports -match [regex]::Escape($import)) {
    throw "Timeline overlay runtime must not import boundary surface: $import"
  }
}

Write-Output 'Timeline overlay runtime checks passed.'

