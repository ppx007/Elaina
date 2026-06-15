import '../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../foundation/storage/webview_session_backfill_storage_contracts.dart';
import 'webview_session_backfill.dart';

enum WebViewSessionBackfillRuntimeFailureKind {
  capabilityUnsupported,
  unavailable,
  disposed,
  challengeNotFound,
  unsupportedOperation,
  rejectedOrigin,
  artifactInactive,
  missingArtifact,
  failed,
}

final class WebViewSessionBackfillRuntimeFailure {
  const WebViewSessionBackfillRuntimeFailure({
    required this.kind,
    required this.message,
    this.providerScope,
  }) : assert(message != '', 'Failure message must not be empty.');

  final WebViewSessionBackfillRuntimeFailureKind kind;
  final String message;
  final String? providerScope;
}

enum WebViewSessionBackfillRuntimeActionResultKind {
  success,
  failed,
  unavailable,
  disposed,
}

final class WebViewSessionBackfillRuntimeActionResult<T> {
  const WebViewSessionBackfillRuntimeActionResult._({
    required this.kind,
    this.value,
    this.failure,
  });

  const WebViewSessionBackfillRuntimeActionResult.success([T? value])
      : this._(kind: WebViewSessionBackfillRuntimeActionResultKind.success,
            value: value);

  WebViewSessionBackfillRuntimeActionResult.failed(
      WebViewSessionBackfillRuntimeFailure failure)
      : this._(kind: WebViewSessionBackfillRuntimeActionResultKind.failed,
            failure: failure);

  WebViewSessionBackfillRuntimeActionResult.unavailable(String message)
      : this._(
            kind: WebViewSessionBackfillRuntimeActionResultKind.unavailable,
            failure: WebViewSessionBackfillRuntimeFailure(
              kind: WebViewSessionBackfillRuntimeFailureKind.unavailable,
              message: message,
            ));

  WebViewSessionBackfillRuntimeActionResult.disposed()
      : this._(
            kind: WebViewSessionBackfillRuntimeActionResultKind.disposed,
            failure: const WebViewSessionBackfillRuntimeFailure(
              kind: WebViewSessionBackfillRuntimeFailureKind.disposed,
              message: 'WebView session backfill runtime has been disposed.',
            ));

  final WebViewSessionBackfillRuntimeActionResultKind kind;
  final T? value;
  final WebViewSessionBackfillRuntimeFailure? failure;

  bool get isSuccess => kind == WebViewSessionBackfillRuntimeActionResultKind.success;
}

final class WebViewSessionBackfillRuntimeRestartProjection {
  const WebViewSessionBackfillRuntimeRestartProjection({
    required this.providerScope,
    this.challengeState,
    this.latestChallengeState,
    this.capabilityState,
    required this.latestArtifactCount,
    this.latestBackfillState,
  });

  final String providerScope;
  final StoredManualChallengeState? challengeState;
  final StoredManualChallengeState? latestChallengeState;
  final StoredWebViewSessionCapabilityState? capabilityState;
  final int latestArtifactCount;
  final StoredWebViewSessionBackfillState? latestBackfillState;
}

final class WebViewSessionBackfillRuntimeProjection {
  const WebViewSessionBackfillRuntimeProjection({
    required this.providerScope,
    required this.restart,
    this.latestArtifactCount,
    this.latestBackfillState,
  });

  final String providerScope;
  final int? latestArtifactCount;
  final StoredWebViewSessionBackfillState? latestBackfillState;
  final WebViewSessionBackfillRuntimeRestartProjection restart;
}

final class WebViewSessionBackfillRuntimeBootstrap {
  WebViewSessionBackfillRuntimeBootstrap({
    required this.store,
    required Map<String, WebViewSessionBackfill> backfillByScope,
    required Map<String, WebViewSessionCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
    DateTime Function()? clock,
  })  : _backfillByScope =
            Map<String, WebViewSessionBackfill>.unmodifiable(backfillByScope),
        _capabilitiesByScope =
            Map<String, WebViewSessionCapabilityMatrix>.unmodifiable(
                capabilitiesByScope),
        _bus = bus,
        _clock = clock;

