$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  'tools/check_full_feature_gate.ps1',
  'tools/check_full_feature_gate_contract.ps1',
  'docs/full-feature-gate.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required Step 60 full feature gate file: $file"
  }
}

$gate = Get-Content -LiteralPath (Join-Path $root 'tools/check_full_feature_gate.ps1') -Raw
$requiredGateTerms = @(
  'openspec.cmd validate --all',
  'dart analyze',
  'flutter analyze',
  'flutter test',
  'check_player_core.ps1',
  'check_player_smoke_gate.ps1',
  'check_acg_data_experience.ps1',
  'check_library_smoke_gate.ps1',
  'check_advanced_playback_core.ps1',
  'check_automation_extension_core.ps1',
  'check_bt_streaming_smoke_gate.ps1',
  'check_diagnostics_center_runtime.ps1',
  'check_full_feature_gate_contract.ps1',
  'LibMpvPath',
  'SampleMediaPath',
  'RequireNativeSmoke',
  'SkipNativePlayerSmoke'
)
foreach ($term in $requiredGateTerms) {
  if ($gate -notmatch [regex]::Escape($term)) {
    throw "Full feature gate missing required term: $term"
  }
}

$forbiddenGateTerms = @(
  'lib/src/ui',
  'lib/main.dart',
  'windows/',
  'setx',
  '[Environment]::SetEnvironmentVariable',
  'PathMachine',
  'PathUser',
  'Invoke-WebRequest',
  'Start-Process',
  'remoteTelemetry',
  'cloudUpload',
  'supportBundleUpload'
)
foreach ($term in $forbiddenGateTerms) {
  if ($gate -match [regex]::Escape($term)) {
    throw "Full feature gate contains forbidden term: $term"
  }
}

$doc = Get-Content -LiteralPath (Join-Path $root 'docs/full-feature-gate.md') -Raw
foreach ($term in @(
  'Step 60',
  'non-UI',
  'tools\check_full_feature_gate.ps1',
  'openspec.cmd validate --all',
  'dart analyze',
  'flutter analyze',
  'flutter test',
  '-RequireNativeSmoke',
  '-SkipNativePlayerSmoke',
  'UI Boundary'
)) {
  if ($doc -notmatch [regex]::Escape($term)) {
    throw "Full feature gate doc missing required term: $term"
  }
}

foreach ($path in @('lib/src/ui', 'windows')) {
  $fullPath = Join-Path $root $path
  if (Test-Path -LiteralPath $fullPath) {
    $matches = Get-ChildItem -Path $fullPath -Recurse -File |
      Select-String -Pattern 'FullFeatureGate|check_full_feature_gate|RequireNativeSmoke'
    if ($matches) {
      throw "Step 60 full feature gate details leaked into $path"
    }
  }
}

$mainPath = Join-Path $root 'lib/main.dart'
if (Test-Path -LiteralPath $mainPath) {
  $mainContent = Get-Content -LiteralPath $mainPath -Raw
  foreach ($term in @('FullFeatureGate', 'check_full_feature_gate', 'RequireNativeSmoke')) {
    if ($mainContent -match [regex]::Escape($term)) {
      throw "Step 60 full feature gate detail '$term' leaked into lib/main.dart"
    }
  }
}

Write-Output 'Full feature gate contract checks passed.'
