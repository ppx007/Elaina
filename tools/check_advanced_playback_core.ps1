$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_bt_streaming_core.ps1')

$requiredFiles = @(
  'lib/src/playback/video_enhancement_pipeline.dart',
  'lib/src/playback/media_kit_mpv_binding.dart',
  'lib/src/playback/av_sync_guard.dart',
  'lib/src/playback/advanced_caption_rendering.dart',
  'lib/src/playback/fallback_adapter.dart',
  'lib/src/foundation/storage/av_sync_guard_storage_contracts.dart',
  'lib/src/foundation/storage/advanced_caption_storage_contracts.dart',
  'lib/src/foundation/storage/video_enhancement_storage_contracts.dart',
  'lib/src/foundation/storage/fallback_adapter_storage_contracts.dart',
  'docs/phase5-advanced-playback-core.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required advanced playback file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('mpv', 'Anime4K', 'VLC', 'AVSyncGuard', 'VideoEnhancementPipeline', 'AdvancedCaptionRenderer', 'PlaybackFallbackStrategy')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden advanced playback UI dependency '$term' found in $($file.FullName)"
    }
  }
}

$approvedConcretePlaybackFiles = @(
  'lib/src/playback/media_kit_mpv_binding.dart'
)
$playbackFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/playback') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $playbackFiles) {
  $relativePath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  if ($approvedConcretePlaybackFiles -contains $relativePath) {
    continue
  }
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $forbiddenImplTerms = @('dart:ffi', 'package:flutter', 'package:vlc', 'package:dart_vlc', 'package:flutter_vlc_player', 'libmpv', 'shaderc')
  foreach ($term in $forbiddenImplTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Playback contract contains forbidden implementation dependency '$term' in $($file.FullName)"
    }
  }
}

$enhancement = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/video_enhancement_pipeline.dart') -Raw
$requiredEnhancementTerms = @('VideoEnhancementPipeline', 'VideoEnhancementProfile', 'RenderBudgetInput', 'Anime4kPresetIntent', 'EnhancementEvaluationOutcome', 'EnhancementApplyOutcome', 'EnhancementDisableOutcome', 'EnhancementDegradationOutcome', 'DeterministicVideoEnhancementPipeline')
foreach ($term in $requiredEnhancementTerms) {
  if ($enhancement -notmatch $term) {
    throw "Video enhancement pipeline missing contract term: $term"
  }
}

$enhancementStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/video_enhancement_storage_contracts.dart') -Raw
$requiredEnhancementStorageTerms = @('StoredEnhancementProfileRecord', 'StoredActiveEnhancementProfileRecord', 'StoredEnhancementPipelineStateRecord', 'EnhancementProfileStore', 'DeterministicEnhancementProfileStore')
foreach ($term in $requiredEnhancementStorageTerms) {
  if ($enhancementStorage -notmatch $term) {
    throw "Video enhancement storage missing contract term: $term"
  }
}

$syncGuard = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/av_sync_guard.dart') -Raw
$requiredAVSyncTerms = @('AVSyncGuard', 'AVSyncSample', 'degradationDrift = const Duration\(milliseconds: 120\)', 'targetDrift = const Duration\(milliseconds: 40\)', 'AVSyncDegradationAction', 'AVSyncEvaluationOutcome', 'AVSyncDegradationRequestOutcome', 'AVSyncRecoveryOutcome', 'DeterministicAVSyncGuard', 'sampleWindowSize')
foreach ($term in $requiredAVSyncTerms) {
  if ($syncGuard -notmatch $term) {
    throw "AVSyncGuard missing contract term: $term"
  }
}

$avSyncStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/av_sync_guard_storage_contracts.dart') -Raw
$requiredAVSyncStorageTerms = @('StoredAVSyncPolicyRecord', 'StoredAVSyncHealthRecord', 'StoredAVSyncSampleHistoryMetadataRecord', 'StoredAVSyncDegradationDecisionRecord', 'AVSyncGuardStore', 'DeterministicAVSyncGuardStore')
foreach ($term in $requiredAVSyncStorageTerms) {
  if ($avSyncStorage -notmatch $term) {
    throw "AV sync storage missing contract term: $term"
  }
}

$captions = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/advanced_caption_rendering.dart') -Raw
if ($captions -notmatch 'MatrixDanmakuRequest' -or $captions -notmatch 'DualSubtitleRequest' -or $captions -notmatch 'pgsImageSubtitle' -or $captions -notmatch 'assEnhancedLayout') {
  throw 'Advanced captions must define Matrix4 danmaku, dual subtitle, PGS, and ASS enhancement contracts.'
}

