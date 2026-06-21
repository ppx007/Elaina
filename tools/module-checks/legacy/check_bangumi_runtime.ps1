$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
& (Join-Path $PSScriptRoot 'check_subtitle_runtime.ps1')

$requiredFiles = @(
  'docs/bangumi-api-client.md',
  'lib/src/provider/bangumi/bangumi_api_client.dart',
  'lib/src/provider/bangumi/bangumi_runtime.dart',
  'lib/src/domain/acg/bangumi_acg_runtime.dart',
  'test/provider/bangumi/bangumi_runtime_test.dart',
  'tools/runtime_checks/bangumi_runtime_contract.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Bangumi runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/provider/bangumi/bangumi_runtime.dart',
  'lib/src/domain/acg/bangumi_acg_runtime.dart'
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
  'src/streaming',
  '../../streaming',
  '../streaming',
  'src/network',
  '../../network',
  '../network',
  'src/provider/rss',
  'src/provider/online',
  'src/playback/subtitle',
  'WebView',
  'OAuth',
  'refreshToken',
  'accessToken',
  'http://',
  'https://'
)

foreach ($file in $runtimeFiles) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Bangumi runtime dependency '$term' found in $file"
    }
  }
}

$apiClient = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/bangumi/bangumi_api_client.dart') -Raw
foreach ($term in @(
  'BangumiApiClient',
  'BangumiApiProvider',
  'BangumiApiTransport',
  'HttpBangumiApiTransport',
  'ProviderGateway',
  'bangumiGatewayRequest',
  '/v0/subjects/',
  '/v0/search/subjects',
  '/v0/episodes/',
  '/v0/me',
  '/v0/users/-/collections/-/episodes/'
)) {
  if ($apiClient -notmatch [regex]::Escape($term)) {
    throw "Bangumi concrete API client missing required term: $term"
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
    throw "Forbidden Bangumi concrete API dependency '$term' found."
  }
}

$domainRuntime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/acg/bangumi_acg_runtime.dart') -Raw
foreach ($term in @('BangumiApiClient', 'HttpBangumiApiTransport', 'dart:io', 'https://api.bgm.tv')) {
  if ($domainRuntime -match [regex]::Escape($term)) {
    throw "Bangumi Domain runtime must not import concrete API detail: $term"
  }
}

$uiFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/ui') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in @('BangumiApiClient', 'BangumiApiProvider', 'HttpBangumiApiTransport', 'package:elaina/src/provider/bangumi')) {
    if ($content -match [regex]::Escape($term)) {
      throw "Bangumi concrete API dependency '$term' leaked into UI file: $($file.FullName)"
    }
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/provider/bangumi/bangumi_api_client.dart',
  'src/provider/bangumi/bangumi_runtime.dart',
  'src/domain/acg/bangumi_acg_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing Bangumi runtime export: $export"
  }
}

Write-Output 'Bangumi runtime checks passed.'

