$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
& (Join-Path $PSScriptRoot 'check_detail_library_seasonal.ps1')

$requiredFiles = @(
  'lib/src/domain/detail/video_detail.dart',
  'lib/src/domain/detail/video_detail_runtime.dart',
  'lib/src/domain/detail/video_detail_storage_adapters.dart',
  'lib/src/domain/detail/video_detail_bootstrap.dart',
  'lib/src/ui/detail/video_detail_page_contract.dart',
  'test/domain/detail/video_detail_runtime_test.dart',
  'docs/video-detail-runtime-implementation.md',
  'tools/runtime_checks/video_detail_runtime_contract.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required video detail runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/domain/detail/video_detail.dart',
  'lib/src/domain/detail/video_detail_runtime.dart'
)

$forbiddenRuntimeTerms = @(
  'package:flutter',
  'dart:ui',
  'ProviderGateway',
  'BangumiProviderRuntime',
  'BangumiAuthSession',
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
  'native player'
)

foreach ($file in $runtimeFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenRuntimeTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 13 video detail runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/detail/video_detail_runtime.dart') -Raw
foreach ($term in @(
  'VideoDetailRuntime',
  'VideoDetailRuntimeSnapshot',
  'VideoDetailRuntimeFailureKind',
  'DeterministicVideoDetailRepository',
  'DeterministicVideoDetailActionHandler',
  'PlaybackSourceHandoffContract',
  'HistoryRecorded',
  'BindingChanged',
  'BangumiVideoDetailSeed'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Video detail runtime missing required term: $term"
  }
}

$storageAdapters = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/detail/video_detail_storage_adapters.dart') -Raw
foreach ($term in @(
  'StorageBackedVideoDetailRepository',
  'storageBackedVideoDetailBootstrap',
  'StorageFoundation',
  'StorageMediaLibraryCatalogRepository',
  'StoragePlaybackHistoryStore',
  'StorageProviderBindingStore',
  'VideoDetailBootstrap.withDependencies',
  'VideoDetailActionHandler',
  'PlaybackSourceHandoffContract'
)) {
  if ($storageAdapters -notmatch [regex]::Escape($term)) {
    throw "Storage-backed video detail adapter missing required term: $term"
  }
}
foreach ($term in @(
  'package:flutter',
  'dart:ui',
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
  'DownloadEngineAdapter',
  'RssEngine',
  'SeasonalIndexer',
  'BtTask',
  'BitTorrent',
  'DiagnosticsCenter'
)) {
  if ($storageAdapters -match [regex]::Escape($term)) {
    throw "Forbidden storage-backed video detail dependency '$term' found in video_detail_storage_adapters.dart"
  }
}

$bootstrap = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/detail/video_detail_bootstrap.dart') -Raw
foreach ($term in @('VideoDetailBootstrap', 'videoDetailRuntimeForbiddenTerms', 'videoDetailRuntimeRequiredTerms')) {
  if ($bootstrap -notmatch [regex]::Escape($term)) {
    throw "Video detail bootstrap missing required term: $term"
  }
}

$detail = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/detail/video_detail.dart') -Raw
foreach ($term in @('VideoDetailActionResult', 'VideoDetailActionResultKind', 'LocalMediaIdentity', 'Future<VideoDetailActionResult>')) {
  if ($detail -notmatch [regex]::Escape($term)) {
    throw "Video detail contract missing required runtime/action term: $term"
  }
}

$ui = Get-Content -LiteralPath (Join-Path $root 'lib/src/ui/detail/video_detail_page_contract.dart') -Raw
foreach ($term in @('Future<VideoDetailActionResult>', 'VideoDetailPageContract', 'VideoDetailController')) {
  if ($ui -notmatch [regex]::Escape($term)) {
    throw "Video detail UI contract missing required framework-neutral action term: $term"
  }
}
foreach ($term in @('package:flutter', 'dart:ui', 'BangumiProviderRuntime', 'ProviderGateway', 'StorageFoundation', 'mpv', 'vlc', 'native player')) {
  if ($ui -match [regex]::Escape($term)) {
    throw "Forbidden concrete UI dependency '$term' found in video detail page contract."
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/domain/detail/video_detail.dart',
  'src/domain/detail/video_detail_runtime.dart',
  'src/domain/detail/video_detail_storage_adapters.dart',
  'src/domain/detail/video_detail_bootstrap.dart',
  'src/ui/detail/video_detail_page_contract.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing video detail runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/detail/flutter_video_detail")) {
  throw 'Public Dart contract barrel must not export concrete Flutter video detail pages.'
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'StorageBackedVideoDetailRepository|storageBackedVideoDetailBootstrap|SqliteStorageFoundation|package:sqlite3'
    if ($matches) {
      throw "Step 43 concrete video detail details leaked into $path"
    }
  }
}
$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('StorageBackedVideoDetailRepository', 'storageBackedVideoDetailBootstrap', 'SqliteStorageFoundation', 'package:sqlite3')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 43 concrete video detail detail '$term' leaked into lib/main.dart"
    }
  }
}

& dart (Join-Path $root 'tools/runtime_checks/video_detail_runtime_contract.dart')

Write-Output 'Video detail runtime checks passed.'

