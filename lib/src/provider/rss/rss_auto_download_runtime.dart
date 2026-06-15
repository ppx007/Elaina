import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/rss_auto_download_policy_storage_contracts.dart';
import 'feed_contracts.dart';
import 'rss_auto_download_policy.dart';

final class RssAutoDownloadPolicyRuntimeBootstrap {
  RssAutoDownloadPolicyRuntimeBootstrap({
    required this.policyStore,
    required Map<String, DeterministicRssAutoDownloadPolicyEvaluator>
        evaluatorByScope,
    required Map<String, RssAutomationCapabilityMatrix> capabilitiesByScope,
    this.historyStore,
    this.cacheInvalidationBus,
    this.clock,
  })  : evaluatorByScope = Map<String,
            DeterministicRssAutoDownloadPolicyEvaluator>.unmodifiable(
            evaluatorByScope),
        capabilitiesByScope =
            Map<String, RssAutomationCapabilityMatrix>.unmodifiable(
                capabilitiesByScope);

  final RssAutoDownloadPolicyStore policyStore;
  final Map<String, DeterministicRssAutoDownloadPolicyEvaluator>
      evaluatorByScope;
  final Map<String, RssAutomationCapabilityMatrix> capabilitiesByScope;
  final RssAutomationHistoryStore? historyStore;
  final CacheInvalidationBus? cacheInvalidationBus;
  final DateTime Function()? clock;

  RssAutoDownloadPolicyRuntime createRuntime() {
    return RssAutoDownloadPolicyRuntime(
      policyStore: policyStore,
      evaluatorByScope: evaluatorByScope,
      capabilitiesByScope: capabilitiesByScope,
      historyStore: historyStore,
      cacheInvalidationBus: cacheInvalidationBus,
      clock: clock,
    );
  }
}

enum RssAutoDownloadPolicyRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  policyNotFound,
  policyDisabled,
  automationDisabled,
  invalidMatcher,
  unsupportedSource,
  historyUnavailable,
  enqueueUnavailable,
  deduplicated,
}

final class RssAutoDownloadPolicyRuntimeFailure implements Exception {
  const RssAutoDownloadPolicyRuntimeFailure({
    required this.kind,
    required this.message,
  });

  final RssAutoDownloadPolicyRuntimeFailureKind kind;
  final String message;
}

enum RssAutoDownloadPolicyRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class RssAutoDownloadPolicyRuntimeActionResult<T> {
  const RssAutoDownloadPolicyRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const RssAutoDownloadPolicyRuntimeActionResult.success(T value)
      : this._(
          kind: RssAutoDownloadPolicyRuntimeActionResultKind.success,
          value: value,
        );

  const RssAutoDownloadPolicyRuntimeActionResult.failed(
    RssAutoDownloadPolicyRuntimeFailure failure,
  ) : this._(
          kind: RssAutoDownloadPolicyRuntimeActionResultKind.failed,
          failure: failure,
        );

  const RssAutoDownloadPolicyRuntimeActionResult.unavailable(
    RssAutoDownloadPolicyRuntimeFailure failure,
  ) : this._(
          kind: RssAutoDownloadPolicyRuntimeActionResultKind.unavailable,
          failure: failure,
        );

  const RssAutoDownloadPolicyRuntimeActionResult.disposed(
    RssAutoDownloadPolicyRuntimeFailure failure,
  ) : this._(
          kind: RssAutoDownloadPolicyRuntimeActionResultKind.disposed,
          failure: failure,
        );

  final RssAutoDownloadPolicyRuntimeActionResultKind kind;
  final T? value;
  final RssAutoDownloadPolicyRuntimeFailure? failure;

  bool get isSuccess =>
      kind == RssAutoDownloadPolicyRuntimeActionResultKind.success;
}

final class RssAutoDownloadPolicyRuntimeRestartProjection {
  const RssAutoDownloadPolicyRuntimeRestartProjection({
    required this.scopeId,
    this.activePolicyId,
    this.latestEvaluationKind,
    this.latestCandidateDedupeKey,
    this.latestEnqueueState,
  });

