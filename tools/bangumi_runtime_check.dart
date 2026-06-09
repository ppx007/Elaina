import '../lib/celesteria.dart';

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
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
