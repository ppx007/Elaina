import '../provider_result.dart';
import 'bangumi_provider.dart';

final class BangumiAuthSession {
  const BangumiAuthSession({
    required this.userId,
    required this.expiresAt,
    this.displayName,
    this.avatarUri,
  });

  final String userId;
  final DateTime expiresAt;
  final String? displayName;
  final Uri? avatarUri;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

enum BangumiProgressState {
  planned,
  watching,
  completed,
  onHold,
  dropped,
}

enum BangumiSubjectCollectionStatus {
  planned,
  completed,
  watching,
  onHold,
  dropped,
}

final class BangumiProgressUpdate {
  const BangumiProgressUpdate({
    required this.subjectId,
    required this.episodeId,
    required this.state,
  });

  final BangumiSubjectId subjectId;
  final BangumiEpisodeId episodeId;
  final BangumiProgressState state;
}

final class BangumiAnimeCollectionItem {
  const BangumiAnimeCollectionItem({
    required this.subjectId,
    required this.title,
    required this.status,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    this.coverUri,
    this.updatedAt,
  })  : assert(title != '', 'Bangumi collection title must not be empty.'),
        assert(watchedEpisodes >= 0,
            'Bangumi watched episode count must not be negative.'),
        assert(totalEpisodes >= 0,
            'Bangumi total episode count must not be negative.');

  final BangumiSubjectId subjectId;
  final String title;
  final BangumiSubjectCollectionStatus status;
  final int watchedEpisodes;
  final int totalEpisodes;
  final Uri? coverUri;
  final DateTime? updatedAt;
}

abstract interface class BangumiAuthProvider {
  Future<AcgProviderResult<BangumiAuthSession>> currentSession();

  Future<AcgProviderResult<void>> syncProgress(BangumiProgressUpdate update);
}

abstract interface class BangumiCollectionProvider {
  Future<AcgProviderResult<List<BangumiAnimeCollectionItem>>>
      currentAnimeCollection();
}
