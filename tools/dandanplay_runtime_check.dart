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

  final DeterministicProviderGateway apiGateway =
      DeterministicProviderGateway(storage: DeterministicStorageFoundation());
  final _CheckDandanplayTransport transport = _CheckDandanplayTransport(
    responses: <String, DandanplayApiResponse>{
      'POST /api/v2/match': const DandanplayApiResponse(
        statusCode: 200,
        body:
            '{"success":true,"isMatched":true,"matches":[{"animeId":1017,"episodeId":1,"animeTitle":"Concrete Check","episodeTitle":"Episode 1"}]}',
      ),
      'GET /api/v2/comment/1?from=0&withRelated=true&chConvert=0':
          const DandanplayApiResponse(
        statusCode: 200,
        body:
            '{"count":1,"comments":[{"cid":1,"p":"4.00,1,16777215,user","m":"concrete-comment"}]}',
      ),
      'POST /api/v2/comment/1': const DandanplayApiResponse(
        statusCode: 200,
        body: '{"success":true,"cid":2}',
      ),
    },
  );
  final DandanplayApiProvider apiProvider = DandanplayApiProvider(
    gateway: apiGateway,
    client: DandanplayApiClient(
      transport: transport,
      baseUri: Uri.parse('https://api.test'),
    ),
    credentialProvider: () async =>
        const DandanplayApiCredentials(bearerToken: 'check-token'),
  );
  final DandanplayAcgRuntime concreteRuntime = DandanplayAcgRuntime(
    gateway: apiGateway,
    dandanplayProvider: apiProvider,
    dandanplayCommentProvider: apiProvider,
  );
  final AcgProviderResult<List<DandanplayMatchCandidate>> concreteMatch =
      await concreteRuntime.controller.matchDandanplay('check.mkv');
  _expect(
    concreteMatch is AcgProviderSuccess<List<DandanplayMatchCandidate>> &&
        concreteMatch.value.single.title == 'Concrete Check - Episode 1',
    'Concrete Dandanplay API provider must map match JSON.',
  );
  final AcgProviderResult<List<DandanplayComment>> concreteComments =
      await concreteRuntime.controller
          .dandanplayComments(const DandanplayEpisodeId('1'));
  _expect(
    concreteComments is AcgProviderSuccess<List<DandanplayComment>> &&
        concreteComments.value.single.text == 'concrete-comment',
    'Concrete Dandanplay API provider must map comment JSON.',
  );
  final AcgProviderResult<void> concretePost =
      await concreteRuntime.controller.postDandanplayComment(
    const DandanplayCommentPost(
      episodeId: DandanplayEpisodeId('1'),
      comment: DandanplayComment(
        timestamp: Duration(seconds: 4),
        text: 'post-concrete',
        mode: DandanplayCommentMode.scrolling,
      ),
    ),
  );
  _expect(concretePost is AcgProviderSuccess<void>,
      'Concrete Dandanplay API provider must post comments with credentials.');

  await verifyBangumiRuntimeContract();
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckDandanplayTransport implements DandanplayApiTransport {
  const _CheckDandanplayTransport({required this.responses});

  final Map<String, DandanplayApiResponse> responses;

  @override
  Future<DandanplayApiResponse> send(DandanplayApiRequest request) async {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    final DandanplayApiResponse? response =
        responses['${request.method} ${request.uri.path}$query'];
    if (response != null) return response;
    return const DandanplayApiResponse(
      statusCode: 404,
      body: '{"success":false,"errorMessage":"missing check response"}',
    );
  }
}
