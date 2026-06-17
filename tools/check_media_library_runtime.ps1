$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_video_detail_runtime.ps1')

$requiredFiles = @(
  'lib/src/domain/media/media_library.dart',
  'lib/src/domain/media/media_library_runtime.dart',
  'lib/src/domain/media/playback_history_integration.dart',
  'lib/src/domain/media/local_file_media_scanner.dart',
  'lib/src/domain/media/media_library_storage_adapters.dart',
  'test/domain/media/playback_history_integration_test.dart',
  'test/domain/media/media_library_concrete_runtime_test.dart',
  'test/domain/media/media_library_runtime_test.dart',
  'docs/playback-history-integration.md',
  'tools/media_library_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required media library runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/domain/media/media_library.dart',
  'lib/src/domain/media/media_library_runtime.dart',
  'lib/src/domain/media/playback_history_integration.dart'
)

$forbiddenRuntimeTerms = @(
  'package:flutter',
  'dart:ui',
  'ProviderGateway',
  'src/foundation/storage',
  '../../foundation/storage',
  '../../storage',
  '../storage',
  '../../network',
  '../network',
  '../../streaming',
  '../streaming',
  '../../domain/rss',
  '../../domain/seasonal',
  '../../provider/rss',
  '../../provider/subtitle',
  'SubtitleProvider',
  'RssEngine',
  'SeasonalIndexer',
  'BtTask',
  'BitTorrent',
  'online_rule',
  'OnlineRule',
  'HttpClient',
  'WebView',
  'DiagnosticsCenter',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'File(',
  'Directory(',
  'dart:io',
  'SQLite',
  'sqflite'
)

foreach ($file in $runtimeFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenRuntimeTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 14 media library runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/media/media_library_runtime.dart') -Raw
foreach ($term in @(
  'MediaLibraryRuntime',
  'MediaLibraryBootstrap',
  'MediaLibraryRuntimeSnapshot',
  'MediaLibraryRuntimeFailureKind',
  'MediaLibraryActionResult',
  'MediaLibraryCatalogItemState',
  'PlaybackSourceHandoffContract',
  'CacheInvalidationBus',
  'MediaLibraryScanner',
  'MediaBatchImportContract',
  'PlaybackHistoryStore',
  'ProviderBindingStore',
  'MediaLibraryItemChanged',
  'HistoryRecorded',
  'BindingChanged'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Media library runtime missing required term: $term"
  }
}

$historyIntegration = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/media/playback_history_integration.dart') -Raw
foreach ($term in @(
  'PlaybackHistoryRecorder',
  'PlaybackHistoryRecordingResult',
  'PlaybackHistoryRecordingObserver',
  'PlaybackStateSnapshot',
  'PlaybackStateObservable',
  'MediaLibraryCatalogRepository',
  'PlaybackHistoryStore',
  'HistoryRecorded',
  'playbackHistoryRecordableStatuses'
)) {
  if ($historyIntegration -notmatch [regex]::Escape($term)) {
    throw "Playback history integration missing required term: $term"
  }
}

$localScanner = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/media/local_file_media_scanner.dart') -Raw
foreach ($term in @(
  'LocalFileMediaLibraryScanner',
  'dart:io',
  'Directory.fromUri',
  'FileSystemEntity',
  'MediaScanCandidateDiscovered',
  'MediaScanCompleted',
  'MediaScanFailureKind.discoveryFailed'
)) {
  if ($localScanner -notmatch [regex]::Escape($term)) {
    throw "Local file media scanner missing required term: $term"
  }
}
foreach ($term in @(
  'package:flutter',
  'package:sqlite3',
  'sqlite3',
  'select ',
  'insert ',
  'update ',
  'delete ',
  'ProviderGateway',
  'HttpClient',
  'WebView',
  'Mpv',
  'libmpv',
  'media_kit',
  'DownloadEngineAdapter'
)) {
  if ($localScanner -match [regex]::Escape($term)) {
    throw "Forbidden local scanner dependency '$term' found in local_file_media_scanner.dart"
  }
}

$storageAdapters = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/media/media_library_storage_adapters.dart') -Raw
foreach ($term in @(
  'StorageMediaLibraryCatalogRepository',
  'StoragePlaybackHistoryStore',
  'StorageProviderBindingStore',
  'StorageMediaBatchImportContract',
  'storageBackedMediaLibraryBootstrap',
  'StorageFoundation',
  'MediaLibraryStore',
  'PlaybackHistoryRepository',
  'ProviderBindingRepository'
)) {
  if ($storageAdapters -notmatch [regex]::Escape($term)) {
    throw "Storage-backed media library adapter missing required term: $term"
  }
}
foreach ($term in @(
  'package:flutter',
  'package:sqlite3',
  'sqlite3',
  'Database',
  'ResultSet',
  'select ',
  'insert ',
  'update ',
  'delete ',
  'HttpClient',
  'WebView',
  'Mpv',
  'libmpv',
  'media_kit',
  'DownloadEngineAdapter'
)) {
  if ($storageAdapters -match [regex]::Escape($term)) {
    throw "Forbidden storage adapter dependency '$term' found in media_library_storage_adapters.dart"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/domain/media/media_library.dart',
  'src/domain/media/media_library_runtime.dart',
  'src/domain/media/playback_history_integration.dart',
  'src/domain/media/local_file_media_scanner.dart',
  'src/domain/media/media_library_storage_adapters.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing media library runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/media")) {
  throw 'Public Dart contract barrel must not export concrete media library UI pages.'
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'LocalFileMediaLibraryScanner|StorageMediaLibraryCatalogRepository|SqliteStorageFoundation|package:sqlite3|dart:io'
    if ($matches) {
      throw "Step 42 concrete media library details leaked into $path"
    }
  }
}
$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('LocalFileMediaLibraryScanner', 'StorageMediaLibraryCatalogRepository', 'SqliteStorageFoundation', 'package:sqlite3')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 42 concrete media library detail '$term' leaked into lib/main.dart"
    }
  }
}

& dart (Join-Path $root 'tools/media_library_runtime_check.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'Media library runtime smoke check failed.'
}

Write-Output 'Media library runtime checks passed.'
