$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_bt_streaming_core.ps1')

$requiredFiles = @(
  'lib/src/playback/video_enhancement_pipeline.dart',
  'lib/src/playback/av_sync_guard.dart',
  'lib/src/playback/advanced_caption_rendering.dart',
  'lib/src/playback/fallback_adapter.dart',
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

$playbackFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/playback') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $playbackFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $forbiddenImplTerms = @('dart:ffi', 'package:flutter', 'package:vlc', 'package:dart_vlc', 'package:flutter_vlc_player', 'libmpv', 'shaderc')
  foreach ($term in $forbiddenImplTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Playback contract contains forbidden implementation dependency '$term' in $($file.FullName)"
    }
  }
}

$enhancement = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/video_enhancement_pipeline.dart') -Raw
if ($enhancement -notmatch 'VideoEnhancementPipeline' -or $enhancement -notmatch 'VideoEnhancementProfile' -or $enhancement -notmatch 'RenderBudgetInput' -or $enhancement -notmatch 'Anime4kPresetIntent') {
  throw 'Video enhancement pipeline must define profile, budget, and preset contracts.'
}

$syncGuard = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/av_sync_guard.dart') -Raw
if ($syncGuard -notmatch 'AVSyncGuard' -or $syncGuard -notmatch 'AVSyncSample' -or $syncGuard -notmatch 'degradationDrift = const Duration\(milliseconds: 120\)' -or $syncGuard -notmatch 'targetDrift = const Duration\(milliseconds: 40\)' -or $syncGuard -notmatch 'AVSyncDegradationAction') {
  throw 'AVSyncGuard must define metrics, 40ms target, 120ms degradation, and degradation actions.'
}

$captions = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/advanced_caption_rendering.dart') -Raw
if ($captions -notmatch 'MatrixDanmakuRequest' -or $captions -notmatch 'DualSubtitleRequest' -or $captions -notmatch 'pgsImageSubtitle' -or $captions -notmatch 'assEnhancedLayout') {
  throw 'Advanced captions must define Matrix4 danmaku, dual subtitle, PGS, and ASS enhancement contracts.'
}

$fallback = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/fallback_adapter.dart') -Raw
if ($fallback -notmatch 'PlaybackFallbackStrategy' -or $fallback -notmatch 'FallbackSelection' -or $fallback -notmatch 'hiddenCapabilities' -or $fallback -match 'requiredVlc|mandatory') {
  throw 'Fallback adapter must define optional selection and capability hiding contracts.'
}

$capabilities = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/capability_matrix.dart') -Raw
$requiredCapabilities = @('videoEnhancement', 'anime4kPreset', 'avSyncGuard', 'matrixDanmaku', 'dualSubtitles', 'pgsSubtitleRendering', 'assSubtitleEnhancement', 'fallbackAdapter')
foreach ($capability in $requiredCapabilities) {
  if ($capabilities -notmatch $capability) {
    throw "PlaybackCapability missing advanced capability: $capability"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
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