$requiredCaptionTerms = @('AdvancedCaptionProfile', 'CaptionEvaluationOutcome', 'CaptionRenderOutcome', 'CaptionDisableOutcome', 'CaptionDegradationOutcome', 'AdvancedCaptionFailureKind', 'DeterministicAdvancedCaptionRenderer', 'disableAdvancedCaptions')
foreach ($term in $requiredCaptionTerms) {
  if ($captions -notmatch $term) {
    throw "Advanced captions missing contract term: $term"
  }
}

$captionStorage = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/advanced_caption_storage_contracts.dart') -Raw
$requiredCaptionStorageTerms = @('StoredAdvancedCaptionProfileRecord', 'StoredActiveAdvancedCaptionProfileRecord', 'StoredAdvancedCaptionDualSubtitleSelectionRecord', 'StoredAdvancedCaptionRendererStateRecord', 'AdvancedCaptionStore', 'DeterministicAdvancedCaptionStore')
foreach ($term in $requiredCaptionStorageTerms) {
  if ($captionStorage -notmatch $term) {
    throw "Advanced caption storage missing contract term: $term"
  }
}

$fallback = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/fallback_adapter.dart') -Raw
if ($fallback -notmatch 'PlaybackFallbackStrategy' -or $fallback -notmatch 'FallbackSelection' -or $fallback -notmatch 'hiddenCapabilities' -or $fallback -match 'requiredVlc|mandatory') {
  throw 'Fallback adapter must define optional selection and capability hiding contracts.'
}

$requiredFallbackTerms = @('FallbackRegistrationOutcome', 'FallbackEvaluationOutcome', 'FallbackSelectionOutcome', 'FallbackDisableOutcome', 'FallbackCapabilityReevaluationOutcome', 'FallbackCapabilityReadModel', 'DeterministicPlaybackFallbackStrategy')
foreach ($term in $requiredFallbackTerms) {
  if ($fallback -notmatch $term) {
    throw "Fallback adapter missing typed contract term: $term"
  }
}

$fallbackStoragePath = Join-Path $root 'lib/src/foundation/storage/fallback_adapter_storage_contracts.dart'
$fallbackStorage = Get-Content -LiteralPath $fallbackStoragePath -Raw
$requiredFallbackStorageTerms = @('StoredFallbackAdapterCandidateRecord', 'StoredActiveFallbackConfigurationRecord', 'StoredFallbackSelectionHistoryRecord', 'StoredFallbackStrategyStateRecord', 'FallbackAdapterStore', 'DeterministicFallbackAdapterStore')
foreach ($term in $requiredFallbackStorageTerms) {
  if ($fallbackStorage -notmatch $term) {
    throw "Fallback adapter storage missing contract term: $term"
  }
}

$capabilities = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/capability_matrix.dart') -Raw
$requiredCapabilities = @('videoEnhancement', 'hdrToneMapping', 'debandFiltering', 'anime4kPreset', 'VideoEnhancementCapabilityStatus', 'avSyncGuard', 'matrixDanmaku', 'dualSubtitles', 'pgsSubtitleRendering', 'assSubtitleEnhancement', 'fallbackAdapter', 'FallbackAdapterCapabilityStatus', 'fallbackAdapterStatus')
foreach ($capability in $requiredCapabilities) {
  if ($capabilities -notmatch $capability) {
    throw "PlaybackCapability missing advanced capability: $capability"
  }
}

$mediaKitBinding = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/media_kit_mpv_binding.dart') -Raw
$requiredMpvEnhancementTerms = @(
  'MpvEnhancementBinding',
  'MpvEnhancementPlanner',
  'MpvEnhancementPlan',
  'MpvEnhancementCommand',
  'setProperty',
  'command',
  'mpvEnhancementScaleProperty',
  'mpvEnhancementToneMappingProperty',
  'mpvEnhancementDebandProperty',
  'mpvEnhancementGlslShadersOption',
  'applyEnhancement',
  'disableEnhancement',
  'EnhancementPipelineFailureKind.adapterRejected'
)
foreach ($term in $requiredMpvEnhancementTerms) {
  if ($mediaKitBinding -notmatch [regex]::Escape($term)) {
    throw "Concrete MPV enhancement binding missing required term: $term"
  }
}

if ($mediaKitBinding -notmatch [regex]::Escape('Anime4K-style preset requires an explicit MPV shader path.')) {
  throw 'Concrete MPV enhancement binding must reject Anime4K intent without an explicit shader path.'
}

