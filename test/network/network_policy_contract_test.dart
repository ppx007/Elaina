// Network policy contract tests define matcher and action semantics independent
// of ProviderGateway runtime persistence.
// Runtime tests assert assignment storage and evaluation recording.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'storage persists profiles rules assignments evaluations blocks and capabilities',
      () async {
    final DateTime observedAt = DateTime.utc(2026, 6, 10, 12);
    final DeterministicNetworkPolicyStore store =
        DeterministicNetworkPolicyStore();

    await store.storeProfile(StoredNetworkPolicyProfileRecord(
      id: 'policy-a',
      providerScope: 'provider-a',
      label: 'Provider A network policy',
      fallbackBehavior: StoredNetworkPolicyFallbackBehavior.systemDns,
      createdAt: observedAt,
      updatedAt: observedAt,
    ));
    await store.storeRules(
      policyId: 'policy-a',
      rules: <StoredNetworkPolicyRuleRecord>[
        StoredNetworkPolicyRuleRecord(
          id: 'rule-a',
          policyId: 'policy-a',
          order: 1,
          matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
          pattern: 'example.test',
          action: StoredNetworkPolicyAction.doh,
          resolverEndpoint:
              Uri.parse('https://resolver.example.test/dns-query'),
          auditLabel: 'runtime-doh',
        ),
      ],
    );
    await store.assignProvider(StoredNetworkPolicyProviderAssignmentRecord(
      id: 'assignment-a',
      providerScope: 'provider-a',
      policyId: 'policy-a',
      assignedAt: observedAt,
    ));
    await store.recordEvaluation(StoredNetworkPolicyEvaluationSnapshotRecord(
      id: 'evaluation-a',
      providerScope: 'provider-a',
      requestUri: Uri.parse('https://media.example.test/episode'),
      policyId: 'policy-a',
      ruleId: 'rule-a',
      decisionKind: StoredNetworkPolicyDecisionKind.allowed,
      action: StoredNetworkPolicyAction.doh,
      recordedAt: observedAt,
    ));
    await store.recordBlockOutcome(StoredNetworkPolicyBlockOutcomeRecord(
      id: 'block-a',
      evaluationId: 'evaluation-b',
      providerScope: 'provider-a',
      requestUri: Uri.parse('http://127.0.0.1/admin'),
      failureKind: NetworkPolicyFailureKind.loopbackAddress,
      reason: 'Loopback blocked.',
      recordedAt: observedAt,
    ));
    await store.storeCapability(StoredNetworkPolicyCapabilityRecord(
      providerScope: 'provider-a',
      capability: NetworkPolicyCapability.dohIntent.name,
      state: StoredNetworkPolicyCapabilityState.supported,
      updatedAt: observedAt,
    ));

    expect((await store.profileById('policy-a'))?.label,
        'Provider A network policy');
    expect((await store.rulesForPolicy('policy-a')).single.action,
        StoredNetworkPolicyAction.doh);
    expect((await store.assignmentForProvider('provider-a'))?.policyId,
        'policy-a');
    expect((await store.evaluationsForProvider('provider-a')).single.action,
        StoredNetworkPolicyAction.doh);
    expect(
        (await store.blockOutcomesForProvider('provider-a')).single.failureKind,
        NetworkPolicyFailureKind.loopbackAddress);
    expect(
      (await store.capabilityForProvider(
        providerScope: 'provider-a',
        capability: NetworkPolicyCapability.dohIntent.name,
      ))
          ?.state,
      StoredNetworkPolicyCapabilityState.supported,
    );
  });

  test('SSRF guard blocks IPv6, 0.0.0.0, and non-dotted IPv4 encodings',
      () async {
    final NetworkPolicy policy = NetworkPolicy(
      id: const NetworkPolicyId('policy-a'),
      providerScope: 'provider-a',
      rules: const <NetworkPolicyRule>[],
    );
    final DeterministicNetworkPolicyEvaluator evaluator =
        DeterministicNetworkPolicyEvaluator();

    Future<NetworkPolicyFailureKind?> kindFor(String uri) async {
      final NetworkPolicyDecision decision = await evaluator.evaluate(
        policy: policy,
        request: NetworkPolicyRequest(
            providerScope: 'provider-a', uri: Uri.parse(uri)),
      );
      return decision is NetworkPolicyBlocked ? decision.kind : null;
    }

    expect(await kindFor('http://[::1]/admin'),
        NetworkPolicyFailureKind.loopbackAddress);
    expect(await kindFor('http://0.0.0.0/admin'),
        NetworkPolicyFailureKind.loopbackAddress);
    expect(await kindFor('http://[fd00::1]/admin'),
        NetworkPolicyFailureKind.privateNetworkAddress);
    expect(await kindFor('http://[fe80::1]/admin'),
        NetworkPolicyFailureKind.linkLocalAddress);
    expect(await kindFor('http://2130706433/admin'),
        NetworkPolicyFailureKind.loopbackAddress);
    expect(await kindFor('http://0x7f000001/admin'),
        NetworkPolicyFailureKind.loopbackAddress);
    expect(await kindFor('http://[::ffff:127.0.0.1]/admin'),
        NetworkPolicyFailureKind.loopbackAddress);
  });

  test('deterministic evaluator matches domain wildcard and cidr intent',
      () async {
    final NetworkPolicy policy = NetworkPolicy(
      id: const NetworkPolicyId('policy-a'),
      providerScope: 'provider-a',
      auditMetadata: NetworkPolicyAuditMetadata(label: 'provider-a-policy'),
      rules: <NetworkPolicyRule>[
        NetworkPolicyRule(
          id: const NetworkPolicyRuleId('wildcard'),
          order: 1,
          matcher: const NetworkPolicyMatcher(
              kind: NetworkPolicyMatcherKind.wildcardHost,
              pattern: '*.proxy.example.test'),
          action: NetworkPolicyAction.proxyTag,
          proxyIntent: const NetworkProxyIntent(proxyTag: 'provider-proxy'),
          auditLabel: 'proxy-rule',
        ),
        NetworkPolicyRule(
          id: const NetworkPolicyRuleId('suffix'),
          order: 2,
          matcher: const NetworkPolicyMatcher(
              kind: NetworkPolicyMatcherKind.domainSuffix,
              pattern: 'example.test'),
          action: NetworkPolicyAction.doh,
          resolverIntent: NetworkResolverIntent.doh(
              endpoint: Uri.parse('https://resolver.example.test/dns-query')),
          auditLabel: 'doh-rule',
        ),
        const NetworkPolicyRule(
          id: NetworkPolicyRuleId('cidr'),
          order: 3,
          matcher: NetworkPolicyMatcher(
              kind: NetworkPolicyMatcherKind.cidr, pattern: '203.0.113.0/24'),
          action: NetworkPolicyAction.direct,
          auditLabel: 'cidr-rule',
        ),
      ],
    );
    final DeterministicNetworkPolicyEvaluator evaluator =
        DeterministicNetworkPolicyEvaluator();

    final NetworkPolicyAllowed proxyDecision = await evaluator.evaluate(
      policy: policy,
      request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://cdn.proxy.example.test/video')),
    ) as NetworkPolicyAllowed;
    final NetworkPolicyAllowed dohDecision = await evaluator.evaluate(
      policy: policy,
      request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://media.example.test/video')),
    ) as NetworkPolicyAllowed;
    final NetworkPolicyAllowed cidrDecision = await evaluator.evaluate(
      policy: policy,
      request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://203.0.113.8/video')),
    ) as NetworkPolicyAllowed;

    expect(proxyDecision.proxyTag, 'provider-proxy');
    expect(dohDecision.action, NetworkPolicyAction.doh);
    expect(cidrDecision.ruleId?.value, 'cidr');
  });

  test(
      'ssrf failures capability fallback gateway handoff and invalidations are typed',
      () async {
    final DateTime observedAt = DateTime.utc(2026, 6, 10, 12);
    final NetworkPolicy policy = NetworkPolicy(
      id: const NetworkPolicyId('policy-a'),
      providerScope: 'provider-a',
      rules: <NetworkPolicyRule>[
        const NetworkPolicyRule(
          id: NetworkPolicyRuleId('dot-required'),
          order: 1,
          matcher: NetworkPolicyMatcher(
              kind: NetworkPolicyMatcherKind.exactHost,
              pattern: 'secure.example.test'),
          action: NetworkPolicyAction.dot,
          resolverIntent:
              NetworkResolverIntent.dot(resolverHost: 'resolver.example.test'),
          fallbackBehavior: NetworkPolicyFallbackBehavior.block,
          requiresStrictCapability: true,
        ),
      ],
    );
    final DeterministicNetworkPolicyEvaluator evaluator =
        DeterministicNetworkPolicyEvaluator(
      capabilities: NetworkPolicyCapabilityMatrix(
        capabilities: <NetworkPolicyCapability, NetworkPolicyCapabilityStatus>{
          for (final NetworkPolicyCapability capability
              in NetworkPolicyCapability.values)
            capability: capability == NetworkPolicyCapability.dotIntent
                ? const NetworkPolicyCapabilityStatus.unsupported(
                    'DoT unavailable.')
                : const NetworkPolicyCapabilityStatus.supported(),
        },
      ),
    );

    final NetworkPolicyBlocked loopback = await evaluator.evaluate(
      policy: policy,
      request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('http://127.0.0.1/admin')),
    ) as NetworkPolicyBlocked;
    final NetworkPolicyBlocked unsupported = await evaluator.evaluate(
      policy: policy,
      request: NetworkPolicyRequest(
          providerScope: 'provider-a',
          uri: Uri.parse('https://secure.example.test/video')),
    ) as NetworkPolicyBlocked;
    final ProviderNetworkPolicyHandoffDescriptor handoff =
        ProviderNetworkPolicyHandoffDescriptor(
      providerId: const ProviderId('provider-a'),
      providerScope: 'provider-a',
      cacheKey: 'provider-a::secure',
      requestUri: Uri.parse('https://secure.example.test/video'),
      cachePolicy: ProviderCachePolicy.networkFirst,
      ratePolicy: const ProviderRatePolicy(
          maxRequests: 2, window: Duration(minutes: 1)),
      retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
      requiredCapabilities: const <NetworkPolicyCapability>{
        NetworkPolicyCapability.dotIntent
      },
      policyRequirementLabel: 'strict-dot',
    );
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(6).toList();
    bus.publish(NetworkPolicyProfileChanged(
      occurredAt: observedAt,
      policyId: 'policy-a',
      providerScope: 'provider-a',
      changeKind: NetworkPolicyProfileChangeKind.updated,
    ));
    bus.publish(NetworkPolicyProviderAssignmentChanged(
      occurredAt: observedAt,
      assignmentId: 'assignment-a',
      providerScope: 'provider-a',
      policyId: 'policy-a',
    ));
    bus.publish(NetworkPolicyRuleChanged(
      occurredAt: observedAt,
      policyId: 'policy-a',
      ruleId: 'dot-required',
      providerScope: 'provider-a',
    ));
    bus.publish(NetworkPolicyEvaluationOutcomeRecorded(
      occurredAt: observedAt,
      evaluationId: 'evaluation-a',
      providerScope: 'provider-a',
      requestUri: Uri.parse('https://secure.example.test/video'),
      decisionKind: 'blocked',
      failureKind: NetworkPolicyFailureKind.unsupportedCapability.name,
    ));
    bus.publish(NetworkPolicyBlockDecisionRecorded(
      occurredAt: observedAt,
      blockOutcomeId: 'block-a',
      providerScope: 'provider-a',
      requestUri: Uri.parse('http://127.0.0.1/admin'),
      failureKind: NetworkPolicyFailureKind.loopbackAddress.name,
      reason: 'Loopback blocked.',
    ));
    bus.publish(NetworkPolicyCapabilityChanged(
      occurredAt: observedAt,
      providerScope: 'provider-a',
      capability: NetworkPolicyCapability.dotIntent.name,
      supported: false,
      reason: 'DoT unavailable.',
    ));
    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(loopback.kind, NetworkPolicyFailureKind.loopbackAddress);
    expect(unsupported.kind, NetworkPolicyFailureKind.unsupportedCapability);
    expect(handoff.requestKey.cacheKey, 'provider-a::secure');
    expect(handoff.networkPolicyRequest.requirePolicyCapability, isTrue);
    expect(delivered.whereType<NetworkPolicyProfileChanged>().length, 1);
    expect(delivered.whereType<NetworkPolicyProviderAssignmentChanged>().length,
        1);
    expect(delivered.whereType<NetworkPolicyRuleChanged>().length, 1);
    expect(delivered.whereType<NetworkPolicyEvaluationOutcomeRecorded>().length,
        1);
    expect(delivered.whereType<NetworkPolicyBlockDecisionRecorded>().length, 1);
    expect(delivered.whereType<NetworkPolicyCapabilityChanged>().length, 1);
  });
}
