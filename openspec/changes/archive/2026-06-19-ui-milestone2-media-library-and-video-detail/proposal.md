## Why

Users need the ability to browse their indexed local media files and view seasonal/episode details of anime series. Implementing the Media Library and Video Detail screens under the spec-driven workflow is required to achieve the second frontend milestone.

## What Changes

- **Media Library Screen**: Create the `MediaLibraryPage` widget to display recent play histories, folder paths, local file lists, and trigger scanner runs.
- **Media Scan Controller Integration**: Wire the UI to [MediaLibraryRuntime](file:///D:/CodeWork/pkpk/lib/src/domain/media/media_library_runtime.dart) to trigger scans and display scanner status.
- **Video Detail Screen**: Create the `VideoDetailPage` widget to present anime cover graphics, episode grids, description details, follow actions, and quick playback shortcuts.
- **Video Detail Controller Integration**: Wire the UI to [VideoDetailController](file:///D:/CodeWork/pkpk/lib/src/ui/detail/video_detail_page_contract.dart) to fetch metadata and perform episode selection.

## Capabilities

### New Capabilities
- `desktop-media-library`: Shows local media folder scanner status and indexed media file collections.
- `desktop-video-detail`: Presents anime series description, episode lists, follow actions, and play links.

### Modified Capabilities
<!-- No requirement changes to existing core specs. -->
