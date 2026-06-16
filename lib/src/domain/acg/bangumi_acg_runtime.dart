import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../../provider/bangumi/bangumi_auth.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../../provider/bangumi/bangumi_runtime.dart';
import '../../provider/dandanplay/dandanplay_comments.dart';
import '../../provider/dandanplay/dandanplay_provider.dart';
import '../../provider/provider_result.dart';
import 'acg_data_controller.dart';

final class BangumiAcgRuntime {
  BangumiAcgRuntime({
    required ProviderGateway gateway,
    Iterable<BangumiSubject> subjects = const <BangumiSubject>[],
    Iterable<BangumiEpisode> episodes = const <BangumiEpisode>[],
    BangumiAuthSession? session,
    bool progressSyncAvailable = true,
    DateTime Function()? now,
    BangumiProvider? bangumiProvider,
    BangumiAuthProvider? bangumiAuthProvider,
    DandanplayProvider? dandanplayProvider,
    DandanplayCommentProvider? dandanplayCommentProvider,
  }) : bangumiRuntime = BangumiProviderRuntime(
          gateway: gateway,
          subjects: subjects,
          episodes: episodes,
          session: session,
          progressSyncAvailable: progressSyncAvailable,
          now: now,
          metadataProvider: bangumiProvider,
          authProvider: bangumiAuthProvider,
        ) {
    controller = AcgDataController(
      bangumiProvider: bangumiRuntime,
      bangumiAuthProvider: bangumiRuntime,
      dandanplayProvider:
          dandanplayProvider ?? const UnavailableDandanplayProvider(),
      dandanplayCommentProvider: dandanplayCommentProvider ??
          const UnavailableDandanplayCommentProvider(),
    );
  }

  final BangumiProviderRuntime bangumiRuntime;

  late final AcgDataController controller;

  Future<void> initialize() => bangumiRuntime.initialize();

  void dispose() => bangumiRuntime.dispose();
}

final class UnavailableDandanplayProvider implements DandanplayProvider {
  const UnavailableDandanplayProvider();

  @override
  ProviderGateway get gateway =>
      throw UnsupportedError('Unavailable Dandanplay provider has no gateway.');

  @override
  String get id => 'dandanplay-unavailable';

  @override
  String get displayName => 'Unavailable Dandanplay';

  @override
  ProviderKind get kind => ProviderKind.danmaku;

  @override
  ProviderRegistration get registration => const ProviderRegistration(
        providerId: ProviderId('dandanplay-unavailable'),
        ratePolicy: unavailableProviderRatePolicy,
        retryPolicy: unavailableProviderRetryPolicy,
      );

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: registration.providerId, cacheKey: cacheKey);
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
            'Dandanplay runtime is not configured for this Bangumi-only bootstrap.',
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchLocalMedia(
      String filename) async {
    return const AcgProviderFailure<List<DandanplayMatchCandidate>>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Dandanplay runtime is not configured for this Bangumi-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> search(
      String query) async {
    return const AcgProviderFailure<List<DandanplayMatchCandidate>>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Dandanplay runtime is not configured for this Bangumi-only bootstrap.',
    );
  }
}

final class UnavailableDandanplayCommentProvider
    implements DandanplayCommentProvider {
  const UnavailableDandanplayCommentProvider();

  @override
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
      DandanplayEpisodeId episodeId) async {
    return const AcgProviderFailure<List<DandanplayComment>>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Dandanplay comments are not configured for this Bangumi-only bootstrap.',
    );
  }

  @override
  Future<AcgProviderResult<void>> postComment(
      DandanplayCommentPost post) async {
    return const AcgProviderFailure<void>(
      kind: AcgProviderFailureKind.unavailable,
      message:
          'Dandanplay comments are not configured for this Bangumi-only bootstrap.',
    );
  }
}
