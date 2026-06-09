$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_detail_library_seasonal.ps1')

$requiredFiles = @(
  'lib/src/domain/detail/video_detail.dart',
  'lib/src/domain/detail/video_detail_runtime.dart',
  'lib/src/domain/detail/video_detail_bootstrap.dart',
  'lib/src/ui/detail/video_detail_page_contract.dart',
  'test/domain/detail/video_detail_runtime_test.dart',
  'tools/video_detail_runtime_check.dart'
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

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/domain/detail/video_detail.dart',
  'src/domain/detail/video_detail_runtime.dart',
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

& dart (Join-Path $root 'tools/video_detail_runtime_check.dart')

Write-Output 'Video detail runtime checks passed.'
