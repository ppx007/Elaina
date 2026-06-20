$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_media_library_runtime.ps1')

$requiredFiles = @(
  'lib/src/domain/subtitle/subtitle_provider_runtime.dart',
  'lib/src/domain/subtitle/subtitle_discovery.dart',
  'lib/src/provider/subtitle/subtitle_provider.dart',
  'test/domain/subtitle/subtitle_provider_runtime_test.dart',
  'tools/subtitle_provider_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required subtitle provider runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/domain/subtitle/subtitle_provider_runtime.dart',
  'lib/src/domain/subtitle/subtitle_discovery.dart',
  'lib/src/provider/subtitle/subtitle_provider.dart'
)

$forbiddenRuntimeTerms = @(
  'package:flutter',
  'dart:ui',
  '../../network',
  '../network',
  '../../streaming',
  '../streaming',
  '../../domain/rss',
  '../../domain/seasonal',
  '../../provider/rss',
  'RssEngine',
  'SeasonalIndexer',
  'BtTask',
  'BitTorrent',
  'online_rule',
  'OnlineRule',
  'HttpClient',
  'WebView',
  'DiagnosticsCenter',
  'AdvancedCaption',
  'advanced_caption',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'OpenSubtitlesClient',
  'scraper',
  'crawler',
  'captcha',
  'SQLite',
  'sqflite',
  'Directory(',
  'dart:io'
)

foreach ($file in $runtimeFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenRuntimeTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 15 subtitle provider runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/subtitle/subtitle_provider_runtime.dart') -Raw
foreach ($term in @(
  'SubtitleProviderRuntime',
  'SubtitleProviderBootstrap',
  'SubtitleProviderRuntimeSnapshot',
  'SubtitleProviderRuntimeFailureKind',
  'SubtitleProviderActionResult',
  'SubtitleDiscoveryContract',
  'SubtitleProviderHandoffResult',
  'SubtitleParseRequest',
  'DeterministicSubtitleDiscoveryContract'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Subtitle provider runtime missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/domain/subtitle/subtitle_provider_runtime.dart',
  'src/domain/subtitle/subtitle_discovery.dart',
  'src/provider/subtitle/subtitle_provider.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing subtitle provider runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/subtitle")) {
  throw 'Public Dart contract barrel must not export concrete subtitle provider UI pages.'
}

& dart (Join-Path $root 'tools/subtitle_provider_runtime_check.dart')

Write-Output 'Subtitle provider runtime checks passed.'
