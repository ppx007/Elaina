import '../provider_result.dart';
import 'bangumi_provider.dart';

final class BangumiAuthSession {
  const BangumiAuthSession({required this.userId, required this.expiresAt});

  final String userId;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

enum BangumiProgressState {
  planned,
  watching,
  completed,
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

abstract interface class BangumiAuthProvider {
  Future<AcgProviderResult<BangumiAuthSession>> currentSession();

  Future<AcgProviderResult<void>> syncProgress(BangumiProgressUpdate update);
}
