$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_acg_data_experience.ps1')

$requiredFiles = @(
  'lib/src/domain/detail/video_detail.dart',
  'lib/src/domain/media/media_library.dart',
  'lib/src/domain/seasonal/seasonal_anime.dart',
  'lib/src/domain/subtitle/subtitle_discovery.dart',
  'lib/src/domain/subtitle/subtitle_provider_bridge.dart',
  'lib/src/provider/subtitle/subtitle_provider.dart',
  'lib/src/provider/subtitle/subtitle_registration.dart',
  'lib/src/provider/rss/feed_contracts.dart',
  'lib/src/provider/rss/yuc_wiki_feed_source.dart',
  'lib/src/ui/detail/video_detail_page_contract.dart',
  'docs/phase3-detail-library-seasonal.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required detail/library/seasonal file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('bangumi', 'dandanplay', 'ProviderGateway', 'ProviderContract', 'FeedSource', 'yucWiki', 'StorageFoundation')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden detail/library UI dependency '$term' found in $($file.FullName)"
    }
  }
}

$subtitleProvider = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/subtitle/subtitle_provider.dart') -Raw
if ($subtitleProvider -notmatch 'implements GatewayBoundProvider' -or $subtitleProvider -notmatch 'ProviderKind\.subtitle') {
  throw 'SubtitleProvider must implement GatewayBoundProvider and use ProviderKind.subtitle.'
}
if ($subtitleProvider -notmatch 'SubtitleProviderCandidate' -or $subtitleProvider -match 'ExternalSubtitleCandidate' -or $subtitleProvider -notmatch 'ProviderSubtitleFormat' -or $subtitleProvider -notmatch 'srt' -or $subtitleProvider -notmatch 'vtt' -or $subtitleProvider -notmatch 'ass') {
  throw 'SubtitleProvider must return parser-compatible external subtitle candidates.'
}
if ($subtitleProvider -notmatch 'ProviderCachePolicy' -or $subtitleProvider -notmatch 'SubtitleProviderCachePolicy') {
  throw 'SubtitleProvider cache behavior must be declared through gateway cache policy contracts.'
}

$rssContracts = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/rss/feed_contracts.dart') -Raw
$requiredRssTerms = @('FeedSource', 'FeedFetcher', 'FeedParser', 'FeedScheduler', 'FeedDeduplicator', 'FeedDedupeKey', 'ProviderKind.rss', 'ProviderGateway')
foreach ($term in $requiredRssTerms) {
  if ($rssContracts -notmatch [regex]::Escape($term)) {
    throw "RSS contracts missing required term: $term"
  }
}

$yucWiki = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/rss/yuc_wiki_feed_source.dart') -Raw
if ($yucWiki -notmatch 'FeedSource' -or $yucWiki -match 'scraper|crawler|HttpClient|download|torrent|bt') {
  throw 'YucWiki must remain a normal FeedSource without scraper/download/BT logic.'
}

$seasonal = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/seasonal/seasonal_anime.dart') -Raw
if ($seasonal -notmatch 'SeasonalAnimeConsumer' -or $seasonal -notmatch 'BangumiMatchQueue' -or $seasonal -notmatch 'userConfirmed' -or $seasonal -notmatch 'AutomaticBangumiMatchResult') {
  throw 'Seasonal contracts must include consumer, Bangumi match queue, and user-confirmed binding priority.'
}
if ($seasonal -match "provider/") {
  throw 'Seasonal Domain contracts must not import provider-layer concrete feed or Bangumi types.'
}

$media = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/media/media_library.dart') -Raw
$requiredMediaTerms = @(
  'MediaLibraryScanner',
  'PlaybackHistoryStore',
  'ProviderBindingAuthority',
  'userConfirmed',
  'ProviderSubjectId',
  'MediaLibraryCatalogRepository',
  'MediaBatchImportContract',
  'MediaImportResult',
  'DeterministicMediaLibraryCatalogRepository',
  'DeterministicPlaybackHistoryStore',
  'DeterministicProviderBindingStore'
)
foreach ($term in $requiredMediaTerms) {
  if ($media -notmatch [regex]::Escape($term)) {
    throw "Media library contracts missing required term: $term"
  }
}
if ($media -match "provider/") {
  throw 'Media library contracts must remain provider-neutral.'
}

