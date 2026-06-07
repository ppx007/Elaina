import 'feed_contracts.dart';

final class RssAutoDownloadPolicyId {
  const RssAutoDownloadPolicyId(this.value)
      : assert(value != '', 'RSS auto-download policy id must not be empty.');

  final String value;
}

final class RssAutoDownloadRuleId {
  const RssAutoDownloadRuleId(this.value)
      : assert(value != '', 'RSS auto-download rule id must not be empty.');

  final String value;
}

enum RssMatcherField {
  title,
  releaseGroup,
  episode,
  season,
  resolution,
  sizeBytes,
  category,
  sourceId,
  metadata,
}

enum RssMatcherOperator {
  contains,
  equals,
  regex,
  glob,
  greaterThanOrEqual,
  lessThanOrEqual,
  exists,
}

enum RssMatcherLogic {
  all,
  any,
}

final class RssMatcherPredicate {
  const RssMatcherPredicate({
    required this.field,
    required this.operator,
    this.value,
    this.metadataKey,
    this.caseSensitive = false,
    this.negated = false,
  });

  final RssMatcherField field;
  final RssMatcherOperator operator;
  final String? value;
  final String? metadataKey;
  final bool caseSensitive;
  final bool negated;
}

final class RssMatcherExpression {
  RssMatcherExpression({
    required this.logic,
    Iterable<RssMatcherPredicate> predicates = const <RssMatcherPredicate>[],
  }) : predicates = List<RssMatcherPredicate>.unmodifiable(predicates);

  final RssMatcherLogic logic;
  final List<RssMatcherPredicate> predicates;
}

final class RssAutoDownloadRule {
  RssAutoDownloadRule({
    required this.id,
    required this.label,
    required this.priority,
    required this.include,
    this.exclude,
    Iterable<FeedSourceId> scopedSources = const <FeedSourceId>[],
    this.enabled = true,
  })  : assert(label != '', 'RSS auto-download rule label must not be empty.'),
        scopedSources = List<FeedSourceId>.unmodifiable(scopedSources);

  final RssAutoDownloadRuleId id;
  final String label;
  final int priority;
  final RssMatcherExpression include;
  final RssMatcherExpression? exclude;
  final List<FeedSourceId> scopedSources;
  final bool enabled;
}

final class RssAutoDownloadPolicy {
  RssAutoDownloadPolicy({
    required this.id,
    required this.label,
    Iterable<RssAutoDownloadRule> rules = const <RssAutoDownloadRule>[],
    this.enabled = true,
  })  : assert(label != '', 'RSS auto-download policy label must not be empty.'),
        rules = List<RssAutoDownloadRule>.unmodifiable(rules);

  final RssAutoDownloadPolicyId id;
  final String label;
  final List<RssAutoDownloadRule> rules;
  final bool enabled;
}

sealed class RssDownloadSource {
  const RssDownloadSource();
}

final class MagnetRssDownloadSource extends RssDownloadSource {
  const MagnetRssDownloadSource(this.uri)
      : assert(uri != '', 'Magnet URI must not be empty.');

  final String uri;
}

final class TorrentRssDownloadSource extends RssDownloadSource {
  const TorrentRssDownloadSource(this.uri);

  final Uri uri;
}

final class RssDownloadCandidate {
  RssDownloadCandidate({
    required this.policyId,
    required this.ruleId,
    required this.item,
    required this.source,
    String? dedupeKey,
    Map<String, String> metadata = const <String, String>{},
  })  : dedupeKey = dedupeKey ?? '${policyId.value}::${item.dedupeKey.value}',
        metadata = Map<String, String>.unmodifiable(metadata);

  final RssAutoDownloadPolicyId policyId;
  final RssAutoDownloadRuleId ruleId;
  final FeedItem item;
  final RssDownloadSource source;
  final String dedupeKey;
  final Map<String, String> metadata;
}

enum RssAutomationRejectionKind {
  automationDisabled,
  policyDisabled,
  ruleDisabled,
  sourceOutOfScope,
  includeNotMatched,
  excluded,
  duplicate,
  unsupportedSource,
}

enum RssAutomationFailureKind {
  policyNotFound,
  policyDisabled,
  invalidMatcher,
  unsupportedSource,
  historyUnavailable,
  enqueueUnavailable,
}

enum RssAutomationCapability {
  policyEvaluation,
  durableHistory,
  btTaskHandoff,
  optionalBackgroundScheduling,
}

final class RssAutomationCapabilityStatus {
  const RssAutomationCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const RssAutomationCapabilityStatus.unsupported(this.reason)
      : supported = false;

