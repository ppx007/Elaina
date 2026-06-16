## MODIFIED Requirements

### Requirement: Local subtitle scanning SHALL be deterministic and media-adjacent
The basic subtitle core SHALL provide local subtitle scanning that discovers
SRT, VTT, and ASS candidates associated with an already-selected local media
value through deterministic media-adjacent inputs. Match confidence values SHALL
come from named scoring policy constants so exact basename, language-suffix, and
contains-stem matches can be reviewed and tuned without editing branch-local
magic numbers.

#### Scenario: Media-adjacent subtitles are discovered
- **WHEN** local media has adjacent subtitle candidates matching the supported
  subtitle formats
- **THEN** the scanner returns external subtitle candidates with normalized
  sources and named confidence scoring semantics without provider lookup,
  database access, broad filesystem traversal, network requests, or native
  player startup
