## ADDED Requirements

### Requirement: Diagnostics center contract SHALL support runtime typed outcomes
The diagnostics center contract SHALL support runtime-level typed outcomes for schema registration, redacted event recording, snapshot filtering, retention enforcement, export description, and capability recording over deterministic contracts.

#### Scenario: Runtime returns typed failure
- **WHEN** a diagnostics runtime operation is unavailable, disposed, unsupported, or fails contract validation
- **THEN** the caller receives a typed diagnostics runtime failure instead of an exception or cross-layer side effect
