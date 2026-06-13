## ADDED Requirements

### Requirement: Step 21 timeline overlay runtime baseline
The repository SHALL treat Phase 4 Step 21 timeline overlay runtime as an optional, isolated read-model layer over playback, BT, virtual stream, and scheduler projections.

#### Scenario: Core playback remains available without overlay runtime
- **WHEN** timeline overlay runtime is unavailable
- **THEN** core playback, BT task runtime, virtual stream runtime, and piece priority scheduler runtime SHALL remain usable.

### Requirement: Step 21 boundary validation
The repository SHALL include validation that rejects Step 21 timeline overlay runtime leakage into UI rendering, playback control, concrete IO, native player integration, scheduler mutation, BT mutation, diagnostics, or Phase 5 features.

#### Scenario: Checker rejects rendering dependencies
- **WHEN** the Step 21 boundary checker scans timeline overlay runtime files
- **THEN** it SHALL fail if those files import Flutter widget/rendering packages or native player dependencies.