$requiredMpvSubtitleTerms = @(
  'MpvAdvancedSubtitleBinding',
  'MpvSubtitlePlanner',
  'MpvSubtitlePlan',
  'mpvSubtitleAddCommand',
  'mpvSubtitlePrimaryProperty',
  'mpvSubtitleSecondaryProperty',
  'mpvSubtitleAssProperty',
  'renderDualSubtitles',
  'renderAdvancedSubtitle',
  'disableAdvancedSubtitles',
  'AdvancedCaptionFailureKind.adapterRejected'
)
foreach ($term in $requiredMpvSubtitleTerms) {
  if ($mediaKitBinding -notmatch [regex]::Escape($term)) {
    throw "Concrete MPV subtitle bridge missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
  }
}

$storageContracts = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/storage_contracts.dart') -Raw
if ($storageContracts -notmatch 'videoEnhancement' -or $storageContracts -notmatch 'EnhancementProfileStore' -or $storageContracts -notmatch 'avSyncGuard' -or $storageContracts -notmatch 'AVSyncGuardStore' -or $storageContracts -notmatch 'advancedCaptions' -or $storageContracts -notmatch 'AdvancedCaptionStore' -or $storageContracts -notmatch 'fallbackAdapter' -or $storageContracts -notmatch 'FallbackAdapterStore') {
  throw 'Storage foundation must expose video enhancement, AV sync guard, advanced caption, and fallback adapter persistence.'
}

$cacheInvalidation = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart') -Raw
$requiredEnhancementEvents = @('EnhancementProfileChanged', 'EnhancementCapabilityReevaluated', 'EnhancementPipelineStateChanged')
foreach ($term in $requiredEnhancementEvents) {
  if ($cacheInvalidation -notmatch $term) {
    throw "Cache invalidation bus missing enhancement event: $term"
  }
}

$requiredAVSyncEvents = @('AVSyncSampleIngested', 'AVSyncHealthTransitioned', 'AVSyncDegradationDecisionRecorded', 'AVSyncRecoveryStateChanged')
foreach ($term in $requiredAVSyncEvents) {
  if ($cacheInvalidation -notmatch $term) {
    throw "Cache invalidation bus missing AV sync event: $term"
  }
}

$requiredAdvancedCaptionEvents = @('AdvancedCaptionProfileChanged', 'AdvancedCaptionCapabilityReevaluated', 'AdvancedCaptionRendererStateChanged', 'AdvancedCaptionDualSubtitleSelectionChanged', 'AdvancedCaptionDegradationStateChanged')
foreach ($term in $requiredAdvancedCaptionEvents) {
  if ($cacheInvalidation -notmatch $term) {
    throw "Cache invalidation bus missing advanced caption event: $term"
  }
}

$requiredFallbackEvents = @('FallbackAdapterRegistrationChanged', 'FallbackCapabilityReevaluated', 'FallbackSelectionChanged', 'FallbackStrategyStateChanged', 'FallbackDisabled', 'FallbackRejected')
foreach ($term in $requiredFallbackEvents) {
  if ($cacheInvalidation -notmatch $term) {
    throw "Cache invalidation bus missing fallback adapter event: $term"
  }
}

if ($syncGuard -match 'VideoEnhancementPipeline\.' -or $syncGuard -match '\.apply\(' -or $syncGuard -match '\.disable\(' -or $syncGuard -match '\.requestDegradation\(') {
  throw 'AVSyncGuard must not execute concrete video enhancement pipeline actions.'
}

if ($syncGuard -match 'AdvancedCaptionRenderer' -or $syncGuard -match 'advanced_caption_rendering') {
  throw 'AVSyncGuard must not execute concrete advanced caption renderer actions.'
}

$forbiddenCaptionImplTerms = @('Widget', 'Canvas', 'PictureRecorder', 'FragmentProgram', 'PgsDecoder', 'AssRenderer', 'NativePlugin', 'dart:ffi', 'libmpv', 'Vlc')
foreach ($term in $forbiddenCaptionImplTerms) {
  if ($captions -match [regex]::Escape($term)) {
    throw "Advanced captions contain forbidden implementation dependency: $term"
  }
}

$phase5Files = @(
  'lib/src/playback/video_enhancement_pipeline.dart',
  'lib/src/playback/av_sync_guard.dart',
  'lib/src/playback/advanced_caption_rendering.dart',
  'lib/src/playback/fallback_adapter.dart',
  'docs/phase5-advanced-playback-core.md'
)
$forbiddenScopeTerms = @('diagnostics center', 'DNS policy', 'online source rule', 'RSS auto-download', 'WebView challenge')
foreach ($file in $phase5Files) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenScopeTerms) {
    if ($file -notlike 'docs/*' -and $content -match [regex]::Escape($term)) {
      throw "Forbidden out-of-scope term '$term' found in $file"
    }
  }
}

'Advanced playback core checks passed.'
