import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('online rule store persists manifests rule sets issues and outcomes',
      () async {
    final DeterministicOnlineRuleRuntimeStore store =
        DeterministicOnlineRuleRuntimeStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);

    await store.storeManifest(StoredOnlineRuleManifestRecord(
      sourceId: 'online-source',
      displayName: 'Online Source',
      version: '1.0.0',
      updateUri: Uri.parse('https://rules.example.test/manifest.json'),
      checksum: 'sha256:abc',
      updateInterval: const Duration(hours: 12),
      validationState: StoredOnlineRuleValidationState.valid,
      createdAt: observedAt,
      updatedAt: observedAt,
    ));
    await store.recordManifestVersion(StoredOnlineRuleManifestVersionRecord(
      sourceId: 'online-source',
      version: '1.0.0',
      checksum: 'sha256:abc',
      recordedAt: observedAt,
    ));
    await store.storeRuleSets(
      sourceId: 'online-source',
      ruleSets: <StoredOnlineRuleSetRecord>[
        StoredOnlineRuleSetRecord(
          id: 'search-rules',
          sourceId: 'online-source',
          target: StoredOnlineRuleTarget.search,
          operations: const <StoredOnlineExtractionOperationRecord>[
            StoredOnlineExtractionOperationRecord(
              id: 'title',
              kind: StoredOnlineExtractionKind.regex,
              expression: 'title="([^"]+)"',
              outputKey: 'title',
              required: true,
            ),
          ],
        ),
      ],
    );
    await store.recordValidationIssue(StoredOnlineRuleValidationIssueRecord(
      id: 'issue-1',
      sourceId: 'online-source',
      message: 'Optional selector missing.',
      recordedAt: observedAt,
    ));
    await store
        .recordEvaluationSnapshot(StoredOnlineRuleEvaluationSnapshotRecord(
      id: 'eval-1',
      sourceId: 'online-source',
      target: StoredOnlineRuleTarget.search,
      pageUri: Uri.parse('https://source.example.test/search'),
      state: StoredOnlineRuleEvaluationState.succeeded,
      values: const <String, String>{'title': 'Result'},
      evaluatedAt: observedAt,
    ));
    await store.recordPageRetrievalOutcome(
      StoredOnlineRulePageRetrievalOutcomeRecord(
        id: 'retrieval-1',
        sourceId: 'online-source',
        pageUri: Uri.parse('https://source.example.test/search'),
        state: StoredOnlineRuleRetrievalState.retrieved,
        providerCacheKey: 'online-source::search',
        recordedAt: observedAt,
      ),
    );
    await store
        .recordUnsupportedOperation(StoredUnsupportedOnlineOperationRecord(
      id: 'unsupported-1',
      sourceId: 'online-source',
      kind: StoredUnsupportedOnlineOperationKind.wasm,
      reason: 'WASM is not supported in Step 27.',
      recordedAt: observedAt,
    ));
    await store.storeCapability(StoredOnlineRuleSourceCapabilityRecord(
      sourceId: 'online-source',
      state: StoredOnlineRuleCapabilityState.supported,
      updatedAt: observedAt,
    ));

    expect((await store.manifestBySource('online-source'))?.version, '1.0.0');
    expect((await store.versionsForSource('online-source')).single.checksum,
        'sha256:abc');
    expect((await store.ruleSetsForSource('online-source')).single.target,
        StoredOnlineRuleTarget.search);
    expect(
        (await store.validationIssuesForSource('online-source')).single.message,
        'Optional selector missing.');
    expect(
        (await store.evaluationsForSource('online-source'))
            .single
            .values['title'],
        'Result');
    expect((await store.latestRetrievalOutcome('online-source'))?.state,
        StoredOnlineRuleRetrievalState.retrieved);
    expect(
        (await store.unsupportedOperationsForSource('online-source'))
            .single
            .kind,
        StoredUnsupportedOnlineOperationKind.wasm);
    expect((await store.capabilityForSource('online-source'))?.state,
        StoredOnlineRuleCapabilityState.supported);
  });

  test('deterministic runtime validates rejects and normalizes outputs',
      () async {
    const DeterministicOnlineRuleRuntime runtime =
        DeterministicOnlineRuleRuntime();

    final OnlineRuleEvaluationOutcome evaluated = await runtime.evaluateTyped(
      OnlineRuleEvaluationRequest(
        manifest: _manifest(),
        target: OnlineRuleTarget.search,
        pageUri: Uri.parse('https://source.example.test/search'),
        document: '<article class="result">'
            '<h2 title="Runtime Result">Runtime Result</h2>'
            '<a class="detail-link" href="https://source.example.test/detail">'
            'Detail</a>'
            '</article>',
      ),
    );
    final OnlineRuleSearchOutput output =
        runtime.normalize(evaluated.result!) as OnlineRuleSearchOutput;

    expect(evaluated.isSuccess, isTrue);
    expect(evaluated.result?.values['title'], 'Runtime Result');
    expect(output.results.single.detailUri.host, 'source.example.test');

    final OnlineRuleValidationResult unsupported =
        await runtime.validateManifest(
      OnlineRuleManifest(
        sourceId: const OnlineRuleSourceId('bad-source'),
        displayName: 'Bad Source',
        version: const OnlineRuleManifestVersion('1'),
        updateUri: Uri.parse('https://rules.example.test/bad.json'),
        checksum: 'sha256:bad',
        updateInterval: const Duration(hours: 1),
        ruleSets: <OnlineRuleSet>[
          OnlineRuleSet(
            target: OnlineRuleTarget.search,
            operations: const <OnlineExtractionOperation>[
              OnlineExtractionOperation(
                id: 'wasm-op',
                kind: OnlineExtractionKind.regex,
                expression: 'wasm:extract',
                outputKey: 'title',
                required: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(unsupported.isValid, isFalse);
    expect(unsupported.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.wasm);

    final OnlineRuleEvaluationOutcome disabled =
        await const DeterministicOnlineRuleRuntime(enabled: false)
            .evaluateTyped(
      OnlineRuleEvaluationRequest(
        manifest: _manifest(),
        target: OnlineRuleTarget.search,
        pageUri: Uri.parse('https://source.example.test/search'),
        document: 'title="Runtime Result"',
      ),
    );
    expect(disabled.failure?.kind, OnlineRuleFailureKind.manifestDisabled);
  });

  test('deterministic runtime rejects unsafe regex before evaluation',
      () async {
    const DeterministicOnlineRuleRuntime runtime =
        DeterministicOnlineRuleRuntime();

    final OnlineRuleValidationResult nested =
        await runtime.validateManifest(_unsafeRegexManifest('(.*)+'));
    final OnlineRuleValidationResult nestedQuantifier =
        await runtime.validateManifest(_unsafeRegexManifest('(a+)+'));
    final OnlineRuleValidationResult repeated = await runtime
        .validateManifest(_unsafeRegexManifest('<h1>(.*)</h1>.*<a>(.*)</a>'));
    final OnlineRuleEvaluationOutcome evaluated = await runtime.evaluateTyped(
      OnlineRuleEvaluationRequest(
        manifest: _unsafeRegexManifest('(.*)+'),
        target: OnlineRuleTarget.search,
        pageUri: Uri.parse('https://source.example.test/search'),
        document: '<h1>Unsafe</h1>',
      ),
    );

    expect(nested.isValid, isFalse);
    expect(nested.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.unboundedRegex);
    expect(nestedQuantifier.isValid, isFalse);
    expect(nestedQuantifier.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.unboundedRegex);
    expect(repeated.isValid, isFalse);
    expect(repeated.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.unboundedRegex);
    expect(evaluated.failure?.kind, OnlineRuleFailureKind.manifestInvalid);
  });

  test('deterministic runtime evaluates xpath subset and selector validation',
      () async {
    const DeterministicOnlineRuleRuntime runtime =
        DeterministicOnlineRuleRuntime();

    final OnlineRuleEvaluationOutcome evaluated = await runtime.evaluateTyped(
      OnlineRuleEvaluationRequest(
        manifest: _xpathManifest(),
        target: OnlineRuleTarget.detail,
        pageUri: Uri.parse('https://source.example.test/detail'),
        document: '<html><body><section id="detail">'
            '<h1>XPath Title</h1>'
            '<a href="https://source.example.test/detail">Detail</a>'
            '</section></body></html>',
      ),
    );
    final OnlineRuleDetailOutput output =
        runtime.normalize(evaluated.result!) as OnlineRuleDetailOutput;

    expect(evaluated.isSuccess, isTrue);
    expect(output.detail.title, 'XPath Title');
    expect(output.detail.pageUri.host, 'source.example.test');

    final OnlineRuleValidationResult unsupported =
        await runtime.validateManifest(_unsupportedSelectorManifest());
    expect(unsupported.isValid, isFalse);
    expect(unsupported.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.unsupportedSelector);
  });

  test('gateway network descriptors and invalidation events stay declarative',
      () async {
    final OnlineRuleGatewayRequestDescriptor descriptor =
        OnlineRuleGatewayRequestDescriptor(
      sourceId: const OnlineRuleSourceId('online-source'),
      providerId: const ProviderId('online-source'),
      cacheKey: 'online-source::page',
      pageUri: Uri.parse('https://source.example.test/page'),
      cachePolicy: ProviderCachePolicy.networkFirst,
      ratePolicy: const ProviderRatePolicy(
          maxRequests: 6, window: Duration(minutes: 1)),
      retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
    );
    final OnlineRuleNetworkPolicyHandoff handoff =
        OnlineRuleNetworkPolicyHandoff(
      sourceId: const OnlineRuleSourceId('online-source'),
      providerScope: 'online-source',
      uri: Uri.https('source.example.test', '/page'),
      failureKind: OnlineRuleNetworkFailureKind.privateNetworkAddress,
      reason: 'Private address blocked.',
    );
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(6).toList();
    final DateTime observedAt = DateTime.utc(2026, 6, 8, 12);

    bus.publish(OnlineRuleManifestChanged(
        occurredAt: observedAt,
        sourceId: 'online-source',
        changeKind: OnlineRuleManifestChangeKind.registered,
        version: '1.0.0'));
    bus.publish(OnlineRuleValidationStateChanged(
        occurredAt: observedAt, sourceId: 'online-source', valid: true));
    bus.publish(OnlineRuleTargetEvaluated(
        occurredAt: observedAt,
        sourceId: 'online-source',
        target: OnlineRuleTarget.search.name,
        state: 'succeeded'));
    bus.publish(OnlineRulePageRetrievalOutcomeRecorded(
        occurredAt: observedAt,
        sourceId: 'online-source',
        pageUri: Uri.parse('https://source.example.test/page'),
        state: 'retrieved'));
    bus.publish(OnlineRuleUnsupportedOperationRecorded(
        occurredAt: observedAt,
        sourceId: 'online-source',
        kind: UnsupportedOnlineOperationKind.wasm.name,
        reason: 'WASM disabled.'));
    bus.publish(OnlineRuleCapabilityChanged(
        occurredAt: observedAt, sourceId: 'online-source', supported: true));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(descriptor.registration.providerId.value, 'online-source');
    expect(descriptor.requestKey.cacheKey, 'online-source::page');
    expect(handoff.failureKind,
        OnlineRuleNetworkFailureKind.privateNetworkAddress);
    expect(delivered.whereType<OnlineRuleManifestChanged>().length, 1);
    expect(delivered.whereType<OnlineRuleValidationStateChanged>().length, 1);
    expect(delivered.whereType<OnlineRuleTargetEvaluated>().length, 1);
    expect(delivered.whereType<OnlineRulePageRetrievalOutcomeRecorded>().length,
        1);
    expect(delivered.whereType<OnlineRuleUnsupportedOperationRecorded>().length,
        1);
    expect(delivered.whereType<OnlineRuleCapabilityChanged>().length, 1);
  });
}

OnlineRuleManifest _manifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('online-source'),
    displayName: 'Online Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/manifest.json'),
    checksum: 'sha256:abc',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'title',
            kind: OnlineExtractionKind.regex,
            expression: 'title="([^"]+)"',
            outputKey: 'title',
            required: true,
          ),
          OnlineExtractionOperation(
            id: 'detailUri',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.detail-link',
            outputKey: 'detailUri',
            attribute: 'href',
            required: true,
          ),
        ],
      ),
    ],
  );
}

OnlineRuleManifest _xpathManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('xpath-source'),
    displayName: 'XPath Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/xpath.json'),
    checksum: 'sha256:xpath',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.detail,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'title',
            kind: OnlineExtractionKind.xpath1,
            expression: '//section[@id="detail"]/h1',
            outputKey: 'title',
            required: true,
          ),
          OnlineExtractionOperation(
            id: 'pageUri',
            kind: OnlineExtractionKind.xpath1,
            expression: '//section[@id="detail"]/a',
            outputKey: 'pageUri',
            attribute: 'href',
            required: true,
          ),
        ],
      ),
    ],
  );
}

OnlineRuleManifest _unsupportedSelectorManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('unsupported-selector'),
    displayName: 'Unsupported Selector Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/unsupported.json'),
    checksum: 'sha256:unsupported',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'title',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.result > .title',
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  );
}

OnlineRuleManifest _unsafeRegexManifest(String expression) {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('unsafe-regex-source'),
    displayName: 'Unsafe Regex Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/unsafe-regex.json'),
    checksum: 'sha256:unsafe-regex',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'unsafe-title',
            kind: OnlineExtractionKind.regex,
            expression: expression,
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  );
}
