import '../player_clock.dart';
import 'subtitle_cue.dart';

final class SubtitleOffset {
  const SubtitleOffset(this.value);

  final Duration value;

  Duration applyTo(Duration playerClockPosition) {
    return playerClockPosition + value;
  }
}

final class SubtitleCueResolver {
  const SubtitleCueResolver({required this.offset});

  final SubtitleOffset offset;

  List<SubtitleCue> activeCues({
    required SubtitleTrack track,
    required PlayerClockSnapshot clock,
  }) {
    final Duration shiftedPosition = offset.applyTo(clock.position);
    return <SubtitleCue>[
      for (final SubtitleCue cue in track.cues)
        if (cue.isActiveAt(shiftedPosition)) cue,
    ];
  }
}
