$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_detail_library_seasonal.ps1')

$requiredFiles = @(
  'lib/src/foundation/storage/bt_task_storage_contracts.dart',
  'lib/src/foundation/storage/virtual_stream_storage_contracts.dart',
  'lib/src/foundation/storage/piece_priority_scheduler_storage_contracts.dart',
  'lib/src/foundation/storage/timeline_overlay_storage_contracts.dart',
  'lib/src/streaming/bt_task_core.dart',
  'lib/src/streaming/file_virtual_byte_source.dart',
  'lib/src/streaming/libtorrent_download_engine_adapter.dart',
  'lib/src/streaming/virtual_media_stream.dart',
  'lib/src/streaming/piece_priority_scheduler.dart',
  'lib/src/streaming/timeline_overlay.dart',
  'lib/src/playback/virtual_stream_playback_source.dart',
  'test/streaming/libtorrent_download_engine_adapter_test.dart',
  'test/streaming/virtual_media_stream_byte_serving_test.dart',
  'test/streaming/bt_streaming_smoke_gate_test.dart',
  'tools/bt_streaming_smoke_gate.dart',
  'tools/check_bt_streaming_smoke_gate.ps1',
  'docs/bt-streaming-smoke-gate.md',
  'docs/phase4-bt-streaming-core.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required BT streaming file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('libtorrent', 'torrent', 'BtTask', 'DownloadEngine', 'PiecePriority', 'VirtualMediaStream', 'TimelineOverlaySource')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden BT/streaming UI dependency '$term' found in $($file.FullName)"
    }
  }
}

$streamingFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/streaming') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $streamingFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $isLibtorrentAdapter = $relativePath -eq 'lib/src/streaming/libtorrent_download_engine_adapter.dart'
  $isFileByteSource = $relativePath -eq 'lib/src/streaming/file_virtual_byte_source.dart'
  $forbiddenImplTerms = @('HttpServer', 'Socket', 'ffi', 'package:flutter')
  if (-not $isFileByteSource) {
    $forbiddenImplTerms += @('dart:io', 'RandomAccessFile')
  }
  if (-not $isLibtorrentAdapter) {
    $forbiddenImplTerms += 'libtorrent'
  }
  foreach ($term in $forbiddenImplTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Streaming contract contains forbidden implementation dependency '$term' in $($file.FullName)"
    }
  }
}

$fileByteSource = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/file_virtual_byte_source.dart') -Raw
foreach ($term in @('FileVirtualByteSource', 'VirtualByteRangeSource', 'RandomAccessFile', 'fileVirtualStreamContentUriResolver')) {
  if ($fileByteSource -notmatch [regex]::Escape($term)) {
    throw "Concrete file byte source missing required term: $term"
  }
}

$libtorrentAdapter = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/libtorrent_download_engine_adapter.dart') -Raw
if ($libtorrentAdapter -notmatch [regex]::Escape("package:libtorrent_flutter/")) {
  throw 'Concrete libtorrent adapter must own the libtorrent Flutter package import.'
}
foreach ($term in @('LibtorrentPiecePriorityPlanApplier', 'PiecePriorityPlanApplier', 'applyPiecePriorityPlan', 'libtorrentPiecePrioritySchedulerRuntime')) {
  if ($libtorrentAdapter -notmatch [regex]::Escape($term)) {
    throw "Concrete libtorrent adapter missing Step 54 priority application term: $term"
  }
}

$smokeGate = Get-Content -LiteralPath (Join-Path $root 'tools/bt_streaming_smoke_gate.dart') -Raw
foreach ($term in @('runBtStreamingSmokeGate', 'BtStreamingSmokeGateResult', 'libtorrentBtTaskRuntimeComposition', 'VirtualMediaStreamRuntime.withDependencies', 'FileVirtualByteSource', 'libtorrentPiecePrioritySchedulerRuntime')) {
  if ($smokeGate -notmatch [regex]::Escape($term)) {
    throw "BT streaming smoke gate missing required Step 55 term: $term"
  }
}
foreach ($term in @('package:flutter', 'lib/src/ui', 'lib/main.dart', 'windows/', 'HttpServer', 'Socket', 'media_kit', 'libmpv', 'WebView', 'TimelineOverlay')) {
  if ($smokeGate -match [regex]::Escape($term)) {
    throw "Forbidden Step 55 smoke gate dependency '$term' found in tools/bt_streaming_smoke_gate.dart"
  }
}

$libDartFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $libDartFiles) {
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $content = Get-Content -LiteralPath $file.FullName -Raw
  if ($relativePath -ne 'lib/src/streaming/libtorrent_download_engine_adapter.dart' -and $content -match [regex]::Escape("package:libtorrent_flutter/")) {
    throw "libtorrent Flutter import leaked outside the concrete adapter: $($file.FullName)"
  }
}

$btCore = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/bt_task_core.dart') -Raw
if ($btCore -notmatch 'BtTaskSource' -or $btCore -notmatch 'BtTaskMetadata' -or $btCore -notmatch 'BtTaskFile' -or $btCore -notmatch 'DownloadEngineAdapter' -or $btCore -notmatch 'BtCapabilityMatrix' -or $btCore -notmatch 'longBackgroundDownload' -or $btCore -notmatch 'BtTaskCoreContract' -or $btCore -notmatch 'DeterministicBtTaskCore' -or $btCore -notmatch 'BtTaskFailureKind') {
  throw 'BT task core must define source, metadata, file, adapter, and capability contracts.'
}

$btStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/bt_task_storage_contracts.dart') -Raw
if ($btStorage -notmatch 'StoredBtTaskRecord' -or $btStorage -notmatch 'StoredBtTaskMetadataRecord' -or $btStorage -notmatch 'StoredBtTaskFileRecord' -or $btStorage -notmatch 'StoredBtTaskTransferSnapshotRecord' -or $btStorage -notmatch 'StoredBtTaskEventRecord' -or $btStorage -notmatch 'BtTaskStore' -or $btStorage -notmatch 'DeterministicBtTaskStore') {
  throw 'BT task storage must define task, metadata, file, transfer snapshot, event, store, and deterministic store contracts.'
}

$storageContracts = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/storage_contracts.dart') -Raw
if ($storageContracts -notmatch 'BtTaskStore get btTask' -or $storageContracts -notmatch 'VirtualMediaStreamStore get virtualMediaStream' -or $storageContracts -notmatch 'PiecePrioritySchedulerStore get piecePriorityScheduler' -or $storageContracts -notmatch 'TimelineOverlayStore get timelineOverlay') {
  throw 'Storage foundation must expose BT task, virtual stream, piece priority scheduler, and timeline overlay persistence responsibilities.'
}

$virtualStreamStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/virtual_stream_storage_contracts.dart') -Raw
foreach ($term in @('StoredVirtualMediaStreamRecord', 'StoredVirtualStreamBufferedRangeRecord', 'StoredVirtualStreamEventRecord', 'VirtualMediaStreamStore', 'DeterministicVirtualMediaStreamStore')) {
  if ($virtualStreamStorage -notmatch [regex]::Escape($term)) {
    throw "Virtual stream storage missing required contract: $term"
  }
}

$schedulerStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/piece_priority_scheduler_storage_contracts.dart') -Raw
foreach ($term in @('StoredPiecePriorityStrategyProfileRecord', 'StoredPiecePriorityPlanRecord', 'StoredPiecePriorityPlanRuleRecord', 'StoredPiecePriorityPlanApplicationEventRecord', 'PiecePrioritySchedulerStore', 'DeterministicPiecePrioritySchedulerStore')) {
  if ($schedulerStorage -notmatch [regex]::Escape($term)) {
    throw "Piece priority scheduler storage missing required contract: $term"
  }
}

$timelineStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/timeline_overlay_storage_contracts.dart') -Raw
foreach ($term in @('StoredTimelineOverlayProfileRecord', 'StoredTimelineOverlayLayerRecord', 'StoredTimelineOverlaySnapshotMetadataRecord', 'TimelineOverlayStore', 'DeterministicTimelineOverlayStore')) {
  if ($timelineStorage -notmatch [regex]::Escape($term)) {
    throw "Timeline overlay storage missing required contract: $term"
  }
}

$cacheInvalidation = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart') -Raw
foreach ($term in @('BtTaskCreated', 'BtMetadataUpdated', 'BtTaskLifecycleChanged', 'BtTaskFileSelectionChanged', 'BtTaskRemoved', 'VirtualStreamCreated', 'VirtualStreamRangeBuffered', 'VirtualStreamRangeFailed', 'VirtualStreamClosed', 'PiecePriorityPlanGenerated', 'PiecePriorityPlanApplied', 'PiecePriorityPlanRejected', 'PiecePriorityProfileChanged', 'TimelineOverlaySnapshotRefreshed', 'TimelineOverlayLayerConfigurationChanged', 'TimelineOverlayCompositionRejected')) {
  if ($cacheInvalidation -notmatch [regex]::Escape($term)) {
    throw "Cache invalidation bus missing streaming event: $term"
  }
}

