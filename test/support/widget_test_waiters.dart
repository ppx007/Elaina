import 'package:flutter_test/flutter_test.dart';

const int defaultWidgetWaitPumpLimit = 20;
const Duration defaultWidgetWaitPumpStep = Duration(milliseconds: 16);

extension WidgetTesterWaiters on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    int maxPumps = defaultWidgetWaitPumpLimit,
    Duration step = defaultWidgetWaitPumpStep,
  }) async {
    await _pumpUntil(
      finder: finder,
      maxPumps: maxPumps,
      step: step,
      isSatisfied: any,
      failurePrefix: 'Expected widget was not found',
    );
  }

  Future<void> pumpUntilGone(
    Finder finder, {
    int maxPumps = defaultWidgetWaitPumpLimit,
    Duration step = defaultWidgetWaitPumpStep,
  }) async {
    await _pumpUntil(
      finder: finder,
      maxPumps: maxPumps,
      step: step,
      isSatisfied: (Finder target) => !any(target),
      failurePrefix: 'Expected widget was still present',
    );
  }

  Future<void> _pumpUntil({
    required Finder finder,
    required int maxPumps,
    required Duration step,
    required bool Function(Finder finder) isSatisfied,
    required String failurePrefix,
  }) async {
    if (maxPumps < 1) {
      throw ArgumentError.value(maxPumps, 'maxPumps', 'must be positive');
    }
    for (int pumpCount = 0; pumpCount < maxPumps; pumpCount++) {
      if (isSatisfied(finder)) return;
      await pump(step);
    }
    if (isSatisfied(finder)) return;
    throw TestFailure('$failurePrefix after $maxPumps pumps: $finder');
  }
}
