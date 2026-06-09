$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_bangumi_runtime.ps1')

$requiredFiles = @(
  'lib/src/provider/dandanplay/dandanplay_runtime.dart',
  'lib/src/domain/acg/dandanplay_acg_runtime.dart',
  'test/provider/dandanplay/dandanplay_runtime_test.dart',
  'tools/dandanplay_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Dandanplay runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/provider/dandanplay/dandanplay_runtime.dart',
  'lib/src/domain/acg/dandanplay_acg_runtime.dart'
)

$forbiddenTerms = @(
  'package:flutter',
  'dart:ui',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'src/ui',
  '../../ui',
  '../ui',
  'src/playback',
  '../../playback',
  '../playback',
  'src/playback/subtitle',
  'src/streaming',
  '../../streaming',
  '../streaming',
  'src/network',
  '../../network',
  '../network',
  'src/provider/rss',
  'src/provider/online',
  '../../provider/rss',
  '../../provider/online',
  'BangumiProviderRuntime',
  'BasicDanmakuRenderer',
  'DanmakuRenderer',
  'PlayerClock',
  'WebView',
  'OAuth',
  'refreshToken',
  'accessToken',
  'tokenStorage',
  'http://',
  'https://'
)

foreach ($file in $runtimeFiles) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Dandanplay runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/dandanplay/dandanplay_runtime.dart') -Raw
foreach ($term in @(
  'dandanplayMatchRequestKey',
  'dandanplaySearchRequestKey',
  'dandanplayCommentsRequestKey',
  'dandanplayPostCommentRequestKey',
  'dandanplayGatewayRequest',
  'DeterministicDandanplayProvider',
  'DeterministicDandanplayCommentProvider',
  'DandanplayProviderRuntime',
  'DandanplayProviderBootstrap',
  'ProviderCachePolicy.networkOnly'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Dandanplay runtime missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/provider/dandanplay/dandanplay_runtime.dart',
  'src/domain/acg/dandanplay_acg_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing Dandanplay runtime export: $export"
  }
}

& dart (Join-Path $root 'tools/dandanplay_runtime_check.dart')

Write-Output 'Dandanplay runtime checks passed.'
