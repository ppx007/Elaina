import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/detail/video_detail.dart';
import '../../../domain/diagnostics/diagnostics_domain.dart';
import '../../../domain/download/download_domain.dart';
import '../../../domain/media/media_library.dart';
import '../../../domain/media/media_library_runtime.dart';
import '../../../domain/playback/playback_controller.dart';
import '../../../domain/playback/playback_state.dart';
import '../../../domain/profile/bangumi_login_domain.dart';
import '../../../domain/profile/profile_domain.dart';
import '../../../domain/rss/rss_engine_runtime.dart';
import '../../../domain/settings/settings_domain.dart';
import '../../detail/video_detail_page.dart';
import '../../detail/video_detail_page_contract.dart';
import '../../diagnostics/diagnostics_page.dart';
import '../../download/downloads_page.dart';
import '../../media/media_library_page.dart';
import '../../rss/rss_page.dart';
import '../../settings/settings_page.dart';
import '../../theme/elaina_theme.dart';
import '../../widgets/hero_carousel.dart';
import '../../widgets/hot_updates_carousel.dart';
import '../../widgets/particle_background.dart';
import '../production_playback_page.dart';

class ElainaAppShell extends StatefulWidget {
  const ElainaAppShell({
    super.key,
    required this.playbackController,
    required this.videoSurface,
    required this.mediaLibraryRuntime,
    required this.videoDetailPageContract,
    required this.rssEngineRuntime,
    required this.downloadRuntime,
    required this.settingsRuntime,
    required this.diagnosticsRuntime,
    this.profileProvider,
    this.bangumiLoginController,
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
  final UserProfileProvider? profileProvider;
  final BangumiLoginController? bangumiLoginController;
  final bool carouselAutoScroll;

  @override
  State<ElainaAppShell> createState() => _ElainaAppShellState();
}

class _ElainaAppShellState extends State<ElainaAppShell>
    implements PlaybackStateObserver, MediaLibraryRuntimeObserver {
  static const int _homeNavIndex = 0;
  static const int _trackingNavIndex = 1;
  static const int _localLibraryNavIndex = 2;
  static const int _downloadsNavIndex = 3;
  static const int _rssNavIndex = 4;
  static const int _settingsNavIndex = 5;
  static const int _diagnosticsNavIndex = 6;

  static const double _pageInset = 24;
  static const double _sectionGap = 24;
  static const double _panelRadius = 16;
  static const double _trackingGridMaxExtent = 360;
  static const double _trackingGridAspectRatio = 1.55;
  static const double _completedProgressThreshold = 0.98;
  static const String _brandLogoAsset =
      'assets/brand/elaina_iconic_character_logo.png';

  int _currentIndex = _homeNavIndex;
  bool _playbackOverlayActive = false;
  VideoDetailId? _activeDetailId;
  int _bangumiAuthRevision = 0;
  late MediaLibraryRuntimeSnapshot _librarySnapshot;
  Future<UserProfileSnapshot?>? _profileFuture;
  _TrackingFilter _trackingFilter = _TrackingFilter.all;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileProvider?.currentProfile();
    _librarySnapshot = widget.mediaLibraryRuntime.currentSnapshot;
    widget.playbackController.addPlaybackStateObserver(this);
    widget.mediaLibraryRuntime.addObserver(this);
    _refreshLibrarySnapshot();
    _checkPlaybackState();
  }

  @override
  void didUpdateWidget(ElainaAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaLibraryRuntime != widget.mediaLibraryRuntime) {
      oldWidget.mediaLibraryRuntime.removeObserver(this);
      _librarySnapshot = widget.mediaLibraryRuntime.currentSnapshot;
      widget.mediaLibraryRuntime.addObserver(this);
      _refreshLibrarySnapshot();
    }
    if (oldWidget.profileProvider != widget.profileProvider) {
      _profileFuture = widget.profileProvider?.currentProfile();
    }
  }

