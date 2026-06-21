<#
.SYNOPSIS
Runs the smallest useful validation set for the current change.

.DESCRIPTION
check_changed_tests.ps1 selects focused tests from changed paths so small UI
and provider edits do not require the full release gate on every iteration.
Use -Scope Full for the existing release-readiness gate.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter()]
  [ValidateSet('Fast', 'Module', 'Full')]
  [string]$Scope = 'Fast',

  [Parameter()]
  [string[]]$ChangedPath = @(),

  [Parameter()]
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CheckChangedDartCommand = 'dart'
$script:CheckChangedFlutterCommand = 'flutter'
$script:CheckChangedPowerShellCommand = 'powershell'
$script:CheckChangedSuccessExitCode = 0

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function ConvertTo-CheckPathToken {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
  )

  return ($Path -replace '\\', '/').Trim()
}

function Add-CheckPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Set,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
  )

  $normalizedPath = ConvertTo-CheckPathToken -Path $Path
  if (-not $Set.ContainsKey($normalizedPath)) {
    $Set[$normalizedPath] = $true
  }
}

function Add-ExistingCheckPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Set,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
  )

  if (Test-Path -LiteralPath (Join-Path $projectRoot $Path)) {
    Add-CheckPath -Set $Set -Path $Path
  }
}

function Get-ChangedCheckPaths {
  [CmdletBinding()]
  param()

  if ($ChangedPath.Count -gt 0) {
    return @($ChangedPath | ForEach-Object { ConvertTo-CheckPathToken -Path $_ })
  }

  $tracked = @(& git -C $projectRoot diff --name-only HEAD)
  $untracked = @(& git -C $projectRoot ls-files --others --exclude-standard)
  return @(
    $tracked + $untracked |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ConvertTo-CheckPathToken -Path $_ }
  )
}

function Invoke-CheckCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Executable,

    [Parameter()]
    [string[]]$Arguments = @()
  )

  $displayCommand = @($Executable) + $Arguments
  Write-Output "Changed test gate: $Name"
  Write-Output "  $($displayCommand -join ' ')"
  if ($DryRun -or -not $PSCmdlet.ShouldProcess($Name, 'run validation command')) {
    return
  }

  & $Executable @Arguments
  if ($LASTEXITCODE -ne $script:CheckChangedSuccessExitCode) {
    throw "Changed test gate step failed: $Name"
  }
}

function Add-UiCheckPaths {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][hashtable]$FlutterTests)

  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/ui/hero_carousel_test.dart'
  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/widget_test.dart'
}

function Add-DetailUiCheckPaths {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][hashtable]$FlutterTests)

  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/ui/playback/media_library_and_video_detail_test.dart'
  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/widget_test.dart'
}

function Add-BangumiCheckPaths {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][hashtable]$FlutterTests)

  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/provider/bangumi/bangumi_runtime_test.dart'
  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/domain/profile/bangumi_tracking_local_store_test.dart'
}

function Add-DetailDomainCheckPaths {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][hashtable]$FlutterTests)

  Add-ExistingCheckPath -Set $FlutterTests -Path 'test/domain/detail/video_detail_runtime_test.dart'
}

