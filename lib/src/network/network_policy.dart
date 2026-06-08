import '../foundation/gateway/provider_gateway.dart';

final class NetworkPolicyId {
  const NetworkPolicyId(this.value)
      : assert(value != '', 'Network policy id must not be empty.');

  final String value;
}

final class NetworkPolicyRuleId {
  const NetworkPolicyRuleId(this.value)
      : assert(value != '', 'Network policy rule id must not be empty.');

  final String value;
}

final class NetworkPolicyAssignmentId {
  const NetworkPolicyAssignmentId(this.value)
      : assert(value != '', 'Network policy assignment id must not be empty.');

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
  doh,
  dot,
  proxyTag,
  direct,
  block,
}

enum NetworkPolicyFallbackBehavior {
  systemDns,
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
  dohIntent,
  dotIntent,
  proxyIntent,
  redirectValidation,
  ssrfGuard,
  backgroundNetworkPolicy,
}

final class NetworkPolicyMatcher {
  const NetworkPolicyMatcher({required this.kind, required this.pattern})
      : assert(
            pattern != '', 'Network policy matcher pattern must not be empty.');

  final NetworkPolicyMatcherKind kind;
  final String pattern;
}

final class NetworkResolverIntent {
  const NetworkResolverIntent.systemDns()
      : this._(kind: NetworkPolicyAction.systemDns);

  const NetworkResolverIntent.configuredDns({required String resolverTag})
      : this._(
            kind: NetworkPolicyAction.configuredDns, resolverTag: resolverTag);

  const NetworkResolverIntent.doh({required Uri endpoint, String? resolverTag})
      : this._(
          kind: NetworkPolicyAction.doh,
          resolverEndpoint: endpoint,
          resolverTag: resolverTag,
        );

  const NetworkResolverIntent.dot(
      {required String resolverHost, String? resolverTag})
      : this._(
          kind: NetworkPolicyAction.dot,
          resolverHost: resolverHost,
          resolverTag: resolverTag,
        );

  const NetworkResolverIntent._({
    required this.kind,
    this.resolverTag,
    this.resolverEndpoint,
    this.resolverHost,
  });

  final NetworkPolicyAction kind;
  final String? resolverTag;
  final Uri? resolverEndpoint;
  final String? resolverHost;
}

final class NetworkProxyIntent {
  const NetworkProxyIntent({required this.proxyTag})
      : assert(proxyTag != '', 'Network proxy tag must not be empty.');

  final String proxyTag;
}

final class NetworkPolicyAuditMetadata {
  NetworkPolicyAuditMetadata({
    required this.label,
    this.updatedBy,
    this.updatedAt,
    Map<String, String> tags = const <String, String>{},
  })  : assert(label != '', 'Network policy audit label must not be empty.'),
        tags = Map<String, String>.unmodifiable(tags);

  final String label;
  final String? updatedBy;
  final DateTime? updatedAt;
  final Map<String, String> tags;
}

final class NetworkPolicyRule {
  const NetworkPolicyRule({
    required this.id,
    required this.order,
    required this.matcher,
    required this.action,
    this.resolverIntent,
    this.proxyIntent,
    this.fallbackBehavior = NetworkPolicyFallbackBehavior.systemDns,
    this.auditLabel,
    this.requiresStrictCapability = false,
  });

  final NetworkPolicyRuleId id;
  final int order;
  final NetworkPolicyMatcher matcher;
  final NetworkPolicyAction action;
  final NetworkResolverIntent? resolverIntent;
  final NetworkProxyIntent? proxyIntent;
  final NetworkPolicyFallbackBehavior fallbackBehavior;
  final String? auditLabel;
  final bool requiresStrictCapability;

  String? get resolverTag => resolverIntent?.resolverTag;

  String? get proxyTag => proxyIntent?.proxyTag;
}

final class NetworkPolicy {
  NetworkPolicy({
    required this.id,
    required this.providerScope,
    Iterable<NetworkPolicyRule> rules = const <NetworkPolicyRule>[],
    this.fallbackBehavior = NetworkPolicyFallbackBehavior.systemDns,
    this.auditMetadata,
  })  : assert(providerScope != '',
            'Network policy provider scope must not be empty.'),
        rules = List<NetworkPolicyRule>.unmodifiable(
          <NetworkPolicyRule>[...rules]..sort(
              (NetworkPolicyRule left, NetworkPolicyRule right) =>
                  left.order.compareTo(right.order)),
        );

