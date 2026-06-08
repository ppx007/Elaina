## ADDED Requirements

### Requirement: WebView session backfill SHALL define a manual challenge lifecycle
The system SHALL model provider challenge handling as an explicit manual lifecycle covering challenge detection, user-opened isolated completion, completed session capture, backfill attempt, success, failure, expiry, and revocation states.

#### Scenario: Challenge is detected
- **WHEN** a provider or ProviderGateway boundary reports that a request requires manual challenge completion
- **THEN** the system records a manual challenge request with provider id, origin, request purpose, state, and normalized reason instead of attempting automated completion

#### Scenario: Challenge lifecycle completes
- **WHEN** a user manually completes the challenge and session artifacts are captured
- **THEN** the lifecycle advances through completed and captured states before any provider retry descriptor can be produced

### Requirement: WebView session backfill SHALL reject automated challenge completion
The system SHALL reject contracts or operations that imply captcha solving, challenge bypass, credential guessing, bot-style completion, headless automation, or hidden browser interaction.

#### Scenario: Automation behavior is requested
- **WHEN** a provider declares a challenge operation that requires automatic captcha solving, challenge bypass, or bot-style completion
- **THEN** the backfill contract reports an unsupported operation and does not produce session artifacts

### Requirement: WebView session backfill SHALL scope artifacts by provider and origin
The system SHALL bind captured session artifacts to a provider identity and origin scope, and MUST NOT allow artifacts captured for one provider or origin to be reused by unrelated providers or cross-origin requests.

#### Scenario: Cross-origin reuse is attempted
- **WHEN** a backfill retry requests artifacts for an origin that does not match the captured artifact origin and allowed domain/path scope
- **THEN** the backfill contract rejects the retry descriptor and reports a normalized scope failure

### Requirement: WebView session backfill SHALL normalize cookie and token artifacts
The system SHALL represent captured artifacts as normalized contracts containing provider id, origin, cookie name, value reference, domain, path, expiry, secure flag, SameSite state, capture time, approval state, and optional provider token metadata.

#### Scenario: Session artifacts are captured
- **WHEN** an isolated manual WebView flow captures same-origin cookies or approved provider tokens
- **THEN** the artifacts are converted into normalized artifact records before storage or ProviderGateway handoff

### Requirement: WebView session backfill SHALL enforce expiry and revocation
The system SHALL treat expired or revoked session artifacts as inactive and MUST NOT attach them to provider retry descriptors.

#### Scenario: Artifact is expired
- **WHEN** a provider retry is prepared using an artifact whose expiry has passed or whose state is revoked
- **THEN** the retry descriptor is rejected and the challenge lifecycle reports that a fresh manual completion is required

### Requirement: WebView session backfill SHALL expose platform capability limits
The system SHALL expose isolated WebView capture, same-origin artifact capture, cookie backfill, provider token backfill, and persistent session support through capability contracts.

#### Scenario: Platform lacks isolated WebView capture
- **WHEN** the current platform cannot provide isolated manual WebView capture
- **THEN** the provider session boundary reports backfill as unsupported while preserving provider flows that do not require manual challenge completion
