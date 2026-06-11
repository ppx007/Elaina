$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  'lib/src/streaming/virtual_media_stream.dart',
  'lib/src/streaming/virtual_media_stream_runtime.dart',
  'lib/src/domain/playback/playback_source_handoff.dart',
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/virtual_stream_storage_contracts.dart',
  'test/streaming/virtual_media_stream_runtime_test.dart',
  'test/domain/playback/playback_source_handoff_test.dart',
  'tools/virtual_media_stream_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required virtual media stream runtime file: $file"
  }
}

$runtimePath = Join-Path $root 'lib/src/streaming/virtual_media_stream_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

foreach ($term in @(
  'VirtualMediaStreamRuntime',
  'VirtualMediaStreamBootstrap',
  'VirtualMediaStreamSnapshot',
  'VirtualMediaStreamRuntimeActionResult',
  'VirtualStreamRestartProjection',
  'VirtualStreamRestartDisposition',
  'createStream(',
  'ensureRange(',
  'closeStream(',
  'failStream(',
  'restartReconciliation('
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Virtual media stream runtime missing required term: $term"
  }
}

foreach ($term in @(
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
  'PiecePriorityScheduler',
  'TimelineOverlay',
  'RssAutoDownload',
  'OnlineRule',
  'DiagnosticsCenter',
  'Widget',
  'package:flutter',
  'HttpClient'
)) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Forbidden Step 19 runtime dependency '$term' found in virtual_media_stream_runtime.dart"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/streaming/virtual_media_stream_runtime.dart';")) {
  throw 'Public Dart contract barrel missing virtual media stream runtime export.'
}

& dart (Join-Path $root 'tools/virtual_media_stream_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Virtual media stream runtime Dart checker failed with exit code $LASTEXITCODE"
}

Write-Output 'Virtual media stream runtime checks passed.'
