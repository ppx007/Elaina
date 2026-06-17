$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_player_core.ps1')

$requiredFiles = @(
  'lib/src/playback/player_clock.dart',
  'lib/src/playback/subtitle/subtitle_source.dart',
  'lib/src/playback/subtitle/subtitle_cue.dart',
  'lib/src/playback/subtitle/subtitle_parser.dart',
  'lib/src/playback/subtitle/subtitle_scanner.dart',
  'lib/src/playback/subtitle/subtitle_offset.dart',
  'lib/src/provider/provider_result.dart',
  'lib/src/provider/gateway_bound_provider.dart',
  'lib/src/provider/bangumi/bangumi_provider.dart',
  'lib/src/provider/bangumi/bangumi_auth.dart',
  'lib/src/provider/bangumi/bangumi_api_client.dart',
  'lib/src/provider/bangumi/bangumi_registration.dart',
  'lib/src/provider/dandanplay/dandanplay_provider.dart',
  'lib/src/provider/dandanplay/dandanplay_comments.dart',
  'lib/src/provider/dandanplay/dandanplay_api_client.dart',
  'lib/src/provider/dandanplay/dandanplay_registration.dart',
  'lib/src/playback/danmaku/danmaku_event.dart',
  'lib/src/playback/danmaku/danmaku_filter.dart',
  'lib/src/playback/danmaku/danmaku_renderer.dart',
  'lib/src/domain/acg/acg_data_controller.dart',
  'lib/src/domain/acg/acg_experience_runtime.dart',
  'lib/src/domain/playback/playback_metadata_bridge.dart',
  'tools/acg_experience_runtime_check.dart',
  'tools/playback_metadata_bridge_runtime_check.dart',
  'docs/phase2-acg-data-experience.md',
  'docs/bangumi-api-client.md',
  'docs/dandanplay-api-client.md',
  'docs/playback-metadata-bridge.md',
  'docs/acg-experience-smoke-gate.md',
  'docs/next-change-detail-library-seasonal.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required ACG data file: $file"
  }
}

$uiPath = Join-Path $root 'lib/src/ui'
$forbiddenUiTerms = @('bangumi', 'dandanplay', 'ProviderGateway', 'ProviderContract')
$uiFiles = Get-ChildItem -LiteralPath $uiPath -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $uiFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($term in $forbiddenUiTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden ACG/provider UI dependency '$term' found in $($file.FullName)"
    }
  }
}

$providerFiles = Get-ChildItem -LiteralPath (Join-Path $root 'lib/src/provider') -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $providerFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $mentionsBypassTerm = $content -match 'HttpClient\(' -or $content -match 'RetryScheduler' -or $content -match 'RateLimiter' -or $content -match 'NegativeCache'
  $usesGatewayRegistration = $content -match 'ProviderGateway|ProviderRegistration'
  if ($mentionsBypassTerm -and -not $usesGatewayRegistration) {
    throw "Provider file may bypass ProviderGateway: $($file.FullName)"
  }
}

$bangumiProvider = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/bangumi/bangumi_provider.dart') -Raw
if ($bangumiProvider -notmatch 'implements GatewayBoundProvider') {
  throw 'BangumiProvider must implement GatewayBoundProvider.'
}

$dandanplayProvider = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/dandanplay/dandanplay_provider.dart') -Raw
if ($dandanplayProvider -notmatch 'implements GatewayBoundProvider') {
  throw 'DandanplayProvider must implement GatewayBoundProvider.'
}

$gatewayBoundProvider = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/gateway_bound_provider.dart') -Raw
if ($gatewayBoundProvider -notmatch 'ProviderGateway get gateway' -or $gatewayBoundProvider -notmatch 'executeGatewayRequest') {
  throw 'GatewayBoundProvider must require gateway access and gateway request execution.'
}

$providerResult = Get-Content -LiteralPath (Join-Path $root 'lib/src/provider/provider_result.dart') -Raw
if ($providerResult -notmatch 'acgFailureKindFromGateway' -or $providerResult -notmatch 'throttled' -or $providerResult -notmatch 'cachedMiss') {
  throw 'ACG provider failures must map ProviderGateway failure semantics.'
}

$acgController = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/acg/acg_data_controller.dart') -Raw
$requiredControllerMethods = @('bangumiEpisode', 'bangumiSession', 'searchDandanplay', 'postDandanplayComment')
foreach ($method in $requiredControllerMethods) {
  if ($acgController -notmatch $method) {
    throw "AcgDataController missing method: $method"
  }
}

$subtitleScanner = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/subtitle/subtitle_scanner.dart') -Raw
if ($subtitleScanner -match 'Provider') {
  throw 'Local subtitle scanner must not reference providers.'
}

$danmakuRenderer = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/danmaku/danmaku_renderer.dart') -Raw
if ($danmakuRenderer -notmatch 'PlayerClockSnapshot') {
  throw 'Danmaku renderer must be driven by PlayerClockSnapshot.'
}

$metadataBridge = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/playback/playback_metadata_bridge.dart') -Raw
$requiredMetadataBridgeTerms = @(
  'PlaybackMetadataBridge',
  'PlaybackMetadataBridgeSnapshot',
  'loadProviderSubtitle',
  'loadPreparedSubtitle',
  'loadDandanplayComments',
  'loadDandanplayCommentValues',
  'BasicSubtitleRuntime',
  'BasicDanmakuRuntime',
  'SubtitleProviderRuntime',
  'DandanplayCommentProvider',
  'PlayerClockSnapshot',
  'PlaybackSubtitleStateSnapshot',
  'PlaybackDanmakuStateSnapshot',
  'applyTo'
)
foreach ($term in $requiredMetadataBridgeTerms) {
  if ($metadataBridge -notmatch [regex]::Escape($term)) {
    throw "Playback metadata bridge missing required term: $term"
  }
}
foreach ($term in @('BangumiApiClient', 'DandanplayApiClient', 'OpenSubtitlesApiClient', 'HttpOpenSubtitlesApiTransport', 'HttpClient(', 'package:flutter', 'libmpv', 'media_kit', 'MpvAdapterBinding', 'WebViewController', 'DownloadEngineAdapter')) {
  if ($metadataBridge -match [regex]::Escape($term)) {
    throw "Playback metadata bridge contains forbidden concrete dependency: $term"
  }
}

$acgExperience = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/acg/acg_experience_runtime.dart') -Raw
$requiredAcgExperienceTerms = @(
  'AcgExperienceRuntime',
  'AcgExperienceRequest',
  'AcgExperienceResult',
  'AcgExperienceFailure',
  'AcgDataController',
  'SubtitleProviderRuntime',
  'PlaybackMetadataBridge',
  'PlaybackMetadataBridgeSnapshot',
  'DandanplayMatchCandidate',
  'BangumiSubject',
  'PlaybackStateSnapshot'
)
foreach ($term in $requiredAcgExperienceTerms) {
  if ($acgExperience -notmatch [regex]::Escape($term)) {
    throw "ACG experience runtime missing required term: $term"
  }
}
foreach ($term in @('BangumiApiClient', 'DandanplayApiClient', 'OpenSubtitlesApiClient', 'HttpOpenSubtitlesApiTransport', 'HttpClient(', 'package:flutter', 'libmpv', 'media_kit', 'MpvAdapterBinding', 'WebViewController', 'DownloadEngineAdapter')) {
  if ($acgExperience -match [regex]::Escape($term)) {
    throw "ACG experience runtime contains forbidden concrete dependency: $term"
  }
}

'ACG data experience checks passed.'
