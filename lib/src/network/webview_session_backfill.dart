final class ManualChallengeRequestId {
  const ManualChallengeRequestId(this.value) : assert(value != '', 'Manual challenge request id must not be empty.');

  final String value;
}

enum ManualChallengeKind {
  captcha,
  login,
  ageGate,
  providerInterstitial,
}

enum WebViewSessionCapability {
  isolatedWebView,
  cookieCapture,
  localStorageCapture,
  userAgentCapture,
}

final class ManualChallengeRequest {
  const ManualChallengeRequest({
    required this.id,
    required this.providerScope,
    required this.origin,
    required this.challengeUri,
    required this.kind,
  }) : assert(providerScope != '', 'Manual challenge provider scope must not be empty.');

  final ManualChallengeRequestId id;
  final String providerScope;
  final Uri origin;
  final Uri challengeUri;
  final ManualChallengeKind kind;
}

final class SessionCookieArtifact {
  const SessionCookieArtifact({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.expiresAt,
    this.secure = true,
    this.httpOnly = true,
    this.sameSite,
  })  : assert(name != '', 'Session cookie name must not be empty.'),
        assert(domain != '', 'Session cookie domain must not be empty.'),
        assert(path != '', 'Session cookie path must not be empty.');

  final String name;
  final String value;
  final String domain;
  final String path;
  final DateTime? expiresAt;
  final bool secure;
  final bool httpOnly;
  final String? sameSite;
}

final class SessionArtifactBundle {
  SessionArtifactBundle({
    required this.providerScope,
    required this.origin,
    required this.capturedAt,
    Iterable<SessionCookieArtifact> cookies = const <SessionCookieArtifact>[],
    Map<String, String> localStorage = const <String, String>{},
    Map<String, String> sessionStorage = const <String, String>{},
    this.userAgent,
  })  : assert(providerScope != '', 'Session artifact provider scope must not be empty.'),
        cookies = List<SessionCookieArtifact>.unmodifiable(cookies),
        localStorage = Map<String, String>.unmodifiable(localStorage),
        sessionStorage = Map<String, String>.unmodifiable(sessionStorage);

  final String providerScope;
  final Uri origin;
  final DateTime capturedAt;
  final List<SessionCookieArtifact> cookies;
  final Map<String, String> localStorage;
  final Map<String, String> sessionStorage;
  final String? userAgent;
}

final class WebViewSessionCapabilityStatus {
  const WebViewSessionCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const WebViewSessionCapabilityStatus.unsupported(this.reason) : supported = false;

  final bool supported;
  final String? reason;
}

final class WebViewSessionCapabilityMatrix {
  WebViewSessionCapabilityMatrix({required Map<WebViewSessionCapability, WebViewSessionCapabilityStatus> capabilities})
      : _capabilities = Map<WebViewSessionCapability, WebViewSessionCapabilityStatus>.unmodifiable(capabilities);

  factory WebViewSessionCapabilityMatrix.unsupported({required String reason}) {
    return WebViewSessionCapabilityMatrix(
      capabilities: <WebViewSessionCapability, WebViewSessionCapabilityStatus>{
        for (final WebViewSessionCapability capability in WebViewSessionCapability.values)
          capability: WebViewSessionCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<WebViewSessionCapability, WebViewSessionCapabilityStatus> _capabilities;

  WebViewSessionCapabilityStatus statusOf(WebViewSessionCapability capability) {
    return _capabilities[capability] ?? const WebViewSessionCapabilityStatus.unsupported('Capability is not declared.');
  }
}

enum SessionBackfillOutcomeKind {
  captured,
  cancelled,
  unsupported,
  rejectedOrigin,
  failed,
}

final class SessionBackfillOutcome {
  const SessionBackfillOutcome({required this.kind, required this.message, this.artifacts})
      : assert(message != '', 'Session backfill outcome message must not be empty.');

  final SessionBackfillOutcomeKind kind;
  final String message;
  final SessionArtifactBundle? artifacts;
}

abstract interface class WebViewSessionBackfill {
  WebViewSessionCapabilityMatrix get capabilities;

  Future<SessionBackfillOutcome> completeManually(ManualChallengeRequest request);
}

abstract interface class ProviderSessionBackfill {
  Future<void> applySessionArtifacts(SessionArtifactBundle artifacts);
}
