import 'package:flutter/material.dart';

import 'src/app_composition.dart';
import 'src/domain/diagnostics/diagnostics_domain.dart';
import 'src/domain/download/download_domain.dart';
import 'src/domain/media/media_library_runtime.dart';
import 'src/domain/playback/playback_controller.dart';
import 'src/domain/playback/player_core_bootstrap.dart';
import 'src/domain/rss/rss_engine_runtime.dart';
import 'src/domain/settings/settings_domain.dart';
import 'src/foundation/storage/rss_auto_download_policy_storage_contracts.dart';
import 'src/provider/bangumi/bangumi_auth.dart';
import 'src/streaming/bt_task_core_runtime.dart';
import 'src/ui/detail/video_detail_page_contract.dart';
import 'src/ui/playback/shell/celesteria_app_shell.dart';
import 'src/ui/theme/celesteria_theme.dart';

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
    this.bangumiAuthProvider,
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
  final BangumiAuthProvider? bangumiAuthProvider;

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
  late final BangumiAuthProvider? _bangumiAuthProvider;

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
      _bangumiAuthProvider = widget.bangumiAuthProvider;
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
      _bangumiAuthProvider = _composition!.bangumiAuthProvider;
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
    return CelesteriaThemeProvider(
      initialMode: CelesteriaThemeMode.auto,
      child: Builder(
        builder: (BuildContext context) {
          final CelesteriaThemeData theme = CelesteriaTheme.of(context);
          return MaterialApp(
            title: 'Celesteria ACG Player',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: theme.brightness,
              scaffoldBackgroundColor: theme.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.primary,
                brightness: theme.brightness,
              ),
              useMaterial3: true,
            ),
            home: CelesteriaAppShell(
              playbackController: _playbackController,
              videoSurface: _videoSurface,
              mediaLibraryRuntime: _mediaLibraryRuntime,
              videoDetailPageContract: _videoDetailPageContract,
              rssEngineRuntime: _rssEngineRuntime,
              downloadRuntime: _downloadRuntime,
              settingsRuntime: _settingsRuntime,
              diagnosticsRuntime: _diagnosticsRuntime,
              bangumiAuthProvider: _bangumiAuthProvider,
            ),
          );
        },
      ),
    );
  }
}
