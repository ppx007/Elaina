import '../../foundation/gateway/provider_gateway.dart';
import 'subtitle_provider.dart';

ProviderRegistration subtitleProviderRegistration({
  required SubtitleProviderId providerId,
  ProviderRatePolicy ratePolicy = const ProviderRatePolicy(maxRequests: 20, window: Duration(minutes: 1)),
  ProviderRetryPolicy retryPolicy = const ProviderRetryPolicy(maxAttempts: 3, initialBackoff: Duration(seconds: 1)),
  ProviderNegativeCachePolicy? negativeCachePolicy = const ProviderNegativeCachePolicy(ttl: Duration(minutes: 10)),
}) {
  return ProviderRegistration(
    providerId: ProviderId(providerId.value),
    ratePolicy: ratePolicy,
    retryPolicy: retryPolicy,
    negativeCachePolicy: negativeCachePolicy,
  );
}
