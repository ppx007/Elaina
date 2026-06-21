param(
  [string]$LibMpvPath,
  [string]$SampleMediaPath,
  [switch]$RequireNativeSmoke,
  [switch]$SkipNativeSmoke
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$libMpvFileName = 'libmpv-2.dll'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("elaina-player-smoke-" + [System.Guid]::NewGuid().ToString('N'))

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

  return $null
}

function New-TemporarySampleMedia([string]$TargetPath) {
  $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($null -eq $ffmpeg) {
    return $false
  }

  & $ffmpeg.Source -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=160x90:rate=10" -t 1 -pix_fmt yuv420p $TargetPath
  if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg failed to generate temporary smoke sample: $TargetPath"
  }
  return Test-Path -LiteralPath $TargetPath -PathType Leaf
}

function Assert-TempChild([string]$Path) {
  $fullTemp = Resolve-FullPath ([System.IO.Path]::GetTempPath())
  $fullPath = Resolve-FullPath $Path
  if (-not $fullPath.StartsWith($fullTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean non-temp smoke path: $fullPath"
  }
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
  $resolvedLibMpv = Resolve-LibMpvDll $LibMpvPath
  if ([string]::IsNullOrWhiteSpace($resolvedLibMpv)) {
    if ($RequireNativeSmoke) {
      throw "Missing $libMpvFileName. Pass -LibMpvPath or set CELESTERIA_LIBMPV_PATH."
    }
    Write-Output "Player smoke gate skipped native checks: missing $libMpvFileName."
    return
  }

  $releaseDir = Join-Path $tempRoot 'release'
  $distDir = Join-Path $tempRoot 'dist'
  New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
  New-Item -ItemType Directory -Force -Path $distDir | Out-Null
  Set-Content -LiteralPath (Join-Path $releaseDir 'Elaina.exe') -Value 'temporary smoke executable'

  $zipPath = Join-Path $distDir 'elaina-player-smoke.zip'
  & powershell -ExecutionPolicy Bypass -File (Join-Path (Join-Path $root 'tools') 'package_windows_release.ps1') -ReleaseDir $releaseDir -LibMpvPath $resolvedLibMpv -OutputZip $zipPath
  if ($LASTEXITCODE -ne 0) {
    throw 'Windows release package smoke failed.'
  }

  if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
    throw "Windows release package smoke did not create zip: $zipPath"
  }

  if ($SkipNativeSmoke) {
    Write-Output "Player smoke gate skipped non-UI playback smoke by request."
    Write-Output "Player smoke gate passed release packaging smoke."
    return
  }

  $samplePath = $SampleMediaPath
  if ([string]::IsNullOrWhiteSpace($samplePath)) {
    $samplePath = Join-Path $tempRoot 'sample.mp4'
    if (-not (New-TemporarySampleMedia $samplePath)) {
      if ($RequireNativeSmoke) {
        throw 'Missing sample media and ffmpeg is unavailable to generate one.'
      }
      Write-Output 'Player smoke gate skipped non-UI playback smoke: missing sample media and ffmpeg.'
      Write-Output 'Player smoke gate passed release packaging smoke.'
      return
    }
  }

  $resolvedSamplePath = Resolve-FullPath $samplePath
  if (-not (Test-Path -LiteralPath $resolvedSamplePath -PathType Leaf)) {
    throw "Sample media file does not exist: $resolvedSamplePath"
  }

  & dart run (Join-Path (Join-Path $root 'tools') 'media_kit_mpv_binding_smoke.dart') --libmpv $resolvedLibMpv $resolvedSamplePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Non-UI media_kit/libmpv playback smoke failed.'
  }

  Write-Output 'Player smoke gate passed release packaging and non-UI playback smoke.'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Assert-TempChild $tempRoot
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}

