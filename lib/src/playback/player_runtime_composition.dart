import 'av_sync_sample_source.dart';
import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_telemetry.dart';

/// Contract-safe runtime composition inputs for app composition roots.
///
/// Concrete Playback implementations create this descriptor. Domain bootstrap
/// code consumes it without importing concrete player packages.
final class PlayerRuntimeCompositionContract {
  const PlayerRuntimeCompositionContract({
    required this.binding,
    required this.capabilities,
    this.telemetrySource,
    this.capabilityProbeSource,
    this.avSyncSampleSource,
  });

  final MpvAdapterBinding binding;
  final PlaybackCapabilityMatrix capabilities;
  final PlayerTelemetrySource? telemetrySource;
  final PlaybackCapabilityProbeSource? capabilityProbeSource;
  final AVSyncSampleSource? avSyncSampleSource;
}
