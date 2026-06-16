$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_phase0_foundation.ps1')

$requiredFiles = @(
  'lib/src/playback/player_adapter.dart',
  'lib/src/playback/capability_matrix.dart',
  'lib/src/playback/deterministic_mpv_binding.dart',
  'lib/src/playback/media_kit_mpv_binding.dart',
  'lib/src/playback/mpv_adapter_facade.dart',
  'lib/src/playback/track_management.dart',
  'lib/src/playback/player_runtime_composition.dart',
  'lib/src/domain/playback/playback_controller.dart',
  'lib/src/domain/playback/playback_source_handoff.dart',
  'lib/src/domain/playback/playback_state.dart',
  'lib/src/domain/playback/player_core_bootstrap.dart',
  'lib/src/domain/playback/player_core_runtime.dart',
  'lib/src/ui/playback/playback_page_contract.dart',
  'docs/phase1-player-core.md',
  'docs/player-capability-gate.md',
  'docs/player-ui-integration-contract.md',
  'docs/player-runtime-composition.md',
  'docs/next-change-acg-data-experience.md',
  'tools/package_windows_release.ps1'
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

$uiOwnedEntryFiles = @(
  'lib/main.dart'
)
foreach ($entryFile in $uiOwnedEntryFiles) {
  $path = Join-Path $root $entryFile
  if (-not (Test-Path -LiteralPath $path)) {
    continue
  }
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenUiTerms + @('package:media_kit/')) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden concrete player dependency '$term' found in UI entry file: $path"
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
foreach ($export in @(
  'src/playback/deterministic_mpv_binding.dart',
  'src/playback/media_kit_mpv_binding.dart',
  'src/playback/player_runtime_composition.dart',
  'src/domain/playback/player_core_bootstrap.dart',
  'src/domain/playback/player_core_runtime.dart'
)) {
  if ($publicBarrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing player-core runtime export: $export"
  }
}

$approvedConcretePlayerImportFiles = @(
  'lib/src/playback/media_kit_mpv_binding.dart'
)
$sourceDartFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $sourceDartFiles) {
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $content = Get-Content -LiteralPath $file.FullName -Raw
  if ($content -match [regex]::Escape('package:media_kit/')) {
    if ($approvedConcretePlayerImportFiles -notcontains $relativePath) {
      throw "Concrete player package import is only allowed in approved Playback binding files: $($file.FullName)"
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
$normalizedMediaLibraryContent = $mediaLibraryContent -replace '\s+', ' '
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
  if ($normalizedMediaLibraryContent -notmatch [regex]::Escape($term)) {
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

$playerCoreRuntimeFiles = @(
  'lib/src/playback/deterministic_mpv_binding.dart',
  'lib/src/domain/playback/player_core_bootstrap.dart',
  'lib/src/domain/playback/player_core_runtime.dart'
)
foreach ($file in $playerCoreRuntimeFiles) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in @(
    'package:flutter', 'dart:ui', 'libmpv', 'media-kit', 'media_kit', 'vlc',
    'exoplayer', 'avplayer', 'platform channel', 'src/provider/',
    'src/foundation/storage/', 'src/network/',
    'Bangumi', 'Dandanplay', 'RSS', 'Anime4K', 'DiagnosticsCenter'
  )) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Phase 1 player-core runtime dependency '$term' found in $path"
    }
  }
}

$playerCoreRuntime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/playback/player_core_runtime.dart') -Raw
foreach ($term in @('PlayerCoreRuntime', 'ActivePlayerAdapterResolver', 'PlaybackControllerContract', 'PlaybackStateSnapshot', 'TrackDiscoveryResult', 'DeterministicPlayerClock')) {
  if ($playerCoreRuntime -notmatch [regex]::Escape($term)) {
    throw "Player core runtime missing required term: $term"
  }
}

$playerCoreBootstrap = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/playback/player_core_bootstrap.dart') -Raw
foreach ($term in @('PlayerCoreBootstrap', 'PlayerCoreRuntime', 'DeterministicMpvBinding', 'playerCoreRuntimeForbiddenDependencies', 'playerCoreRuntimeRequiredTerms')) {
  if ($playerCoreBootstrap -notmatch [regex]::Escape($term)) {
    throw "Player core bootstrap missing required term: $term"
  }
}

$deterministicBinding = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/deterministic_mpv_binding.dart') -Raw
foreach ($term in @('DeterministicMpvBinding', 'MpvAdapterBinding', 'PlaybackOperation', 'TrackDiscoveryResult', 'TrackSwitchResult')) {
  if ($deterministicBinding -notmatch [regex]::Escape($term)) {
    throw "Deterministic MPV binding missing required term: $term"
  }
}

$runtimeComposition = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/player_runtime_composition.dart') -Raw
foreach ($term in @('PlayerRuntimeCompositionContract', 'MpvAdapterBinding', 'PlaybackCapabilityMatrix')) {
  if ($runtimeComposition -notmatch [regex]::Escape($term)) {
    throw "Player runtime composition contract missing required term: $term"
  }
}
foreach ($term in @('package:media_kit/', 'libmpv', 'MediaKitMpvBinding')) {
  if ($runtimeComposition -match [regex]::Escape($term)) {
    throw "Neutral player runtime composition contract must not import concrete player details: $term"
  }
}