$virtualStream = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/virtual_media_stream.dart') -Raw
if ($virtualStream -notmatch 'VirtualMediaStream' -or $virtualStream -notmatch 'VirtualByteRangeRequest' -or $virtualStream -notmatch 'VirtualByteRangeChunk' -or $virtualStream -notmatch 'VirtualRangeEnsureOutcome' -or $virtualStream -notmatch 'VirtualMediaStreamFailureKind' -or $virtualStream -notmatch 'DeterministicVirtualMediaStreamRegistry' -or $virtualStream -notmatch 'StreamBufferedRange' -or $virtualStream -notmatch 'VirtualMediaStreamStore|BufferedRange') {
  throw 'Virtual media stream must define deterministic range, failure, registry, and buffered range contracts tied to storage contracts.'
}

$playbackHandoff = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/playback/playback_source_handoff.dart') -Raw
if ($playbackHandoff -notmatch 'VirtualStreamSourceHandoffInput' -or $playbackHandoff -notmatch 'UnsupportedPlaybackSourceHandoffInput' -or $playbackHandoff -match 'DownloadEngine|PiecePriority|TimelineOverlay') {
  throw 'Playback source handoff must accept virtual stream source values while rejecting engine, scheduler, and timeline coupling.'
}

$scheduler = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/piece_priority_scheduler.dart') -Raw
if ($scheduler -notmatch 'PiecePriorityScheduler' -or $scheduler -notmatch 'PlaybackWindow' -or $scheduler -notmatch 'SeekTarget' -or $scheduler -notmatch 'PiecePriorityStrategyProfile' -or $scheduler -notmatch 'PiecePriorityPlanApplier' -or $scheduler -notmatch 'PiecePriorityPlanRequest' -or $scheduler -notmatch 'PiecePriorityPlanOutcome' -or $scheduler -notmatch 'PiecePriorityPlanFailureKind' -or $scheduler -notmatch 'PiecePriorityApplicationOutcome' -or $scheduler -notmatch 'DeterministicPiecePriorityScheduler') {
  throw 'Piece priority scheduler must define playback, seek, profile, deterministic planning, typed outcomes, and plan application contracts.'
}
foreach ($term in @('TimelineOverlay', 'auto-download', 'autoDownload', 'rule-source', 'ruleSource', 'Anime4K', 'diagnostics center')) {
  if ($scheduler -match [regex]::Escape($term)) {
    throw "Piece priority scheduler contains forbidden out-of-scope term '$term'"
  }
}

$timeline = Get-Content -LiteralPath (Join-Path $root 'lib/src/streaming/timeline_overlay.dart') -Raw
if ($timeline -notmatch 'TimelineOverlaySnapshot' -or $timeline -notmatch 'TimelineOverlayLayer' -or $timeline -notmatch 'TimelinePieceSegment' -or $timeline -notmatch 'TimelineOverlaySource' -or $timeline -notmatch 'TimelinePriorityWindow' -or $timeline -notmatch 'TimelineHeatValue' -or $timeline -notmatch 'TimelineOverlayCompositionOutcome' -or $timeline -notmatch 'DeterministicTimelineOverlayComposer' -or $timeline -match 'Controller') {
  throw 'Timeline overlay must remain read-only presentation data, not a controller.'
}

$playbackSource = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/virtual_stream_playback_source.dart') -Raw
if ($playbackSource -notmatch 'extends PlaybackSource' -or $playbackSource -match 'BtTask|DownloadEngine|PiecePriority') {
  throw 'Playback source must depend on virtual stream abstraction, not BT task or scheduler internals.'
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
  }
}

$phase4Files = @(
  'lib/src/streaming/bt_task_core.dart',
  'lib/src/streaming/virtual_media_stream.dart',
  'lib/src/streaming/piece_priority_scheduler.dart',
  'lib/src/streaming/timeline_overlay.dart',
  'lib/src/playback/virtual_stream_playback_source.dart',
  'docs/phase4-bt-streaming-core.md'
)
$forbiddenScopeTerms = @('auto-download', 'autoDownload', 'rule-source', 'ruleSource', 'Anime4K', 'VLC fallback', 'WebView challenge', 'DNS policy', 'diagnostics center')
foreach ($file in $phase4Files) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenScopeTerms) {
    if ($file -notlike 'docs/*' -and $content -match [regex]::Escape($term)) {
      throw "Forbidden out-of-scope term '$term' found in $file"
    }
  }
}

'BT streaming core checks passed.'
