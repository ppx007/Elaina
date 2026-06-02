import '../../provider/bangumi/bangumi_auth.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/dandanplay/dandanplay_comments.dart';
import '../../provider/dandanplay/dandanplay_provider.dart';
import '../../provider/provider_result.dart';

final class AcgDataController {
  const AcgDataController({
    required BangumiProvider bangumiProvider,
    required BangumiAuthProvider bangumiAuthProvider,
    required DandanplayProvider dandanplayProvider,
    required DandanplayCommentProvider dandanplayCommentProvider,
  })  : _bangumiProvider = bangumiProvider,
        _bangumiAuthProvider = bangumiAuthProvider,
        _dandanplayProvider = dandanplayProvider,
        _dandanplayCommentProvider = dandanplayCommentProvider;

  final BangumiProvider _bangumiProvider;
  final BangumiAuthProvider _bangumiAuthProvider;
  final DandanplayProvider _dandanplayProvider;
  final DandanplayCommentProvider _dandanplayCommentProvider;

  Future<AcgProviderResult<BangumiSubject>> bangumiSubject(BangumiSubjectId id) {
    return _bangumiProvider.lookupSubject(id);
  }

  Future<AcgProviderResult<BangumiEpisode>> bangumiEpisode(BangumiEpisodeId id) {
    return _bangumiProvider.lookupEpisode(id);
  }

  Future<AcgProviderResult<BangumiAuthSession>> bangumiSession() {
    return _bangumiAuthProvider.currentSession();
  }

  Future<AcgProviderResult<void>> syncBangumiProgress(BangumiProgressUpdate update) {
    return _bangumiAuthProvider.syncProgress(update);
  }

  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchDandanplay(String filename) {
    return _dandanplayProvider.matchLocalMedia(filename);
  }

  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> searchDandanplay(String query) {
    return _dandanplayProvider.search(query);
  }

  Future<AcgProviderResult<List<DandanplayComment>>> dandanplayComments(DandanplayEpisodeId episodeId) {
    return _dandanplayCommentProvider.commentsForEpisode(episodeId);
  }

  Future<AcgProviderResult<void>> postDandanplayComment(DandanplayCommentPost post) {
    return _dandanplayCommentProvider.postComment(post);
  }
}
