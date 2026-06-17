## ADDED Requirements

### Requirement: Online rule runtime SHALL evaluate supplied documents with bounded concrete extraction
The online rule runtime SHALL evaluate supplied document content with concrete
regex extraction, CSS selector subset extraction, and XPath subset extraction
instead of marker-style placeholder matching.

#### Scenario: CSS selector target is evaluated
- **WHEN** an operation declares a supported CSS selector and the supplied
  document contains a matching element
- **THEN** the runtime extracts the requested text or attribute value into the
  typed evaluation result without exposing raw selector internals to UI or
  playback layers

#### Scenario: XPath target is evaluated
- **WHEN** an operation declares a supported XPath subset expression and the
  supplied document contains a matching element
- **THEN** the runtime extracts the requested text or attribute value into the
  typed evaluation result

#### Scenario: Regex target is evaluated
- **WHEN** an operation declares a safe regex expression and the supplied
  document contains a match
- **THEN** the runtime extracts the first capture group when present, otherwise
  the whole match

### Requirement: Online rule runtime SHALL reject unsupported selector syntax
The online rule runtime SHALL validate unsupported CSS and XPath syntax as
typed `unsupportedSelector` issues rather than silently falling back, throwing
parser-specific exceptions, or executing arbitrary code.

#### Scenario: Unsupported selector is declared
- **WHEN** a manifest declares selector syntax outside the bounded Step 48 CSS
  or XPath subset
- **THEN** validation returns an unsupported-selector issue associated with the
  operation and evaluation does not execute that operation

### Requirement: Online rule runtime SHALL keep executable operations disabled
The Step 48 evaluator SHALL keep JavaScript, WASM, scriptlet, arbitrary code,
browser DOM execution, and unsafe regex operations outside the runtime.

#### Scenario: Executable operation is declared
- **WHEN** a manifest declares JavaScript, WASM, scriptlet, arbitrary code, or
  unsafe regex behavior
- **THEN** validation records a typed unsupported-operation issue and the
  supplied-document evaluator does not execute it
