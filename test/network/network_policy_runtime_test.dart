import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkPolicyRuntime', () {
    late DeterministicNetworkPolicyStore store;
    late DeterministicNetworkPolicyEvaluator evaluator;
    late StreamCacheInvalidationBus bus;

    setUp(() {
      store = DeterministicNetworkPolicyStore();
      evaluator = DeterministicNetworkPolicyEvaluator();
      bus = StreamCacheInvalidationBus();
    });

    tearDown(() async {
      await bus.close();
    });

    NetworkPolicyRuntime _runtime({
      required String providerScope,
      NetworkPolicyCapabilityMatrix? capabilities,
    }) {
      return NetworkPolicyRuntimeBootstrap(
        store: store,
        policiesByScope: <String, NetworkPolicy>{
          providerScope: _testPolicy(providerScope),
        },
        evaluatorsByScope: <String, NetworkPolicyEvaluator>{
          providerScope: evaluator,
        },
        capabilitiesByScope: <String, NetworkPolicyCapabilityMatrix>{
          providerScope:
              capabilities ?? NetworkPolicyCapabilityMatrix.supported(),
        },
        bus: bus,
      ).createRuntime();
    }

    test('initial snapshot projects assignment and capability state', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.providerScope, 'provider-a');
    });

    test('provider assignment stores and publishes event', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      await store.storeProfile(StoredNetworkPolicyProfileRecord(
        id: 'policy-a',
        providerScope: 'provider-a',
        label: 'Default policy',
        fallbackBehavior: StoredNetworkPolicyFallbackBehavior.systemDns,
        createdAt: DateTime.utc(2026, 6, 16, 10),
        updatedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.assignProvider(
        providerScope: 'provider-a',
        policyId: const NetworkPolicyId('policy-a'),
        reason: 'Initial assignment',
      );

      expect(result.isSuccess, isTrue);
      expect(events.whereType<NetworkPolicyProviderAssignmentChanged>(),
          isNotEmpty);
      await subscription.cancel();
    });

    test('allowed evaluation stores snapshot and publishes event', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, isA<NetworkPolicyAllowed>());
      expect(
          events.whereType<NetworkPolicyEvaluationOutcomeRecorded>(), isNotEmpty);
      await subscription.cancel();
    });

    test('SSRF block evaluation stores snapshot block outcome and publishes events',
        () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('http://127.0.0.1/admin'),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, isA<NetworkPolicyBlocked>());
      final blocked = result.value! as NetworkPolicyBlocked;
      expect(blocked.kind, NetworkPolicyFailureKind.loopbackAddress);
      expect(events.whereType<NetworkPolicyEvaluationOutcomeRecorded>(),
          isNotEmpty);
      expect(
          events.whereType<NetworkPolicyBlockDecisionRecorded>(), isNotEmpty);
      await subscription.cancel();
    });

    test('block outcome replay reads stored block outcome', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.recordBlockOutcome(StoredNetworkPolicyBlockOutcomeRecord(
        id: 'block-1',
        evaluationId: 'eval-1',
        providerScope: 'provider-a',
        requestUri: Uri.parse('http://127.0.0.1/admin'),
        failureKind: NetworkPolicyFailureKind.loopbackAddress,
        reason: 'Request host is blocked by SSRF guard.',
        recordedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.latestBlockReason,
          'Request host is blocked by SSRF guard.');
    });

    test('capability recording stores and publishes event', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.recordCapability(
        providerScope: 'provider-a',
        capability: NetworkPolicyCapability.ssrfGuard,
        supported: true,
      );

      expect(result.isSuccess, isTrue);
      expect(events.whereType<NetworkPolicyCapabilityChanged>(), isNotEmpty);
      await subscription.cancel();
    });

    test('unsupported capability returns capabilityUnsupported', () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        capabilities: NetworkPolicyCapabilityMatrix.unsupported(
            reason: 'No policy integration.'),
      );

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          NetworkPolicyRuntimeFailureKind.capabilityUnsupported);
    });

    test('disabled policy returns policyDisabled', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await runtime.disable(providerScope: 'provider-a');

      final result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(
          result.failure?.kind, NetworkPolicyRuntimeFailureKind.policyDisabled);
    });

    test('unavailable runtime rejects all operations', () async {
      final runtime =
          NetworkPolicyRuntime.unavailable(reason: 'Platform unsupported.');

      expect(
          (await runtime.snapshot('provider-a')).failure?.kind,
          NetworkPolicyRuntimeFailureKind.unavailable);
      expect(
          (await runtime.evaluate(
            providerScope: 'provider-a',
            request: NetworkPolicyRequest(
              providerScope: 'provider-a',
              uri: Uri.parse('https://example.test/page'),
            ),
          )).failure?.kind,
          NetworkPolicyRuntimeFailureKind.unavailable);
      expect(
          (await runtime.assignProvider(
            providerScope: 'provider-a',
            policyId: const NetworkPolicyId('policy-a'),
          )).failure?.kind,
          NetworkPolicyRuntimeFailureKind.unavailable);
      expect(
          (await runtime.recordCapability(
            providerScope: 'provider-a',
            capability: NetworkPolicyCapability.ssrfGuard,
            supported: true,
          )).failure?.kind,
          NetworkPolicyRuntimeFailureKind.unavailable);
    });

    test('disposed runtime rejects snapshot', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      runtime.dispose();

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          NetworkPolicyRuntimeFailureKind.disposed);
    });

    test('invalidation events published on evaluate and capability', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );
      await runtime.recordCapability(
        providerScope: 'provider-a',
        capability: NetworkPolicyCapability.ssrfGuard,
        supported: true,
      );

      expect(events.whereType<NetworkPolicyEvaluationOutcomeRecorded>(),
          hasLength(1));
      expect(events.whereType<NetworkPolicyCapabilityChanged>(), hasLength(1));
      await subscription.cancel();
    });

    test('restart projection replays stored evaluation block and capability state',
        () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('http://127.0.0.1/admin'),
        ),
      );

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.latestAssignmentPolicyId, 'policy-a');
      expect(result.value?.restart.latestEvaluationDecisionKind, isNotNull);
      expect(result.value?.restart.latestBlockReason, isNotNull);
    });

    test('policyNotFound when no policy assigned to provider', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      final result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          NetworkPolicyRuntimeFailureKind.policyNotFound);
    });

    test('invalidAssignment when policy profile missing from store', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      final result = await runtime.assignProvider(
        providerScope: 'provider-a',
        policyId: const NetworkPolicyId('nonexistent-policy'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          NetworkPolicyRuntimeFailureKind.invalidAssignment);
    });

    test('evaluationFailed when evaluator throws', () async {
      final runtime = NetworkPolicyRuntimeBootstrap(
        store: store,
        policiesByScope: <String, NetworkPolicy>{
          'provider-a': _testPolicy('provider-a'),
        },
        evaluatorsByScope: <String, NetworkPolicyEvaluator>{
          'provider-a': _ThrowingEvaluator(),
        },
        capabilitiesByScope: <String, NetworkPolicyCapabilityMatrix>{
          'provider-a': NetworkPolicyCapabilityMatrix.supported(),
        },
        bus: bus,
      ).createRuntime();

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          NetworkPolicyRuntimeFailureKind.evaluationFailed);
    });

    test('reenable restores evaluate for disabled policy', () async {
      final runtime = _runtime(providerScope: 'provider-a');

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-1',
        providerScope: 'provider-a',
        policyId: 'policy-a',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      await runtime.disable(providerScope: 'provider-a');

      var result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(
          result.failure?.kind, NetworkPolicyRuntimeFailureKind.policyDisabled);

      await runtime.reenable(providerScope: 'provider-a');

      result = await runtime.evaluate(
        providerScope: 'provider-a',
        request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://example.test/page'),
        ),
      );
      expect(result.isSuccess, isTrue);
    });

    test('provider-scoped operations do not mutate unrelated provider', () async {
      final runtime = NetworkPolicyRuntimeBootstrap(
        store: store,
        policiesByScope: <String, NetworkPolicy>{
          'provider-a': _testPolicy('provider-a'),
          'provider-b': _testPolicy('provider-b'),
        },
        evaluatorsByScope: <String, NetworkPolicyEvaluator>{
          'provider-a': evaluator,
          'provider-b': evaluator,
        },
        capabilitiesByScope: <String, NetworkPolicyCapabilityMatrix>{
          'provider-a': NetworkPolicyCapabilityMatrix.supported(),
          'provider-b': NetworkPolicyCapabilityMatrix.supported(),
        },
        bus: bus,
      ).createRuntime();

      await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
        id: 'assign-b',
        providerScope: 'provider-b',
        policyId: 'policy-b',
        assignedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      await runtime.disable(providerScope: 'provider-a');

      final providerBResult = await runtime.evaluate(
        providerScope: 'provider-b',
        request: NetworkPolicyRequest(
          providerScope: 'provider-b',
          uri: Uri.parse('https://example.test/page'),
        ),
      );

      expect(providerBResult.isSuccess, isTrue);
    });
  });
}

NetworkPolicy _testPolicy(String providerScope) {
  final policyId = providerScope == 'provider-a' ? 'policy-a' : 'policy-b';
  return NetworkPolicy(
    id: NetworkPolicyId(policyId),
    providerScope: providerScope,
    rules: const <NetworkPolicyRule>[],
  );
}


final class _ThrowingEvaluator implements NetworkPolicyEvaluator {
  @override
  NetworkPolicyCapabilityMatrix get capabilities =>
      NetworkPolicyCapabilityMatrix.supported();

  @override
  Future<NetworkPolicyDecision> evaluate({
    required NetworkPolicy policy,
    required NetworkPolicyRequest request,
  }) {
    throw StateError('Evaluator failed.');
  }
}
