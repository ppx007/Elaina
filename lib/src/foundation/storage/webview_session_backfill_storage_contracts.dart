enum StoredManualChallengeKind {
  captcha,
  login,
  ageGate,
  providerInterstitial,
}

enum StoredManualChallengeState {
  required,
  opened,
  completed,
  captured,
  backfilled,
  expired,
  revoked,
  failed,
}

enum StoredWebViewSessionArtifactKind {
  cookie,
  providerToken,
}

enum StoredWebViewSessionSameSite {
  strict,
  lax,
  none,
  unspecified,
}

enum StoredWebViewSessionArtifactState {
  pending,
  approved,
  rejected,
  revoked,
  expired,
}

enum StoredWebViewSessionBackfillState {
  pending,
  succeeded,
  failed,
  rejectedOrigin,
  expired,
  revoked,
  unsupported,
  blockedByNetworkPolicy,
}

enum StoredWebViewSessionCapabilityState {
  supported,
  unsupported,
  disabled,
}

final class StoredManualChallengeRequestRecord {
  StoredManualChallengeRequestRecord({
    required this.id,
    required this.providerScope,
    required this.origin,
    required this.challengeUri,
    required this.kind,
    required this.state,
    required this.requestedAt,
    this.reason,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(id != '', 'Manual challenge request id must not be empty.'),
        assert(providerScope != '',
            'Manual challenge provider scope must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String id;
  final String providerScope;
  final Uri origin;
  final Uri challengeUri;
  final StoredManualChallengeKind kind;
  final StoredManualChallengeState state;
  final String? reason;
  final DateTime requestedAt;
  final Map<String, String> metadata;
}

final class StoredWebViewSessionArtifactRecord {
  StoredWebViewSessionArtifactRecord({
    required this.id,
    required this.challengeRequestId,
    required this.providerScope,
    required this.origin,
    required this.kind,
    required this.name,
    required this.valueReference,
    required this.capturedAt,
    required this.state,
    this.domain,
    this.path,
    this.expiresAt,
    this.secure = true,
    this.httpOnly = true,
    this.sameSite = StoredWebViewSessionSameSite.unspecified,
    this.revokedAt,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(id != '', 'WebView session artifact id must not be empty.'),
        assert(challengeRequestId != '',
            'Challenge request id must not be empty.'),
        assert(providerScope != '',
            'WebView session provider scope must not be empty.'),
        assert(name != '', 'WebView session artifact name must not be empty.'),
        assert(valueReference != '',
            'WebView session value reference must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final String id;
  final String challengeRequestId;
  final String providerScope;
  final Uri origin;
  final StoredWebViewSessionArtifactKind kind;
  final String name;
  final String valueReference;
  final String? domain;
  final String? path;
  final DateTime? expiresAt;
  final bool secure;
  final bool httpOnly;
  final StoredWebViewSessionSameSite sameSite;
  final DateTime capturedAt;
  final StoredWebViewSessionArtifactState state;
  final DateTime? revokedAt;
  final Map<String, String> metadata;
}

final class StoredWebViewSessionBackfillAttemptRecord {
  const StoredWebViewSessionBackfillAttemptRecord({
    required this.id,
    required this.challengeRequestId,
    required this.providerScope,
    required this.requestUri,
    required this.state,
    required this.attemptedAt,
    this.providerCacheKey,
    this.failureKind,
    this.message,
  })  : assert(
            id != '', 'WebView session backfill attempt id must not be empty.'),
        assert(challengeRequestId != '',
            'Challenge request id must not be empty.'),
        assert(providerScope != '',
            'WebView session provider scope must not be empty.');

  final String id;
  final String challengeRequestId;
  final String providerScope;
  final Uri requestUri;
  final StoredWebViewSessionBackfillState state;
  final String? providerCacheKey;
  final String? failureKind;
  final String? message;
  final DateTime attemptedAt;
}

final class StoredWebViewSessionCapabilityRecord {
  const StoredWebViewSessionCapabilityRecord({
    required this.providerScope,
    required this.capability,
    required this.state,
    required this.updatedAt,
    this.reason,
  })  : assert(providerScope != '',
            'WebView session provider scope must not be empty.'),
        assert(
            capability != '', 'WebView session capability must not be empty.');

  final String providerScope;
  final String capability;
  final StoredWebViewSessionCapabilityState state;
  final String? reason;
  final DateTime updatedAt;
}

abstract interface class WebViewSessionBackfillStore {
  Future<StoredManualChallengeRequestRecord> storeChallengeRequest(
      StoredManualChallengeRequestRecord request);

  Future<StoredManualChallengeRequestRecord?> challengeRequestById(String id);

  Future<List<StoredManualChallengeRequestRecord>> challengeRequestsForProvider(
      String providerScope);

  Future<void> updateChallengeState({
    required String id,
    required StoredManualChallengeState state,
    String? reason,
  });

  Future<void> storeArtifacts(
      Iterable<StoredWebViewSessionArtifactRecord> artifacts);

  Future<List<StoredWebViewSessionArtifactRecord>> artifactsForChallenge(
      String challengeRequestId);

  Future<List<StoredWebViewSessionArtifactRecord>> activeArtifactsForProvider({
    required String providerScope,
    required DateTime now,
  });

  Future<void> revokeArtifact(
      {required String artifactId, required DateTime revokedAt});

  Future<void> recordBackfillAttempt(
      StoredWebViewSessionBackfillAttemptRecord attempt);

  Future<StoredWebViewSessionBackfillAttemptRecord?> latestBackfillAttempt(
      String challengeRequestId);

  Future<void> storeCapability(StoredWebViewSessionCapabilityRecord capability);

  Future<StoredWebViewSessionCapabilityRecord?> capabilityForProvider({
    required String providerScope,
    required String capability,
  });
}

final class DeterministicWebViewSessionBackfillStore
    implements WebViewSessionBackfillStore {
  final Map<String, StoredManualChallengeRequestRecord> _requestsById =
      <String, StoredManualChallengeRequestRecord>{};
  final Map<String, StoredWebViewSessionArtifactRecord> _artifactsById =
      <String, StoredWebViewSessionArtifactRecord>{};
  final Map<String, StoredWebViewSessionBackfillAttemptRecord>
      _attemptsByChallengeId =
      <String, StoredWebViewSessionBackfillAttemptRecord>{};
  final Map<String, StoredWebViewSessionCapabilityRecord> _capabilities =
      <String, StoredWebViewSessionCapabilityRecord>{};

  @override
  Future<List<StoredWebViewSessionArtifactRecord>> activeArtifactsForProvider({
    required String providerScope,
    required DateTime now,
  }) {
    return Future<List<StoredWebViewSessionArtifactRecord>>.value(
      <StoredWebViewSessionArtifactRecord>[
        for (final StoredWebViewSessionArtifactRecord artifact
            in _artifactsById.values)
          if (artifact.providerScope == providerScope &&
              _isActive(artifact, now))
            artifact,
      ],
    );
  }

  @override
  Future<List<StoredWebViewSessionArtifactRecord>> artifactsForChallenge(
      String challengeRequestId) {
    return Future<List<StoredWebViewSessionArtifactRecord>>.value(
      <StoredWebViewSessionArtifactRecord>[
        for (final StoredWebViewSessionArtifactRecord artifact
            in _artifactsById.values)
          if (artifact.challengeRequestId == challengeRequestId) artifact,
      ],
    );
  }

  @override
  Future<StoredWebViewSessionCapabilityRecord?> capabilityForProvider({
    required String providerScope,
    required String capability,
  }) {
    return Future<StoredWebViewSessionCapabilityRecord?>.value(
        _capabilities[_key(providerScope, capability)]);
  }

  @override
  Future<StoredManualChallengeRequestRecord?> challengeRequestById(String id) {
    return Future<StoredManualChallengeRequestRecord?>.value(_requestsById[id]);
  }

  @override
  Future<List<StoredManualChallengeRequestRecord>> challengeRequestsForProvider(
      String providerScope) {
    return Future<List<StoredManualChallengeRequestRecord>>.value(
      <StoredManualChallengeRequestRecord>[
        for (final StoredManualChallengeRequestRecord request
            in _requestsById.values)
          if (request.providerScope == providerScope) request,
      ],
    );
  }

  @override
  Future<StoredWebViewSessionBackfillAttemptRecord?> latestBackfillAttempt(
      String challengeRequestId) {
    return Future<StoredWebViewSessionBackfillAttemptRecord?>.value(
        _attemptsByChallengeId[challengeRequestId]);
  }

  @override
  Future<void> recordBackfillAttempt(
      StoredWebViewSessionBackfillAttemptRecord attempt) {
    _attemptsByChallengeId[attempt.challengeRequestId] = attempt;
    return Future<void>.value();
  }

  @override
  Future<void> revokeArtifact({
    required String artifactId,
    required DateTime revokedAt,
  }) {
    final StoredWebViewSessionArtifactRecord? artifact =
        _artifactsById[artifactId];
    if (artifact != null) {
      _artifactsById[artifactId] = StoredWebViewSessionArtifactRecord(
        id: artifact.id,
        challengeRequestId: artifact.challengeRequestId,
        providerScope: artifact.providerScope,
        origin: artifact.origin,
        kind: artifact.kind,
        name: artifact.name,
        valueReference: artifact.valueReference,
        capturedAt: artifact.capturedAt,
        state: StoredWebViewSessionArtifactState.revoked,
        domain: artifact.domain,
        path: artifact.path,
        expiresAt: artifact.expiresAt,
        secure: artifact.secure,
        httpOnly: artifact.httpOnly,
        sameSite: artifact.sameSite,
        revokedAt: revokedAt,
        metadata: artifact.metadata,
      );
    }
    return Future<void>.value();
  }

  @override
  Future<void> storeArtifacts(
      Iterable<StoredWebViewSessionArtifactRecord> artifacts) {
    for (final StoredWebViewSessionArtifactRecord artifact in artifacts) {
      _artifactsById[artifact.id] = artifact;
    }
    return Future<void>.value();
  }

  @override
  Future<void> storeCapability(
      StoredWebViewSessionCapabilityRecord capability) {
    _capabilities[_key(capability.providerScope, capability.capability)] =
        capability;
    return Future<void>.value();
  }

  @override
  Future<StoredManualChallengeRequestRecord> storeChallengeRequest(
      StoredManualChallengeRequestRecord request) {
    _requestsById[request.id] = request;
    return Future<StoredManualChallengeRequestRecord>.value(request);
  }

  @override
  Future<void> updateChallengeState({
    required String id,
    required StoredManualChallengeState state,
    String? reason,
  }) {
    final StoredManualChallengeRequestRecord? request = _requestsById[id];
    if (request != null) {
      _requestsById[id] = StoredManualChallengeRequestRecord(
        id: request.id,
        providerScope: request.providerScope,
        origin: request.origin,
        challengeUri: request.challengeUri,
        kind: request.kind,
        state: state,
        requestedAt: request.requestedAt,
        reason: reason ?? request.reason,
        metadata: request.metadata,
      );
    }
    return Future<void>.value();
  }

  static bool _isActive(
      StoredWebViewSessionArtifactRecord artifact, DateTime now) {
    return artifact.state == StoredWebViewSessionArtifactState.approved &&
        artifact.revokedAt == null &&
        (artifact.expiresAt == null || artifact.expiresAt!.isAfter(now));
  }

  static String _key(String providerScope, String capability) =>
      '$providerScope::$capability';
}
