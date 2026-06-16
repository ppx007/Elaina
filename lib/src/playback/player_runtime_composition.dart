import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';

/// Contract-safe runtime composition inputs for app composition roots.
///
/// Concrete Playback implementations create this descriptor. Domain bootstrap
/// code consumes it without importing concrete player packages.
final class PlayerRuntimeCompositionContract {
  const PlayerRuntimeCompositionContract({
    required this.binding,
    required this.capabilities,
  });

  final MpvAdapterBinding binding;
  final PlaybackCapabilityMatrix capabilities;
}