  final WebViewSessionBackfillStore store;
  final Map<String, WebViewSessionBackfill> _backfillByScope;
  final Map<String, WebViewSessionCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;
  final DateTime Function()? _clock;

  WebViewSessionBackfillRuntime createRuntime() {
    return WebViewSessionBackfillRuntime._(
      store: store,
      backfillByScope: _backfillByScope,
      capabilitiesByScope: _capabilitiesByScope,
      bus: _bus,
      clock: _clock,
    );
  }
}

final class WebViewSessionBackfillRuntime {
  WebViewSessionBackfillRuntime._({
    required WebViewSessionBackfillStore store,
    required Map<String, WebViewSessionBackfill> backfillByScope,
    required Map<String, WebViewSessionCapabilityMatrix> capabilitiesByScope,
    CacheInvalidationBus? bus,
    DateTime Function()? clock,
  })  : _store = store,
        _backfillByScope = backfillByScope,
        _capabilitiesByScope = capabilitiesByScope,
        _bus = bus,
        _clock = clock,
        _unavailableReason = null;

  WebViewSessionBackfillRuntime.unavailable({required String reason})
      : _store = null,
        _backfillByScope =
            const <String, WebViewSessionBackfill>{},
        _capabilitiesByScope =
            const <String, WebViewSessionCapabilityMatrix>{},
        _bus = null,
        _clock = null,
        _unavailableReason = reason;

  final WebViewSessionBackfillStore? _store;
  final Map<String, WebViewSessionBackfill> _backfillByScope;
  final Map<String, WebViewSessionCapabilityMatrix> _capabilitiesByScope;
  final CacheInvalidationBus? _bus;
  final DateTime Function()? _clock;
  final String? _unavailableReason;
  bool _disposed = false;

  WebViewSessionBackfillStore _requireStore() {
    final WebViewSessionBackfillStore? store = _store;
    if (store == null) throw StateError('Store required but unavailable.');
    return store;
  }

