import '../foundation/extension_points.dart';
import '../foundation/gateway/provider_gateway.dart';

abstract interface class GatewayBoundProvider implements ProviderContract {
  ProviderGateway get gateway;

  ProviderRegistration get registration;

  ProviderRequestKey requestKey(String cacheKey);

  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  });
}
