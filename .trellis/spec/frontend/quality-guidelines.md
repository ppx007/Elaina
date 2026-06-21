# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

(To be filled by the team)

---

## Testing Requirements

### Widget Test Waiting

Widget tests must wait for observable UI state instead of sleeping for a fixed
duration. Use `test/support/widget_test_waiters.dart` helpers such as
`pumpUntilFound` and `pumpUntilGone` when async UI work needs another frame.

```dart
// Good: waits for the state the test actually needs.
await tester.pumpUntilFound(find.text('Remote Anime'));

// Bad: guesses timing and can hide slow or broken async work.
await tester.pump(const Duration(milliseconds: 100));
```

### Network Images In Widget Tests

Tests that need `NetworkImage` decoding must use
`test/support/network_image_test_overrides.dart`. Do not hand-roll
`HttpClient`, `noSuchMethod`, or image byte mocks inside individual widget test
files.

### Validation Tiers

Use focused validation while iterating:

- `tools/check_changed_tests.ps1 -Scope Fast` for normal small changes.
- `tools/check_changed_tests.ps1 -Scope Module` when UI/domain/provider files
  change together.
- `tools/check_changed_tests.ps1 -Scope Full` only for release-readiness or
  broad refactors.

### Dense Tool Surfaces

Flutter tool pages with tables, side panels, or compact rows must be verified
at the default widget-test viewport, not only at desktop-friendly sizes. This
prevents layouts that look fine on a wide monitor but fail tests with
`RenderFlex overflowed`.

Good:

```dart
const ButtonStyle compactIconButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  maximumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
```

Use a scrollable detail region when fixed header, metadata, file tables, and
footer actions share limited height. Do not stack a fixed-height detail panel
under another fixed area unless the parent has enough bounded space.

When placing `ListTile`, `CheckboxListTile`, or similar ink widgets inside a
decorated panel with a background color, wrap each tile in its own
`Material(color: Colors.transparent)` or use a Material-backed panel. Flutter
asserts when a `DecoratedBox` hides ListTile ink and background effects.

Tests required for dense tool surfaces:

- Render the page at the default widget-test viewport.
- Assert no Flutter layout exceptions are thrown.
- Exercise at least one row action and one detail-panel action.
- Scroll internal detail regions by key when testing content below the fold.


---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
