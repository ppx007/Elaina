import '../provider_contracts.dart';
import '../storage/storage_contracts.dart';

// Provider value contracts are a shared kernel; re-export them so existing
// `provider_gateway.dart` importers keep working unchanged.
export '../provider_contracts.dart';

final class ProviderDiagnosticsCorrelationDescriptor {
  const ProviderDiagnosticsCorrelationDescriptor({
    required this.providerId,
    required this.requestKey,
    required this.cachePolicy,
    required this.correlationId,
    this.failureKind,
    this.failureMessage,
    this.networkPolicyFailureKind,
    this.networkPolicyEvaluationId,
  });

  final ProviderId providerId;
  final ProviderRequestKey requestKey;
  final ProviderCachePolicy cachePolicy;
  final String correlationId;
  final ProviderFailureKind? failureKind;
  final String? failureMessage;
  final String? networkPolicyFailureKind;
  final String? networkPolicyEvaluationId;
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

  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request);
}
