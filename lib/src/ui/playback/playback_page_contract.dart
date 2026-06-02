import '../../domain/playback/playback_controller.dart';

final class PlaybackPageContract {
  const PlaybackPageContract({required PlaybackController controller}) : _controller = controller;

  final PlaybackController _controller;

  PlaybackSurfaceState resolveState() => _controller.resolveSurfaceState();
}
