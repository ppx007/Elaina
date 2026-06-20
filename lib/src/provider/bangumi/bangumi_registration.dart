import '../../foundation/gateway/provider_gateway.dart';

const ProviderId bangumiProviderId = ProviderId('bangumi');

ProviderRegistration bangumiProviderRegistration() {
  return const ProviderRegistration(
    providerId: bangumiProviderId,
    ratePolicy:
        ProviderRatePolicy(maxRequests: 6, window: Duration(seconds: 1)),
    retryPolicy: ProviderRetryPolicy(
        maxAttempts: 3, initialBackoff: Duration(milliseconds: 300)),
    negativeCachePolicy: ProviderNegativeCachePolicy(ttl: Duration(minutes: 5)),
  );
}
