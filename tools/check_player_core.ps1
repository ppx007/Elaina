$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_phase0_foundation.ps1')

$requiredFiles = @(
  'lib/src/playback/player_adapter.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/mpv_adapter_facade.dart',
  'lib/src/playback/track_management.dart',
  'lib/src/domain/playback/playback_controller.dart',
  'lib/src/domain/playback/playback_source_handoff.dart',
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
  'package:celesteria/celesteria.dart'
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

$frameworkNeutralPlaybackContracts = @(
  'lib/src/domain/playback/playback_controller.dart',
  'lib/src/domain/playback/playback_source_handoff.dart',
  'lib/src/ui/playback/playback_page_contract.dart'
)
foreach ($file in $frameworkNeutralPlaybackContracts) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  if ($content -match [regex]::Escape('package:flutter') -or $content -match [regex]::Escape('dart:ui')) {
    throw "Framework-neutral playback contract must not import Flutter: $path"
  }
}

$publicBarrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($publicBarrel.Contains('flutter_playback_shell.dart')) {
  throw 'Public Dart contract barrel must not export the Flutter playback shell.'
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

$nonUiLayerPaths = @(
  'lib/src/domain',
  'lib/src/playback',
  'lib/src/provider',
  'lib/src/foundation/gateway',
  'lib/src/foundation/storage',
  'lib/src/streaming',
  'lib/src/network'
)
foreach ($layerPath in $nonUiLayerPaths) {
  $fullPath = Join-Path $root $layerPath
  if (-not (Test-Path -LiteralPath $fullPath)) {
    continue
  }
  $dartFiles = Get-ChildItem -LiteralPath $fullPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $dartFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match [regex]::Escape('package:flutter') -or $content -match [regex]::Escape('dart:ui')) {
      throw "Non-UI layer must not import Flutter: $($file.FullName)"
    }
    if ($content.Contains('src/ui/playback/flutter_playback_shell.dart')) {
      throw "Non-UI layer must not import Flutter playback shell: $($file.FullName)"
    }
    if ($content.Contains('../../ui/playback/flutter_playback_shell.dart') -or $content.Contains('../ui/playback/flutter_playback_shell.dart')) {
      throw "Non-UI layer must not import Flutter playback shell: $($file.FullName)"
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

$playbackSourceHandoffPath = Join-Path $root 'lib/src/domain/playback/playback_source_handoff.dart'
$playbackSourceHandoffContent = Get-Content -LiteralPath $playbackSourceHandoffPath -Raw
$forbiddenPlaybackSourceHandoffTerms = @(
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
  'native player',
  'online_rule_runtime',
  'platform channel',
  'BT',
  'bt',
  'Bangumi',
  'Dandanplay',
  'RSS',
  'Anime4K',
  'danmaku',
  'diagnostics'
)
foreach ($term in $forbiddenPlaybackSourceHandoffTerms) {
  if ($playbackSourceHandoffContent -match [regex]::Escape($term)) {
    throw "Forbidden playback source handoff dependency '$term' found in $playbackSourceHandoffPath"
  }
}

$mediaLibraryPath = Join-Path $root 'lib/src/domain/media/media_library.dart'
$mediaLibraryContent = Get-Content -LiteralPath $mediaLibraryPath -Raw
$requiredMediaScannerTerms = @(
  'enum MediaScanFailureKind',
  'final class NormalizedMediaScanScope',
  'final class MediaScanScopeNormalizationResult',
  'MediaScanScopeNormalizationResult normalizeMediaScanScope',
  'final class DeterministicMediaLibraryScanner implements MediaLibraryScanner',
  'final class MediaScanCancelled extends MediaScanEvent',
  'abstract interface class MediaLibraryCatalogRepository',
  'abstract interface class MediaBatchImportContract',
  'final class DeterministicMediaLibraryCatalogRepository implements MediaLibraryCatalogRepository',
  'final class DeterministicPlaybackHistoryStore implements PlaybackHistoryStore',
  'final class DeterministicProviderBindingStore implements ProviderBindingStore'
)
foreach ($term in $requiredMediaScannerTerms) {
  if ($mediaLibraryContent -notmatch [regex]::Escape($term)) {
    throw "Media library scanner contract missing required term: $term"
  }
}

$forbiddenMediaScannerDependencyTerms = @(
  '../../playback/',
  '../playback/',
  'src/playback/',
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
  'dart:io',
  'dart:ui',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'online_rule_runtime',
  'platform channel'
)
foreach ($term in $forbiddenMediaScannerDependencyTerms) {
  if ($mediaLibraryContent -match [regex]::Escape($term)) {
    throw "Forbidden local media scanner dependency '$term' found in $mediaLibraryPath"
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
