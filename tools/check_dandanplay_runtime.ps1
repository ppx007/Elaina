$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_bangumi_runtime.ps1')

$requiredFiles = @(
  'docs/dandanplay-api-client.md',
  'lib/src/provider/dandanplay/dandanplay_api_client.dart',
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

$apiClient = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/dandanplay/dandanplay_api_client.dart') -Raw
foreach ($term in @(
  'DandanplayApiClient',
  'DandanplayApiProvider',
  'DandanplayApiTransport',
  'HttpDandanplayApiTransport',
  'ProviderGateway',
  'dandanplayGatewayRequest',
  '/api/v2/match',
  '/api/v2/search/episodes',
  '/api/v2/comment/',
  'X-AppId',
  'X-AppSecret'
)) {
  if ($apiClient -notmatch [regex]::Escape($term)) {
    throw "Dandanplay concrete API client missing required term: $term"
  }
}

foreach ($term in @(
  'package:flutter',
  'dart:ui',
  'media_kit',
  'libmpv',
  'src/ui',
  '../../ui',
  '../ui',
  'src/playback',
  '../../playback',
  '../playback',
  'src/streaming',
  '../../streaming',
  '../streaming',
  'src/foundation/storage',
  '../../foundation/storage',
  '../foundation/storage'
)) {
  if ($apiClient -match [regex]::Escape($term)) {
    throw "Forbidden Dandanplay concrete API dependency '$term' found."
  }
}

$domainRuntime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/acg/dandanplay_acg_runtime.dart') -Raw
foreach ($term in @('DandanplayApiClient', 'HttpDandanplayApiTransport', 'dart:io', 'https://api.dandanplay.net')) {
  if ($domainRuntime -match [regex]::Escape($term)) {
    throw "Dandanplay Domain runtime must not import concrete API detail: $term"
  }
}

$uiFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/ui') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in @('DandanplayApiClient', 'DandanplayApiProvider', 'HttpDandanplayApiTransport', 'package:celesteria/src/provider/dandanplay')) {
    if ($content -match [regex]::Escape($term)) {
      throw "Dandanplay concrete API dependency '$term' leaked into UI file: $($file.FullName)"
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
  'src/provider/dandanplay/dandanplay_api_client.dart',
  'src/provider/dandanplay/dandanplay_runtime.dart',
  'src/domain/acg/dandanplay_acg_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing Dandanplay runtime export: $export"
  }
}

& dart (Join-Path $root 'tools/dandanplay_runtime_check.dart')

Write-Output 'Dandanplay runtime checks passed.'
