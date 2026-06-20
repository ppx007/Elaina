import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual challenge storage persists artifacts attempts and capabilities',
      () async {
    final DeterministicWebViewSessionBackfillStore store =
        DeterministicWebViewSessionBackfillStore();
    final DateTime observedAt = DateTime.utc(2026, 6, 9, 12);

    await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
      id: 'challenge-1',
      providerScope: 'provider-a',
      origin: Uri.parse('https://provider.example.test'),
      challengeUri: Uri.parse('https://provider.example.test/challenge'),
      kind: StoredManualChallengeKind.captcha,
      state: StoredManualChallengeState.required,
      requestedAt: observedAt,
      reason: 'Manual challenge required.',
    ));
    await store.updateChallengeState(
      id: 'challenge-1',
      state: StoredManualChallengeState.captured,
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
        domain: 'provider.example.test',
        path: '/',
        capturedAt: observedAt,
        expiresAt: observedAt.add(const Duration(hours: 1)),
        state: StoredWebViewSessionArtifactState.approved,
      ),
    ]);
    await store.recordBackfillAttempt(StoredWebViewSessionBackfillAttemptRecord(
      id: 'attempt-1',
      challengeRequestId: 'challenge-1',
      providerScope: 'provider-a',
      requestUri: Uri.parse('https://provider.example.test/resource'),
      state: StoredWebViewSessionBackfillState.succeeded,
      providerCacheKey: 'provider-a::resource',
      attemptedAt: observedAt,
    ));
    await store.storeCapability(StoredWebViewSessionCapabilityRecord(
      providerScope: 'provider-a',
      capability: WebViewSessionCapability.isolatedWebView.name,
      state: StoredWebViewSessionCapabilityState.supported,
      updatedAt: observedAt,
    ));

    expect((await store.challengeRequestById('challenge-1'))?.state,
        StoredManualChallengeState.captured);
    expect((await store.artifactsForChallenge('challenge-1')).single.name,
        'session');
    expect(
        (await store.activeArtifactsForProvider(
                providerScope: 'provider-a', now: observedAt))
            .single
            .valueReference,
        'secret-ref');
    expect((await store.latestBackfillAttempt('challenge-1'))?.state,
        StoredWebViewSessionBackfillState.succeeded);
    expect(
        (await store.capabilityForProvider(
                providerScope: 'provider-a',
                capability: WebViewSessionCapability.isolatedWebView.name))
            ?.state,
        StoredWebViewSessionCapabilityState.supported);

    await store.revokeArtifact(artifactId: 'artifact-1', revokedAt: observedAt);
    expect(
        await store.activeArtifactsForProvider(
            providerScope: 'provider-a', now: observedAt),
        isEmpty);
  });

  test(
      'retry descriptors enforce same-origin active artifacts and gateway shape',
      () {
    const WebViewSessionBackfillDescriptorFactory factory =
        WebViewSessionBackfillDescriptorFactory();
    final DateTime observedAt = DateTime.utc(2026, 6, 9, 12);
    final SessionArtifactBundle artifacts = SessionArtifactBundle(
      providerScope: 'provider-a',
      origin: Uri.parse('https://provider.example.test'),
      capturedAt: observedAt,
      cookies: <SessionCookieArtifact>[
        SessionCookieArtifact(
          id: const WebViewSessionArtifactId('cookie-1'),
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          name: 'session',
          valueReference: 'secret-ref',
          domain: 'provider.example.test',
          path: '/',
          capturedAt: observedAt,
          expiresAt: observedAt.add(const Duration(hours: 1)),
          sameSite: WebViewSessionSameSite.lax,
        ),
      ],
      providerTokens: <ProviderSessionTokenArtifact>[
        ProviderSessionTokenArtifact(
          id: const WebViewSessionProviderTokenId('token-1'),
          providerScope: 'provider-a',
          origin: Uri.parse('https://provider.example.test'),
          name: 'csrf',
          valueReference: 'csrf-ref',
          capturedAt: observedAt,
        ),
      ],
      userAgent: 'Elaina Manual Challenge',
    );

    final WebViewSessionBackfillRetryOutcome ready = factory.retryDescriptor(
      attemptId: const WebViewSessionBackfillAttemptId('attempt-1'),
      providerId: const ProviderId('provider-a'),
      providerScope: 'provider-a',
      requestUri: Uri.parse('https://provider.example.test/resource'),
      cacheKey: 'provider-a::resource',
      artifacts: artifacts,
      now: observedAt,
      ratePolicy: const ProviderRatePolicy(
          maxRequests: 2, window: Duration(minutes: 1)),
      retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
    );

    expect(ready.isSuccess, isTrue);
    expect(ready.descriptor?.registration.providerId.value, 'provider-a');
    expect(ready.descriptor?.requestKey.cacheKey, 'provider-a::resource');
    expect(ready.descriptor?.cookies.single.valueReference, 'secret-ref');
    expect(ready.descriptor?.providerTokens.single.valueReference, 'csrf-ref');

    final WebViewSessionBackfillRetryOutcome crossOrigin =
        factory.retryDescriptor(
      attemptId: const WebViewSessionBackfillAttemptId('attempt-2'),
      providerId: const ProviderId('provider-a'),
      providerScope: 'provider-a',
      requestUri: Uri.parse('https://evil.example.test/resource'),
      cacheKey: 'provider-a::evil',
      artifacts: artifacts,
      now: observedAt,
      ratePolicy: const ProviderRatePolicy(
          maxRequests: 2, window: Duration(minutes: 1)),
      retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 2, initialBackoff: Duration(seconds: 1)),
    );

    expect(crossOrigin.isSuccess, isFalse);
    expect(crossOrigin.failure?.failureKind,
        WebViewSessionBackfillFailureKind.rejectedOrigin);
  });

  test('contracts reject forbidden automation and publish invalidation events',
      () async {
    const WebViewSessionBackfillDescriptorFactory factory =
        WebViewSessionBackfillDescriptorFactory();
    final SessionBackfillOutcome rejected =
        factory.validateManualOperation('auto captcha solve');
    final WebViewSessionNetworkPolicyHandoff handoff =
        WebViewSessionNetworkPolicyHandoff(
      providerScope: 'provider-a',
      uri: Uri.parse('http://127.0.0.1/challenge'),
      purpose: 'manualChallenge',
      failureKind: WebViewSessionBackfillFailureKind.networkPolicyBlocked,
      reason: 'Loopback address blocked.',
    );
    final StreamCacheInvalidationBus bus = StreamCacheInvalidationBus();
    final DateTime observedAt = DateTime.utc(2026, 6, 9, 12);
    final Future<List<CacheInvalidationEvent>> events =
        bus.events.take(5).toList();

    bus.publish(WebViewSessionChallengeChanged(
      occurredAt: observedAt,
      challengeRequestId: 'challenge-1',
      providerScope: 'provider-a',
      origin: Uri.parse('https://provider.example.test'),
      changeKind: WebViewSessionChallengeChangeKind.required,
    ));
    bus.publish(WebViewSessionArtifactCaptured(
      occurredAt: observedAt,
      challengeRequestId: 'challenge-1',
      artifactId: 'artifact-1',
      providerScope: 'provider-a',
      origin: Uri.parse('https://provider.example.test'),
      artifactKind: StoredWebViewSessionArtifactKind.cookie.name,
    ));
    bus.publish(WebViewSessionBackfillOutcomeRecorded(
      occurredAt: observedAt,
      attemptId: 'attempt-1',
      challengeRequestId: 'challenge-1',
      providerScope: 'provider-a',
      state: StoredWebViewSessionBackfillState.succeeded.name,
    ));
    bus.publish(WebViewSessionArtifactStateChanged(
      occurredAt: observedAt,
      artifactId: 'artifact-1',
      providerScope: 'provider-a',
      state: StoredWebViewSessionArtifactState.revoked.name,
    ));
    bus.publish(WebViewSessionCapabilityChanged(
      occurredAt: observedAt,
      providerScope: 'provider-a',
      capability: WebViewSessionCapability.isolatedWebView.name,
      supported: true,
    ));

    final List<CacheInvalidationEvent> delivered = await events;
    await bus.close();

    expect(rejected.kind, SessionBackfillOutcomeKind.rejectedOperation);
    expect(rejected.unsupportedOperationKind,
        UnsupportedWebViewSessionOperationKind.automaticCaptchaSolving);
    expect(handoff.failureKind,
        WebViewSessionBackfillFailureKind.networkPolicyBlocked);
    expect(delivered.whereType<WebViewSessionChallengeChanged>().length, 1);
    expect(delivered.whereType<WebViewSessionArtifactCaptured>().length, 1);
    expect(
        delivered.whereType<WebViewSessionBackfillOutcomeRecorded>().length, 1);
    expect(delivered.whereType<WebViewSessionArtifactStateChanged>().length, 1);
    expect(delivered.whereType<WebViewSessionCapabilityChanged>().length, 1);
  });
}
