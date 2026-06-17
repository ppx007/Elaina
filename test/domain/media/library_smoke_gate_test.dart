import 'package:flutter_test/flutter_test.dart';

import '../../../tools/library_smoke_gate.dart';

void main() {
  test('library smoke gate composes scan import detail playback and history',
      () async {
    final LibrarySmokeGateResult result = await runLibrarySmokeGate();

    expect(result.scannedCandidateCount, 2);
    expect(result.importedItemCount, 2);
    expect(result.detailEpisodeCount, 2);
    expect(result.handoffUri.isScheme('file'), isTrue);
    expect(result.continueWatchingPosition, const Duration(minutes: 6));
    expect(result.continueWatchingDuration, const Duration(minutes: 24));
    expect(result.historyEventCount, greaterThanOrEqualTo(2));
    expect(result.bindingEventCount, 2);
    expect(result.replayedContinueWatching, isTrue);
  });
}
