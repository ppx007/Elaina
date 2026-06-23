import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/detail/video_detail.dart';
import '../../../domain/diagnostics/diagnostics_domain.dart';
import '../../../domain/download/download_domain.dart';
import '../../../domain/home/home_recommendation_domain.dart';
import '../../../domain/home/home_search_domain.dart';
import '../../../domain/media/media_library.dart';
import '../../../domain/media/media_library_runtime.dart';
import '../../../domain/playback/playback_controller.dart';
import '../../../domain/playback/playback_state.dart';
import '../../../domain/profile/bangumi_login_domain.dart';
import '../../../domain/profile/bangumi_tracking_domain.dart';
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
import '../../testing/ui_element_ids.dart';
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
    this.bangumiTrackingProvider,
    this.bangumiLoginController,
    this.homeRecommendationProvider,
    this.homeSearchProvider,
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
  final BangumiTrackingProvider? bangumiTrackingProvider;
  final BangumiLoginController? bangumiLoginController;
  final HomeRecommendationProvider? homeRecommendationProvider;
  final HomeSearchProvider? homeSearchProvider;
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
  static const int _homeHeroRecommendationLimit = 7;
  static const int _homeMoreRecommendationPageSize = 20;
  static const double _homeMoreRecommendationLoadAheadExtent = 640;
  static const double _recommendationPosterAspectRatio = 9 / 16;
  static const double _recommendationThreeColumnWidth = 900;
  static const double _recommendationTwoColumnWidth = 560;
  static const double _recommendationWaterfallGap = 24;
  static const double _recentWatchingPanelHeight = 400;
  static const double _homeSearchEntryMaxWidth = 420;
  static const double _homeSearchEntryHeight = 44;
  static const double _searchOverlayMaxWidth = 760;
  static const double _searchOverlayPanelPadding = 24;
  static const double _searchResultCoverWidth = 64;
  static const double _searchResultCoverHeight = 90;
  static const String _brandLogoAsset =
      'assets/brand/elaina_iconic_character_logo.png';

  int _currentIndex = _homeNavIndex;
  bool _playbackOverlayActive = false;
  VideoDetailId? _activeDetailId;
  int _bangumiAuthRevision = 0;
  int _homeRecommendationRevision = 0;
  late MediaLibraryRuntimeSnapshot _librarySnapshot;
  late final ScrollController _homeScrollController;
  Future<UserProfileSnapshot?>? _profileFuture;
  Future<BangumiTrackingSnapshot>? _trackingFuture;
  Future<HomeRecommendationSnapshot>? _homeRecommendationFuture;
  late final TextEditingController _homeSearchController;
  late final FocusNode _homeSearchFocusNode;
  Timer? _homeSearchDebounceTimer;
  final List<HomeRecommendationItem> _moreRecommendationItems =
      <HomeRecommendationItem>[];
  final Set<String> _moreRecommendationSubjectIds = <String>{};
  Set<String> _homeHeroSubjectIds = <String>{};
  int _moreRecommendationOffset = 0;
  bool _moreRecommendationIsLoading = false;
  bool _moreRecommendationHasMore = true;
  String? _moreRecommendationMessage;
  bool _homeSearchOverlayActive = false;
  bool _homeSearchIsLoading = false;
  int _homeSearchRevision = 0;
  String _homeSearchQuery = '';
  HomeSearchSnapshot? _homeSearchSnapshot;
  _TrackingFilter _trackingFilter = _TrackingFilter.all;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileProvider?.currentProfile();
    _trackingFuture = widget.bangumiTrackingProvider?.currentAnimeCollection();
    _homeScrollController = ScrollController();
    _homeScrollController.addListener(_onHomeScroll);
    _homeSearchController = TextEditingController();
    _homeSearchFocusNode = FocusNode();
    _reloadHomeRecommendations();
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
    if (oldWidget.bangumiTrackingProvider != widget.bangumiTrackingProvider) {
      _trackingFuture =
          widget.bangumiTrackingProvider?.currentAnimeCollection();
    }
    if (oldWidget.homeRecommendationProvider !=
        widget.homeRecommendationProvider) {
      _reloadHomeRecommendations();
    }
  }

  @override
  void dispose() {
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    _homeSearchDebounceTimer?.cancel();
    _homeSearchController.dispose();
    _homeSearchFocusNode.dispose();
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
      _trackingFuture =
          widget.bangumiTrackingProvider?.currentAnimeCollection();
    });
  }

  void _refreshBangumiTracking() {
    setState(() {
      _trackingFuture =
          widget.bangumiTrackingProvider?.currentAnimeCollection();
    });
  }

  void _refreshLibrarySnapshot() {
    unawaited(widget.mediaLibraryRuntime.refresh());
  }

  void _reloadHomeRecommendations() {
    _homeRecommendationRevision += 1;
    final int revision = _homeRecommendationRevision;
    final Future<HomeRecommendationSnapshot>? heroFuture =
        widget.homeRecommendationProvider?.trendingAnime(
      limit: _homeHeroRecommendationLimit,
      offset: 0,
    );
    _homeRecommendationFuture = heroFuture;
    _homeHeroSubjectIds = <String>{};
    _moreRecommendationItems.clear();
    _moreRecommendationSubjectIds.clear();
    _moreRecommendationOffset = 0;
    _moreRecommendationIsLoading = false;
    _moreRecommendationHasMore = heroFuture != null;
    _moreRecommendationMessage = null;

    if (heroFuture == null) return;
    unawaited(
      heroFuture.then((HomeRecommendationSnapshot snapshot) {
        if (!mounted || revision != _homeRecommendationRevision) return;
        final Set<String> heroSubjectIds = _subjectIdsFromRecommendations(
          _loadedHomeRecommendationItems(snapshot)
              .take(_homeHeroRecommendationLimit),
        );
        setState(() {
          _homeHeroSubjectIds = heroSubjectIds;
        });
        unawaited(_loadMoreRecommendations());
      }).catchError((Object error) {
        if (!mounted || revision != _homeRecommendationRevision) return;
        unawaited(_loadMoreRecommendations());
      }),
    );
  }

  void _onHomeScroll() {
    if (_shouldLoadMoreHomeRecommendations()) {
      unawaited(_loadMoreRecommendations());
    }
  }

  bool _shouldLoadMoreHomeRecommendations() {
    return _homeScrollController.hasClients &&
        _homeScrollController.position.extentAfter <=
            _homeMoreRecommendationLoadAheadExtent;
  }

  Future<void> _loadMoreRecommendations() async {
    final HomeRecommendationProvider? provider =
        widget.homeRecommendationProvider;
    if (provider == null ||
        _moreRecommendationIsLoading ||
        !_moreRecommendationHasMore ||
        _moreRecommendationMessage != null) {
      return;
    }

    final int revision = _homeRecommendationRevision;
    final int offset = _moreRecommendationOffset;
    setState(() {
      _moreRecommendationIsLoading = true;
      _moreRecommendationMessage = null;
    });

    late final HomeRecommendationSnapshot snapshot;
    try {
      snapshot = await provider.recentPopularAnime(
        limit: _homeMoreRecommendationPageSize,
        offset: offset,
      );
    } catch (error) {
      if (!mounted || revision != _homeRecommendationRevision) return;
      setState(() {
        _moreRecommendationIsLoading = false;
        _moreRecommendationHasMore = true;
        _moreRecommendationMessage = 'Bangumi 推荐加载失败：$error';
      });
      return;
    }
    if (!mounted || revision != _homeRecommendationRevision) return;

    if (snapshot.status == HomeRecommendationLoadStatus.failed) {
      setState(() {
        _moreRecommendationIsLoading = false;
        _moreRecommendationHasMore = true;
        _moreRecommendationMessage = snapshot.message;
      });
      return;
    }

    final List<HomeRecommendationItem> incoming = snapshot.items;
    final List<HomeRecommendationItem> accepted =
        _newMoreRecommendationItems(incoming);
    setState(() {
      _moreRecommendationItems.addAll(accepted);
      for (final HomeRecommendationItem item in accepted) {
        _moreRecommendationSubjectIds.add(item.subjectId);
      }
      _moreRecommendationOffset += incoming.length;
      _moreRecommendationHasMore = incoming.isNotEmpty;
      _moreRecommendationIsLoading = false;
    });

    if (_moreRecommendationHasMore &&
        (accepted.isEmpty || _shouldLoadMoreHomeRecommendations())) {
      unawaited(_loadMoreRecommendations());
    }
  }

  void _retryMoreRecommendations() {
    setState(() {
      _moreRecommendationHasMore = true;
      _moreRecommendationMessage = null;
    });
    unawaited(_loadMoreRecommendations());
  }

  void _openBangumiSettings() {
    setState(() {
      _currentIndex = _settingsNavIndex;
    });
  }

  void _openDetail(String idValue) {
    setState(() {
      _activeDetailId = VideoDetailId(idValue);
    });
  }

  void _openHomeSearch() {
    setState(() {
      _homeSearchOverlayActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _homeSearchOverlayActive) {
        _homeSearchFocusNode.requestFocus();
      }
    });
  }

  void _closeHomeSearch() {
    _homeSearchDebounceTimer?.cancel();
    _homeSearchRevision += 1;
    _homeSearchFocusNode.unfocus();
    setState(() {
      _homeSearchOverlayActive = false;
      _homeSearchController.clear();
      _homeSearchQuery = '';
      _homeSearchSnapshot = null;
      _homeSearchIsLoading = false;
    });
  }

  void _onHomeSearchQueryChanged(String value) {
    _homeSearchDebounceTimer?.cancel();
    _homeSearchRevision += 1;
    final int revision = _homeSearchRevision;
    final String query = value.trim();
    setState(() {
      _homeSearchQuery = query;
      _homeSearchSnapshot = null;
      _homeSearchIsLoading = false;
    });
    if (query.length < homeSearchMinimumQueryLength) return;
    _homeSearchDebounceTimer = Timer(homeSearchDebounceDuration, () {
      unawaited(_runHomeSearch(query, revision));
    });
  }

  Future<void> _runHomeSearch(String query, int revision) async {
    if (!mounted ||
        revision != _homeSearchRevision ||
        !_homeSearchOverlayActive ||
        query != _homeSearchQuery) {
      return;
    }
    final HomeSearchProvider? provider = widget.homeSearchProvider;
    if (provider == null) {
      if (!mounted ||
          revision != _homeSearchRevision ||
          !_homeSearchOverlayActive) {
        return;
      }
      setState(() {
        _homeSearchSnapshot =
            const HomeSearchSnapshot.failed('Bangumi 搜索服务不可用。');
        _homeSearchIsLoading = false;
      });
      return;
    }

    setState(() {
      _homeSearchIsLoading = true;
      _homeSearchSnapshot = null;
    });
    late final HomeSearchSnapshot snapshot;
    try {
      snapshot = await provider.searchAnime(query);
    } catch (error) {
      snapshot = HomeSearchSnapshot.failed('Bangumi 搜索失败：$error');
    }
    if (!mounted ||
        revision != _homeSearchRevision ||
        !_homeSearchOverlayActive ||
        query != _homeSearchQuery) {
      return;
    }
    setState(() {
      _homeSearchSnapshot = snapshot;
      _homeSearchIsLoading = false;
    });
  }

  void _retryHomeSearch() {
    final String query = _homeSearchQuery;
    if (query.length < homeSearchMinimumQueryLength) return;
    _homeSearchDebounceTimer?.cancel();
    _homeSearchRevision += 1;
    unawaited(_runHomeSearch(query, _homeSearchRevision));
  }

  void _openFirstHomeSearchResult() {
    final List<HomeSearchItem> items =
        _homeSearchSnapshot?.items ?? const <HomeSearchItem>[];
    if (items.isEmpty) return;
    _openHomeSearchResult(items.first);
  }

  void _openHomeSearchResult(HomeSearchItem item) {
    _homeSearchDebounceTimer?.cancel();
    _homeSearchRevision += 1;
    setState(() {
      _homeSearchOverlayActive = false;
      _homeSearchController.clear();
      _homeSearchQuery = '';
      _homeSearchSnapshot = null;
      _homeSearchIsLoading = false;
      _activeDetailId = VideoDetailId(item.subjectId);
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
      BangumiLoginStartStatus.opened => '已打开 Bangumi OAuth 授权页面',
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

          // Playback Screen Overlay (grows on active playback status)
          if (_playbackOverlayActive)
            Positioned.fill(
              child: ProductionPlaybackPage(
                controller: widget.playbackController,
                videoSurface: widget.videoSurface,
              ),
            ),

          if (_homeSearchOverlayActive)
            Positioned.fill(
              child: _HomeSearchOverlay(
                controller: _homeSearchController,
                focusNode: _homeSearchFocusNode,
                theme: theme,
                query: _homeSearchQuery,
                isLoading: _homeSearchIsLoading,
                snapshot: _homeSearchSnapshot,
                onChanged: _onHomeSearchQueryChanged,
                onClose: _closeHomeSearch,
                onRetry: _retryHomeSearch,
                onSubmitFirst: _openFirstHomeSearchResult,
                onOpenItem: _openHomeSearchResult,
              ),
            ),

          // Video Detail Page Overlay (global top-level detail surface)
          if (_activeDetailId != null)
            Positioned.fill(
              child: VideoDetailPage(
                key: ValueKey<String>(_activeDetailId!.value),
                id: _activeDetailId!,
                videoDetailPageContract: widget.videoDetailPageContract,
                playbackController: widget.playbackController,
                onPlaybackStarted: () {
                  setState(() {
                    _activeDetailId = null;
                  });
                  _checkPlaybackState();
                },
                onClose: () {
                  setState(() {
                    _activeDetailId = null;
                  });
                },
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
          key: ValueKey<String>(_sidebarElementId(index)),
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

  String _sidebarElementId(int index) {
    return switch (index) {
      _homeNavIndex => UiElementIds.navHome,
      _trackingNavIndex => UiElementIds.navTracking,
      _localLibraryNavIndex => UiElementIds.navLocalLibrary,
      _downloadsNavIndex => UiElementIds.navDownloads,
      _rssNavIndex => UiElementIds.navRss,
      _settingsNavIndex => UiElementIds.navSettings,
      _diagnosticsNavIndex => UiElementIds.navDiagnostics,
      _ => throw ArgumentError.value(index, 'index', 'Unknown sidebar index.'),
    };
  }

  // 1. Beautiful Home Page
  Widget _buildHomePage(ElainaThemeData theme) {
    return Container(
      key: const ValueKey<String>(UiElementIds.pageHome),
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
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _homeSearchEntryMaxWidth,
                    ),
                    child: _HomeSearchEntry(
                      theme: theme,
                      height: _homeSearchEntryHeight,
                      onTap: _openHomeSearch,
                    ),
                  ),
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
              controller: _homeScrollController,
              children: <Widget>[
                _buildBangumiHomeRecommendations(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBangumiHomeRecommendations(ElainaThemeData theme) {
    return FutureBuilder<HomeRecommendationSnapshot>(
      future: _homeRecommendationFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<HomeRecommendationSnapshot> snapshot,
      ) {
        final List<HomeRecommendationItem> items =
            _loadedHomeRecommendationItems(snapshot.data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            HeroCarousel(
              autoScroll: widget.carouselAutoScroll,
              items: _heroItemsFromRecommendations(items),
              onOpenDetail: _openDetail,
            ),
            const SizedBox(height: 32),
            _buildRecentWatchingSection(theme),
            const SizedBox(height: 32),
            Text(
              '更多推荐',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecommendationsWaterfall(
              theme,
              _moreRecommendationItems,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentWatchingSection(ElainaThemeData theme) {
    return FutureBuilder<BangumiTrackingSnapshot>(
      future: _trackingFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<BangumiTrackingSnapshot> snapshot,
      ) {
        final BangumiTrackingSnapshot? trackingSnapshot = snapshot.data;
        final bool isRefreshing =
            snapshot.connectionState == ConnectionState.waiting;
        final List<_TrackedBangumiItem> recentItems =
            _recentWatchingItems(trackingSnapshot);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.history, color: theme.accentMagenta, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '最近观看',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: isRefreshing ? null : _refreshBangumiTracking,
                  child: Text(
                    '刷新',
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
            _buildRecentWatchingContent(
              theme,
              trackingSnapshot,
              recentItems,
              isRefreshing: isRefreshing,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentWatchingContent(
    ElainaThemeData theme,
    BangumiTrackingSnapshot? trackingSnapshot,
    List<_TrackedBangumiItem> recentItems, {
    required bool isRefreshing,
  }) {
    if (isRefreshing && trackingSnapshot == null) {
      return _buildRecentWatchingPanel(
        theme,
        child: CircularProgressIndicator(color: theme.primary),
      );
    }
    if (_recentWatchingNeedsLogin(trackingSnapshot)) {
      return _buildRecentWatchingPanel(
        theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.login, color: theme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              '请登录',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _startBangumiLogin,
              icon: const Icon(Icons.open_in_new),
              label: const Text('登录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.background,
              ),
            ),
          ],
        ),
      );
    }
    if (trackingSnapshot?.status == BangumiTrackingLoadStatus.failed) {
      return _buildRecentWatchingPanel(
        theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.sync_problem, color: theme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              trackingSnapshot?.message ?? '最近观看同步失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (recentItems.isEmpty) {
      return _buildRecentWatchingPanel(
        theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_toggle_off, color: theme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              '暂无最近观看',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return HotUpdatesCarousel(
      autoScroll: widget.carouselAutoScroll,
      items: _hotUpdateItemsFromRecentWatching(recentItems),
      useFallbackItems: false,
      onOpenDetail: _openDetail,
    );
  }

  Widget _buildRecentWatchingPanel(
    ElainaThemeData theme, {
    required Widget child,
  }) {
    return SizedBox(
      height: _recentWatchingPanelHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(child: child),
      ),
    );
  }

  bool _recentWatchingNeedsLogin(BangumiTrackingSnapshot? snapshot) {
    return _trackingFuture == null ||
        snapshot?.status == BangumiTrackingLoadStatus.unauthenticated;
  }

  List<_TrackedBangumiItem> _recentWatchingItems(
    BangumiTrackingSnapshot? snapshot,
  ) {
    if (snapshot?.status != BangumiTrackingLoadStatus.loaded) {
      return const <_TrackedBangumiItem>[];
    }
    return <_TrackedBangumiItem>[
      for (final _TrackedBangumiItem item
          in _remoteTrackedBangumiItems(snapshot!.items))
        if (_isRecentWatchingCandidate(item)) item,
    ];
  }

  bool _isRecentWatchingCandidate(_TrackedBangumiItem item) {
    return item.hasProgress ||
        item.watchedEpisodes > 0 ||
        item.status == BangumiTrackingStatus.watching ||
        item.status == BangumiTrackingStatus.completed;
  }

  List<HomeRecommendationItem> _loadedHomeRecommendationItems(
    HomeRecommendationSnapshot? snapshot,
  ) {
    if (snapshot?.status != HomeRecommendationLoadStatus.loaded) {
      return const <HomeRecommendationItem>[];
    }
    return snapshot!.items;
  }

  Set<String> _subjectIdsFromRecommendations(
    Iterable<HomeRecommendationItem> items,
  ) {
    return <String>{
      for (final HomeRecommendationItem item in items) item.subjectId,
    };
  }

  List<HomeRecommendationItem> _newMoreRecommendationItems(
    Iterable<HomeRecommendationItem> items,
  ) {
    final Set<String> blockedSubjectIds = <String>{
      ..._homeHeroSubjectIds,
      ..._moreRecommendationSubjectIds,
    };
    return <HomeRecommendationItem>[
      for (final HomeRecommendationItem item in items)
        if (!blockedSubjectIds.contains(item.subjectId)) item,
    ];
  }

  List<HeroCarouselItem> _heroItemsFromRecommendations(
    List<HomeRecommendationItem> items,
  ) {
    return <HeroCarouselItem>[
      for (final HomeRecommendationItem item
          in items.take(_homeHeroRecommendationLimit))
        HeroCarouselItem(
          subjectId: item.subjectId,
          title: item.title,
          symbol: _symbolForTitle(item.title),
          coverUri: item.coverUri,
          popularitySentence: item.popularitySentence,
        ),
    ];
  }

  List<HotUpdateItem> _hotUpdateItemsFromRecentWatching(
    List<_TrackedBangumiItem> items,
  ) {
    return <HotUpdateItem>[
      for (final _TrackedBangumiItem item in items)
        HotUpdateItem(
          subjectId: item.subjectId,
          title: item.title,
          tag: item.statusLabel,
          description: _recentWatchingDescription(item),
          symbol: _symbolForTitle(item.title),
          coverUri: item.coverUri,
        ),
    ];
  }

  String _recentWatchingDescription(_TrackedBangumiItem item) {
    final DateTime? updatedAt = item.updatedAt;
    if (updatedAt == null) return '进度 ${item.progressLabel}';
    return '进度 ${item.progressLabel}，更新于 ${_formatShortDate(updatedAt)}';
  }

  String _formatShortDate(DateTime value) {
    final DateTime localValue = value.toLocal();
    final String month = localValue.month.toString().padLeft(2, '0');
    final String day = localValue.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  String _symbolForTitle(String title) {
    final String normalized = title.trim();
    if (normalized.isEmpty) return 'BG';
    final Iterable<String> codeUnits = normalized.runes
        .take(2)
        .map((int rune) => String.fromCharCode(rune).toUpperCase());
    return codeUnits.join();
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

  Widget _buildRecommendationsWaterfall(
    ElainaThemeData theme,
    List<HomeRecommendationItem> items,
  ) {
    final List<_RecommendationCardModel> cards =
        _recommendationCardsFromItems(items);
    if (cards.isEmpty) {
      return _buildMoreRecommendationStatus(theme);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columnCount =
            _recommendationColumnCount(constraints.maxWidth);
        final List<List<int>> columns =
            _recommendationWaterfallColumns(cards.length, columnCount);
        return KeyedSubtree(
          key: const ValueKey<String>(UiElementIds.homeRecommendationWaterfall),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int columnIndex = 0;
                      columnIndex < columns.length;
                      columnIndex += 1) ...<Widget>[
                    if (columnIndex > 0)
                      const SizedBox(width: _recommendationWaterfallGap),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          for (final int cardIndex in columns[columnIndex])
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: cardIndex == columns[columnIndex].last
                                    ? 0
                                    : _recommendationWaterfallGap,
                              ),
                              child: _buildRecommendationWaterfallCard(
                                cards[cardIndex],
                                cardIndex,
                                theme,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              _buildMoreRecommendationFooter(theme),
            ],
          ),
        );
      },
    );
  }

  List<_RecommendationCardModel> _recommendationCardsFromItems(
    List<HomeRecommendationItem> items,
  ) {
    return <_RecommendationCardModel>[
      for (final HomeRecommendationItem item in items)
        _RecommendationCardModel(
          title: item.title,
          subtitle: _episodeLabel(item.episodeCount),
          rating: item.popularitySentence,
          symbol: _symbolForTitle(item.title),
          coverUri: item.coverUri,
          subjectId: item.subjectId,
        ),
    ];
  }

  Widget _buildMoreRecommendationStatus(ElainaThemeData theme) {
    final String? message = _moreRecommendationMessage;
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.homeRecommendationWaterfall),
      child: SizedBox(
        height: 180,
        child: Center(
          child: message != null
              ? _buildMoreRecommendationRetry(theme, message)
              : _moreRecommendationIsLoading
                  ? CircularProgressIndicator(color: theme.primary)
                  : Text(
                      '暂无推荐',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.62),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildMoreRecommendationFooter(ElainaThemeData theme) {
    final String? message = _moreRecommendationMessage;
    if (message != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _buildMoreRecommendationRetry(theme, message),
      );
    }
    if (!_moreRecommendationIsLoading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            color: theme.primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreRecommendationRetry(
    ElainaThemeData theme,
    String message,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.68),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed:
              _moreRecommendationIsLoading ? null : _retryMoreRecommendations,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.primary,
            side: BorderSide(color: theme.primary),
          ),
        ),
      ],
    );
  }

  List<List<int>> _recommendationWaterfallColumns(
    int cardCount,
    int columnCount,
  ) {
    final List<List<int>> columns = <List<int>>[
      for (int index = 0; index < columnCount; index += 1) <int>[],
    ];
    for (int cardIndex = 0; cardIndex < cardCount; cardIndex += 1) {
      columns[cardIndex % columnCount].add(cardIndex);
    }
    return columns;
  }

  Widget _buildRecommendationWaterfallCard(
    _RecommendationCardModel card,
    int index,
    ElainaThemeData theme,
  ) {
    return _buildRecCard(
      title: card.title,
      subtitle: card.subtitle,
      rating: card.rating,
      symbol: card.symbol,
      coverUri: card.coverUri,
      accentIndex: index,
      theme: theme,
      subjectId: card.subjectId,
    );
  }

  int _recommendationColumnCount(double width) {
    if (width >= _recommendationThreeColumnWidth) return 3;
    if (width >= _recommendationTwoColumnWidth) return 2;
    return 1;
  }

  String _episodeLabel(int? episodeCount) {
    if (episodeCount == null || episodeCount == 0) return '动画条目';
    return '$episodeCount 话';
  }

  Widget _buildRecCard(
      {required String title,
      required String subtitle,
      required String rating,
      required String symbol,
      required Uri? coverUri,
      required int accentIndex,
      required ElainaThemeData theme,
      String? subjectId}) {
    final bool canOpenDetail = subjectId != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor:
            canOpenDetail ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onTap: canOpenDetail ? () => _openDetail(subjectId) : null,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), width: 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: _recommendationPosterAspectRatio,
                child: _RecommendationBackdrop(
                  symbol: symbol,
                  accentIndex: accentIndex,
                  theme: theme,
                  coverUri: coverUri,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Bangumi tracking page
  Widget _buildTrackingPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageTracking),
      child: FutureBuilder<BangumiTrackingSnapshot>(
        future: _trackingFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<BangumiTrackingSnapshot> snapshot,
        ) {
          return _buildTrackingPageContent(
            theme,
            snapshot.data,
            isRefreshing: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      ),
    );
  }

  Widget _buildTrackingPageContent(
    ElainaThemeData theme,
    BangumiTrackingSnapshot? remoteSnapshot, {
    required bool isRefreshing,
  }) {
    final List<_TrackedBangumiItem> trackedItems =
        _trackedBangumiItems(remoteSnapshot);
    final List<_TrackedBangumiItem> visibleItems =
        _trackedBangumiItemsFor(_trackingFilter, trackedItems);
    final int continuingCount = trackedItems
        .where((_TrackedBangumiItem item) =>
            item.status == BangumiTrackingStatus.watching ||
            item.status == BangumiTrackingStatus.onHold)
        .length;
    final int completedCount = trackedItems
        .where((_TrackedBangumiItem item) =>
            item.status == BangumiTrackingStatus.completed)
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Tooltip(
                    message: '刷新',
                    child: IconButton(
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: isRefreshing ? null : _refreshBangumiTracking,
                      icon: const Icon(Icons.refresh),
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BangumiAccountPill(
                    profileFuture: _profileFuture,
                    theme: theme,
                    onPressed: _startBangumiLogin,
                  ),
                ],
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
                      child: isRefreshing && trackedItems.isEmpty
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.primary,
                              ),
                            )
                          : visibleItems.isEmpty
                              ? _TrackingEmptyState(
                                  filter: _trackingFilter,
                                  hasAnyTrackedItem: trackedItems.isNotEmpty,
                                  remoteSnapshot: remoteSnapshot,
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
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final _TrackedBangumiItem item =
                                        visibleItems[index];
                                    return _TrackingItemCard(
                                      item: item,
                                      theme: theme,
                                      onOpenDetail: () =>
                                          _openDetail(item.subjectId),
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

  List<_TrackedBangumiItem> _trackedBangumiItems(
    BangumiTrackingSnapshot? remoteSnapshot,
  ) {
    if (remoteSnapshot?.status == BangumiTrackingLoadStatus.loaded) {
      return _remoteTrackedBangumiItems(remoteSnapshot!.items);
    }
    return _localTrackedBangumiItems();
  }

  List<_TrackedBangumiItem> _remoteTrackedBangumiItems(
    Iterable<BangumiTrackingItem> remoteItems,
  ) {
    final Map<String, _LocalTrackingProgress> localProgress =
        _localTrackingProgressBySubjectId();
    final List<_TrackedBangumiItem> items = <_TrackedBangumiItem>[
      for (final BangumiTrackingItem item in remoteItems)
        _TrackedBangumiItem(
          subjectId: item.subjectId,
          title: item.title,
          status: item.status,
          progress: _progressForRemoteItem(item, localProgress[item.subjectId]),
          watchedEpisodes: item.watchedEpisodes,
          totalEpisodes: item.totalEpisodes,
          coverUri: item.coverUri,
          updatedAt: item.updatedAt ?? localProgress[item.subjectId]?.updatedAt,
        ),
    ];
    items.sort(_compareTrackedBangumiItems);
    return items;
  }

  List<_TrackedBangumiItem> _localTrackedBangumiItems() {
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
          status: _statusForLocalProgress(
            itemState.continueWatching?.progress ?? 0,
          ),
          progress: itemState.continueWatching?.progress ?? 0,
          watchedEpisodes: 0,
          totalEpisodes: 0,
          updatedAt: itemState.continueWatching?.updatedAt,
        ),
      );
    }
    items.sort(_compareTrackedBangumiItems);
    return items;
  }

  Map<String, _LocalTrackingProgress> _localTrackingProgressBySubjectId() {
    return <String, _LocalTrackingProgress>{
      for (final MediaLibraryCatalogItemState itemState
          in _librarySnapshot.catalogItems)
        if (_confirmedBangumiSubjectId(itemState) != null)
          _confirmedBangumiSubjectId(itemState)!: _LocalTrackingProgress(
            progress: itemState.continueWatching?.progress ?? 0,
            updatedAt: itemState.continueWatching?.updatedAt,
          ),
    };
  }

  String? _confirmedBangumiSubjectId(MediaLibraryCatalogItemState itemState) {
    final ProviderBinding? binding = itemState.binding;
    final String? subjectId = binding?.subjectId?.value;
    if (binding == null ||
        subjectId == null ||
        binding.providerId != defaultVideoDetailMetadataProviderId ||
        binding.authority != ProviderBindingAuthority.userConfirmed) {
      return null;
    }
    return subjectId;
  }

  double _progressForRemoteItem(
    BangumiTrackingItem item,
    _LocalTrackingProgress? localProgress,
  ) {
    if (item.status == BangumiTrackingStatus.completed) return 1;
    if (item.totalEpisodes > 0) {
      return (item.watchedEpisodes / item.totalEpisodes).clamp(0, 1).toDouble();
    }
    return localProgress?.progress ?? 0;
  }

  BangumiTrackingStatus _statusForLocalProgress(double progress) {
    if (progress >= _completedProgressThreshold) {
      return BangumiTrackingStatus.completed;
    }
    if (progress > 0) return BangumiTrackingStatus.watching;
    return BangumiTrackingStatus.planned;
  }

  int _compareTrackedBangumiItems(
    _TrackedBangumiItem left,
    _TrackedBangumiItem right,
  ) {
    final DateTime? leftUpdated = left.updatedAt;
    final DateTime? rightUpdated = right.updatedAt;
    if (leftUpdated == null && rightUpdated == null) {
      return left.title.compareTo(right.title);
    }
    if (leftUpdated == null) return 1;
    if (rightUpdated == null) return -1;
    return rightUpdated.compareTo(leftUpdated);
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
      _TrackingFilter.watching => item.status == BangumiTrackingStatus.watching,
      _TrackingFilter.planned => item.status == BangumiTrackingStatus.planned,
      _TrackingFilter.completed =>
        item.status == BangumiTrackingStatus.completed,
      _TrackingFilter.onHold => item.status == BangumiTrackingStatus.onHold,
      _TrackingFilter.dropped => item.status == BangumiTrackingStatus.dropped,
    };
  }

  // 3. Library Page
  Widget _buildLibraryPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageLocalLibrary),
      child: MediaLibraryPage(
        mediaLibraryRuntime: widget.mediaLibraryRuntime,
        playbackController: widget.playbackController,
        settingsRuntime: widget.settingsRuntime,
        onNavigateToDetail: _openDetail,
      ),
    );
  }

  // 4. Downloads Page
  Widget _buildDownloadsPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageDownloads),
      child: DownloadsPage(
        downloadRuntime: widget.downloadRuntime,
      ),
    );
  }

  // 5. RSS Page
  Widget _buildRssPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageRss),
      child: RssPage(
        rssEngineRuntime: widget.rssEngineRuntime,
      ),
    );
  }

  // 6. Settings Page
  Widget _buildSettingsPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageSettings),
      child: SettingsPage(
        settingsRuntime: widget.settingsRuntime,
        bangumiLoginController: widget.bangumiLoginController,
        onBangumiAuthChanged: _refreshBangumiProfile,
      ),
    );
  }

  // 7. Diagnostics Page
  Widget _buildDiagnosticsPage(ElainaThemeData theme) {
    return KeyedSubtree(
      key: const ValueKey<String>(UiElementIds.pageDiagnostics),
      child: DiagnosticsPage(
        diagnosticsRuntime: widget.diagnosticsRuntime,
      ),
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
    required this.status,
    required this.progress,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    this.coverUri,
    this.updatedAt,
  });

  final String subjectId;
  final String title;
  final BangumiTrackingStatus status;
  final double progress;
  final int watchedEpisodes;
  final int totalEpisodes;
  final Uri? coverUri;
  final DateTime? updatedAt;

  bool get hasProgress => progress > 0;

  String get progressLabel {
    if (totalEpisodes > 0) return '$watchedEpisodes / $totalEpisodes';
    if (!hasProgress) return statusLabel;
    final int percent = (progress * 100).round().clamp(1, 100);
    return '已观看 $percent%';
  }

  String get statusLabel {
    return switch (status) {
      BangumiTrackingStatus.planned => '想看',
      BangumiTrackingStatus.completed => '已看',
      BangumiTrackingStatus.watching => '在追',
      BangumiTrackingStatus.onHold => '搁置',
      BangumiTrackingStatus.dropped => '抛弃',
    };
  }
}

