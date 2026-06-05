import '../streaming/virtual_media_stream.dart';
import 'player_adapter.dart';

final class VirtualStreamPlaybackSource extends PlaybackSource {
  const VirtualStreamPlaybackSource({
    required this.streamId,
    required super.uri,
    super.headers,
  });

  factory VirtualStreamPlaybackSource.fromDescriptor(
      VirtualMediaStreamDescriptor descriptor) {
    return VirtualStreamPlaybackSource(
      streamId: descriptor.id,
      uri: descriptor.contentUri ??
          Uri.parse(
              'celesteria-virtual-stream://${Uri.encodeComponent(descriptor.id.value)}'),
    );
  }

  final VirtualMediaStreamId streamId;
}
