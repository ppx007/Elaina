import '../storage/storage_contracts.dart';

final class ProviderId {
  const ProviderId(this.value) : assert(value != '', 'Provider id must not be empty.');

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

final class ProviderGatewayRequest<T> {
  const ProviderGatewayRequest({
    required this.key,
    required this.load,
    this.cachePolicy = ProviderCachePolicy.networkOnly,
    this.deduplicationWindow = Duration.zero,
  });

  final ProviderRequestKey key;
  final Future<T> Function() load;
  final ProviderCachePolicy cachePolicy;
  final Duration deduplicationWindow;
}

enum ProviderCachePolicy {
  networkOnly,
  cacheFirst,
  networkFirst,
  negativeCacheable,
}

final class ProviderGatewayResponse<T> {
  const ProviderGatewayResponse({
    required this.value,
    required this.source,
  });

  final T value;
  final ProviderGatewayResponseSource source;
}

enum ProviderGatewayResponseSource {
  network,
  httpCache,
  semanticCache,
  negativeCache,
}

abstract interface class ProviderGateway {
  StorageFoundation get storage;

  Future<void> registerProvider(ProviderRegistration registration);

  Future<ProviderGatewayResponse<T>> execute<T>(ProviderGatewayRequest<T> request);
}
