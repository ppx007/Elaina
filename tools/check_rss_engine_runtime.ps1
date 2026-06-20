$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_subtitle_provider_runtime.ps1')
& (Join-Path $PSScriptRoot 'check_rss_feed_fetcher_parser.ps1')

$requiredFiles = @(
  'lib/src/domain/rss/rss_engine.dart',
  'lib/src/domain/rss/rss_engine_runtime.dart',
  'lib/src/provider/rss/feed_contracts.dart',
  'lib/src/provider/rss/rss_feed_fetcher_parser.dart',
  'test/domain/rss/rss_engine_contract_test.dart',
  'test/domain/rss/rss_engine_runtime_test.dart',
  'test/provider/rss/rss_feed_fetcher_parser_test.dart',
  'tools/rss_engine_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required RSS engine runtime file: $file"
  }
}

$runtimeFiles = @(
  'lib/src/domain/rss/rss_engine.dart',
  'lib/src/domain/rss/rss_engine_runtime.dart',
  'lib/src/provider/rss/feed_contracts.dart'
)

$forbiddenRuntimeTerms = @(
  'package:flutter',
  'dart:ui',
  'dart:io',
  '../../network',
  '../network',
  '../../streaming',
  '../streaming',
  '../../domain/seasonal',
  '../seasonal',
  'SeasonalIndexer',
  'SeasonalAnimeConsumer',
  'BangumiMatch',
  'RssAutoDownload',
  'rss_auto_download',
  'BtTask',
  'BitTorrent',
  'online_rule',
  'OnlineRule',
  'HttpClient',
  'WebView',
  'DiagnosticsCenter',
  'Widget',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'YucWikiScraper',
  'yucWikiScraper',
  'crawler',
  'scraper',
  'SQLite',
  'sqflite'
)

foreach ($file in $runtimeFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenRuntimeTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 16 RSS engine runtime dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/rss/rss_engine_runtime.dart') -Raw
foreach ($term in @(
  'RssEngineRuntime',
  'RssEngineBootstrap',
  'RssEngineRuntimeSnapshot',
  'RssEngineRuntimeFailureKind',
  'RssEngineActionResult',
  'RssEngineRuntimeObserver',
  'RssEngineCursorSnapshot',
  'RssEngineDedupeSnapshot',
  'RssEngineRefreshSnapshot',
  'FeedScheduler',
  'RssFeedStore',
  'FeedDeduplicator'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "RSS engine runtime missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/domain/rss/rss_engine.dart',
  'src/domain/rss/rss_engine_runtime.dart',
  'src/provider/rss/feed_contracts.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing RSS engine runtime export: $export"
  }
}
if ($barrel -match [regex]::Escape("export 'src/ui/rss")) {
  throw 'Public Dart contract barrel must not export concrete RSS UI pages.'
}

& dart (Join-Path $root 'tools/rss_engine_runtime_check.dart')

Write-Output 'RSS engine runtime checks passed.'
