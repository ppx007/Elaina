abstract final class UiElementIds {
  static const String navHome = 'nav-home';
  static const String navTracking = 'nav-tracking';
  static const String navLocalLibrary = 'nav-local-library';
  static const String navDownloads = 'nav-downloads';
  static const String navRss = 'nav-rss';
  static const String navSettings = 'nav-settings';
  static const String navDiagnostics = 'nav-diagnostics';

  static const String pageHome = 'page-home';
  static const String pageTracking = 'page-tracking';
  static const String pageLocalLibrary = 'page-local-library';
  static const String pageDownloads = 'page-downloads';
  static const String pageRss = 'page-rss';
  static const String pageSettings = 'page-settings';
  static const String pageDiagnostics = 'page-diagnostics';

  static const String homeSearchEntry = 'home-search-entry';
  static const String homeSearchInput = 'home-search-input';
  static const String homeSearchClose = 'home-search-close';
  static const String homeSearchRetry = 'home-search-retry';
  static const String homeRecommendationWaterfall =
      'home-recommendation-waterfall';

  static const String videoDetailClose = 'video-detail-close';

  static const String settingsThemeMode = 'settings-theme-mode';
  static const String settingsSectionAppearance = 'settings-section-appearance';
  static const String settingsSectionBangumi = 'settings-section-bangumi';
  static const String settingsSectionNetwork = 'settings-section-network';
  static const String settingsSectionMediaLibrary =
      'settings-section-media-library';
  static const String settingsBangumiOAuthLogin =
      'settings-bangumi-oauth-login';
  static const String settingsBangumiAccessToken =
      'settings-bangumi-access-token';
  static const String settingsBangumiLogin = 'settings-bangumi-login';
  static const String settingsBangumiMirror = 'settings-bangumi-mirror';
  static const String settingsBangumiMirrorApiUrl =
      'settings-bangumi-mirror-api-url';
  static const String settingsBangumiMirrorImageUrl =
      'settings-bangumi-mirror-image-url';
  static const String settingsBangumiMirrorSave =
      'settings-bangumi-mirror-save';
  static const String settingsHttpProxy = 'settings-http-proxy';
  static const String settingsSaveProxy = 'settings-save-proxy';
  static const String settingsDnsPolicy = 'settings-dns-policy';
  static const String settingsSaveDns = 'settings-save-dns';
  static const String settingsAddMediaFolder = 'settings-add-media-folder';

  static const String downloadDetailScroll = 'download-detail-scroll';
  static const String rssItemSearch = 'rss-item-search';
  static const String rssSelectVisibleDownloadable =
      'rss-select-visible-downloadable';
  static const String rssClearSelection = 'rss-clear-selection';
  static const String rssDownloadSelected = 'rss-download-selected';
  static const String heroCarouselCachePin = 'hero-carousel-cache-pin';

  static const String playbackPage = 'playback-page';
  static const String playbackPlayPause = 'playback-play-pause';
  static const String playbackSeekBar = 'playback-seek-bar';
  static const String playbackStop = 'playback-stop';
  static const String playbackInspector = 'playback-inspector';
  static const String playbackTrackPanel = 'playback-track-panel';
  static const String playbackSubtitleOverlay = 'playback-subtitle-overlay';
  static const String playbackDanmakuOverlay = 'playback-danmaku-overlay';

  static String playbackTrack(String trackId) {
    return 'playback-track-$trackId';
  }

  static String homeSearchResult(String subjectId) {
    return 'home-search-result-$subjectId';
  }

  static String homeRecentWatchingDetail(String subjectId) {
    return 'home-recent-watching-detail-$subjectId';
  }

  static String trackingItem(String subjectId) {
    return 'tracking-item-$subjectId';
  }

  static String heroCarouselItem(String subjectId) {
    return 'hero-carousel-item-$subjectId';
  }

  static String settingsEditMediaFolder(Uri folder) {
    return 'settings-edit-media-folder-${folder.toString()}';
  }

  static String settingsRemoveMediaFolder(Uri folder) {
    return 'settings-remove-media-folder-${folder.toString()}';
  }

  static String rssItemSelect(String itemId) {
    return 'rss-item-select-$itemId';
  }

  static String rssItemDownload(String itemId) {
    return 'rss-item-download-$itemId';
  }
}
