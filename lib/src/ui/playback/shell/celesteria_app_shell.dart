import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../domain/detail/video_detail.dart';
import '../../../domain/diagnostics/diagnostics_domain.dart';
import '../../../domain/download/download_domain.dart';
import '../../../domain/media/media_library.dart';
import '../../../domain/media/media_library_runtime.dart';
import '../../../domain/playback/playback_controller.dart';
import '../../../domain/playback/playback_source_handoff.dart';
import '../../../domain/playback/playback_state.dart';
import '../../../domain/rss/rss_engine_runtime.dart';
import '../../../domain/settings/settings_domain.dart';
import '../../detail/video_detail_page.dart';
import '../../detail/video_detail_page_contract.dart';
import '../../diagnostics/diagnostics_page.dart';
import '../../download/downloads_page.dart';
import '../../media/media_library_page.dart';
import '../../rss/rss_page.dart';
import '../../settings/settings_page.dart';
import '../../theme/celesteria_theme.dart';
import '../../widgets/hero_carousel.dart';
import '../../widgets/hot_updates_carousel.dart';
import '../../widgets/particle_background.dart';
import '../production_playback_page.dart';

class CelesteriaAppShell extends StatefulWidget {
  const CelesteriaAppShell({
    super.key,
    required this.playbackController,
    required this.videoSurface,
    required this.mediaLibraryRuntime,
    required this.videoDetailPageContract,
    required this.rssEngineRuntime,
    required this.downloadRuntime,
    required this.settingsRuntime,
    required this.diagnosticsRuntime,
    this.carouselAutoScroll = true,
  });

  final PlaybackControllerContract playbackController;
  final Widget videoSurface;
  final MediaLibraryRuntime mediaLibraryRuntime;
  final VideoDetailPageContract videoDetailPageContract;
  final RssEngineRuntime rssEngineRuntime;
  final DownloadRuntime downloadRuntime;
  final SettingsRuntime settingsRuntime;
  final DiagnosticsRuntime diagnosticsRuntime;
  final bool carouselAutoScroll;

  @override
  State<CelesteriaAppShell> createState() => _CelesteriaAppShellState();
}

