import '../foundation/gateway/provider_gateway.dart';

sealed class AcgProviderResult<T> {
  const AcgProviderResult();
}

final class AcgProviderSuccess<T> extends AcgProviderResult<T> {
  const AcgProviderSuccess(this.value);

  final T value;
}

final class AcgProviderFailure<T> extends AcgProviderResult<T> {
  const AcgProviderFailure({required this.kind, required this.message});

  final AcgProviderFailureKind kind;
  final String message;
}

enum AcgProviderFailureKind {
  unavailable,
  unauthenticated,
  retryable,
  throttled,
  cachedMiss,
  notFound,
  terminal,
}

AcgProviderFailureKind acgFailureKindFromGateway(ProviderFailureKind kind) {
  return switch (kind) {
    ProviderFailureKind.retryable => AcgProviderFailureKind.retryable,
    ProviderFailureKind.throttled => AcgProviderFailureKind.throttled,
    ProviderFailureKind.cachedMiss => AcgProviderFailureKind.cachedMiss,
    ProviderFailureKind.terminal => AcgProviderFailureKind.terminal,
  };
}
