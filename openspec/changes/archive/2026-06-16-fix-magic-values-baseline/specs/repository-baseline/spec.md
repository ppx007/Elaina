## ADDED Requirements

### Requirement: Repository baseline SHALL name reusable runtime policy literals
Production and runtime scaffold code SHALL express reusable deterministic
defaults, thresholds, limits, and sentinel policies through named constants or
configuration objects rather than repeated inline literals.

#### Scenario: Runtime defaults are shared
- **WHEN** multiple runtime or storage-facing components use the same default
  clock value, page limit, or history limit
- **THEN** they reference a named baseline default rather than duplicating the
  literal value at each call site

#### Scenario: Fixture values remain local
- **WHEN** a test or smoke checker uses a value only as scenario data
- **THEN** that value may remain local to the fixture and does not need to be
  promoted into production defaults

#### Scenario: Documented domain thresholds remain explicit
- **WHEN** a literal represents a documented domain rule such as AV sync drift
  thresholds
- **THEN** it may remain close to the policy definition if the field names and
  surrounding contract already provide the semantic meaning
