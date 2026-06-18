import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnlineRuleSourceRuntime', () {
    late DeterministicOnlineRuleRuntimeStore store;
    late StreamCacheInvalidationBus bus;

    setUp(() {
      store = DeterministicOnlineRuleRuntimeStore(
        seedManifests: <StoredOnlineRuleManifestRecord>[
          StoredOnlineRuleManifestRecord(
            sourceId: 'source-1',
            displayName: 'Test Source',
            version: '1.0.0',
            updateUri: Uri.parse('https://rules.example.test/manifest.json'),
            checksum: 'sha256:abc',
            updateInterval: const Duration(hours: 12),
            validationState: StoredOnlineRuleValidationState.valid,
            createdAt: DateTime.utc(2026, 6, 16),
            updatedAt: DateTime.utc(2026, 6, 16),
          ),
        ],
      );
      bus = StreamCacheInvalidationBus();
    });

    tearDown(() async {
      await bus.close();
    });

    OnlineRuleSourceRuntime _runtime() {
      return OnlineRuleSourceRuntimeBootstrap(
        store: store,
        runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
          'source-1': const DeterministicOnlineRuleRuntime(),
        },
        capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
          'source-1': _supportedCapabilities(),
        },
        bus: bus,
      ).createRuntime();
    }

    test('1 initial snapshot returns projection from seeded store', () async {
      final result = await _runtime().snapshot('source-1');
      expect(result.isSuccess, isTrue);
      expect(result.value?.sourceId, 'source-1');
      expect(result.value?.manifestDisplayName, 'Test Source');
      expect(
          result.value?.validationState, StoredOnlineRuleValidationState.valid);
      expect(result.value?.restart.manifestValidationState,
          StoredOnlineRuleValidationState.valid);
      expect(result.value?.restart.latestEvaluationState, isNull);
    });

    test('2 validate succeeds for valid manifest', () async {
      final runtime = _runtime();
      final result = await runtime.validate('source-1', _testManifest());
      expect(result.isSuccess, isTrue);
      expect(
          result.value?.validationState, StoredOnlineRuleValidationState.valid);
      final stored = await store.manifestBySource('source-1');
      expect(stored?.validationState, StoredOnlineRuleValidationState.valid);
    });

    test('3 validate records issues for wasm operations', () async {
      final runtime = _runtime();
      final result = await runtime.validate('source-1', _wasmManifest());
      expect(result.isSuccess, isTrue);
      expect(result.value?.validationState,
          StoredOnlineRuleValidationState.invalid);
      final issues = await store.validationIssuesForSource('source-1');
      expect(issues, isNotEmpty);
      expect(issues.first.unsupportedKind,
          StoredUnsupportedOnlineOperationKind.wasm);
      final unsupported =
          await store.unsupportedOperationsForSource('source-1');
      expect(unsupported, isNotEmpty);
    });

    test('4 evaluate succeeds and persists to store', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _testManifest());
      final result = await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: _searchDocument('Test Title'),
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.value?.latestEvaluationState,
          StoredOnlineRuleEvaluationState.succeeded);
      expect(result.value?.latestEvaluationOutcome?.isSuccess, isTrue);
      final snapshots = await store.evaluationsForSource('source-1');
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.state, StoredOnlineRuleEvaluationState.succeeded);
    });

    test('5 evaluate fails for disabled deterministic runtime', () async {
      final runtime = OnlineRuleSourceRuntimeBootstrap(
        store: store,
        runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
          'source-1': const DeterministicOnlineRuleRuntime(enabled: false),
        },
        capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
          'source-1': _supportedCapabilities(),
        },
        bus: bus,
      ).createRuntime();
      await runtime.validate('source-1', _testManifest());
      final result = await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: 'title="Test"',
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.manifestDisabled);
    });

    test('6 evaluate fails for missing target', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _testManifest());
      final result = await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.episode,
          pageUri: Uri.parse('https://source.example.test/ep'),
          document: 'episode data',
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.evaluationFailed);
    });

    test('7 disable sets validation state to disabled', () async {
      final runtime = _runtime();
      final result = await runtime.disable('source-1');
      expect(result.isSuccess, isTrue);
      expect(result.value?.validationState,
          StoredOnlineRuleValidationState.disabled);
      final stored = await store.manifestBySource('source-1');
      expect(stored?.validationState, StoredOnlineRuleValidationState.disabled);
    });

    test('8 reenable restores disabled to valid', () async {
      final runtime = _runtime();
      await runtime.disable('source-1');
      final result = await runtime.reenable('source-1');
      expect(result.isSuccess, isTrue);
      expect(
          result.value?.validationState, StoredOnlineRuleValidationState.valid);
      final stored = await store.manifestBySource('source-1');
      expect(stored?.validationState, StoredOnlineRuleValidationState.valid);
    });

    test('9 reenable with invalid manifest returns manifestInvalid', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _wasmManifest());
      final result = await runtime.reenable('source-1');
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.manifestInvalid);
    });

    test('10 reenable with already-valid manifest returns success idempotent',
        () async {
      final runtime = _runtime();
      final result = await runtime.reenable('source-1');
      expect(result.isSuccess, isTrue);
      expect(
          result.value?.validationState, StoredOnlineRuleValidationState.valid);
    });

    test('11 disable with missing manifest returns manifestNotFound', () async {
      final runtime = OnlineRuleSourceRuntimeBootstrap(
        store: store,
        runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
          'source-1': const DeterministicOnlineRuleRuntime(),
          'source-2': const DeterministicOnlineRuleRuntime(),
        },
        capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
          'source-1': _supportedCapabilities(),
          'source-2': _supportedCapabilities(),
        },
        bus: bus,
      ).createRuntime();
      final result = await runtime.disable('source-2');
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.manifestNotFound);
    });

    test('12 unsupported capability returns capabilityUnsupported', () async {
      final runtime = OnlineRuleSourceRuntimeBootstrap(
        store: store,
        runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
          'source-1': const DeterministicOnlineRuleRuntime(),
        },
        capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
          'source-1': _unsupportedCapabilities(),
        },
        bus: bus,
      ).createRuntime();
      final result = await runtime.snapshot('source-1');
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.capabilityUnsupported);
    });

    test(
        '13 evaluate with no suppliedDocumentEvaluation returns capabilityUnsupported',
        () async {
      final runtime = OnlineRuleSourceRuntimeBootstrap(
        store: store,
        runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
          'source-1': const DeterministicOnlineRuleRuntime(),
        },
        capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
          'source-1': _noEvaluationCapabilities(),
        },
        bus: bus,
      ).createRuntime();
      final result = await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: 'title="Test"',
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.capabilityUnsupported);
    });

    test('14 unavailable runtime rejects all 5 ops', () async {
      final runtime =
          OnlineRuleSourceRuntime.unavailable(reason: 'Platform unsupported');
      expect((await runtime.snapshot('source-1')).failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.unavailable);
      expect(
          (await runtime.validate('source-1', _testManifest())).failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.unavailable);
      expect(
          (await runtime.evaluate(
            'source-1',
            OnlineRuleEvaluationRequest(
              manifest: _testManifest(),
              target: OnlineRuleTarget.search,
              pageUri: Uri.parse('https://x.test'),
              document: 'x',
            ),
          ))
              .failure
              ?.kind,
          OnlineRuleSourceRuntimeFailureKind.unavailable);
      expect((await runtime.disable('source-1')).failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.unavailable);
      expect((await runtime.reenable('source-1')).failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.unavailable);
    });

    test('15 disposed runtime rejects snapshot', () async {
      final runtime = _runtime();
      runtime.dispose();
      final result = await runtime.snapshot('source-1');
      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind, OnlineRuleSourceRuntimeFailureKind.disposed);
    });

    test('16 invalidation events published on evaluate', () async {
      final runtime = _runtime();
      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);
      await runtime.validate('source-1', _testManifest());
      await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: _searchDocument('Test Title'),
        ),
      );
      expect(events.whereType<OnlineRuleTargetEvaluated>(), isNotEmpty);
      final evalEvent = events.whereType<OnlineRuleTargetEvaluated>().first;
      expect(evalEvent.sourceId, 'source-1');
      expect(evalEvent.target, 'search');
      expect(evalEvent.state, 'succeeded');
      await subscription.cancel();
    });

    test('17 invalidation events published on validate', () async {
      final runtime = _runtime();
      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);
      await runtime.validate('source-1', _testManifest());
      expect(events.whereType<OnlineRuleManifestChanged>(), isNotEmpty);
      expect(events.whereType<OnlineRuleValidationStateChanged>(), isNotEmpty);
      final manifestEvent = events.whereType<OnlineRuleManifestChanged>().first;
      expect(manifestEvent.sourceId, 'source-1');
      expect(manifestEvent.changeKind, OnlineRuleManifestChangeKind.registered);
      final validEvent =
          events.whereType<OnlineRuleValidationStateChanged>().first;
      expect(validEvent.sourceId, 'source-1');
      expect(validEvent.valid, isTrue);
      await subscription.cancel();
    });

    test('18 restart projection replays stored evaluation state', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _testManifest());
      await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: _searchDocument('Test Title'),
        ),
      );
      final snapshot = await runtime.snapshot('source-1');
      final restart = snapshot.value!.restart;
      expect(restart.sourceId, 'source-1');
      expect(restart.manifestValidationState,
          StoredOnlineRuleValidationState.valid);
      expect(restart.latestEvaluationTarget, StoredOnlineRuleTarget.search);
      expect(restart.latestEvaluationState,
          StoredOnlineRuleEvaluationState.succeeded);
    });

    test('19 normalize produces typed output on evaluate', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _testManifest());
      await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _testManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: _searchDocument('Test Title'),
        ),
      );
      final snapshot = await runtime.snapshot('source-1');
      expect(snapshot.value?.latestNormalizedOutput,
          isA<OnlineRuleSearchOutput>());
      final output =
          snapshot.value!.latestNormalizedOutput! as OnlineRuleSearchOutput;
      expect(output.results.single.title, 'Test Title');
    });

    test('20 evaluate maps normalization failures to typed failures', () async {
      final runtime = _runtime();
      await runtime.validate('source-1', _normalizationFailureManifest());
      final result = await runtime.evaluate(
        'source-1',
        OnlineRuleEvaluationRequest(
          manifest: _normalizationFailureManifest(),
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document:
              '<article class="result"><h2>Missing Detail URI</h2></article>',
        ),
      );
      final snapshots = await store.evaluationsForSource('source-1');

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          OnlineRuleSourceRuntimeFailureKind.evaluationFailed);
      expect(snapshots.last.state, StoredOnlineRuleEvaluationState.failed);
      expect(snapshots.last.values['title'], 'Missing Detail URI');
      expect(snapshots.last.reason, contains('detailUri'));
    });

    test('21 disable publishes manifest changed event', () async {
      final runtime = _runtime();
      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);
      await runtime.disable('source-1');
      expect(events.whereType<OnlineRuleManifestChanged>(), isNotEmpty);
      final disableEvent = events.whereType<OnlineRuleManifestChanged>().first;
      expect(disableEvent.sourceId, 'source-1');
      expect(disableEvent.changeKind, OnlineRuleManifestChangeKind.disabled);
      await subscription.cancel();
    });
  });
}

