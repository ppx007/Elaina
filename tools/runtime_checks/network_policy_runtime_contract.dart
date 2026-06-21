import '../../lib/elaina.dart';

Future<void> main() async {
  final DeterministicNetworkPolicyStore store =
      DeterministicNetworkPolicyStore();
  final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
  final NetworkPolicyRuntime runtime = _buildRuntime(store: store, bus: bus);

  await store.storeProfile(StoredNetworkPolicyProfileRecord(
    id: 'policy-a',
    providerScope: 'provider-a',
    label: 'Runtime check policy',
    fallbackBehavior: StoredNetworkPolicyFallbackBehavior.systemDns,
    createdAt: DateTime.utc(2026, 6, 16, 10),
    updatedAt: DateTime.utc(2026, 6, 16, 10),
  ));
  await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
    id: 'assignment-a',
    providerScope: 'provider-a',
    policyId: 'policy-a',
    assignedAt: DateTime.utc(2026, 6, 16, 10),
  ));

  final NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>
      snapshot = await runtime.snapshot('provider-a');
  _expect(snapshot.isSuccess, 'Snapshot must succeed.');
  _expect(snapshot.value!.restart.latestAssignmentPolicyId == 'policy-a',
      'Snapshot must project stored assignment.');

  final Future<List<CacheInvalidationEvent>> allowEvents =
      bus.events.take(1).toList();
  final NetworkPolicyRuntimeActionResult<NetworkPolicyDecision> allowed =
      await runtime.evaluate(
    providerScope: 'provider-a',
    request: NetworkPolicyRequest(
      providerScope: 'provider-a',
      uri: Uri.parse('https://example.test/video'),
    ),
  );
  _expect(allowed.isSuccess, 'Allowed evaluation must succeed.');
  _expect(allowed.value is NetworkPolicyAllowed,
      'Allowed evaluation must return an allow decision.');
  _expect((await allowEvents).single is NetworkPolicyEvaluationOutcomeRecorded,
      'Allowed evaluation must publish outcome invalidation.');

  final Future<List<CacheInvalidationEvent>> blockEvents =
      bus.events.take(2).toList();
  final NetworkPolicyRuntimeActionResult<NetworkPolicyDecision> blocked =
      await runtime.evaluate(
    providerScope: 'provider-a',
    request: NetworkPolicyRequest(
      providerScope: 'provider-a',
      uri: Uri.parse('http://127.0.0.1/admin'),
    ),
  );
  final List<CacheInvalidationEvent> blockInvalidations = await blockEvents;
  _expect(blocked.isSuccess, 'Blocked evaluation must still return success.');
  _expect(blocked.value is NetworkPolicyBlocked,
      'Blocked evaluation must preserve block decision.');
  _expect(
      blockInvalidations
              .whereType<NetworkPolicyEvaluationOutcomeRecorded>()
              .length ==
          1,
      'Blocked evaluation must publish outcome invalidation.');
  _expect(
      blockInvalidations
              .whereType<NetworkPolicyBlockDecisionRecorded>()
              .length ==
          1,
      'Blocked evaluation must publish block invalidation.');

  final NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>
      replay = await runtime.snapshot('provider-a');
  _expect(
      replay.value!.restart.latestEvaluationDecisionKind ==
          StoredNetworkPolicyDecisionKind.blocked.name,
      'Restart projection must replay stored block decision.');
  _expect(replay.value!.restart.latestBlockReason != null,
      'Restart projection must replay stored block reason.');

  final Future<List<CacheInvalidationEvent>> capabilityEvents =
      bus.events.take(1).toList();
  final NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>
      capability = await runtime.recordCapability(
    providerScope: 'provider-a',
    capability: NetworkPolicyCapability.ssrfGuard,
    supported: true,
  );
  _expect(capability.isSuccess, 'Capability recording must succeed.');
  _expect((await capabilityEvents).single is NetworkPolicyCapabilityChanged,
      'Capability recording must publish invalidation.');

  _expect((await runtime.disable(providerScope: 'provider-a')).isSuccess,
      'Disable must succeed.');
  final NetworkPolicyRuntimeActionResult<NetworkPolicyDecision> disabled =
      await runtime.evaluate(
    providerScope: 'provider-a',
    request: NetworkPolicyRequest(
      providerScope: 'provider-a',
      uri: Uri.parse('https://example.test/video'),
    ),
  );
  _expect(
      disabled.failure!.kind == NetworkPolicyRuntimeFailureKind.policyDisabled,
      'Disabled provider must report policyDisabled.');
  _expect((await runtime.reenable(providerScope: 'provider-a')).isSuccess,
      'Reenable must succeed.');

  final NetworkPolicyRuntime unsupported = NetworkPolicyRuntimeBootstrap(
    store: DeterministicNetworkPolicyStore(),
    policiesByScope: <String, NetworkPolicy>{
      'provider-a': _policy('provider-a'),
    },
    evaluatorsByScope: <String, NetworkPolicyEvaluator>{
      'provider-a': DeterministicNetworkPolicyEvaluator(),
    },
    capabilitiesByScope: <String, NetworkPolicyCapabilityMatrix>{
      'provider-a': NetworkPolicyCapabilityMatrix.unsupported(
        reason: 'Runtime check capability disabled.',
      ),
    },
  ).createRuntime();
  _expect(
      (await unsupported.snapshot('provider-a')).failure!.kind ==
          NetworkPolicyRuntimeFailureKind.capabilityUnsupported,
      'Unsupported capability must normalize failure.');

  final NetworkPolicyRuntime unavailable =
      NetworkPolicyRuntime.unavailable(reason: 'Runtime check unavailable.');
  _expect(
      (await unavailable.snapshot('provider-a')).failure!.kind ==
          NetworkPolicyRuntimeFailureKind.unavailable,
      'Unavailable runtime must reject actions.');

  runtime.dispose();
  _expect(
      (await runtime.snapshot('provider-a')).failure!.kind ==
          NetworkPolicyRuntimeFailureKind.disposed,
      'Disposed runtime must reject actions.');

  await bus.close();
}

NetworkPolicyRuntime _buildRuntime({
  required DeterministicNetworkPolicyStore store,
  required StreamCacheInvalidationBus bus,
}) {
  return NetworkPolicyRuntimeBootstrap(
    store: store,
    policiesByScope: <String, NetworkPolicy>{
      'provider-a': _policy('provider-a'),
    },
    evaluatorsByScope: <String, NetworkPolicyEvaluator>{
      'provider-a': DeterministicNetworkPolicyEvaluator(),
    },
    capabilitiesByScope: <String, NetworkPolicyCapabilityMatrix>{
      'provider-a': NetworkPolicyCapabilityMatrix.supported(),
    },
    bus: bus,
  ).createRuntime();
}

NetworkPolicy _policy(String providerScope) {
  return NetworkPolicy(
    id: const NetworkPolicyId('policy-a'),
    providerScope: providerScope,
    rules: const <NetworkPolicyRule>[],
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
