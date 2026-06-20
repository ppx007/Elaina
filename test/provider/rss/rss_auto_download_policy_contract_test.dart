import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RSS auto-download store persists policies history and enqueue outcomes',
      () async {
    final DeterministicRssAutoDownloadPolicyStore store =
        DeterministicRssAutoDownloadPolicyStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);

    await store.storePolicy(StoredRssAutoDownloadPolicyRecord(
      id: 'policy-1',
      label: 'Anime policy',
      enabled: true,
      createdAt: observedAt,
      updatedAt: observedAt,
    ));
    await store.storeFeedActivation(
      StoredRssAutoDownloadFeedActivationRecord(
        policyId: 'policy-1',
        sourceId: 'anime-feed',
        enabled: true,
        updatedAt: observedAt,
      ),
    );
    await store.storeRules(
      policyId: 'policy-1',
      rules: <StoredRssAutoDownloadRuleRecord>[
        StoredRssAutoDownloadRuleRecord(
          id: 'rule-1',
          policyId: 'policy-1',
          label: 'Episode rule',
          priority: 1,
          enabled: true,
          includeMatcher: StoredRssAutoDownloadMatcherRecord(
            ruleId: 'rule-1',
            logic: StoredRssAutoDownloadMatcherLogic.all,
            predicates: const <StoredRssAutoDownloadMatcherPredicateRecord>[
              StoredRssAutoDownloadMatcherPredicateRecord(
                field: StoredRssAutoDownloadMatcherField.title,
                operator: StoredRssAutoDownloadMatcherOperator.contains,
                value: 'Episode',
              ),
            ],
          ),
        ),
      ],
    );
    await store.recordEvaluation(StoredRssAutoDownloadEvaluationRecord(
      id: 'eval-1',
      policyId: 'policy-1',
      ruleId: 'rule-1',
      itemId: 'item-1',
      sourceId: 'anime-feed',
      itemDedupeKey: 'item-dedupe-1',
      evaluationKind: StoredRssAutoDownloadEvaluationKind.accepted,
      candidateId: 'candidate-1',
      evaluatedAt: observedAt,
    ));
    await store.storeAcceptedCandidate(
      StoredRssAutoDownloadAcceptedCandidateRecord(
        id: 'candidate-1',
        policyId: 'policy-1',
        ruleId: 'rule-1',
        itemId: 'item-1',
        sourceId: 'anime-feed',
        itemDedupeKey: 'item-dedupe-1',
        candidateDedupeKey: 'policy-1::item-dedupe-1',
        sourceKind: StoredRssAutoDownloadSourceKind.magnet,
        sourceUri: 'magnet:?xt=urn:btih:episode1',
        acceptedAt: observedAt,
      ),
    );
    await store.recordDedupeKey(StoredRssAutoDownloadDedupeRecord(
      policyId: 'policy-1',
      candidateDedupeKey: 'policy-1::item-dedupe-1',
      itemDedupeKey: 'item-dedupe-1',
      candidateId: 'candidate-1',
      recordedAt: observedAt,
    ));
    await store.recordEnqueueOutcome(
      StoredRssAutoDownloadEnqueueOutcomeRecord(
        id: 'enqueue-1',
        candidateId: 'candidate-1',
        policyId: 'policy-1',
        state: StoredRssAutoDownloadEnqueueState.pending,
        message: 'Pending handoff.',
        recordedAt: observedAt,
      ),
    );

    expect((await store.policyById('policy-1'))?.label, 'Anime policy');
    expect((await store.activationsForPolicy('policy-1')).single.sourceId,
        'anime-feed');
    expect(
        (await store.rulesForPolicy('policy-1')).single.label, 'Episode rule');
    expect(
        (await store.evaluationsForItem(
                policyId: 'policy-1', itemDedupeKey: 'item-dedupe-1'))
            .single
            .evaluationKind,
        StoredRssAutoDownloadEvaluationKind.accepted);
    expect(
        (await store.acceptedCandidatesForPolicy('policy-1'))
            .single
            .candidateDedupeKey,
        'policy-1::item-dedupe-1');
    expect(
        await store.hasCandidateDedupeKey(
            policyId: 'policy-1',
            candidateDedupeKey: 'policy-1::item-dedupe-1'),
        isTrue);
    expect((await store.latestEnqueueOutcome('candidate-1'))?.state,
        StoredRssAutoDownloadEnqueueState.pending);
  });

  test(
      'policy evaluator accepts torrent candidates and builds BT handoff models',
      () async {
    final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
        DeterministicRssAutoDownloadPolicyEvaluator(
            clock: () => DateTime.utc(2026, 6, 7, 12));
    final _MemoryRssAutomationHistoryStore history =
        _MemoryRssAutomationHistoryStore();

    final List<RssAutomationDecision> decisions = await evaluator.evaluate(
      policy: _policy(),
      items: <FeedItem>[_feedItem()],
      history: history,
    );

    final RssAutomationAccepted accepted =
        decisions.single as RssAutomationAccepted;
    final RssAutomationHandoffOutcome handoff =
        rssAutomationHandoffFromCandidate(accepted.candidate);

    expect(accepted.candidate.policyId.value, 'policy-1');
    expect(accepted.candidate.ruleId.value, 'rule-include');
    expect(accepted.candidate.source, isA<TorrentRssDownloadSource>());
    expect(handoff.isSuccess, isTrue);
    expect(handoff.handoff?.feedItemId.value, 'item-1');
    expect(handoff.handoff?.candidateDedupeKey, 'policy-1::item-1');
    expect(history.entries.single.decision, isA<RssAutomationAccepted>());
  });

  test('policy evaluator applies exclude precedence and durable dedupe',
      () async {
    final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
        DeterministicRssAutoDownloadPolicyEvaluator(
            clock: () => DateTime.utc(2026, 6, 7, 12));
    final _MemoryRssAutomationHistoryStore history =
        _MemoryRssAutomationHistoryStore();

    final List<RssAutomationDecision> excluded = await evaluator.evaluate(
      policy: _policy(excludeBatch: true),
      items: <FeedItem>[_feedItem(title: 'Episode 1 Batch')],
      history: history,
    );
    final List<RssAutomationDecision> accepted = await evaluator.evaluate(
      policy: _policy(),
      items: <FeedItem>[_feedItem(id: 'item-2', dedupeKey: 'item-2')],
      history: history,
    );
    final List<RssAutomationDecision> deduped = await evaluator.evaluate(
      policy: _policy(),
      items: <FeedItem>[_feedItem(id: 'item-2', dedupeKey: 'item-2')],
      history: history,
    );

    expect((excluded.single as RssAutomationRejected).kind,
        RssAutomationRejectionKind.excluded);
    expect(accepted.single, isA<RssAutomationAccepted>());
    expect(deduped.single, isA<RssAutomationDeduplicated>());
  });

  test('policy evaluator reports disabled automation without BT handoff',
      () async {
    final DeterministicRssAutoDownloadPolicyEvaluator evaluator =
        const DeterministicRssAutoDownloadPolicyEvaluator(
            automationEnabled: false);

    final List<RssAutomationDecision> decisions = await evaluator.evaluate(
      policy: _policy(),
      items: <FeedItem>[_feedItem()],
      history: _MemoryRssAutomationHistoryStore(),
    );

    expect(decisions.single, isA<RssAutomationDisabled>());
  });

  test('RSS automation invalidation events are published explicitly', () async {
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DateTime observedAt = DateTime.utc(2026, 6, 7, 12);
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(6).toList();

    bus.publish(RssAutoDownloadPolicyChanged(
      occurredAt: observedAt,
      policyId: 'policy-1',
      changeKind: RssAutoDownloadPolicyChangeKind.registered,
    ));
    bus.publish(RssAutoDownloadFeedItemEvaluated(
      occurredAt: observedAt,
      policyId: 'policy-1',
      ruleId: 'rule-1',
      feedItemId: 'item-1',
      sourceId: 'anime-feed',
      outcomeKind: 'accepted',
    ));
    bus.publish(RssAutoDownloadCandidateAccepted(
      occurredAt: observedAt,
      policyId: 'policy-1',
      ruleId: 'rule-1',
      candidateDedupeKey: 'policy-1::item-1',
      feedItemId: 'item-1',
      sourceId: 'anime-feed',
    ));
    bus.publish(RssAutoDownloadCandidateRejected(
      occurredAt: observedAt,
      policyId: 'policy-1',
      feedItemId: 'item-2',
      sourceId: 'anime-feed',
      reason: 'Excluded.',
    ));
    bus.publish(RssAutoDownloadDedupeStateChanged(
      occurredAt: observedAt,
      policyId: 'policy-1',
      candidateDedupeKey: 'policy-1::item-1',
      candidateId: 'candidate-1',
    ));
    bus.publish(RssAutoDownloadEnqueueOutcomeRecorded(
      occurredAt: observedAt,
      policyId: 'policy-1',
      candidateId: 'candidate-1',
      state: 'pending',
    ));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(delivered.whereType<RssAutoDownloadPolicyChanged>().length, 1);
    expect(delivered.whereType<RssAutoDownloadFeedItemEvaluated>().length, 1);
    expect(delivered.whereType<RssAutoDownloadCandidateAccepted>().length, 1);
    expect(delivered.whereType<RssAutoDownloadCandidateRejected>().length, 1);
    expect(delivered.whereType<RssAutoDownloadDedupeStateChanged>().length, 1);
    expect(
        delivered.whereType<RssAutoDownloadEnqueueOutcomeRecorded>().length, 1);
  });
}

