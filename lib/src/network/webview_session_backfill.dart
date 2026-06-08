import '../foundation/gateway/provider_gateway.dart';

final class ManualChallengeRequestId {
  const ManualChallengeRequestId(this.value)
      : assert(value != '', 'Manual challenge request id must not be empty.');

  final String value;
}

final class WebViewSessionArtifactId {
  const WebViewSessionArtifactId(this.value)
      : assert(value != '', 'WebView session artifact id must not be empty.');

  final String value;
}

final class WebViewSessionBackfillAttemptId {
  const WebViewSessionBackfillAttemptId(this.value)
      : assert(value != '', 'WebView session backfill attempt id must not be empty.');

  final String value;
}

final class WebViewSessionProviderTokenId {
  const WebViewSessionProviderTokenId(this.value)
      : assert(value != '', 'WebView session provider token id must not be empty.');

  final String value;
}

enum ManualChallengeKind {
  captcha,
  login,
  ageGate,
  providerInterstitial,
}

enum ManualChallengeState {
  required,
  opened,
  completed,
  captured,
  backfilled,
  expired,
  revoked,
  failed,
}

enum WebViewSessionSameSite {
  strict,
  lax,
  none,
  unspecified,
}

enum WebViewSessionArtifactApprovalState {
  pending,
  approved,
  rejected,
  revoked,
  expired,
}

enum WebViewSessionBackfillFailureKind {
  unsupportedCapability,
  unsupportedOperation,
  rejectedOrigin,
  artifactExpired,
  artifactRevoked,
  artifactRejected,
  missingArtifact,
  gatewayUnavailable,
  networkPolicyBlocked,
  failed,
}

enum UnsupportedWebViewSessionOperationKind {
  automaticCaptchaSolving,
  challengeBypass,
  credentialGuessing,
  botCompletion,
  headlessAutomation,
  hiddenBrowserInteraction,
  sharedProfileCookieAccess,
  crossOriginReuse,
}

enum WebViewSessionCapability {
  isolatedWebView,
  cookieCapture,
  localStorageCapture,
  userAgentCapture,
  sameOriginArtifactCapture,
  providerTokenBackfill,
  persistentSession,
}

final class ManualChallengeRequest {
  const ManualChallengeRequest({
    required this.id,
    required this.providerScope,
    required this.origin,
    required this.challengeUri,
    required this.kind,
    this.state = ManualChallengeState.required,
    this.reason,
    this.requestedAt,
  }) : assert(providerScope != '', 'Manual challenge provider scope must not be empty.');

  final ManualChallengeRequestId id;
  final String providerScope;
  final Uri origin;
  final Uri challengeUri;
  final ManualChallengeKind kind;
  final ManualChallengeState state;
  final String? reason;
  final DateTime? requestedAt;
}

final class SessionCookieArtifact {
  const SessionCookieArtifact({
    required this.id,
    required this.providerScope,
    required this.origin,
    required this.name,
    required this.valueReference,
    required this.domain,
    required this.path,
    required this.capturedAt,
    this.expiresAt,
    this.secure = true,
    this.httpOnly = true,
    this.sameSite = WebViewSessionSameSite.unspecified,
    this.approvalState = WebViewSessionArtifactApprovalState.approved,
    this.revokedAt,
  })  : assert(providerScope != '', 'Session cookie provider scope must not be empty.'),
        assert(name != '', 'Session cookie name must not be empty.'),
        assert(valueReference != '', 'Session cookie value reference must not be empty.'),
        assert(domain != '', 'Session cookie domain must not be empty.'),
        assert(path != '', 'Session cookie path must not be empty.');

  final WebViewSessionArtifactId id;
  final String providerScope;
  final Uri origin;
  final String name;
  final String valueReference;
  final String domain;
  final String path;
  final DateTime? expiresAt;
  final bool secure;
  final bool httpOnly;
  final WebViewSessionSameSite sameSite;
  final DateTime capturedAt;
  final WebViewSessionArtifactApprovalState approvalState;
  final DateTime? revokedAt;

  bool isActiveAt(DateTime now) {
    return approvalState == WebViewSessionArtifactApprovalState.approved &&
        revokedAt == null &&
        (expiresAt == null || expiresAt!.isAfter(now));
  }