  final NetworkPolicyId id;
  final String providerScope;
  final List<NetworkPolicyRule> rules;
  final NetworkPolicyFallbackBehavior fallbackBehavior;
  final NetworkPolicyAuditMetadata? auditMetadata;
}

final class NetworkPolicyProviderAssignment {
  const NetworkPolicyProviderAssignment({
    required this.id,
    required this.providerScope,
    required this.policyId,
    required this.assignedAt,
    this.reason,
  }) : assert(providerScope != '',
            'Network policy assignment provider scope must not be empty.');

  final NetworkPolicyAssignmentId id;
  final String providerScope;
  final NetworkPolicyId policyId;
  final DateTime assignedAt;
  final String? reason;
}

final class NetworkPolicyRequest {
  const NetworkPolicyRequest({
    required this.providerScope,
    required this.uri,
    this.redirectedFrom,
    this.cacheKey,
    this.requirePolicyCapability = false,
  }) : assert(providerScope != '',
            'Network policy provider scope must not be empty.');

  final String providerScope;
  final Uri uri;
  final Uri? redirectedFrom;
  final String? cacheKey;
  final bool requirePolicyCapability;
}

sealed class NetworkPolicyDecision {
  const NetworkPolicyDecision({
    required this.request,
    this.policyId,
    this.ruleId,
    this.auditLabel,
    this.fallbackBehavior = NetworkPolicyFallbackBehavior.systemDns,
  });

  final NetworkPolicyRequest request;
  final NetworkPolicyId? policyId;
  final NetworkPolicyRuleId? ruleId;
  final String? auditLabel;
  final NetworkPolicyFallbackBehavior fallbackBehavior;
}

final class NetworkPolicyAllowed extends NetworkPolicyDecision {
  const NetworkPolicyAllowed({
    required super.request,
    required this.action,
    super.policyId,
    super.ruleId,
    super.auditLabel,
    super.fallbackBehavior,
    this.resolverIntent,
    this.proxyIntent,
    this.capabilityFallbackReason,
  });

  final NetworkPolicyAction action;
  final NetworkResolverIntent? resolverIntent;
  final NetworkProxyIntent? proxyIntent;
  final String? capabilityFallbackReason;

  String? get resolverTag => resolverIntent?.resolverTag;

  String? get proxyTag => proxyIntent?.proxyTag;
}

final class NetworkPolicyBlocked extends NetworkPolicyDecision {
  const NetworkPolicyBlocked({
    required super.request,
    required this.kind,
    required this.reason,
    super.policyId,
    super.ruleId,
    super.auditLabel,
    super.fallbackBehavior = NetworkPolicyFallbackBehavior.block,
  }) : assert(reason != '', 'Network policy block reason must not be empty.');

  final NetworkPolicyFailureKind kind;
  final String reason;
}

final class NetworkPolicyEvaluationSnapshot {
  const NetworkPolicyEvaluationSnapshot({
    required this.id,
    required this.providerScope,
    required this.requestUri,
    required this.decisionKind,
    required this.recordedAt,
    this.policyId,
    this.ruleId,
    this.failureKind,
    this.action,
    this.redirectedFrom,
    this.cacheKey,
    this.auditLabel,
    this.reason,
  })  : assert(id != '',
            'Network policy evaluation snapshot id must not be empty.'),
        assert(providerScope != '',
            'Network policy evaluation provider scope must not be empty.'),
        assert(decisionKind != '',
            'Network policy evaluation decision kind must not be empty.');

  final String id;
  final String providerScope;
  final Uri requestUri;
  final Uri? redirectedFrom;
  final String? cacheKey;
  final NetworkPolicyId? policyId;
  final NetworkPolicyRuleId? ruleId;
  final String decisionKind;
  final NetworkPolicyFailureKind? failureKind;
  final NetworkPolicyAction? action;
  final String? auditLabel;
  final String? reason;
  final DateTime recordedAt;
}

