import '../../playback/capability_matrix.dart';
import '../../playback/deterministic_mpv_binding.dart';
import '../../playback/mpv_adapter_facade.dart';
import '../../playback/player_adapter.dart';
import '../../playback/player_runtime_composition.dart';
import '../../playback/track_management.dart';
import 'playback_controller.dart';
import 'player_core_runtime.dart';

/// Forbidden dependency terms for Phase 1 player-core runtime files.
const Set<String> playerCoreRuntimeForbiddenDependencies = <String>{
  'package:' 'flutter',
  'dart:' 'ui',
  'lib' 'mpv',
  'media' '-kit',
  'media' '_kit',
  'v' 'lc',
  'exo' 'player',
  'av' 'player',
  'platform' ' channel',
  'src/' 'provider/',
  'src/foundation/' 'storage/',
  'src/' 'streaming/',
  'src/' 'network/',
};

/// Required surface terms for Phase 1 player-core runtime validation.
const Set<String> playerCoreRuntimeRequiredTerms = <String>{
  'PlayerCoreBootstrap',
  'PlayerCoreRuntime',
  'DeterministicMpvBinding',
  'MpvPlayerAdapterFacade',
  'PlaybackCapabilityMatrix',
  'PlaybackControllerContract',
};

/// Phase 1 player-core bootstrap that composes Step 5-8 surfaces.
final class PlayerCoreBootstrap {
  PlayerCoreBootstrap({Object? foundationDependency}) {
    _runtime = PlayerCoreRuntime.unsupported(
      foundationDependency: foundationDependency,
    );
  }

  PlayerCoreBootstrap.withBinding({
    required MpvAdapterBinding binding,
    PlaybackCapabilityMatrix? capabilities,
    Object? foundationDependency,
  }) {
    _runtime = PlayerCoreRuntime.bound(
      binding: binding,
      capabilities: capabilities,
      foundationDependency: foundationDependency,
    );
  }

  PlayerCoreBootstrap.withComposition({
    required PlayerRuntimeCompositionContract composition,
    Object? foundationDependency,
  }) {
    _runtime = PlayerCoreRuntime.bound(
      binding: composition.binding,
      capabilities: composition.capabilities,
      foundationDependency: foundationDependency,
      telemetrySource: composition.telemetrySource,
    );
  }

  PlayerCoreBootstrap.withDependencies({
    required PlayerAdapter activeAdapter,
    Object? foundationDependency,
  }) {
    _runtime = PlayerCoreRuntime(
      activeAdapter: activeAdapter,
      foundationDependency: foundationDependency,
    );
  }

  late final PlayerCoreRuntime _runtime;

  PlayerCoreRuntime get runtime => _runtime;

  PlaybackControllerContract get controller => _runtime.controller;

  PlayerAdapter get activeAdapter => _runtime.activeAdapter;

  bool get isDisposed => _runtime.isDisposed;

  Future<void> dispose() => _runtime.dispose();

  static List<String> findForbiddenTerms(String content) {
    return <String>[
      for (final String term in playerCoreRuntimeForbiddenDependencies)
        if (content.contains(term)) term,
    ];
  }

  static List<String> findMissingRequiredTerms(String content) {
    return <String>[
      for (final String term in playerCoreRuntimeRequiredTerms)
        if (!content.contains(term)) term,
    ];
  }

  /// Creates a deterministic MPV binding for focused tests and runtime checks.
  static DeterministicMpvBinding deterministicBinding({
    List<MediaTrackDescriptor> tracks = const <MediaTrackDescriptor>[],
  }) {
    return DeterministicMpvBinding(tracks: tracks);
  }
}
