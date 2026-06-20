import '../lib/elaina.dart';

Future<void> main() async {
  await verifyBangumiRuntimeContract();
}

Future<void> verifyBangumiRuntimeContract() async {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  final DeterministicProviderGateway gateway =
      DeterministicProviderGateway(storage: storage);
  final BangumiSubject subject = BangumiSubject(
    id: const BangumiSubjectId('subject-check'),
    title: 'Bangumi Check',
  );
  final BangumiEpisode episode = BangumiEpisode(
    id: const BangumiEpisodeId('episode-check'),
    subjectId: subject.id,
    index: 1,
    title: 'Runtime Check',
  );
  final BangumiAcgRuntime runtime = BangumiAcgRuntime(
    gateway: gateway,
    subjects: <BangumiSubject>[subject],
    episodes: <BangumiEpisode>[episode],
    session: BangumiAuthSession(
      userId: 'check-user',
      expiresAt: DateTime.utc(2026, 6, 10),
    ),
    now: () => DateTime.utc(2026, 6, 9),
  );

  final AcgProviderResult<BangumiSubject> subjectResult =
      await runtime.controller.bangumiSubject(subject.id);
  _expect(subjectResult is AcgProviderSuccess<BangumiSubject>,
      'Bangumi subject lookup must succeed.');
  final AcgProviderResult<BangumiEpisode> episodeResult =
      await runtime.controller.bangumiEpisode(episode.id);
  _expect(episodeResult is AcgProviderSuccess<BangumiEpisode>,
      'Bangumi episode lookup must succeed.');
  final AcgProviderResult<BangumiAuthSession> sessionResult =
      await runtime.controller.bangumiSession();
  _expect(sessionResult is AcgProviderSuccess<BangumiAuthSession>,
      'Bangumi session lookup must succeed when configured.');
  final AcgProviderResult<void> progressResult =
      await runtime.controller.syncBangumiProgress(
    BangumiProgressUpdate(
      subjectId: subject.id,
      episodeId: episode.id,
      state: BangumiProgressState.completed,
    ),
  );
  _expect(progressResult is AcgProviderSuccess<void>,
      'Bangumi progress sync must succeed when authenticated.');

  final BangumiAcgRuntime unauthenticated = BangumiAcgRuntime(
    gateway:
        DeterministicProviderGateway(storage: DeterministicStorageFoundation()),
    now: () => DateTime.utc(2026, 6, 9),
  );
  final AcgProviderResult<void> unauthenticatedSync =
      await unauthenticated.controller.syncBangumiProgress(
    const BangumiProgressUpdate(
      subjectId: BangumiSubjectId('subject-check'),
      episodeId: BangumiEpisodeId('episode-check'),
      state: BangumiProgressState.watching,
    ),
  );
  _expect(
    unauthenticatedSync is AcgProviderFailure<void> &&
        unauthenticatedSync.kind == AcgProviderFailureKind.unauthenticated,
    'Unauthenticated progress sync must normalize to unauthenticated failure.',
  );

  final DeterministicProviderGateway apiGateway =
      DeterministicProviderGateway(storage: DeterministicStorageFoundation());
  final _CheckBangumiTransport transport = _CheckBangumiTransport(
    responses: <String, BangumiApiResponse>{
      'GET /v0/subjects/1017': const BangumiApiResponse(
        statusCode: 200,
        body: '{"id":1017,"name":"Check","name_cn":"Concrete Check"}',
      ),
      'GET /v0/me': const BangumiApiResponse(
        statusCode: 200,
        body: '{"username":"check-user"}',
      ),
      'PUT /v0/users/-/collections/-/episodes/1':
          const BangumiApiResponse(statusCode: 204, body: ''),
    },
  );
  final BangumiApiProvider apiProvider = BangumiApiProvider(
    gateway: apiGateway,
    client: BangumiApiClient(
      transport: transport,
      baseUri: Uri.parse('https://api.test'),
    ),
    accessTokenProvider: () async => BangumiApiAccessToken(
      value: 'check-token',
      expiresAt: DateTime.utc(2026, 6, 10),
    ),
    now: () => DateTime.utc(2026, 6, 9),
  );
  final BangumiAcgRuntime concreteRuntime = BangumiAcgRuntime(
    gateway: apiGateway,
    bangumiProvider: apiProvider,
    bangumiAuthProvider: apiProvider,
  );
  final AcgProviderResult<BangumiSubject> concreteSubject =
      await concreteRuntime.controller
          .bangumiSubject(const BangumiSubjectId('1017'));
  _expect(
    concreteSubject is AcgProviderSuccess<BangumiSubject> &&
        concreteSubject.value.title == 'Concrete Check',
    'Concrete Bangumi API provider must map subject JSON.',
  );
  final AcgProviderResult<BangumiAuthSession> concreteSession =
      await concreteRuntime.controller.bangumiSession();
  _expect(
    concreteSession is AcgProviderSuccess<BangumiAuthSession> &&
        concreteSession.value.userId == 'check-user',
    'Concrete Bangumi API provider must map current session JSON.',
  );
  final AcgProviderResult<void> concreteProgress =
      await concreteRuntime.controller.syncBangumiProgress(
    const BangumiProgressUpdate(
      subjectId: BangumiSubjectId('1017'),
      episodeId: BangumiEpisodeId('1'),
      state: BangumiProgressState.completed,
    ),
  );
  _expect(concreteProgress is AcgProviderSuccess<void>,
      'Concrete Bangumi API provider must sync progress via fake transport.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _CheckBangumiTransport implements BangumiApiTransport {
  const _CheckBangumiTransport({required this.responses});

  final Map<String, BangumiApiResponse> responses;

  @override
  Future<BangumiApiResponse> send(BangumiApiRequest request) async {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    final BangumiApiResponse? response =
        responses['${request.method} ${request.uri.path}$query'];
    if (response != null) return response;
    return const BangumiApiResponse(
      statusCode: 404,
      body: '{"title":"missing check response"}',
    );
  }
}
