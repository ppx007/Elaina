import '../../foundation/cache_invalidation/cache_invalidation_bus.dart';
import '../../provider/bangumi/bangumi_provider.dart';
import '../media/media_library.dart';
import '../playback/playback_source_handoff.dart';
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
    Iterable<BangumiVideoDetailSeed> seeds = const <BangumiVideoDetailSeed>[],
    String providerId = defaultVideoDetailMetadataProviderId,
    DateTime Function()? now,
  }) : runtime = VideoDetailRuntime(
          metadataProvider: metadataProvider,
          bindingStore: bindingStore,
          historyStore: historyStore,
          playbackSourceHandoff: playbackSourceHandoff,
          invalidationBus: invalidationBus,
          seeds: seeds,
          providerId: providerId,
          now: now,
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
