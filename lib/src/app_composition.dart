import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'domain/detail/video_detail_bootstrap.dart';
import 'domain/diagnostics/diagnostics_domain.dart';
import 'domain/download/download_domain.dart';
import 'domain/home/home_recommendation_domain.dart';
import 'domain/home/home_search_domain.dart';
import 'domain/media/local_file_media_scanner.dart';
import 'domain/media/media_library_runtime.dart';
import 'domain/media/media_library_storage_adapters.dart';
import 'domain/playback/playback_source_handoff.dart';
import 'domain/profile/bangumi_login_domain.dart';
import 'domain/profile/bangumi_tracking_domain.dart';
import 'domain/profile/bangumi_tracking_local_store.dart';
import 'domain/profile/profile_domain.dart';
import 'domain/rss/rss_engine_runtime.dart';
import 'domain/settings/settings_domain.dart';
import 'foundation/constants.dart';
import 'foundation/diagnostics/diagnostics_center.dart';
import 'foundation/diagnostics/diagnostics_center_runtime.dart';
import 'foundation/foundation_bootstrap.dart';
import 'foundation/provider_contracts.dart';
import 'gateway/network_policy_provider_gateway.dart';
import 'playback/media_kit_mpv_binding.dart';
import 'playback/player_runtime_composition.dart';
import 'provider/bangumi/bangumi_api_client.dart';
import 'provider/bangumi/bangumi_auth.dart';
import 'provider/bangumi/bangumi_provider.dart';
import 'provider/bangumi/bangumi_runtime.dart';
import 'provider/provider_result.dart';
import 'provider/rss/rss_feed_fetcher_parser.dart';
import 'streaming/bt_task_core_runtime.dart';
import 'streaming/libtorrent_download_engine_adapter.dart';
import 'ui/detail/video_detail_page_contract.dart';

const String _bangumiMirrorApiUrlFieldName = 'Bangumi API mirror URL';
const String _bangumiMirrorImageUrlFieldName = 'Bangumi image mirror URL';
const String _rssTorrentCacheDirectoryName = 'elaina-rss-torrent-cache';
const String _rssTorrentCacheFileExtension = '.torrent';
const String _rssTorrentAcceptHeader =
    'application/x-bittorrent, application/octet-stream;q=0.9, */*;q=0.1';
const String _rssTorrentUserAgent = 'Elaina RSS Torrent Resolver';
const int _rssTorrentCacheKeyLength = 96;

final class PeriodicFeedScheduler implements FeedScheduler {
  const PeriodicFeedScheduler(
      {this.interval = AppConstants.defaultFeedRefreshInterval});

  final Duration interval;

  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) async* {
    final DateTime now = DateTime.now();
    for (final FeedSource source in sources) {
      yield FeedScheduleDecision(source: source, dueAt: now);
    }
  }
}

final class HttpRssTorrentUrlResolver implements RssTorrentUrlResolver {
  HttpRssTorrentUrlResolver({
    HttpClient? httpClient,
    Directory? cacheDirectory,
  })  : _httpClient = httpClient ?? HttpClient(),
        _cacheDirectory = cacheDirectory;

  final HttpClient _httpClient;
  final Directory? _cacheDirectory;

  void dispose() {
    _httpClient.close(force: true);
  }

  @override
  Future<RssTorrentUrlResolution> resolve(Uri torrentUri) async {
    // DownloadRuntime intentionally does not accept remote .torrent URLs. RSS
    // auto-download resolves them into cached local files before task creation
    // so the downloads page can keep its stricter source contract.
    final Directory directory = _cacheDirectory ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          '$_rssTorrentCacheDirectoryName',
        );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final File cached = File(
      '${directory.path}${Platform.pathSeparator}'
      '${_torrentCacheKey(torrentUri)}$_rssTorrentCacheFileExtension',
    );
    if (await cached.exists() && await cached.length() > 0) {
      return RssTorrentUrlResolution.success(cached.uri);
    }

