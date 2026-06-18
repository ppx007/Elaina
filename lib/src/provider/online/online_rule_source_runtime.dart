import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../foundation/storage/online_rule_runtime_storage_contracts.dart';
import 'online_rule_runtime.dart';

enum OnlineRuleSourceRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  manifestNotFound,
  manifestDisabled,
  manifestInvalid,
  evaluationFailed,
  sourceUnsupported,
}

final class OnlineRuleSourceRuntimeFailure {
  const OnlineRuleSourceRuntimeFailure({
    required this.kind,
    required this.message,
    this.sourceId,
  }) : assert(message != '',
            'Online rule source runtime failure message must not be empty.');

  final OnlineRuleSourceRuntimeFailureKind kind;
  final String message;
  final String? sourceId;
}

enum OnlineRuleSourceRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class OnlineRuleSourceRuntimeActionResult<T> {
  const OnlineRuleSourceRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const OnlineRuleSourceRuntimeActionResult.success([T? value])
      : this._(
            kind: OnlineRuleSourceRuntimeActionResultKind.success,
            value: value);

  OnlineRuleSourceRuntimeActionResult.failed(
      OnlineRuleSourceRuntimeFailure failure)
      : this._(
            kind: OnlineRuleSourceRuntimeActionResultKind.failed,
            failure: failure);

  OnlineRuleSourceRuntimeActionResult.unavailable(String message)
      : this._(
          kind: OnlineRuleSourceRuntimeActionResultKind.unavailable,
          failure: OnlineRuleSourceRuntimeFailure(
            kind: OnlineRuleSourceRuntimeFailureKind.unavailable,
            message: message,
          ),
        );

  OnlineRuleSourceRuntimeActionResult.disposed()
      : this._(
          kind: OnlineRuleSourceRuntimeActionResultKind.disposed,
          failure: const OnlineRuleSourceRuntimeFailure(
            kind: OnlineRuleSourceRuntimeFailureKind.disposed,
            message: 'Online rule source runtime has been disposed.',
          ),
        );

  final OnlineRuleSourceRuntimeActionResultKind kind;
  final T? value;
  final OnlineRuleSourceRuntimeFailure? failure;

  bool get isSuccess => kind == OnlineRuleSourceRuntimeActionResultKind.success;
}

final class OnlineRuleSourceRuntimeRestartProjection {
  const OnlineRuleSourceRuntimeRestartProjection({
    required this.sourceId,
    required this.manifestValidationState,
    this.latestEvaluationTarget,
    this.latestEvaluationState,
  });

  final String sourceId;
  final StoredOnlineRuleValidationState manifestValidationState;
  final StoredOnlineRuleTarget? latestEvaluationTarget;
  final StoredOnlineRuleEvaluationState? latestEvaluationState;
}

final class OnlineRuleSourceRuntimeProjection {
  const OnlineRuleSourceRuntimeProjection({
    required this.sourceId,
    required this.restart,
    this.manifestDisplayName,
    this.manifestVersion,
    this.validationState,
    this.latestEvaluationTarget,
    this.latestEvaluationState,
    this.latestEvaluationOutcome,
    this.latestNormalizedOutput,
    this.latestFailure,
  });

  final String sourceId;
  final String? manifestDisplayName;
  final String? manifestVersion;
  final StoredOnlineRuleValidationState? validationState;
  final StoredOnlineRuleTarget? latestEvaluationTarget;
  final StoredOnlineRuleEvaluationState? latestEvaluationState;
  final OnlineRuleEvaluationOutcome? latestEvaluationOutcome;
  final OnlineRuleNormalizedOutput? latestNormalizedOutput;
  final OnlineRuleSourceRuntimeFailure? latestFailure;
  final OnlineRuleSourceRuntimeRestartProjection restart;
}

final class OnlineRuleSourceRuntimeBootstrap {
  OnlineRuleSourceRuntimeBootstrap({
    required this.store,
    required Map<String, DeterministicOnlineRuleRuntime> runtimeByScope,
    required Map<String, OnlineRuleCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
  })  : _runtimeByScope =
            Map<String, DeterministicOnlineRuleRuntime>.unmodifiable(
                runtimeByScope),
        _capabilitiesByScope =
            Map<String, OnlineRuleCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _bus = bus;