final class NetworkPolicyCapabilityStatus {
  const NetworkPolicyCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const NetworkPolicyCapabilityStatus.unsupported(this.reason)
      : supported = false;

  final bool supported;
  final String? reason;
}

final class NetworkPolicyCapabilityMatrix {
  NetworkPolicyCapabilityMatrix({
    required Map<NetworkPolicyCapability, NetworkPolicyCapabilityStatus>
        capabilities,
  }) : _capabilities = Map<NetworkPolicyCapability,
            NetworkPolicyCapabilityStatus>.unmodifiable(capabilities);

  factory NetworkPolicyCapabilityMatrix.supported() {
    return NetworkPolicyCapabilityMatrix(
      capabilities: <NetworkPolicyCapability, NetworkPolicyCapabilityStatus>{
        for (final NetworkPolicyCapability capability
            in NetworkPolicyCapability.values)
          capability: const NetworkPolicyCapabilityStatus.supported(),
      },
    );
  }

  factory NetworkPolicyCapabilityMatrix.unsupported({required String reason}) {
    return NetworkPolicyCapabilityMatrix(
      capabilities: <NetworkPolicyCapability, NetworkPolicyCapabilityStatus>{
        for (final NetworkPolicyCapability capability
            in NetworkPolicyCapability.values)
          capability: NetworkPolicyCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<NetworkPolicyCapability, NetworkPolicyCapabilityStatus>
      _capabilities;

  NetworkPolicyCapabilityStatus statusOf(NetworkPolicyCapability capability) {
    return _capabilities[capability] ??
        const NetworkPolicyCapabilityStatus.unsupported(
            'Capability is not declared.');
  }
}

final class ProviderNetworkPolicyHandoffDescriptor {
  const ProviderNetworkPolicyHandoffDescriptor({
    required this.providerId,
    required this.providerScope,
    required this.cacheKey,
    required this.requestUri,
    required this.cachePolicy,
    required this.ratePolicy,
    required this.retryPolicy,
    this.redirectedFrom,
    this.requiredCapabilities = const <NetworkPolicyCapability>{},
    this.negativeCachePolicy,
    this.policyRequirementLabel,
  })  : assert(providerScope != '',
            'Provider network policy scope must not be empty.'),
        assert(cacheKey != '',
            'Provider network policy cache key must not be empty.');

  final ProviderId providerId;
  final String providerScope;
  final String cacheKey;
  final Uri requestUri;
  final Uri? redirectedFrom;
  final ProviderCachePolicy cachePolicy;
  final ProviderRatePolicy ratePolicy;
  final ProviderRetryPolicy retryPolicy;
  final ProviderNegativeCachePolicy? negativeCachePolicy;
  final Set<NetworkPolicyCapability> requiredCapabilities;
  final String? policyRequirementLabel;

  ProviderRegistration get registration {
    return ProviderRegistration(
      providerId: providerId,
      ratePolicy: ratePolicy,
      retryPolicy: retryPolicy,
      negativeCachePolicy: negativeCachePolicy,
    );
  }

  ProviderRequestKey get requestKey {
    return ProviderRequestKey(providerId: providerId, cacheKey: cacheKey);
  }

  NetworkPolicyRequest get networkPolicyRequest {
    return NetworkPolicyRequest(
      providerScope: providerScope,
      uri: requestUri,
      redirectedFrom: redirectedFrom,
      cacheKey: cacheKey,
      requirePolicyCapability: requiredCapabilities.isNotEmpty,
    );
  }
}

abstract interface class NetworkPolicyEvaluator {
  NetworkPolicyCapabilityMatrix get capabilities;

  Future<NetworkPolicyDecision> evaluate({
    required NetworkPolicy policy,
    required NetworkPolicyRequest request,
  });
}

final class DeterministicNetworkPolicyEvaluator
    implements NetworkPolicyEvaluator {
  DeterministicNetworkPolicyEvaluator(
      {NetworkPolicyCapabilityMatrix? capabilities})
      : capabilities =
            capabilities ?? NetworkPolicyCapabilityMatrix.supported();

  @override
  final NetworkPolicyCapabilityMatrix capabilities;

  @override
  Future<NetworkPolicyDecision> evaluate({
    required NetworkPolicy policy,
    required NetworkPolicyRequest request,
  }) {
    if (policy.providerScope != request.providerScope) {
      return Future<NetworkPolicyDecision>.value(
        NetworkPolicyBlocked(
          request: request,
          policyId: policy.id,
          kind: NetworkPolicyFailureKind.blockedHost,
          reason: 'Network policy provider scope does not match request scope.',
        ),
      );
    }

    final NetworkPolicyBlocked? securityBlock = _securityBlock(policy, request);
    if (securityBlock != null) {
      return Future<NetworkPolicyDecision>.value(securityBlock);
    }

    final String host = request.uri.host.toLowerCase();
    for (final NetworkPolicyRule rule in policy.rules) {
      if (_matches(rule.matcher, host)) {
        return Future<NetworkPolicyDecision>.value(
            _decisionForRule(policy, request, rule));
      }
    }

    return Future<NetworkPolicyDecision>.value(
      NetworkPolicyAllowed(
        request: request,
        policyId: policy.id,
        action: _fallbackAction(policy.fallbackBehavior),
        fallbackBehavior: policy.fallbackBehavior,
        auditLabel: policy.auditMetadata?.label,
      ),
    );
  }

  NetworkPolicyDecision _decisionForRule(
    NetworkPolicy policy,
    NetworkPolicyRequest request,
    NetworkPolicyRule rule,
  ) {
    if (rule.action == NetworkPolicyAction.block) {
      return NetworkPolicyBlocked(
        request: request,
        policyId: policy.id,
        ruleId: rule.id,
        auditLabel: rule.auditLabel ?? policy.auditMetadata?.label,
        kind: NetworkPolicyFailureKind.blockedHost,
        reason: 'Host blocked by network policy rule.',
      );
    }

    final NetworkPolicyCapability? capability =
        _requiredCapability(rule.action);
    if (capability != null) {
      final NetworkPolicyCapabilityStatus status =
          capabilities.statusOf(capability);
      if (!status.supported) {
        if (rule.requiresStrictCapability ||
            rule.fallbackBehavior == NetworkPolicyFallbackBehavior.block) {
          return NetworkPolicyBlocked(
            request: request,
            policyId: policy.id,
            ruleId: rule.id,
            auditLabel: rule.auditLabel ?? policy.auditMetadata?.label,
            kind: NetworkPolicyFailureKind.unsupportedCapability,
            reason: status.reason ??
                'Required network policy capability is unsupported.',
          );
        }
        return NetworkPolicyAllowed(
          request: request,
          policyId: policy.id,
          ruleId: rule.id,
          action: _fallbackAction(rule.fallbackBehavior),
          fallbackBehavior: rule.fallbackBehavior,
          auditLabel: rule.auditLabel ?? policy.auditMetadata?.label,
          capabilityFallbackReason: status.reason,
        );
      }
    }

    return NetworkPolicyAllowed(
      request: request,
      policyId: policy.id,
      ruleId: rule.id,
      action: rule.action,
      resolverIntent: rule.resolverIntent,
      proxyIntent: rule.proxyIntent,
      fallbackBehavior: rule.fallbackBehavior,
      auditLabel: rule.auditLabel ?? policy.auditMetadata?.label,
    );
  }

  NetworkPolicyBlocked? _securityBlock(
      NetworkPolicy policy, NetworkPolicyRequest request) {
    if (!_isHttpScheme(request.uri)) {
      return NetworkPolicyBlocked(
        request: request,
        policyId: policy.id,
        kind: NetworkPolicyFailureKind.disallowedScheme,
        reason:
            'Only HTTP and HTTPS provider traffic can use network policy evaluation.',
      );
    }
    if (request.redirectedFrom != null &&
        !_isHttpScheme(request.redirectedFrom!)) {
      return NetworkPolicyBlocked(
        request: request,
        policyId: policy.id,
        kind: NetworkPolicyFailureKind.unsafeRedirect,
        reason: 'Redirect source uses a disallowed scheme.',
      );
    }
    final NetworkPolicyFailureKind? hostFailure =
        _hostFailureKind(request.uri.host);
    if (hostFailure != null) {
      return NetworkPolicyBlocked(
        request: request,
        policyId: policy.id,
        kind: hostFailure,
        reason: 'Request host is blocked by SSRF guard.',
      );
    }
    return null;
  }

  static NetworkPolicyFailureKind? _hostFailureKind(String host) {
    final String normalized = host.toLowerCase();
    if (normalized == 'localhost') {
      return NetworkPolicyFailureKind.loopbackAddress;
    }
    final List<int>? octets = _ipv4Octets(normalized);
    if (octets == null) {
      return null;
    }
    if (octets[0] == 127) {
      return NetworkPolicyFailureKind.loopbackAddress;
    }
    if (octets[0] == 169 && octets[1] == 254) {
      return NetworkPolicyFailureKind.linkLocalAddress;
    }
    if (octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168)) {
      return NetworkPolicyFailureKind.privateNetworkAddress;
    }
    return null;
  }

  static bool _isHttpScheme(Uri uri) =>
      uri.scheme == 'http' || uri.scheme == 'https';

  static NetworkPolicyAction _fallbackAction(
      NetworkPolicyFallbackBehavior fallback) {
    return switch (fallback) {
      NetworkPolicyFallbackBehavior.systemDns => NetworkPolicyAction.systemDns,
      NetworkPolicyFallbackBehavior.direct => NetworkPolicyAction.direct,
      NetworkPolicyFallbackBehavior.block => NetworkPolicyAction.block,
    };
  }

  static NetworkPolicyCapability? _requiredCapability(
      NetworkPolicyAction action) {
    return switch (action) {
      NetworkPolicyAction.configuredDns =>
        NetworkPolicyCapability.configuredDnsIntent,
      NetworkPolicyAction.doh => NetworkPolicyCapability.dohIntent,
      NetworkPolicyAction.dot => NetworkPolicyCapability.dotIntent,
      NetworkPolicyAction.proxyTag => NetworkPolicyCapability.proxyIntent,
      NetworkPolicyAction.systemDns ||
      NetworkPolicyAction.direct ||
      NetworkPolicyAction.block =>
        null,
    };
  }

  static bool _matches(NetworkPolicyMatcher matcher, String host) {
    final String pattern = matcher.pattern.toLowerCase();
    return switch (matcher.kind) {
      NetworkPolicyMatcherKind.exactHost => host == pattern,
      NetworkPolicyMatcherKind.domainSuffix =>
        host == _trimLeadingDot(pattern) ||
            host.endsWith('.${_trimLeadingDot(pattern)}'),
      NetworkPolicyMatcherKind.wildcardHost => _matchesWildcard(pattern, host),
      NetworkPolicyMatcherKind.cidr => _matchesCidr(pattern, host),
    };
  }

  static bool _matchesWildcard(String pattern, String host) {
    if (!pattern.startsWith('*.')) {
      return host == pattern;
    }
    final String suffix = pattern.substring(2);
    return host.endsWith('.$suffix') && host != suffix;
  }

  static bool _matchesCidr(String pattern, String host) {
    final List<String> parts = pattern.split('/');
    if (parts.length != 2) {
      return false;
    }
    final List<int>? hostOctets = _ipv4Octets(host);
    final List<int>? baseOctets = _ipv4Octets(parts[0]);
    final int? prefix = int.tryParse(parts[1]);
    if (hostOctets == null ||
        baseOctets == null ||
        prefix == null ||
        prefix < 0 ||
        prefix > 32) {
      return false;
    }
    final int hostValue = _ipv4Value(hostOctets);
    final int baseValue = _ipv4Value(baseOctets);
    final int mask =
        prefix == 0 ? 0 : (0xffffffff << (32 - prefix)) & 0xffffffff;
    return (hostValue & mask) == (baseValue & mask);
  }

  static String _trimLeadingDot(String value) =>
      value.startsWith('.') ? value.substring(1) : value;

  static List<int>? _ipv4Octets(String value) {
    final List<String> parts = value.split('.');
    if (parts.length != 4) {
      return null;
    }
    final List<int> octets = <int>[];
    for (final String part in parts) {
      final int? parsed = int.tryParse(part);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return null;
      }
      octets.add(parsed);
    }
    return octets;
  }

  static int _ipv4Value(List<int> octets) {
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }
}
