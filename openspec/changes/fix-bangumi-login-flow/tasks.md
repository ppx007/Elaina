## 1. Workflow

- [x] 1.1 Create change `fix-bangumi-login-flow`.
- [x] 1.2 Add proposal, task list, and spec deltas for Bangumi login behavior.

## 2. Login Boundary

- [x] 2.1 Add a Domain-level Bangumi login controller contract.
- [x] 2.2 Add provider helpers for official OAuth authorization URI
  construction without embedding secrets.
- [x] 2.3 Compose the login controller from app composition using the existing
  settings store and Bangumi auth provider.

## 3. UI Flow

- [x] 3.1 Change tracking-page login actions to start Bangumi authorization
  instead of only navigating to settings.
- [x] 3.2 Change the settings access-token field to validate and refresh
  profile state immediately after token submission.
- [x] 3.3 Surface auth start/save failures without blocking non-Bangumi
  features.

## 4. Validation

- [x] 4.1 Add focused tests for OAuth URI construction, login action dispatch,
  and manual token profile refresh.
- [x] 4.2 Run format, focused tests, Dart analysis, OpenSpec validation, and a
  credential leak scan.