    try {
      final HttpClientRequest request = await _httpClient.getUrl(torrentUri);
      request.headers.set(HttpHeaders.acceptHeader, _rssTorrentAcceptHeader);
      request.headers.set(HttpHeaders.userAgentHeader, _rssTorrentUserAgent);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        return RssTorrentUrlResolution.failure(
          'RSS torrent 下载失败：HTTP ${response.statusCode}。',
        );
      }
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );
      if (bytes.isEmpty) {
        return const RssTorrentUrlResolution.failure(
          'RSS torrent 下载失败：响应为空。',
        );
      }
      await cached.writeAsBytes(bytes, flush: true);
      return RssTorrentUrlResolution.success(cached.uri);
    } on Object catch (error) {
      return RssTorrentUrlResolution.failure(
        'RSS torrent 下载失败：$error',
      );
    }
  }

  String _torrentCacheKey(Uri uri) {
    final String encoded =
        base64Url.encode(utf8.encode(uri.toString())).replaceAll('=', '');
    if (encoded.length <= _rssTorrentCacheKeyLength) return encoded;
    return encoded.substring(0, _rssTorrentCacheKeyLength);
  }
}

/// Wires production runtimes while preserving layer boundaries.
///
/// Composition is the only place where storage, provider gateway, playback,
/// RSS, downloads, and UI-facing adapters are assembled together. Feature pages
/// should receive contracts from here instead of constructing runtimes locally.
class AppComposition {
  AppComposition() {
    // 1. Initialize foundation bootstrap
    foundation = FoundationBootstrap();
    final providerGateway = NetworkPolicyProviderGateway(
      delegate: foundation.gateway,
      networkPolicyStore: foundation.storage.networkPolicy,
    );

    // 2. Playback Composition
    playbackComposition = mediaKitLocalFilePlayerRuntimeComposition();
    final MediaKitMpvBinding binding =
        playbackComposition.binding as MediaKitMpvBinding;
    videoController = VideoController(binding.backend.player);

    // 3. Media Library Runtime
    final scanner = LocalFileMediaLibraryScanner();
    final catalogRepository =
        StorageMediaLibraryCatalogRepository(foundation.storage.mediaLibrary);
    final importer =
        StorageMediaBatchImportContract(repository: catalogRepository);
    final historyStore =
        StoragePlaybackHistoryStore(foundation.storage.playbackHistory);
    final bindingStore =
        StorageProviderBindingStore(foundation.storage.providerBinding);

    // 4. Bangumi Provider Runtime
    final BangumiApiClient bangumiApiClient = BangumiApiClient(
      transport: HttpBangumiApiTransport(),
      mirrorConfigProvider: () async {
        final settings = foundation.storage.settings;
        final String? enabled = await settings
            .readString(SettingsPreferenceKeys.bangumiMirrorEnabled);
        if (!BangumiMirrorSettings.isEnabled(enabled)) {
          return const BangumiApiMirrorConfig.disabled();
        }
        try {
          return BangumiApiMirrorConfig.enabled(
            apiBaseUri: BangumiMirrorSettings.parseBaseUri(
              await settings.readString(
                    SettingsPreferenceKeys.bangumiMirrorApiBaseUrl,
                  ) ??
                  '',
              fieldName: _bangumiMirrorApiUrlFieldName,
            ),
            imageBaseUri: BangumiMirrorSettings.parseBaseUri(
              await settings.readString(
                    SettingsPreferenceKeys.bangumiMirrorImageBaseUrl,
                  ) ??
                  '',
              fieldName: _bangumiMirrorImageUrlFieldName,
            ),
          );
        } on FormatException catch (error) {
          throw ProviderFailure(
            kind: ProviderFailureKind.terminal,
            message: 'Bangumi mirror configuration is invalid: '
                '${error.message}',
          );
        }
      },
    );
    final bangumiApiProvider = BangumiApiProvider(
      gateway: providerGateway,
      client: bangumiApiClient,
      accessTokenProvider: () async {
        final String token = (await foundation.storage.settings
                    .readString(SettingsPreferenceKeys.bangumiAccessToken))
                ?.trim() ??
            '';
        if (token.isEmpty) return null;
        return BangumiApiAccessToken(value: token);
      },
    );

    bangumiProviderRuntime = BangumiProviderRuntime(
      gateway: providerGateway,
      metadataProvider: bangumiApiProvider,
      authProvider: bangumiApiProvider,
      collectionProvider: bangumiApiProvider,
    );
    bangumiAuthProvider = bangumiProviderRuntime;
    profileProvider = _BangumiUserProfileProvider(bangumiAuthProvider);
    localTrackingStore =
        SettingsBangumiLocalTrackingStore(foundation.storage.settings);
    final BangumiTrackingProvider remoteTrackingProvider =
        _BangumiTrackingCollectionProvider(
      bangumiProviderRuntime,
    );
    trackingSyncProvider = _BangumiTrackingStatusSyncProvider(
      bangumiProviderRuntime,
    );
    trackingProvider = CloudFirstBangumiTrackingProvider(
      localStore: localTrackingStore,
      remoteProvider: remoteTrackingProvider,
    );
    homeRecommendationProvider = _BangumiHomeRecommendationProvider(
      bangumiProviderRuntime,
    );
    homeSearchProvider = _BangumiHomeSearchProvider(
      bangumiProviderRuntime,
    );

    mediaLibraryRuntime = MediaLibraryRuntime(
      scanner: scanner,
      catalogRepository: catalogRepository,
      importer: importer,
      historyStore: historyStore,
      bindingStore: bindingStore,
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: foundation.invalidationBus,
      bangumiMatcher: BangumiLocalMediaMatcher(
        bangumiProvider: bangumiProviderRuntime,
      ),
    );

    // 5. Video Detail Runtime
    videoDetailBootstrap = VideoDetailBootstrap(
      metadataProvider: bangumiProviderRuntime,
      bindingStore: bindingStore,
      historyStore: historyStore,
      playbackSourceHandoff: const LocalPlaybackSourceHandoff(),
      invalidationBus: foundation.invalidationBus,
      trackingProvider: trackingProvider,
      localTrackingStore: localTrackingStore,
      trackingSyncProvider: trackingSyncProvider,
    );

    videoDetailPageContract = VideoDetailPageContract(
      controller: videoDetailBootstrap.controller,
    );

    // 6. BT Task Core Runtime
    final btTaskComposition = libtorrentBtTaskRuntimeComposition(
      store: foundation.storage.btTask,
      cacheInvalidationBus: foundation.invalidationBus,
    );
    btTaskCoreRuntime = BtTaskCoreBootstrap.withComposition(
      composition: btTaskComposition,
    ).runtime;
    downloadRuntime = DownloadRuntimeAdapter(btTaskCoreRuntime);

    // 7. RSS Engine Runtime
    final transport = HttpFeedHttpTransport();
    final fetcher = HttpFeedFetcher(
      gateway: providerGateway,
      transport: transport,
    );
    const parser = AutoXmlFeedParser();
    const scheduler = PeriodicFeedScheduler();
    rssTorrentUrlResolver = HttpRssTorrentUrlResolver();

    rssEngineRuntime = RssEngineBootstrap(
      store: foundation.storage.rssFeed,
      fetcher: fetcher,
      parser: parser,
      scheduler: scheduler,
      policyStore: foundation.storage.rssAutoDownloadPolicy,
      downloadTaskEnqueuer: DownloadRuntimeRssTaskEnqueuer(
        downloadRuntime: downloadRuntime,
        torrentResolver: rssTorrentUrlResolver,
      ),
    ).runtime;

    // 8. Settings Runtime
    settingsRuntime = SettingsRuntimeAdapter(
      settingsStore: foundation.storage.settings,
      networkPolicyStore: foundation.storage.networkPolicy,
    );
    bangumiLoginController = _BangumiLoginController(
      settingsRuntime: settingsRuntime,
      authProvider: bangumiAuthProvider,
      oauthAuthorizationUri: bangumiApiClient.oauthAuthorizationPageUri(),
      openExternalUri: SystemExternalUriLauncher().open,
    );

    // 9. Diagnostics Runtime
    final diagnosticsCapabilityMatrix = DiagnosticsCapabilityMatrix(
      capabilities: <DiagnosticsCapability, DiagnosticsCapabilityStatus>{
        for (final DiagnosticsCapability cap in DiagnosticsCapability.values)
          cap: const DiagnosticsCapabilityStatus.supported(),
      },
    );

    final diagnosticsCenterRuntime = DiagnosticsCenterRuntimeBootstrap(
      store: foundation.storage.diagnostics,
      registry: DeterministicDiagnosticsEventRegistry(),
      retentionPolicy: const DiagnosticsRetentionPolicy(
        maxEvents: AppConstants.diagnosticsRetentionMaxEvents,
        maxAge: AppConstants.diagnosticsRetentionMaxAge,
      ),
      redactionPolicy: DiagnosticsRedactionPolicy(),
      capabilityMatrix: diagnosticsCapabilityMatrix,
      bus: foundation.invalidationBus,
    ).createRuntime();

    diagnosticsRuntime = DiagnosticsRuntimeAdapter(
      centerRuntime: diagnosticsCenterRuntime,
      store: foundation.storage.diagnostics,
      capabilityMatrix: diagnosticsCapabilityMatrix,
      avSyncGuardStore: foundation.storage.avSyncGuard,
    );
  }