  final String scopeId;
  final String? activePolicyId;
  final StoredRssAutoDownloadEvaluationKind? latestEvaluationKind;
  final String? latestCandidateDedupeKey;
  final StoredRssAutoDownloadEnqueueState? latestEnqueueState;
}

final class RssAutoDownloadPolicyRuntimeProjection {
  const RssAutoDownloadPolicyRuntimeProjection._({
    required this.scopeId,
    this.activePolicyId,
    this.activePolicyLabel,
    this.activePolicyEnabled,
    this.latestEvaluationOutcome,
    this.latestHandoffOutcome,
    this.latestFailure,
    required this.restart,
  });

  final String scopeId;
  final RssAutoDownloadPolicyId? activePolicyId;
  final String? activePolicyLabel;
  final bool? activePolicyEnabled;
  final RssAutomationEvaluationOutcome? latestEvaluationOutcome;
  final RssAutomationHandoffOutcome? latestHandoffOutcome;
  final RssAutoDownloadPolicyRuntimeFailure? latestFailure;
  final RssAutoDownloadPolicyRuntimeRestartProjection restart;
}

final class RssAutoDownloadPolicyRuntime {
  RssAutoDownloadPolicyRuntime({
    required RssAutoDownloadPolicyStore policyStore,
    required Map<String, DeterministicRssAutoDownloadPolicyEvaluator>
        evaluatorByScope,
    required Map<String, RssAutomationCapabilityMatrix> capabilitiesByScope,
    RssAutomationHistoryStore? historyStore,
    CacheInvalidationBus? cacheInvalidationBus,
    DateTime Function()? clock,
  })  : _policyStore = policyStore,
        _evaluatorByScope = evaluatorByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _historyStore = historyStore,
        _cacheInvalidationBus = cacheInvalidationBus,
        _clock = clock,
        _unavailableReason = null;

  RssAutoDownloadPolicyRuntime.unavailable({required String reason})
      : _policyStore = DeterministicRssAutoDownloadPolicyStore(),
        _evaluatorByScope =
            const <String, DeterministicRssAutoDownloadPolicyEvaluator>{},
        _capabilitiesByScope =
            const <String, RssAutomationCapabilityMatrix>{},
        _historyStore = null,
        _cacheInvalidationBus = null,
        _clock = null,
        _unavailableReason = reason;

  final RssAutoDownloadPolicyStore _policyStore;
  final Map<String, DeterministicRssAutoDownloadPolicyEvaluator>
      _evaluatorByScope;
  final Map<String, RssAutomationCapabilityMatrix> _capabilitiesByScope;
  final RssAutomationHistoryStore? _historyStore;
  final CacheInvalidationBus? _cacheInvalidationBus;
  final DateTime Function()? _clock;
  final String? _unavailableReason;

  bool _disposed = false;
  RssAutomationEvaluationOutcome? _latestEvaluationOutcome;
  RssAutomationHandoffOutcome? _latestHandoffOutcome;
  RssAutoDownloadPolicyRuntimeFailure? _latestFailure;

  Future<RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>>
      snapshot(String scopeId) async {
    final RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
        gated =
        _gate(scopeId, RssAutomationCapability.policyEvaluation);
    if (gated != null) return gated;
    return RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection>.success(
        await _projection(scopeId));
  }

