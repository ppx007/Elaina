import 'av_sync_sample_source.dart';
import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_adapter.dart';
import 'player_telemetry.dart';

/// Contract-safe runtime composition inputs for app composition roots.
///
/// Concrete Playback implementations create this descriptor. Domain bootstrap
/// code consumes it without importing concrete player packages.
final class PlayerRuntimeCompositionContract {
  const PlayerRuntimeCompositionContract({
    required this.adapter,
    required this.capabilities,
    this.binding,
    this.telemetrySource,
    this.capabilityProbeSource,
    this.avSyncSampleSource,
  });

  final PlayerAdapter adapter;

  /// Compatibility seam for MPV-specific application services such as
  /// Anime4K shader updates and the media-kit video controller.
  ///
  /// Player core must consume [adapter]. Composition roots may still keep this
  /// reference while MPV owns features that no fallback backend can implement.
  final MpvAdapterBinding? binding;
  final PlaybackCapabilityMatrix capabilities;
  final PlayerTelemetrySource? telemetrySource;
  final PlaybackCapabilityProbeSource? capabilityProbeSource;
  final AVSyncSampleSource? avSyncSampleSource;
}
