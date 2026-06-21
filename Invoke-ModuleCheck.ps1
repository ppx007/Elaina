<#
.SYNOPSIS
Runs a module validation check with shared logging, environment validation, and
failure handling.

.DESCRIPTION
Invoke-ModuleCheck is the shared runner for repository module checks. It can
wrap an existing tools/check_*.ps1 script, execute dependency checks, and run
declarative file/term validation so individual check scripts can be reduced over
time without changing their observable failure behavior.

.PARAMETER ModuleName
Logical module name. Names such as bangumi-runtime and bangumi_runtime resolve
to tools/check_bangumi_runtime.ps1 when legacy script invocation is enabled.

.PARAMETER SkipLegacyScript
Skips the resolved tools/check_*.ps1 invocation and only runs declarative checks
provided through parameters.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [Alias('Module')]
  [ValidateNotNullOrEmpty()]
  [ValidatePattern('^[A-Za-z0-9_.-]+$')]
  [string]$ModuleName,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$ProjectRoot = '.',

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$ToolsDirectory = 'tools',

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$CheckScriptPath,

  [Parameter()]
  [string[]]$DependsOnChecks = @(),

  [Parameter()]
  [string[]]$RequiredFiles = @(),

  [Parameter()]
  [hashtable]$RequiredTermsByFile = @{},

  [Parameter()]
  [hashtable]$ForbiddenTermsByFile = @{},

  [Parameter()]
  [hashtable]$RecursiveForbiddenTermsByPath = @{},

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$RecursiveFileExtension = '.dart',

  [Parameter()]
  [string[]]$DartCheckScripts = @(),

  [Parameter()]
  [string[]]$DartTestPaths = @(),

  [Parameter()]
  [string[]]$ScriptArguments = @(),

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$ScriptArgumentsBase64,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$LogPath,

  [Parameter()]
  [switch]$SkipLegacyScript,

  [Parameter()]
  [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleCheckMinimumPowerShellMajorVersion = 5
$script:ModuleCheckSuccessExitCode = 0
$script:ModuleCheckFailureExitCode = 1
$script:ModuleCheckDefaultScriptPrefix = 'check_'
$script:ModuleCheckScriptExtension = '.ps1'
$script:ModuleCheckWindowsPowerShellCommand = 'powershell.exe'
$script:ModuleCheckDartCommand = 'dart'
$script:ModuleCheckDartTestSubCommand = 'test'
$script:ModuleCheckLogPath = $null

function ConvertTo-CheckStringList {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true)]
    [AllowNull()]
    [object]$Value
  )

  process {
    if ($null -eq $Value) {
      return @()
    }
    if ($Value -is [string]) {
      return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
      $items = @()
      foreach ($item in $Value) {
        if ($null -ne $item) {
          $items += [string]$item
        }
      }
      return $items
    }
    return @([string]$Value)
  }
}

function ConvertFrom-CheckScriptArgumentsBase64 {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Value
  )

  try {
    $bytes = [System.Convert]::FromBase64String($Value)
    $jsonText = [System.Text.Encoding]::UTF8.GetString($bytes)
    $decoded = ConvertFrom-Json -InputObject $jsonText
  } catch {
    throw 'Script arguments payload must be a base64-encoded JSON string array.'
  }

  return @(ConvertTo-CheckStringList -Value $decoded)
}

function ConvertTo-CheckModuleToken {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name
  )

  $token = $Name.Trim()
  if ($token.EndsWith($script:ModuleCheckScriptExtension, [System.StringComparison]::OrdinalIgnoreCase)) {
    $token = [System.IO.Path]::GetFileNameWithoutExtension($token)
  }
  if ($token.StartsWith($script:ModuleCheckDefaultScriptPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    $token = $token.Substring($script:ModuleCheckDefaultScriptPrefix.Length)
  }
  $token = $token -replace '[^A-Za-z0-9]+', '_'
  $token = $token.Trim('_').ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'Module name did not produce a valid check script token.'
  }
  return $token
}

function Get-CheckRelativePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
  )

  $rootFullPath = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\')
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if ($fullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($rootFullPath.Length).TrimStart('\')
  }
  return $fullPath
}

