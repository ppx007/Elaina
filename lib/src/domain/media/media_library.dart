final class LocalMediaId {
  const LocalMediaId(this.value) : assert(value != '', 'Local media id must not be empty.');

  final String value;
}

final class MediaScanId {
  const MediaScanId(this.value) : assert(value != '', 'Media scan id must not be empty.');

  final String value;
}

final class MediaLibraryItemId {
  const MediaLibraryItemId(this.value) : assert(value != '', 'Media library item id must not be empty.');

  final String value;
}

final class MediaFileFingerprint {
  const MediaFileFingerprint({required this.algorithm, required this.value})
      : assert(algorithm != '', 'Fingerprint algorithm must not be empty.'),
        assert(value != '', 'Fingerprint value must not be empty.');

  final String algorithm;
  final String value;
}

final class LocalMediaIdentity {
  const LocalMediaIdentity({
    required this.id,
    required this.uri,
    required this.basename,
    this.fingerprint,
  }) : assert(basename != '', 'Media basename must not be empty.');

  final LocalMediaId id;
  final Uri uri;
  final String basename;
  final MediaFileFingerprint? fingerprint;
}

final class MediaScanScope {
  const MediaScanScope({
    required this.roots,
    required this.extensions,
    this.recursive = true,
    this.excludePatterns = const <String>[],
  }) : assert(roots.length > 0, 'Media scan scope must include at least one root.');

  final List<Uri> roots;
  final Set<String> extensions;
  final bool recursive;
  final List<String> excludePatterns;
}

final class MediaScanCandidate {
  const MediaScanCandidate({
    required this.identity,
    required this.sizeBytes,
    this.duration,
    this.discoveredAt,
  }) : assert(sizeBytes >= 0, 'sizeBytes must not be negative.');

  final LocalMediaIdentity identity;
  final int sizeBytes;
  final Duration? duration;
  final DateTime? discoveredAt;
}

final class MediaLibraryItem {
  const MediaLibraryItem({
    required this.id,
    required this.identity,
    required this.addedAt,
    this.duration,
    this.binding,
  });

  final MediaLibraryItemId id;
  final LocalMediaIdentity identity;
  final DateTime addedAt;
  final Duration? duration;
  final ProviderBinding? binding;
}

abstract interface class MediaLibraryScanner {
  Future<MediaScanResult> scan(MediaScanScope scope);

  Stream<MediaScanEvent> watch(MediaScanId scanId);

  Future<void> cancel(MediaScanId scanId);
}

final class MediaScanResult {
  const MediaScanResult({
    required this.scanId,
    required this.candidates,
    this.failures = const <MediaScanFailure>[],
  });

  final MediaScanId scanId;
  final List<MediaScanCandidate> candidates;
  final List<MediaScanFailure> failures;
}

final class MediaScanFailure {
  const MediaScanFailure({required this.uri, required this.message});

  final Uri uri;
  final String message;
}

sealed class MediaScanEvent {
  const MediaScanEvent({required this.scanId});

  final MediaScanId scanId;
}

final class MediaScanCandidateDiscovered extends MediaScanEvent {
  const MediaScanCandidateDiscovered({required super.scanId, required this.candidate});

  final MediaScanCandidate candidate;
}

final class MediaScanProgressChanged extends MediaScanEvent {
  const MediaScanProgressChanged({required super.scanId, required this.scannedCount});

  final int scannedCount;
}

final class MediaScanCompleted extends MediaScanEvent {
  const MediaScanCompleted({required super.scanId, required this.result});

  final MediaScanResult result;
}

final class MediaScanFailed extends MediaScanEvent {
  const MediaScanFailed({required super.scanId, required this.failure});

  final MediaScanFailure failure;
}

final class PlaybackHistoryEntryId {
  const PlaybackHistoryEntryId(this.value) : assert(value != '', 'Playback history entry id must not be empty.');

  final String value;
}

final class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.id,
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  })  : assert(position >= Duration.zero, 'position must not be negative.'),
        assert(duration >= Duration.zero, 'duration must not be negative.');

  final PlaybackHistoryEntryId id;
  final LocalMediaId mediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
}

final class ContinueWatchingState {
  const ContinueWatchingState({
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  })  : assert(position >= Duration.zero, 'position must not be negative.'),
        assert(duration >= Duration.zero, 'duration must not be negative.');

  final LocalMediaId mediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get progress {
    if (duration == Duration.zero) {
      return 0;
    }
    final ratio = position.inMilliseconds / duration.inMilliseconds;
    return ratio.clamp(0, 1).toDouble();
  }
}

abstract interface class PlaybackHistoryStore {
  Future<void> record(PlaybackHistoryEntry entry);

  Future<PlaybackHistoryEntry?> latestFor(LocalMediaId mediaId);

  Future<List<ContinueWatchingState>> continueWatching({int limit = 20});
}

enum ProviderBindingAuthority {
  automatic,
  userConfirmed,
}

final class ProviderBindingId {
  const ProviderBindingId(this.value) : assert(value != '', 'Provider binding id must not be empty.');

  final String value;
}

final class ProviderSubjectId {
  const ProviderSubjectId(this.value) : assert(value != '', 'Provider subject id must not be empty.');

  final String value;
}

final class ProviderBinding {
  const ProviderBinding({
    required this.id,
    required this.localMediaId,
    required this.providerId,
    required this.subjectId,
    required this.authority,
    required this.confidence,
    required this.createdAt,
  }) : assert(confidence >= 0 && confidence <= 1, 'confidence must be between 0 and 1.');

  final ProviderBindingId id;
  final LocalMediaId localMediaId;
  final String providerId;
  final ProviderSubjectId? subjectId;
  final ProviderBindingAuthority authority;
  final double confidence;
  final DateTime createdAt;

  bool outranks(ProviderBinding other) {
    if (authority == other.authority) {
      return confidence >= other.confidence;
    }
    return authority == ProviderBindingAuthority.userConfirmed;
  }
}

abstract interface class ProviderBindingStore {
  Future<ProviderBinding?> bindingFor(LocalMediaId mediaId);

  Future<ProviderBinding> saveUserConfirmed(ProviderBinding binding);

  Future<ProviderBinding> saveAutomaticIfAllowed(ProviderBinding candidate);
}