  late final FoundationBootstrap foundation;
  late final PlayerRuntimeCompositionContract playbackComposition;
  late final VideoController videoController;
  late final MediaLibraryRuntime mediaLibraryRuntime;
  late final VideoDetailBootstrap videoDetailBootstrap;
  late final VideoDetailPageContract videoDetailPageContract;
  late final RssEngineRuntime rssEngineRuntime;
  late final BtTaskCoreRuntime btTaskCoreRuntime;
  late final DownloadRuntime downloadRuntime;
  late final HttpRssTorrentUrlResolver rssTorrentUrlResolver;
  late final SettingsRuntime settingsRuntime;
  late final DiagnosticsRuntime diagnosticsRuntime;
  late final BangumiProviderRuntime bangumiProviderRuntime;
  late final BangumiAuthProvider bangumiAuthProvider;
  late final BangumiLoginController bangumiLoginController;
  late final UserProfileProvider profileProvider;
  late final BangumiLocalTrackingStore localTrackingStore;
  late final BangumiTrackingSyncProvider trackingSyncProvider;
  late final BangumiTrackingProvider trackingProvider;
  late final HomeRecommendationProvider homeRecommendationProvider;
  late final HomeSearchProvider homeSearchProvider;

  Widget buildVideoSurface(BuildContext context) {
    return Video(controller: videoController);
  }

