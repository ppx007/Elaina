import '../../provider/rss/feed_contracts.dart';
import '../../provider/rss/rss_auto_download_policy.dart';

// Persisted RSS automation policy records.
//
// The evaluator writes decisions, candidates, dedupe keys, and enqueue outcomes
// separately so the UI can explain why an item was or was not downloaded after
// a refresh.
enum StoredRssAutoDownloadMatcherField {
  title,
  releaseGroup,
  episode,
  season,
  resolution,
  sizeBytes,
  category,
  sourceId,
  downloadSource,
  metadata,
}

enum StoredRssAutoDownloadMatcherOperator {
  contains,
  equals,
  regex,
  glob,
  greaterThanOrEqual,
  lessThanOrEqual,
  exists,
}

enum StoredRssAutoDownloadMatcherLogic {
  all,
  any,
}

enum StoredRssAutoDownloadEvaluationKind {
  accepted,
  rejected,
  deduplicated,
  disabled,
}

enum StoredRssAutoDownloadRejectionKind {
  automationDisabled,
  policyDisabled,
  ruleDisabled,
  sourceOutOfScope,
  includeNotMatched,
  excluded,
  duplicate,
  unsupportedSource,
  handoffUnavailable,
}

enum StoredRssAutoDownloadSourceKind {
  magnet,
  torrentUri,
}

enum StoredRssAutoDownloadEnqueueState {
  pending,
  accepted,
  rejected,
  duplicate,
  adapterUnavailable,
}

