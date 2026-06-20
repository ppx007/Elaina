# desktop-video-detail Specification

## Purpose
TBD - created by archiving change ui-milestone2-media-library-and-video-detail. Update Purpose after archive.
## Requirements
### Requirement: Video Detail UI SHALL render from detail view data
The video detail page SHALL render anime descriptions, cover graphics, tags, and episode lists purely using [VideoDetailViewData](file:///D:/CodeWork/elaina/lib/src/domain/detail/video_detail.dart#L42) provided by the controller.

#### Scenario: Render episode list and descriptions
- **WHEN** the video detail page is opened for a specific anime series
- **THEN** it renders the cover art, full description text, follow status
- **AND** displays an interactive grid representing all available episodes

### Requirement: Video Detail UI SHALL support continue playback action
The video detail page SHALL provide a primary action button to resume watching from the user's latest recorded playback position.

#### Scenario: Trigger continue playback
- **WHEN** the user activates the continue playback button in the detail view
- **THEN** the UI dispatches the command to [VideoDetailPageContract.continuePlayback](file:///D:/CodeWork/elaina/lib/src/ui/detail/video_detail_page_contract.dart#L13)
- **AND** navigates the app layout shell to the playback page on success

