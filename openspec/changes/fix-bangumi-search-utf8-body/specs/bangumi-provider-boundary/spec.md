## ADDED Requirements

### Requirement: Bangumi HTTP transport SHALL write JSON bodies as UTF-8 bytes
Concrete Bangumi HTTP requests with JSON bodies SHALL encode the body as UTF-8
bytes before writing it to the socket.

#### Scenario: Search body contains Chinese text
- **WHEN** Bangumi search sends a JSON body containing a Chinese keyword
- **THEN** the transport writes UTF-8 bytes rather than a raw Dart string
- **AND** the `Content-Type` header declares `application/json; charset=utf-8`
- **AND** the request still uses ProviderGateway proxy and network policy
  context

#### Scenario: Non-search POST body contains non-ASCII text
- **WHEN** any Bangumi POST or PATCH request body contains non-ASCII text
- **THEN** the same UTF-8 body encoding path is used
- **AND** no UI-side fallback or alternate endpoint is used
