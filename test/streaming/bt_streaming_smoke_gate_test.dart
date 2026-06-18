import 'package:flutter_test/flutter_test.dart';

import '../../tools/bt_streaming_smoke_gate.dart';

void main() {
  test('BT streaming smoke gate composes task stream and priority path',
      () async {
    final BtStreamingSmokeGateResult result = await runBtStreamingSmokeGate();

    expect(result.taskId, '55');
    expect(result.streamId, '55::1');
    expect(result.metadataFileCount, 2);
    expect(result.selectedFileIndex, 1);
    expect(result.streamCreated, isTrue);
    expect(result.bytesServed, 16);
    expect(
        result.servedBytes, List<int>.generate(16, (int index) => index + 2));
    expect(result.bufferedRangeCount, 1);
    expect(result.planRuleCount, greaterThan(0));
    expect(result.priorityApplied, isTrue);
    expect(result.filePriorities, <int>[0, 1]);
  });
}
