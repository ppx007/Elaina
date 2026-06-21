$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'lib/src/streaming/virtual_media_stream.dart',
  'lib/src/streaming/virtual_media_stream_runtime.dart',
  'lib/src/streaming/file_virtual_byte_source.dart',
  'lib/src/domain/playback/playback_source_handoff.dart',
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/storage/virtual_stream_storage_contracts.dart',
  'test/streaming/virtual_media_stream_runtime_test.dart',
  'test/streaming/virtual_media_stream_byte_serving_test.dart',
  'test/domain/playback/playback_source_handoff_test.dart',
  'tools/runtime_checks/virtual_media_stream_runtime_contract.dart'
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
  'openRange(',
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

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/streaming/virtual_media_stream_runtime.dart';")) {
  throw 'Public Dart contract barrel missing virtual media stream runtime export.'
}

if ($barrel -notmatch [regex]::Escape("export 'src/streaming/file_virtual_byte_source.dart';")) {
  throw 'Public Dart contract barrel missing concrete virtual file byte source export.'
}

$fileByteSource = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/file_virtual_byte_source.dart') -Raw
foreach ($term in @(
  'FileVirtualByteSource',
  'VirtualByteRangeSource',
  'RandomAccessFile',
  'fileVirtualStreamContentUriResolver'
)) {
  if ($fileByteSource -notmatch [regex]::Escape($term)) {
    throw "Concrete virtual file byte source missing required term: $term"
  }
}

& dart (Join-Path $root 'tools/runtime_checks/virtual_media_stream_runtime_contract.dart')
if ($LASTEXITCODE -ne 0) {
  throw "Virtual media stream runtime Dart checker failed with exit code $LASTEXITCODE"
}

Write-Output 'Virtual media stream runtime checks passed.'

