import 'player_adapter.dart';

final class VirtualPlaybackStreamId {
  const VirtualPlaybackStreamId(this.value)
      : assert(value != '', 'Virtual playback stream id must not be empty.');

  final String value;
}

final class PlaybackVirtualStreamDescriptor {
  const PlaybackVirtualStreamDescriptor({
    required this.id,
    this.contentUri,
  });

  final VirtualPlaybackStreamId id;
  final Uri? contentUri;
}

final class VirtualStreamPlaybackSource extends PlaybackSource {
  const VirtualStreamPlaybackSource({
    required this.streamId,
    required super.uri,
    super.headers,
  });

  factory VirtualStreamPlaybackSource.fromDescriptor(
      PlaybackVirtualStreamDescriptor descriptor) {
    return VirtualStreamPlaybackSource(
      streamId: descriptor.id,
      uri: descriptor.contentUri ??
          Uri.parse(
              'celesteria-virtual-stream://${Uri.encodeComponent(descriptor.id.value)}'),
    );
  }

  factory VirtualStreamPlaybackSource.fromValues({
    required String streamId,
    Uri? contentUri,
    Map<String, String> headers = const <String, String>{},
  }) {
    return VirtualStreamPlaybackSource(
      streamId: VirtualPlaybackStreamId(streamId),
      uri: contentUri ??
          Uri.parse(
              'celesteria-virtual-stream://${Uri.encodeComponent(streamId)}'),
      headers: headers,
    );
  }

  final VirtualPlaybackStreamId streamId;
}
