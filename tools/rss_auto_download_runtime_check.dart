import 'dart:io';

import '../lib/celesteria.dart';

void main() {
  verifyRssAutoDownloadPolicyRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> verifyRssAutoDownloadPolicyRuntimeContract() async {
  // --- Harness setup ---
  final DeterministicRssAutoDownloadPolicyStore policyStore =
      DeterministicRssAutoDownloadPolicyStore();

  final DeterministicRssAutomationHistoryStore historyStore =
      DeterministicRssAutomationHistoryStore();

  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();

  final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
      const DeterministicRssAutoDownloadPolicyEvaluator();

  final RssAutoDownloadPolicy policy = RssAutoDownloadPolicy(
    id: RssAutoDownloadPolicyId('policy-1'),
    label: 'Anime auto-download',
    rules: <RssAutoDownloadRule>[
      RssAutoDownloadRule(
        id: RssAutoDownloadRuleId('rule-1'),
        label: 'Episode rule',
        priority: 1,
        include: RssMatcherExpression(
          logic: RssMatcherLogic.all,
          predicates: <RssMatcherPredicate>[
            RssMatcherPredicate(
              field: RssMatcherField.title,
              operator: RssMatcherOperator.contains,
              value: 'Episode',
            ),
          ],
        ),
      ),
    ],
    enabled: true,
  );

  final FeedItem feedItem = FeedItem(
    id: FeedItemId('item-1'),
    sourceId: FeedSourceId('feed-1'),
    dedupeKey: FeedDedupeKey('item-dedupe-1'),
    title: 'Test Episode 01',
    link: Uri.parse('magnet:?xt=urn:btih:abc123'),
  );

  RssAutomationCapabilityMatrix _supportedCapabilities() {
    return RssAutomationCapabilityMatrix(
      capabilities: <RssAutomationCapability, RssAutomationCapabilityStatus>{
        RssAutomationCapability.policyEvaluation:
            const RssAutomationCapabilityStatus.supported(),
        RssAutomationCapability.durableHistory:
            const RssAutomationCapabilityStatus.supported(),
        RssAutomationCapability.btTaskHandoff:
            const RssAutomationCapabilityStatus.supported(),
        RssAutomationCapability.optionalBackgroundScheduling:
            const RssAutomationCapabilityStatus.supported(),
      },
    );
  }

  // Seed store with initial policy
  await policyStore.storePolicy(StoredRssAutoDownloadPolicyRecord(
    id: policy.id.value,
    label: policy.label,
    enabled: policy.enabled,
    createdAt: _now(),
    updatedAt: _now(),
  ));

  final RssAutoDownloadPolicyRuntimeBootstrap bootstrap =
      RssAutoDownloadPolicyRuntimeBootstrap(
    policyStore: policyStore,
    evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
      'scope-1': evaluator,
    },
    capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
      'scope-1': _supportedCapabilities(),
    },
    historyStore: historyStore,
    cacheInvalidationBus: bus,
    clock: _now,
  );

  final RssAutoDownloadPolicyRuntime runtime = bootstrap.createRuntime();

  // --- Test: initial snapshot ---
  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> snapshot =
      await runtime.snapshot('scope-1');
  _expect(snapshot.isSuccess, 'snapshot should succeed');
  _expect(snapshot.value!.activePolicyId?.value == 'policy-1',
      'snapshot should show policy-1');
  _expect(
      snapshot.value!.activePolicyEnabled == true, 'policy should be enabled');
  _expect(snapshot.value!.restart.activePolicyId == 'policy-1',
      'restart should replay policy-1');

  // --- Test: evaluate ---
  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> evalResult =
      await runtime.evaluate('scope-1', policy, <FeedItem>[feedItem]);
  _expect(evalResult.isSuccess, 'evaluate should succeed');
  _expect(evalResult.value!.latestEvaluationOutcome != null,
      'evaluate should set evaluation outcome');
  _expect(evalResult.value!.latestEvaluationOutcome!.isSuccess,
      'evaluation outcome should be success');

  // --- Test: handoff ---
  // Create a candidate directly since evaluator history may already have entries
  final RssDownloadCandidate candidate = RssDownloadCandidate(
    policyId: policy.id,
    ruleId: RssAutoDownloadRuleId('rule-1'),
    item: feedItem,
    source: MagnetRssDownloadSource('magnet:?xt=urn:btih:abc123'),
  );

  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> handoffResult =
      await runtime.handoff('scope-1', candidate);
  _expect(handoffResult.isSuccess, 'handoff should succeed');
  _expect(handoffResult.value!.latestHandoffOutcome != null,
      'handoff should set handoff outcome');
  _expect(handoffResult.value!.latestHandoffOutcome!.isSuccess,
      'handoff outcome should be success');

  // --- Test: disable ---
  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> disableResult =
      await runtime.disable('scope-1', RssAutoDownloadPolicyId('policy-1'));
  _expect(disableResult.isSuccess, 'disable should succeed');
  _expect(disableResult.value!.activePolicyEnabled == false,
      'policy should be disabled after disable');

  // --- Test: reenable ---
  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> reenableResult =
      await runtime.reenable('scope-1', RssAutoDownloadPolicyId('policy-1'));
  _expect(reenableResult.isSuccess, 'reenable should succeed');
  _expect(reenableResult.value!.activePolicyEnabled == true,
      'policy should be enabled after reenable');

  // --- Test: unsupported capability ---
  final RssAutoDownloadPolicyRuntime unsupportedRuntime =
      RssAutoDownloadPolicyRuntimeBootstrap(
    policyStore: policyStore,
    evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
      'scope-unsupported': evaluator,
    },
    capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
      'scope-unsupported':
          RssAutomationCapabilityMatrix.unsupported(reason: 'Not available.'),
    },
    clock: _now,
  ).createRuntime();

  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> unsupportedResult =
      await unsupportedRuntime
          .evaluate('scope-unsupported', policy, <FeedItem>[feedItem]);
  _expect(!unsupportedResult.isSuccess, 'unsupported evaluate should fail');
  _expect(
      unsupportedResult.failure!.kind ==
          RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported,
      'unsupported should return capabilityUnsupported');

  // --- Test: unavailable ---
  final RssAutoDownloadPolicyRuntime unavailable =
      RssAutoDownloadPolicyRuntime.unavailable(
          reason: 'RSS automation unavailable.');

  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> unavailResult =
      await unavailable.snapshot('scope-1');
  _expect(!unavailResult.isSuccess, 'unavailable snapshot should fail');
  _expect(
      unavailResult.failure!.kind ==
          RssAutoDownloadPolicyRuntimeFailureKind.unavailable,
      'unavailable should return unavailable');

  // --- Test: disposed ---
  await runtime.dispose();
  final RssAutoDownloadPolicyRuntimeActionResult<
          RssAutoDownloadPolicyRuntimeProjection> disposedResult =
      await runtime.snapshot('scope-1');
  _expect(!disposedResult.isSuccess, 'disposed snapshot should fail');
  _expect(
      disposedResult.failure!.kind ==
          RssAutoDownloadPolicyRuntimeFailureKind.disposed,
      'disposed should return disposed');

  stdout.writeln('RSS auto-download policy runtime contract verified.');
}

DateTime _now() => DateTime.utc(2026, 6, 15, 12);