function Resolve-CheckPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter()]
    [switch]$MustExist
  )

  $rootFullPath = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\')
  $candidatePath = $Path
  if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
    $candidatePath = Join-Path $rootFullPath $candidatePath
  }
  $candidateFullPath = [System.IO.Path]::GetFullPath($candidatePath)
  $insideRoot = $candidateFullPath.Equals($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $candidateFullPath.StartsWith("$rootFullPath\", [System.StringComparison]::OrdinalIgnoreCase)
  if (-not $insideRoot) {
    throw "Path '$Path' resolves outside project root '$rootFullPath'."
  }
  if ($MustExist -and -not (Test-Path -LiteralPath $candidateFullPath)) {
    throw "Required path does not exist: $(Get-CheckRelativePath -RootPath $rootFullPath -Path $candidateFullPath)"
  }
  return $candidateFullPath
}

function Write-CheckMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Info', 'Success', 'Warning', 'Error')]
    [string]$Level,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message
  )

  $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = "[$timestamp] [$Level] $Message"
  switch ($Level) {
    'Success' { Write-Host $line -ForegroundColor Green }
    'Warning' { Write-Warning $Message }
    'Error' { Write-Host $line -ForegroundColor Red }
    default { Write-Host $line }
  }

  if ($null -ne $script:ModuleCheckLogPath -and -not $WhatIfPreference) {
    Add-Content -LiteralPath $script:ModuleCheckLogPath -Value $line -Encoding UTF8
  }
}

function Assert-CheckCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CommandName
  )

  if ($null -eq (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "Required command '$CommandName' was not found on PATH."
  }
}

function Assert-CheckEnvironment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ToolRootPath,

    [Parameter()]
    [switch]$RequiresLegacyScriptRunner,

    [Parameter()]
    [switch]$RequiresDart
  )

  if ($PSVersionTable.PSVersion.Major -lt $script:ModuleCheckMinimumPowerShellMajorVersion) {
    throw "PowerShell $($script:ModuleCheckMinimumPowerShellMajorVersion) or newer is required."
  }
  if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
    throw "Project root does not exist: $RootPath"
  }
  if (-not (Test-Path -LiteralPath $ToolRootPath -PathType Container)) {
    throw "Tools directory does not exist: $(Get-CheckRelativePath -RootPath $RootPath -Path $ToolRootPath)"
  }
  if ($RequiresLegacyScriptRunner) {
    Assert-CheckCommand -CommandName $script:ModuleCheckWindowsPowerShellCommand
  }
  if ($RequiresDart) {
    Assert-CheckCommand -CommandName $script:ModuleCheckDartCommand
  }
}

function Get-ModuleCheckScriptPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ToolRootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name
  )

  if ($Name.EndsWith($script:ModuleCheckScriptExtension, [System.StringComparison]::OrdinalIgnoreCase) -or
      $Name.Contains('\') -or
      $Name.Contains('/')) {
    return Resolve-CheckPath -RootPath $RootPath -Path $Name -MustExist
  }

  $token = ConvertTo-CheckModuleToken -Name $Name
  $scriptFileName = "$($script:ModuleCheckDefaultScriptPrefix)$token$($script:ModuleCheckScriptExtension)"
  $scriptPath = Join-Path $ToolRootPath $scriptFileName
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Module check script was not found: $(Get-CheckRelativePath -RootPath $RootPath -Path $scriptPath)"
  }
  return $scriptPath
}

function Assert-RequiredCheckFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter()]
    [string[]]$Files = @()
  )

  foreach ($file in $Files) {
    [void](Resolve-CheckPath -RootPath $RootPath -Path $file -MustExist)
  }
}

function Assert-CheckTermsInFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$File,

    [Parameter()]
    [string[]]$Terms = @(),

    [Parameter(Mandatory = $true)]
    [ValidateSet('Required', 'Forbidden')]
    [string]$Mode
  )

  $path = Resolve-CheckPath -RootPath $RootPath -Path $File -MustExist
  $relativePath = Get-CheckRelativePath -RootPath $RootPath -Path $path
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $Terms) {
    $hasTerm = $content -match [regex]::Escape($term)
    if ($Mode -eq 'Required' -and -not $hasTerm) {
      throw "Required term '$term' missing from $relativePath."
    }
    if ($Mode -eq 'Forbidden' -and $hasTerm) {
      throw "Forbidden term '$term' found in $relativePath."
    }
  }
}

function Assert-CheckTermsInFileMap {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter()]
    [hashtable]$TermsByFile = @{},

    [Parameter(Mandatory = $true)]
    [ValidateSet('Required', 'Forbidden')]
    [string]$Mode
  )

  foreach ($file in $TermsByFile.Keys) {
    $terms = ConvertTo-CheckStringList -Value $TermsByFile[$file]
    Assert-CheckTermsInFile -RootPath $RootPath -File $file -Terms $terms -Mode $Mode
  }
}