  final bool supported;
  final String? reason;
}

final class RssAutomationCapabilityMatrix {
  const RssAutomationCapabilityMatrix(
      {required Map<RssAutomationCapability, RssAutomationCapabilityStatus>
          capabilities})
      : _capabilities = capabilities;

  factory RssAutomationCapabilityMatrix.unsupported({required String reason}) {
    return RssAutomationCapabilityMatrix(
      capabilities: <RssAutomationCapability, RssAutomationCapabilityStatus>{
        for (final RssAutomationCapability capability
            in RssAutomationCapability.values)
          capability: RssAutomationCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<RssAutomationCapability, RssAutomationCapabilityStatus>
      _capabilities;

  RssAutomationCapabilityStatus statusOf(RssAutomationCapability capability) {
    return _capabilities[capability] ??
        const RssAutomationCapabilityStatus.unsupported(
            'RSS automation capability is not declared.');
  }
}

final class RssAutomationFailure {
  const RssAutomationFailure({required this.kind, required this.message})
      : assert(message != '', 'RSS automation failure message must not be empty.');

  final RssAutomationFailureKind kind;
  final String message;
}

final class RssAutomationRegistrationOutcome {
  const RssAutomationRegistrationOutcome._({this.policyId, this.failure});

  const RssAutomationRegistrationOutcome.registered(
      {required RssAutoDownloadPolicyId policyId})
      : this._(policyId: policyId);

  const RssAutomationRegistrationOutcome.failure(
      {required RssAutomationFailure failure})
      : this._(failure: failure);

  final RssAutoDownloadPolicyId? policyId;
  final RssAutomationFailure? failure;

  bool get isSuccess => failure == null;
}

final class RssAutomationDisableOutcome {
  const RssAutomationDisableOutcome._({this.policyId, this.failure});

  const RssAutomationDisableOutcome.disabled(
      {required RssAutoDownloadPolicyId policyId})
      : this._(policyId: policyId);

  const RssAutomationDisableOutcome.failure(
      {required RssAutomationFailure failure})
      : this._(failure: failure);

  final RssAutoDownloadPolicyId? policyId;
  final RssAutomationFailure? failure;

  bool get isSuccess => failure == null;
}

sealed class RssAutomationDecision {
  const RssAutomationDecision({required this.item});

  final FeedItem item;
}

final class RssAutomationAccepted extends RssAutomationDecision {
  const RssAutomationAccepted({required super.item, required this.candidate});

  final RssDownloadCandidate candidate;
}

final class RssAutomationDeduplicated extends RssAutomationDecision {
  const RssAutomationDeduplicated({
    required super.item,
    required this.policyId,
    required this.dedupeKey,
    required this.reason,
  }) : assert(reason != '', 'RSS automation dedupe reason must not be empty.');

  final RssAutoDownloadPolicyId policyId;
  final String dedupeKey;
  final String reason;
}

final class RssAutomationDisabled extends RssAutomationDecision {
  const RssAutomationDisabled({
    required super.item,
    required this.policyId,
    required this.reason,
  }) : assert(reason != '', 'RSS automation disabled reason must not be empty.');

  final RssAutoDownloadPolicyId policyId;
  final String reason;
}

final class RssAutomationRejected extends RssAutomationDecision {
  const RssAutomationRejected({
    required super.item,
    required this.kind,
    required this.reason,
    this.ruleId,
  }) : assert(reason != '', 'RSS automation rejection reason must not be empty.');

  final RssAutomationRejectionKind kind;
  final String reason;
  final RssAutoDownloadRuleId? ruleId;
}

final class RssAutomationEvaluationOutcome {
  RssAutomationEvaluationOutcome._({
    required Iterable<RssAutomationDecision> decisions,
    this.failure,
  }) : decisions = List<RssAutomationDecision>.unmodifiable(decisions);

  RssAutomationEvaluationOutcome.success(
      {required Iterable<RssAutomationDecision> decisions})
      : this._(decisions: decisions);

  RssAutomationEvaluationOutcome.failure(
      {required RssAutomationFailure failure})
      : this._(decisions: const <RssAutomationDecision>[], failure: failure);

  final List<RssAutomationDecision> decisions;
  final RssAutomationFailure? failure;

  bool get isSuccess => failure == null;
}

final class RssAutomationBtHandoffReadModel {
  const RssAutomationBtHandoffReadModel({
    required this.policyId,
    required this.ruleId,
    required this.feedItemId,
    required this.feedSourceId,
    required this.itemDedupeKey,
    required this.candidateDedupeKey,
    required this.source,
  })  : assert(itemDedupeKey != '', 'RSS feed item dedupe key must not be empty.'),
        assert(candidateDedupeKey != '', 'RSS candidate dedupe key must not be empty.');

  final RssAutoDownloadPolicyId policyId;
  final RssAutoDownloadRuleId ruleId;
  final FeedItemId feedItemId;
  final FeedSourceId feedSourceId;
  final String itemDedupeKey;
  final String candidateDedupeKey;
  final RssDownloadSource source;
}

final class RssAutomationHandoffOutcome {
  const RssAutomationHandoffOutcome._({this.handoff, this.failure});

  const RssAutomationHandoffOutcome.ready(
      {required RssAutomationBtHandoffReadModel handoff})
      : this._(handoff: handoff);

  const RssAutomationHandoffOutcome.failure(
      {required RssAutomationFailure failure})
      : this._(failure: failure);

  final RssAutomationBtHandoffReadModel? handoff;
  final RssAutomationFailure? failure;

  bool get isSuccess => failure == null;
}

final class RssAutomationHistoryEntry {
  const RssAutomationHistoryEntry({
    required this.policyId,
    required this.itemKey,
    required this.evaluatedAt,
    required this.decision,
    this.enqueueOutcomeId,
  });

  final RssAutoDownloadPolicyId policyId;
  final FeedDedupeKey itemKey;
  final DateTime evaluatedAt;
  final RssAutomationDecision decision;
  final String? enqueueOutcomeId;
}

abstract interface class RssAutomationHistoryStore {
  Future<bool> hasAccepted(FeedDedupeKey itemKey);

  Future<void> record(RssAutomationHistoryEntry entry);
}

abstract interface class RssAutoDownloadPolicyEvaluator {
  Future<List<RssAutomationDecision>> evaluate({
    required RssAutoDownloadPolicy policy,
    required Iterable<FeedItem> items,
    required RssAutomationHistoryStore history,
  });
}

final class DeterministicRssAutoDownloadPolicyEvaluator
    implements RssAutoDownloadPolicyEvaluator {
  const DeterministicRssAutoDownloadPolicyEvaluator({
    this.automationEnabled = true,
    DateTime Function()? clock,
  }) : _clock = clock;

  final bool automationEnabled;
  final DateTime Function()? _clock;

  @override
  Future<List<RssAutomationDecision>> evaluate({
    required RssAutoDownloadPolicy policy,
    required Iterable<FeedItem> items,
    required RssAutomationHistoryStore history,
  }) async {
    final DateTime evaluatedAt = (_clock ?? _defaultClock)();
    final List<RssAutoDownloadRule> orderedRules = <RssAutoDownloadRule>[
      ...policy.rules,
    ]..sort((RssAutoDownloadRule left, RssAutoDownloadRule right) =>
        left.priority.compareTo(right.priority));
    final List<RssAutomationDecision> decisions = <RssAutomationDecision>[];

    for (final FeedItem item in items) {
      final RssAutomationDecision decision = await _evaluateItem(
        policy: policy,
        rules: orderedRules,
        item: item,
        history: history,
      );
      decisions.add(decision);
      await history.record(
        RssAutomationHistoryEntry(
          policyId: policy.id,
          itemKey: item.dedupeKey,
          evaluatedAt: evaluatedAt,
          decision: decision,
        ),
      );
    }

    return decisions;
  }

  Future<RssAutomationEvaluationOutcome> evaluateTyped({
    required RssAutoDownloadPolicy policy,
    required Iterable<FeedItem> items,
    required RssAutomationHistoryStore history,
  }) async {
    try {
      return RssAutomationEvaluationOutcome.success(
        decisions:
            await evaluate(policy: policy, items: items, history: history),
      );
    } on Object catch (error) {
      return RssAutomationEvaluationOutcome.failure(
        failure: RssAutomationFailure(
          kind: RssAutomationFailureKind.historyUnavailable,
          message: error.toString(),
        ),
      );
    }
  }

  Future<RssAutomationDecision> _evaluateItem({
    required RssAutoDownloadPolicy policy,
    required List<RssAutoDownloadRule> rules,
    required FeedItem item,
    required RssAutomationHistoryStore history,
  }) async {
    if (!automationEnabled) {
      return RssAutomationDisabled(
        item: item,
        policyId: policy.id,
        reason: 'RSS auto-download automation is disabled.',
      );
    }
    if (!policy.enabled) {
      return RssAutomationDisabled(
        item: item,
        policyId: policy.id,
        reason: 'RSS auto-download policy is disabled.',
      );
    }
    if (await history.hasAccepted(item.dedupeKey)) {
      return RssAutomationDeduplicated(
        item: item,
        policyId: policy.id,
        dedupeKey: item.dedupeKey.value,
        reason: 'RSS feed item was already accepted by policy history.',
      );
    }

    RssAutomationRejected? mostSpecificRejection;
    for (final RssAutoDownloadRule rule in rules) {
      final RssAutomationRejected? rejection = _ruleRejection(rule, item);
      if (rejection != null) {
        mostSpecificRejection = _moreSpecificRejection(
            current: mostSpecificRejection, candidate: rejection);
        continue;
      }
      final RssDownloadSource? source = _downloadSourceFor(item);
      if (source == null) {
        return RssAutomationRejected(
          item: item,
          kind: RssAutomationRejectionKind.unsupportedSource,
          reason: 'Feed item does not expose a magnet or torrent source.',
          ruleId: rule.id,
        );
      }
      return RssAutomationAccepted(
        item: item,
        candidate: RssDownloadCandidate(
          policyId: policy.id,
          ruleId: rule.id,
          item: item,
          source: source,
          metadata: <String, String>{
            'feedSourceId': item.sourceId.value,
            'feedItemId': item.id.value,
            'itemDedupeKey': item.dedupeKey.value,
          },
        ),
      );
    }

    if (mostSpecificRejection != null) {
      return mostSpecificRejection;
    }

    return RssAutomationRejected(
      item: item,
      kind: RssAutomationRejectionKind.includeNotMatched,
      reason: 'No enabled RSS auto-download rule matched the feed item.',
    );
  }

  RssAutomationRejected _moreSpecificRejection({
    required RssAutomationRejected? current,
    required RssAutomationRejected candidate,
  }) {
    if (current == null) {
      return candidate;
    }
    return _rejectionSpecificity(candidate.kind) >
            _rejectionSpecificity(current.kind)
        ? candidate
        : current;
  }

  int _rejectionSpecificity(RssAutomationRejectionKind kind) {
    return switch (kind) {
      RssAutomationRejectionKind.excluded => 5,
      RssAutomationRejectionKind.unsupportedSource => 4,
      RssAutomationRejectionKind.sourceOutOfScope => 3,
      RssAutomationRejectionKind.ruleDisabled => 2,
      RssAutomationRejectionKind.includeNotMatched => 1,
      RssAutomationRejectionKind.duplicate => 1,
      RssAutomationRejectionKind.policyDisabled => 1,
      RssAutomationRejectionKind.automationDisabled => 1,
    };
  }

  RssAutomationRejected? _ruleRejection(
      RssAutoDownloadRule rule, FeedItem item) {
    if (!rule.enabled) {
      return RssAutomationRejected(
        item: item,
        kind: RssAutomationRejectionKind.ruleDisabled,
        reason: 'RSS auto-download rule is disabled.',
        ruleId: rule.id,
      );
    }
    if (rule.scopedSources.isNotEmpty &&
        !rule.scopedSources.any(
            (FeedSourceId sourceId) => sourceId.value == item.sourceId.value)) {
      return RssAutomationRejected(
        item: item,
        kind: RssAutomationRejectionKind.sourceOutOfScope,
        reason: 'Feed item source is outside the RSS auto-download rule scope.',
        ruleId: rule.id,
      );
    }
    if (!_matchesExpression(rule.include, item)) {
      return RssAutomationRejected(
        item: item,
        kind: RssAutomationRejectionKind.includeNotMatched,
        reason: 'Feed item did not match the include matcher.',
        ruleId: rule.id,
      );
    }
    if (rule.exclude != null && _matchesExpression(rule.exclude!, item)) {
      return RssAutomationRejected(
        item: item,
        kind: RssAutomationRejectionKind.excluded,
        reason: 'Feed item matched the exclude matcher.',
        ruleId: rule.id,
      );
    }
    return null;
  }

  bool _matchesExpression(RssMatcherExpression expression, FeedItem item) {
    if (expression.predicates.isEmpty) {
      return true;
    }
    return switch (expression.logic) {
      RssMatcherLogic.all => expression.predicates.every(
          (RssMatcherPredicate predicate) => _matchesPredicate(predicate, item)),
      RssMatcherLogic.any => expression.predicates.any(
          (RssMatcherPredicate predicate) => _matchesPredicate(predicate, item)),
    };
  }

  bool _matchesPredicate(RssMatcherPredicate predicate, FeedItem item) {
    final String? candidate = _fieldValue(predicate, item);
    final bool matched = switch (predicate.operator) {
      RssMatcherOperator.contains => _contains(candidate, predicate),
      RssMatcherOperator.equals => _equals(candidate, predicate),
      RssMatcherOperator.regex => _regex(candidate, predicate),
      RssMatcherOperator.glob => _glob(candidate, predicate),
      RssMatcherOperator.greaterThanOrEqual =>
        _numeric(candidate, predicate, (num left, num right) => left >= right),
      RssMatcherOperator.lessThanOrEqual =>
        _numeric(candidate, predicate, (num left, num right) => left <= right),
      RssMatcherOperator.exists => candidate != null && candidate != '',
    };
    return predicate.negated ? !matched : matched;
  }

  String? _fieldValue(RssMatcherPredicate predicate, FeedItem item) {
    return switch (predicate.field) {
      RssMatcherField.title => item.title,
      RssMatcherField.releaseGroup => item.title,
      RssMatcherField.episode => item.title,
      RssMatcherField.season => item.title,
      RssMatcherField.resolution => item.title,
      RssMatcherField.sizeBytes => item.enclosure?.lengthBytes?.toString(),
      RssMatcherField.category => item.categories.join(' '),
      RssMatcherField.sourceId => item.sourceId.value,
      RssMatcherField.metadata => null,
    };
  }

  bool _contains(String? candidate, RssMatcherPredicate predicate) {
    if (candidate == null || predicate.value == null) {
      return false;
    }
    return _normalize(candidate, predicate)
        .contains(_normalize(predicate.value!, predicate));
  }

  bool _equals(String? candidate, RssMatcherPredicate predicate) {
    if (candidate == null || predicate.value == null) {
      return false;
    }
    return _normalize(candidate, predicate) ==
        _normalize(predicate.value!, predicate);
  }

  bool _regex(String? candidate, RssMatcherPredicate predicate) {
    if (candidate == null || predicate.value == null) {
      return false;
    }
    return RegExp(predicate.value!, caseSensitive: predicate.caseSensitive)
        .hasMatch(candidate);
  }

  bool _glob(String? candidate, RssMatcherPredicate predicate) {
    if (candidate == null || predicate.value == null) {
      return false;
    }
    final String escaped = RegExp.escape(predicate.value!)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    return RegExp('^$escaped\$', caseSensitive: predicate.caseSensitive)
        .hasMatch(candidate);
  }

  bool _numeric(
    String? candidate,
    RssMatcherPredicate predicate,
    bool Function(num left, num right) compare,
  ) {
    final num? left = num.tryParse(candidate ?? '');
    final num? right = num.tryParse(predicate.value ?? '');
    return left != null && right != null && compare(left, right);
  }

  String _normalize(String value, RssMatcherPredicate predicate) {
    return predicate.caseSensitive ? value : value.toLowerCase();
  }

  RssDownloadSource? _downloadSourceFor(FeedItem item) {
    final Uri? enclosureUri = item.enclosure?.uri;
    if (enclosureUri != null) {
      if (enclosureUri.scheme == 'magnet') {
        return MagnetRssDownloadSource(enclosureUri.toString());
      }
      if (_isTorrentUri(enclosureUri, item.enclosure?.mimeType)) {
        return TorrentRssDownloadSource(enclosureUri);
      }
    }
    final Uri? link = item.link;
    if (link == null) {
      return null;
    }
    if (link.scheme == 'magnet') {
      return MagnetRssDownloadSource(link.toString());
    }
    if (_isTorrentUri(link, null)) {
      return TorrentRssDownloadSource(link);
    }
    return null;
  }

  bool _isTorrentUri(Uri uri, String? mimeType) {
    return mimeType == 'application/x-bittorrent' ||
        uri.path.toLowerCase().endsWith('.torrent');
  }
}

RssAutomationHandoffOutcome rssAutomationHandoffFromCandidate(
    RssDownloadCandidate candidate) {
  return RssAutomationHandoffOutcome.ready(
    handoff: RssAutomationBtHandoffReadModel(
      policyId: candidate.policyId,
      ruleId: candidate.ruleId,
      feedItemId: candidate.item.id,
      feedSourceId: candidate.item.sourceId,
      itemDedupeKey: candidate.item.dedupeKey.value,
      candidateDedupeKey: candidate.dedupeKey,
      source: candidate.source,
    ),
  );
}

DateTime _defaultClock() => DateTime.now().toUtc();
