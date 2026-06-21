$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'lib/src/provider/rss/rss_feed_fetcher_parser.dart',
  'test/provider/rss/rss_feed_fetcher_parser_test.dart',
  'tools/rss_feed_fetcher_parser_check.dart',
  'docs/rss-fetcher-parser.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required RSS feed fetcher/parser file: $file"
  }
}

$provider = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/rss/rss_feed_fetcher_parser.dart') -Raw
foreach ($term in @(
  'HttpFeedFetcher',
  'HttpFeedHttpTransport',
  'FeedHttpTransport',
  'RssXmlFeedParser',
  'AtomXmlFeedParser',
  'ProviderGatewayRequest',
  'FeedFetchResponse',
  'notModified',
  'package:xml/xml.dart'
)) {
  if ($provider -notmatch [regex]::Escape($term)) {
    throw "RSS feed fetcher/parser missing required term: $term"
  }
}

foreach ($term in @(
  'package:flutter',
  'dart:ui',
  'DownloadEngineAdapter',
  'libtorrent',
  'WebViewController',
  'runJavascript',
  'YucWikiScraper',
  'crawler',
  'scraper',
  'media_kit',
  'libmpv',
  'sqlite3'
)) {
  if ($provider -match [regex]::Escape($term)) {
    throw "RSS feed fetcher/parser contains forbidden dependency: $term"
  }
}

$domainFiles = @(
  'lib/src/domain/rss/rss_engine.dart',
  'lib/src/domain/rss/rss_engine_runtime.dart'
)

foreach ($file in $domainFiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in @(
    'dart:io',
    'HttpClient',
    'package:xml',
    'HttpFeedFetcher',
    'HttpFeedHttpTransport',
    'RssXmlFeedParser',
    'AtomXmlFeedParser'
  )) {
    if ($content -match [regex]::Escape($term)) {
      throw "Domain RSS file contains Step 46 concrete dependency '$term': $file"
    }
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/provider/rss/rss_feed_fetcher_parser.dart';")) {
  throw 'Public Dart barrel missing RSS feed fetcher/parser export.'
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
  foreach ($term in @('HttpFeedFetcher', 'RssXmlFeedParser', 'AtomXmlFeedParser', 'package:xml/xml.dart')) {
    if ($content -match [regex]::Escape($term)) {
      throw "UI/platform file contains Step 46 concrete dependency '$term': $($file.FullName)"
    }
  }
}

& dart (Join-Path $root 'tools/rss_feed_fetcher_parser_check.dart')

Write-Output 'RSS feed fetcher/parser boundary checks passed.'

