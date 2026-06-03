$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_phase0_foundation.ps1')

$requiredFiles = @(
  'lib/src/playback/player_adapter.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/mpv_adapter_facade.dart',
  'lib/src/playback/track_management.dart',
  'lib/src/domain/playback/playback_controller.dart',
  'lib/src/domain/playback/playback_state.dart',
  'lib/src/ui/playback/playback_page_contract.dart',
  'docs/phase1-player-core.md',
  'docs/next-change-acg-data-experience.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required player-core file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('mpv', 'libmpv', 'media-kit', 'media_kit', 'vlc', 'exoplayer', 'avplayer', 'native player')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden playback UI concrete dependency '$term' found in $($file.FullName)"
    }
  }
}

$uiPlaybackPath = Join-Path $root 'lib/src/ui/playback'
$forbiddenUiPlaybackImports = @(
  'src/playback/mpv_adapter_facade.dart',
  'src/playback/player_adapter.dart',
  'src/playback/fallback_adapter.dart',
  'src/provider/',
  'src/gateway/',
  'src/storage/',
  'src/streaming/',
  'src/network/',
  'package:celesteria/celesteria.dart',
  'package:flutter',
  'dart:ui'
)
$uiPlaybackFiles = Get-ChildItem -LiteralPath $uiPlaybackPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiPlaybackFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiPlaybackImports) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden playback UI import or dependency '$term' found in $($file.FullName)"
    }
  }
}

$domainPlaybackPaths = @(
  'lib/src/domain',
  'lib/src/playback'
)
foreach ($layerPath in $domainPlaybackPaths) {
  $fullPath = Join-Path $root $layerPath
  $dartFiles = Get-ChildItem -LiteralPath $fullPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $dartFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content.Contains('src/ui')) {
      throw "Domain/Playback file must not import UI layer: $($file.FullName)"
    }
    if ($content.Contains('../../ui') -or $content.Contains('../ui')) {
      throw "Domain/Playback file must not import UI layer: $($file.FullName)"
    }
  }
}

$playbackStatePath = Join-Path $root 'lib/src/domain/playback/playback_state.dart'
$playbackStateContent = Get-Content -LiteralPath $playbackStatePath -Raw
$forbiddenPlaybackStateTerms = @(
  '../../playback/',
  '../playback/',
  'src/playback/',
  '../../provider/',
  '../provider/',
  'src/provider/',
  '../../gateway/',
  '../gateway/',
  'src/gateway/',
  '../../storage/',
  '../storage/',
  'src/storage/',
  '../../streaming/',
  '../streaming/',
  'src/streaming/',
  '../../network/',
  '../network/',
  'src/network/',
  'package:flutter',
  'dart:ui',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player'
)
foreach ($term in $forbiddenPlaybackStateTerms) {
  if ($playbackStateContent -match [regex]::Escape($term)) {
    throw "Forbidden playback state dependency '$term' found in $playbackStatePath"
  }
}

$mpvFacade = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/mpv_adapter_facade.dart') -Raw
if ($mpvFacade -notmatch 'PlaybackCapabilityMatrix\.unsupported') {
  throw 'MPV facade must expose an unsupported capability matrix when no binding is available.'
}
if ($mpvFacade -notmatch 'adapterUnavailable') {
  throw 'MPV facade must normalize missing binding failures as adapterUnavailable.'
}
if ($mpvFacade -notmatch 'abstract interface class MpvAdapterBinding') {
  throw 'MPV facade must define a native binding interface before advertising supported playback.'
}
if ($mpvFacade -notmatch 'return binding\.load\(source\)' -or $mpvFacade -notmatch 'return binding\.play\(\)') {
  throw 'MPV facade must delegate available binding operations instead of returning synthetic success.'
}
if ($mpvFacade -match 'MpvAdapterBindingState\.available') {
  throw 'MPV facade must not expose an availability state without an injected binding delegate.'
}

& dart (Join-Path $root 'tools/player_core_runtime_check.dart')

'Player core checks passed.'
