abstract interface class PlayerClock {
  Stream<PlayerClockSnapshot> get snapshots;

  PlayerClockSnapshot get current;

  Future<void> seek(Duration position);
}

final class PlayerClockSnapshot {
  const PlayerClockSnapshot({
    required this.position,
    required this.isPlaying,
    required this.playbackSpeed,
  }) : assert(playbackSpeed > 0, 'playbackSpeed must be positive.');

  final Duration position;
  final bool isPlaying;
  final double playbackSpeed;
}
