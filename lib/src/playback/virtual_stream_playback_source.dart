import '../streaming/virtual_media_stream.dart';
import 'player_adapter.dart';

final class VirtualStreamPlaybackSource extends PlaybackSource {
  const VirtualStreamPlaybackSource({
    required this.streamId,
    required super.uri,
    super.headers,
  });

  final VirtualMediaStreamId streamId;
}
