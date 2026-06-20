import 'package:flutter/material.dart';

import 'src/app_composition.dart';
import 'src/domain/diagnostics/diagnostics_domain.dart';
import 'src/domain/download/download_domain.dart';
import 'src/domain/home/home_recommendation_domain.dart';
import 'src/domain/media/media_library_runtime.dart';
import 'src/domain/playback/playback_controller.dart';
import 'src/domain/playback/player_core_bootstrap.dart';
import 'src/domain/profile/bangumi_login_domain.dart';
import 'src/domain/profile/bangumi_tracking_domain.dart';
import 'src/domain/profile/profile_domain.dart';
import 'src/domain/rss/rss_engine_runtime.dart';
import 'src/domain/settings/settings_domain.dart';
import 'src/foundation/storage/rss_auto_download_policy_storage_contracts.dart';
import 'src/streaming/bt_task_core_runtime.dart';
import 'src/ui/detail/video_detail_page_contract.dart';
import 'src/ui/playback/shell/elaina_app_shell.dart';
import 'src/ui/theme/elaina_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.playbackController,
    this.videoSurface,
    this.mediaLibraryRuntime,
    this.videoDetailPageContract,
    this.rssEngineRuntime,
    this.btTaskCoreRuntime,
    this.policyStore,
    this.settingsRuntime,
    this.diagnosticsRuntime,
    this.profileProvider,
    this.bangumiTrackingProvider,
    this.bangumiLoginController,
    this.homeRecommendationProvider,
  });

  final PlaybackControllerContract? playbackController;
  final Widget? videoSurface;
  final MediaLibraryRuntime? mediaLibraryRuntime;
  final VideoDetailPageContract? videoDetailPageContract;
  final RssEngineRuntime? rssEngineRuntime;
  final BtTaskCoreRuntime? btTaskCoreRuntime;
  final RssAutoDownloadPolicyStore? policyStore;
  final SettingsRuntime? settingsRuntime;
  final DiagnosticsRuntime? diagnosticsRuntime;
  final UserProfileProvider? profileProvider;
  final BangumiTrackingProvider? bangumiTrackingProvider;
  final BangumiLoginController? bangumiLoginController;
  final HomeRecommendationProvider? homeRecommendationProvider;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppComposition? _composition;
  PlayerCoreBootstrap? _bootstrap;
  late final PlaybackControllerContract _playbackController;
  late final Widget _videoSurface;
  late final MediaLibraryRuntime _mediaLibraryRuntime;
  late final VideoDetailPageContract _videoDetailPageContract;
  late final RssEngineRuntime _rssEngineRuntime;
  late final BtTaskCoreRuntime _btTaskCoreRuntime;
  late final DownloadRuntime _downloadRuntime;
  late final SettingsRuntime _settingsRuntime;
  late final DiagnosticsRuntime _diagnosticsRuntime;
  late final UserProfileProvider? _profileProvider;
  late final BangumiTrackingProvider? _bangumiTrackingProvider;
  late final BangumiLoginController? _bangumiLoginController;
  late final HomeRecommendationProvider? _homeRecommendationProvider;

  @override
  void initState() {
    super.initState();
    if (widget.playbackController != null &&
        widget.videoSurface != null &&
        widget.mediaLibraryRuntime != null &&
        widget.videoDetailPageContract != null &&
        widget.rssEngineRuntime != null &&
        widget.btTaskCoreRuntime != null &&
        widget.policyStore != null) {
      _playbackController = widget.playbackController!;
      _videoSurface = widget.videoSurface!;
      _mediaLibraryRuntime = widget.mediaLibraryRuntime!;
      _videoDetailPageContract = widget.videoDetailPageContract!;
      _rssEngineRuntime = widget.rssEngineRuntime!;
      _btTaskCoreRuntime = widget.btTaskCoreRuntime!;
      _settingsRuntime = widget.settingsRuntime ?? FakeSettingsRuntime();
      _diagnosticsRuntime =
          widget.diagnosticsRuntime ?? FakeDiagnosticsRuntime();
      _profileProvider = widget.profileProvider;
      _bangumiTrackingProvider = widget.bangumiTrackingProvider;
      _bangumiLoginController = widget.bangumiLoginController;
      _homeRecommendationProvider = widget.homeRecommendationProvider;
    } else {
      _composition = AppComposition();
      _bootstrap = PlayerCoreBootstrap.withComposition(
        composition: _composition!.playbackComposition,
      );
      _playbackController = _bootstrap!.controller;
      _videoSurface = _composition!.buildVideoSurface(context);
      _mediaLibraryRuntime = _composition!.mediaLibraryRuntime;
      _videoDetailPageContract = _composition!.videoDetailPageContract;
      _rssEngineRuntime = _composition!.rssEngineRuntime;
      _btTaskCoreRuntime = _composition!.btTaskCoreRuntime;
      _settingsRuntime = _composition!.settingsRuntime;
      _diagnosticsRuntime = _composition!.diagnosticsRuntime;
      _profileProvider = _composition!.profileProvider;
      _bangumiTrackingProvider = _composition!.trackingProvider;
      _bangumiLoginController = _composition!.bangumiLoginController;
      _homeRecommendationProvider = _composition!.homeRecommendationProvider;
    }
    _downloadRuntime = DownloadRuntimeAdapter(_btTaskCoreRuntime);
  }

  @override
  void dispose() {
    _downloadRuntime.dispose();
    _bootstrap?.dispose();
    _composition?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElainaThemeProvider(
      initialMode: ElainaThemeMode.auto,
      child: Builder(
        builder: (BuildContext context) {
          final ElainaThemeData theme = ElainaTheme.of(context);
          const WidgetStateMouseCursor clickCursor =
              WidgetStateMouseCursor.clickable;
          return MaterialApp(
            title: 'Elaina ACG Player',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: theme.brightness,
              scaffoldBackgroundColor: theme.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.primary,
                brightness: theme.brightness,
              ),
              useMaterial3: true,
              iconButtonTheme: IconButtonThemeData(
                style: ButtonStyle(mouseCursor: clickCursor),
              ),
              textButtonTheme: TextButtonThemeData(
                style: ButtonStyle(mouseCursor: clickCursor),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(mouseCursor: clickCursor),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: ButtonStyle(mouseCursor: clickCursor),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: ButtonStyle(mouseCursor: clickCursor),
              ),
              switchTheme: SwitchThemeData(mouseCursor: clickCursor),
              checkboxTheme: CheckboxThemeData(mouseCursor: clickCursor),
              radioTheme: RadioThemeData(mouseCursor: clickCursor),
            ),
            home: ElainaAppShell(
              playbackController: _playbackController,
              videoSurface: _videoSurface,
              mediaLibraryRuntime: _mediaLibraryRuntime,
              videoDetailPageContract: _videoDetailPageContract,
              rssEngineRuntime: _rssEngineRuntime,
              downloadRuntime: _downloadRuntime,
              settingsRuntime: _settingsRuntime,
              diagnosticsRuntime: _diagnosticsRuntime,
              profileProvider: _profileProvider,
              bangumiTrackingProvider: _bangumiTrackingProvider,
              bangumiLoginController: _bangumiLoginController,
              homeRecommendationProvider: _homeRecommendationProvider,
            ),
          );
        },
      ),
    );
  }
}