  bool isSameOriginFor({required String providerScope, required Uri uri}) {
    return this.providerScope == providerScope &&
        _sameOrigin(origin, uri) &&
        _domainMatches(host: uri.host, domain: domain) &&
        uri.path.startsWith(path == '/' ? '/' : path);
  }
}

final class ProviderSessionTokenArtifact {
  ProviderSessionTokenArtifact({
    required this.id,
    required this.providerScope,
    required this.origin,
    required this.name,
    required this.valueReference,
    required this.capturedAt,
    this.expiresAt,
    this.approvalState = WebViewSessionArtifactApprovalState.approved,
    this.revokedAt,
    Map<String, String> metadata = const <String, String>{},
  })  : assert(providerScope != '', 'Provider token provider scope must not be empty.'),
        assert(name != '', 'Provider token name must not be empty.'),
        assert(valueReference != '', 'Provider token value reference must not be empty.'),
        metadata = Map<String, String>.unmodifiable(metadata);

  final WebViewSessionProviderTokenId id;
  final String providerScope;
  final Uri origin;
  final String name;
  final String valueReference;
  final DateTime capturedAt;
  final DateTime? expiresAt;
  final WebViewSessionArtifactApprovalState approvalState;
  final DateTime? revokedAt;
  final Map<String, String> metadata;

  bool isActiveAt(DateTime now) {
    return approvalState == WebViewSessionArtifactApprovalState.approved &&
        revokedAt == null &&
        (expiresAt == null || expiresAt!.isAfter(now));
  }

  bool isSameOriginFor({required String providerScope, required Uri uri}) {
    return this.providerScope == providerScope && _sameOrigin(origin, uri);
  }
}

final class SessionArtifactBundle {
  SessionArtifactBundle({
    required this.providerScope,
    required this.origin,
    required this.capturedAt,
    Iterable<SessionCookieArtifact> cookies = const <SessionCookieArtifact>[],
    Iterable<ProviderSessionTokenArtifact> providerTokens =
        const <ProviderSessionTokenArtifact>[],
    Map<String, String> localStorage = const <String, String>{},
    Map<String, String> sessionStorage = const <String, String>{},
    this.userAgent,
  })  : assert(providerScope != '', 'Session artifact provider scope must not be empty.'),
        cookies = List<SessionCookieArtifact>.unmodifiable(cookies),
        providerTokens = List<ProviderSessionTokenArtifact>.unmodifiable(providerTokens),
        localStorage = Map<String, String>.unmodifiable(localStorage),
        sessionStorage = Map<String, String>.unmodifiable(sessionStorage);

  final String providerScope;
  final Uri origin;
  final DateTime capturedAt;
  final List<SessionCookieArtifact> cookies;
  final List<ProviderSessionTokenArtifact> providerTokens;
  final Map<String, String> localStorage;
  final Map<String, String> sessionStorage;
  final String? userAgent;

  List<SessionCookieArtifact> activeCookiesFor({
    required Uri uri,
    required DateTime now,
  }) {
    return <SessionCookieArtifact>[
      for (final SessionCookieArtifact cookie in cookies)
        if (cookie.isActiveAt(now) &&
            cookie.isSameOriginFor(providerScope: providerScope, uri: uri))
          cookie,
    ];
  }

  List<ProviderSessionTokenArtifact> activeProviderTokensFor({
    required Uri uri,
    required DateTime now,
  }) {
    return <ProviderSessionTokenArtifact>[
      for (final ProviderSessionTokenArtifact token in providerTokens)
        if (token.isActiveAt(now) &&
            token.isSameOriginFor(providerScope: providerScope, uri: uri))
          token,
    ];
  }
}

final class WebViewSessionCapabilityStatus {
  const WebViewSessionCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const WebViewSessionCapabilityStatus.unsupported(this.reason)
      : supported = false;

  final bool supported;
  final String? reason;
}

final class WebViewSessionCapabilityMatrix {
  WebViewSessionCapabilityMatrix({
    required Map<WebViewSessionCapability, WebViewSessionCapabilityStatus>
        capabilities,
  }) : _capabilities =
            Map<WebViewSessionCapability, WebViewSessionCapabilityStatus>
                .unmodifiable(capabilities);

