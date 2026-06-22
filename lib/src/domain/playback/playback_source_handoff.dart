// Playback source handoff is the domain boundary for opening local files,
// virtual streams, and detail-page media in the player controller.
import '../../playback/player_adapter.dart';
import '../../playback/virtual_stream_playback_source.dart';
import '../media/media_library.dart';

sealed class PlaybackSourceHandoffInput {
  const PlaybackSourceHandoffInput();

  const factory PlaybackSourceHandoffInput.localMediaIdentity(
      LocalMediaIdentity identity) = LocalMediaIdentityHandoffInput;

  const factory PlaybackSourceHandoffInput.mediaScanCandidate(
      MediaScanCandidate candidate) = MediaScanCandidateHandoffInput;

  const factory PlaybackSourceHandoffInput.virtualStreamSource(
      VirtualStreamPlaybackSource source) = VirtualStreamSourceHandoffInput;

  const factory PlaybackSourceHandoffInput.virtualStreamDescriptor(
          PlaybackVirtualStreamDescriptor descriptor) =
      VirtualStreamDescriptorHandoffInput;

  const factory PlaybackSourceHandoffInput.unsupportedSource(Object value) =
      UnsupportedPlaybackSourceHandoffInput;
}

final class LocalMediaIdentityHandoffInput extends PlaybackSourceHandoffInput {
  const LocalMediaIdentityHandoffInput(this.identity);

  final LocalMediaIdentity identity;
}

final class MediaScanCandidateHandoffInput extends PlaybackSourceHandoffInput {
  const MediaScanCandidateHandoffInput(this.candidate);

  final MediaScanCandidate candidate;
}

final class VirtualStreamSourceHandoffInput extends PlaybackSourceHandoffInput {
  const VirtualStreamSourceHandoffInput(this.source);

  final VirtualStreamPlaybackSource source;
}

final class VirtualStreamDescriptorHandoffInput
    extends PlaybackSourceHandoffInput {
  const VirtualStreamDescriptorHandoffInput(this.descriptor);

  final PlaybackVirtualStreamDescriptor descriptor;
}

final class UnsupportedPlaybackSourceHandoffInput
    extends PlaybackSourceHandoffInput {
  const UnsupportedPlaybackSourceHandoffInput(this.value);

  final Object value;
}

enum PlaybackSourceHandoffFailureKind {
  missingSourceData,
  unsupportedScheme,
  unsupportedSource,
}

final class PlaybackSourceHandoffFailure {
  const PlaybackSourceHandoffFailure({
    required this.kind,
    required this.message,
    this.uri,
  }) : assert(message != '',
            'Playback source handoff failure message must not be empty.');

  final PlaybackSourceHandoffFailureKind kind;
  final String message;
  final Uri? uri;
}

final class PlaybackSourceHandoffResult {
  const PlaybackSourceHandoffResult._({this.source, this.failure});

  const PlaybackSourceHandoffResult.success(PlaybackSource source)
      : this._(source: source);

  const PlaybackSourceHandoffResult.failure(
      PlaybackSourceHandoffFailure failure)
      : this._(failure: failure);

  final PlaybackSource? source;
  final PlaybackSourceHandoffFailure? failure;

  bool get isSuccess => source != null;
}

abstract interface class PlaybackSourceHandoffContract {
  PlaybackSourceHandoffResult prepare(PlaybackSourceHandoffInput input);
}

final class LocalPlaybackSourceHandoff
    implements PlaybackSourceHandoffContract {
  const LocalPlaybackSourceHandoff();

  @override
  PlaybackSourceHandoffResult prepare(PlaybackSourceHandoffInput input) {
    if (input case VirtualStreamSourceHandoffInput(:final source)) {
      return PlaybackSourceHandoffResult.success(source);
    }

    if (input case VirtualStreamDescriptorHandoffInput(:final descriptor)) {
      return PlaybackSourceHandoffResult.success(
          VirtualStreamPlaybackSource.fromDescriptor(descriptor));
    }

    if (input case UnsupportedPlaybackSourceHandoffInput()) {
      return const PlaybackSourceHandoffResult.failure(
        PlaybackSourceHandoffFailure(
          kind: PlaybackSourceHandoffFailureKind.unsupportedSource,
          message: 'Unsupported playback source handoff input.',
        ),
      );
    }

    final LocalMediaIdentity identity = switch (input) {
      LocalMediaIdentityHandoffInput(:final identity) => identity,
      MediaScanCandidateHandoffInput(:final candidate) => candidate.identity,
      VirtualStreamSourceHandoffInput() => throw StateError('Handled above.'),
      VirtualStreamDescriptorHandoffInput() =>
        throw StateError('Handled above.'),
      UnsupportedPlaybackSourceHandoffInput() =>
        throw StateError('Handled above.'),
    };

    final Uri uri = identity.uri;
    if (uri.toString().isEmpty) {
      return const PlaybackSourceHandoffResult.failure(
        PlaybackSourceHandoffFailure(
          kind: PlaybackSourceHandoffFailureKind.missingSourceData,
          message: 'Selected local media does not include a source URI.',
        ),
      );
    }

    if (!uri.isScheme('file')) {
      return PlaybackSourceHandoffResult.failure(
        PlaybackSourceHandoffFailure(
          kind: PlaybackSourceHandoffFailureKind.unsupportedScheme,
          message: 'Only file URI playback source handoff is supported.',
          uri: uri,
        ),
      );
    }

    return PlaybackSourceHandoffResult.success(
        LocalFilePlaybackSource(uri: uri));
  }
}
