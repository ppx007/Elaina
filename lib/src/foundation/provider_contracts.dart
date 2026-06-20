/// Shared provider value contracts.
///
/// These pure value objects form a cross-cutting kernel used by both the
/// `gateway` layer (request governance) and the `network` layer (policy
/// handoff descriptors).  They live directly under `foundation` — not under
/// `gateway/` — so neither layer has to depend on the other to reference them.
library;

const ProviderRatePolicy unavailableProviderRatePolicy =
    ProviderRatePolicy(maxRequests: 1, window: Duration(seconds: 1));
const ProviderRetryPolicy unavailableProviderRetryPolicy = ProviderRetryPolicy(
    maxAttempts: 1, initialBackoff: Duration(milliseconds: 1));

final class ProviderId {
  const ProviderId(this.value)
      : assert(value != '', 'Provider id must not be empty.');

  final String value;
}

final class ProviderRequestKey {
  const ProviderRequestKey({required this.providerId, required this.cacheKey});

  final ProviderId providerId;
  final String cacheKey;
}

final class ProviderRatePolicy {
  const ProviderRatePolicy({
    required this.maxRequests,
    required this.window,
  }) : assert(maxRequests > 0, 'maxRequests must be positive.');

  final int maxRequests;
  final Duration window;
}

final class ProviderRetryPolicy {
  const ProviderRetryPolicy({
    required this.maxAttempts,
    required this.initialBackoff,
  }) : assert(maxAttempts > 0, 'maxAttempts must be positive.');

  final int maxAttempts;
  final Duration initialBackoff;
}

final class ProviderNegativeCachePolicy {
  const ProviderNegativeCachePolicy({required this.ttl});

  final Duration ttl;
}

final class ProviderRegistration {
  const ProviderRegistration({
    required this.providerId,
    required this.ratePolicy,
    required this.retryPolicy,
    this.negativeCachePolicy,
  });

  final ProviderId providerId;
  final ProviderRatePolicy ratePolicy;
  final ProviderRetryPolicy retryPolicy;
  final ProviderNegativeCachePolicy? negativeCachePolicy;
}

enum ProviderFailureKind {
  retryable,
  throttled,
  cachedMiss,
  terminal,
}

final class ProviderFailure implements Exception {
  const ProviderFailure({required this.kind, required this.message});

  final ProviderFailureKind kind;
  final String message;
}

enum ProviderCachePolicy {
  networkOnly,
  cacheFirst,
  networkFirst,
  negativeCacheable,
}
