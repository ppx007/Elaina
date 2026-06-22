import '../../network/network_policy.dart';

/// Stored network policy records describe user/operator policy configuration.
/// ProviderGateway evaluates these through NetworkPolicyRuntime before HTTP.
enum StoredNetworkPolicyAction {
  systemDns,
  configuredDns,
  doh,
  dot,
  proxyTag,
  direct,
  block,
}

enum StoredNetworkPolicyMatcherKind {
  exactHost,
  domainSuffix,
  wildcardHost,
  cidr,
}

enum StoredNetworkPolicyFallbackBehavior {
  systemDns,
  direct,
  block,
}

enum StoredNetworkPolicyDecisionKind {
  allowed,
  blocked,
  fallback,
}

enum StoredNetworkPolicyCapabilityState {
  supported,
  unsupported,
  disabled,
}

final class StoredNetworkPolicyProfileRecord {
  StoredNetworkPolicyProfileRecord({
    required this.id,
    required this.providerScope,
    required this.label,
    required this.fallbackBehavior,
    required this.createdAt,
    required this.updatedAt,
    Map<String, String> auditMetadata = const <String, String>{},
  })  : assert(id != '', 'Network policy profile id must not be empty.'),
        assert(providerScope != '',
            'Network policy provider scope must not be empty.'),
        assert(label != '', 'Network policy profile label must not be empty.'),
        auditMetadata = Map<String, String>.unmodifiable(auditMetadata);

  final String id;
  final String providerScope;
  final String label;
  final StoredNetworkPolicyFallbackBehavior fallbackBehavior;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> auditMetadata;
}