  DateTime _now() => (_clock != null) ? _clock() : DateTime.now().toUtc();

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> snapshot(
      String providerScope) async {
    final WebViewSessionBackfillRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);
    return _projection(providerScope);
  }

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> completeManually({
    required String providerScope,
    required ManualChallengeRequest request,
  }) async {
    final WebViewSessionBackfillRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    final WebViewSessionBackfill backfill = _backfillByScope[providerScope]!;
    final SessionBackfillOutcome outcome =
        await backfill.completeManually(request);

    final DateTime now = _now();
    final StoredManualChallengeState challengeState =
        outcome.kind == SessionBackfillOutcomeKind.captured
            ? StoredManualChallengeState.completed
            : StoredManualChallengeState.failed;

    await _requireStore().updateChallengeState(
      id: request.id.value,
      state: challengeState,
      reason: outcome.message,
    );

    if (outcome.artifacts != null && outcome.kind == SessionBackfillOutcomeKind.captured) {
      final SessionArtifactBundle bundle = outcome.artifacts!;
      final List<StoredWebViewSessionArtifactRecord> storedArtifacts =
          <StoredWebViewSessionArtifactRecord>[
        for (int i = 0; i < bundle.cookies.length; i++)
          StoredWebViewSessionArtifactRecord(
            id: bundle.cookies[i].id.value,
            challengeRequestId: request.id.value,
            providerScope: providerScope,
            origin: request.origin,
            kind: StoredWebViewSessionArtifactKind.cookie,
            name: bundle.cookies[i].name,
            valueReference: bundle.cookies[i].valueReference,
            domain: bundle.cookies[i].domain,
            path: bundle.cookies[i].path,
            capturedAt: bundle.cookies[i].capturedAt,
            expiresAt: bundle.cookies[i].expiresAt,
            state: StoredWebViewSessionArtifactState.approved,
          ),
        for (int i = 0; i < bundle.providerTokens.length; i++)
          StoredWebViewSessionArtifactRecord(
            id: bundle.providerTokens[i].id.value,
            challengeRequestId: request.id.value,
            providerScope: providerScope,
            origin: request.origin,
            kind: StoredWebViewSessionArtifactKind.providerToken,
            name: bundle.providerTokens[i].name,
            valueReference: bundle.providerTokens[i].valueReference,
            capturedAt: bundle.providerTokens[i].capturedAt,
            expiresAt: bundle.providerTokens[i].expiresAt,
            state: StoredWebViewSessionArtifactState.approved,
          ),
      ];
      if (storedArtifacts.isNotEmpty) {
        await _requireStore().storeArtifacts(storedArtifacts);
      }
    }

    _publishEvent(WebViewSessionChallengeChanged(
      occurredAt: now,
      challengeRequestId: request.id.value,
      providerScope: providerScope,
      origin: request.origin,
      changeKind: WebViewSessionChallengeChangeKind.completed,
      reason: outcome.message,
    ));

    return _projection(providerScope);
  }

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> prepareRetry({
    required String providerScope,
    required Uri requestUri,
  }) async {
    final WebViewSessionBackfillRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    final List<StoredManualChallengeRequestRecord> challenges =
        await _requireStore().challengeRequestsForProvider(providerScope);
    if (challenges.isEmpty) {
      return WebViewSessionBackfillRuntimeActionResult<
          WebViewSessionBackfillRuntimeProjection>.failed(
        WebViewSessionBackfillRuntimeFailure(
          kind: WebViewSessionBackfillRuntimeFailureKind.challengeNotFound,
          message: 'No challenge found for provider scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }

    final StoredManualChallengeRequestRecord latestChallenge = challenges.last;
    final List<StoredWebViewSessionArtifactRecord> artifacts =
        await _requireStore()
            .activeArtifactsForProvider(providerScope: providerScope, now: _now());
    if (artifacts.isEmpty) {
      return WebViewSessionBackfillRuntimeActionResult<
          WebViewSessionBackfillRuntimeProjection>.failed(
        WebViewSessionBackfillRuntimeFailure(
          kind: WebViewSessionBackfillRuntimeFailureKind.missingArtifact,
          message: 'No active artifacts available for retry.',
          providerScope: providerScope,
        ),
      );
    }

    if (!_sameOrigin(latestChallenge.origin, requestUri)) {
      return WebViewSessionBackfillRuntimeActionResult<
          WebViewSessionBackfillRuntimeProjection>.failed(
        WebViewSessionBackfillRuntimeFailure(
          kind: WebViewSessionBackfillRuntimeFailureKind.rejectedOrigin,
          message:
              'Request URI origin does not match challenge origin.',
          providerScope: providerScope,
        ),
      );
    }

    await _requireStore().recordBackfillAttempt(
      StoredWebViewSessionBackfillAttemptRecord(
        id: 'retry-${latestChallenge.id}-${_now().millisecondsSinceEpoch}',
        challengeRequestId: latestChallenge.id,
        providerScope: providerScope,
        requestUri: requestUri,
        state: StoredWebViewSessionBackfillState.pending,
        attemptedAt: _now(),
      ),
    );

    final DateTime now = _now();
    _publishEvent(WebViewSessionBackfillOutcomeRecorded(
      occurredAt: now,
      attemptId: 'retry-${latestChallenge.id}-${now.millisecondsSinceEpoch}',
      challengeRequestId: latestChallenge.id,
      providerScope: providerScope,
      state: StoredWebViewSessionBackfillState.pending.name,
    ));

    return _projection(providerScope);
  }

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> revokeArtifact({
    required String providerScope,
    required String artifactId,
  }) async {
    final WebViewSessionBackfillRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    final DateTime now = _now();
    await _requireStore().revokeArtifact(artifactId: artifactId, revokedAt: now);

    _publishEvent(WebViewSessionArtifactStateChanged(
      occurredAt: now,
      artifactId: artifactId,
      providerScope: providerScope,
      state: StoredWebViewSessionArtifactState.revoked.name,
    ));

    return _projection(providerScope);
  }

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> recordCapability({
    required String providerScope,
    required WebViewSessionCapability capability,
    required bool supported,
  }) async {
    final WebViewSessionBackfillRuntimeActionResult<void>? gate =
        _gate(providerScope);
    if (gate != null) return _castFail(gate);

    final DateTime now = _now();
    final StoredWebViewSessionCapabilityState state =
        supported
            ? StoredWebViewSessionCapabilityState.supported
            : StoredWebViewSessionCapabilityState.unsupported;

    await _requireStore().storeCapability(StoredWebViewSessionCapabilityRecord(
      providerScope: providerScope,
      capability: capability.name,
      state: state,
      updatedAt: now,
    ));

    _publishEvent(WebViewSessionCapabilityChanged(
      occurredAt: now,
      providerScope: providerScope,
      capability: capability.name,
      supported: supported,
    ));

    return _projection(providerScope);
  }

  void dispose() {
    _disposed = true;
  }

  WebViewSessionBackfillRuntimeActionResult<void>? _gate(
      String providerScope) {
    if (_disposed) {
      return WebViewSessionBackfillRuntimeActionResult<void>.disposed();
    }
    if (_unavailableReason != null) {
      return WebViewSessionBackfillRuntimeActionResult<void>.unavailable(
          _unavailableReason);
    }
    final WebViewSessionCapabilityMatrix? capabilities =
        _capabilitiesByScope[providerScope];
    if (capabilities == null) {
      return WebViewSessionBackfillRuntimeActionResult<void>.failed(
        WebViewSessionBackfillRuntimeFailure(
          kind: WebViewSessionBackfillRuntimeFailureKind.unsupportedOperation,
          message: 'No capabilities declared for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }
    final WebViewSessionCapabilityStatus capabilityStatus =
        capabilities.statusOf(WebViewSessionCapability.isolatedWebView);
    if (!capabilityStatus.supported) {
      return WebViewSessionBackfillRuntimeActionResult<void>.failed(
        WebViewSessionBackfillRuntimeFailure(
          kind: WebViewSessionBackfillRuntimeFailureKind.capabilityUnsupported,
          message: capabilityStatus.reason ??
              'Capability isolatedWebView is not supported for scope $providerScope.',
          providerScope: providerScope,
        ),
      );
    }
    return null;
  }

  Future<WebViewSessionBackfillRuntimeActionResult<
      WebViewSessionBackfillRuntimeProjection>> _projection(
      String providerScope) async {
    final List<StoredManualChallengeRequestRecord> challenges =
        await _requireStore().challengeRequestsForProvider(providerScope);
    final StoredManualChallengeRequestRecord? latestChallenge =
        challenges.isNotEmpty ? challenges.last : null;
    final List<StoredWebViewSessionArtifactRecord> artifacts =
        await _requireStore()
            .activeArtifactsForProvider(providerScope: providerScope, now: _now());
    final StoredWebViewSessionBackfillAttemptRecord? latestAttempt =
        latestChallenge != null
            ? await _requireStore().latestBackfillAttempt(latestChallenge.id)
            : null;
    final StoredWebViewSessionCapabilityRecord? capability =
        await _requireStore().capabilityForProvider(
              providerScope: providerScope,
              capability: WebViewSessionCapability.isolatedWebView.name,
            );

    final WebViewSessionBackfillRuntimeRestartProjection restart =
        WebViewSessionBackfillRuntimeRestartProjection(
      providerScope: providerScope,
      challengeState: latestChallenge?.state,
      latestChallengeState: latestChallenge?.state,
      capabilityState: capability?.state,
      latestArtifactCount: artifacts.length,
      latestBackfillState: latestAttempt?.state,
    );

    return WebViewSessionBackfillRuntimeActionResult<
        WebViewSessionBackfillRuntimeProjection>.success(
      WebViewSessionBackfillRuntimeProjection(
        providerScope: providerScope,
        latestArtifactCount: artifacts.length,
        latestBackfillState: latestAttempt?.state,
        restart: restart,
      ),
    );
  }

  void _publishEvent(CacheInvalidationEvent event) {
    _bus?.publish(event);
  }

  WebViewSessionBackfillRuntimeActionResult<T> _castFail<T>(
      WebViewSessionBackfillRuntimeActionResult<void> fail) {
    return WebViewSessionBackfillRuntimeActionResult<T>._(
      kind: fail.kind,
      failure: fail.failure,
    );
  }
}

bool _sameOrigin(Uri left, Uri right) {
  return left.scheme == right.scheme &&
      left.host == right.host &&
      _effectivePort(left) == _effectivePort(right);
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }
  return switch (uri.scheme) {
    'http' => 80,
    'https' => 443,
    _ => 0,
  };
}