class _CelesteriaAppShellState extends State<CelesteriaAppShell>
    implements PlaybackStateObserver {
  int _currentIndex = 0;
  bool _playbackOverlayActive = false;
  VideoDetailId? _activeDetailId;

  @override
  void initState() {
    super.initState();
    widget.playbackController.addPlaybackStateObserver(this);
    _checkPlaybackState();
  }

  @override
  void dispose() {
    widget.playbackController.removePlaybackStateObserver(this);
    super.dispose();
  }

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    if (mounted) {
      _checkPlaybackState();
    }
  }

  void _checkPlaybackState() {
    final PlaybackLifecycleStatus status =
        widget.playbackController.currentState.status;
    final bool active = status != PlaybackLifecycleStatus.idle &&
        status != PlaybackLifecycleStatus.ended;
    if (_playbackOverlayActive != active) {
      setState(() {
        _playbackOverlayActive = active;
      });
    }
  }

  // ignore: unused_element  // TODO(ui): wire "open local file" action into the shell toolbar
  Future<void> _pickAndPlayFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.single.path != null) {
        final String path = result.files.single.path!;
        final Uri fileUri = Uri.file(path);

        const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
        final PlaybackSourceHandoffResult prepared = handoff.prepare(
          PlaybackSourceHandoffInput.localMediaIdentity(
            LocalMediaIdentity(
              id: LocalMediaId('local-${path.hashCode}'),
              uri: fileUri,
              basename: result.files.single.name,
            ),
          ),
        );

        if (prepared.isSuccess) {
          final DomainPlaybackCommandResult openResult =
              await widget.playbackController.open(prepared.source!);
          if (openResult.isSuccess) {
            await widget.playbackController.play();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('打开文件失败: ${openResult.failure?.message}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('解析文件失败: ${prepared.failure?.message}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件出错: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CelesteriaThemeData theme = CelesteriaTheme.of(context);

    // Build the correct sub-page
    final Widget mainPageContent = IndexedStack(
      index: _currentIndex,
      children: <Widget>[
        _buildHomePage(theme),
        _buildLibraryPage(theme),
        _buildDownloadsPage(theme),
        _buildRssPage(theme),
        _buildSettingsPage(theme),
        _buildDiagnosticsPage(theme),
      ],
    );

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: <Widget>[
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: theme.brightness == Brightness.dark ? 0.4 : 0.2,
              child: _ShellBackdrop(theme: theme),
            ),
          ),

          // Particle Animation Layer
          Positioned.fill(
            child: ParticleBackground(
              colors: theme.splatterColors,
            ),
          ),

          // Main App Layout
          Positioned.fill(
            child: Row(
              children: <Widget>[
                // Navigation rail
                _buildSidebar(theme),

                // Content Area
                Expanded(
                  child: mainPageContent,
                ),
              ],
            ),
          ),

          // Video Detail Page Overlay (grows on active detail id)
          if (_activeDetailId != null)
            Positioned.fill(
              child: VideoDetailPage(
                id: _activeDetailId!,
                videoDetailPageContract: widget.videoDetailPageContract,
                playbackController: widget.playbackController,
                onPlaybackStarted: () {},
                onClose: () {
                  setState(() {
                    _activeDetailId = null;
                  });
                },
              ),
            ),

          // Playback Screen Overlay (grows on active playback status)
          if (_playbackOverlayActive)
            Positioned.fill(
              child: ProductionPlaybackPage(
                controller: widget.playbackController,
                videoSurface: widget.videoSurface,
              ),
            ),
        ],
      ),
    );
  }

  // Navigation sidebar builder
  Widget _buildSidebar(CelesteriaThemeData theme) {
    final double sidebarWidth = 260.0;
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.6),
        border: Border(
          right: BorderSide(color: theme.border, width: 1.0),
        ),
      ),
      child: Column(
        children: <Widget>[
          // Logo & Name
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: theme.border),
                  ),
                  child: Icon(Icons.blur_on, color: theme.primary, size: 28),
                ),
                const SizedBox(width: 16.0),
                Text(
                  'PKPK',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: <Widget>[
                _buildSidebarItem(
                    0, Icons.home_outlined, Icons.home, '首页', theme),
                _buildSidebarItem(1, Icons.video_library_outlined,
                    Icons.video_library, '我的追番', theme),
                _buildSidebarItem(
                    2, Icons.download_outlined, Icons.download, '下载', theme),
                _buildSidebarItem(
                    3, Icons.rss_feed, Icons.rss_feed, 'RSS订阅', theme),
              ],
            ),
          ),

          // Bottom Items
          Padding(
            padding:
                const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
            child: Column(
              children: <Widget>[
                _buildSidebarItem(
                    4, Icons.settings_outlined, Icons.settings, '设置', theme),
                _buildSidebarItem(5, Icons.troubleshoot_outlined,
                    Icons.troubleshoot, '诊断', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
    CelesteriaThemeData theme,
  ) {
    final bool isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24.0),
            bottomRight: Radius.circular(24.0),
            topLeft: Radius.circular(4.0),
            bottomLeft: Radius.circular(4.0),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24.0),
                bottomRight: Radius.circular(24.0),
                topLeft: Radius.circular(4.0),
                bottomLeft: Radius.circular(4.0),
              ),
              border: isSelected
                  ? Border(left: BorderSide(color: theme.primary, width: 4.0))
                  : const Border(
                      left: BorderSide(color: Colors.transparent, width: 4.0)),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: theme.primary.withValues(alpha: 0.3),
                          blurRadius: 12.0)
                    ]
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected
                      ? theme.primary
                      : theme.onBackground.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 16.0),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.primary
                        : theme.onBackground.withValues(alpha: 0.8),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Beautiful Home Page
  Widget _buildHomePage(CelesteriaThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '欢迎回来，指挥官！',
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrentDate(),
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  // Theme Toggle
                  _buildThemeToggle(context),
                  const SizedBox(width: 16),
                  // Profile Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.secondary.withValues(alpha: 0.3),
                    child: Icon(Icons.person, color: theme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Scrollable Content
          Expanded(
            child: ListView(
              children: <Widget>[
                // Hero Banner
                HeroCarousel(autoScroll: widget.carouselAutoScroll),
                const SizedBox(height: 32),

                // Hot updates section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.local_fire_department,
                            color: theme.accentMagenta, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '热门更新',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        '查看全部',
                        style: TextStyle(
                          color: theme.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                HotUpdatesCarousel(autoScroll: widget.carouselAutoScroll),
                const SizedBox(height: 32),

                // Recommendations section
                Text(
                  '更多推荐',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecommendationsGrid(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Theme selector slider
  Widget _buildThemeToggle(BuildContext context) {
    final CelesteriaTheme theme = CelesteriaTheme.controllerOf(context);
    final bool isDark = theme.data.brightness == Brightness.dark;

    return Container(
      width: 96,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300FBFB),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Sliding Thumb
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 40,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FBFB).withValues(alpha: 0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          ),
          // Interactive icons
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                GestureDetector(
                  onTap: () => theme.onModeChanged(CelesteriaThemeMode.light),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.light_mode,
                      size: 18,
                      color: !isDark
                          ? theme.data.primary
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => theme.onModeChanged(CelesteriaThemeMode.dark),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.dark_mode,
                      size: 18,
                      color: isDark
                          ? theme.data.primary
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsGrid(CelesteriaThemeData theme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      childAspectRatio: 1.5,
      children: <Widget>[
        _buildRecCard('星际回响', '12 话全', '9.8 ★', 'SE', 0, theme),
        _buildRecCard('霓虹协议', '更新至 08 话', '9.5 ★', 'NP', 1, theme),
        _buildRecCard('绯红地平线', '24 话全', '9.2 ★', 'CH', 2, theme),
      ],
    );
  }

  Widget _buildRecCard(
    String title,
    String subtitle,
    String rating,
    String symbol,
    int accentIndex,
    CelesteriaThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.0),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _RecommendationBackdrop(
            symbol: symbol,
            accentIndex: accentIndex,
            theme: theme,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8)
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      rating,
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Library Page
  Widget _buildLibraryPage(CelesteriaThemeData theme) {
    return MediaLibraryPage(
      mediaLibraryRuntime: widget.mediaLibraryRuntime,
      playbackController: widget.playbackController,
      onNavigateToDetail: (String idValue) {
        setState(() {
          _activeDetailId = VideoDetailId(idValue);
        });
      },
    );
  }

  // 3. Downloads Page
  Widget _buildDownloadsPage(CelesteriaThemeData theme) {
    return DownloadsPage(
      downloadRuntime: widget.downloadRuntime,
    );
  }

  // 4. RSS Page
  Widget _buildRssPage(CelesteriaThemeData theme) {
    return RssPage(
      rssEngineRuntime: widget.rssEngineRuntime,
    );
  }

  // 5. Settings Page
  Widget _buildSettingsPage(CelesteriaThemeData theme) {
    return SettingsPage(
      settingsRuntime: widget.settingsRuntime,
    );
  }

  // 6. Diagnostics Page
  Widget _buildDiagnosticsPage(CelesteriaThemeData theme) {
    return DiagnosticsPage(
      diagnosticsRuntime: widget.diagnosticsRuntime,
    );
  }

  String _formatCurrentDate() {
    final DateTime now = DateTime.now();
    final List<String> weekdays = const <String>[
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ];
    final String weekdayStr = weekdays[now.weekday - 1];
    return '${now.year}年${now.month}月${now.day}日 $weekdayStr';
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop({required this.theme});

  final CelesteriaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.background,
            theme.primary.withValues(alpha: 0.22),
            theme.accentMagenta.withValues(alpha: 0.16),
            theme.surface,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -96,
            top: -80,
            child: Icon(
              Icons.blur_on,
              size: 360,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: 280,
            bottom: -120,
            child: Icon(
              Icons.auto_awesome,
              size: 320,
              color: theme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationBackdrop extends StatelessWidget {
  const _RecommendationBackdrop({
    required this.symbol,
    required this.accentIndex,
    required this.theme,
  });

  final String symbol;
  final int accentIndex;
  final CelesteriaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final List<List<Color>> palettes = <List<Color>>[
      <Color>[theme.primary, theme.accentMagenta],
      <Color>[theme.secondary, const Color(0xFF4F46E5)],
      <Color>[const Color(0xFFFF5A6A), const Color(0xFF2D1B69)],
    ];
    final List<Color> colors = palettes[accentIndex % palettes.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -20,
            top: -28,
            child: Icon(
              Icons.blur_on,
              size: 140,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: 16,
            top: 14,
            child: Text(
              symbol,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