  final OnlineRuleRuntimeStore store;
  final Map<String, DeterministicOnlineRuleRuntime> _runtimeByScope;
  final Map<String, OnlineRuleCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;

  OnlineRuleSourceRuntime createRuntime() {
    return OnlineRuleSourceRuntime._(
      store: store,
      runtimeByScope: _runtimeByScope,
      capabilitiesByScope: _capabilitiesByScope,
      bus: _bus,
    );
  }
}

final class OnlineRuleSourceRuntime {
  OnlineRuleSourceRuntime._({
    required OnlineRuleRuntimeStore store,
    required Map<String, DeterministicOnlineRuleRuntime> runtimeByScope,
    required Map<String, OnlineRuleCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
  })  : _store = store,
        _runtimeByScope = runtimeByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _bus = bus,
        _unavailableReason = null;

  OnlineRuleSourceRuntime.unavailable({required String reason})
      : _store = null,
        _runtimeByScope = const <String, DeterministicOnlineRuleRuntime>{},
        _capabilitiesByScope = const <String, OnlineRuleCapabilityMatrix>{},
        _bus = null,
        _unavailableReason = reason;

  final OnlineRuleRuntimeStore? _store;
  final Map<String, DeterministicOnlineRuleRuntime> _runtimeByScope;
  final Map<String, OnlineRuleCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;
  final String? _unavailableReason;
  bool _disposed = false;

  final Map<String, OnlineRuleEvaluationOutcome> _outcomeByScope =
      <String, OnlineRuleEvaluationOutcome>{};
  final Map<String, OnlineRuleNormalizedOutput> _normalizedByScope =
      <String, OnlineRuleNormalizedOutput>{};

