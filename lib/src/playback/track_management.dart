import 'capability_matrix.dart';

final class MediaTrackId {
  const MediaTrackId(this.value)
      : assert(value != '', 'Track id must not be empty.');

  final String value;
}

enum MediaTrackType {
  audio,
  subtitle,
}

final class MediaTrackDescriptor {
  const MediaTrackDescriptor({
    required this.id,
    required this.type,
    required this.label,
    this.languageCode,
    this.isSelected = false,
  });

  final MediaTrackId id;
  final MediaTrackType type;
  final String label;
  final String? languageCode;
  final bool isSelected;
}

final class TrackDiscoveryResult {
  const TrackDiscoveryResult({
    required this.tracks,
    required this.capabilityMatrix,
  });

  factory TrackDiscoveryResult.unsupported({required String reason}) {
    return TrackDiscoveryResult(
      tracks: const <MediaTrackDescriptor>[],
      capabilityMatrix: PlaybackCapabilityMatrix.unsupported(reason: reason),
    );
  }

  final List<MediaTrackDescriptor> tracks;
  final PlaybackCapabilityMatrix capabilityMatrix;
}

final class TrackSwitchResult {
  const TrackSwitchResult._({this.failure});

  const TrackSwitchResult.success() : this._();

  const TrackSwitchResult.unsupported(String reason) : this._(failure: reason);

  final String? failure;

  bool get isSuccess => failure == null;
}