$mediaKitBinding = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/media_kit_mpv_binding.dart') -Raw
foreach ($term in @('MediaKitMpvBinding', 'MpvAdapterBinding', 'LocalFilePlaybackSource', 'BundledMpvLibraryResolver', 'libmpv-2.dll', 'MediaKit.ensureInitialized', 'mediaKitLocalFilePlaybackCapabilities', 'mediaKitLocalFilePlayerRuntimeComposition', 'PlayerRuntimeCompositionContract', 'PlaybackFailureKind.operationFailed')) {
  if ($mediaKitBinding -notmatch [regex]::Escape($term)) {
    throw "Concrete MPV binding missing required term: $term"
  }
}
foreach ($term in @('HttpPlaybackSource', 'HlsPlaybackSource')) {
  if ($mediaKitBinding -match [regex]::Escape($term)) {
    throw "Concrete MPV binding must not implement unverified source type directly: $term"
  }
}

$windowsReleasePackageScript = Get-Content -LiteralPath (Join-Path $root 'tools/package_windows_release.ps1') -Raw
foreach ($term in @('libmpv-2.dll', 'CELESTERIA_LIBMPV_PATH', 'Copy-Item', 'Compress-Archive', 'Assert-ZipContainsReleaseFiles')) {
  if ($windowsReleasePackageScript -notmatch [regex]::Escape($term)) {
    throw "Windows release packaging script missing required term: $term"
  }
}
foreach ($term in @('setx', '[Environment]::SetEnvironmentVariable', 'PathMachine', 'PathUser')) {
  if ($windowsReleasePackageScript -match [regex]::Escape($term)) {
    throw "Windows release packaging script must not mutate global PATH or environment: $term"
  }
}

$compositionDoc = Get-Content -LiteralPath (Join-Path $root 'docs/player-runtime-composition.md') -Raw
foreach ($term in @('mediaKitLocalFilePlayerRuntimeComposition', 'PlayerCoreBootstrap.withComposition', 'package_windows_release.ps1', 'libmpv-2.dll', 'UI code must not import')) {
  if ($compositionDoc -notmatch [regex]::Escape($term)) {
    throw "Player runtime composition doc missing required term: $term"
  }
}

$uiIntegrationDoc = Get-Content -LiteralPath (Join-Path $root 'docs/player-ui-integration-contract.md') -Raw
foreach ($term in @('PlaybackSourceHandoffResult', 'PlaybackSourceHandoffInput.localMediaIdentity', 'PlaybackControllerContract.currentState', 'PlaybackStateObserver', 'PlaybackPageContract.dispatch', 'await playerCore.dispose()', 'PlaybackCommandResult.failure', 'PlaybackFailureKind', 'PlaybackStateSnapshot.failureReason', 'must not parse concrete backend exception strings')) {
  if ($uiIntegrationDoc -notmatch [regex]::Escape($term)) {
    throw "Player UI integration contract doc missing required term: $term"
  }
}

$capabilityGateDoc = Get-Content -LiteralPath (Join-Path $root 'docs/player-capability-gate.md') -Raw
foreach ($term in @('mediaKitLocalFilePlayerRuntimeComposition', 'PlaybackPageContract', 'PlaybackPageSurfaceDescriptor', 'localFilePlayback', 'playPause', 'seek', 'stop', 'httpPlayback', 'hlsPlayback', 'progressReporting', 'audioTrackDiscovery', 'subtitleTrackSwitching', 'fallbackAdapter', 'UI code must not call a concrete media_kit/libmpv backend directly')) {
  if ($capabilityGateDoc -notmatch [regex]::Escape($term)) {
    throw "Player capability gate doc missing required term: $term"
  }
}

$mediaKitBindingTest = Get-Content -LiteralPath (Join-Path $root 'test/playback/media_kit_mpv_binding_test.dart') -Raw
foreach ($term in @('composition exposes only verified UI-facing controls', 'PlaybackPageContract', 'PlaybackPageControlId.playPause', 'PlaybackPageControlId.seek', 'PlaybackPageControlId.stop', 'PlaybackPageControlId.progress', 'PlaybackPagePanelId.tracks', 'PlaybackPageIntentOutcome.unsupported')) {
  if ($mediaKitBindingTest -notmatch [regex]::Escape($term)) {
    throw "Concrete MPV binding tests missing capability gate assertion: $term"
  }
}

$playerCoreRuntimeTest = Get-Content -LiteralPath (Join-Path $root 'test/playback/player_core_runtime_test.dart') -Raw
foreach ($term in @('ui integration flow prepares source observes lifecycle and disposes', 'PlaybackSourceHandoffInput.localMediaIdentity', 'PlaybackStateObserver', 'PlaybackLifecycleStatus.opening', 'PlaybackLifecycleStatus.playing', 'PlaybackFailureKind.disposed', 'ui integration flow preserves normalized source and runtime errors', 'PlaybackSourceHandoffFailureKind.unsupportedScheme', 'PlaybackFailureKind.unsupported', 'PlaybackLifecycleStatus.failed')) {
  if ($playerCoreRuntimeTest -notmatch [regex]::Escape($term)) {
    throw "Player core runtime tests missing UI integration assertion: $term"
  }
}

& dart (Join-Path $root 'tools/player_core_runtime_check.dart')

'Player core checks passed.'
