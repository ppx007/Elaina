import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RssAutoDownloadPolicyRuntime', () {
    late DeterministicRssAutoDownloadPolicyStore policyStore;
    late DeterministicRssAutomationHistoryStore historyStore;
    late StreamCacheInvalidationBus bus;
    late DeterministicRssAutoDownloadPolicyEvaluator evaluator;
    late RssAutoDownloadPolicy policy;
    late FeedItem feedItem;
    late RssAutoDownloadPolicyRuntime runtime;

    DateTime _now() => DateTime.utc(2026, 6, 15, 12);

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

    RssAutomationCapabilityMatrix _unsupportedCapabilities() {
      return RssAutomationCapabilityMatrix.unsupported(
          reason: 'Not available.');
    }

    RssAutomationCapabilityMatrix _noHandoffCapabilities() {
      return RssAutomationCapabilityMatrix(
        capabilities: <RssAutomationCapability, RssAutomationCapabilityStatus>{
          RssAutomationCapability.policyEvaluation:
              const RssAutomationCapabilityStatus.supported(),
          RssAutomationCapability.durableHistory:
              const RssAutomationCapabilityStatus.supported(),
          RssAutomationCapability.btTaskHandoff:
              const RssAutomationCapabilityStatus.unsupported('No BT handoff.'),
          RssAutomationCapability.optionalBackgroundScheduling:
              const RssAutomationCapabilityStatus.supported(),
        },
      );
    }

    Future<RssAutoDownloadPolicyRuntime> _createRuntime({
      Map<String, DeterministicRssAutoDownloadPolicyEvaluator> evaluatorByScope =
          const <String, DeterministicRssAutoDownloadPolicyEvaluator>{},
      Map<String, RssAutomationCapabilityMatrix> capabilitiesByScope =
          const <String, RssAutomationCapabilityMatrix>{},
    }) async {
      final RssAutoDownloadPolicyRuntimeBootstrap bootstrap =
          RssAutoDownloadPolicyRuntimeBootstrap(
        policyStore: policyStore,
        evaluatorByScope: evaluatorByScope,
        capabilitiesByScope: capabilitiesByScope,
        historyStore: historyStore,
        cacheInvalidationBus: bus,
        clock: _now,
      );
      return bootstrap.createRuntime();
    }

    setUp(() async {
      policyStore = DeterministicRssAutoDownloadPolicyStore();
      historyStore = DeterministicRssAutomationHistoryStore();
      bus = StreamCacheInvalidationBus();
      evaluator = const DeterministicRssAutoDownloadPolicyEvaluator();
      policy = RssAutoDownloadPolicy(
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
      feedItem = FeedItem(
        id: FeedItemId('item-1'),
        sourceId: FeedSourceId('feed-1'),
        dedupeKey: FeedDedupeKey('item-dedupe-1'),
        title: 'Test Episode 01',
        link: Uri.parse('magnet:?xt=urn:btih:abc123'),
      );

      await policyStore.storePolicy(StoredRssAutoDownloadPolicyRecord(
        id: policy.id.value,
        label: policy.label,
        enabled: policy.enabled,
        createdAt: _now(),
        updatedAt: _now(),
      ));

      runtime = await _createRuntime(
        evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
          'scope-1': evaluator,
        },
        capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
          'scope-1': _supportedCapabilities(),
        },
      );
    });

    test('initial snapshot returns projection from seeded store', () async {
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.snapshot('scope-1');

      expect(result.isSuccess, isTrue);
      final RssAutoDownloadPolicyRuntimeProjection projection = result.value!;
      expect(projection.scopeId, 'scope-1');
      expect(projection.activePolicyId?.value, 'policy-1');
      expect(projection.activePolicyLabel, 'Anime auto-download');
      expect(projection.activePolicyEnabled, isTrue);
      expect(projection.restart.activePolicyId, 'policy-1');
    });

    test('evaluate succeeds and persists to store', () async {
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.evaluate('scope-1', policy, <FeedItem>[feedItem]);

      expect(result.isSuccess, isTrue);
      final RssAutoDownloadPolicyRuntimeProjection projection = result.value!;
      expect(projection.latestEvaluationOutcome, isNotNull);
      expect(projection.latestEvaluationOutcome!.isSuccess, isTrue);
      expect(projection.latestEvaluationOutcome!.decisions, isNotEmpty);
    });

    test('handoff succeeds and produces read model', () async {
      // First evaluate to get a candidate
      final RssAutomationEvaluationOutcome evalOutcome =
          await evaluator.evaluateTyped(
        policy: policy,
        items: <FeedItem>[feedItem],
        history: historyStore,
      );
      expect(evalOutcome.isSuccess, isTrue);
      final RssAutomationAccepted accepted =
          evalOutcome.decisions.whereType<RssAutomationAccepted>().first;

      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.handoff('scope-1', accepted.candidate);

      expect(result.isSuccess, isTrue);
      final RssAutoDownloadPolicyRuntimeProjection projection = result.value!;
      expect(projection.latestHandoffOutcome, isNotNull);
      expect(projection.latestHandoffOutcome!.isSuccess, isTrue);
      expect(projection.latestHandoffOutcome!.handoff, isNotNull);
    });

    test('disable succeeds and sets enabled false', () async {
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.disable('scope-1', RssAutoDownloadPolicyId('policy-1'));

      expect(result.isSuccess, isTrue);
      expect(result.value!.activePolicyEnabled, isFalse);
    });

    test('reenable succeeds and sets enabled true', () async {
      await runtime.disable('scope-1', RssAutoDownloadPolicyId('policy-1'));
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.reenable(
              'scope-1', RssAutoDownloadPolicyId('policy-1'));

      expect(result.isSuccess, isTrue);
      expect(result.value!.activePolicyEnabled, isTrue);
    });

    test('unsupported capability returns capabilityUnsupported', () async {
      final RssAutoDownloadPolicyRuntime unsupportedRuntime =
          await _createRuntime(
        evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
          'scope-unsupported': evaluator,
        },
        capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
          'scope-unsupported': _unsupportedCapabilities(),
        },
      );

      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await unsupportedRuntime
              .evaluate('scope-unsupported', policy, <FeedItem>[feedItem]);

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported);
    });

    test(
        'handoff with no btTaskHandoff capability returns capabilityUnsupported',
        () async {
      final RssAutoDownloadPolicyRuntime noHandoffRuntime =
          await _createRuntime(
        evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
          'scope-no-handoff': evaluator,
        },
        capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
          'scope-no-handoff': _noHandoffCapabilities(),
        },
      );

      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await noHandoffRuntime.handoff(
              'scope-no-handoff',
              RssDownloadCandidate(
                policyId: policy.id,
                ruleId: RssAutoDownloadRuleId('rule-1'),
                item: feedItem,
                source: MagnetRssDownloadSource('magnet:?xt=urn:btih:abc123'),
              ));

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported);
    });

    test('unavailable runtime rejects all operations', () async {
      final RssAutoDownloadPolicyRuntime unavailable =
          RssAutoDownloadPolicyRuntime.unavailable(
              reason: 'RSS automation unavailable.');

      final List<
          Future<
              RssAutoDownloadPolicyRuntimeActionResult<
                  RssAutoDownloadPolicyRuntimeProjection>>> ops = <Future<
          RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>>>[
        unavailable.snapshot('scope-1'),
        unavailable.evaluate('scope-1', policy, <FeedItem>[feedItem]),
        unavailable.handoff(
            'scope-1',
            RssDownloadCandidate(
              policyId: policy.id,
              ruleId: RssAutoDownloadRuleId('rule-1'),
              item: feedItem,
              source: MagnetRssDownloadSource('magnet:?xt=urn:btih:abc123'),
            )),
        unavailable.disable('scope-1', RssAutoDownloadPolicyId('policy-1')),
        unavailable.reenable('scope-1', RssAutoDownloadPolicyId('policy-1')),
      ];

      for (final Future<
          RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>> op in ops) {
        final RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection> result = await op;
        expect(result.isSuccess, isFalse);
        expect(result.failure!.kind,
            RssAutoDownloadPolicyRuntimeFailureKind.unavailable);
      }
    });

    test('disposed runtime rejects snapshot', () async {
      await runtime.dispose();
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.snapshot('scope-1');

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          RssAutoDownloadPolicyRuntimeFailureKind.disposed);
    });

    test('invalidation events are published on evaluate', () async {
      // Collect events during the action
      final List<CacheInvalidationEvent> collected = <CacheInvalidationEvent>[];
      final StreamSubscription<CacheInvalidationEvent> sub =
          bus.events.listen(collected.add);

      await runtime.evaluate('scope-1', policy, <FeedItem>[feedItem]);

      // Allow microtasks to flush
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(collected, isNotEmpty);
      expect(
          collected.whereType<RssAutoDownloadFeedItemEvaluated>(), isNotEmpty);
    });

    test('restart projection replays stored state', () async {
      await runtime.evaluate('scope-1', policy, <FeedItem>[feedItem]);

      // Create a new runtime from the same store (simulating restart)
      final RssAutoDownloadPolicyRuntime restartedRuntime =
          await _createRuntime(
        evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
          'scope-1': evaluator,
        },
        capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
          'scope-1': _supportedCapabilities(),
        },
      );

      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await restartedRuntime.snapshot('scope-1');

      expect(result.isSuccess, isTrue);
      final RssAutoDownloadPolicyRuntimeRestartProjection restart =
          result.value!.restart;
      expect(restart.activePolicyId, 'policy-1');
    });

    test('domain failure mapping - automationDisabled', () async {
      final DeterministicRssAutoDownloadPolicyEvaluator disabledEvaluator =
          const DeterministicRssAutoDownloadPolicyEvaluator(
              automationEnabled: false);

      final RssAutoDownloadPolicyRuntime disabledRuntime = await _createRuntime(
        evaluatorByScope: <String, DeterministicRssAutoDownloadPolicyEvaluator>{
          'scope-disabled': disabledEvaluator,
        },
        capabilitiesByScope: <String, RssAutomationCapabilityMatrix>{
          'scope-disabled': _supportedCapabilities(),
        },
      );

      // Evaluate with automation disabled - items get RssAutomationDisabled decisions
      // which are NOT failures - they're valid decisions. The evaluator succeeds.
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await disabledRuntime
              .evaluate('scope-disabled', policy, <FeedItem>[feedItem]);

      // Evaluation still succeeds but decisions contain Disabled decisions
      expect(result.isSuccess, isTrue);
      expect(result.value!.latestEvaluationOutcome!.decisions, isNotEmpty);
      expect(
          result.value!.latestEvaluationOutcome!.decisions
              .whereType<RssAutomationDisabled>(),
          isNotEmpty);
    });

    test('disable with non-existent policy returns policyNotFound failure',
        () async {
      final RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection> result =
          await runtime.disable(
              'scope-1', RssAutoDownloadPolicyId('non-existent'));

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind,
          RssAutoDownloadPolicyRuntimeFailureKind.policyNotFound);
    });
  });
}
