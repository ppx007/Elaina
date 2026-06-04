$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $root 'lib'
$requiredFiles = @(
  'pubspec.yaml',
  'analysis_options.yaml',
  'lib/celesteria.dart',
  'lib/src/foundation/layers/layer_manifest.dart',
  'lib/src/foundation/extension_points.dart',
  'lib/src/foundation/storage/storage_contracts.dart',
  'lib/src/foundation/gateway/provider_gateway.dart',
  'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
  'docs/phase0-foundation.md',
  'docs/phase0-storage-schema.md',
  'docs/next-change-player-core.md',
  'lib/src/ui/README.md',
  'lib/src/domain/README.md',
  'lib/src/playback/README.md',
  'lib/src/provider/README.md',
  'lib/src/gateway/README.md',
  'lib/src/storage/README.md',
  'lib/src/streaming/README.md',
  'lib/src/network/README.md'
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

$storageContracts = Get-Content -LiteralPath (Join-Path $root 'lib/src/foundation/storage/storage_contracts.dart') -Raw
$requiredStorageTerms = @(
  'MediaLibraryStore',
  'PlaybackHistoryRepository',
  'ProviderBindingRepository',
  'SubtitleCacheStore',
  'StoredSubtitleSearchCacheRecord',
  'StoredSubtitleContentCacheRecord',
  'mediaLibrary',
  'playbackHistory',
  'providerBinding',
  'subtitleCache'
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
      $packagePattern = "package:celesteria/src/$toLayer/"
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

'Phase 0 foundation checks passed.'
