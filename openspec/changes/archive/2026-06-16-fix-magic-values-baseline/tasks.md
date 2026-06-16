## 1. OpenSpec

- [x] 1.1 Create change `fix-magic-values-baseline`.
- [x] 1.2 Add spec deltas for named runtime defaults, subtitle scoring,
  seasonal match thresholds, and unavailable-provider sentinel policies.
- [x] 1.3 Run `openspec.cmd instructions apply --change "fix-magic-values-baseline" --json`.

## 2. Runtime Defaults

- [x] 2.1 Add named foundation defaults for deterministic contract clock values
  and shared list limits.
- [x] 2.2 Replace repeated production/runtime literals with the named defaults.
- [x] 2.3 Keep tests and runtime smoke checker fixture values local unless they
  assert reusable production policy.

## 3. Domain Policies

- [x] 3.1 Name subtitle scanner confidence scoring values.
- [x] 3.2 Name seasonal Bangumi automatic-match confidence defaults.
- [x] 3.3 Name unavailable provider rate/retry sentinel policies.
- [x] 3.4 Name mock playback observed time and UI demo seek duration.

## 4. Validation

- [x] 4.1 Run focused tests/checkers covering edited runtime slices.
- [x] 4.2 Run `openspec.cmd validate "fix-magic-values-baseline" --strict`.
- [x] 4.3 Run baseline validation gates.

## 5. Archive And Commit

- [x] 5.1 Archive the OpenSpec change after validation passes.
- [x] 5.2 Re-run `openspec.cmd validate --all`.
- [x] 5.3 Check `git status --short`.
- [x] 5.4 Create grouped commits for code and OpenSpec archive changes.
