import '../../playback/subtitle/subtitle_cue.dart';
import '../../playback/subtitle/subtitle_runtime_state.dart';
import '../playback/playback_state.dart';

PlaybackSubtitleStateSnapshot playbackSubtitleStateFromRuntimeSnapshot(
  BasicSubtitleRuntimeSnapshot snapshot,
) {
  return PlaybackSubtitleStateSnapshot(
    availableTracks: <DomainSubtitleTrackDescriptor>[
      for (final SubtitleTrack track in snapshot.loadedTracks)
        DomainSubtitleTrackDescriptor(
          id: track.source.id,
          format: track.source.format.name,
          languageCode: track.source.languageCode,
          title: track.title,
        ),
    ],
    selectedTrackId: snapshot.selectedSource?.id,
    activeCues: <DomainSubtitleCueDescriptor>[
      for (final SubtitleCue cue in snapshot.activeCues)
        DomainSubtitleCueDescriptor(
          start: cue.start,
          end: cue.end,
          text: cue.text,
          id: cue.id,
        ),
    ],
    offset: snapshot.offset.value,
    warnings: snapshot.warnings,
    failureReason: snapshot.failure?.message,
  );
}