final class StoredNetworkPolicyRuleRecord {
  StoredNetworkPolicyRuleRecord({
    required this.id,
    required this.policyId,
    required this.order,
    required this.matcherKind,
    required this.pattern,
    required this.action,
    this.resolverTag,
    this.resolverEndpoint,
    this.resolverHost,
    this.proxyTag,
    this.auditLabel,
    this.fallbackBehavior = StoredNetworkPolicyFallbackBehavior.systemDns,
    this.requiresStrictCapability = false,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(id != '', 'Network policy rule id must not be empty.'),
        assert(
            policyId != '', 'Network policy rule policy id must not be empty.'),
        assert(pattern != '',
            'Network policy rule matcher pattern must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String id;
  final String policyId;
  final int order;
  final StoredNetworkPolicyMatcherKind matcherKind;
  final String pattern;
  final StoredNetworkPolicyAction action;
  final String? resolverTag;
  final Uri? resolverEndpoint;
  final String? resolverHost;
  final String? proxyTag;
  final String? auditLabel;
  final StoredNetworkPolicyFallbackBehavior fallbackBehavior;
  final bool requiresStrictCapability;
  final Map<String, String> metadata;
}

final class StoredNetworkPolicyProviderAssignmentRecord {
  const StoredNetworkPolicyProviderAssignmentRecord({
    required this.id,
    required this.providerScope,
    required this.policyId,
    required this.assignedAt,
    this.reason,
  })  : assert(id != '', 'Network policy assignment id must not be empty.'),
        assert(providerScope != '',
            'Network policy assignment provider scope must not be empty.'),
        assert(policyId != '',
            'Network policy assignment policy id must not be empty.');

  final String id;
  final String providerScope;
  final String policyId;
  final String? reason;
  final DateTime assignedAt;
}

final class StoredNetworkPolicyEvaluationSnapshotRecord {
  const StoredNetworkPolicyEvaluationSnapshotRecord({
    required this.id,
    required this.providerScope,
    required this.requestUri,
    required this.decisionKind,
    required this.recordedAt,
    this.policyId,
    this.ruleId,
    this.redirectedFrom,
    this.cacheKey,
    this.action,
    this.failureKind,
    this.auditLabel,
    this.reason,
  })  : assert(id != '', 'Network policy evaluation id must not be empty.'),
        assert(providerScope != '',
            'Network policy evaluation provider scope must not be empty.');

  final String id;
  final String providerScope;
  final Uri requestUri;
  final Uri? redirectedFrom;
  final String? cacheKey;
  final String? policyId;
  final String? ruleId;
  final StoredNetworkPolicyDecisionKind decisionKind;
  final StoredNetworkPolicyAction? action;
  final NetworkPolicyFailureKind? failureKind;
  final String? auditLabel;
  final String? reason;
  final DateTime recordedAt;
}

final class StoredNetworkPolicyBlockOutcomeRecord {
  const StoredNetworkPolicyBlockOutcomeRecord({
    required this.id,
    required this.evaluationId,
    required this.providerScope,
    required this.requestUri,
    required this.failureKind,
    required this.reason,
    required this.recordedAt,
  })  : assert(id != '', 'Network policy block outcome id must not be empty.'),
        assert(evaluationId != '',
            'Network policy block evaluation id must not be empty.'),
        assert(providerScope != '',
            'Network policy block provider scope must not be empty.'),
        assert(reason != '', 'Network policy block reason must not be empty.');

  final String id;
  final String evaluationId;
  final String providerScope;
  final Uri requestUri;
  final NetworkPolicyFailureKind failureKind;
  final String reason;
  final DateTime recordedAt;
}

final class StoredNetworkPolicyCapabilityRecord {
  const StoredNetworkPolicyCapabilityRecord({
    required this.providerScope,
    required this.capability,
    required this.state,
    required this.updatedAt,
    this.reason,
  })  : assert(providerScope != '',
            'Network policy capability provider scope must not be empty.'),
        assert(
            capability != '', 'Network policy capability must not be empty.');

  final String providerScope;
  final String capability;
  final StoredNetworkPolicyCapabilityState state;
  final String? reason;
  final DateTime updatedAt;
}

/// Persistence port for network policy profiles and provider assignments.
/// Evaluation is performed by NetworkPolicyRuntime so storage never becomes a
/// second, divergent network-policy engine.
abstract interface class NetworkPolicyStore {
  Future<StoredNetworkPolicyProfileRecord> storeProfile(
      StoredNetworkPolicyProfileRecord profile);

  Future<StoredNetworkPolicyProfileRecord?> profileById(String id);

  Future<List<StoredNetworkPolicyProfileRecord>> profilesForProvider(
      String providerScope);

  Future<void> storeRules(
      {required String policyId,
      required Iterable<StoredNetworkPolicyRuleRecord> rules});

  Future<List<StoredNetworkPolicyRuleRecord>> rulesForPolicy(String policyId);

  Future<void> assignProvider(
      StoredNetworkPolicyProviderAssignmentRecord assignment);

  Future<StoredNetworkPolicyProviderAssignmentRecord?> assignmentForProvider(
      String providerScope);

  Future<void> recordEvaluation(
      StoredNetworkPolicyEvaluationSnapshotRecord evaluation);

  Future<List<StoredNetworkPolicyEvaluationSnapshotRecord>>
      evaluationsForProvider(String providerScope);

  Future<void> recordBlockOutcome(
      StoredNetworkPolicyBlockOutcomeRecord outcome);

  Future<List<StoredNetworkPolicyBlockOutcomeRecord>> blockOutcomesForProvider(
      String providerScope);

  Future<void> storeCapability(StoredNetworkPolicyCapabilityRecord capability);

  Future<StoredNetworkPolicyCapabilityRecord?> capabilityForProvider(
      {required String providerScope, required String capability});
}

final class DeterministicNetworkPolicyStore implements NetworkPolicyStore {
  final Map<String, StoredNetworkPolicyProfileRecord> _profilesById =
      <String, StoredNetworkPolicyProfileRecord>{};
  final Map<String, StoredNetworkPolicyRuleRecord> _rulesById =
      <String, StoredNetworkPolicyRuleRecord>{};
  final Map<String, StoredNetworkPolicyProviderAssignmentRecord>
      _assignmentsByProvider =
      <String, StoredNetworkPolicyProviderAssignmentRecord>{};
  final Map<String, StoredNetworkPolicyEvaluationSnapshotRecord>
      _evaluationsById =
      <String, StoredNetworkPolicyEvaluationSnapshotRecord>{};
  final Map<String, StoredNetworkPolicyBlockOutcomeRecord> _blocksById =
      <String, StoredNetworkPolicyBlockOutcomeRecord>{};
  final Map<String, StoredNetworkPolicyCapabilityRecord> _capabilities =
      <String, StoredNetworkPolicyCapabilityRecord>{};

  @override
  Future<void> assignProvider(
      StoredNetworkPolicyProviderAssignmentRecord assignment) {
    _assignmentsByProvider[assignment.providerScope] = assignment;
    return Future<void>.value();
  }

  @override
  Future<StoredNetworkPolicyProviderAssignmentRecord?> assignmentForProvider(
      String providerScope) {
    return Future<StoredNetworkPolicyProviderAssignmentRecord?>.value(
        _assignmentsByProvider[providerScope]);
  }

  @override
  Future<List<StoredNetworkPolicyBlockOutcomeRecord>> blockOutcomesForProvider(
      String providerScope) {
    return Future<List<StoredNetworkPolicyBlockOutcomeRecord>>.value(
      <StoredNetworkPolicyBlockOutcomeRecord>[
        for (final StoredNetworkPolicyBlockOutcomeRecord outcome
            in _blocksById.values)
          if (outcome.providerScope == providerScope) outcome,
      ],
    );
  }

  @override
  Future<StoredNetworkPolicyCapabilityRecord?> capabilityForProvider(
      {required String providerScope, required String capability}) {
    return Future<StoredNetworkPolicyCapabilityRecord?>.value(
        _capabilities[_key(providerScope, capability)]);
  }

  @override
  Future<List<StoredNetworkPolicyEvaluationSnapshotRecord>>
      evaluationsForProvider(String providerScope) {
    return Future<List<StoredNetworkPolicyEvaluationSnapshotRecord>>.value(
      <StoredNetworkPolicyEvaluationSnapshotRecord>[
        for (final StoredNetworkPolicyEvaluationSnapshotRecord evaluation
            in _evaluationsById.values)
          if (evaluation.providerScope == providerScope) evaluation,
      ],
    );
  }

  @override
  Future<StoredNetworkPolicyProfileRecord?> profileById(String id) {
    return Future<StoredNetworkPolicyProfileRecord?>.value(_profilesById[id]);
  }

  @override
  Future<List<StoredNetworkPolicyProfileRecord>> profilesForProvider(
      String providerScope) {
    return Future<List<StoredNetworkPolicyProfileRecord>>.value(
      <StoredNetworkPolicyProfileRecord>[
        for (final StoredNetworkPolicyProfileRecord profile
            in _profilesById.values)
          if (profile.providerScope == providerScope) profile,
      ],
    );
  }

  @override
  Future<void> recordBlockOutcome(
      StoredNetworkPolicyBlockOutcomeRecord outcome) {
    _blocksById[outcome.id] = outcome;
    return Future<void>.value();
  }

  @override
  Future<void> recordEvaluation(
      StoredNetworkPolicyEvaluationSnapshotRecord evaluation) {
    _evaluationsById[evaluation.id] = evaluation;
    return Future<void>.value();
  }

  @override
  Future<List<StoredNetworkPolicyRuleRecord>> rulesForPolicy(String policyId) {
    return Future<List<StoredNetworkPolicyRuleRecord>>.value(
      <StoredNetworkPolicyRuleRecord>[
        for (final StoredNetworkPolicyRuleRecord rule in _rulesById.values)
          if (rule.policyId == policyId) rule,
      ]..sort((StoredNetworkPolicyRuleRecord left,
              StoredNetworkPolicyRuleRecord right) =>
          left.order.compareTo(right.order)),
    );
  }

  @override
  Future<void> storeCapability(StoredNetworkPolicyCapabilityRecord capability) {
    _capabilities[_key(capability.providerScope, capability.capability)] =
        capability;
    return Future<void>.value();
  }

  @override
  Future<StoredNetworkPolicyProfileRecord> storeProfile(
      StoredNetworkPolicyProfileRecord profile) {
    _profilesById[profile.id] = profile;
    return Future<StoredNetworkPolicyProfileRecord>.value(profile);
  }

  @override
  Future<void> storeRules(
      {required String policyId,
      required Iterable<StoredNetworkPolicyRuleRecord> rules}) {
    _rulesById.removeWhere((String key, StoredNetworkPolicyRuleRecord rule) =>
        rule.policyId == policyId);
    for (final StoredNetworkPolicyRuleRecord rule in rules) {
      _rulesById[rule.id] = rule;
    }
    return Future<void>.value();
  }

  static String _key(String providerScope, String capability) =>
      '$providerScope::$capability';
}
