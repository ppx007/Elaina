$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$requiredFiles = @(
  'lib/src/provider/online/online_rule_source_runtime.dart',
  'lib/src/provider/online/online_rule_runtime.dart',
  'test/provider/online/online_rule_source_runtime_test.dart',
  'test/provider/online/online_rule_runtime_contract_test.dart',
  'tools/runtime_checks/online_rule_source_runtime_contract.dart',
  'docs/online-rule-evaluator.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required online rule source runtime file: $file"
  }
}

$runtimeFile = Join-Path $root 'lib/src/provider/online/online_rule_source_runtime.dart'
$onlineRuleRuntimeFile = Join-Path $root 'lib/src/provider/online/online_rule_runtime.dart'

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
$onlineRuleRuntime = Get-Content -LiteralPath $onlineRuleRuntimeFile -Raw
foreach ($term in $requiredRuntimeTerms) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Online rule source runtime missing required term: $term"
  }
}

$requiredStep48Terms = @(
  'OnlineExtractionKind.cssSelector',
  'OnlineExtractionKind.xpath1',
  'OnlineExtractionKind.regex',
  'unsupportedSelector',
  'attribute'
)
foreach ($term in $requiredStep48Terms) {
  if ($onlineRuleRuntime -notmatch [regex]::Escape($term)) {
    throw "Online rule evaluator missing Step 48 term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/provider/online/online_rule_runtime.dart',
  'src/provider/online/online_rule_source_runtime.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing online rule export: $export"
  }
}

$checker = Get-Content -LiteralPath (Join-Path $root 'tools/runtime_checks/online_rule_source_runtime_contract.dart') -Raw
$requiredCheckerTerms = @(
  'OnlineRuleSourceRuntimeBootstrap',
  'OnlineRuleSourceRuntime',
  'OnlineRuleSourceRuntimeActionResult',
  'OnlineRuleSourceRuntimeFailureKind',
  'OnlineRuleSourceRuntimeRestartProjection',
  'OnlineRuleSourceRuntimeProjection',
  'OnlineRuleCapabilityMatrix',
  'DeterministicOnlineRuleRuntimeStore',
  'UnsupportedOnlineOperationKind.unsupportedSelector',
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
  'tools/runtime_checks/online_rule_source_runtime_contract.dart'
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

$step48FilesToScan = @(
  'lib/src/provider/online/online_rule_runtime.dart',
  'lib/src/provider/online/online_rule_source_runtime.dart',
  'test/provider/online/online_rule_runtime_contract_test.dart',
  'test/provider/online/online_rule_source_runtime_test.dart',
  'tools/runtime_checks/online_rule_source_runtime_contract.dart'
)

$step48ForbiddenTerms = @(
  'HttpClient',
  'package:flutter/',
  'WebViewController',
  'runJavascript',
  'dart:js',
  'package:js',
  'js_interop',
  'dart:ffi',
  'dart:mirrors',
  'package:html',
  'package:webview',
  'Crawler',
  'Scraper',
  'libtorrent',
  'rss_auto_download',
  'yuc.wiki',
  'DiagnosticsCenter'
)

foreach ($file in $step48FilesToScan) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $step48ForbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden Step 48 boundary term '$term' found in $file"
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

& dart (Join-Path $root 'tools/runtime_checks/online_rule_source_runtime_contract.dart')

Write-Output 'Online rule source runtime checks passed.'