  @override
  void dispose() {
    widget.mediaLibraryRuntime.removeObserver(this);
    widget.playbackController.removePlaybackStateObserver(this);
    super.dispose();
  }

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    if (mounted) {
      _checkPlaybackState();
    }
  }

  @override
  void onMediaLibraryRuntimeSnapshot(MediaLibraryRuntimeSnapshot snapshot) {
    if (mounted) {
      setState(() {
        _librarySnapshot = snapshot;
      });
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

  void _refreshBangumiProfile() {
    setState(() {
      _bangumiAuthRevision++;
      _profileFuture = widget.profileProvider?.currentProfile();
    });
  }

  void _refreshLibrarySnapshot() {
    unawaited(widget.mediaLibraryRuntime.refresh());
  }

  void _openBangumiSettings() {
    setState(() {
      _currentIndex = _settingsNavIndex;
    });
  }

  Future<void> _startBangumiLogin() async {
    final BangumiLoginController? loginController =
        widget.bangumiLoginController;
    if (loginController == null) {
      _openBangumiSettings();
      return;
    }

    final BangumiLoginStartResult result = await loginController.startLogin();
    if (!mounted) return;
    final String? message = switch (result.status) {
      BangumiLoginStartStatus.opened => '已打开 Bangumi token 获取页面',
      BangumiLoginStartStatus.unavailable => result.message,
      BangumiLoginStartStatus.failed => result.message,
    };
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);

    // Build the correct sub-page
    final Widget mainPageContent = IndexedStack(
      index: _currentIndex,
      children: <Widget>[
        _buildHomePage(theme),
        _buildTrackingPage(theme),
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
  Widget _buildSidebar(ElainaThemeData theme) {
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
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    _brandLogoAsset,
                    fit: BoxFit.cover,
                    semanticLabel: 'Elaina',
                  ),
                ),
                const SizedBox(width: 16.0),
                Text(
                  'Elaina',
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
                _buildSidebarItem(_homeNavIndex, Icons.home_outlined,
                    Icons.home, '首页', theme),
                _buildSidebarItem(_trackingNavIndex, Icons.bookmarks_outlined,
                    Icons.bookmarks, '我的追番', theme),
                _buildSidebarItem(
                    _localLibraryNavIndex,
                    Icons.video_library_outlined,
                    Icons.video_library,
                    '本地媒体库',
                    theme),
                _buildSidebarItem(_downloadsNavIndex, Icons.download_outlined,
                    Icons.download, '下载', theme),
                _buildSidebarItem(_rssNavIndex, Icons.rss_feed, Icons.rss_feed,
                    'RSS订阅', theme),
              ],
            ),
          ),

          // Bottom Items
          Padding(
            padding:
                const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
            child: Column(
              children: <Widget>[
                _buildSidebarItem(_settingsNavIndex, Icons.settings_outlined,
                    Icons.settings, '设置', theme),
                _buildSidebarItem(
                    _diagnosticsNavIndex,
                    Icons.troubleshoot_outlined,
                    Icons.troubleshoot,
                    '诊断',
                    theme),
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
    ElainaThemeData theme,
  ) {
    final bool isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
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
  Widget _buildHomePage(ElainaThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _WelcomeTitle(
                      profileFuture: _profileFuture,
                      theme: theme,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrentDate(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Theme Toggle
                  _buildThemeToggle(context),
                  const SizedBox(width: 16),
                  _BangumiProfileAvatar(
                    profileFuture: _profileFuture,
                    theme: theme,
                    refreshRevision: _bangumiAuthRevision,
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
    final ElainaTheme theme = ElainaTheme.controllerOf(context);
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
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => theme.onModeChanged(ElainaThemeMode.light),
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
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => theme.onModeChanged(ElainaThemeMode.dark),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsGrid(ElainaThemeData theme) {
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
    ElainaThemeData theme,
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

  // 2. Bangumi tracking page
  Widget _buildTrackingPage(ElainaThemeData theme) {
    final List<_TrackedBangumiItem> trackedItems = _trackedBangumiItems();
    final List<_TrackedBangumiItem> visibleItems =
        _trackedBangumiItemsFor(_trackingFilter, trackedItems);
    final int continuingCount = trackedItems
        .where((_TrackedBangumiItem item) =>
            item.progress > 0 && item.progress < _completedProgressThreshold)
        .length;
    final int completedCount = trackedItems
        .where((_TrackedBangumiItem item) =>
            item.progress >= _completedProgressThreshold)
        .length;
    final int unboundCount = _librarySnapshot.catalogItems
        .where((MediaLibraryCatalogItemState item) => item.binding == null)
        .length;

    return Padding(
      padding: const EdgeInsets.all(_pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '我的追番',
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _BangumiAccountPill(
                profileFuture: _profileFuture,
                theme: theme,
                onPressed: _startBangumiLogin,
              ),
            ],
          ),
          const SizedBox(height: _sectionGap),
          Row(
            children: <Widget>[
              Expanded(
                child: _TrackingMetricTile(
                  label: 'Bangumi 追番',
                  value: trackedItems.length.toString(),
                  icon: Icons.bookmarks,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrackingMetricTile(
                  label: '继续观看',
                  value: continuingCount.toString(),
                  icon: Icons.play_circle_outline,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrackingMetricTile(
                  label: '已看完',
                  value: completedCount.toString(),
                  icon: Icons.task_alt,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrackingMetricTile(
                  label: '待关联',
                  value: unboundCount.toString(),
                  icon: Icons.link_off,
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: _sectionGap),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(_panelRadius),
                border: Border.all(color: theme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _TrackingFilterBar(
                      selected: _trackingFilter,
                      counts: _trackingFilterCounts(trackedItems),
                      theme: theme,
                      onSelected: (_TrackingFilter filter) {
                        setState(() {
                          _trackingFilter = filter;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: visibleItems.isEmpty
                          ? _TrackingEmptyState(
                              filter: _trackingFilter,
                              hasAnyTrackedItem: trackedItems.isNotEmpty,
                              theme: theme,
                              onOpenLibrary: () {
                                setState(() {
                                  _currentIndex = _localLibraryNavIndex;
                                });
                              },
                              onLogin: _startBangumiLogin,
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: _trackingGridMaxExtent,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: _trackingGridAspectRatio,
                              ),
                              itemCount: visibleItems.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _TrackedBangumiItem item =
                                    visibleItems[index];
                                return _TrackingItemCard(
                                  item: item,
                                  theme: theme,
                                  onOpenDetail: () {
                                    setState(() {
                                      _activeDetailId =
                                          VideoDetailId(item.subjectId);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TrackedBangumiItem> _trackedBangumiItems() {
    final List<_TrackedBangumiItem> items = <_TrackedBangumiItem>[];
    for (final MediaLibraryCatalogItemState itemState
        in _librarySnapshot.catalogItems) {
      final ProviderBinding? binding = itemState.binding;
      final String? subjectId = binding?.subjectId?.value;
      if (binding == null ||
          subjectId == null ||
          binding.providerId != defaultVideoDetailMetadataProviderId ||
          binding.authority != ProviderBindingAuthority.userConfirmed) {
        continue;
      }
      items.add(
        _TrackedBangumiItem(
          subjectId: subjectId,
          title: itemState.item.identity.basename,
          progress: itemState.continueWatching?.progress ?? 0,
          updatedAt: itemState.continueWatching?.updatedAt,
        ),
      );
    }
    items.sort(
      (_TrackedBangumiItem left, _TrackedBangumiItem right) {
        final DateTime? leftUpdated = left.updatedAt;
        final DateTime? rightUpdated = right.updatedAt;
        if (leftUpdated == null && rightUpdated == null) {
          return left.title.compareTo(right.title);
        }
        if (leftUpdated == null) return 1;
        if (rightUpdated == null) return -1;
        return rightUpdated.compareTo(leftUpdated);
      },
    );
    return items;
  }

  Map<_TrackingFilter, int> _trackingFilterCounts(
    List<_TrackedBangumiItem> items,
  ) {
    return <_TrackingFilter, int>{
      for (final _TrackingFilter filter in _TrackingFilter.values)
        filter: _trackedBangumiItemsFor(filter, items).length,
    };
  }

  List<_TrackedBangumiItem> _trackedBangumiItemsFor(
    _TrackingFilter filter,
    List<_TrackedBangumiItem> items,
  ) {
    return <_TrackedBangumiItem>[
      for (final _TrackedBangumiItem item in items)
        if (_matchesTrackingFilter(filter, item)) item,
    ];
  }

  bool _matchesTrackingFilter(
    _TrackingFilter filter,
    _TrackedBangumiItem item,
  ) {
    return switch (filter) {
      _TrackingFilter.all => true,
      _TrackingFilter.watching =>
        item.progress > 0 && item.progress < _completedProgressThreshold,
      _TrackingFilter.planned => item.progress == 0,
      _TrackingFilter.completed => item.progress >= _completedProgressThreshold,
      _TrackingFilter.onHold => false,
      _TrackingFilter.dropped => false,
    };
  }

  // 3. Library Page
  Widget _buildLibraryPage(ElainaThemeData theme) {
    return MediaLibraryPage(
      mediaLibraryRuntime: widget.mediaLibraryRuntime,
      playbackController: widget.playbackController,
      settingsRuntime: widget.settingsRuntime,
      onNavigateToDetail: (String idValue) {
        setState(() {
          _activeDetailId = VideoDetailId(idValue);
        });
      },
    );
  }

  // 4. Downloads Page
  Widget _buildDownloadsPage(ElainaThemeData theme) {
    return DownloadsPage(
      downloadRuntime: widget.downloadRuntime,
    );
  }

  // 5. RSS Page
  Widget _buildRssPage(ElainaThemeData theme) {
    return RssPage(
      rssEngineRuntime: widget.rssEngineRuntime,
    );
  }

  // 6. Settings Page
  Widget _buildSettingsPage(ElainaThemeData theme) {
    return SettingsPage(
      settingsRuntime: widget.settingsRuntime,
      bangumiLoginController: widget.bangumiLoginController,
      onBangumiAuthChanged: _refreshBangumiProfile,
    );
  }

  // 7. Diagnostics Page
  Widget _buildDiagnosticsPage(ElainaThemeData theme) {
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

enum _TrackingFilter {
  all('全部'),
  watching('在追'),
  planned('想看'),
  completed('已看'),
  onHold('搁置'),
  dropped('抛弃');

  const _TrackingFilter(this.label);

  final String label;
}

final class _TrackedBangumiItem {
  const _TrackedBangumiItem({
    required this.subjectId,
    required this.title,
    required this.progress,
    this.updatedAt,
  });

  final String subjectId;
  final String title;
  final double progress;
  final DateTime? updatedAt;

  bool get hasProgress => progress > 0;

  String get progressLabel {
    if (!hasProgress) return '未开始';
    final int percent = (progress * 100).round().clamp(1, 100);
    return '已观看 $percent%';
  }
}

class _BangumiAccountPill extends StatelessWidget {
  const _BangumiAccountPill({
    required this.profileFuture,
    required this.theme,
    required this.onPressed,
  });

  static const double _pillRadius = 999;

  final Future<UserProfileSnapshot?>? profileFuture;
  final ElainaThemeData theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Future<UserProfileSnapshot?>? future = profileFuture;
    if (future == null) {
      return _buildPill('登录 Bangumi', Icons.login);
    }
    return FutureBuilder<UserProfileSnapshot?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<UserProfileSnapshot?> snapshot) {
        final String? displayName = snapshot.data?.displayName?.trim();
        if (displayName == null || displayName.isEmpty) {
          return _buildPill('登录 Bangumi', Icons.login);
        }
        return _buildPill('Bangumi：$displayName', Icons.verified_user);
      },
    );
  }

  Widget _buildPill(String label, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(color: theme.primary.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingFilterBar extends StatelessWidget {
  const _TrackingFilterBar({
    required this.selected,
    required this.counts,
    required this.theme,
    required this.onSelected,
  });

  static const double _chipGap = 8;
  static const double _chipRunGap = 8;

  final _TrackingFilter selected;
  final Map<_TrackingFilter, int> counts;
  final ElainaThemeData theme;
  final ValueChanged<_TrackingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _chipGap,
      runSpacing: _chipRunGap,
      children: <Widget>[
        for (final _TrackingFilter filter in _TrackingFilter.values)
          ChoiceChip(
            label: Text('${filter.label} ${counts[filter] ?? 0}'),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            mouseCursor: SystemMouseCursors.click,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected == filter ? theme.background : theme.onSurface,
              fontWeight:
                  selected == filter ? FontWeight.bold : FontWeight.w600,
            ),
            backgroundColor: theme.background.withValues(alpha: 0.42),
            selectedColor: theme.primary,
            side: BorderSide(
              color: selected == filter
                  ? theme.primary
                  : theme.border.withValues(alpha: 0.9),
            ),
          ),
      ],
    );
  }
}

class _TrackingMetricTile extends StatelessWidget {
  const _TrackingMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String value;
  final IconData icon;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(_ElainaAppShellState._panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingEmptyState extends StatelessWidget {
  const _TrackingEmptyState({
    required this.filter,
    required this.hasAnyTrackedItem,
    required this.theme,
    required this.onOpenLibrary,
    required this.onLogin,
  });

  final _TrackingFilter filter;
  final bool hasAnyTrackedItem;
  final ElainaThemeData theme;
  final VoidCallback onOpenLibrary;
  final VoidCallback onLogin;

  String get _title {
    if (!hasAnyTrackedItem) {
      return '还没有 Bangumi 追番条目';
    }
    return switch (filter) {
      _TrackingFilter.all => '还没有 Bangumi 追番条目',
      _TrackingFilter.watching => '当前没有在追条目',
      _TrackingFilter.planned => '当前没有想看条目',
      _TrackingFilter.completed => '当前没有已看条目',
      _TrackingFilter.onHold => '当前没有搁置条目',
      _TrackingFilter.dropped => '当前没有抛弃条目',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.bookmark_add_outlined,
                      color: theme.primary.withValues(alpha: 0.7),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed: onOpenLibrary,
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('打开本地媒体库'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: theme.background,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onLogin,
                          icon: const Icon(Icons.login),
                          label: const Text('登录 Bangumi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primary,
                            side: BorderSide(color: theme.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackingItemCard extends StatelessWidget {
  const _TrackingItemCard({
    required this.item,
    required this.theme,
    required this.onOpenDetail,
  });

  final _TrackedBangumiItem item;
  final ElainaThemeData theme;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.background.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.movie_filter_outlined,
                        color: theme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bangumi ID: ${item.subjectId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.onBackground.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.progressLabel,
                  style: TextStyle(
                    color: theme.onBackground.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 6,
                    backgroundColor: theme.border.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle({
    required this.profileFuture,
    required this.theme,
  });

  final Future<UserProfileSnapshot?>? profileFuture;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Future<UserProfileSnapshot?>? future = profileFuture;
    if (future == null) {
      return _buildText('欢迎回来');
    }
    return FutureBuilder<UserProfileSnapshot?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<UserProfileSnapshot?> snapshot) {
        final String? displayName = snapshot.data?.displayName?.trim();
        if (displayName == null || displayName.isEmpty) {
          return _buildText('欢迎回来');
        }
        return _buildText('欢迎回来，$displayName');
      },
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _BangumiProfileAvatar extends StatefulWidget {
  const _BangumiProfileAvatar({
    required this.profileFuture,
    required this.theme,
    required this.refreshRevision,
  });

  final Future<UserProfileSnapshot?>? profileFuture;
  final ElainaThemeData theme;
  final int refreshRevision;

  static const double _avatarDiameter = 40;

  @override
  State<_BangumiProfileAvatar> createState() => _BangumiProfileAvatarState();
}

class _BangumiProfileAvatarState extends State<_BangumiProfileAvatar> {
  @override
  Widget build(BuildContext context) {
    final Future<UserProfileSnapshot?>? future = widget.profileFuture;
    if (future == null) {
      return _buildFallbackAvatar(widget.theme);
    }
    return FutureBuilder<UserProfileSnapshot?>(
      key: ValueKey<int>(widget.refreshRevision),
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<UserProfileSnapshot?> snapshot) {
        final Uri? avatarUri = snapshot.data?.avatarUri;
        if (avatarUri == null) {
          return _buildFallbackAvatar(widget.theme);
        }
        return ClipOval(
          child: SizedBox.square(
            dimension: _BangumiProfileAvatar._avatarDiameter,
            child: Image.network(
              avatarUri.toString(),
              key: ValueKey<String>(avatarUri.toString()),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) =>
                  _buildFallbackAvatar(widget.theme),
              loadingBuilder: (BuildContext context, Widget child,
                  ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildFallbackAvatar(widget.theme);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(ElainaThemeData theme) {
    return CircleAvatar(
      radius: _BangumiProfileAvatar._avatarDiameter / 2,
      backgroundColor: theme.secondary.withValues(alpha: 0.3),
      child: Icon(Icons.person, color: theme.primary),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop({required this.theme});

  final ElainaThemeData theme;

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
  final ElainaThemeData theme;

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
