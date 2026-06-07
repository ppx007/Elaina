## ADDED Requirements

### Requirement: Capability matrix SHALL gate advanced caption features explicitly
The playback capability matrix SHALL expose explicit supported or unsupported status and reason strings for Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement before UI or renderer contracts treat those features as executable.

#### Scenario: PGS rendering is unsupported
- **WHEN** the active adapter or platform cannot support PGS subtitle rendering
- **THEN** the capability matrix reports `pgsSubtitleRendering` as unsupported with an explicit reason rather than allowing PGS rendering to appear executable