  OnlineRuleRuntimeStore _requireStore() {
    final OnlineRuleRuntimeStore? store = _store;
    if (store == null) throw StateError('Store required but unavailable.');
    return store;
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      snapshot(String scopeId) async {
    final OnlineRuleSourceRuntimeActionResult<void>? gate =
        _gate(scopeId, OnlineRuleCapability.manifestValidation);
    if (gate != null) return _castFail(gate);
    return _projection(scopeId);
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      validate(String scopeId, OnlineRuleManifest manifest) async {
    final OnlineRuleSourceRuntimeActionResult<void>? gate =
        _gate(scopeId, OnlineRuleCapability.manifestValidation);
    if (gate != null) return _castFail(gate);

    final DeterministicOnlineRuleRuntime runtime = _runtimeByScope[scopeId]!;
    final OnlineRuleValidationResult result =
        await runtime.validateManifest(manifest);

    final DateTime now = DateTime.now().toUtc();
    final StoredOnlineRuleValidationState validationState = result.isValid
        ? StoredOnlineRuleValidationState.valid
        : StoredOnlineRuleValidationState.invalid;

    await _requireStore().storeManifest(StoredOnlineRuleManifestRecord(
      sourceId: manifest.sourceId.value,
      displayName: manifest.displayName,
      version: manifest.version.value,
      updateUri: manifest.updateUri,
      checksum: manifest.checksum,
      updateInterval: manifest.updateInterval,
      validationState: validationState,
      createdAt: now,
      updatedAt: now,
    ));

    for (final OnlineRuleValidationIssue issue in result.issues) {
      await _requireStore()
          .recordValidationIssue(StoredOnlineRuleValidationIssueRecord(
        id: 'vi-${manifest.sourceId.value}-${issue.operationId ?? "general"}',
        sourceId: manifest.sourceId.value,
        message: issue.message,
        recordedAt: now,
        operationId: issue.operationId,
        unsupportedKind: issue.unsupportedKind != null
            ? _mapStoredUnsupportedKind(issue.unsupportedKind!)
            : null,
      ));
      if (issue.unsupportedKind != null) {
        await _requireStore()
            .recordUnsupportedOperation(StoredUnsupportedOnlineOperationRecord(
          id: 'uo-${manifest.sourceId.value}-${issue.operationId ?? "general"}',
          sourceId: manifest.sourceId.value,
          kind: _mapStoredUnsupportedKind(issue.unsupportedKind!),
          reason: issue.message,
          recordedAt: now,
          operationId: issue.operationId,
        ));
        _publishEvent(OnlineRuleUnsupportedOperationRecorded(
          occurredAt: now,
          sourceId: manifest.sourceId.value,
          kind: issue.unsupportedKind!.name,
          reason: issue.message,
          operationId: issue.operationId,
        ));
      }
    }

    await _requireStore().storeRuleSets(
      sourceId: manifest.sourceId.value,
      ruleSets: <StoredOnlineRuleSetRecord>[
        for (final OnlineRuleSet ruleSet in manifest.ruleSets)
          StoredOnlineRuleSetRecord(
            id: 'rs-${manifest.sourceId.value}-${ruleSet.target.name}',
            sourceId: manifest.sourceId.value,
            target: _mapStoredTarget(ruleSet.target),
            operations: <StoredOnlineExtractionOperationRecord>[
              for (final OnlineExtractionOperation op in ruleSet.operations)
                StoredOnlineExtractionOperationRecord(
                  id: op.id ?? 'op-${op.outputKey}',
                  kind: _mapStoredExtractionKind(op.kind),
                  expression: op.expression,
                  outputKey: op.outputKey,
                  required: op.required,
                  attribute: op.attribute,
                ),
            ],
          ),
      ],
    );

    _publishEvent(OnlineRuleManifestChanged(
      occurredAt: now,
      sourceId: manifest.sourceId.value,
      changeKind: OnlineRuleManifestChangeKind.registered,
      version: manifest.version.value,
    ));
    _publishEvent(OnlineRuleValidationStateChanged(
      occurredAt: now,
      sourceId: manifest.sourceId.value,
      valid: result.isValid,
      issueCount: result.issues.length,
    ));

    return _projection(scopeId);
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      evaluate(String scopeId, OnlineRuleEvaluationRequest request) async {
    final OnlineRuleSourceRuntimeActionResult<void>? gate =
        _gate(scopeId, OnlineRuleCapability.suppliedDocumentEvaluation);
    if (gate != null) return _castFail(gate);

    final DeterministicOnlineRuleRuntime runtime = _runtimeByScope[scopeId]!;
    final OnlineRuleEvaluationOutcome outcome =
        await runtime.evaluateTyped(request);
    final DateTime now = DateTime.now().toUtc();

    if (outcome.isSuccess) {
      final OnlineRuleNormalizationOutcome normalization =
          runtime.tryNormalize(outcome.result!);
      if (!normalization.isSuccess) {
        final OnlineRuleEvaluationOutcome failedOutcome =
            OnlineRuleEvaluationOutcome.failure(
                failure: normalization.failure!);
        _outcomeByScope[scopeId] = failedOutcome;
        _normalizedByScope.remove(scopeId);

        await _requireStore()
            .recordEvaluationSnapshot(StoredOnlineRuleEvaluationSnapshotRecord(
          id: 'eval-${request.manifest.sourceId.value}-${request.target.name}',
          sourceId: request.manifest.sourceId.value,
          target: _mapStoredTarget(request.target),
          pageUri: request.pageUri,
          state: StoredOnlineRuleEvaluationState.failed,
          values: outcome.result!.values,
          reason: normalization.failure?.message,
          evaluatedAt: now,
        ));

        _publishEvent(OnlineRuleTargetEvaluated(
          occurredAt: now,
          sourceId: request.manifest.sourceId.value,
          target: request.target.name,
          state: 'failed',
        ));

        return OnlineRuleSourceRuntimeActionResult<
            OnlineRuleSourceRuntimeProjection>.failed(
          OnlineRuleSourceRuntimeFailure(
            kind: _mapFailureKind(normalization.failure!.kind),
            message: normalization.failure!.message,
            sourceId: normalization.failure!.sourceId?.value,
          ),
        );
      }

      final OnlineRuleNormalizedOutput normalized = normalization.output!;
      _outcomeByScope[scopeId] = outcome;
      _normalizedByScope[scopeId] = normalized;

      await _requireStore()
          .recordEvaluationSnapshot(StoredOnlineRuleEvaluationSnapshotRecord(
        id: 'eval-${request.manifest.sourceId.value}-${request.target.name}',
        sourceId: request.manifest.sourceId.value,
        target: _mapStoredTarget(request.target),
        pageUri: request.pageUri,
        state: StoredOnlineRuleEvaluationState.succeeded,
        values: outcome.result!.values,
        evaluatedAt: now,
      ));

      _publishEvent(OnlineRuleTargetEvaluated(
        occurredAt: now,
        sourceId: request.manifest.sourceId.value,
        target: request.target.name,
        state: 'succeeded',
      ));
    } else {
      _outcomeByScope[scopeId] = outcome;

      await _requireStore()
          .recordEvaluationSnapshot(StoredOnlineRuleEvaluationSnapshotRecord(
        id: 'eval-${request.manifest.sourceId.value}-${request.target.name}',
        sourceId: request.manifest.sourceId.value,
        target: _mapStoredTarget(request.target),
        pageUri: request.pageUri,
        state: StoredOnlineRuleEvaluationState.failed,
        reason: outcome.failure?.message,
        evaluatedAt: now,
      ));

      _publishEvent(OnlineRuleTargetEvaluated(
        occurredAt: now,
        sourceId: request.manifest.sourceId.value,
        target: request.target.name,
        state: 'failed',
      ));

      return OnlineRuleSourceRuntimeActionResult<
          OnlineRuleSourceRuntimeProjection>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: _mapFailureKind(outcome.failure!.kind),
          message: outcome.failure!.message,
          sourceId: outcome.failure!.sourceId?.value,
        ),
      );
    }

    return _projection(scopeId);
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      disable(String scopeId) async {
    final OnlineRuleSourceRuntimeActionResult<void>? gate =
        _gate(scopeId, OnlineRuleCapability.manifestValidation);
    if (gate != null) return _castFail(gate);

    final StoredOnlineRuleManifestRecord? stored =
        await _requireStore().manifestBySource(scopeId);
    if (stored == null) {
      return OnlineRuleSourceRuntimeActionResult<
          OnlineRuleSourceRuntimeProjection>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: OnlineRuleSourceRuntimeFailureKind.manifestNotFound,
          message: 'Manifest not found for scope $scopeId.',
          sourceId: scopeId,
        ),
      );
    }

    final DateTime now = DateTime.now().toUtc();
    await _requireStore().storeManifest(StoredOnlineRuleManifestRecord(
      sourceId: stored.sourceId,
      displayName: stored.displayName,
      version: stored.version,
      updateUri: stored.updateUri,
      checksum: stored.checksum,
      updateInterval: stored.updateInterval,
      validationState: StoredOnlineRuleValidationState.disabled,
      createdAt: stored.createdAt,
      updatedAt: now,
      metadata: stored.metadata,
    ));

    _publishEvent(OnlineRuleManifestChanged(
      occurredAt: now,
      sourceId: scopeId,
      changeKind: OnlineRuleManifestChangeKind.disabled,
    ));

    return _projection(scopeId);
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      reenable(String scopeId) async {
    final OnlineRuleSourceRuntimeActionResult<void>? gate =
        _gate(scopeId, OnlineRuleCapability.manifestValidation);
    if (gate != null) return _castFail(gate);

    final StoredOnlineRuleManifestRecord? stored =
        await _requireStore().manifestBySource(scopeId);
    if (stored == null) {
      return OnlineRuleSourceRuntimeActionResult<
          OnlineRuleSourceRuntimeProjection>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: OnlineRuleSourceRuntimeFailureKind.manifestNotFound,
          message: 'Manifest not found for scope $scopeId.',
          sourceId: scopeId,
        ),
      );
    }

