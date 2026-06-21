import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../media/media_library.dart';
import '../playback/playback_source_handoff.dart';
import '../profile/bangumi_tracking_domain.dart';
import '../profile/bangumi_tracking_local_store.dart';
import 'video_detail.dart';
import 'video_detail_runtime.dart';

const Set<String> videoDetailRuntimeForbiddenTerms = <String>{
  'package:' 'flutter',
  'dart:' 'ui',
  'ProviderGateway',
  'BangumiProviderRuntime',
  'BangumiAuthSession',
  'src/foundation/storage',
  '../../foundation/storage',
  '../../storage',
  '../storage',
  '../../network',
  '../network',
  '../../streaming',
  '../streaming',
  '../../domain/rss',
  '../../domain/seasonal',
  '../../provider/rss',
  '../../provider/subtitle',
  'MediaLibraryScanner',
  'SubtitleProvider',
  'RssEngine',
  'SeasonalIndexer',
  'BtTask',
  'BitTorrent',
  'torrent',
  'online_rule',
  'OnlineRule',
  'HttpClient',
  'WebView',
  'DiagnosticsCenter',
  'mpv',
  'libmpv',
  'media-kit',
  'media_kit',
  'vlc',
  'native player',
};

const Set<String> videoDetailRuntimeRequiredTerms = <String>{
  'VideoDetailRuntime',
  'VideoDetailBootstrap',
  'DeterministicVideoDetailRepository',
  'DeterministicVideoDetailActionHandler',
  'VideoDetailActionResult',
  'PlaybackSourceHandoffContract',
  'CacheInvalidationBus',
  'ProviderBindingStore',
  'PlaybackHistoryStore',
};

final class VideoDetailBootstrap {
  VideoDetailBootstrap({
    required BangumiProvider metadataProvider,
    required ProviderBindingStore bindingStore,
    required PlaybackHistoryStore historyStore,
    required PlaybackSourceHandoffContract playbackSourceHandoff,
    required CacheInvalidationBus invalidationBus,
    BangumiTrackingProvider? trackingProvider,
    BangumiLocalTrackingStore? localTrackingStore,
    BangumiTrackingSyncProvider? trackingSyncProvider,
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  }) : runtime = VideoDetailRuntime(
          metadataProvider: metadataProvider,
          bindingStore: bindingStore,
          historyStore: historyStore,
          playbackSourceHandoff: playbackSourceHandoff,
          invalidationBus: invalidationBus,
          trackingProvider: trackingProvider,
          localTrackingStore: localTrackingStore,
          trackingSyncProvider: trackingSyncProvider,
          seeds: seeds,
          providerId: providerId,
          now: now,
        );

  VideoDetailBootstrap.withDependencies({
    required VideoDetailRepository repository,
    required VideoDetailActionHandler actionHandler,
    void Function()? disposeRepository,
    void Function()? disposeActionHandler,
  }) : runtime = VideoDetailRuntime.withDependencies(
          repository: repository,
          actionHandler: actionHandler,
          disposeRepository: disposeRepository,
          disposeActionHandler: disposeActionHandler,
        );

  final VideoDetailRuntime runtime;

  VideoDetailController get controller => runtime.controller;

  VideoDetailRepository get repository => runtime.repository;

  VideoDetailActionHandler get actionHandler => runtime.actionHandler;

  Future<VideoDetailViewData> load(VideoDetailId id) => runtime.load(id);

  void dispose() => runtime.dispose();

  static List<String> findForbiddenTerms(String content) {
    return <String>[
      for (final String term in videoDetailRuntimeForbiddenTerms)
        if (content.contains(term)) term,
    ];
  }

  static List<String> findMissingRequiredTerms(String content) {
    return <String>[
      for (final String term in videoDetailRuntimeRequiredTerms)
        if (!content.contains(term)) term,
    ];
  }
}
