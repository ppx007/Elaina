## Context

This design outlines how the Media Library and Video Detail UI pages integrate with the respective domain-layer services. It governs visual display and triggers, ensuring layers are kept isolated.

## Goals / Non-Goals

**Goals:**
- Construct a card-based Media Library view presenting local folders, scanner status, and scan progress.
- Construct a details screen showing descriptions, action buttons (Follow/Unfollow), and episode selectors.
- Connect widgets to the respective stream and future descriptors exposed by [MediaLibraryRuntime](file:///D:/CodeWork/elaina/lib/src/domain/media/media_library_runtime.dart) and [VideoDetailPageContract](file:///D:/CodeWork/elaina/lib/src/ui/detail/video_detail_page_contract.dart).

**Non-Goals:**
- Implementing online scraping or custom subtitle indexing directly in the UI layer.
- Changing storage or network policies during scanning.

## Decisions

### 1. Stream-backed Detail Observation
- **Choice**: The `VideoDetailPage` widget will subscribe to the `watch()` stream exposed by [VideoDetailPageContract](file:///D:/CodeWork/elaina/lib/src/ui/detail/video_detail_page_contract.dart#L11) instead of performing manual loads.
- **Rationale**: Any state change (e.g., episode watched, followed state) propagates naturally through the DB to the stream, updating the UI automatically.

### 2. Standardized Card Component
- **Choice**: Implement a reusable `GlassmorphicCard` widget matching the design token properties.
- **Rationale**: Prevents duplicated container styling and ensures consistent margin, border-radius, and stroke highlights across the library grid and episode lists.

## Risks / Trade-offs

- **[Risk] Heavy scan results delay UI thread updates** → **Mitigation**: The scan runtime already performs disk operations asynchronously. The UI will simply observe state updates and rebuild using lightweight animations.
