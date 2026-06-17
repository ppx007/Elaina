$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_rss_feed_fetcher_parser.ps1')

$requiredFiles = @(
  'lib/src/domain/seasonal/seasonal_feed_flow.dart',
  'test/domain/seasonal/seasonal_feed_flow_test.dart',
  'tools/seasonal_feed_flow_check.dart',
  'docs/seasonal-feed-flow.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required seasonal feed flow file: $file"
  }
}

$flow = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_feed_flow.dart') -Raw
foreach ($term in @(
  'SeasonalFeedFlowRuntime',
  'SeasonalFeedFlowBootstrap',
  'SeasonalFeedFlowRefreshSnapshot',
  'SeasonalFeedFlowActionResult',
  'RssEngineRuntime',
  'SeasonalIndexerRuntime',
  'refreshSource',
  'BangumiMatchQueueProjection'
)) {
  if ($flow -notmatch [regex]::Escape($term)) {
    throw "Seasonal feed flow missing required term: $term"
  }
}

$seasonal = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_anime.dart') -Raw
foreach ($term in @(
  'FeedItemSeasonalAnimeConsumer',
  'defaultSeasonalCatalogEntryIdPrefix',
  'SeasonalAnimeConsumer'
)) {
  if ($seasonal -notmatch [regex]::Escape($term)) {
    throw "Seasonal consumer contracts missing required term: $term"
  }
}

$domainSeasonalFiles = @(
  'lib/src/domain/seasonal/seasonal_anime.dart',
  'lib/src/domain/seasonal/seasonal_indexer_runtime.dart',
  'lib/src/domain/seasonal/seasonal_feed_flow.dart'
)

foreach ($file in $domainSeasonalFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in @(
    'dart:io',
    'HttpClient',
    'package:xml',
    'HttpFeedFetcher',
    'HttpFeedHttpTransport',
    'RssXmlFeedParser',
    'AtomXmlFeedParser',
    'RssAutoDownload',
    'rss_auto_download',
    'DownloadEngineAdapter',
    'BitTorrent',
    'BtTask',
    'OnlineRule',
    'WebViewController',
    'DiagnosticsCenter',
    'package:flutter',
    'dart:ui'
  )) {
    if ($content -match [regex]::Escape($term)) {
      throw "Domain seasonal file contains forbidden Step 47 dependency '$term': $file"
    }
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/domain/seasonal/seasonal_feed_flow.dart';")) {
  throw 'Public Dart barrel missing seasonal feed flow export.'
}

$uiAndPlatformFiles = @()
foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $uiAndPlatformFiles += Get-ChildItem -LiteralPath $fullPath -Recurse -File |
      Where-Object { $_.Extension -in @('.dart', '.cpp', '.h', '.cc', '.ps1') }
  }
}
$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $uiAndPlatformFiles += Get-Item -LiteralPath $mainPath
}

foreach ($file in $uiAndPlatformFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in @('SeasonalFeedFlowRuntime', 'SeasonalFeedFlowBootstrap', 'HttpFeedFetcher', 'RssXmlFeedParser')) {
    if ($content -match [regex]::Escape($term)) {
      throw "UI/platform file contains Step 47 dependency '$term': $($file.FullName)"
    }
  }
}

& dart (Join-Path $root 'tools/seasonal_feed_flow_check.dart')

Write-Output 'Seasonal feed flow boundary checks passed.'
