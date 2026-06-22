/// Stored online-rule records are persistence DTOs, not parser/runtime models.
/// Keep validation and extraction semantics in the provider runtime layer.
enum StoredOnlineRuleTarget {
  search,
  detail,
  episode,
  playableSource,
}

enum StoredOnlineExtractionKind {
  cssSelector,
  xpath1,
  regex,
}

enum StoredUnsupportedOnlineOperationKind {
  javascript,
  wasm,
  scriptlet,
  arbitraryCode,
  unsupportedSelector,
  unboundedRegex,
}

enum StoredOnlineRuleValidationState {
  valid,
  invalid,
  disabled,
}

enum StoredOnlineRuleEvaluationState {
  succeeded,
  failed,
  disabled,
  unsupported,
}

enum StoredOnlineRuleRetrievalState {
  pending,
  retrieved,
  failed,
  blockedByNetworkPolicy,
  gatewayUnavailable,
}

enum StoredOnlineRuleCapabilityState {
  supported,
  unsupported,
  disabled,
}

final class StoredOnlineRuleManifestRecord {
  StoredOnlineRuleManifestRecord({
    required this.sourceId,
    required this.displayName,
    required this.version,
    required this.updateUri,
    required this.checksum,
    required this.updateInterval,
    required this.validationState,
    required this.createdAt,
    required this.updatedAt,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(sourceId != '', 'Online rule source id must not be empty.'),
        assert(
            displayName != '', 'Online rule display name must not be empty.'),
        assert(
            version != '', 'Online rule manifest version must not be empty.'),
        assert(checksum != '', 'Online rule checksum must not be empty.'),
        assert(updateInterval > Duration.zero,
            'Online rule update interval must be positive.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String sourceId;
  final String displayName;
  final String version;
  final Uri updateUri;
  final String checksum;
  final Duration updateInterval;
  final StoredOnlineRuleValidationState validationState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> metadata;
}

final class StoredOnlineRuleManifestVersionRecord {
  const StoredOnlineRuleManifestVersionRecord({
    required this.sourceId,
    required this.version,
    required this.checksum,
    required this.recordedAt,
    this.previousVersion,
  })  : assert(sourceId != '', 'Online rule source id must not be empty.'),
        assert(
            version != '', 'Online rule manifest version must not be empty.'),
        assert(checksum != '', 'Online rule checksum must not be empty.');

  final String sourceId;
  final String version;
  final String? previousVersion;
  final String checksum;
  final DateTime recordedAt;
}

final class StoredOnlineExtractionOperationRecord {
  const StoredOnlineExtractionOperationRecord({
    required this.id,
    required this.kind,
    required this.expression,
    required this.outputKey,
    required this.required,
    this.attribute,
  })  : assert(id != '', 'Online extraction operation id must not be empty.'),
        assert(expression != '',
            'Online extraction expression must not be empty.'),
        assert(
            outputKey != '', 'Online extraction output key must not be empty.');

  final String id;
  final StoredOnlineExtractionKind kind;
  final String expression;
  final String outputKey;
  final String? attribute;
  final bool required;
}

final class StoredOnlineRuleSetRecord {
  StoredOnlineRuleSetRecord({
    required this.id,
    required this.sourceId,
    required this.target,
    Iterable<StoredOnlineExtractionOperationRecord> operations =
        const <StoredOnlineExtractionOperationRecord>[],
  })  : assert(id != '', 'Online rule set id must not be empty.'),
        assert(sourceId != '', 'Online rule source id must not be empty.'),
        operations = List<StoredOnlineExtractionOperationRecord>.unmodifiable(
            operations);

  final String id;
  final String sourceId;
  final StoredOnlineRuleTarget target;
  final List<StoredOnlineExtractionOperationRecord> operations;
}

final class StoredOnlineRuleValidationIssueRecord {
  const StoredOnlineRuleValidationIssueRecord({
    required this.id,
    required this.sourceId,
    required this.message,
    required this.recordedAt,
    this.ruleSetId,
    this.operationId,
    this.unsupportedKind,
  })  : assert(id != '', 'Online rule validation issue id must not be empty.'),
        assert(sourceId != '', 'Online rule source id must not be empty.'),
        assert(
            message != '', 'Online rule validation message must not be empty.');

  final String id;
  final String sourceId;
  final String? ruleSetId;
  final String? operationId;
  final StoredUnsupportedOnlineOperationKind? unsupportedKind;
  final String message;
  final DateTime recordedAt;
}

final class StoredOnlineRuleEvaluationSnapshotRecord {
  StoredOnlineRuleEvaluationSnapshotRecord({
    required this.id,
    required this.sourceId,
    required this.target,
    required this.pageUri,
    required this.state,
    required this.evaluatedAt,
    Map<String, String> values = const <String, String>{},
    this.reason,
  })  : assert(id != '', 'Online rule evaluation id must not be empty.'),
        assert(sourceId != '', 'Online rule source id must not be empty.'),
        values = Map<String, String>.unmodifiable(values);

  final String id;
  final String sourceId;
  final StoredOnlineRuleTarget target;
  final Uri pageUri;
  final StoredOnlineRuleEvaluationState state;
  final Map<String, String> values;
  final String? reason;
  final DateTime evaluatedAt;
}

final class StoredOnlineRulePageRetrievalOutcomeRecord {
  const StoredOnlineRulePageRetrievalOutcomeRecord({
    required this.id,
    required this.sourceId,
    required this.pageUri,
    required this.state,
    required this.recordedAt,
    this.providerCacheKey,
    this.networkFailureKind,
    this.message,
  })  : assert(id != '', 'Online rule retrieval outcome id must not be empty.'),
        assert(sourceId != '', 'Online rule source id must not be empty.');

  final String id;
  final String sourceId;
  final Uri pageUri;
  final StoredOnlineRuleRetrievalState state;
  final String? providerCacheKey;
  final String? networkFailureKind;
  final String? message;
  final DateTime recordedAt;
}

final class StoredUnsupportedOnlineOperationRecord {
  const StoredUnsupportedOnlineOperationRecord({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.reason,
    required this.recordedAt,
    this.operationId,
  })  : assert(id != '', 'Unsupported online operation id must not be empty.'),
        assert(sourceId != '', 'Online rule source id must not be empty.'),
        assert(reason != '',
            'Unsupported online operation reason must not be empty.');

  final String id;
  final String sourceId;
  final String? operationId;
  final StoredUnsupportedOnlineOperationKind kind;
  final String reason;
  final DateTime recordedAt;
}

final class StoredOnlineRuleSourceCapabilityRecord {
  const StoredOnlineRuleSourceCapabilityRecord({
    required this.sourceId,
    required this.state,
    required this.updatedAt,
    this.reason,
  }) : assert(sourceId != '', 'Online rule source id must not be empty.');

  final String sourceId;
  final StoredOnlineRuleCapabilityState state;
  final String? reason;
  final DateTime updatedAt;
}

/// Persistence port consumed by the online-rule runtime.
/// Runtime validation owns semantics; this store only preserves manifests,
/// retrieval outcomes, evaluations, and unsupported-operation audit entries.
abstract interface class OnlineRuleRuntimeStore {
  Future<StoredOnlineRuleManifestRecord> storeManifest(
      StoredOnlineRuleManifestRecord manifest);

  Future<StoredOnlineRuleManifestRecord?> manifestBySource(String sourceId);

  Future<List<StoredOnlineRuleManifestRecord>> listManifests();

  Future<bool> removeManifest(String sourceId);

  Future<void> recordManifestVersion(
      StoredOnlineRuleManifestVersionRecord version);

  Future<List<StoredOnlineRuleManifestVersionRecord>> versionsForSource(
      String sourceId);

  Future<void> storeRuleSets({
    required String sourceId,
    required Iterable<StoredOnlineRuleSetRecord> ruleSets,
  });

  Future<List<StoredOnlineRuleSetRecord>> ruleSetsForSource(String sourceId);

  Future<void> recordValidationIssue(
      StoredOnlineRuleValidationIssueRecord issue);

  Future<List<StoredOnlineRuleValidationIssueRecord>> validationIssuesForSource(
      String sourceId);

  Future<void> recordEvaluationSnapshot(
      StoredOnlineRuleEvaluationSnapshotRecord snapshot);

  Future<List<StoredOnlineRuleEvaluationSnapshotRecord>> evaluationsForSource(
      String sourceId);

  Future<void> recordPageRetrievalOutcome(
      StoredOnlineRulePageRetrievalOutcomeRecord outcome);

  Future<StoredOnlineRulePageRetrievalOutcomeRecord?> latestRetrievalOutcome(
      String sourceId);

  Future<void> recordUnsupportedOperation(
      StoredUnsupportedOnlineOperationRecord operation);

  Future<List<StoredUnsupportedOnlineOperationRecord>>
      unsupportedOperationsForSource(String sourceId);

  Future<void> storeCapability(
      StoredOnlineRuleSourceCapabilityRecord capability);

  Future<StoredOnlineRuleSourceCapabilityRecord?> capabilityForSource(
      String sourceId);
}

final class DeterministicOnlineRuleRuntimeStore
    implements OnlineRuleRuntimeStore {
  DeterministicOnlineRuleRuntimeStore({
    Iterable<StoredOnlineRuleManifestRecord> seedManifests =
        const <StoredOnlineRuleManifestRecord>[],
  }) {
    for (final StoredOnlineRuleManifestRecord manifest in seedManifests) {
      _manifestsBySource[manifest.sourceId] = manifest;
    }
  }

  final Map<String, StoredOnlineRuleManifestRecord> _manifestsBySource =
      <String, StoredOnlineRuleManifestRecord>{};
  final Map<String, List<StoredOnlineRuleManifestVersionRecord>>
      _versionsBySource =
      <String, List<StoredOnlineRuleManifestVersionRecord>>{};
  final Map<String, List<StoredOnlineRuleSetRecord>> _ruleSetsBySource =
      <String, List<StoredOnlineRuleSetRecord>>{};
  final List<StoredOnlineRuleValidationIssueRecord> _validationIssues =
      <StoredOnlineRuleValidationIssueRecord>[];
  final List<StoredOnlineRuleEvaluationSnapshotRecord> _evaluations =
      <StoredOnlineRuleEvaluationSnapshotRecord>[];
  final Map<String, StoredOnlineRulePageRetrievalOutcomeRecord>
      _retrievalOutcomesBySource =
      <String, StoredOnlineRulePageRetrievalOutcomeRecord>{};
  final List<StoredUnsupportedOnlineOperationRecord> _unsupportedOperations =
      <StoredUnsupportedOnlineOperationRecord>[];
  final Map<String, StoredOnlineRuleSourceCapabilityRecord>
      _capabilitiesBySource =
      <String, StoredOnlineRuleSourceCapabilityRecord>{};

  @override
  Future<StoredOnlineRuleSourceCapabilityRecord?> capabilityForSource(
      String sourceId) {
    return Future<StoredOnlineRuleSourceCapabilityRecord?>.value(
        _capabilitiesBySource[sourceId]);
  }

  @override
  Future<List<StoredOnlineRuleEvaluationSnapshotRecord>> evaluationsForSource(
      String sourceId) {
    return Future<List<StoredOnlineRuleEvaluationSnapshotRecord>>.value(
      <StoredOnlineRuleEvaluationSnapshotRecord>[
        for (final StoredOnlineRuleEvaluationSnapshotRecord snapshot
            in _evaluations)
          if (snapshot.sourceId == sourceId) snapshot,
      ],
    );
  }

  @override
  Future<StoredOnlineRulePageRetrievalOutcomeRecord?> latestRetrievalOutcome(
      String sourceId) {
    return Future<StoredOnlineRulePageRetrievalOutcomeRecord?>.value(
        _retrievalOutcomesBySource[sourceId]);
  }

  @override
  Future<List<StoredOnlineRuleManifestRecord>> listManifests() {
    return Future<List<StoredOnlineRuleManifestRecord>>.value(
        <StoredOnlineRuleManifestRecord>[..._manifestsBySource.values]);
  }

  @override
  Future<StoredOnlineRuleManifestRecord?> manifestBySource(String sourceId) {
    return Future<StoredOnlineRuleManifestRecord?>.value(
        _manifestsBySource[sourceId]);
  }

  @override
  Future<void> recordEvaluationSnapshot(
      StoredOnlineRuleEvaluationSnapshotRecord snapshot) {
    _evaluations.add(snapshot);
    return Future<void>.value();
  }

  @override
  Future<void> recordManifestVersion(
      StoredOnlineRuleManifestVersionRecord version) {
    _versionsBySource
        .putIfAbsent(
            version.sourceId, () => <StoredOnlineRuleManifestVersionRecord>[])
        .add(version);
    return Future<void>.value();
  }

  @override
  Future<void> recordPageRetrievalOutcome(
      StoredOnlineRulePageRetrievalOutcomeRecord outcome) {
    _retrievalOutcomesBySource[outcome.sourceId] = outcome;
    return Future<void>.value();
  }

  @override
  Future<void> recordUnsupportedOperation(
      StoredUnsupportedOnlineOperationRecord operation) {
    _unsupportedOperations.add(operation);
    return Future<void>.value();
  }

  @override
  Future<void> recordValidationIssue(
      StoredOnlineRuleValidationIssueRecord issue) {
    _validationIssues.add(issue);
    return Future<void>.value();
  }

  @override
  Future<bool> removeManifest(String sourceId) {
    final bool removed = _manifestsBySource.remove(sourceId) != null;
    _versionsBySource.remove(sourceId);
    _ruleSetsBySource.remove(sourceId);
    _validationIssues.removeWhere(
        (StoredOnlineRuleValidationIssueRecord issue) =>
            issue.sourceId == sourceId);
    _evaluations.removeWhere(
        (StoredOnlineRuleEvaluationSnapshotRecord snapshot) =>
            snapshot.sourceId == sourceId);
    _retrievalOutcomesBySource.remove(sourceId);
    _unsupportedOperations.removeWhere(
        (StoredUnsupportedOnlineOperationRecord operation) =>
            operation.sourceId == sourceId);
    _capabilitiesBySource.remove(sourceId);
    return Future<bool>.value(removed);
  }

  @override
  Future<List<StoredOnlineRuleSetRecord>> ruleSetsForSource(String sourceId) {
    return Future<List<StoredOnlineRuleSetRecord>>.value(
        <StoredOnlineRuleSetRecord>[...?_ruleSetsBySource[sourceId]]);
  }

  @override
  Future<void> storeCapability(
      StoredOnlineRuleSourceCapabilityRecord capability) {
    _capabilitiesBySource[capability.sourceId] = capability;
    return Future<void>.value();
  }

  @override
  Future<StoredOnlineRuleManifestRecord> storeManifest(
      StoredOnlineRuleManifestRecord manifest) {
    _manifestsBySource[manifest.sourceId] = manifest;
    return Future<StoredOnlineRuleManifestRecord>.value(manifest);
  }

  @override
  Future<void> storeRuleSets({
    required String sourceId,
    required Iterable<StoredOnlineRuleSetRecord> ruleSets,
  }) {
    _ruleSetsBySource[sourceId] = <StoredOnlineRuleSetRecord>[...ruleSets];
    return Future<void>.value();
  }

  @override
  Future<List<StoredUnsupportedOnlineOperationRecord>>
      unsupportedOperationsForSource(String sourceId) {
    return Future<List<StoredUnsupportedOnlineOperationRecord>>.value(
      <StoredUnsupportedOnlineOperationRecord>[
        for (final StoredUnsupportedOnlineOperationRecord operation
            in _unsupportedOperations)
          if (operation.sourceId == sourceId) operation,
      ],
    );
  }

  @override
  Future<List<StoredOnlineRuleValidationIssueRecord>> validationIssuesForSource(
      String sourceId) {
    return Future<List<StoredOnlineRuleValidationIssueRecord>>.value(
      <StoredOnlineRuleValidationIssueRecord>[
        for (final StoredOnlineRuleValidationIssueRecord issue
            in _validationIssues)
          if (issue.sourceId == sourceId) issue,
      ],
    );
  }

  @override
  Future<List<StoredOnlineRuleManifestVersionRecord>> versionsForSource(
      String sourceId) {
    return Future<
        List<
            StoredOnlineRuleManifestVersionRecord>>.value(<StoredOnlineRuleManifestVersionRecord>[
      ...?_versionsBySource[sourceId],
    ]);
  }
}
