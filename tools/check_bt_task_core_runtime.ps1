$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_bt_streaming_core.ps1')

$requiredFiles = @(
  'lib/src/streaming/bt_task_core.dart',
  'lib/src/streaming/bt_task_core_runtime.dart',
  'lib/src/foundation/storage/bt_task_storage_contracts.dart',
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'test/streaming/bt_task_core_runtime_test.dart',
  'tools/bt_task_core_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required BT task core runtime file: $file"
  }
}

$runtimePath = Join-Path $root 'lib/src/streaming/bt_task_core_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

foreach ($term in @(
  'BtTaskCoreRuntime',
  'BtTaskCoreBootstrap',
  'BtTaskCoreRuntimeSnapshot',
  'BtTaskCoreRuntimeFailureKind',
  'BtTaskCoreRuntimeActionResult',
  'BtTaskCoreRuntimeObserver',
  'BtTaskProjection',
  'BtTaskMetadataProjection',
  'BtTaskFileProjection',
  'BtTaskRestartProjection',
  'restartReconciliation',
  'observeStatus',
  'observeEvents'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "BT task core runtime missing required term: $term"
  }
}

foreach ($term in @(
  'package:flutter',
  'dart:ui',
  'dart:io',
  'HttpServer',
  'Socket',
  'libtorrent',
  'ffi',
  'RandomAccessFile',
  'RangeServer',
  'PipeServer',
  'PiecePriorityScheduler',
  'TimelineOverlay',
  'RssAutoDownload',
  'OnlineRule',
  'DiagnosticsCenter',
  'Widget',
  'SQLite',
  'sqflite',
  'mpv',
  'vlc',
  'native player'
)) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden Step 18 runtime dependency '$term' found in bt_task_core_runtime.dart"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/streaming/bt_task_core_runtime.dart';")) {
  throw 'Public Dart contract barrel missing BT task core runtime export.'
}

& dart (Join-Path $root 'tools/bt_task_core_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw "BT task core runtime Dart checker failed with exit code $LASTEXITCODE"
}

Write-Output 'BT task core runtime checks passed.'
