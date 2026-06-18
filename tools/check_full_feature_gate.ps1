param(
  [string]$LibMpvPath,
  [string]$SampleMediaPath,
  [switch]$RequireNativeSmoke,
  [switch]$SkipNativePlayerSmoke
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Invoke-GateStep([string]$Name, [scriptblock]$Command) {
  Write-Output "Full feature gate: $Name"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Full feature gate step failed: $Name"
  }
}

function Invoke-Checker([string]$ScriptName) {
  Invoke-GateStep $ScriptName {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $ScriptName)
  }
}

Push-Location $root
try {
  Invoke-GateStep 'openspec validate --all' {
    & openspec.cmd validate --all
  }

  Invoke-GateStep 'full feature gate contract' {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_full_feature_gate_contract.ps1')
  }

  Invoke-GateStep 'dart analyze' {
    & dart analyze
  }

  Invoke-GateStep 'flutter analyze' {
    & flutter analyze
  }

  Invoke-GateStep 'flutter test' {
    & flutter test
  }

  Invoke-Checker 'check_player_core.ps1'
  Invoke-Checker 'check_acg_data_experience.ps1'
  Invoke-Checker 'check_library_smoke_gate.ps1'
  Invoke-Checker 'check_advanced_playback_core.ps1'
  Invoke-Checker 'check_automation_extension_core.ps1'
  Invoke-Checker 'check_bt_streaming_smoke_gate.ps1'
  Invoke-Checker 'check_diagnostics_center_runtime.ps1'

  Invoke-GateStep 'check_player_smoke_gate.ps1' {
    $playerSmokeArgs = @(
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      (Join-Path $PSScriptRoot 'check_player_smoke_gate.ps1')
    )
    if (-not [string]::IsNullOrWhiteSpace($LibMpvPath)) {
      $playerSmokeArgs += @('-LibMpvPath', $LibMpvPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($SampleMediaPath)) {
      $playerSmokeArgs += @('-SampleMediaPath', $SampleMediaPath)
    }
    if ($RequireNativeSmoke) {
      $playerSmokeArgs += '-RequireNativeSmoke'
    }
    if ($SkipNativePlayerSmoke) {
      $playerSmokeArgs += '-SkipNativeSmoke'
    }
    & powershell @playerSmokeArgs
  }

  Write-Output 'Full feature gate checks passed.'
} finally {
  Pop-Location
}
