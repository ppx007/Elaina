$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  'lib/src/provider/online/online_rule_source_runtime.dart',
  'lib/src/provider/online/online_rule_runtime.dart',
  'test/provider/online/online_rule_source_runtime_test.dart',
  'test/provider/online/online_rule_runtime_contract_test.dart',
  'tools/online_rule_source_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required online rule source runtime file: $file"
  }
}

$runtimeFile = Join-Path $root 'lib/src/provider/online/online_rule_source_runtime.dart'

$requiredRuntimeTerms = @(
  'OnlineRuleSourceRuntimeFailureKind',
  'OnlineRuleSourceRuntimeFailure',
  'OnlineRuleSourceRuntimeActionResultKind',
  'OnlineRuleSourceRuntimeActionResult',
  'OnlineRuleSourceRuntimeRestartProjection',
  'OnlineRuleSourceRuntimeProjection',
  'OnlineRuleSourceRuntimeBootstrap',
  'OnlineRuleSourceRuntime',
  'capabilityUnsupported',
  'unavailable',
  'disposed',
  'manifestNotFound',
  'manifestDisabled',
  'manifestInvalid',
  'evaluationFailed',
  'sourceUnsupported'
)

$runtime = Get-Content -LiteralPath $runtimeFile -Raw
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Online rule source runtime missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/provider/online/online_rule_runtime.dart',
  'src/provider/online/online_rule_source_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing online rule export: $export"
  }
}

$checker = Get-Content -LiteralPath (Join-Path $root 'tools/online_rule_source_runtime_check.dart') -Raw
$requiredCheckerTerms = @(
  'OnlineRuleSourceRuntimeBootstrap',
  'OnlineRuleSourceRuntime',
  'OnlineRuleSourceRuntimeActionResult',
  'OnlineRuleSourceRuntimeFailureKind',
  'OnlineRuleSourceRuntimeRestartProjection',
  'OnlineRuleSourceRuntimeProjection',
  'OnlineRuleCapabilityMatrix',
  'DeterministicOnlineRuleRuntimeStore',
  '_expect'
)
foreach ($term in $requiredCheckerTerms) {
  if ($checker -notmatch [regex]::Escape($term)) {
    throw "Online rule source runtime checker missing required term: $term"
  }
}

$forbiddenTerms = @(
  'ProviderGateway',
  'HttpClient',
  'Crawler',
  'WebView',
  'captcha',
  'DNS',
  'proxy',
  'DiagnosticsCenter',
  'package:flutter/',
  'yuc.wiki',
  'libtorrent',
  'registerSource',
  'refreshManifest'
)

$filesToScan = @(
  'lib/src/provider/online/online_rule_source_runtime.dart',
  'test/provider/online/online_rule_source_runtime_test.dart',
  'tools/online_rule_source_runtime_check.dart'
)

foreach ($file in $filesToScan) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden boundary term '$term' found in $file"
    }
  }
}

$importGuards = @(
  '../../foundation/gateway',
  '../../network',
  'package:flutter'
)
foreach ($term in $importGuards) {
  if ($runtime -match [regex]::Escape($term)) {
    throw "Online rule source runtime contains forbidden import: $term"
  }
}

& dart (Join-Path $root 'tools/online_rule_source_runtime_check.dart')

Write-Output 'Online rule source runtime checks passed.'