final class StoredRssAutoDownloadPolicyRecord {
  StoredRssAutoDownloadPolicyRecord({
    required this.id,
    required this.label,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(id != '', 'RSS auto-download policy id must not be empty.'),
        assert(
            label != '', 'RSS auto-download policy label must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String id;
  final String label;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> metadata;
}

final class StoredRssAutoDownloadFeedActivationRecord {
  const StoredRssAutoDownloadFeedActivationRecord({
    required this.policyId,
    required this.sourceId,
    required this.enabled,
    required this.updatedAt,
  })  : assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(sourceId != '', 'RSS feed source id must not be empty.');

  final String policyId;
  final String sourceId;
  final bool enabled;
  final DateTime updatedAt;
}

final class StoredRssAutoDownloadMatcherPredicateRecord {
  const StoredRssAutoDownloadMatcherPredicateRecord({
    required this.field,
    required this.operator,
    this.value,
    this.metadataKey,
    this.caseSensitive = false,
    this.negated = false,
  });

  final StoredRssAutoDownloadMatcherField field;
  final StoredRssAutoDownloadMatcherOperator operator;
  final String? value;
  final String? metadataKey;
  final bool caseSensitive;
  final bool negated;
}

final class StoredRssAutoDownloadMatcherRecord {
  StoredRssAutoDownloadMatcherRecord({
    required this.ruleId,
    required this.logic,
    Iterable<StoredRssAutoDownloadMatcherPredicateRecord> predicates =
        const <StoredRssAutoDownloadMatcherPredicateRecord>[],
  })  : assert(ruleId != '', 'RSS auto-download rule id must not be empty.'),
        predicates =
            List<StoredRssAutoDownloadMatcherPredicateRecord>.unmodifiable(
                predicates);

  final String ruleId;
  final StoredRssAutoDownloadMatcherLogic logic;
  final List<StoredRssAutoDownloadMatcherPredicateRecord> predicates;
}

final class StoredRssAutoDownloadRuleRecord {
  StoredRssAutoDownloadRuleRecord({
    required this.id,
    required this.policyId,
    required this.label,
    required this.priority,
    required this.enabled,
    required this.includeMatcher,
    this.excludeMatcher,
    Iterable<String> scopedSourceIds = const <String>[],
  })  : assert(id != '', 'RSS auto-download rule id must not be empty.'),
        assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(label != '', 'RSS auto-download rule label must not be empty.'),
        scopedSourceIds = List<String>.unmodifiable(scopedSourceIds);

  final String id;
  final String policyId;
  final String label;
  final int priority;
  final bool enabled;
  final StoredRssAutoDownloadMatcherRecord includeMatcher;
  final StoredRssAutoDownloadMatcherRecord? excludeMatcher;
  final List<String> scopedSourceIds;
}

final class StoredRssAutoDownloadEvaluationRecord {
  const StoredRssAutoDownloadEvaluationRecord({
    required this.id,
    required this.policyId,
    required this.itemId,
    required this.sourceId,
    required this.itemDedupeKey,
    required this.evaluationKind,
    required this.evaluatedAt,
    this.ruleId,
    this.candidateId,
    this.reason,
  })  : assert(id != '', 'RSS auto-download evaluation id must not be empty.'),
        assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(itemId != '', 'RSS feed item id must not be empty.'),
        assert(sourceId != '', 'RSS feed source id must not be empty.'),
        assert(
            itemDedupeKey != '', 'RSS feed item dedupe key must not be empty.');

  final String id;
  final String policyId;
  final String? ruleId;
  final String itemId;
  final String sourceId;
  final String itemDedupeKey;
  final StoredRssAutoDownloadEvaluationKind evaluationKind;
  final String? candidateId;
  final String? reason;
  final DateTime evaluatedAt;
}

final class StoredRssAutoDownloadAcceptedCandidateRecord {
  StoredRssAutoDownloadAcceptedCandidateRecord({
    required this.id,
    required this.policyId,
    required this.ruleId,
    required this.itemId,
    required this.sourceId,
    required this.itemDedupeKey,
    required this.candidateDedupeKey,
    required this.sourceKind,
    required this.sourceUri,
    required this.acceptedAt,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(id != '', 'RSS auto-download candidate id must not be empty.'),
        assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(ruleId != '', 'RSS auto-download rule id must not be empty.'),
        assert(itemId != '', 'RSS feed item id must not be empty.'),
        assert(sourceId != '', 'RSS feed source id must not be empty.'),
        assert(
            itemDedupeKey != '', 'RSS feed item dedupe key must not be empty.'),
        assert(candidateDedupeKey != '',
            'RSS candidate dedupe key must not be empty.'),
        assert(sourceUri != '', 'RSS candidate source URI must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String id;
  final String policyId;
  final String ruleId;
  final String itemId;
  final String sourceId;
  final String itemDedupeKey;
  final String candidateDedupeKey;
  final StoredRssAutoDownloadSourceKind sourceKind;
  final String sourceUri;
  final DateTime acceptedAt;
  final Map<String, String> metadata;
}

final class StoredRssAutoDownloadRejectedCandidateRecord {
  const StoredRssAutoDownloadRejectedCandidateRecord({
    required this.id,
    required this.policyId,
    required this.itemId,
    required this.sourceId,
    required this.itemDedupeKey,
    required this.rejectionKind,
    required this.reason,
    required this.rejectedAt,
    this.ruleId,
  })  : assert(id != '', 'RSS auto-download rejection id must not be empty.'),
        assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(itemId != '', 'RSS feed item id must not be empty.'),
        assert(sourceId != '', 'RSS feed source id must not be empty.'),
        assert(
            itemDedupeKey != '', 'RSS feed item dedupe key must not be empty.'),
        assert(reason != '',
            'RSS auto-download rejection reason must not be empty.');

  final String id;
  final String policyId;
  final String? ruleId;
  final String itemId;
  final String sourceId;
  final String itemDedupeKey;
  final StoredRssAutoDownloadRejectionKind rejectionKind;
  final String reason;
  final DateTime rejectedAt;
}

final class StoredRssAutoDownloadDedupeRecord {
  const StoredRssAutoDownloadDedupeRecord({
    required this.policyId,
    required this.candidateDedupeKey,
    required this.itemDedupeKey,
    required this.candidateId,
    required this.recordedAt,
  })  : assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(candidateDedupeKey != '',
            'RSS candidate dedupe key must not be empty.'),
        assert(
            itemDedupeKey != '', 'RSS feed item dedupe key must not be empty.'),
        assert(candidateId != '',
            'RSS auto-download candidate id must not be empty.');

  final String policyId;
  final String candidateDedupeKey;
  final String itemDedupeKey;
  final String candidateId;
  final DateTime recordedAt;
}

final class StoredRssAutoDownloadEnqueueOutcomeRecord {
  const StoredRssAutoDownloadEnqueueOutcomeRecord({
    required this.id,
    required this.candidateId,
    required this.policyId,
    required this.state,
    required this.message,
    required this.recordedAt,
    this.taskId,
  })  : assert(id != '', 'RSS enqueue outcome id must not be empty.'),
        assert(candidateId != '',
            'RSS auto-download candidate id must not be empty.'),
        assert(
            policyId != '', 'RSS auto-download policy id must not be empty.'),
        assert(message != '', 'RSS enqueue outcome message must not be empty.');

  final String id;
  final String candidateId;
  final String policyId;
  final StoredRssAutoDownloadEnqueueState state;
  final String message;
  final String? taskId;
  final DateTime recordedAt;
}

abstract interface class RssAutoDownloadPolicyStore {
  Future<StoredRssAutoDownloadPolicyRecord> storePolicy(
      StoredRssAutoDownloadPolicyRecord policy);

  Future<StoredRssAutoDownloadPolicyRecord?> policyById(String policyId);

  Future<List<StoredRssAutoDownloadPolicyRecord>> listPolicies();

  Future<bool> removePolicy(String policyId);

  Future<void> storeFeedActivation(
      StoredRssAutoDownloadFeedActivationRecord activation);

  Future<StoredRssAutoDownloadFeedActivationRecord?> feedActivation({
    required String policyId,
    required String sourceId,
  });

  Future<List<StoredRssAutoDownloadFeedActivationRecord>> activationsForPolicy(
      String policyId);

  Future<void> storeRules({
    required String policyId,
    required Iterable<StoredRssAutoDownloadRuleRecord> rules,
  });

  Future<List<StoredRssAutoDownloadRuleRecord>> rulesForPolicy(String policyId);

  Future<void> recordEvaluation(StoredRssAutoDownloadEvaluationRecord record);

  Future<List<StoredRssAutoDownloadEvaluationRecord>> evaluationsForItem({
    required String policyId,
    required String itemDedupeKey,
  });

  Future<void> storeAcceptedCandidate(
      StoredRssAutoDownloadAcceptedCandidateRecord candidate);

  Future<StoredRssAutoDownloadAcceptedCandidateRecord?> acceptedCandidateById(
      String candidateId);

  Future<List<StoredRssAutoDownloadAcceptedCandidateRecord>>
      acceptedCandidatesForPolicy(String policyId);

  Future<void> storeRejectedCandidate(
      StoredRssAutoDownloadRejectedCandidateRecord rejected);

  Future<List<StoredRssAutoDownloadRejectedCandidateRecord>>
      rejectedCandidatesForPolicy(String policyId);

  Future<bool> hasCandidateDedupeKey({
    required String policyId,
    required String candidateDedupeKey,
  });

  Future<void> recordDedupeKey(StoredRssAutoDownloadDedupeRecord record);

  Future<List<StoredRssAutoDownloadDedupeRecord>> dedupeKeysForPolicy(
      String policyId);

  Future<void> recordEnqueueOutcome(
      StoredRssAutoDownloadEnqueueOutcomeRecord outcome);

  Future<StoredRssAutoDownloadEnqueueOutcomeRecord?> latestEnqueueOutcome(
      String candidateId);
}

final class DeterministicRssAutoDownloadPolicyStore
    implements RssAutoDownloadPolicyStore {
  DeterministicRssAutoDownloadPolicyStore({
    Iterable<StoredRssAutoDownloadPolicyRecord> seedPolicies =
        const <StoredRssAutoDownloadPolicyRecord>[],
  }) {
    for (final StoredRssAutoDownloadPolicyRecord policy in seedPolicies) {
      _policiesById[policy.id] = policy;
    }
  }

  final Map<String, StoredRssAutoDownloadPolicyRecord> _policiesById =
      <String, StoredRssAutoDownloadPolicyRecord>{};
  final Map<String, StoredRssAutoDownloadFeedActivationRecord>
      _activationsByPolicyAndSource =
      <String, StoredRssAutoDownloadFeedActivationRecord>{};
  final Map<String, List<StoredRssAutoDownloadRuleRecord>> _rulesByPolicyId =
      <String, List<StoredRssAutoDownloadRuleRecord>>{};
  final List<StoredRssAutoDownloadEvaluationRecord> _evaluations =
      <StoredRssAutoDownloadEvaluationRecord>[];
  final Map<String, StoredRssAutoDownloadAcceptedCandidateRecord>
      _acceptedCandidatesById =
      <String, StoredRssAutoDownloadAcceptedCandidateRecord>{};
  final List<StoredRssAutoDownloadRejectedCandidateRecord> _rejectedCandidates =
      <StoredRssAutoDownloadRejectedCandidateRecord>[];
  final Map<String, StoredRssAutoDownloadDedupeRecord> _dedupeByPolicyAndKey =
      <String, StoredRssAutoDownloadDedupeRecord>{};
  final Map<String, StoredRssAutoDownloadEnqueueOutcomeRecord>
      _enqueueOutcomesByCandidateId =
      <String, StoredRssAutoDownloadEnqueueOutcomeRecord>{};

  @override
  Future<StoredRssAutoDownloadAcceptedCandidateRecord?> acceptedCandidateById(
      String candidateId) {
    return Future<StoredRssAutoDownloadAcceptedCandidateRecord?>.value(
        _acceptedCandidatesById[candidateId]);
  }

  @override
  Future<List<StoredRssAutoDownloadAcceptedCandidateRecord>>
      acceptedCandidatesForPolicy(String policyId) {
    return Future<List<StoredRssAutoDownloadAcceptedCandidateRecord>>.value(
      <StoredRssAutoDownloadAcceptedCandidateRecord>[
        for (final StoredRssAutoDownloadAcceptedCandidateRecord candidate
            in _acceptedCandidatesById.values)
          if (candidate.policyId == policyId) candidate,
      ],
    );
  }

  @override
  Future<List<StoredRssAutoDownloadFeedActivationRecord>> activationsForPolicy(
      String policyId) {
    return Future<List<StoredRssAutoDownloadFeedActivationRecord>>.value(
      <StoredRssAutoDownloadFeedActivationRecord>[
        for (final StoredRssAutoDownloadFeedActivationRecord activation
            in _activationsByPolicyAndSource.values)
          if (activation.policyId == policyId) activation,
      ],
    );
  }

  @override
  Future<List<StoredRssAutoDownloadDedupeRecord>> dedupeKeysForPolicy(
      String policyId) {
    return Future<List<StoredRssAutoDownloadDedupeRecord>>.value(
      <StoredRssAutoDownloadDedupeRecord>[
        for (final StoredRssAutoDownloadDedupeRecord record
            in _dedupeByPolicyAndKey.values)
          if (record.policyId == policyId) record,
      ],
    );
  }

  @override
  Future<List<StoredRssAutoDownloadEvaluationRecord>> evaluationsForItem({
    required String policyId,
    required String itemDedupeKey,
  }) {
    return Future<List<StoredRssAutoDownloadEvaluationRecord>>.value(
      <StoredRssAutoDownloadEvaluationRecord>[
        for (final StoredRssAutoDownloadEvaluationRecord record in _evaluations)
          if (record.policyId == policyId &&
              record.itemDedupeKey == itemDedupeKey)
            record,
      ],
    );
  }

  @override
  Future<StoredRssAutoDownloadFeedActivationRecord?> feedActivation({
    required String policyId,
    required String sourceId,
  }) {
    return Future<StoredRssAutoDownloadFeedActivationRecord?>.value(
        _activationsByPolicyAndSource[_key(policyId, sourceId)]);
  }

  @override
  Future<bool> hasCandidateDedupeKey({
    required String policyId,
    required String candidateDedupeKey,
  }) {
    return Future<bool>.value(
        _dedupeByPolicyAndKey.containsKey(_key(policyId, candidateDedupeKey)));
  }

  @override
  Future<StoredRssAutoDownloadEnqueueOutcomeRecord?> latestEnqueueOutcome(
      String candidateId) {
    return Future<StoredRssAutoDownloadEnqueueOutcomeRecord?>.value(
        _enqueueOutcomesByCandidateId[candidateId]);
  }

  @override
  Future<List<StoredRssAutoDownloadPolicyRecord>> listPolicies() {
    return Future<List<StoredRssAutoDownloadPolicyRecord>>.value(
        <StoredRssAutoDownloadPolicyRecord>[..._policiesById.values]);
  }

  @override
  Future<StoredRssAutoDownloadPolicyRecord?> policyById(String policyId) {
    return Future<StoredRssAutoDownloadPolicyRecord?>.value(
        _policiesById[policyId]);
  }

  @override
  Future<void> recordDedupeKey(StoredRssAutoDownloadDedupeRecord record) {
    _dedupeByPolicyAndKey[_key(record.policyId, record.candidateDedupeKey)] =
        record;
    return Future<void>.value();
  }

  @override
  Future<void> recordEnqueueOutcome(
      StoredRssAutoDownloadEnqueueOutcomeRecord outcome) {
    _enqueueOutcomesByCandidateId[outcome.candidateId] = outcome;
    return Future<void>.value();
  }

  @override
  Future<void> recordEvaluation(StoredRssAutoDownloadEvaluationRecord record) {
    _evaluations.add(record);
    return Future<void>.value();
  }

  @override
  Future<bool> removePolicy(String policyId) {
    final bool removed = _policiesById.remove(policyId) != null;
    _activationsByPolicyAndSource.removeWhere(
        (String key, StoredRssAutoDownloadFeedActivationRecord activation) =>
            activation.policyId == policyId);
    _rulesByPolicyId.remove(policyId);
    _evaluations.removeWhere((StoredRssAutoDownloadEvaluationRecord record) =>
        record.policyId == policyId);
    _acceptedCandidatesById.removeWhere(
        (String key, StoredRssAutoDownloadAcceptedCandidateRecord candidate) =>
            candidate.policyId == policyId);
    _rejectedCandidates.removeWhere(
        (StoredRssAutoDownloadRejectedCandidateRecord rejected) =>
            rejected.policyId == policyId);
    _dedupeByPolicyAndKey.removeWhere(
        (String key, StoredRssAutoDownloadDedupeRecord record) =>
            record.policyId == policyId);
    _enqueueOutcomesByCandidateId.removeWhere(
        (String key, StoredRssAutoDownloadEnqueueOutcomeRecord outcome) =>
            outcome.policyId == policyId);
    return Future<bool>.value(removed);
  }

  @override
  Future<List<StoredRssAutoDownloadRejectedCandidateRecord>>
      rejectedCandidatesForPolicy(String policyId) {
    return Future<List<StoredRssAutoDownloadRejectedCandidateRecord>>.value(
      <StoredRssAutoDownloadRejectedCandidateRecord>[
        for (final StoredRssAutoDownloadRejectedCandidateRecord rejected
            in _rejectedCandidates)
          if (rejected.policyId == policyId) rejected,
      ],
    );
  }

  @override
  Future<List<StoredRssAutoDownloadRuleRecord>> rulesForPolicy(
      String policyId) {
    return Future<List<StoredRssAutoDownloadRuleRecord>>.value(
        <StoredRssAutoDownloadRuleRecord>[...?_rulesByPolicyId[policyId]]);
  }

  @override
  Future<void> storeAcceptedCandidate(
      StoredRssAutoDownloadAcceptedCandidateRecord candidate) {
    _acceptedCandidatesById[candidate.id] = candidate;
    return Future<void>.value();
  }

  @override
  Future<void> storeFeedActivation(
      StoredRssAutoDownloadFeedActivationRecord activation) {
    _activationsByPolicyAndSource[
        _key(activation.policyId, activation.sourceId)] = activation;
    return Future<void>.value();
  }

  @override
  Future<StoredRssAutoDownloadPolicyRecord> storePolicy(
      StoredRssAutoDownloadPolicyRecord policy) {
    _policiesById[policy.id] = policy;
    return Future<StoredRssAutoDownloadPolicyRecord>.value(policy);
  }

  @override
  Future<void> storeRejectedCandidate(
      StoredRssAutoDownloadRejectedCandidateRecord rejected) {
    _rejectedCandidates.add(rejected);
    return Future<void>.value();
  }

  @override
  Future<void> storeRules({
    required String policyId,
    required Iterable<StoredRssAutoDownloadRuleRecord> rules,
  }) {
    _rulesByPolicyId[policyId] = <StoredRssAutoDownloadRuleRecord>[...rules];
    return Future<void>.value();
  }

  static String _key(String first, String second) => '$first::$second';
}

final class DeterministicRssAutomationHistoryStore
    implements RssAutomationHistoryStore {
  DeterministicRssAutomationHistoryStore({
    Iterable<FeedDedupeKey> seedAcceptedKeys = const <FeedDedupeKey>[],
  }) {
    for (final FeedDedupeKey key in seedAcceptedKeys) {
      _acceptedKeys.add(key.value);
    }
  }

  final Set<String> _acceptedKeys = <String>{};
  final List<RssAutomationHistoryEntry> _entries =
      <RssAutomationHistoryEntry>[];

  @override
  Future<bool> hasAccepted(FeedDedupeKey itemKey) {
    return Future<bool>.value(_acceptedKeys.contains(itemKey.value));
  }

  @override
  Future<void> record(RssAutomationHistoryEntry entry) {
    _entries.add(entry);
    if (entry.decision is RssAutomationAccepted) {
      _acceptedKeys.add(entry.itemKey.value);
    }
    return Future<void>.value();
  }
}
