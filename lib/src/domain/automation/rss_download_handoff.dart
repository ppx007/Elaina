import '../../provider/rss/rss_auto_download_policy.dart';
import '../../streaming/bt_task_core.dart';

final class AutomationDownloadRequest {
  AutomationDownloadRequest({
    required this.candidate,
    Iterable<BtFileIndex> initialFileSelections = const <BtFileIndex>[],
  }) : initialFileSelections =
            List<BtFileIndex>.unmodifiable(initialFileSelections);

  final RssDownloadCandidate candidate;
  final List<BtFileIndex> initialFileSelections;

  BtTaskCreateRequest toBtTaskCreateRequest() {
    final RssDownloadSource downloadSource = candidate.source;
    return BtTaskCreateRequest(
      source: switch (downloadSource) {
        MagnetRssDownloadSource(:final uri) => MagnetBtTaskSource(uri: uri),
        TorrentRssDownloadSource(:final uri) =>
          TorrentDataBtTaskSource(uri: uri),
      },
      initialFileSelections: initialFileSelections,
    );
  }
}

enum AutomationEnqueueOutcomeKind {
  enqueued,
  duplicate,
  unsupported,
  rejected,
  failed,
}

final class AutomationEnqueueOutcome {
  const AutomationEnqueueOutcome({
    required this.kind,
    required this.message,
    this.taskId,
  }) : assert(message != '',
            'Automation enqueue outcome message must not be empty.');

  final AutomationEnqueueOutcomeKind kind;
  final String message;
  final BtTaskId? taskId;
}

abstract interface class AutomationDownloadEnqueuer {
  Future<AutomationEnqueueOutcome> enqueue(AutomationDownloadRequest request);
}
