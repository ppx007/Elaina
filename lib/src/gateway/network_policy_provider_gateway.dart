import '../foundation/constants.dart';
import '../foundation/gateway/provider_gateway.dart';
import '../foundation/storage/storage_contracts.dart';
import '../network/network_policy.dart';

const String defaultProviderGatewayNetworkPolicyId =
    AppConstants.defaultNetworkPolicyId;

final class NetworkPolicyProviderGateway implements ProviderGateway {
  NetworkPolicyProviderGateway({
    required ProviderGateway delegate,
    required NetworkPolicyStore networkPolicyStore,
    NetworkPolicyEvaluator? evaluator,
    this.policyId = defaultProviderGatewayNetworkPolicyId,
  })  : _delegate = delegate,
        _networkPolicyStore = networkPolicyStore,
        _evaluator = evaluator ?? DeterministicNetworkPolicyEvaluator();

  final ProviderGateway _delegate;
  final NetworkPolicyStore _networkPolicyStore;
  final NetworkPolicyEvaluator _evaluator;
  final String policyId;

  @override
  StorageFoundation get storage => _delegate.storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) {
    return _delegate.registerProvider(registration);
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) async {
    final Uri? requestUri = request.networkPolicyUri;
    if (requestUri == null) return _delegate.execute(request);

    final String providerScope = request.resolvedNetworkPolicyProviderScope;
    final List<StoredNetworkPolicyRuleRecord> records =
        await _networkPolicyStore.rulesForPolicy(policyId);
    if (records.isEmpty) return _delegate.execute(request);

    final NetworkPolicyRequest policyRequest = NetworkPolicyRequest(
      providerScope: providerScope,
      uri: requestUri,
      redirectedFrom: request.redirectedFrom,
      cacheKey: request.key.cacheKey,
    );
    final NetworkPolicy policy = NetworkPolicy(
      id: NetworkPolicyId(policyId),
      providerScope: providerScope,
      rules: records.map(_networkPolicyRuleFromRecord),
      auditMetadata: NetworkPolicyAuditMetadata(label: 'provider-gateway'),
    );
    final NetworkPolicyDecision decision =
        await _evaluator.evaluate(policy: policy, request: policyRequest);
    await _recordNetworkPolicyDecision(_networkPolicyStore, decision);

    if (decision is NetworkPolicyBlocked) {
      throw ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message: 'Network policy blocked provider request: ${decision.reason}',
      );
    }

    final String? proxyUrl = decision is NetworkPolicyAllowed &&
            decision.action == NetworkPolicyAction.proxyTag
        ? decision.proxyTag
        : null;
    return _delegate.execute(
      ProviderGatewayRequest<T>(
        key: request.key,
        load: () => request.executeLoad(
          ProviderGatewayRequestContext(proxyUrl: proxyUrl),
        ),
        cachePolicy: request.cachePolicy,
        deduplicationWindow: request.deduplicationWindow,
      ),
    );
  }
}

NetworkPolicyRule _networkPolicyRuleFromRecord(
    StoredNetworkPolicyRuleRecord record) {
  return NetworkPolicyRule(
    id: NetworkPolicyRuleId(record.id),
    order: record.order,
    matcher: NetworkPolicyMatcher(
      kind: _networkPolicyMatcherKind(record.matcherKind),
      pattern: record.pattern,
    ),
    action: _networkPolicyAction(record.action),
    resolverIntent: _resolverIntent(record),
    proxyIntent: record.proxyTag == null
        ? null
        : NetworkProxyIntent(proxyTag: record.proxyTag!),
    fallbackBehavior: _networkPolicyFallback(record.fallbackBehavior),
    auditLabel: record.auditLabel,
    requiresStrictCapability: record.requiresStrictCapability,
  );
}

NetworkResolverIntent? _resolverIntent(StoredNetworkPolicyRuleRecord record) {
  return switch (record.action) {
    StoredNetworkPolicyAction.systemDns =>
      const NetworkResolverIntent.systemDns(),
    StoredNetworkPolicyAction.configuredDns => record.resolverTag == null
        ? null
        : NetworkResolverIntent.configuredDns(resolverTag: record.resolverTag!),
    StoredNetworkPolicyAction.doh => record.resolverEndpoint == null
        ? null
        : NetworkResolverIntent.doh(endpoint: record.resolverEndpoint!),
    StoredNetworkPolicyAction.dot => record.resolverHost == null
        ? null
        : NetworkResolverIntent.dot(resolverHost: record.resolverHost!),
    StoredNetworkPolicyAction.proxyTag ||
    StoredNetworkPolicyAction.direct ||
    StoredNetworkPolicyAction.block =>
      null,
  };
}

