import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/network_policy_storage_contracts.dart';
import 'network_policy.dart';

enum NetworkPolicyRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  policyNotFound,
  policyDisabled,
  evaluationFailed,
  invalidAssignment,
}

final class NetworkPolicyRuntimeFailure {
  const NetworkPolicyRuntimeFailure({
    required this.kind,
    required this.message,
    this.providerScope,
  }) : assert(message != '', 'Failure message must not be empty.');

  final NetworkPolicyRuntimeFailureKind kind;
  final String message;
  final String? providerScope;
}

enum NetworkPolicyRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class NetworkPolicyRuntimeActionResult<T> {
  const NetworkPolicyRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const NetworkPolicyRuntimeActionResult.success([T? value])
      : this._(kind: NetworkPolicyRuntimeActionResultKind.success, value: value);

  NetworkPolicyRuntimeActionResult.failed(NetworkPolicyRuntimeFailure failure)
      : this._(kind: NetworkPolicyRuntimeActionResultKind.failed, failure: failure);

  NetworkPolicyRuntimeActionResult.unavailable(String message)
      : this._(
          kind: NetworkPolicyRuntimeActionResultKind.unavailable,
          failure: NetworkPolicyRuntimeFailure(
            kind: NetworkPolicyRuntimeFailureKind.unavailable,
            message: message,
          ),
        );

  NetworkPolicyRuntimeActionResult.disposed()
      : this._(
          kind: NetworkPolicyRuntimeActionResultKind.disposed,
          failure: const NetworkPolicyRuntimeFailure(
            kind: NetworkPolicyRuntimeFailureKind.disposed,
            message: 'Network policy runtime has been disposed.',
          ),
        );

  final NetworkPolicyRuntimeActionResultKind kind;
  final T? value;
  final NetworkPolicyRuntimeFailure? failure;

  bool get isSuccess =>
      kind == NetworkPolicyRuntimeActionResultKind.success;
}

final class NetworkPolicyRuntimeRestartProjection {
  const NetworkPolicyRuntimeRestartProjection({
    required this.providerScope,
    this.latestAssignment,
    this.latestAssignmentPolicyId,
    this.latestEvaluation,
    this.latestEvaluationDecisionKind,
    this.latestBlock,
    this.latestBlockReason,
    this.latestCapability,
  });

  final String providerScope;
  final StoredNetworkPolicyProviderAssignmentRecord? latestAssignment;
  final String? latestAssignmentPolicyId;
  final StoredNetworkPolicyEvaluationSnapshotRecord? latestEvaluation;
  final String? latestEvaluationDecisionKind;
  final StoredNetworkPolicyBlockOutcomeRecord? latestBlock;
  final String? latestBlockReason;
  final StoredNetworkPolicyCapabilityRecord? latestCapability;
}

final class NetworkPolicyRuntimeProjection {
  const NetworkPolicyRuntimeProjection({
    required this.providerScope,
    required this.restart,
  });

  final String providerScope;
  final NetworkPolicyRuntimeRestartProjection restart;
}

final class NetworkPolicyRuntimeBootstrap {
  NetworkPolicyRuntimeBootstrap({
    required this.store,
    required Map<String, NetworkPolicy> policiesByScope,
    required Map<String, NetworkPolicyEvaluator> evaluatorsByScope,
    required Map<String, NetworkPolicyCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
  })  : _policiesByScope =
            Map<String, NetworkPolicy>.unmodifiable(policiesByScope),
        _evaluatorsByScope =
            Map<String, NetworkPolicyEvaluator>.unmodifiable(evaluatorsByScope),
        _capabilitiesByScope =
            Map<String, NetworkPolicyCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _bus = bus;

  final NetworkPolicyStore store;
  final Map<String, NetworkPolicy> _policiesByScope;
  final Map<String, NetworkPolicyEvaluator> _evaluatorsByScope;
  final Map<String, NetworkPolicyCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;

