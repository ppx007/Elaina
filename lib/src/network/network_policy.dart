final class NetworkPolicyId {
  const NetworkPolicyId(this.value) : assert(value != '', 'Network policy id must not be empty.');

  final String value;
}

final class NetworkPolicyRuleId {
  const NetworkPolicyRuleId(this.value) : assert(value != '', 'Network policy rule id must not be empty.');

  final String value;
}

enum NetworkPolicyMatcherKind {
  exactHost,
  domainSuffix,
  wildcardHost,
  cidr,
}

enum NetworkPolicyAction {
  systemDns,
  configuredDns,
  proxyTag,
  direct,
  block,
}

enum NetworkPolicyFailureKind {
  disallowedScheme,
  loopbackAddress,
  linkLocalAddress,
  privateNetworkAddress,
  unsafeRedirect,
  blockedHost,
  unsupportedCapability,
}

enum NetworkPolicyCapability {
  configuredDnsIntent,
  proxyIntent,
  redirectValidation,
  ssrfGuard,
  backgroundNetworkPolicy,
}

final class NetworkPolicyMatcher {
  const NetworkPolicyMatcher({required this.kind, required this.pattern})
      : assert(pattern != '', 'Network policy matcher pattern must not be empty.');

  final NetworkPolicyMatcherKind kind;
  final String pattern;
}

final class NetworkPolicyRule {
  const NetworkPolicyRule({
    required this.id,
    required this.order,
    required this.matcher,
    required this.action,
    this.resolverTag,
    this.proxyTag,
    this.auditLabel,
  });

  final NetworkPolicyRuleId id;
  final int order;
  final NetworkPolicyMatcher matcher;
  final NetworkPolicyAction action;
  final String? resolverTag;
  final String? proxyTag;
  final String? auditLabel;
}

final class NetworkPolicy {
  NetworkPolicy({
    required this.id,
    required this.providerScope,
    Iterable<NetworkPolicyRule> rules = const <NetworkPolicyRule>[],
    this.fallbackAction = NetworkPolicyAction.systemDns,
  })  : assert(providerScope != '', 'Network policy provider scope must not be empty.'),
        rules = List<NetworkPolicyRule>.unmodifiable(rules);

  final NetworkPolicyId id;
  final String providerScope;
  final List<NetworkPolicyRule> rules;
  final NetworkPolicyAction fallbackAction;
}

final class NetworkPolicyRequest {
  const NetworkPolicyRequest({
    required this.providerScope,
    required this.uri,
    this.redirectedFrom,
  }) : assert(providerScope != '', 'Network policy provider scope must not be empty.');

  final String providerScope;
  final Uri uri;
  final Uri? redirectedFrom;
}

sealed class NetworkPolicyDecision {
  const NetworkPolicyDecision({required this.request, this.ruleId});

  final NetworkPolicyRequest request;
  final NetworkPolicyRuleId? ruleId;
}

final class NetworkPolicyAllowed extends NetworkPolicyDecision {
  const NetworkPolicyAllowed({
    required super.request,
    required this.action,
    super.ruleId,
    this.resolverTag,
    this.proxyTag,
    this.auditLabel,
  });

  final NetworkPolicyAction action;
  final String? resolverTag;
  final String? proxyTag;
  final String? auditLabel;
}

final class NetworkPolicyBlocked extends NetworkPolicyDecision {
  const NetworkPolicyBlocked({
    required super.request,
    required this.kind,
    required this.reason,
    super.ruleId,
  }) : assert(reason != '', 'Network policy block reason must not be empty.');

  final NetworkPolicyFailureKind kind;
  final String reason;
}

final class NetworkPolicyCapabilityStatus {
  const NetworkPolicyCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const NetworkPolicyCapabilityStatus.unsupported(this.reason) : supported = false;

  final bool supported;
  final String? reason;
}

final class NetworkPolicyCapabilityMatrix {
  NetworkPolicyCapabilityMatrix({required Map<NetworkPolicyCapability, NetworkPolicyCapabilityStatus> capabilities})
      : _capabilities = Map<NetworkPolicyCapability, NetworkPolicyCapabilityStatus>.unmodifiable(capabilities);

  factory NetworkPolicyCapabilityMatrix.unsupported({required String reason}) {
    return NetworkPolicyCapabilityMatrix(
      capabilities: <NetworkPolicyCapability, NetworkPolicyCapabilityStatus>{
        for (final NetworkPolicyCapability capability in NetworkPolicyCapability.values)
          capability: NetworkPolicyCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<NetworkPolicyCapability, NetworkPolicyCapabilityStatus> _capabilities;

  NetworkPolicyCapabilityStatus statusOf(NetworkPolicyCapability capability) {
    return _capabilities[capability] ?? const NetworkPolicyCapabilityStatus.unsupported('Capability is not declared.');
  }
}

abstract interface class NetworkPolicyEvaluator {
  NetworkPolicyCapabilityMatrix get capabilities;

  Future<NetworkPolicyDecision> evaluate({required NetworkPolicy policy, required NetworkPolicyRequest request});
}