function Get-TargetedChecks {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string[]]$Paths)

  $flutterTests = @{}
  $dartTests = @{}
  $sawUiChange = $false
  $sawBangumiChange = $false
  $sawDetailChange = $false

  foreach ($path in $Paths) {
    if ($path -like 'test/tools/*') {
      Add-ExistingCheckPath -Set $dartTests -Path 'test/tools'
      continue
    }
    if ($path -like 'test/support/*') {
      Add-UiCheckPaths -FlutterTests $flutterTests
      Add-DetailUiCheckPaths -FlutterTests $flutterTests
      continue
    }
    if ($path -like 'test/*.dart' -or $path -like 'test/*/*.dart' -or $path -like 'test/*/*/*.dart') {
      Add-ExistingCheckPath -Set $flutterTests -Path $path
    }

    if ($path -like 'lib/src/ui/widgets/hero_carousel.dart' -or
        $path -like 'test/ui/hero_carousel_test.dart') {
      $sawUiChange = $true
      Add-UiCheckPaths -FlutterTests $flutterTests
    }

    if ($path -like 'lib/src/ui/detail/*' -or
        $path -like 'lib/src/ui/playback/shell/*' -or
        $path -like 'test/ui/playback/media_library_and_video_detail_test.dart') {
      $sawUiChange = $true
      Add-DetailUiCheckPaths -FlutterTests $flutterTests
    }

    if ($path -like 'lib/src/domain/profile/bangumi_tracking_local_store.dart' -or
        $path -like 'lib/src/provider/bangumi/*' -or
        $path -like 'test/provider/bangumi/*' -or
        $path -like 'test/domain/profile/bangumi_tracking_local_store_test.dart') {
      $sawBangumiChange = $true
      Add-BangumiCheckPaths -FlutterTests $flutterTests
    }

    if ($path -like 'lib/src/domain/detail/*' -or
        $path -like 'test/domain/detail/*') {
      $sawDetailChange = $true
      Add-DetailDomainCheckPaths -FlutterTests $flutterTests
    }

    if ($path -like 'tools/runtime_check_base.dart' -or
        $path -like 'tools/*_runtime_check.dart') {
      Add-ExistingCheckPath -Set $dartTests -Path 'test/tools'
    }
  }

  if ($Scope -eq 'Module') {
    if ($sawUiChange) {
      Add-UiCheckPaths -FlutterTests $flutterTests
      Add-DetailUiCheckPaths -FlutterTests $flutterTests
    }
    if ($sawBangumiChange) {
      Add-BangumiCheckPaths -FlutterTests $flutterTests
      Add-DetailDomainCheckPaths -FlutterTests $flutterTests
    }
    if ($sawDetailChange) {
      Add-DetailDomainCheckPaths -FlutterTests $flutterTests
      Add-DetailUiCheckPaths -FlutterTests $flutterTests
    }
  }

  return [pscustomobject]@{
    FlutterTests = @($flutterTests.Keys | Sort-Object)
    DartTests = @($dartTests.Keys | Sort-Object)
  }
}

Push-Location $projectRoot
try {
  if ($Scope -eq 'Full') {
    Invoke-CheckCommand `
      -Name 'full feature gate' `
      -Executable $script:CheckChangedPowerShellCommand `
      -Arguments @('-ExecutionPolicy', 'Bypass', '-File', 'tools\check_full_feature_gate.ps1')
    return
  }

  $paths = @(Get-ChangedCheckPaths)
  Write-Output "Changed test gate scope: $Scope"
  if ($paths.Count -eq 0) {
    Write-Output 'Changed test gate: no changed paths detected.'
  } else {
    Write-Output 'Changed test gate paths:'
    foreach ($path in $paths) {
      Write-Output "  $path"
    }
  }

  $checks = Get-TargetedChecks -Paths $paths
  Invoke-CheckCommand `
    -Name 'dart analyze' `
    -Executable $script:CheckChangedDartCommand `
    -Arguments @('analyze')

  if ($checks.DartTests.Count -gt 0) {
    Invoke-CheckCommand `
      -Name 'dart targeted tests' `
      -Executable $script:CheckChangedDartCommand `
      -Arguments (@('test') + $checks.DartTests)
  }

  if ($checks.FlutterTests.Count -gt 0) {
    Invoke-CheckCommand `
      -Name 'flutter targeted tests' `
      -Executable $script:CheckChangedFlutterCommand `
      -Arguments (@('test') + $checks.FlutterTests)
  } else {
    Write-Output 'Changed test gate: no targeted Flutter tests selected.'
  }
} finally {
  Pop-Location
}