  NetworkPolicyRuntime createRuntime() {
    return NetworkPolicyRuntime._(
      store: store,
      policiesByScope: _policiesByScope,
      evaluatorsByScope: _evaluatorsByScope,
      capabilitiesByScope: _capabilitiesByScope,
      bus: _bus,
    );
  }
}

final class NetworkPolicyRuntime {
  NetworkPolicyRuntime._({
    required NetworkPolicyStore store,
    required Map<String, NetworkPolicy> policiesByScope,
    required Map<String, NetworkPolicyEvaluator> evaluatorsByScope,
    required Map<String, NetworkPolicyCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
  })  : _store = store,
        _policiesByScope = policiesByScope,
        _evaluatorsByScope = evaluatorsByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _bus = bus,
        _unavailableReason = null;

  NetworkPolicyRuntime.unavailable({required String reason})
      : _store = null,
        _policiesByScope = const <String, NetworkPolicy>{},
        _evaluatorsByScope = const <String, NetworkPolicyEvaluator>{},
        _capabilitiesByScope = const <String, NetworkPolicyCapabilityMatrix>{},
        _bus = null,
        _unavailableReason = reason;

  final NetworkPolicyStore? _store;
  final Map<String, NetworkPolicy> _policiesByScope;
  final Map<String, NetworkPolicyEvaluator> _evaluatorsByScope;
  final Map<String, NetworkPolicyCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;
  final String? _unavailableReason;
  bool _disposed = false;
  final Set<String> _disabledScopes = <String>{};

  NetworkPolicyStore _requireStore() {
    final NetworkPolicyStore? store = _store;
    if (store == null) throw StateError('Store required but unavailable.');
    return store;
  }

  DateTime _now() => DateTime.now().toUtc();

  NetworkPolicyRuntimeActionResult<void>? _gate(String providerScope) {
    if (_disposed) {
      return NetworkPolicyRuntimeActionResult<void>.disposed();
    }
    final String? unavailableReason = _unavailableReason;
    if (unavailableReason != null) {
      return NetworkPolicyRuntimeActionResult<void>.unavailable(
          unavailableReason);
    }
    final NetworkPolicyCapabilityMatrix? capabilities =
        _capabilitiesByScope[providerScope];
    if (capabilities == null) {
      return NetworkPolicyRuntimeActionResult<void>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.policyNotFound,
          message: 'No capabilities declared for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }
    final NetworkPolicyCapabilityStatus ssrfStatus =
        capabilities.statusOf(NetworkPolicyCapability.ssrfGuard);
    if (!ssrfStatus.supported) {
      return NetworkPolicyRuntimeActionResult<void>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.capabilityUnsupported,
          message: ssrfStatus.reason ??
              'Capability ssrfGuard is not supported for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }
    return null;
  }

  NetworkPolicyRuntimeActionResult<T> _castFail<T>(
      NetworkPolicyRuntimeActionResult<void> fail) {
    return NetworkPolicyRuntimeActionResult<T>._(
      kind: fail.kind,
      failure: fail.failure,
    );
  }

  void _publishEvent(CacheInvalidationEvent event) {
    _bus?.publish(event);
  }

  Future<NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>>
      snapshot(String providerScope) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);
    return _projection(providerScope);
  }

