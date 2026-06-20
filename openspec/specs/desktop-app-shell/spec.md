# desktop-app-shell Specification

## Purpose
TBD - created by archiving change ui-milestone1-setup-and-playback-shell. Update Purpose after archive.
## Requirements
### Requirement: Desktop app entry point SHALL launch a Flutter application on Windows
The system SHALL provide `lib/main.dart` that initializes and starts the Flutter application runner targeting Windows desktop.

#### Scenario: Running the desktop app opens a window
- **WHEN** the application starts via `lib/main.dart` on a Windows host
- **THEN** a window is displayed and mounts the root Flutter application widget

### Requirement: Root app shell SHALL initialize and dispose core composition runtimes once
The application shell SHALL manage the lifetime of the core player runtime composition, initializing it at startup and properly disposing of it on application exit.

#### Scenario: App startup initializes runtimes
- **WHEN** the application launches
- **THEN** the composition root instantiates the player core runtime composition once
- **AND** makes the controller and runtime instances available to UI screens

#### Scenario: App shutdown disposes runtimes
- **WHEN** the application is closed by the user
- **THEN** the composition root invokes the dispose methods on the player core runtime composition to release all native player handles and file streams

### Requirement: App layout SHALL provide a responsive navigation rail
The application layout SHALL display a navigation rail or sidebar allowing users to switch between the key pages of the application.

#### Scenario: Layout renders sidebar icons
- **WHEN** the application shell is rendered
- **THEN** it displays a navigation rail showing icons for Home, Media Library, Playback, Downloads, RSS, Settings, and Diagnostics