$detail = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/detail/video_detail.dart') -Raw
if ($detail -notmatch 'VideoDetailViewData' -or $detail -notmatch 'ContinueWatchingState' -or $detail -notmatch 'VideoDetailActionSet' -or $detail -notmatch 'hasValidPrimaryCount' -or $detail -notmatch 'perform') {
  throw 'Detail contracts must include view data, continue-watching state, and action limits.'
}

$subtitleBridge = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/subtitle/subtitle_provider_bridge.dart') -Raw
if ($subtitleBridge -notmatch 'SubtitleParseRequest' -or $subtitleBridge -notmatch 'ExternalSubtitleSource' -or $subtitleBridge -notmatch 'SubtitleProviderCandidate') {
  throw 'Domain subtitle bridge must explicitly connect provider candidates to basic subtitle parser contracts.'
}

$subtitleDiscovery = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/subtitle/subtitle_discovery.dart') -Raw
$requiredSubtitleDiscoveryTerms = @(
  'SubtitleDiscoveryContract',
  'DeterministicSubtitleDiscoveryContract',
  'SubtitleCacheStore',
  'LocalExternalSubtitleScanner',
  'subtitleParseRequestFromProviderFile',
  'encodingHint'
)
foreach ($term in $requiredSubtitleDiscoveryTerms) {
  if ($subtitleDiscovery -notmatch [regex]::Escape($term)) {
    throw "Subtitle discovery contracts missing required term: $term"
  }
}

$providerFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/provider') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $providerFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $mentionsBypassTerm = $content -match 'HttpClient\(' -or $content -match 'RetryScheduler' -or $content -match 'RateLimiter' -or $content -match 'NegativeCache'
  $usesGatewayRegistration = $content -match 'ProviderGateway|ProviderRegistration|GatewayBoundProvider'
  if ($mentionsBypassTerm -and -not $usesGatewayRegistration) {
    throw "Provider file may bypass ProviderGateway: $($file.FullName)"
  }
}

$allDart = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($file in $requiredFiles | Where-Object { $_ -like 'lib/src/*.dart' -or $_ -like 'lib/src/**/*.dart' }) {
  $exportPath = $file.Replace('lib/', '')
  if ($barrel -notmatch [regex]::Escape("export '$exportPath';")) {
    throw "Public barrel missing export: $exportPath"
  }
}

$phase3Files = @(
  'lib/src/domain/detail/video_detail.dart',
  'lib/src/domain/media/media_library.dart',
  'lib/src/domain/seasonal/seasonal_anime.dart',
  'lib/src/domain/subtitle/subtitle_provider_bridge.dart',
  'lib/src/provider/subtitle/subtitle_provider.dart',
  'lib/src/provider/rss/feed_contracts.dart',
  'lib/src/provider/rss/yuc_wiki_feed_source.dart',
  'docs/phase3-detail-library-seasonal.md'
)
$forbiddenScopeTerms = @('auto-download', 'autoDownload', 'rule-source', 'ruleSource', 'torrent', 'BitTorrent', 'BT playback', 'Anime4K', 'VLC fallback', 'WebView challenge', 'DNS policy')
foreach ($file in $phase3Files) {
  $content = Get-Content -LiteralPath (Join-Path $root $file) -Raw
  foreach ($term in $forbiddenScopeTerms) {
    if ($file -notlike 'docs/*' -and $content -match [regex]::Escape($term)) {
      throw "Forbidden Phase 4+ implementation term '$term' found in $file"
    }
  }
}

'Detail/library/seasonal checks passed.'
