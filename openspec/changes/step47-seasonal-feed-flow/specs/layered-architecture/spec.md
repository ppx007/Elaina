## ADDED Requirements

### Requirement: Step 47 seasonal feed flow SHALL preserve UI and provider boundaries
Step 47 seasonal feed flow work SHALL compose RSS and seasonal Domain/runtime
contracts without adding Flutter UI ownership or leaking concrete feed transport
and parser packages into seasonal Domain files.

#### Scenario: Seasonal feed flow is implemented
- **WHEN** Step 47 adds the seasonal feed flow runtime, tests, tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  concrete HTTP/XML details remain outside Domain seasonal files, and UI-owned
  code may consume only Domain/runtime contracts and projections
