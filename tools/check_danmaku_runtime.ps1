$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check_dandanplay_runtime.ps1')

$requiredFiles = @(
  'lib/src/playback/danmaku/danmaku_runtime_state.dart',
  'lib/src/domain/playback/basic_danmaku_state.dart',
  'test/playback/danmaku/basic_danmaku_runtime_test.dart',
  'tools/danmaku_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required basic danmaku runtime file: $file"
  }
}

$playbackDanmakuFiles = @(
  'lib/src/playback/danmaku/danmaku_event.dart',
  'lib/src/playback/danmaku/danmaku_filter.dart',
  'lib/src/playback/danmaku/danmaku_renderer.dart',
  'lib/src/playback/danmaku/danmaku_runtime_state.dart'
)

$forbiddenPlaybackTerms = @(
  'package:flutter',
  'dart:ui',
  'Canvas',
  'CustomPainter',
  'Matrix4',
  'advanced_caption',
  'AdvancedCaption',
  'ProviderGateway',
  'DandanplayProviderRuntime',
  '../../provider',
  '../provider',
  'src/provider',
  '../../foundation/gateway',
  '../../foundation/storage',
  '../../storage',
  '../storage',
  '../../network',
  '../network',
  '../../streaming',
  '../streaming',
  'online_rule',
  'rss',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
  'WebView',
  'http://',
  'https://'
)

foreach ($file in $playbackDanmakuFiles) {
  $path = Join-Path $root $file
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($term in $forbiddenPlaybackTerms) {
    if ($content -match [regex]::Escape($term)) {
      throw "Forbidden basic danmaku playback dependency '$term' found in $file"
    }
  }
}

$runtime = Get-Content -LiteralPath (Join-Path $root 'lib/src/playback/danmaku/danmaku_runtime_state.dart') -Raw
foreach ($term in @(
  'BasicDanmakuRuntime',
  'BasicDanmakuRuntimeSnapshot',
  'BasicDanmakuRuntimeFailureKind',
  'BasicDanmakuRuntimeObserver',
  'resolveFrame',
  'PlayerClockSnapshot'
)) {
  if ($runtime -notmatch [regex]::Escape($term)) {
    throw "Basic danmaku runtime missing required term: $term"
  }
}

$bridge = Get-Content -LiteralPath (Join-Path $root 'lib/src/domain/playback/basic_danmaku_state.dart') -Raw
foreach ($term in @(
  'playbackDanmakuStateFromRuntimeSnapshot',
  'danmakuCommentFromDandanplay',
  'danmakuCommentsFromDandanplay',
  'danmakuModeFromDandanplay'
)) {
  if ($bridge -notmatch [regex]::Escape($term)) {
    throw "Basic danmaku bridge missing required term: $term"
  }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
foreach ($export in @(
  'src/playback/danmaku/danmaku_runtime_state.dart',
  'src/domain/playback/basic_danmaku_state.dart'
)) {
  if ($barrel -notmatch [regex]::Escape("export '$export';")) {
    throw "Public Dart contract barrel missing basic danmaku export: $export"
  }
}

& dart (Join-Path $root 'tools/danmaku_runtime_check.dart')

Write-Output 'Basic danmaku runtime checks passed.'
