$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $root 'lib'
$requiredFiles = @(
  'pubspec.yaml',
  'analysis_options.yaml',
  'lib/elaina.dart',
  'lib/src/foundation/layers/layer_manifest.dart',
  'lib/src/foundation/extension_points.dart',
  'lib/src/foundation/storage/storage_contracts.dart',
  'lib/src/foundation/storage/seasonal_storage_contracts.dart',
  'lib/src/foundation/gateway/provider_gateway.dart',
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'lib/src/foundation/foundation_runtime.dart',
  'lib/src/foundation/foundation_bootstrap.dart',
  'lib/src/foundation/layer_boundary_checker.dart',
  'lib/src/foundation/deterministic_storage_foundation.dart'
)

$requiredDirs = @(
  'lib/src/ui',
  'lib/src/domain',
  'lib/src/playback',
  'lib/src/provider',
  'lib/src/gateway',
  'lib/src/storage',
  'lib/src/streaming',
  'lib/src/network'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required foundation file: $file"
  }
}

foreach ($dir in $requiredDirs) {
  $path = Join-Path $root $dir
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required foundation directory: $dir"
  }
}

$storageContracts = @(
  Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/storage_contracts.dart') -Raw
  Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/seasonal_storage_contracts.dart') -Raw
) -join "`n"
$requiredStorageTerms = @(
  'MediaLibraryStore',
  'PlaybackHistoryRepository',
  'ProviderBindingRepository',
  'SubtitleCacheStore',
  'StoredSubtitleSearchCacheRecord',
  'StoredSubtitleContentCacheRecord',
  'RssFeedStore',
  'StoredFeedSourceRecord',
  'StoredFeedItemRecord',
  'StoredFeedCursorRecord',
  'StoredFeedDedupeKeyRecord',
  'SeasonalCatalogStore',
  'StoredSeasonalCatalogEntryRecord',
  'BangumiMatchQueueStore',
  'StoredBangumiMatchQueueItemRecord',
  'StoredBangumiMatchCandidateRecord',
  'mediaLibrary',
  'playbackHistory',
  'providerBinding',
  'subtitleCache',
  'rssFeed',
  'seasonalCatalog',
  'bangumiMatchQueue'
)
foreach ($term in $requiredStorageTerms) {
  if ($storageContracts -notmatch [regex]::Escape($term)) {
    throw "Storage foundation missing media persistence term: $term"
  }
}

$uiPath = Join-Path $lib 'src/ui'
if (Test-Path -LiteralPath $uiPath) {
  $forbidden = @('mpv', 'libmpv', 'vlc', 'bangumi', 'dandanplay', 'libtorrent', 'yuc.wiki')
  $uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $uiFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($term in $forbidden) {
      if ($content -match [regex]::Escape($term)) {
        throw "Forbidden UI concrete dependency '$term' found in $($file.FullName)"
      }
    }
  }
}

$layerRules = @{
  'ui' = @('domain')
  'domain' = @('playback', 'provider', 'gateway', 'storage', 'streaming')
  'playback' = @('streaming')
  'provider' = @('gateway')
  'gateway' = @('storage', 'network')
  'storage' = @()
  'streaming' = @('storage')
  'network' = @()
}

foreach ($fromLayer in $layerRules.Keys) {
  $fromPath = Join-Path $lib "src/$fromLayer"
  if (-not (Test-Path -LiteralPath $fromPath)) {
    continue
  }

  $files = Get-ChildItem -LiteralPath $fromPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($toLayer in $layerRules.Keys) {
      if ($toLayer -eq $fromLayer) {
        continue
      }

      $allowed = $layerRules[$fromLayer] -contains $toLayer
      $singleQuotePattern = "../$toLayer/"
      $packagePattern = "package:elaina/src/$toLayer/"
      $importsLayer = $content.Contains($singleQuotePattern) -or $content.Contains($packagePattern)
      if ($importsLayer -and -not $allowed) {
        throw "Forbidden layer import from '$fromLayer' to '$toLayer' found in $($file.FullName)"
      }
    }
  }
}

$providerPath = Join-Path $lib 'src/provider'
if (Test-Path -LiteralPath $providerPath) {
  $providerFiles = Get-ChildItem -LiteralPath $providerPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
  foreach ($file in $providerFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $bypassTerms = @('HttpClient(', 'RetryScheduler', 'NegativeCache', 'RateLimiter')
    foreach ($term in $bypassTerms) {
      if ($content -match [regex]::Escape($term) -and $content -notmatch 'ProviderGateway|ProviderRegistration') {
        throw "Possible ProviderGateway bypass '$term' found in $($file.FullName)"
      }
    }
  }
}

