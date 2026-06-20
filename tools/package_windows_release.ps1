param(
  [string]$ReleaseDir,
  [string]$LibMpvPath,
  [string]$OutputZip,
  [switch]$SkipZip
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$libMpvFileName = 'libmpv-2.dll'

if ([string]::IsNullOrWhiteSpace($ReleaseDir)) {
  $ReleaseDir = Join-Path $root 'build\windows\x64\runner\Release'
}
if ([string]::IsNullOrWhiteSpace($OutputZip)) {
  $OutputZip = Join-Path $root 'build\dist\celesteria-windows-x64.zip'
}

function Resolve-FullPath([string]$Path) {
  return [System.IO.Path]::GetFullPath($Path)
}

function Resolve-LibMpvDll([string]$Candidate) {
  $paths = @()
  if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
    $paths += $Candidate
  }
  if (-not [string]::IsNullOrWhiteSpace($env:CELESTERIA_LIBMPV_PATH)) {
    $paths += $env:CELESTERIA_LIBMPV_PATH
  }
  $paths += Join-Path $root '.cache\native\media-kit-libmpv\extracted'

  foreach ($path in $paths) {
    $fullPath = Resolve-FullPath $path
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
      if ((Split-Path -Leaf $fullPath) -ne $libMpvFileName) {
        throw "Libmpv path must point to $libMpvFileName, got: $fullPath"
      }
      return $fullPath
    }
    if (Test-Path -LiteralPath $fullPath -PathType Container) {
      $dllPath = Join-Path $fullPath $libMpvFileName
      if (Test-Path -LiteralPath $dllPath -PathType Leaf) {
        return $dllPath
      }
    }
  }

  throw "Missing $libMpvFileName. Pass -LibMpvPath or set CELESTERIA_LIBMPV_PATH to a DLL or directory."
}

function Assert-WindowsReleaseDirectory([string]$Directory) {
  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
    throw "Windows release directory does not exist: $Directory"
  }

  $executables = Get-ChildItem -LiteralPath $Directory -File -Filter '*.exe'
  if ($executables.Count -eq 0) {
    throw "Windows release directory must contain an application .exe: $Directory"
  }
}

function Assert-ZipContainsReleaseFiles([string]$ZipPath) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    $hasExe = $false
    $hasLibMpv = $false
    foreach ($entryName in $entryNames) {
      if ($entryName -match '^[^/]+\.exe$') {
        $hasExe = $true
      }
      if ($entryName -eq $libMpvFileName) {
        $hasLibMpv = $true
      }
    }
    if (-not $hasExe) {
      throw "Release zip is missing a root application .exe: $ZipPath"
    }
    if (-not $hasLibMpv) {
      throw "Release zip is missing root ${libMpvFileName}: $ZipPath"
    }
  } finally {
    $archive.Dispose()
  }
}

$resolvedReleaseDir = Resolve-FullPath $ReleaseDir
Assert-WindowsReleaseDirectory $resolvedReleaseDir

$resolvedLibMpv = Resolve-LibMpvDll $LibMpvPath
$targetLibMpv = Join-Path $resolvedReleaseDir $libMpvFileName
Copy-Item -LiteralPath $resolvedLibMpv -Destination $targetLibMpv -Force

if (-not (Test-Path -LiteralPath $targetLibMpv -PathType Leaf)) {
  throw "Failed to stage $libMpvFileName beside the app executable: $targetLibMpv"
}

if ($SkipZip) {
  Write-Output "Windows release staging passed: $resolvedReleaseDir"
  return
}

$resolvedOutputZip = Resolve-FullPath $OutputZip
$outputDirectory = Split-Path -Parent $resolvedOutputZip
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (Test-Path -LiteralPath $resolvedOutputZip) {
  Remove-Item -LiteralPath $resolvedOutputZip -Force
}

Compress-Archive -Path (Join-Path $resolvedReleaseDir '*') -DestinationPath $resolvedOutputZip -Force
Assert-ZipContainsReleaseFiles $resolvedOutputZip

Write-Output "Windows release package created: $resolvedOutputZip"
