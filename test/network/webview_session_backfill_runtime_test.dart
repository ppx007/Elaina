import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebViewSessionBackfillRuntime', () {
    late DeterministicWebViewSessionBackfillStore store;
    late StreamCacheInvalidationBus bus;

    setUp(() {
      store = DeterministicWebViewSessionBackfillStore();
      bus = StreamCacheInvalidationBus();
    });

    tearDown(() async {
      await bus.close();
    });

    WebViewSessionBackfillRuntime _runtime({
      required String providerScope,
      required WebViewSessionBackfill backfill,
      WebViewSessionCapabilityMatrix? capabilities,
      DateTime Function()? clock,
    }) {
      return WebViewSessionBackfillRuntimeBootstrap(
        store: store,
        backfillByScope: <String, WebViewSessionBackfill>{
          providerScope: backfill,
        },
        capabilitiesByScope: <String, WebViewSessionCapabilityMatrix>{
          providerScope: capabilities ?? _supportedCapabilities(),
        },
        bus: bus,
        clock: clock,
      ).createRuntime();
    }

    test('initial snapshot projects seeded challenge and capability state',
        () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
        id: 'challenge-1',
        providerScope: 'provider-a',
        origin: Uri.parse('https://provider.example.test'),
        challengeUri: Uri.parse('https://provider.example.test/challenge'),
        kind: StoredManualChallengeKind.captcha,
        state: StoredManualChallengeState.required,
        requestedAt: DateTime.utc(2026, 6, 16, 10),
      ));
      await store.storeCapability(StoredWebViewSessionCapabilityRecord(
        providerScope: 'provider-a',
        capability: WebViewSessionCapability.isolatedWebView.name,
        state: StoredWebViewSessionCapabilityState.supported,
        updatedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.providerScope, 'provider-a');
      expect(result.value?.restart.challengeState,
          StoredManualChallengeState.required);
      expect(result.value?.restart.capabilityState,
          StoredWebViewSessionCapabilityState.supported);
    });

    test('manual completion stores challenge and artifact replay state',
        () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
        id: 'challenge-1',
        providerScope: 'provider-a',
        origin: Uri.parse('https://provider.example.test'),
        challengeUri: Uri.parse('https://provider.example.test/challenge'),
        kind: StoredManualChallengeKind.captcha,
        state: StoredManualChallengeState.required,
        requestedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.completeManually(
        providerScope: 'provider-a',
        request: ManualChallengeRequest(
          id: const ManualChallengeRequestId('challenge-1'),
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          challengeUri: Uri.parse('https://provider.example.test/challenge'),
          kind: ManualChallengeKind.captcha,
          requestedAt: DateTime.utc(2026, 6, 16, 10),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect((await store.challengeRequestById('challenge-1'))?.state,
          StoredManualChallengeState.completed);
      expect(events.whereType<WebViewSessionChallengeChanged>(), isNotEmpty);
      await subscription.cancel();
    });

    test('prepare retry rejects cross-origin artifacts', () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
        id: 'challenge-1',
        providerScope: 'provider-a',
        origin: Uri.parse('https://provider.example.test'),
        challengeUri: Uri.parse('https://provider.example.test/challenge'),
        kind: StoredManualChallengeKind.captcha,
        state: StoredManualChallengeState.captured,
        requestedAt: DateTime.utc(2026, 6, 16, 10),
      ));
      await store.storeArtifacts(<StoredWebViewSessionArtifactRecord>[
        StoredWebViewSessionArtifactRecord(
          id: 'artifact-1',
          challengeRequestId: 'challenge-1',
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          kind: StoredWebViewSessionArtifactKind.cookie,
          name: 'session',
          valueReference: 'secret-ref',
          capturedAt: DateTime.utc(2026, 6, 16, 10),
          state: StoredWebViewSessionArtifactState.approved,
        ),
      ]);

      final result = await runtime.prepareRetry(
        providerScope: 'provider-a',
        requestUri: Uri.parse('https://evil.example.test/resource'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          WebViewSessionBackfillRuntimeFailureKind.rejectedOrigin);
    });

    test('revoke artifact publishes artifact state change', () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      await store.storeArtifacts(<StoredWebViewSessionArtifactRecord>[
        StoredWebViewSessionArtifactRecord(
          id: 'artifact-1',
          challengeRequestId: 'challenge-1',
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          kind: StoredWebViewSessionArtifactKind.cookie,
          name: 'session',
          valueReference: 'secret-ref',
          capturedAt: DateTime.utc(2026, 6, 16, 10),
          state: StoredWebViewSessionArtifactState.approved,
        ),
      ]);

      final events = <CacheInvalidationEvent>[];
      final subscription = bus.events.listen(events.add);

      final result = await runtime.revokeArtifact(
        providerScope: 'provider-a',
        artifactId: 'artifact-1',
      );

      expect(result.isSuccess, isTrue);
      expect(events.whereType<WebViewSessionArtifactStateChanged>(), isNotEmpty);
      await subscription.cancel();
    });

    test('unsupported capability returns capabilityUnsupported', () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
        capabilities: WebViewSessionCapabilityMatrix.unsupported(
            reason: 'No WebView integration.'),
      );

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          WebViewSessionBackfillRuntimeFailureKind.capabilityUnsupported);
    });

    test('unavailable runtime rejects all operations', () async {
      final runtime = WebViewSessionBackfillRuntime.unavailable(
        reason: 'Platform unsupported.',
      );

      expect((await runtime.snapshot('provider-a')).failure?.kind,
          WebViewSessionBackfillRuntimeFailureKind.unavailable);
      expect((await runtime.completeManually(
        providerScope: 'provider-a',
        request: _manualRequest(),
      )).failure?.kind, WebViewSessionBackfillRuntimeFailureKind.unavailable);
      expect((await runtime.prepareRetry(
        providerScope: 'provider-a',
        requestUri: Uri.parse('https://provider.example.test/resource'),
      )).failure?.kind, WebViewSessionBackfillRuntimeFailureKind.unavailable);
      expect((await runtime.revokeArtifact(
        providerScope: 'provider-a',
        artifactId: 'artifact-1',
      )).failure?.kind, WebViewSessionBackfillRuntimeFailureKind.unavailable);
      expect((await runtime.recordCapability(
        providerScope: 'provider-a',
        capability: WebViewSessionCapability.isolatedWebView,
        supported: false,
      )).failure?.kind, WebViewSessionBackfillRuntimeFailureKind.unavailable);
    });

    test('disposed runtime rejects snapshot', () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      runtime.dispose();

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isFalse);
      expect(result.failure?.kind,
          WebViewSessionBackfillRuntimeFailureKind.disposed);
    });

    test('restart projection replays stored challenge artifact and attempt state',
        () async {
      final runtime = _runtime(
        providerScope: 'provider-a',
        backfill: _supportedBackfill(),
      );

      await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
        id: 'challenge-1',
        providerScope: 'provider-a',
        origin: Uri.parse('https://provider.example.test'),
        challengeUri: Uri.parse('https://provider.example.test/challenge'),
        kind: StoredManualChallengeKind.captcha,
        state: StoredManualChallengeState.backfilled,
        requestedAt: DateTime.utc(2026, 6, 16, 10),
      ));
      await store.storeArtifacts(<StoredWebViewSessionArtifactRecord>[
        StoredWebViewSessionArtifactRecord(
          id: 'artifact-1',
          challengeRequestId: 'challenge-1',
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          kind: StoredWebViewSessionArtifactKind.cookie,
          name: 'session',
          valueReference: 'secret-ref',
          capturedAt: DateTime.utc(2026, 6, 16, 10),
          state: StoredWebViewSessionArtifactState.approved,
        ),
      ]);
      await store.recordBackfillAttempt(StoredWebViewSessionBackfillAttemptRecord(
        id: 'attempt-1',
        challengeRequestId: 'challenge-1',
        providerScope: 'provider-a',
        requestUri: Uri.parse('https://provider.example.test/resource'),
        state: StoredWebViewSessionBackfillState.succeeded,
        attemptedAt: DateTime.utc(2026, 6, 16, 10),
      ));

      final result = await runtime.snapshot('provider-a');

      expect(result.isSuccess, isTrue);
      expect(result.value?.restart.latestChallengeState,
          StoredManualChallengeState.backfilled);
      expect(result.value?.restart.latestArtifactCount, 1);
      expect(result.value?.restart.latestBackfillState,
          StoredWebViewSessionBackfillState.succeeded);
    });
  });
}