function Assert-CheckTermsNotInTree {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter()]
    [string[]]$Terms = @(),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FileExtension
  )

  $scanRoot = Resolve-CheckPath -RootPath $RootPath -Path $Path -MustExist
  $files = Get-ChildItem -LiteralPath $scanRoot -Recurse -File | Where-Object { $_.Extension -eq $FileExtension }
  foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relativePath = Get-CheckRelativePath -RootPath $RootPath -Path $file.FullName
    foreach ($term in $Terms) {
      if ($content -match [regex]::Escape($term)) {
        throw "Forbidden term '$term' found in $relativePath."
      }
    }
  }
}

function Assert-CheckTermsNotInTreeMap {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter()]
    [hashtable]$TermsByPath = @{},

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FileExtension
  )

  foreach ($path in $TermsByPath.Keys) {
    $terms = ConvertTo-CheckStringList -Value $TermsByPath[$path]
    Assert-CheckTermsNotInTree -RootPath $RootPath -Path $path -Terms $terms -FileExtension $FileExtension
  }
}

function Invoke-CheckProcess {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter()]
    [string[]]$ArgumentList = @(),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ActivityName
  )

  $displayCommand = @($FilePath) + $ArgumentList
  $displayText = $displayCommand -join ' '
  if (-not $PSCmdlet.ShouldProcess($displayText, $ActivityName)) {
    return
  }

  Write-CheckMessage -Level Info -Message "$ActivityName`: $displayText"
  & $FilePath @ArgumentList
  $exitCode = $global:LASTEXITCODE
  if ($null -eq $exitCode) {
    $exitCode = $script:ModuleCheckSuccessExitCode
  }
  if ($exitCode -ne $script:ModuleCheckSuccessExitCode) {
    throw "$ActivityName failed with exit code $exitCode."
  }
}

function Invoke-CheckScript {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath,

    [Parameter()]
    [string[]]$Arguments = @()
  )

  $argumentList = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $ScriptPath
  ) + $Arguments
  Invoke-CheckProcess -FilePath $script:ModuleCheckWindowsPowerShellCommand -ArgumentList $argumentList -ActivityName 'Invoke module check script'
}

function Invoke-DartCheckScript {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath
  )

  $path = Resolve-CheckPath -RootPath $RootPath -Path $ScriptPath -MustExist
  Invoke-CheckProcess -FilePath $script:ModuleCheckDartCommand -ArgumentList @($path) -ActivityName 'Invoke Dart check script'
}

function Invoke-DartTestPath {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TestPath
  )

  $path = Resolve-CheckPath -RootPath $RootPath -Path $TestPath -MustExist
  Invoke-CheckProcess -FilePath $script:ModuleCheckDartCommand -ArgumentList @($script:ModuleCheckDartTestSubCommand, $path) -ActivityName 'Invoke Dart test path'
}