  factory WebViewSessionCapabilityMatrix.unsupported({required String reason}) {
    return WebViewSessionCapabilityMatrix(
      capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
        for (final WebViewSessionCapability capability
            in WebViewSessionCapability.values)
          capability: WebViewSessionCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<WebViewSessionCapability, WebViewSessionCapabilityStatus>
      _capabilities;

  WebViewSessionCapabilityStatus statusOf(WebViewSessionCapability capability) {
    return _capabilities[capability] ??
        const WebViewSessionCapabilityStatus.unsupported(
            'Capability is not declared.');
  }
}

enum SessionBackfillOutcomeKind {
  captured,
  cancelled,
  unsupported,
  rejectedOrigin,
  rejectedOperation,
  expired,
  revoked,
  failed,
}

final class SessionBackfillOutcome {
  const SessionBackfillOutcome({
    required this.kind,
    required this.message,
    this.artifacts,
    this.failureKind,
    this.unsupportedOperationKind,
  }) : assert(message != '', 'Session backfill outcome message must not be empty.');

  final SessionBackfillOutcomeKind kind;
  final String message;
  final SessionArtifactBundle? artifacts;
  final WebViewSessionBackfillFailureKind? failureKind;
  final UnsupportedWebViewSessionOperationKind? unsupportedOperationKind;
}

final class WebViewSessionBackfillRetryDescriptor {
  WebViewSessionBackfillRetryDescriptor({
    required this.attemptId,
    required this.providerId,
    required this.providerScope,
    required this.requestUri,
    required this.cacheKey,
    required Iterable<SessionCookieArtifact> cookies,
    required Iterable<ProviderSessionTokenArtifact> providerTokens,
    required this.cachePolicy,
    required this.ratePolicy,
    required this.retryPolicy,
    this.negativeCachePolicy,
    this.userAgent,
  })  : assert(providerScope != '', 'Backfill provider scope must not be empty.'),
        assert(cacheKey != '', 'Backfill cache key must not be empty.'),
        cookies = List<SessionCookieArtifact>.unmodifiable(cookies),
        providerTokens =
            List<ProviderSessionTokenArtifact>.unmodifiable(providerTokens);

  final WebViewSessionBackfillAttemptId attemptId;
  final ProviderId providerId;
  final String providerScope;
  final Uri requestUri;
  final String cacheKey;
  final List<SessionCookieArtifact> cookies;
  final List<ProviderSessionTokenArtifact> providerTokens;
  final ProviderCachePolicy cachePolicy;
  final ProviderRatePolicy ratePolicy;
  final ProviderRetryPolicy retryPolicy;
  final ProviderNegativeCachePolicy? negativeCachePolicy;
  final String? userAgent;

  ProviderRegistration get registration {
    return ProviderRegistration(
      providerId: providerId,
      ratePolicy: ratePolicy,
      retryPolicy: retryPolicy,
      negativeCachePolicy: negativeCachePolicy,
    );
  }

  ProviderRequestKey get requestKey {
    return ProviderRequestKey(providerId: providerId, cacheKey: cacheKey);
  }
}

final class WebViewSessionBackfillRetryOutcome {
  const WebViewSessionBackfillRetryOutcome._({this.descriptor, this.failure});

  const WebViewSessionBackfillRetryOutcome.ready({
    required WebViewSessionBackfillRetryDescriptor descriptor,
  }) : this._(descriptor: descriptor);

  const WebViewSessionBackfillRetryOutcome.failure({
    required SessionBackfillOutcome failure,
  }) : this._(failure: failure);

  final WebViewSessionBackfillRetryDescriptor? descriptor;
  final SessionBackfillOutcome? failure;

  bool get isSuccess => failure == null;
}

final class WebViewSessionNetworkPolicyHandoff {
  const WebViewSessionNetworkPolicyHandoff({
    required this.providerScope,
    required this.uri,
    required this.purpose,
    this.redirectedFrom,
    this.failureKind,
    this.reason,
  })  : assert(providerScope != '', 'WebView session provider scope must not be empty.'),
        assert(purpose != '', 'WebView session network purpose must not be empty.');

  final String providerScope;
  final Uri uri;
  final Uri? redirectedFrom;
  final String purpose;
  final WebViewSessionBackfillFailureKind? failureKind;
  final String? reason;
}

final class WebViewSessionBackfillDescriptorFactory {
  const WebViewSessionBackfillDescriptorFactory();

  SessionBackfillOutcome validateManualOperation(String operation) {
    final String normalized = operation.toLowerCase();
    if (normalized.contains('captcha') && normalized.contains('solve')) {
      return const SessionBackfillOutcome(
        kind: SessionBackfillOutcomeKind.rejectedOperation,
        message: 'Automatic captcha solving is not supported.',
        failureKind: WebViewSessionBackfillFailureKind.unsupportedOperation,
        unsupportedOperationKind:
            UnsupportedWebViewSessionOperationKind.automaticCaptchaSolving,
      );
    }
    if (normalized.contains('bypass')) {
      return const SessionBackfillOutcome(
        kind: SessionBackfillOutcomeKind.rejectedOperation,
        message: 'Challenge bypass is not supported.',
        failureKind: WebViewSessionBackfillFailureKind.unsupportedOperation,
        unsupportedOperationKind:
            UnsupportedWebViewSessionOperationKind.challengeBypass,
      );
    }
    if (normalized.contains('headless')) {
      return const SessionBackfillOutcome(
        kind: SessionBackfillOutcomeKind.rejectedOperation,
        message: 'Headless challenge automation is not supported.',
        failureKind: WebViewSessionBackfillFailureKind.unsupportedOperation,
        unsupportedOperationKind:
            UnsupportedWebViewSessionOperationKind.headlessAutomation,
      );
    }
    return const SessionBackfillOutcome(
      kind: SessionBackfillOutcomeKind.captured,
      message: 'Manual operation is supported.',
    );
  }

  WebViewSessionBackfillRetryOutcome retryDescriptor({
    required WebViewSessionBackfillAttemptId attemptId,
    required ProviderId providerId,
    required String providerScope,
    required Uri requestUri,
    required String cacheKey,
    required SessionArtifactBundle artifacts,
    required DateTime now,
    required ProviderRatePolicy ratePolicy,
    required ProviderRetryPolicy retryPolicy,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkFirst,
    ProviderNegativeCachePolicy? negativeCachePolicy,
  }) {
    if (artifacts.providerScope != providerScope ||
        !_sameOrigin(artifacts.origin, requestUri)) {
      return const WebViewSessionBackfillRetryOutcome.failure(
        failure: SessionBackfillOutcome(
          kind: SessionBackfillOutcomeKind.rejectedOrigin,
          message: 'Captured session artifacts do not match the retry origin.',
          failureKind: WebViewSessionBackfillFailureKind.rejectedOrigin,
        ),
      );
    }
    final List<SessionCookieArtifact> cookies =
        artifacts.activeCookiesFor(uri: requestUri, now: now);
    final List<ProviderSessionTokenArtifact> tokens =
        artifacts.activeProviderTokensFor(uri: requestUri, now: now);
    if (cookies.isEmpty && tokens.isEmpty) {
      return const WebViewSessionBackfillRetryOutcome.failure(
        failure: SessionBackfillOutcome(
          kind: SessionBackfillOutcomeKind.expired,
          message: 'No active same-origin session artifacts are available.',
          failureKind: WebViewSessionBackfillFailureKind.missingArtifact,
        ),
      );
    }
    return WebViewSessionBackfillRetryOutcome.ready(
      descriptor: WebViewSessionBackfillRetryDescriptor(
        attemptId: attemptId,
        providerId: providerId,
        providerScope: providerScope,
        requestUri: requestUri,
        cacheKey: cacheKey,
        cookies: cookies,
        providerTokens: tokens,
        cachePolicy: cachePolicy,
        ratePolicy: ratePolicy,
        retryPolicy: retryPolicy,
        negativeCachePolicy: negativeCachePolicy,
        userAgent: artifacts.userAgent,
      ),
    );
  }
}

abstract interface class WebViewSessionBackfill {
  WebViewSessionCapabilityMatrix get capabilities;

  Future<SessionBackfillOutcome> completeManually(
      ManualChallengeRequest request);
}

abstract interface class ProviderSessionBackfill {
  Future<void> applySessionArtifacts(SessionArtifactBundle artifacts);
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

bool _domainMatches({required String host, required String domain}) {
  final String normalizedHost = host.toLowerCase();
  final String loweredDomain = domain.toLowerCase();
  final String normalizedDomain = loweredDomain.startsWith('.')
      ? loweredDomain.substring(1)
      : loweredDomain;
  return normalizedHost == normalizedDomain ||
      normalizedHost.endsWith('.$normalizedDomain');
}