  void dispose() {
    rssTorrentUrlResolver.dispose();
    downloadRuntime.dispose();
    mediaLibraryRuntime.dispose();
    videoDetailBootstrap.dispose();
    bangumiProviderRuntime.dispose();
    rssEngineRuntime.dispose();
    btTaskCoreRuntime.dispose();
    foundation.dispose();
  }
}

typedef _OpenExternalUri = Future<bool> Function(Uri uri);
typedef StartExternalProcess = Future<Process> Function(
  String executable,
  List<String> arguments,
);

final class _BangumiLoginController implements BangumiLoginController {
  const _BangumiLoginController({
    required SettingsRuntime settingsRuntime,
    required BangumiAuthProvider authProvider,
    required Uri oauthAuthorizationUri,
    required _OpenExternalUri openExternalUri,
  })  : _settingsRuntime = settingsRuntime,
        _authProvider = authProvider,
        _oauthAuthorizationUri = oauthAuthorizationUri,
        _openExternalUri = openExternalUri;

  final SettingsRuntime _settingsRuntime;
  final BangumiAuthProvider _authProvider;
  final Uri _oauthAuthorizationUri;
  final _OpenExternalUri _openExternalUri;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    try {
      final bool opened = await _openExternalUri(_oauthAuthorizationUri);
      if (!opened) {
        return const BangumiLoginStartResult.unavailable(
          '无法打开系统浏览器。',
        );
      }
      return BangumiLoginStartResult.opened(_oauthAuthorizationUri);
    } catch (error) {
      return BangumiLoginStartResult.failed('打开 Bangumi OAuth 授权页失败: $error');
    }
  }

  @override
  Future<BangumiTokenSignInResult> signInWithAccessToken(
    String accessToken,
  ) async {
    final String token = accessToken.trim();
    await _settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.bangumiAccessToken,
      value: token,
    );
    if (token.isEmpty) return const BangumiTokenSignInResult.signedOut();

    final AcgProviderResult<BangumiAuthSession> result =
        await _authProvider.currentSession();
    if (result is AcgProviderSuccess<BangumiAuthSession>) {
      final BangumiAuthSession session = result.value;
      return BangumiTokenSignInResult.signedIn(
        UserProfileSnapshot(
          displayName: session.displayName ?? session.userId,
          avatarUri: session.avatarUri,
        ),
      );
    }
    if (result is AcgProviderFailure<BangumiAuthSession>) {
      if (result.kind == AcgProviderFailureKind.unauthenticated) {
        await _settingsRuntime.setPreference(
          key: SettingsPreferenceKeys.bangumiAccessToken,
          value: '',
        );
      }
      return BangumiTokenSignInResult.failed(result.message);
    }
    return const BangumiTokenSignInResult.failed('Bangumi 登录状态未知。');
  }
}

final class SystemExternalUriLauncher {
  SystemExternalUriLauncher({StartExternalProcess? startProcess})
      : _startProcess = startProcess ?? _startDetachedProcess;