  Future<NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>> evaluate({
    required String providerScope,
    required NetworkPolicyRequest request,
  }) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    if (_disabledScopes.contains(providerScope)) {
      return NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.policyDisabled,
          message: 'Network policy is disabled for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }

    final StoredNetworkPolicyProviderAssignmentRecord? assignment =
        await _requireStore().assignmentForProvider(providerScope);
    if (assignment == null) {
      return NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.policyNotFound,
          message:
              'No policy assignment found for provider scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }

    final NetworkPolicy? policy = _policiesByScope[providerScope];
    if (policy == null) {
      return NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.policyNotFound,
          message: 'No policy declared for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }

    final NetworkPolicyEvaluator evaluator =
        _evaluatorsByScope[providerScope]!;

    final NetworkPolicyDecision decision;
    try {
      decision = await evaluator.evaluate(policy: policy, request: request);
    } catch (e) {
      return NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.evaluationFailed,
          message: 'Policy evaluation failed: $e',
          providerScope: providerScope,
        ),
      );
    }

    final DateTime now = _now();
    final String evalId =
        'eval-${providerScope}-${now.millisecondsSinceEpoch}';

    final StoredNetworkPolicyDecisionKind decisionKind =
        decision is NetworkPolicyAllowed
            ? StoredNetworkPolicyDecisionKind.allowed
            : StoredNetworkPolicyDecisionKind.blocked;

    final StoredNetworkPolicyAction? storedAction =
        decision is NetworkPolicyAllowed ? _storeAction(decision.action) : null;

    final NetworkPolicyFailureKind? failureKind =
        decision is NetworkPolicyBlocked ? decision.kind : null;

    await _requireStore().recordEvaluation(
      StoredNetworkPolicyEvaluationSnapshotRecord(
        id: evalId,
        providerScope: providerScope,
        requestUri: request.uri,
        decisionKind: decisionKind,
        recordedAt: now,
        policyId: decision.policyId?.value,
        ruleId: decision.ruleId?.value,
        redirectedFrom: request.redirectedFrom,
        cacheKey: request.cacheKey,
        action: storedAction,
        failureKind: failureKind,
        auditLabel: decision.auditLabel,
        reason: decision is NetworkPolicyBlocked ? decision.reason : null,
      ),
    );

    _publishEvent(NetworkPolicyEvaluationOutcomeRecorded(
      occurredAt: now,
      evaluationId: evalId,
      providerScope: providerScope,
      requestUri: request.uri,
      decisionKind: decisionKind.name,
      policyId: decision.policyId?.value,
      ruleId: decision.ruleId?.value,
      failureKind: failureKind?.name,
    ));

    if (decision is NetworkPolicyBlocked) {
      final String blockId =
          'block-${providerScope}-${now.millisecondsSinceEpoch}';
      await _requireStore().recordBlockOutcome(
        StoredNetworkPolicyBlockOutcomeRecord(
          id: blockId,
          evaluationId: evalId,
          providerScope: providerScope,
          requestUri: request.uri,
          failureKind: decision.kind,
          reason: decision.reason,
          recordedAt: now,
        ),
      );

      _publishEvent(NetworkPolicyBlockDecisionRecorded(
        occurredAt: now,
        blockOutcomeId: blockId,
        providerScope: providerScope,
        requestUri: request.uri,
        failureKind: decision.kind.name,
        reason: decision.reason,
        policyId: decision.policyId?.value,
        ruleId: decision.ruleId?.value,
      ));
    }

    return NetworkPolicyRuntimeActionResult<NetworkPolicyDecision>.success(
        decision);
  }

