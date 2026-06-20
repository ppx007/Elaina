import '../../foundation/gateway/provider_gateway.dart';

const ProviderId dandanplayProviderId = ProviderId('dandanplay');

ProviderRegistration dandanplayProviderRegistration() {
  return const ProviderRegistration(
    providerId: dandanplayProviderId,
    ratePolicy:
        ProviderRatePolicy(maxRequests: 4, window: Duration(seconds: 1)),
    retryPolicy: ProviderRetryPolicy(
        maxAttempts: 3, initialBackoff: Duration(milliseconds: 500)),
    negativeCachePolicy: ProviderNegativeCachePolicy(ttl: Duration(minutes: 3)),
  );
}