# Foundation runtime must not contain forbidden dependencies
$foundationRuntimePath = Join-Path $root 'lib/src/foundation/foundation_runtime.dart'
$foundationRuntime = Get-Content -LiteralPath $foundationRuntimePath -Raw
$foundationForbiddenTerms = @(
  'package:flutter', 'mpv', 'libmpv', 'vlc', 'MediaPlayer', 'bangumi',
  'dandanplay', 'yuc.wiki', 'libtorrent', 'DownloadEngineAdapter', 'bt_task_core',
  'HttpClient(', 'DnsClient', 'DoHClient', 'DoTClient', 'ProxyServer',
  'VpnService', 'TunInterface', 'PacketCapture', 'DpiEngine',
  'runJavascript', 'dart:mirrors', 'eval(', 'Function.apply',
  'WebViewController', 'captchaSolver', 'headless', 'Crawler', 'Scraper',
  'remoteTelemetry', 'CrashReporter', 'AnalyticsClient', 'cloudUpload',
  'supportBundleUpload', 'sqlite', 'SQLite', 'drift', 'moor', 'hive',
  'path_provider', 'shared_preferences'
)
foreach ($term in $foundationForbiddenTerms) {
  if ($foundationRuntime -match [regex]::Escape($term)) {
    throw "Foundation runtime bootstrap contains forbidden dependency: $term"
  }
}

# Foundation runtime must contain required terms
$foundationRequiredTerms = @(
  'FoundationRuntime', 'StorageFoundation', 'ProviderGateway',
  'CacheInvalidationBus', 'LayerBoundary', 'elainaLayerManifest'
)
foreach ($term in $foundationRequiredTerms) {
  if ($foundationRuntime -notmatch [regex]::Escape($term)) {
    throw "Foundation runtime bootstrap missing required term: $term"
  }
}

# Layer boundary checker must define forbidden and required terms
$checkerPath = Join-Path $root 'lib/src/foundation/layer_boundary_checker.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw
foreach ($term in @('LayerBoundaryChecker', 'foundationForbiddenTerms', 'foundationRequiredTerms', 'findForbiddenTerms', 'findMissingRequiredTerms', 'validateManifest')) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Layer boundary checker missing required term: $term"
  }
}

# Deterministic storage foundation must expose all store contracts
$storageFoundationPath = Join-Path $root 'lib/src/foundation/deterministic_storage_foundation.dart'
$storageFoundation = Get-Content -LiteralPath $storageFoundationPath -Raw
foreach ($term in @('DeterministicStorageFoundation', 'DeterministicMetadataStore', 'DeterministicBlobCacheStore', 'DeterministicMediaCacheStore', 'DeterministicSettingsStore', 'DeterministicMediaLibraryStore', 'DeterministicPlaybackHistoryRepository', 'DeterministicProviderBindingRepository')) {
  if ($storageFoundation -notmatch [regex]::Escape($term)) {
    throw "Deterministic storage foundation missing required term: $term"
  }
}

# Deterministic storage foundation must not contain concrete adapters
foreach ($term in @('package:flutter', 'drift', 'moor', 'hive', 'HttpClient(', 'DnsClient', 'ProxyServer', 'cloudUpload', 'remoteTelemetry')) {
  if ($storageFoundation -match [regex]::Escape($term)) {
    throw "Deterministic storage foundation contains forbidden dependency: $term"
  }
}

# Public barrel must export foundation surfaces
$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @('foundation_runtime.dart', 'layer_boundary_checker.dart', 'deterministic_storage_foundation.dart', 'foundation_bootstrap.dart')) {
  if ($barrel -notmatch [regex]::Escape($export)) {
    throw "Public barrel missing foundation export: $export"
  }
}

# Foundation bootstrap must exist and compose existing modules
$bootstrapPath = Join-Path $root 'lib/src/foundation/foundation_bootstrap.dart'
if (-not (Test-Path -LiteralPath $bootstrapPath)) {
  throw 'Missing foundation bootstrap module: lib/src/foundation/foundation_bootstrap.dart'
}

$bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw
$bootstrapForbiddenTerms = @(
  'package:flutter', 'mpv', 'libmpv', 'vlc', 'libtorrent', 'yuc.wiki',
  'WebViewController', 'runJavascript', 'dart:mirrors', 'dart:ffi',
  'eval(', 'Function.apply', 'HttpClient(', 'DnsClient', 'DoHClient',
  'DoTClient', 'ProxyServer', 'VpnService', 'TunInterface',
  'PacketCapture', 'DpiEngine', 'remoteTelemetry', 'CrashReporter',
  'AnalyticsClient', 'cloudUpload', 'SQLite', 'sqlite', 'dart:io'
)
foreach ($term in $bootstrapForbiddenTerms) {
  if ($bootstrap -match [regex]::Escape($term)) {
    throw "Foundation bootstrap contains forbidden dependency: $term"
  }
}

# Foundation bootstrap must define required contract surfaces
$requiredBootstrapTerms = @(
  'FoundationBootstrap',
  'DeterministicStorageFoundation',
  'FoundationRuntime',
  'LayerBoundaryChecker',
  'foundationBootstrapForbiddenDependencies',
  'foundationBootstrapAllowedExports',
  'elainaLayerManifest'
)
foreach ($term in $requiredBootstrapTerms) {
  if ($bootstrap -notmatch [regex]::Escape($term)) {
    throw "Foundation bootstrap missing required contract surface: $term"
  }
}

'Phase 0 foundation checks passed.'