WebViewSessionBackfill _supportedBackfill() {
  return _UnsupportedBackfill();
}

ManualChallengeRequest _manualRequest() {
  return ManualChallengeRequest(
    id: const ManualChallengeRequestId('challenge-1'),
    providerScope: 'provider-a',
    origin: Uri.parse('https://provider.example.test'),
    challengeUri: Uri.parse('https://provider.example.test/challenge'),
    kind: ManualChallengeKind.captcha,
    requestedAt: DateTime.utc(2026, 6, 16, 10),
  );
}

final class _UnsupportedBackfill implements WebViewSessionBackfill {
  @override
  WebViewSessionCapabilityMatrix get capabilities =>
      WebViewSessionCapabilityMatrix(
        capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
          WebViewSessionCapability.isolatedWebView:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.cookieCapture:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.localStorageCapture:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.userAgentCapture:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.sameOriginArtifactCapture:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.providerTokenBackfill:
              WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.persistentSession:
              WebViewSessionCapabilityStatus.supported(),
        },
      );

  @override
  Future<SessionBackfillOutcome> completeManually(
      ManualChallengeRequest request) async {
    return SessionBackfillOutcome(
      kind: SessionBackfillOutcomeKind.captured,
      message: 'captured',
      artifacts: SessionArtifactBundle(
        providerScope: request.providerScope,
        origin: request.origin,
        capturedAt: request.requestedAt ?? DateTime.utc(2026, 6, 16, 10),
      ),
    );
  }
}

WebViewSessionCapabilityMatrix _supportedCapabilities() {
  return WebViewSessionCapabilityMatrix(
    capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
      WebViewSessionCapability.isolatedWebView:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.cookieCapture:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.localStorageCapture:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.userAgentCapture:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.sameOriginArtifactCapture:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.providerTokenBackfill:
          WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.persistentSession:
          WebViewSessionCapabilityStatus.supported(),
    },
  );
}
