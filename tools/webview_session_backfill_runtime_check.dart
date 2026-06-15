import '../lib/celesteria.dart';

Future<void> main() async {
  final store = DeterministicWebViewSessionBackfillStore();
  final bus = StreamCacheInvalidationBus();

  // Seed challenge record
  await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
    id: 'challenge-1',
    providerScope: 'provider-a',
    origin: Uri.parse('https://provider.example.test'),
    challengeUri: Uri.parse('https://provider.example.test/challenge'),
    kind: StoredManualChallengeKind.captcha,
    state: StoredManualChallengeState.required,
    requestedAt: DateTime.utc(2026, 6, 16, 10),
  ));

  // Seed capability record
  await store.storeCapability(StoredWebViewSessionCapabilityRecord(
    providerScope: 'provider-a',
    capability: WebViewSessionCapability.isolatedWebView.name,
    state: StoredWebViewSessionCapabilityState.supported,
    updatedAt: DateTime.utc(2026, 6, 16, 10),
  ));

  // Build runtime
  final runtime = _buildRuntime(store: store, bus: bus);

  // --- Snapshot with restart projection ---
  final snapshot = await runtime.snapshot('provider-a');
  _expect(snapshot.isSuccess, 'Initial snapshot must succeed.');
  _expect(snapshot.value!.restart.providerScope == 'provider-a',
      'Restart projection must show provider-a.');
  _expect(snapshot.value!.restart.challengeState == StoredManualChallengeState.required,
      'Restart projection must show required challenge state.');
  _expect(snapshot.value!.restart.capabilityState == StoredWebViewSessionCapabilityState.supported,
      'Restart projection must show supported capability.');

  // --- Manual completion ---
  final completeResult = await runtime.completeManually(
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
  _expect(completeResult.isSuccess, 'Manual completion must succeed.');
  _expect(completeResult.value!.restart.challengeState == StoredManualChallengeState.completed,
      'After completion, challenge state must be completed.');

  // --- Same-origin retry preparation ---
  // Add a fresh challenge in captured state for retry
  await store.storeChallengeRequest(StoredManualChallengeRequestRecord(
    id: 'challenge-2',
    providerScope: 'provider-a',
    origin: Uri.parse('https://provider.example.test'),
    challengeUri: Uri.parse('https://provider.example.test/challenge'),
    kind: StoredManualChallengeKind.captcha,
    state: StoredManualChallengeState.captured,
    requestedAt: DateTime.utc(2026, 6, 16, 11),
  ));
  // Seed an artifact for retry
  await store.storeArtifacts(<StoredWebViewSessionArtifactRecord>[
    StoredWebViewSessionArtifactRecord(
      id: 'artifact-1',
      challengeRequestId: 'challenge-2',
      providerScope: 'provider-a',
      origin: Uri.parse('https://provider.example.test'),
      kind: StoredWebViewSessionArtifactKind.cookie,
      name: 'session',
      valueReference: 'secret-ref',
      capturedAt: DateTime.utc(2026, 6, 16, 11),
      state: StoredWebViewSessionArtifactState.approved,
    ),
  ]);

  final retryResult = await runtime.prepareRetry(
    providerScope: 'provider-a',
    requestUri: Uri.parse('https://provider.example.test/resource'),
  );
  _expect(retryResult.isSuccess, 'Same-origin retry must succeed.');
  _expect(retryResult.value!.restart.latestBackfillState == StoredWebViewSessionBackfillState.pending,
      'Retry must record pending backfill state.');

  // --- Cross-origin retry rejection ---
  final crossResult = await runtime.prepareRetry(
    providerScope: 'provider-a',
    requestUri: Uri.parse('https://evil.example.test/resource'),
  );
  _expect(!crossResult.isSuccess, 'Cross-origin retry must fail.');
  _expect(crossResult.failure!.kind == WebViewSessionBackfillRuntimeFailureKind.rejectedOrigin,
      'Cross-origin retry must report rejectedOrigin.');

  // --- Capability recording ---
  final capResult = await runtime.recordCapability(
    providerScope: 'provider-a',
    capability: WebViewSessionCapability.cookieCapture,
    supported: false,
  );
  _expect(capResult.isSuccess, 'Capability recording must succeed.');

  // --- Artifact revocation ---
  final revokeResult = await runtime.revokeArtifact(
    providerScope: 'provider-a',
    artifactId: 'artifact-1',
  );
  _expect(revokeResult.isSuccess, 'Artifact revocation must succeed.');

  // --- Unavailable gate ---
  final unavailable = WebViewSessionBackfillRuntime.unavailable(reason: 'Not supported.');
  _expect(!(await unavailable.snapshot('provider-a')).isSuccess,
      'Unavailable snapshot must fail.');
  _expect((await unavailable.snapshot('provider-a')).failure!.kind ==
      WebViewSessionBackfillRuntimeFailureKind.unavailable,
      'Unavailable must report unavailable kind.');

  // --- Disposed gate ---
  runtime.dispose();
  _expect(!(await runtime.snapshot('provider-a')).isSuccess,
      'Disposed snapshot must fail.');
  _expect((await runtime.snapshot('provider-a')).failure!.kind ==
      WebViewSessionBackfillRuntimeFailureKind.disposed,
      'Disposed must report disposed kind.');

  await bus.close();
}

WebViewSessionBackfillRuntime _buildRuntime({
  required DeterministicWebViewSessionBackfillStore store,
  required StreamCacheInvalidationBus bus,
}) {
  return WebViewSessionBackfillRuntimeBootstrap(
    store: store,
    backfillByScope: <String, WebViewSessionBackfill>{
      'provider-a': _CheckBackfill(),
    },
    capabilitiesByScope: <String, WebViewSessionCapabilityMatrix>{
      'provider-a': WebViewSessionCapabilityMatrix(
        capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
          WebViewSessionCapability.isolatedWebView: WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.cookieCapture: WebViewSessionCapabilityStatus.supported(),
          WebViewSessionCapability.providerTokenBackfill: WebViewSessionCapabilityStatus.supported(),
        },
      ),
    },
    bus: bus,
  ).createRuntime();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckBackfill implements WebViewSessionBackfill {
  @override
  WebViewSessionCapabilityMatrix get capabilities => WebViewSessionCapabilityMatrix(
    capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
      WebViewSessionCapability.isolatedWebView: WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.cookieCapture: WebViewSessionCapabilityStatus.supported(),
      WebViewSessionCapability.providerTokenBackfill: WebViewSessionCapabilityStatus.supported(),
    },
  );

  @override
  Future<SessionBackfillOutcome> completeManually(ManualChallengeRequest request) async {
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
