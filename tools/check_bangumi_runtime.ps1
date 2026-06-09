$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_subtitle_runtime.ps1')

$requiredFiles = @(
  'lib/src/provider/bangumi/bangumi_runtime.dart',
  'lib/src/domain/acg/bangumi_acg_runtime.dart',
  'test/provider/bangumi/bangumi_runtime_test.dart',
  'tools/bangumi_runtime_check.dart'
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

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/provider/bangumi/bangumi_runtime.dart',
  'src/domain/acg/bangumi_acg_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing Bangumi runtime export: $export"
  }
}

Write-Output 'Bangumi runtime checks passed.'
