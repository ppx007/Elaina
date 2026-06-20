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
    this.loadWithContext,
    this.cachePolicy = ProviderCachePolicy.networkOnly,
    this.deduplicationWindow = Duration.zero,
    this.networkPolicyUri,
    this.networkPolicyProviderScope,
    this.redirectedFrom,
  });

  final ProviderRequestKey key;
  final Future<T> Function() load;
  final Future<T> Function(ProviderGatewayRequestContext context)?
      loadWithContext;
  final ProviderCachePolicy cachePolicy;
  final Duration deduplicationWindow;
  final Uri? networkPolicyUri;
  final String? networkPolicyProviderScope;
  final Uri? redirectedFrom;

  String get resolvedNetworkPolicyProviderScope =>
      networkPolicyProviderScope ?? key.providerId.value;

  Future<T> executeLoad(ProviderGatewayRequestContext context) {
    final Future<T> Function(ProviderGatewayRequestContext context)? loader =
        loadWithContext;
    if (loader != null) return loader(context);
    return load();
  }
}

final class ProviderGatewayRequestContext {
  const ProviderGatewayRequestContext({this.proxyUrl});

  final String? proxyUrl;
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