  Future<RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>>
      evaluate(String scopeId, RssAutoDownloadPolicy policy,
          Iterable<FeedItem> items) async {
    final RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
        gated =
        _gate(scopeId, RssAutomationCapability.policyEvaluation);
    if (gated != null) return gated;

    final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
        _evaluatorByScope[scopeId]!;
    final RssAutomationHistoryStore history =
        _historyStore ?? DeterministicRssAutomationHistoryStore();

    final RssAutomationEvaluationOutcome outcome =
        await evaluator.evaluateTyped(
      policy: policy,
      items: items,
      history: history,
    );

    if (outcome.isSuccess) {
      _latestEvaluationOutcome = outcome;
      _latestFailure = null;

      for (final RssAutomationDecision decision in outcome.decisions) {
        switch (decision) {
          case RssAutomationAccepted():
            await _persistAcceptedCandidate(decision.candidate);
            await _persistDedupeKey(decision.candidate);
            _publishEvent(RssAutoDownloadCandidateAccepted(
              occurredAt: _now(),
              policyId: decision.candidate.policyId.value,
              ruleId: decision.candidate.ruleId.value,
              candidateDedupeKey: decision.candidate.dedupeKey,
              feedItemId: decision.candidate.item.id.value,
              sourceId: decision.candidate.item.sourceId.value,
            ));
            _publishEvent(RssAutoDownloadDedupeStateChanged(
              occurredAt: _now(),
              policyId: decision.candidate.policyId.value,
              candidateDedupeKey: decision.candidate.dedupeKey,
              candidateId: decision.candidate.item.id.value,
            ));
          case RssAutomationRejected():
            await _persistRejectedCandidate(decision);
            _publishEvent(RssAutoDownloadCandidateRejected(
              occurredAt: _now(),
              policyId: policy.id.value,
              feedItemId: decision.item.id.value,
              sourceId: decision.item.sourceId.value,
              reason: decision.reason,
              ruleId: decision.ruleId?.value,
            ));
          case RssAutomationDeduplicated():
            _publishEvent(RssAutoDownloadDedupeStateChanged(
              occurredAt: _now(),
              policyId: decision.policyId.value,
              candidateDedupeKey: decision.dedupeKey,
              candidateId: decision.item.id.value,
            ));
          case RssAutomationDisabled():
            break;
        }

        _publishEvent(RssAutoDownloadFeedItemEvaluated(
          occurredAt: _now(),
          policyId: policy.id.value,
          feedItemId: decision.item.id.value,
          sourceId: decision.item.sourceId.value,
          outcomeKind: _decisionOutcomeKind(decision),
          ruleId: decision is RssAutomationAccepted
              ? decision.candidate.ruleId.value
              : (decision is RssAutomationRejected ? decision.ruleId?.value : null),
        ));
      }
    } else {
      _latestFailure = RssAutoDownloadPolicyRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      _latestEvaluationOutcome = outcome;
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.failed(_latestFailure!);
    }

    return RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection>.success(
        await _projection(scopeId));
  }

  Future<RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>>
      handoff(String scopeId, RssDownloadCandidate candidate) async {
    final RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
        gated =
        _gate(scopeId, RssAutomationCapability.btTaskHandoff);
    if (gated != null) return gated;

    final RssAutomationHandoffOutcome outcome =
        rssAutomationHandoffFromCandidate(candidate);

    if (outcome.isSuccess) {
      _latestHandoffOutcome = outcome;
      _latestFailure = null;

      await _persistAcceptedCandidate(candidate);
      await _persistDedupeKey(candidate);
      await _persistEnqueueOutcome(candidate, StoredRssAutoDownloadEnqueueState.pending);

      _publishEvent(RssAutoDownloadCandidateAccepted(
        occurredAt: _now(),
        policyId: candidate.policyId.value,
        ruleId: candidate.ruleId.value,
        candidateDedupeKey: candidate.dedupeKey,
        feedItemId: candidate.item.id.value,
        sourceId: candidate.item.sourceId.value,
      ));
      _publishEvent(RssAutoDownloadDedupeStateChanged(
        occurredAt: _now(),
        policyId: candidate.policyId.value,
        candidateDedupeKey: candidate.dedupeKey,
        candidateId: candidate.item.id.value,
      ));
      _publishEvent(RssAutoDownloadEnqueueOutcomeRecorded(
        occurredAt: _now(),
        policyId: candidate.policyId.value,
        candidateId: candidate.item.id.value,
        state: 'pending',
      ));
    } else {
      _latestFailure = RssAutoDownloadPolicyRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
      );
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.failed(_latestFailure!);
    }