Future<void> _recordNetworkPolicyDecision(
  NetworkPolicyStore store,
  NetworkPolicyDecision decision,
) async {
  final DateTime now = DateTime.now();
  final String providerScope = decision.request.providerScope;
  final String evaluationId =
      'gateway-eval-$providerScope-${now.microsecondsSinceEpoch}';
  await store.recordEvaluation(
    StoredNetworkPolicyEvaluationSnapshotRecord(
      id: evaluationId,
      providerScope: providerScope,
      requestUri: decision.request.uri,
      decisionKind: decision is NetworkPolicyBlocked
          ? StoredNetworkPolicyDecisionKind.blocked
          : StoredNetworkPolicyDecisionKind.allowed,
      recordedAt: now,
      policyId: decision.policyId?.value,
      ruleId: decision.ruleId?.value,
      redirectedFrom: decision.request.redirectedFrom,
      cacheKey: decision.request.cacheKey,
      action: decision is NetworkPolicyAllowed
          ? _storedNetworkPolicyAction(decision.action)
          : null,
      failureKind: decision is NetworkPolicyBlocked ? decision.kind : null,
      auditLabel: decision.auditLabel,
      reason: decision is NetworkPolicyBlocked ? decision.reason : null,
    ),
  );
  if (decision is NetworkPolicyBlocked) {
    await store.recordBlockOutcome(
      StoredNetworkPolicyBlockOutcomeRecord(
        id: 'gateway-block-$providerScope-${now.microsecondsSinceEpoch}',
        evaluationId: evaluationId,
        providerScope: providerScope,
        requestUri: decision.request.uri,
        failureKind: decision.kind,
        reason: decision.reason,
        recordedAt: now,
      ),
    );
  }
}

NetworkPolicyMatcherKind _networkPolicyMatcherKind(
    StoredNetworkPolicyMatcherKind kind) {
  return switch (kind) {
    StoredNetworkPolicyMatcherKind.exactHost =>
      NetworkPolicyMatcherKind.exactHost,
    StoredNetworkPolicyMatcherKind.domainSuffix =>
      NetworkPolicyMatcherKind.domainSuffix,
    StoredNetworkPolicyMatcherKind.wildcardHost =>
      NetworkPolicyMatcherKind.wildcardHost,
    StoredNetworkPolicyMatcherKind.cidr => NetworkPolicyMatcherKind.cidr,
  };
}

NetworkPolicyAction _networkPolicyAction(StoredNetworkPolicyAction action) {
  return switch (action) {
    StoredNetworkPolicyAction.systemDns => NetworkPolicyAction.systemDns,
    StoredNetworkPolicyAction.configuredDns =>
      NetworkPolicyAction.configuredDns,
    StoredNetworkPolicyAction.doh => NetworkPolicyAction.doh,
    StoredNetworkPolicyAction.dot => NetworkPolicyAction.dot,
    StoredNetworkPolicyAction.proxyTag => NetworkPolicyAction.proxyTag,
    StoredNetworkPolicyAction.direct => NetworkPolicyAction.direct,
    StoredNetworkPolicyAction.block => NetworkPolicyAction.block,
  };
}

StoredNetworkPolicyAction _storedNetworkPolicyAction(
    NetworkPolicyAction action) {
  return switch (action) {
    NetworkPolicyAction.systemDns => StoredNetworkPolicyAction.systemDns,
    NetworkPolicyAction.configuredDns =>
      StoredNetworkPolicyAction.configuredDns,
    NetworkPolicyAction.doh => StoredNetworkPolicyAction.doh,
    NetworkPolicyAction.dot => StoredNetworkPolicyAction.dot,
    NetworkPolicyAction.proxyTag => StoredNetworkPolicyAction.proxyTag,
    NetworkPolicyAction.direct => StoredNetworkPolicyAction.direct,
    NetworkPolicyAction.block => StoredNetworkPolicyAction.block,
  };
}

NetworkPolicyFallbackBehavior _networkPolicyFallback(
    StoredNetworkPolicyFallbackBehavior fallback) {
  return switch (fallback) {
    StoredNetworkPolicyFallbackBehavior.systemDns =>
      NetworkPolicyFallbackBehavior.systemDns,
    StoredNetworkPolicyFallbackBehavior.direct =>
      NetworkPolicyFallbackBehavior.direct,
    StoredNetworkPolicyFallbackBehavior.block =>
      NetworkPolicyFallbackBehavior.block,
  };
}
