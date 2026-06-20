$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_rss_engine_runtime.ps1')
& (Join-Path $PSScriptRoot 'check_seasonal_feed_flow.ps1')

$requiredFiles = @(
  'lib/src/domain/seasonal/seasonal_anime.dart',
  'lib/src/domain/seasonal/seasonal_indexer_runtime.dart',
  'lib/src/domain/seasonal/seasonal_feed_flow.dart',
  'lib/src/provider/rss/yuc_wiki_feed_source.dart',
  'test/domain/seasonal/seasonal_indexer_contract_test.dart',
  'test/domain/seasonal/seasonal_indexer_runtime_test.dart',
  'test/domain/seasonal/seasonal_feed_flow_test.dart',
  'tools/seasonal_indexer_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required seasonal indexer runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/domain/seasonal/seasonal_anime.dart',
  'lib/src/domain/seasonal/seasonal_indexer_runtime.dart',
  'lib/src/domain/seasonal/seasonal_feed_flow.dart',
  'lib/src/provider/rss/yuc_wiki_feed_source.dart'
)

$forbiddenRuntimeTerms = @(
  'package:flutter',
  'dart:ui',
  'dart:io',
  '../../ui',
  '../ui',
  '../../network',
  '../network',
  'HttpClient',
  'WebView',
  'YucWikiScraper',
  'yucWikiScraper',
  'Crawler',
  'crawler',
  'Scraper',
  'scraper',
  'RssAutoDownload',
  'rss_auto_download',
  'BtTask',
  'BitTorrent',
  'online_rule',
  'OnlineRule',
  'DiagnosticsCenter',
  'Widget',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'SQLite',
  'sqflite'
)

foreach ($file in $runtimeFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenRuntimeTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 17 seasonal indexer runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_indexer_runtime.dart') -Raw
foreach ($term in @(
  'SeasonalIndexerRuntime',
  'SeasonalIndexerBootstrap',
  'SeasonalIndexerRuntimeSnapshot',
  'SeasonalIndexerRuntimeFailureKind',
  'SeasonalIndexerActionResult',
  'SeasonalIndexerRuntimeObserver',
  'registerYucWikiSource',
  'processFeedItem',
  'startListening',
  'stopListening',
  'pendingMatchQueue',
  'processNextBangumiMatch',
  'SeasonalFeedFlowRuntime',
  'SeasonalFeedFlowBootstrap'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    $flow = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_feed_flow.dart') -Raw
    if ($flow -notmatch [regex]::Escape($term)) {
      throw "Seasonal indexer runtime missing required term: $term"
    }
  }
}

$seasonal = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_anime.dart') -Raw
foreach ($term in @(
  'SeasonalAnimeConsumer',
  'SeasonalCatalogEntry',
  'DeterministicSeasonalIndexer',
  'BangumiMatchQueueProjection',
  'DeterministicBangumiMatchWorker',
  'AutomaticBangumiMatchOutcome',
  'FeedItemSeasonalAnimeConsumer'
)) {
  if ($seasonal -notmatch [regex]::Escape($term) -and $runtime -notmatch [regex]::Escape($term)) {
    throw "Seasonal indexer contracts missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/domain/seasonal/seasonal_anime.dart',
  'src/domain/seasonal/seasonal_indexer_runtime.dart',
  'src/provider/rss/yuc_wiki_feed_source.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing seasonal indexer runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/seasonal")) {
  throw 'Public Dart contract barrel must not export concrete seasonal UI pages.'
}

& dart (Join-Path $root 'tools/seasonal_indexer_runtime_check.dart')

Write-Output 'Seasonal indexer runtime checks passed.'
