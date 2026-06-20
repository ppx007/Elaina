## ADDED Requirements

### Requirement: Media Library UI SHALL display scanned folder list
The media library page SHALL display a list of all indexed folders and scan directories configured in [MediaLibraryRuntime](file:///D:/CodeWork/pkpk/lib/src/domain/media/media_library_runtime.dart).

#### Scenario: Render libraries list
- **WHEN** the media library page is loaded
- **THEN** the UI displays list items containing directory paths, scanned counts, and scanner status details retrieved from the runtime

### Requirement: Media Library UI SHALL show scan progress and scanner trigger
The media library page SHALL provide a button to trigger a library scan and show the scanner run progress dynamically.

#### Scenario: Trigger scanner
- **WHEN** the user activates the scan library command button
- **THEN** the UI dispatches a scanner run to [LocalFileMediaLibraryScanner](file:///D:/CodeWork/pkpk/lib/src/domain/media/local_file_media_scanner.dart)
- **AND** displays a progress indicator representing the scan state
