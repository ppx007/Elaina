## MODIFIED Requirements

### Requirement: Advanced caption rendering contract MUST remain scoped to Step 24
The system MUST keep concrete Flutter widgets, GPU rendering, Matrix4 layout engines, PGS decoders, ASS layout engines, native plugins, FFI, VLC fallback behavior, diagnostics center integration, RSS automation, online rule runtime, WebView handling, network policy, and runtime acceptance layer boundary enforcement outside the advanced caption rendering contract slice.

#### Scenario: Phase 5 checker runs
- **WHEN** boundary checks scan Step 24 contracts
- **THEN** no concrete renderer, decoder, native plugin, FFI, VLC fallback, diagnostics center, Flutter widget, or out-of-scope Phase 6 dependency is required by the advanced caption rendering contract

## ADDED Requirements

### Requirement: Advanced caption rendering contract SHALL expose runtime ActionResult type
The system SHALL define `AdvancedCaptionRuntimeActionResult<T>` with success, failed, unavailable, and disposed variants for typed caption operation outcomes at the runtime acceptance layer.

#### Scenario: Runtime evaluation returns typed result
- **WHEN** `evaluate()` is called via the runtime on a supported scope
- **THEN** the result is an `AdvancedCaptionRuntimeActionResult<CaptionEvaluationOutcome>` with kind `success` containing the evaluation report