final class _LocalTrackingProgress {
  const _LocalTrackingProgress({
    required this.progress,
    this.updatedAt,
  });

  final double progress;
  final DateTime? updatedAt;
}

final class _RecommendationCardModel {
  const _RecommendationCardModel({
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.symbol,
    this.coverUri,
    this.subjectId,
  });

  final String title;
  final String subtitle;
  final String rating;
  final String symbol;
  final Uri? coverUri;
  final String? subjectId;
}

class _HomeSearchEntry extends StatelessWidget {
  const _HomeSearchEntry({
    required this.theme,
    required this.height,
    required this.onTap,
  });

  static const double _radius = 12;

  final ElainaThemeData theme;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey<String>(UiElementIds.homeSearchEntry),
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: theme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Icon(Icons.search, color: theme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '搜索 Bangumi 动画',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onSurface.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_return,
                  color: theme.onSurface.withValues(alpha: 0.38),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSearchOverlay extends StatelessWidget {
  const _HomeSearchOverlay({
    required this.controller,
    required this.focusNode,
    required this.theme,
    required this.query,
    required this.isLoading,
    required this.snapshot,
    required this.onChanged,
    required this.onClose,
    required this.onRetry,
    required this.onSubmitFirst,
    required this.onOpenItem,
  });

  static const double _inputHeight = 56;
  static const double _resultTileRadius = 12;
  static const double _resultTilePadding = 12;
  static const double _bodyTopGap = 18;
  static const double _stateIconSize = 32;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ElainaThemeData theme;
  final String query;
  final bool isLoading;
  final HomeSearchSnapshot? snapshot;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback onSubmitFirst;
  final ValueChanged<HomeSearchItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (DismissIntent intent) {
              onClose();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              onSubmitFirst();
              return null;
            },
          ),
        },
        child: Material(
          color: theme.background.withValues(alpha: 0.96),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _ElainaAppShellState._searchOverlayMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(
                    _ElainaAppShellState._searchOverlayPanelPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildSearchInput(),
                      const SizedBox(height: _bodyTopGap),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: _inputHeight,
            child: TextField(
              key: const ValueKey<String>(UiElementIds.homeSearchInput),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitFirst(),
              textInputAction: TextInputAction.search,
              cursorColor: theme.primary,
              style: TextStyle(color: theme.onSurface, fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.surface,
                prefixIcon: Icon(Icons.search, color: theme.primary),
                hintText: '搜索 Bangumi 动画',
                hintStyle: TextStyle(
                  color: theme.onSurface.withValues(alpha: 0.46),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_resultTileRadius),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_resultTileRadius),
                  borderSide: BorderSide(color: theme.primary, width: 1.4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          key: const ValueKey<String>(UiElementIds.homeSearchClose),
          mouseCursor: SystemMouseCursors.click,
          tooltip: '关闭搜索',
          onPressed: onClose,
          icon: Icon(Icons.close, color: theme.onSurface),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (query.length < homeSearchMinimumQueryLength) {
      return _buildState(
        icon: Icons.manage_search,
        label: '输入至少 $homeSearchMinimumQueryLength 个字符',
      );
    }
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: _stateIconSize,
              height: _stateIconSize,
              child: CircularProgressIndicator(
                color: theme.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '搜索中',
              style: TextStyle(
                color: theme.onSurface.withValues(alpha: 0.74),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final HomeSearchSnapshot? value = snapshot;
    if (value == null) {
      return _buildState(icon: Icons.hourglass_empty, label: '准备搜索');
    }
    if (value.status == HomeSearchLoadStatus.failed) {
      return _buildFailure(value.message ?? 'Bangumi 搜索失败。');
    }
    if (value.items.isEmpty) {
      return _buildState(icon: Icons.search_off, label: '没有找到结果');
    }
    return ListView.separated(
      itemCount: value.items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final HomeSearchItem item = value.items[index];
        return _HomeSearchResultTile(
          item: item,
          theme: theme,
          onTap: () => onOpenItem(item),
        );
      },
    );
  }

  Widget _buildFailure(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, color: theme.accentMagenta, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.onSurface),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey<String>(UiElementIds.homeSearchRetry),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildState({
    required IconData icon,
    required String label,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: theme.primary.withValues(alpha: 0.82),
            size: _stateIconSize,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: theme.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchResultTile extends StatelessWidget {
  const _HomeSearchResultTile({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final HomeSearchItem item;
  final ElainaThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>(UiElementIds.homeSearchResult(item.subjectId)),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(_HomeSearchOverlay._resultTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius:
                BorderRadius.circular(_HomeSearchOverlay._resultTileRadius),
            border: Border.all(color: theme.border),
          ),
          padding: const EdgeInsets.all(_HomeSearchOverlay._resultTilePadding),
          child: Row(
            children: <Widget>[
              _buildCover(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.metadataSentence.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        item.metadataSentence,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (item.summary != null &&
                        item.summary!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.onSurface.withValues(alpha: 0.62),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, color: theme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    final Uri? coverUri = item.coverUri;
    return Container(
      width: _ElainaAppShellState._searchResultCoverWidth,
      height: _ElainaAppShellState._searchResultCoverHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: coverUri == null
          ? _buildCoverFallback()
          : Image.network(
              coverUri.toString(),
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                return _buildCoverFallback();
              },
            ),
    );
  }

  Widget _buildCoverFallback() {
    return Icon(Icons.movie_creation_outlined, color: theme.primary);
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
    required this.remoteSnapshot,
    required this.theme,
    required this.onOpenLibrary,
    required this.onLogin,
  });

  final _TrackingFilter filter;
  final bool hasAnyTrackedItem;
  final BangumiTrackingSnapshot? remoteSnapshot;
  final ElainaThemeData theme;
  final VoidCallback onOpenLibrary;
  final VoidCallback onLogin;

  String get _title {
    final BangumiTrackingSnapshot? snapshot = remoteSnapshot;
    if (snapshot?.status == BangumiTrackingLoadStatus.unauthenticated) {
      return '登录后同步 Bangumi 追番';
    }
    if (snapshot?.status == BangumiTrackingLoadStatus.failed) {
      return snapshot?.message ?? 'Bangumi 追番刷新失败';
    }
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
        key: ValueKey<String>(UiElementIds.trackingItem(item.subjectId)),
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
                    RepaintBoundary(
                      child: Container(
                        width: 42,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: item.coverUri == null
                            ? Icon(
                                Icons.movie_filter_outlined,
                                color: theme.primary,
                                size: 22,
                              )
                            : Image.network(
                                item.coverUri.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) {
                                  return Icon(
                                    Icons.movie_filter_outlined,
                                    color: theme.primary,
                                    size: 22,
                                  );
                                },
                              ),
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
        return RepaintBoundary(
          child: ClipOval(
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
    this.coverUri,
  });

  final String symbol;
  final int accentIndex;
  final ElainaThemeData theme;
  final Uri? coverUri;

  @override
  Widget build(BuildContext context) {
    final List<List<Color>> palettes = <List<Color>>[
      <Color>[theme.primary, theme.accentMagenta],
      <Color>[theme.secondary, const Color(0xFF4F46E5)],
      <Color>[const Color(0xFFFF5A6A), const Color(0xFF2D1B69)],
    ];
    final List<Color> colors = palettes[accentIndex % palettes.length];

    final Uri? imageUri = coverUri;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageUri == null)
            _buildFallbackPoster()
          else
            RepaintBoundary(
              child: Image.network(
                imageUri.toString(),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return _buildFallbackPoster();
                },
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) return child;
                  return _buildFallbackPoster();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Stack(
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
        Center(
          child: Icon(
            Icons.movie_filter_outlined,
            color: Colors.white.withValues(alpha: 0.32),
            size: 42,
          ),
        ),
      ],
    );
  }
}