OnlineRuleCapabilityMatrix _supportedCapabilities() {
  return const OnlineRuleCapabilityMatrix(
    capabilities: <OnlineRuleCapability, OnlineRuleCapabilityStatus>{
      OnlineRuleCapability.manifestValidation:
          OnlineRuleCapabilityStatus.supported(),
      OnlineRuleCapability.suppliedDocumentEvaluation:
          OnlineRuleCapabilityStatus.supported(),
      OnlineRuleCapability.gatewayPageRetrieval:
          OnlineRuleCapabilityStatus.unsupported('No gateway in bootstrap.'),
      OnlineRuleCapability.cssSelectorIntent:
          OnlineRuleCapabilityStatus.supported(),
      OnlineRuleCapability.xpath1Intent: OnlineRuleCapabilityStatus.supported(),
      OnlineRuleCapability.regexExtraction:
          OnlineRuleCapabilityStatus.supported(),
    },
  );
}

OnlineRuleCapabilityMatrix _unsupportedCapabilities() {
  return OnlineRuleCapabilityMatrix.unsupported(reason: 'All unsupported.');
}

OnlineRuleCapabilityMatrix _noEvaluationCapabilities() {
  return const OnlineRuleCapabilityMatrix(
    capabilities: <OnlineRuleCapability, OnlineRuleCapabilityStatus>{
      OnlineRuleCapability.manifestValidation:
          OnlineRuleCapabilityStatus.supported(),
      OnlineRuleCapability.suppliedDocumentEvaluation:
          OnlineRuleCapabilityStatus.unsupported('No document evaluation.'),
      OnlineRuleCapability.gatewayPageRetrieval:
          OnlineRuleCapabilityStatus.unsupported('No gateway.'),
      OnlineRuleCapability.cssSelectorIntent:
          OnlineRuleCapabilityStatus.unsupported('No CSS.'),
      OnlineRuleCapability.xpath1Intent:
          OnlineRuleCapabilityStatus.unsupported('No XPath.'),
      OnlineRuleCapability.regexExtraction:
          OnlineRuleCapabilityStatus.unsupported('No regex.'),
    },
  );
}

OnlineRuleManifest _testManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('source-1'),
    displayName: 'Test Source',
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

String _searchDocument(String title) {
  return '<article class="result">'
      '<h2 title="$title">$title</h2>'
      '<a class="detail-link" href="https://source.example.test/detail">'
      'Detail</a>'
      '</article>';
}

OnlineRuleManifest _wasmManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('source-1'),
    displayName: 'WASM Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/manifest.json'),
    checksum: 'sha256:bad',
    updateInterval: const Duration(hours: 12),
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
  );
}

OnlineRuleManifest _normalizationFailureManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('source-1'),
    displayName: 'Normalization Failure Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri:
        Uri.parse('https://rules.example.test/normalization-failure.json'),
    checksum: 'sha256:normalization-failure',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'search-title',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.result h2',
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  );
}