  final StartExternalProcess _startProcess;

  Future<bool> open(Uri uri) async {
    final String target = uri.toString();
    if (Platform.isWindows) {
      return _startDetached(
        'rundll32',
        <String>['url.dll,FileProtocolHandler', target],
      );
    }
    if (Platform.isMacOS) {
      return _startDetached('open', <String>[target]);
    }
    if (Platform.isLinux) {
      return _startDetached('xdg-open', <String>[target]);
    }
    return false;
  }

  static Future<Process> _startDetachedProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
  }

  Future<bool> _startDetached(String executable, List<String> arguments) async {
    await _startProcess(executable, arguments);
    return true;
  }
}

final class _BangumiUserProfileProvider implements UserProfileProvider {
  const _BangumiUserProfileProvider(this._authProvider);

  final BangumiAuthProvider _authProvider;

  @override
  Future<UserProfileSnapshot?> currentProfile() async {
    final AcgProviderResult<BangumiAuthSession> result =
        await _authProvider.currentSession();
    if (result is! AcgProviderSuccess<BangumiAuthSession>) {
      return null;
    }
    final BangumiAuthSession session = result.value;
    return UserProfileSnapshot(
      displayName: session.displayName ?? session.userId,
      avatarUri: session.avatarUri,
    );
  }
}

final class _BangumiTrackingCollectionProvider
    implements BangumiTrackingProvider {
  const _BangumiTrackingCollectionProvider(this._collectionProvider);

  final BangumiCollectionProvider _collectionProvider;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    final AcgProviderResult<List<BangumiAnimeCollectionItem>> result =
        await _collectionProvider.currentAnimeCollection();
    if (result is AcgProviderSuccess<List<BangumiAnimeCollectionItem>>) {
      return BangumiTrackingSnapshot.loaded(
        result.value.map(_trackingItemFromCollection),
      );
    }
    if (result is AcgProviderFailure<List<BangumiAnimeCollectionItem>>) {
      if (result.kind == AcgProviderFailureKind.unauthenticated) {
        return BangumiTrackingSnapshot.unauthenticated(result.message);
      }
      return BangumiTrackingSnapshot.failed(result.message);
    }
    return const BangumiTrackingSnapshot.failed('Bangumi 追番状态未知。');
  }
}

final class _BangumiTrackingStatusSyncProvider
    implements BangumiTrackingSyncProvider {
  const _BangumiTrackingStatusSyncProvider(this._syncProvider);

  final BangumiSubjectCollectionSyncProvider _syncProvider;

  @override
  Future<BangumiTrackingSyncResult> syncTrackingStatus({
    required String subjectId,
    required BangumiTrackingStatus status,
  }) async {
    final AcgProviderResult<void> result =
        await _syncProvider.syncSubjectCollection(
      BangumiSubjectCollectionUpdate(
        subjectId: BangumiSubjectId(subjectId),
        status: _subjectCollectionStatusFromTracking(status),
      ),
    );
    if (result is AcgProviderSuccess<void>) {
      return const BangumiTrackingSyncResult.success();
    }
    if (result is AcgProviderFailure<void>) {
      if (result.kind == AcgProviderFailureKind.unauthenticated) {
        return BangumiTrackingSyncResult.unauthenticated(result.message);
      }
      return BangumiTrackingSyncResult.failed(result.message);
    }
    return const BangumiTrackingSyncResult.failed(
      'Bangumi tracking sync state is unknown.',
    );
  }
}

