$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
& (Join-Path $PSScriptRoot 'check_phase0_foundation.ps1')

$requiredFiles = @(
  'lib/src/foundation/storage/sqlite_storage_foundation.dart',
  'test/foundation/sqlite_storage_foundation_test.dart',
  'tools/sqlite_storage_foundation_check.dart',
  'docs/sqlite-storage-foundation.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required concrete storage file: $file"
  }
}

$sqliteStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/sqlite_storage_foundation.dart') -Raw
foreach ($term in @('SqliteStorageFoundation', 'SqliteMetadataStore', 'SqliteSettingsStore', 'SqliteBlobCacheStore', 'SqliteMediaLibraryStore', 'SqlitePlaybackHistoryRepository', 'SqliteProviderBindingRepository', 'SqliteSubtitleCacheStore', 'sqlite3.open', 'schema_version')) {
  if ($sqliteStorage -notmatch [regex]::Escape($term)) {
    throw "SQLite storage foundation missing required term: $term"
  }
}
foreach ($term in @('package:flutter', 'package:media_kit', 'libmpv', 'HttpClient(', 'WebViewController', 'DownloadEngineAdapter', 'package:drift', 'package:sqflite')) {
  if ($sqliteStorage -match [regex]::Escape($term)) {
    throw "SQLite storage foundation contains forbidden dependency: $term"
  }
}

$deterministic = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/deterministic_storage_foundation.dart') -Raw
foreach ($term in @('package:sqlite3', 'SqliteStorageFoundation', 'sqlite3.open', 'schema_version')) {
  if ($deterministic -match [regex]::Escape($term)) {
    throw "Deterministic storage foundation must remain SQLite-free: $term"
  }
}

$forbiddenLayerRoots = @(
  'lib/src/ui',
  'lib/src/domain',
  'lib/src/playback',
  'lib/src/provider',
  'lib/src/streaming',
  'lib/src/network'
)
foreach ($relativeRoot in $forbiddenLayerRoots) {
  $path = Join-Path $root $relativeRoot
  if (-not (Test-Path -LiteralPath $path)) {
    continue
  }
  $files = Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($term in @('package:sqlite3', 'SqliteStorageFoundation', 'sqlite3.open', 'select * from', 'schema_version')) {
      if ($content -match [regex]::Escape($term)) {
        throw "SQLite implementation detail leaked into $relativeRoot`: $($file.FullName) contains $term"
      }
    }
  }
}

'Concrete SQLite storage foundation checks passed.'

