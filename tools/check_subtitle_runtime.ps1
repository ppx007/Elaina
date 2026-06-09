$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_player_core.ps1')

$requiredFiles = @(
  'lib/src/playback/subtitle/subtitle_parser.dart',
  'lib/src/playback/subtitle/subtitle_scanner.dart',
  'lib/src/playback/subtitle/subtitle_runtime_state.dart',
  'lib/src/domain/subtitle/basic_subtitle_state.dart',
  'test/playback/subtitle/subtitle_parser_test.dart',
  'test/playback/subtitle/basic_subtitle_runtime_test.dart',
  'tools/subtitle_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required subtitle runtime file: $file"
  }
}

$subtitleRuntimeFiles = @(
  'lib/src/playback/subtitle/subtitle_parser.dart',
  'lib/src/playback/subtitle/subtitle_scanner.dart',
  'lib/src/playback/subtitle/subtitle_runtime_state.dart',
  'lib/src/domain/subtitle/basic_subtitle_state.dart',
  'lib/src/domain/playback/playback_state.dart',
  'lib/src/ui/playback/playback_page_contract.dart'
)

$forbiddenTerms = @(
  'package:flutter',
  'dart:ui',
  'mpv_adapter_facade',
  'deterministic_mpv_binding',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'src/provider/',
  'src/foundation/gateway/',
  'src/foundation/storage/',
  'src/streaming/',
  'src/network/',
  'advanced_caption_rendering',
  'diagnostics',
  'online_rule_runtime',
  'bt_task_core'
)

foreach ($file in $subtitleRuntimeFiles) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden subtitle runtime dependency '$term' found in $file"
    }
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
foreach ($export in @(
  'src/playback/subtitle/subtitle_runtime_state.dart',
  'src/domain/subtitle/basic_subtitle_state.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing subtitle runtime export: $export"
  }
}

Write-Output 'Subtitle runtime checks passed.'