function Invoke-ModuleCheck {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ToolRootPath,

    [Parameter()]
    [string]$LegacyScriptPath,

    [Parameter()]
    [string[]]$DependencyChecks = @(),

    [Parameter()]
    [string[]]$Files = @(),

    [Parameter()]
    [hashtable]$RequiredTermMap = @{},

    [Parameter()]
    [hashtable]$ForbiddenTermMap = @{},

    [Parameter()]
    [hashtable]$RecursiveForbiddenTermMap = @{},

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TreeFileExtension,

    [Parameter()]
    [string[]]$DartScripts = @(),

    [Parameter()]
    [string[]]$DartTests = @(),

    [Parameter()]
    [string[]]$LegacyScriptArguments = @(),

    [Parameter()]
    [switch]$DoNotInvokeLegacyScript
  )

  $startedAt = Get-Date
  $requiresLegacyRunner = (-not $DoNotInvokeLegacyScript) -or $DependencyChecks.Count -gt 0
  $requiresDart = $DartScripts.Count -gt 0 -or $DartTests.Count -gt 0
  Assert-CheckEnvironment -RootPath $RootPath -ToolRootPath $ToolRootPath -RequiresLegacyScriptRunner:$requiresLegacyRunner -RequiresDart:$requiresDart

  $hasDeclarativeChecks = $Files.Count -gt 0 -or
    $RequiredTermMap.Count -gt 0 -or
    $ForbiddenTermMap.Count -gt 0 -or
    $RecursiveForbiddenTermMap.Count -gt 0 -or
    $DartScripts.Count -gt 0 -or
    $DartTests.Count -gt 0 -or
    $DependencyChecks.Count -gt 0
  if ($DoNotInvokeLegacyScript -and -not $hasDeclarativeChecks) {
    throw 'No module check actions were configured.'
  }

  Write-CheckMessage -Level Info -Message "Starting module check '$Name'."
  foreach ($dependency in $DependencyChecks) {
    $dependencyPath = Get-ModuleCheckScriptPath -RootPath $RootPath -ToolRootPath $ToolRootPath -Name $dependency
    Invoke-CheckScript -ScriptPath $dependencyPath
  }

  Assert-RequiredCheckFiles -RootPath $RootPath -Files $Files
  Assert-CheckTermsInFileMap -RootPath $RootPath -TermsByFile $RequiredTermMap -Mode Required
  Assert-CheckTermsInFileMap -RootPath $RootPath -TermsByFile $ForbiddenTermMap -Mode Forbidden
  Assert-CheckTermsNotInTreeMap -RootPath $RootPath -TermsByPath $RecursiveForbiddenTermMap -FileExtension $TreeFileExtension

  foreach ($dartScript in $DartScripts) {
    Invoke-DartCheckScript -RootPath $RootPath -ScriptPath $dartScript
  }

  foreach ($dartTest in $DartTests) {
    Invoke-DartTestPath -RootPath $RootPath -TestPath $dartTest
  }

  if (-not $DoNotInvokeLegacyScript) {
    if ([string]::IsNullOrWhiteSpace($LegacyScriptPath)) {
      throw "Legacy check script path was not provided for module '$Name'."
    }
    Invoke-CheckScript -ScriptPath $LegacyScriptPath -Arguments $LegacyScriptArguments
  }

  $duration = (Get-Date) - $startedAt
  Write-CheckMessage -Level Success -Message "Module check '$Name' passed in $([math]::Round($duration.TotalSeconds, 2)) seconds."
  return [pscustomobject]@{
    ModuleName = $Name
    Success = $true
    ExitCode = $script:ModuleCheckSuccessExitCode
    StartedAt = $startedAt
    FinishedAt = Get-Date
    Duration = $duration
  }
}

try {
  $resolvedRoot = Resolve-CheckPath -RootPath $ProjectRoot -Path '.' -MustExist
  $resolvedTools = Resolve-CheckPath -RootPath $resolvedRoot -Path $ToolsDirectory -MustExist

  if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $resolvedLogPath = Resolve-CheckPath -RootPath $resolvedRoot -Path $LogPath
    $logParent = Split-Path -Parent $resolvedLogPath
    if (-not (Test-Path -LiteralPath $logParent -PathType Container)) {
      throw "Log directory does not exist: $(Get-CheckRelativePath -RootPath $resolvedRoot -Path $logParent)"
    }
    $script:ModuleCheckLogPath = $resolvedLogPath
  }

  $effectiveScriptArguments = @($ScriptArguments)
  if (-not [string]::IsNullOrWhiteSpace($ScriptArgumentsBase64)) {
    if ($ScriptArguments.Count -gt 0) {
      throw 'Use either -ScriptArguments or -ScriptArgumentsBase64, not both.'
    }
    $effectiveScriptArguments = ConvertFrom-CheckScriptArgumentsBase64 -Value $ScriptArgumentsBase64
  }

  $resolvedLegacyScript = $null
  if (-not $SkipLegacyScript) {
    if ([string]::IsNullOrWhiteSpace($CheckScriptPath)) {
      $resolvedLegacyScript = Get-ModuleCheckScriptPath -RootPath $resolvedRoot -ToolRootPath $resolvedTools -Name $ModuleName
    } else {
      $resolvedLegacyScript = Resolve-CheckPath -RootPath $resolvedRoot -Path $CheckScriptPath -MustExist
    }
  }

  $result = Invoke-ModuleCheck `
    -Name $ModuleName `
    -RootPath $resolvedRoot `
    -ToolRootPath $resolvedTools `
    -LegacyScriptPath $resolvedLegacyScript `
    -DependencyChecks $DependsOnChecks `
    -Files $RequiredFiles `
    -RequiredTermMap $RequiredTermsByFile `
    -ForbiddenTermMap $ForbiddenTermsByFile `
    -RecursiveForbiddenTermMap $RecursiveForbiddenTermsByPath `
    -TreeFileExtension $RecursiveFileExtension `
    -DartScripts $DartCheckScripts `
    -DartTests $DartTestPaths `
    -LegacyScriptArguments $effectiveScriptArguments `
    -DoNotInvokeLegacyScript:$SkipLegacyScript

  if ($PassThru) {
    $result
  }
} catch {
  Write-CheckMessage -Level Error -Message "Module check '$ModuleName' failed: $($_.Exception.Message)"
  throw
}
