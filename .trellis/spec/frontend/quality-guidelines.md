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


---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
