import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../../provider/bangumi/bangumi_auth.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/dandanplay/dandanplay_comments.dart';
import '../../provider/dandanplay/dandanplay_provider.dart';
import '../../provider/dandanplay/dandanplay_runtime.dart';
import '../../provider/provider_result.dart';
import 'acg_data_controller.dart';

final class DandanplayAcgRuntime {
  DandanplayAcgRuntime({
    required ProviderGateway gateway,
    Map<String, List<DandanplayMatchCandidate>> matchCandidatesByFilename =
        const <String, List<DandanplayMatchCandidate>>{},
    Iterable<DandanplayMatchCandidate> searchCandidates =
        const <DandanplayMatchCandidate>[],
    Map<String, List<DandanplayComment>> commentsByEpisodeId =
        const <String, List<DandanplayComment>>{},
    bool postingAvailable = true,
    DandanplayProvider? dandanplayProvider,
    DandanplayCommentProvider? dandanplayCommentProvider,
    BangumiProvider? bangumiProvider,
    BangumiAuthProvider? bangumiAuthProvider,
  }) : dandanplayRuntime = DandanplayProviderRuntime(
          gateway: gateway,
          matchCandidatesByFilename: matchCandidatesByFilename,
          searchCandidates: searchCandidates,
          commentsByEpisodeId: commentsByEpisodeId,
          postingAvailable: postingAvailable,
          provider: dandanplayProvider,
          commentProvider: dandanplayCommentProvider,
        ) {
    controller = AcgDataController(
      bangumiProvider: bangumiProvider ?? const UnavailableBangumiProvider(),
      bangumiAuthProvider:
          bangumiAuthProvider ?? const UnavailableBangumiAuthProvider(),
      dandanplayProvider: dandanplayRuntime,
      dandanplayCommentProvider: dandanplayRuntime,
    );
  }

  final DandanplayProviderRuntime dandanplayRuntime;

  late final AcgDataController controller;

  Future<void> initialize() => dandanplayRuntime.initialize();

  void dispose() => dandanplayRuntime.dispose();
}

final class UnavailableBangumiProvider implements BangumiProvider {
  const UnavailableBangumiProvider();

  @override
  ProviderGateway get gateway =>
      throw UnsupportedError('Unavailable Bangumi provider has no gateway.');

  @override
  String get id => 'bangumi-unavailable';

  @override
  String get displayName => 'Unavailable Bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => const ProviderRegistration(
        providerId: ProviderId('bangumi-unavailable'),
        ratePolicy: unavailableProviderRatePolicy,
        retryPolicy: unavailableProviderRetryPolicy,
      );

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: registration.providerId,
      cacheKey: cacheKey,
    );
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return Future<ProviderGatewayResponse<T>>.error(
      const ProviderFailure(
        kind: ProviderFailureKind.terminal,
        message:
            'Bangumi runtime is not configured for this Dandanplay-only bootstrap.',
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(
    BangumiSubjectId id,
  ) async {
    return const AcgProviderFailure<BangumiSubject>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi runtime is not configured for this Dandanplay-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query,
  ) async {
    return const AcgProviderFailure<List<BangumiSubject>>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi runtime is not configured for this Dandanplay-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
    BangumiEpisodeId id,
  ) async {
    return const AcgProviderFailure<BangumiEpisode>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi runtime is not configured for this Dandanplay-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) async {
    return const AcgProviderFailure<List<BangumiEpisode>>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi runtime is not configured for this Dandanplay-only bootstrap.',
    );
  }
}

final class UnavailableBangumiAuthProvider implements BangumiAuthProvider {
  const UnavailableBangumiAuthProvider();

  @override
  Future<AcgProviderResult<BangumiAuthSession>> currentSession() async {
    return const AcgProviderFailure<BangumiAuthSession>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi auth is not configured for this Dandanplay-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<void>> syncProgress(
    BangumiProgressUpdate update,
  ) async {
    return const AcgProviderFailure<void>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Bangumi auth is not configured for this Dandanplay-only bootstrap.',
    );
  }
}
