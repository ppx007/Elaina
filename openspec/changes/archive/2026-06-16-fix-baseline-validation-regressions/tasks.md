## 1. OpenSpec

- [x] 1.1 Create change `fix-baseline-validation-regressions`.
- [x] 1.2 Add spec deltas for playback handoff isolation and virtual stream
  skipped-file semantics.
- [x] 1.3 Apply change instructions before implementation.

## 2. Playback Boundary

- [x] 2.1 Replace Streaming descriptor/snapshot handoff inputs with
  playback-owned virtual stream descriptor inputs.
- [x] 2.2 Remove Streaming imports from playback source handoff and virtual
  stream playback source code.
- [x] 2.3 Update tests and smoke checks to map Streaming runtime projections at
  the caller boundary.

## 3. Validation Cleanup

- [x] 3.1 Update virtual stream contract test to expect `fileSkipped` for
  skipped selected files.
- [x] 3.2 Replace checker-script `print` calls with analyzer-clean stdout
  writes.
- [x] 3.3 Run focused and baseline validation commands.

## 4. Archive

- [x] 4.1 Archive the OpenSpec change after validation passes.
- [x] 4.2 Re-run global OpenSpec validation and report git status.
