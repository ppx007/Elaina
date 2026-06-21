$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'tools/bt_streaming_smoke_gate.dart',
  'tools/check_bt_streaming_smoke_gate.ps1',
  'test/streaming/bt_streaming_smoke_gate_test.dart',
  'docs/bt-streaming-smoke-gate.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Step 55 BT streaming smoke gate file: $file"
  }
}

$tool = Get-Content -LiteralPath (Join-Path $root 'tools/bt_streaming_smoke_gate.dart') -Raw
foreach ($term in @(
  'runBtStreamingSmokeGate',
  'BtStreamingSmokeGateResult',
  'libtorrentBtTaskRuntimeComposition',
  'VirtualMediaStreamRuntime.withDependencies',
  'fileVirtualStreamContentUriResolver',
  'FileVirtualByteSource',
  'libtorrentPiecePrioritySchedulerRuntime',
  'PiecePrioritySchedulerRuntime.balancedProfile',
  'LibtorrentEngineBackend',
  'setFilePriorities',
  'stdout.writeln'
)) {
  if ($tool -notmatch [regex]::Escape($term)) {
    throw "BT streaming smoke gate tool missing required term: $term"
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
  'HttpServer',
  'Socket',
  'WebView',
  'DiagnosticsCenter',
  'RssAutoDownloadPolicy',
  'OnlineRule',
  'TimelineOverlay'
)) {
  if ($tool -match [regex]::Escape($term)) {
    throw "Forbidden Step 55 dependency '$term' found in BT streaming smoke gate tool."
  }
}

$doc = Get-Content -LiteralPath (Join-Path $root 'docs/bt-streaming-smoke-gate.md') -Raw
foreach ($term in @(
  'Step 55',
  'non-UI',
  'BT task -> virtual stream -> byte range -> priority application',
  'LibtorrentEngineBackend',
  'FileVirtualByteSource',
  'UI Boundary'
)) {
  if ($doc -notmatch [regex]::Escape($term)) {
    throw "BT streaming smoke gate doc missing required term: $term"
  }
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'BtStreamingSmokeGate|bt_streaming_smoke_gate|LibtorrentEngineBackend|FileVirtualByteSource|PiecePrioritySchedulerRuntime'
    if ($matches) {
      throw "Step 55 BT streaming smoke gate details leaked into $path"
    }
  }
}

$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('BtStreamingSmokeGate', 'bt_streaming_smoke_gate', 'LibtorrentEngineBackend', 'FileVirtualByteSource', 'PiecePrioritySchedulerRuntime')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 55 BT streaming smoke gate detail '$term' leaked into lib/main.dart"
    }
  }
}

& flutter test (Join-Path $root 'test/streaming/bt_streaming_smoke_gate_test.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'BT streaming smoke gate focused test failed.'
}

& dart (Join-Path $root 'tools/bt_streaming_smoke_gate.dart')
if ($LASTEXITCODE -ne 0) {
  throw 'BT streaming smoke gate Dart tool failed.'
}

Write-Output 'BT streaming smoke gate checks passed.'