    return RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection>.success(
        await _projection(scopeId));
  }

  Future<RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>>
      disable(String scopeId, RssAutoDownloadPolicyId policyId) async {
    final RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
        gated =
        _gate(scopeId, RssAutomationCapability.policyEvaluation);
    if (gated != null) return gated;

    final StoredRssAutoDownloadPolicyRecord? storedPolicy =
        await _policyStore.policyById(policyId.value);
    if (storedPolicy == null) {
      _latestFailure = const RssAutoDownloadPolicyRuntimeFailure(
        kind: RssAutoDownloadPolicyRuntimeFailureKind.policyNotFound,
        message: 'RSS auto-download policy not found.',
      );
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.failed(_latestFailure!);
    }

    await _policyStore.storePolicy(StoredRssAutoDownloadPolicyRecord(
      id: storedPolicy.id,
      label: storedPolicy.label,
      enabled: false,
      createdAt: storedPolicy.createdAt,
      updatedAt: _now(),
      metadata: storedPolicy.metadata,
    ));

    _publishEvent(RssAutoDownloadPolicyChanged(
      occurredAt: _now(),
      policyId: policyId.value,
      changeKind: RssAutoDownloadPolicyChangeKind.disabled,
    ));

    return RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection>.success(
        await _projection(scopeId));
  }

  Future<RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>>
      reenable(String scopeId, RssAutoDownloadPolicyId policyId) async {
    final RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
        gated =
        _gate(scopeId, RssAutomationCapability.policyEvaluation);
    if (gated != null) return gated;

    final StoredRssAutoDownloadPolicyRecord? storedPolicy =
        await _policyStore.policyById(policyId.value);
    if (storedPolicy == null) {
      _latestFailure = const RssAutoDownloadPolicyRuntimeFailure(
        kind: RssAutoDownloadPolicyRuntimeFailureKind.policyNotFound,
        message: 'RSS auto-download policy not found.',
      );
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.failed(_latestFailure!);
    }

    await _policyStore.storePolicy(StoredRssAutoDownloadPolicyRecord(
      id: storedPolicy.id,
      label: storedPolicy.label,
      enabled: true,
      createdAt: storedPolicy.createdAt,
      updatedAt: _now(),
      metadata: storedPolicy.metadata,
    ));

    _publishEvent(RssAutoDownloadPolicyChanged(
      occurredAt: _now(),
      policyId: policyId.value,
      changeKind: RssAutoDownloadPolicyChangeKind.updated,
    ));

    return RssAutoDownloadPolicyRuntimeActionResult<
            RssAutoDownloadPolicyRuntimeProjection>.success(
        await _projection(scopeId));
  }

  Future<void> dispose() async {
    _disposed = true;
  }

  RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>?
      _gate(String scopeId, RssAutomationCapability requiredCapability) {
    if (_disposed) {
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.disposed(
        const RssAutoDownloadPolicyRuntimeFailure(
          kind: RssAutoDownloadPolicyRuntimeFailureKind.disposed,
          message: 'RSS auto-download policy runtime is disposed.',
        ),
      );
    }
    if (_unavailableReason != null) {
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.unavailable(
        RssAutoDownloadPolicyRuntimeFailure(
          kind: RssAutoDownloadPolicyRuntimeFailureKind.unavailable,
          message: _unavailableReason,
        ),
      );
    }
    if (!_evaluatorByScope.containsKey(scopeId) ||
        !_capabilitiesByScope.containsKey(scopeId)) {
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.unavailable(
        RssAutoDownloadPolicyRuntimeFailure(
          kind: RssAutoDownloadPolicyRuntimeFailureKind.unavailable,
          message:
              'RSS auto-download policy runtime is unavailable for $scopeId.',
        ),
      );
    }
    if (!_capabilitiesByScope[scopeId]!
        .statusOf(requiredCapability).supported) {
      return RssAutoDownloadPolicyRuntimeActionResult<
              RssAutoDownloadPolicyRuntimeProjection>.failed(
        RssAutoDownloadPolicyRuntimeFailure(
          kind: RssAutoDownloadPolicyRuntimeFailureKind.capabilityUnsupported,
          message:
              '${requiredCapability.name} capability is unsupported for scope $scopeId.',
        ),
      );
    }
    return null;
  }

  Future<RssAutoDownloadPolicyRuntimeProjection> _projection(
      String scopeId) async {
    final List<StoredRssAutoDownloadPolicyRecord> policies =
        await _policyStore.listPolicies();
    final StoredRssAutoDownloadPolicyRecord? activePolicy =
        policies.isNotEmpty ? policies.first : null;

    StoredRssAutoDownloadEvaluationKind? latestEvaluationKind;
    String? latestCandidateDedupeKey;
    StoredRssAutoDownloadEnqueueState? latestEnqueueState;

    if (activePolicy != null) {
      final List<StoredRssAutoDownloadEvaluationRecord> evals =
          await _policyStore.evaluationsForItem(
        policyId: activePolicy.id,
        itemDedupeKey: '',
      );
      if (evals.isNotEmpty) {
        latestEvaluationKind = evals.last.evaluationKind;
      }

      final List<StoredRssAutoDownloadAcceptedCandidateRecord> candidates =
          await _policyStore.acceptedCandidatesForPolicy(activePolicy.id);
      if (candidates.isNotEmpty) {
        latestCandidateDedupeKey = candidates.last.candidateDedupeKey;
        final StoredRssAutoDownloadEnqueueOutcomeRecord? enqueue =
            await _policyStore.latestEnqueueOutcome(candidates.last.id);
        if (enqueue != null) {
          latestEnqueueState = enqueue.state;
        }
      }
    }

    final RssAutoDownloadPolicyRuntimeRestartProjection restart =
        RssAutoDownloadPolicyRuntimeRestartProjection(
      scopeId: scopeId,
      activePolicyId: activePolicy?.id,
      latestEvaluationKind: latestEvaluationKind,
      latestCandidateDedupeKey: latestCandidateDedupeKey,
      latestEnqueueState: latestEnqueueState,
    );

    return RssAutoDownloadPolicyRuntimeProjection._(
      scopeId: scopeId,
      activePolicyId: activePolicy != null
          ? RssAutoDownloadPolicyId(activePolicy.id)
          : null,
      activePolicyLabel: activePolicy?.label,
      activePolicyEnabled: activePolicy?.enabled,
      latestEvaluationOutcome: _latestEvaluationOutcome,
      latestHandoffOutcome: _latestHandoffOutcome,
      latestFailure: _latestFailure,
      restart: restart,
    );
  }

  Future<void> _persistAcceptedCandidate(
      RssDownloadCandidate candidate) async {
    await _policyStore.storeAcceptedCandidate(
      StoredRssAutoDownloadAcceptedCandidateRecord(
        id: candidate.item.id.value,
        policyId: candidate.policyId.value,
        ruleId: candidate.ruleId.value,
        itemId: candidate.item.id.value,
        sourceId: candidate.item.sourceId.value,
        itemDedupeKey: candidate.item.dedupeKey.value,
        candidateDedupeKey: candidate.dedupeKey,
        sourceKind: candidate.source is MagnetRssDownloadSource
            ? StoredRssAutoDownloadSourceKind.magnet
            : StoredRssAutoDownloadSourceKind.torrentUri,
        sourceUri: candidate.source is MagnetRssDownloadSource
            ? (candidate.source as MagnetRssDownloadSource).uri
            : (candidate.source as TorrentRssDownloadSource).uri.toString(),
        acceptedAt: _now(),
      ),
    );
  }

  Future<void> _persistRejectedCandidate(
      RssAutomationRejected rejection) async {
    await _policyStore.storeRejectedCandidate(
      StoredRssAutoDownloadRejectedCandidateRecord(
        id: rejection.item.id.value,
        policyId: _latestEvaluationOutcome?.decisions.first.policyId?.value ?? '',
        itemId: rejection.item.id.value,
        sourceId: rejection.item.sourceId.value,
        itemDedupeKey: rejection.item.dedupeKey.value,
        rejectionKind: _mapRejectionKind(rejection.kind),
        reason: rejection.reason,
        rejectedAt: _now(),
        ruleId: rejection.ruleId?.value,
      ),
    );
  }

  Future<void> _persistDedupeKey(RssDownloadCandidate candidate) async {
    await _policyStore.recordDedupeKey(
      StoredRssAutoDownloadDedupeRecord(
        policyId: candidate.policyId.value,
        candidateDedupeKey: candidate.dedupeKey,
        itemDedupeKey: candidate.item.dedupeKey.value,
        candidateId: candidate.item.id.value,
        recordedAt: _now(),
      ),
    );
  }

  Future<void> _persistEnqueueOutcome(
      RssDownloadCandidate candidate,
      StoredRssAutoDownloadEnqueueState state) async {
    await _policyStore.recordEnqueueOutcome(
      StoredRssAutoDownloadEnqueueOutcomeRecord(
        id: 'enqueue-${candidate.item.id.value}',
        candidateId: candidate.item.id.value,
        policyId: candidate.policyId.value,
        state: state,
        message: 'Enqueue ${state.name}.',
        recordedAt: _now(),
      ),
    );
  }

  void _publishEvent(CacheInvalidationEvent event) {
    _cacheInvalidationBus?.publish(event);
  }

  DateTime _now() => (_clock ?? DateTime.now().toUtc)();

  RssAutoDownloadPolicyRuntimeFailureKind _mapFailureKind(
      RssAutomationFailureKind kind) {
    return switch (kind) {
      RssAutomationFailureKind.policyNotFound =>
        RssAutoDownloadPolicyRuntimeFailureKind.policyNotFound,
      RssAutomationFailureKind.policyDisabled =>
        RssAutoDownloadPolicyRuntimeFailureKind.policyDisabled,
      RssAutomationFailureKind.invalidMatcher =>
        RssAutoDownloadPolicyRuntimeFailureKind.invalidMatcher,
      RssAutomationFailureKind.unsupportedSource =>
        RssAutoDownloadPolicyRuntimeFailureKind.unsupportedSource,
      RssAutomationFailureKind.historyUnavailable =>
        RssAutoDownloadPolicyRuntimeFailureKind.historyUnavailable,
      RssAutomationFailureKind.enqueueUnavailable =>
        RssAutoDownloadPolicyRuntimeFailureKind.enqueueUnavailable,
    };
  }

  StoredRssAutoDownloadRejectionKind _mapRejectionKind(
      RssAutomationRejectionKind kind) {
    return switch (kind) {
      RssAutomationRejectionKind.automationDisabled =>
        StoredRssAutoDownloadRejectionKind.automationDisabled,
      RssAutomationRejectionKind.policyDisabled =>
        StoredRssAutoDownloadRejectionKind.policyDisabled,
      RssAutomationRejectionKind.ruleDisabled =>
        StoredRssAutoDownloadRejectionKind.ruleDisabled,
      RssAutomationRejectionKind.sourceOutOfScope =>
        StoredRssAutoDownloadRejectionKind.sourceOutOfScope,
      RssAutomationRejectionKind.includeNotMatched =>
        StoredRssAutoDownloadRejectionKind.includeNotMatched,
      RssAutomationRejectionKind.excluded =>
        StoredRssAutoDownloadRejectionKind.excluded,
      RssAutomationRejectionKind.duplicate =>
        StoredRssAutoDownloadRejectionKind.duplicate,
      RssAutomationRejectionKind.unsupportedSource =>
        StoredRssAutoDownloadRejectionKind.unsupportedSource,
    };
  }

  String _decisionOutcomeKind(RssAutomationDecision decision) {
    return switch (decision) {
      RssAutomationAccepted() => 'accepted',
      RssAutomationDeduplicated() => 'deduplicated',
      RssAutomationDisabled() => 'disabled',
      RssAutomationRejected() => 'rejected',
    };
  }
}

extension on RssAutomationDecision {
  RssAutoDownloadPolicyId? get policyId {
    return switch (this) {
      RssAutomationAccepted(:final candidate) => candidate.policyId,
      RssAutomationDeduplicated(:final policyId) => policyId,
      RssAutomationDisabled(:final policyId) => policyId,
      RssAutomationRejected() => null,
    };
  }
}
