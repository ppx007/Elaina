import '../lib/celesteria.dart';
import 'bangumi_runtime_check.dart';

Future<void> main() async {
  await verifyDandanplayRuntimeContract();
}

Future<void> verifyDandanplayRuntimeContract() async {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  final DeterministicProviderGateway gateway =
      DeterministicProviderGateway(storage: storage);
  const DandanplayMatchCandidate candidate = DandanplayMatchCandidate(
    animeId: DandanplayAnimeId('anime-check'),
    episodeId: DandanplayEpisodeId('episode-check'),
    title: 'Dandanplay Check',
    confidence: 0.95,
  );
  const DandanplayComment comment = DandanplayComment(
    timestamp: Duration(seconds: 4),
    text: 'runtime-check-comment',
    mode: DandanplayCommentMode.scrolling,
  );
  final DandanplayAcgRuntime runtime = DandanplayAcgRuntime(
    gateway: gateway,
    matchCandidatesByFilename: const <String, List<DandanplayMatchCandidate>>{
      'check.mkv': <DandanplayMatchCandidate>[candidate],
    },
    searchCandidates: const <DandanplayMatchCandidate>[candidate],
    commentsByEpisodeId: const <String, List<DandanplayComment>>{
      'episode-check': <DandanplayComment>[comment],
    },
  );

  final AcgProviderResult<List<DandanplayMatchCandidate>> match =
      await runtime.controller.matchDandanplay('check.mkv');
  _expect(match is AcgProviderSuccess<List<DandanplayMatchCandidate>>,
      'Dandanplay match must succeed deterministically.');
  final AcgProviderResult<List<DandanplayMatchCandidate>> search =
      await runtime.controller.searchDandanplay('check');
  _expect(search is AcgProviderSuccess<List<DandanplayMatchCandidate>>,
      'Dandanplay search must succeed deterministically.');
  final AcgProviderResult<List<DandanplayComment>> comments =
      await runtime.controller.dandanplayComments(candidate.episodeId);
  _expect(comments is AcgProviderSuccess<List<DandanplayComment>>,
      'Dandanplay comments must succeed deterministically.');
  final AcgProviderResult<void> post =
      await runtime.controller.postDandanplayComment(
    const DandanplayCommentPost(
      episodeId: DandanplayEpisodeId('episode-check'),
      comment: DandanplayComment(
        timestamp: Duration(seconds: 5),
        text: 'posted-check-comment',
        mode: DandanplayCommentMode.bottom,
      ),
    ),
  );
  _expect(post is AcgProviderSuccess<void>,
      'Dandanplay comment posting must succeed when configured.');

  final DandanplayProviderRuntime unavailable = DandanplayProviderRuntime(
    gateway:
        DeterministicProviderGateway(storage: DeterministicStorageFoundation()),
    postingAvailable: false,
  );
  final AcgProviderResult<void> failedPost = await unavailable.postComment(
    const DandanplayCommentPost(
      episodeId: DandanplayEpisodeId('episode-check'),
      comment: DandanplayComment(
        timestamp: Duration.zero,
        text: 'retryable',
        mode: DandanplayCommentMode.scrolling,
      ),
    ),
  );
  _expect(
    failedPost is AcgProviderFailure<void> &&
        failedPost.kind == AcgProviderFailureKind.retryable,
    'Unavailable Dandanplay posting must normalize to retryable failure.',
  );

  await verifyBangumiRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
