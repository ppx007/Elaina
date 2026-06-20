# Full Code Review Report - 2026-06-20

## Findings

### 1. RSS add-feed dialog can throw on invalid user URL

- Severity: Medium
- Confidence: High
- Location: `lib/src/ui/rss/rss_page.dart:556`
- Evidence: The dialog passes user-entered text directly to `Uri.parse(url)` inside the async `onPressed` handler. Malformed input can throw instead of producing a typed UI validation error or preserving a recoverable dialog state.
- Impact: User-facing RSS source creation can fail as an uncaught UI exception path. This does not affect core RSS fetch/parse contracts, but it is a real desktop UI robustness gap.
- Recommended fix: Replace with `Uri.tryParse`, validate non-empty scheme/host for HTTP(S) RSS URLs, and show inline dialog feedback before calling `registerSourceParams`.

### 2. Carousel timers keep one integration test skipped and can keep animating while offscreen

- Severity: Medium
- Confidence: High
- Locations:
  - `lib/src/ui/widgets/hero_carousel.dart:53`
  - `lib/src/ui/widgets/hot_updates_carousel.dart:46`
  - `test/ui/playback/media_library_and_video_detail_test.dart:448`
- Evidence: `HeroCarousel` and `HotUpdatesCarousel` start `Timer.periodic` in `initState`. The shell integration test remains `skip: true` because `pumpAndSettle` cannot settle while periodic auto-scroll keeps scheduling work.
- Impact: One UI integration path is not continuously tested. In shell layouts that keep inactive tabs alive, periodic animation can also keep consuming work while the carousel is not visible.
- Recommended fix: Add an `autoScroll` constructor flag defaulting to true, disable it in tests, and gate timer ticks with `TickerMode.of(context)` or an equivalent visibility signal.

### 3. Desktop UI still contains generated placeholder media and demo data

- Severity: Low
- Confidence: High
- Locations:
  - `lib/src/ui/widgets/hero_carousel.dart:20`
  - `lib/src/ui/widgets/hot_updates_carousel.dart:19`
  - `lib/src/ui/playback/shell/celesteria_app_shell.dart:161`
  - `lib/src/ui/playback/shell/celesteria_app_shell.dart:562`
  - `lib/src/ui/playback/shell/celesteria_app_shell.dart:716`
- Evidence: Multiple first-viewport and recommendation surfaces still use `lh3.googleusercontent.com/aida...` assets plus hard-coded titles/ratings. `_hotUpdateDemos` is suppressed with an unused-element TODO.
- Impact: Product polish and data ownership risk. This is not a runtime correctness bug, but it means the desktop UI is still a prototype/demo surface in these areas.
- Recommended fix: Replace placeholder URLs and demo arrays with local assets, runtime projections, or a declared mock-data boundary that is explicitly disabled in production composition.

### 4. Stale analyzer suppression remains in diagnostics domain adapter

- Severity: Low
- Confidence: High
- Location: `lib/src/domain/diagnostics/diagnostics_domain.dart:48`
- Evidence: `_centerRuntime` is now used by `queryEvents()` through `snapshot()`, but `// ignore: unused_field` remains above the field.
- Impact: No behavioral risk, but stale suppressions weaken review signal because future real warnings near that field are easier to ignore.
- Recommended fix: Remove the obsolete suppression comment.

## Validation Evidence

All core gates passed during this review:

- `git status --short` before review: clean
- `openspec.cmd validate --all`: 91 passed, 0 failed
- `dart analyze`: no issues
- `flutter analyze`: no issues
- `flutter test`: 472 passed, 1 skipped
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`: passed
- `powershell -ExecutionPolicy Bypass -File "tools\check_full_feature_gate.ps1"`: passed

The full feature gate also ran OpenSpec validation, Dart/Flutter analysis, full Flutter tests, player core checks, library smoke gate, advanced playback checks, automation extension checks, BT streaming smoke gate, and diagnostics center runtime checks. The native player smoke check was skipped by the script because `libmpv-2.dll` is absent on this machine; the script treats that as an expected local-environment skip, not a project failure.

## Scope Reviewed

- OpenSpec specs and archived desktop UI changes
- Public barrel exports and app composition entry points
- UI shell, playback page, media library, detail, RSS, downloads, settings, diagnostics, widgets, and Windows runner scaffolding
- Runtime slices under domain, provider, playback, streaming, network, foundation, and storage-backed contracts
- Test coverage for domain/runtime contracts, UI widgets, layer import graph, outbound URI guard, smoke gates, and automation extension gates
- Text searches for skipped tests, analyzer suppressions, TODO/FIXME markers, raw URI parsing, direct network/client usage, and UI-to-provider/playback/network/streaming imports

## Confirmed Non-Findings

- No current dirty working-tree files were present at the start of this review.
- No OpenSpec validation failures were found.
- No Dart or Flutter analyzer issues were found.
- No architecture gate failure was found in `check_automation_extension_core.ps1` or `check_full_feature_gate.ps1`.
- The UI layer search did not find direct imports of provider/playback/network/streaming/foundation internals from `lib/src/ui`; matches were limited to tests.
- The previously reported diagnostics `_centerRuntime` design issue is behaviorally resolved: `DiagnosticsRuntimeAdapter.queryEvents()` now calls `_centerRuntime.snapshot()` before reading the diagnostics store. Only the stale ignore comment remains.

## Residual Risk

- UI robustness is still weaker than core runtime robustness. The known risks are localized to generated/demo desktop UI surfaces, not the core playback/provider/storage/network contracts.
- The current test baseline intentionally includes one skipped UI integration test. The skipped test should be treated as technical debt, not as a green coverage signal.
- Native player smoke coverage depends on a local `libmpv-2.dll`; this review could not exercise native MPV playback on this machine.

## Review Conclusion

Core contracts and runtime layers are release-gate clean at high confidence. The remaining actionable defects are UI-layer robustness and productization issues, with no newly found P0/P1 core-runtime blockers.