final class _BangumiHomeRecommendationProvider
    implements HomeRecommendationProvider {
  const _BangumiHomeRecommendationProvider(this._discoveryProvider);

  final BangumiDiscoveryProvider _discoveryProvider;

  @override
  Future<HomeRecommendationSnapshot> trendingAnime({
    required int limit,
    required int offset,
  }) async {
    if (limit <= 0 || offset < 0) {
      return const HomeRecommendationSnapshot.failed(
        'Bangumi 推荐分页参数无效。',
      );
    }
    final AcgProviderResult<List<BangumiSubject>> result =
        await _discoveryProvider.trendingAnime(
      limit: limit,
      offset: offset,
    );
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      return HomeRecommendationSnapshot.loaded(
        result.value.map(_homeRecommendationItemFromSubject),
      );
    }
    if (result is AcgProviderFailure<List<BangumiSubject>>) {
      return HomeRecommendationSnapshot.failed(result.message);
    }
    return const HomeRecommendationSnapshot.failed('Bangumi 近期注目状态未知。');
  }

  @override
  Future<HomeRecommendationSnapshot> recentPopularAnime({
    required int limit,
    required int offset,
  }) async {
    if (limit <= 0 || offset < 0) {
      return const HomeRecommendationSnapshot.failed(
        'Bangumi 推荐分页参数无效。',
      );
    }
    final AcgProviderResult<List<BangumiSubject>> result =
        await _discoveryProvider.recentPopularAnime(
      limit: limit,
      offset: offset,
    );
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      return HomeRecommendationSnapshot.loaded(
        result.value.map(_homeRecommendationItemFromSubject),
      );
    }
    if (result is AcgProviderFailure<List<BangumiSubject>>) {
      return HomeRecommendationSnapshot.failed(result.message);
    }
    return const HomeRecommendationSnapshot.failed('Bangumi 近期热门状态未知。');
  }
}

HomeRecommendationItem _homeRecommendationItemFromSubject(
  BangumiSubject subject,
) {
  return HomeRecommendationItem(
    subjectId: subject.id.value,
    title: subject.title,
    summary: subject.summary,
    coverUri: subject.coverUri,
    rank: subject.rank,
    score: subject.score,
    collectionTotal: subject.collectionTotal,
    episodeCount: subject.episodeCount,
  );
}

final class _BangumiHomeSearchProvider implements HomeSearchProvider {
  const _BangumiHomeSearchProvider(this._provider);

  final BangumiProvider _provider;

  @override
  Future<HomeSearchSnapshot> searchAnime(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.length < homeSearchMinimumQueryLength) {
      return HomeSearchSnapshot.loaded(const <HomeSearchItem>[]);
    }
    final AcgProviderResult<List<BangumiSubject>> result =
        await _provider.searchSubjects(normalizedQuery);
    if (result is AcgProviderSuccess<List<BangumiSubject>>) {
      return HomeSearchSnapshot.loaded(
        result.value
            .take(homeSearchSuggestionLimit)
            .map(_homeSearchItemFromSubject),
      );
    }
    if (result is AcgProviderFailure<List<BangumiSubject>>) {
      return HomeSearchSnapshot.failed(result.message);
    }
    return const HomeSearchSnapshot.failed('Bangumi 搜索状态未知。');
  }
}

HomeSearchItem _homeSearchItemFromSubject(BangumiSubject subject) {
  return HomeSearchItem(
    subjectId: subject.id.value,
    title: subject.title,
    summary: subject.summary,
    coverUri: subject.coverUri,
    rank: subject.rank,
    score: subject.score,
    collectionTotal: subject.collectionTotal,
    episodeCount: subject.episodeCount,
  );
}

BangumiTrackingItem _trackingItemFromCollection(
  BangumiAnimeCollectionItem item,
) {
  return BangumiTrackingItem(
    subjectId: item.subjectId.value,
    title: item.title,
    status: _trackingStatusFromCollection(item.status),
    watchedEpisodes: item.watchedEpisodes,
    totalEpisodes: item.totalEpisodes,
    coverUri: item.coverUri,
    updatedAt: item.updatedAt,
  );
}

BangumiTrackingStatus _trackingStatusFromCollection(
  BangumiSubjectCollectionStatus status,
) {
  return switch (status) {
    BangumiSubjectCollectionStatus.planned => BangumiTrackingStatus.planned,
    BangumiSubjectCollectionStatus.completed => BangumiTrackingStatus.completed,
    BangumiSubjectCollectionStatus.watching => BangumiTrackingStatus.watching,
    BangumiSubjectCollectionStatus.onHold => BangumiTrackingStatus.onHold,
    BangumiSubjectCollectionStatus.dropped => BangumiTrackingStatus.dropped,
  };
}

BangumiSubjectCollectionStatus _subjectCollectionStatusFromTracking(
  BangumiTrackingStatus status,
) {
  return switch (status) {
    BangumiTrackingStatus.planned => BangumiSubjectCollectionStatus.planned,
    BangumiTrackingStatus.completed => BangumiSubjectCollectionStatus.completed,
    BangumiTrackingStatus.watching => BangumiSubjectCollectionStatus.watching,
    BangumiTrackingStatus.onHold => BangumiSubjectCollectionStatus.onHold,
    BangumiTrackingStatus.dropped => BangumiSubjectCollectionStatus.dropped,
  };
}
