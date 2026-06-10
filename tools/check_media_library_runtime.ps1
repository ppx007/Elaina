$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_video_detail_runtime.ps1')

$requiredFiles = @(
  'lib/src/domain/media/media_library.dart',
  'lib/src/domain/media/media_library_runtime.dart',
  'test/domain/media/media_library_runtime_test.dart',
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
  'lib/src/domain/media/media_library_runtime.dart'
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

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/domain/media/media_library.dart',
  'src/domain/media/media_library_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing media library runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/media")) {
  throw 'Public Dart contract barrel must not export concrete media library UI pages.'
}

& dart (Join-Path $root 'tools/media_library_runtime_check.dart')

Write-Output 'Media library runtime checks passed.'
