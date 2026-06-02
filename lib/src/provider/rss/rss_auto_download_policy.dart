import 'feed_contracts.dart';

final class RssAutoDownloadPolicyId {
  const RssAutoDownloadPolicyId(this.value) : assert(value != '', 'RSS auto-download policy id must not be empty.');

  final String value;
}

final class RssAutoDownloadRuleId {
  const RssAutoDownloadRuleId(this.value) : assert(value != '', 'RSS auto-download rule id must not be empty.');

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
  })  : assert(label != '', 'RSS auto-download policy label must not be empty.'),
        rules = List<RssAutoDownloadRule>.unmodifiable(rules);

  final RssAutoDownloadPolicyId id;
  final String label;
  final List<RssAutoDownloadRule> rules;
}

sealed class RssDownloadSource {
  const RssDownloadSource();
}

final class MagnetRssDownloadSource extends RssDownloadSource {
  const MagnetRssDownloadSource(this.uri) : assert(uri != '', 'Magnet URI must not be empty.');

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
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map<String, String>.unmodifiable(metadata);

  final RssAutoDownloadPolicyId policyId;
  final RssAutoDownloadRuleId ruleId;
  final FeedItem item;
  final RssDownloadSource source;
  final Map<String, String> metadata;
}

enum RssAutomationRejectionKind {
  ruleDisabled,
  sourceOutOfScope,
  includeNotMatched,
  excluded,
  duplicate,
  unsupportedSource,
}

sealed class RssAutomationDecision {
  const RssAutomationDecision({required this.item});

  final FeedItem item;
}

final class RssAutomationAccepted extends RssAutomationDecision {
  const RssAutomationAccepted({required super.item, required this.candidate});

  final RssDownloadCandidate candidate;
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
