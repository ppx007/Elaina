$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. Required file presence
# ---------------------------------------------------------------------------
$requiredFiles = @(
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/piece_priority_scheduler_storage_contracts.dart',
  'lib/src/streaming/piece_priority_scheduler.dart',
  'lib/src/streaming/piece_priority_scheduler_runtime.dart',
  'lib/src/streaming/bt_task_core.dart',
  'lib/src/streaming/virtual_media_stream.dart',
  'test/streaming/piece_priority_scheduler_contract_test.dart',
  'test/streaming/piece_priority_scheduler_runtime_test.dart',
  'tools/piece_priority_scheduler_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $file"
  }
}

# ---------------------------------------------------------------------------
# 2. Dart smoke check
# ---------------------------------------------------------------------------
& dart (Join-Path $root 'tools/piece_priority_scheduler_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Piece priority scheduler runtime Dart checker failed with exit code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# 3. Required-term checks in runtime surface
# ---------------------------------------------------------------------------
$runtimePath = Join-Path $root 'lib/src/streaming/piece_priority_scheduler_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
  'PiecePrioritySchedulerBootstrap',
  'PiecePrioritySchedulerRuntime',
  'PiecePrioritySchedulerSnapshot',
  'PiecePriorityProfileProjection',
  'PiecePriorityGeneratedPlanSummary',
  'PiecePriorityRuleProjection',
  'PiecePriorityApplicationProjection',
  'PiecePriorityPlanningFailureProjection',
  'PiecePriorityRuntimeFailure',
  'PiecePriorityRuntimeFailureKind',
  'PiecePriorityProfileSelectionOutcome',
  'PiecePriorityPlanLookupOutcome',
  'PiecePrioritySnapshotOutcome',
  'balancedProfile',
  'selectProfile(',
  'lookupPlan(',
  'snapshot(',
  'planWithProfileId(',
  'applyPlan(',
  'dispose('
)
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Piece priority scheduler runtime missing required term: $term"
  }
}

# ---------------------------------------------------------------------------
# 4. Barrel export check
# ---------------------------------------------------------------------------
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  "export 'src/streaming/piece_priority_scheduler.dart';",
  "export 'src/streaming/piece_priority_scheduler_runtime.dart';"
)) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public Dart contract barrel missing export: $export"
  }
}

# ---------------------------------------------------------------------------
# 5. Scope guard: forbidden Step 21+ terms in runtime surface
# ---------------------------------------------------------------------------
$forbiddenRuntimeTerms = @(
  'dart:io',
  'HttpServer',
  'Socket',
  'RandomAccessFile',
  'PipeServer',
  'RangeServer',
  'libtorrent',
  'ffi',
  'mpv',
  'vlc',
  'media-kit',
  'platform channel',
  'TimelineOverlay',
  'RssAutoDownload',
  'OnlineRule',
  'DiagnosticsCenter',
  'Widget',
  'package:flutter',
  'HttpClient',
  'VideoEnhancement',
  'AvSyncGuard',
  'CaptionRendering',
  'FallbackAdapter',
  'HeatMap',
  'MarkerComposer',
  'OverlayComposer',
  'TimelineUI'
)
foreach ($term in $forbiddenRuntimeTerms) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden Step 21+ dependency '$term' found in piece_priority_scheduler_runtime.dart"
  }
}

# ---------------------------------------------------------------------------
# 6. Scope guard: forbidden terms in test surface
# ---------------------------------------------------------------------------
$runtimeTestPath = Join-Path $root 'test/streaming/piece_priority_scheduler_runtime_test.dart'
$runtimeTest = Get-Content -LiteralPath $runtimeTestPath -Raw

# Test files may import flutter_test; reject only concrete UI/runtime imports.
$forbiddenTestTerms = @(
  'dart:io',
  'HttpServer',
  'Socket',
  'RandomAccessFile',
  'libtorrent',
  'ffi',
  'mpv',
  'vlc',
  'media-kit',
  'platform channel',
  'package:flutter/material',
  'package:flutter/widgets',
  'package:flutter/cupertino',
  'package:flutter/services',
  'HttpClient',
  'TimelineOverlay',
  'HeatMap',
  'MarkerComposer',
  'OverlayComposer',
  'VideoEnhancement',
  'AvSyncGuard',
  'CaptionRendering',
  'FallbackAdapter',
  'RssAutoDownload',
  'OnlineRule',
  'DiagnosticsCenter'
)
foreach ($term in $forbiddenTestTerms) {
  if ($runtimeTest -match [regex]::Escape($term)) {
    throw "Forbidden Step 21+ dependency '$term' found in piece_priority_scheduler_runtime_test.dart"
  }
}

# ---------------------------------------------------------------------------
# 7. Scope guard: forbidden terms in Dart checker surface
# ---------------------------------------------------------------------------
$checkerPath = Join-Path $root 'tools/piece_priority_scheduler_runtime_check.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw

foreach ($term in $forbiddenTestTerms) {
  if ($checker -match [regex]::Escape($term)) {
    throw "Forbidden Step 21+ dependency '$term' found in piece_priority_scheduler_runtime_check.dart"
  }
}

# ---------------------------------------------------------------------------
# 8. Scope guard: runtime must not import unrelated later-phase surfaces
# ---------------------------------------------------------------------------
$runtimeImports = $runtime | Select-String -Pattern "^import " -AllMatches
$forbiddenImports = @(
  'video_enhancement',
  'av_sync',
  'advanced_caption',
  'fallback_adapter',
  'rss_auto_download',
  'online_rule_runtime',
  'diagnostics_center',
  'timeline_overlay',
  'network_policy'
)
foreach ($import in $forbiddenImports) {
  if ($runtimeImports -match [regex]::Escape($import)) {
    throw "Runtime must not import later-phase surface: $import"
  }
}

Write-Output 'Piece priority scheduler runtime checks passed.'
