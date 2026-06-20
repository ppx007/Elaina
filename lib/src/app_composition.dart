import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'domain/detail/video_detail_bootstrap.dart';
import 'domain/diagnostics/diagnostics_domain.dart';
import 'domain/media/local_file_media_scanner.dart';
import 'domain/media/media_library_runtime.dart';
import 'domain/media/media_library_storage_adapters.dart';
import 'domain/playback/playback_source_handoff.dart';
import 'domain/profile/bangumi_login_domain.dart';
import 'domain/profile/profile_domain.dart';
import 'domain/rss/rss_engine_runtime.dart';
import 'domain/settings/settings_domain.dart';
import 'foundation/constants.dart';
import 'foundation/diagnostics/diagnostics_center.dart';
import 'foundation/diagnostics/diagnostics_center_runtime.dart';
import 'foundation/foundation_bootstrap.dart';
import 'gateway/network_policy_provider_gateway.dart';
import 'playback/media_kit_mpv_binding.dart';
import 'playback/player_runtime_composition.dart';
import 'provider/bangumi/bangumi_api_client.dart';
import 'provider/bangumi/bangumi_auth.dart';
import 'provider/bangumi/bangumi_runtime.dart';
import 'provider/provider_result.dart';
import 'provider/rss/rss_feed_fetcher_parser.dart';
import 'streaming/bt_task_core_runtime.dart';
import 'streaming/libtorrent_download_engine_adapter.dart';
import 'ui/detail/video_detail_page_contract.dart';

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
    );
    bangumiAuthProvider = bangumiProviderRuntime;
    profileProvider = _BangumiUserProfileProvider(bangumiAuthProvider);

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
    );

    videoDetailPageContract = VideoDetailPageContract(
      controller: videoDetailBootstrap.controller,
    );

    // 6. RSS Engine Runtime
    final transport = HttpFeedHttpTransport();
    final fetcher = HttpFeedFetcher(
      gateway: providerGateway,
      transport: transport,
    );
    const parser = AutoXmlFeedParser();
    const scheduler = PeriodicFeedScheduler();

    rssEngineRuntime = RssEngineBootstrap(
      store: foundation.storage.rssFeed,
      fetcher: fetcher,
      parser: parser,
      scheduler: scheduler,
      policyStore: foundation.storage.rssAutoDownloadPolicy,
    ).runtime;

    // 6. BT Task Core Runtime
    final btTaskComposition = libtorrentBtTaskRuntimeComposition(
      store: foundation.storage.btTask,
      cacheInvalidationBus: foundation.invalidationBus,
    );
    btTaskCoreRuntime = BtTaskCoreBootstrap.withComposition(
      composition: btTaskComposition,
    ).runtime;

    // 7. Settings Runtime
    settingsRuntime = SettingsRuntimeAdapter(
      settingsStore: foundation.storage.settings,
      networkPolicyStore: foundation.storage.networkPolicy,
    );
    bangumiLoginController = _BangumiLoginController(
      settingsRuntime: settingsRuntime,
      authProvider: bangumiAuthProvider,
      tokenAcquisitionUri: bangumiApiClient.accessTokenPageUri(),
      openExternalUri: const _SystemExternalUriLauncher().open,
    );

    // 8. Diagnostics Runtime
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
  late final SettingsRuntime settingsRuntime;
  late final DiagnosticsRuntime diagnosticsRuntime;
  late final BangumiProviderRuntime bangumiProviderRuntime;
  late final BangumiAuthProvider bangumiAuthProvider;
  late final BangumiLoginController bangumiLoginController;
  late final UserProfileProvider profileProvider;

  Widget buildVideoSurface(BuildContext context) {
    return Video(controller: videoController);
  }

  void dispose() {
    mediaLibraryRuntime.dispose();
    videoDetailBootstrap.dispose();
    bangumiProviderRuntime.dispose();
    rssEngineRuntime.dispose();
    btTaskCoreRuntime.dispose();
    foundation.dispose();
  }
}

typedef _OpenExternalUri = Future<bool> Function(Uri uri);

final class _BangumiLoginController implements BangumiLoginController {
  const _BangumiLoginController({
    required SettingsRuntime settingsRuntime,
    required BangumiAuthProvider authProvider,
    required Uri tokenAcquisitionUri,
    required _OpenExternalUri openExternalUri,
  })  : _settingsRuntime = settingsRuntime,
        _authProvider = authProvider,
        _tokenAcquisitionUri = tokenAcquisitionUri,
        _openExternalUri = openExternalUri;

  final SettingsRuntime _settingsRuntime;
  final BangumiAuthProvider _authProvider;
  final Uri _tokenAcquisitionUri;
  final _OpenExternalUri _openExternalUri;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    try {
      final bool opened = await _openExternalUri(_tokenAcquisitionUri);
      if (!opened) {
        return const BangumiLoginStartResult.unavailable(
          '无法打开系统浏览器。',
        );
      }
      return BangumiLoginStartResult.opened(_tokenAcquisitionUri);
    } catch (error) {
      return BangumiLoginStartResult.failed('打开 Bangumi token 获取页失败: $error');
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

final class _SystemExternalUriLauncher {
  const _SystemExternalUriLauncher();

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

  Future<bool> _startDetached(String executable, List<String> arguments) async {
    final Process process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
    unawaited(process.exitCode);
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