RssAutoDownloadPolicy _policy({bool excludeBatch = false}) {
  return RssAutoDownloadPolicy(
    id: const RssAutoDownloadPolicyId('policy-1'),
    label: 'Policy 1',
    rules: <RssAutoDownloadRule>[
      RssAutoDownloadRule(
        id: const RssAutoDownloadRuleId('rule-include'),
        label: 'Include episodes',
        priority: 1,
        include: RssMatcherExpression(
          logic: RssMatcherLogic.all,
          predicates: const <RssMatcherPredicate>[
            RssMatcherPredicate(
              field: RssMatcherField.title,
              operator: RssMatcherOperator.contains,
              value: 'Episode',
            ),
            RssMatcherPredicate(
              field: RssMatcherField.category,
              operator: RssMatcherOperator.contains,
              value: 'anime',
            ),
          ],
        ),
        exclude: excludeBatch
            ? RssMatcherExpression(
                logic: RssMatcherLogic.any,
                predicates: const <RssMatcherPredicate>[
                  RssMatcherPredicate(
                    field: RssMatcherField.title,
                    operator: RssMatcherOperator.contains,
                    value: 'Batch',
                  ),
                ],
              )
            : null,
        scopedSources: const <FeedSourceId>[FeedSourceId('anime-feed')],
      ),
    ],
  );
}

FeedItem _feedItem(
    {String id = 'item-1',
    String dedupeKey = 'item-1',
    String title = 'Episode 1'}) {
  return FeedItem(
    id: FeedItemId(id),
    sourceId: const FeedSourceId('anime-feed'),
    dedupeKey: FeedDedupeKey(dedupeKey),
    title: title,
    categories: const <String>['anime'],
    enclosure: FeedEnclosure(
      uri: Uri.parse('https://example.test/$id.torrent'),
      mimeType: 'application/x-bittorrent',
      lengthBytes: 1024,
    ),
  );
}

final class _MemoryRssAutomationHistoryStore
    implements RssAutomationHistoryStore {
  final List<RssAutomationHistoryEntry> entries = <RssAutomationHistoryEntry>[];
  final Set<String> _acceptedKeys = <String>{};

  @override
  Future<bool> hasAccepted(FeedDedupeKey itemKey) {
    return Future<bool>.value(_acceptedKeys.contains(itemKey.value));
  }

  @override
  Future<void> record(RssAutomationHistoryEntry entry) {
    entries.add(entry);
    if (entry.decision is RssAutomationAccepted) {
      _acceptedKeys.add(entry.itemKey.value);
    }
    return Future<void>.value();
  }
}