    if (stored.validationState == StoredOnlineRuleValidationState.invalid) {
      return OnlineRuleSourceRuntimeActionResult<
          OnlineRuleSourceRuntimeProjection>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: OnlineRuleSourceRuntimeFailureKind.manifestInvalid,
          message: 'Cannot reenable manifest with invalid validation state.',
          sourceId: scopeId,
        ),
      );
    }

    if (stored.validationState == StoredOnlineRuleValidationState.valid) {
      return _projection(scopeId);
    }

    final DateTime now = DateTime.now().toUtc();
    await _requireStore().storeManifest(StoredOnlineRuleManifestRecord(
      sourceId: stored.sourceId,
      displayName: stored.displayName,
      version: stored.version,
      updateUri: stored.updateUri,
      checksum: stored.checksum,
      updateInterval: stored.updateInterval,
      validationState: StoredOnlineRuleValidationState.valid,
      createdAt: stored.createdAt,
      updatedAt: now,
      metadata: stored.metadata,
    ));

    _publishEvent(OnlineRuleManifestChanged(
      occurredAt: now,
      sourceId: scopeId,
      changeKind: OnlineRuleManifestChangeKind.updated,
    ));

    return _projection(scopeId);
  }

  void dispose() {
    _disposed = true;
  }

  OnlineRuleSourceRuntimeActionResult<void>? _gate(
      String scopeId, OnlineRuleCapability capability) {
    if (_disposed) {
      return OnlineRuleSourceRuntimeActionResult<void>.disposed();
    }
    if (_unavailableReason != null) {
      return OnlineRuleSourceRuntimeActionResult<void>.unavailable(
          _unavailableReason);
    }
    final OnlineRuleCapabilityMatrix? capabilities =
        _capabilitiesByScope[scopeId];
    if (capabilities == null) {
      return OnlineRuleSourceRuntimeActionResult<void>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: OnlineRuleSourceRuntimeFailureKind.sourceUnsupported,
          message: 'No capabilities declared for scope $scopeId.',
          sourceId: scopeId,
        ),
      );
    }
    final OnlineRuleCapabilityStatus status = capabilities.statusOf(capability);
    if (!status.supported) {
      return OnlineRuleSourceRuntimeActionResult<void>.failed(
        OnlineRuleSourceRuntimeFailure(
          kind: OnlineRuleSourceRuntimeFailureKind.capabilityUnsupported,
          message: status.reason ??
              'Capability $capability is not supported for scope $scopeId.',
          sourceId: scopeId,
        ),
      );
    }
    return null;
  }

  Future<OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>>
      _projection(String scopeId) async {
    final StoredOnlineRuleManifestRecord? manifest =
        await _requireStore().manifestBySource(scopeId);
    final List<StoredOnlineRuleEvaluationSnapshotRecord> evaluations =
        await _requireStore().evaluationsForSource(scopeId);
    final StoredOnlineRuleEvaluationSnapshotRecord? latestEval =
        evaluations.isNotEmpty ? evaluations.last : null;

    final OnlineRuleEvaluationOutcome? outcome = _outcomeByScope[scopeId];
    final OnlineRuleNormalizedOutput? normalized = _normalizedByScope[scopeId];
    final OnlineRuleSourceRuntimeFailure? failure;

    if (outcome != null && !outcome.isSuccess) {
      failure = OnlineRuleSourceRuntimeFailure(
        kind: _mapFailureKind(outcome.failure!.kind),
        message: outcome.failure!.message,
        sourceId: outcome.failure!.sourceId?.value,
      );
    } else {
      failure = null;
    }

    final OnlineRuleSourceRuntimeRestartProjection restart =
        OnlineRuleSourceRuntimeRestartProjection(
      sourceId: scopeId,
      manifestValidationState:
          manifest?.validationState ?? StoredOnlineRuleValidationState.valid,
      latestEvaluationTarget: latestEval?.target,
      latestEvaluationState: latestEval?.state,
    );

    return OnlineRuleSourceRuntimeActionResult<
        OnlineRuleSourceRuntimeProjection>.success(
      OnlineRuleSourceRuntimeProjection(
        sourceId: scopeId,
        manifestDisplayName: manifest?.displayName,
        manifestVersion: manifest?.version,
        validationState: manifest?.validationState,
        latestEvaluationTarget: latestEval?.target,
        latestEvaluationState: latestEval?.state,
        latestEvaluationOutcome: outcome,
        latestNormalizedOutput: normalized,
        latestFailure: failure,
        restart: restart,
      ),
    );
  }

  OnlineRuleSourceRuntimeFailureKind _mapFailureKind(
      OnlineRuleFailureKind kind) {
    return switch (kind) {
      OnlineRuleFailureKind.manifestInvalid =>
        OnlineRuleSourceRuntimeFailureKind.manifestInvalid,
      OnlineRuleFailureKind.manifestDisabled =>
        OnlineRuleSourceRuntimeFailureKind.manifestDisabled,
      OnlineRuleFailureKind.sourceUnsupported =>
        OnlineRuleSourceRuntimeFailureKind.sourceUnsupported,
      OnlineRuleFailureKind.targetMissing =>
        OnlineRuleSourceRuntimeFailureKind.evaluationFailed,
      OnlineRuleFailureKind.requiredOutputMissing =>
        OnlineRuleSourceRuntimeFailureKind.evaluationFailed,
      OnlineRuleFailureKind.unsupportedOperation =>
        OnlineRuleSourceRuntimeFailureKind.evaluationFailed,
      OnlineRuleFailureKind.evaluationFailed =>
        OnlineRuleSourceRuntimeFailureKind.evaluationFailed,
      OnlineRuleFailureKind.gatewayUnavailable =>
        OnlineRuleSourceRuntimeFailureKind.sourceUnsupported,
      OnlineRuleFailureKind.networkPolicyBlocked =>
        OnlineRuleSourceRuntimeFailureKind.sourceUnsupported,
    };
  }

  StoredOnlineRuleTarget _mapStoredTarget(OnlineRuleTarget target) {
    return switch (target) {
      OnlineRuleTarget.search => StoredOnlineRuleTarget.search,
      OnlineRuleTarget.detail => StoredOnlineRuleTarget.detail,
      OnlineRuleTarget.episode => StoredOnlineRuleTarget.episode,
      OnlineRuleTarget.playableSource => StoredOnlineRuleTarget.playableSource,
    };
  }

  StoredOnlineExtractionKind _mapStoredExtractionKind(
      OnlineExtractionKind kind) {
    return switch (kind) {
      OnlineExtractionKind.cssSelector =>
        StoredOnlineExtractionKind.cssSelector,
      OnlineExtractionKind.xpath1 => StoredOnlineExtractionKind.xpath1,
      OnlineExtractionKind.regex => StoredOnlineExtractionKind.regex,
    };
  }

  StoredUnsupportedOnlineOperationKind _mapStoredUnsupportedKind(
      UnsupportedOnlineOperationKind kind) {
    return switch (kind) {
      UnsupportedOnlineOperationKind.javascript =>
        StoredUnsupportedOnlineOperationKind.javascript,
      UnsupportedOnlineOperationKind.wasm =>
        StoredUnsupportedOnlineOperationKind.wasm,
      UnsupportedOnlineOperationKind.scriptlet =>
        StoredUnsupportedOnlineOperationKind.scriptlet,
      UnsupportedOnlineOperationKind.arbitraryCode =>
        StoredUnsupportedOnlineOperationKind.arbitraryCode,
      UnsupportedOnlineOperationKind.unsupportedSelector =>
        StoredUnsupportedOnlineOperationKind.unsupportedSelector,
      UnsupportedOnlineOperationKind.unboundedRegex =>
        StoredUnsupportedOnlineOperationKind.unboundedRegex,
    };
  }

  void _publishEvent(CacheInvalidationEvent event) {
    _bus?.publish(event);
  }

  OnlineRuleSourceRuntimeActionResult<T> _castFail<T>(
      OnlineRuleSourceRuntimeActionResult<void> fail) {
    return OnlineRuleSourceRuntimeActionResult<T>._(
      kind: fail.kind,
      failure: fail.failure,
    );
  }
}
