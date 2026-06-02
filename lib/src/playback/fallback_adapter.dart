import 'capability_matrix.dart';
import 'player_adapter.dart';

final class FallbackAdapterId {
  const FallbackAdapterId(this.value) : assert(value != '', 'Fallback adapter id must not be empty.');

  final String value;
}

enum FallbackFailureKind {
  loadFailure,
  unsupportedCodec,
  unsupportedContainer,
  adapterCrashed,
}

final class FallbackFailure {
  const FallbackFailure({required this.kind, required this.message});

  final FallbackFailureKind kind;
  final String message;
}

final class FallbackAdapterCandidate {
  const FallbackAdapterCandidate({required this.id, required this.adapter, required this.capabilities});

  final FallbackAdapterId id;
  final PlayerAdapter adapter;
  final PlaybackCapabilityMatrix capabilities;
}

final class FallbackSelection {
  FallbackSelection({
    required this.candidate,
    required Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities,
    required this.reason,
  }) : hiddenCapabilities = Map<PlaybackCapability, CapabilityStatus>.unmodifiable(hiddenCapabilities);

  final FallbackAdapterCandidate candidate;
  final Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities;
  final String reason;
}

abstract interface class PlaybackFallbackStrategy {
  Future<void> register(FallbackAdapterCandidate candidate);

  Future<FallbackSelection?> selectFallback({required PlaybackSource source, required FallbackFailure failure});
}
