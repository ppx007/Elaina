## ADDED Requirements

### Requirement: Downloads Page SHALL render active torrent downloads
The downloads page SHALL display a list of active BT torrent tasks along with details like progress percentage, active peers, download speed, and piece mapping.

#### Scenario: Render download list
- **WHEN** the downloads page is opened
- **THEN** it renders progress bars, download speed (in MB/s), active peer counts, and status indicators fetched from [BtTaskCoreRuntime](file:///D:/CodeWork/pkpk/lib/src/streaming/bt_task_core_runtime.dart)

### Requirement: Downloads Page SHALL support torrent task control operations
The downloads page SHALL provide controls to pause, resume, and remove active BT torrent download tasks.

#### Scenario: Pause active download
- **WHEN** the user clicks the pause button on a downloading torrent task
- **THEN** the UI dispatches a pause command to the download manager in [BtTaskCoreRuntime]
- **AND** updates the task's visual status to paused
