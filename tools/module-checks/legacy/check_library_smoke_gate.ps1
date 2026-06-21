$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'tools/library_smoke_gate.dart',
  'tools/check_library_smoke_gate.ps1',
  'test/domain/media/library_smoke_gate_test.dart',
  'docs/library-smoke-gate.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Step 45 library smoke gate file: $file"
  }
}

$tool = Get-Content -LiteralPath (Join-Path $root 'tools/library_smoke_gate.dart') -Raw
foreach ($term in @(
  'runLibrarySmokeGate',
  'LibrarySmokeGateResult',
  'storageBackedMediaLibraryBootstrap',
  'storageBackedVideoDetailBootstrap',
  'PlaybackHistoryRecorder',
  'PlaybackStateSnapshot',
  'LocalFileMediaLibraryScanner',
  'SqliteStorageFoundation.open',
  'VideoDetailActionResult',
  'PlaybackSourceHandoffResult',
  'HistoryRecorded',
  'BindingChanged',
  'stdout.writeln'
)) {
  if ($tool -notmatch [regex]::Escape($term)) {
    throw "Library smoke gate tool missing required term: $term"
  }
}

foreach ($term in @(
  'package:flutter',
  'dart:ui',
  'lib/src/ui',
  'lib/main.dart',
  'windows/',
  'media_kit',
  'libmpv',
  'MpvPlayer',
  'Vlc',
  'BangumiApiClient',
  'DandanplayApiClient',
  'OpenSubtitlesApiClient',
  'HttpClient',
  'WebView',
  'DownloadEngineAdapter',
  'BtTask',
  'RssEngine',
  'OnlineRule',
  'DiagnosticsCenter'
)) {
  if ($tool -match [regex]::Escape($term)) {
    throw "Forbidden Step 45 dependency '$term' found in library smoke gate tool."
  }
}

$doc = Get-Content -LiteralPath (Join-Path $root 'docs/library-smoke-gate.md') -Raw
foreach ($term in @(
  'Step 45',
  'scan -> import -> detail -> playback handoff -> history -> continue-watching replay',
  'non-UI',
  'storageBackedMediaLibraryBootstrap',
  'storageBackedVideoDetailBootstrap',
  'PlaybackHistoryRecorder',
  'UI Boundary'
)) {
  if ($doc -notmatch [regex]::Escape($term)) {
    throw "Library smoke gate doc missing required term: $term"
  }
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'LibrarySmokeGate|library_smoke_gate|storageBackedMediaLibraryBootstrap|storageBackedVideoDetailBootstrap|SqliteStorageFoundation|LocalFileMediaLibraryScanner'
    if ($matches) {
      throw "Step 45 library smoke gate details leaked into $path"
    }
  }
}

$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('LibrarySmokeGate', 'library_smoke_gate', 'storageBackedMediaLibraryBootstrap', 'storageBackedVideoDetailBootstrap', 'SqliteStorageFoundation', 'LocalFileMediaLibraryScanner')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 45 library smoke gate detail '$term' leaked into lib/main.dart"
    }
  }
}

& flutter test (Join-Path $root 'test/domain/media/library_smoke_gate_test.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'Library smoke gate focused test failed.'
}

& dart (Join-Path $root 'tools/library_smoke_gate.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'Library smoke gate Dart tool failed.'
}

Write-Output 'Library smoke gate checks passed.'