  Future<NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>>
      assignProvider({
    required String providerScope,
    required NetworkPolicyId policyId,
    String? reason,
  }) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    if (policyId.value.isEmpty) {
      return NetworkPolicyRuntimeActionResult<
          NetworkPolicyRuntimeProjection>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.invalidAssignment,
          message: 'Policy id must not be empty.',
          providerScope: providerScope,
        ),
      );
    }

    final StoredNetworkPolicyProfileRecord? profile =
        await _requireStore().profileById(policyId.value);
    if (profile == null) {
      return NetworkPolicyRuntimeActionResult<
          NetworkPolicyRuntimeProjection>.failed(
        NetworkPolicyRuntimeFailure(
          kind: NetworkPolicyRuntimeFailureKind.invalidAssignment,
          message:
              'Policy profile ${policyId.value} not found in store.',
          providerScope: providerScope,
        ),
      );
    }

    final DateTime now = _now();
    final String assignId =
        'assign-${providerScope}-${now.millisecondsSinceEpoch}';

    await _requireStore().assignProvider(
      StoredNetworkPolicyProviderAssignmentRecord(
        id: assignId,
        providerScope: providerScope,
        policyId: policyId.value,
        assignedAt: now,
        reason: reason,
      ),
    );

    _publishEvent(NetworkPolicyProviderAssignmentChanged(
      occurredAt: now,
      assignmentId: assignId,
      providerScope: providerScope,
      policyId: policyId.value,
      reason: reason,
    ));

    return _projection(providerScope);
  }

  Future<NetworkPolicyRuntimeActionResult<void>> disable({
    required String providerScope,
  }) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return gate;

    _disabledScopes.add(providerScope);
    return const NetworkPolicyRuntimeActionResult<void>.success();
  }

  Future<NetworkPolicyRuntimeActionResult<void>> reenable({
    required String providerScope,
  }) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return gate;

    _disabledScopes.remove(providerScope);
    return const NetworkPolicyRuntimeActionResult<void>.success();
  }

  Future<NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>>
      recordCapability({
    required String providerScope,
    required NetworkPolicyCapability capability,
    required bool supported,
  }) async {
    final NetworkPolicyRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    final DateTime now = _now();
    final StoredNetworkPolicyCapabilityState state = supported
        ? StoredNetworkPolicyCapabilityState.supported
        : StoredNetworkPolicyCapabilityState.unsupported;

    await _requireStore().storeCapability(
      StoredNetworkPolicyCapabilityRecord(
        providerScope: providerScope,
        capability: capability.name,
        state: state,
        updatedAt: now,
      ),
    );

    _publishEvent(NetworkPolicyCapabilityChanged(
      occurredAt: now,
      providerScope: providerScope,
      capability: capability.name,
      supported: supported,
    ));

    return _projection(providerScope);
  }

  void dispose() {
    _disposed = true;
  }

  Future<NetworkPolicyRuntimeActionResult<NetworkPolicyRuntimeProjection>>
      _projection(String providerScope) async {
    final StoredNetworkPolicyProviderAssignmentRecord? assignment =
        await _requireStore().assignmentForProvider(providerScope);
    final List<StoredNetworkPolicyEvaluationSnapshotRecord> evaluations =
        await _requireStore().evaluationsForProvider(providerScope);
    final StoredNetworkPolicyEvaluationSnapshotRecord? latestEvaluation =
        evaluations.isNotEmpty ? evaluations.last : null;
    final List<StoredNetworkPolicyBlockOutcomeRecord> blocks =
        await _requireStore().blockOutcomesForProvider(providerScope);
    final StoredNetworkPolicyBlockOutcomeRecord? latestBlock =
        blocks.isNotEmpty ? blocks.last : null;
    final StoredNetworkPolicyCapabilityRecord? capability =
        await _requireStore().capabilityForProvider(
      providerScope: providerScope,
      capability: NetworkPolicyCapability.ssrfGuard.name,
    );

    final NetworkPolicyRuntimeRestartProjection restart =
        NetworkPolicyRuntimeRestartProjection(
      providerScope: providerScope,
      latestAssignment: assignment,
      latestAssignmentPolicyId: assignment?.policyId,
      latestEvaluation: latestEvaluation,
      latestEvaluationDecisionKind: latestEvaluation?.decisionKind.name,
      latestBlock: latestBlock,
      latestBlockReason: latestBlock?.reason,
      latestCapability: capability,
    );

    return NetworkPolicyRuntimeActionResult<
        NetworkPolicyRuntimeProjection>.success(
      NetworkPolicyRuntimeProjection(
        providerScope: providerScope,
        restart: restart,
      ),
    );
  }

  static StoredNetworkPolicyAction _storeAction(NetworkPolicyAction action) {
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
}
