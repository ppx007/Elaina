<#
.SYNOPSIS
Runs the smallest useful validation set for the current change.

.DESCRIPTION
check_changed_tests.ps1 selects focused tests from changed paths through
tools/test_suites.json so path rules stay declarative. Use -Scope Full for the
existing release-readiness gate.
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
$script:TestSuiteRegistryPath = 'tools\test_suites.json'

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

function ConvertTo-PathPattern {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Pattern
  )

  $normalizedPattern = ConvertTo-CheckPathToken -Path $Pattern
  return $normalizedPattern -replace '\*\*', '*'
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

function Read-TestSuiteRegistry {
  [CmdletBinding()]
  param()

  $registryPath = Join-Path $projectRoot $script:TestSuiteRegistryPath
  if (-not (Test-Path -LiteralPath $registryPath)) {
    throw "Test suite registry was not found: $script:TestSuiteRegistryPath"
  }
  return Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
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

function Test-SuiteScope {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Suite
  )

  $suiteScopes = @($Suite.scopes)
  if ($Scope -eq 'Fast') {
    return $suiteScopes -contains 'Fast'
  }
  if ($Scope -eq 'Module') {
    return ($suiteScopes -contains 'Fast') -or ($suiteScopes -contains 'Module')
  }
  return $false
}

function Test-PathMatchesSuite {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [pscustomobject]$Suite
  )

  foreach ($trigger in @($Suite.triggers)) {
    $pattern = ConvertTo-PathPattern -Pattern ([string]$trigger)
    if ($Path -like $pattern) {
      return $true
    }
  }
  return $false
}

function Get-SelectedTestSuites {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Registry,

    [Parameter(Mandatory = $true)]
    [string[]]$Paths
  )

  $selectedByName = @{}
  foreach ($suite in @($Registry.suites)) {
    if (-not (Test-SuiteScope -Suite $suite)) {
      continue
    }
    foreach ($path in $Paths) {
      if (Test-PathMatchesSuite -Path $path -Suite $suite) {
        $selectedByName[$suite.name] = $suite
        break
      }
    }
  }
  return @($selectedByName.Values | Sort-Object -Property name)
}

function ConvertTo-RunnerGroups {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Suites
  )

  $dartTests = @{}
  $flutterTests = @{}
  $flutterExtraArgs = @{}

  foreach ($suite in $Suites) {
    $runner = [string]$suite.runner
    foreach ($path in @($suite.paths)) {
      if ($runner -eq 'dart') {
        Add-ExistingCheckPath -Set $dartTests -Path ([string]$path)
      } elseif ($runner -eq 'flutter') {
        Add-ExistingCheckPath -Set $flutterTests -Path ([string]$path)
      } else {
        throw "Unsupported test suite runner '$runner' in suite '$($suite.name)'."
      }
    }

    if ($runner -eq 'flutter' -and $suite.PSObject.Properties.Name -contains 'extraArgs') {
      $extraArgs = @($suite.extraArgs | ForEach-Object { [string]$_ })
      if ($extraArgs.Count -gt 0) {
        foreach ($path in @($suite.paths)) {
          $normalizedPath = ConvertTo-CheckPathToken -Path ([string]$path)
          $flutterExtraArgs[$normalizedPath] = $extraArgs
        }
      }
    }
  }

  return [pscustomobject]@{
    DartTests = @($dartTests.Keys | Sort-Object)
    FlutterTests = @($flutterTests.Keys | Sort-Object)
    FlutterExtraArgs = $flutterExtraArgs
  }
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

function Invoke-FlutterTestGroups {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,

    [Parameter(Mandatory = $true)]
    [hashtable]$ExtraArgsByPath
  )

  $defaultPaths = @(
    $Paths |
      Where-Object { -not $ExtraArgsByPath.ContainsKey($_) }
  )
  if ($defaultPaths.Count -gt 0) {
    Invoke-CheckCommand `
      -Name 'flutter targeted tests' `
      -Executable $script:CheckChangedFlutterCommand `
      -Arguments (@('test') + $defaultPaths)
  }

  foreach ($path in @($Paths | Where-Object { $ExtraArgsByPath.ContainsKey($_) })) {
    Invoke-CheckCommand `
      -Name "flutter targeted test $path" `
      -Executable $script:CheckChangedFlutterCommand `
      -Arguments (@('test', $path) + @($ExtraArgsByPath[$path]))
  }
}

Push-Location $projectRoot
try {
  $registry = Read-TestSuiteRegistry
  if ($Scope -eq 'Full') {
    Invoke-CheckCommand `
      -Name 'full feature gate' `
      -Executable $script:CheckChangedPowerShellCommand `
      -Arguments @('-ExecutionPolicy', 'Bypass', '-File', $registry.fullGate)
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

  $suites = @(Get-SelectedTestSuites -Registry $registry -Paths $paths)
  if ($suites.Count -gt 0) {
    Write-Output 'Changed test gate suites:'
    foreach ($suite in $suites) {
      Write-Output "  $($suite.name)"
    }
  }

  $checks = ConvertTo-RunnerGroups -Suites $suites
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
    Invoke-FlutterTestGroups `
      -Paths $checks.FlutterTests `
      -ExtraArgsByPath $checks.FlutterExtraArgs
  } else {
    Write-Output 'Changed test gate: no targeted Flutter tests selected.'
  }
} finally {
  Pop-Location
}
