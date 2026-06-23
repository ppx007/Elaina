import 'package:elaina/src/ui/testing/ui_element_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class ElainaFinders {
  static Finder byId(String id) => find.byKey(ValueKey<String>(id));

  static Finder get navHome => byId(UiElementIds.navHome);
  static Finder get navTracking => byId(UiElementIds.navTracking);
  static Finder get navLocalLibrary => byId(UiElementIds.navLocalLibrary);
  static Finder get navDownloads => byId(UiElementIds.navDownloads);
  static Finder get navRss => byId(UiElementIds.navRss);
  static Finder get navSettings => byId(UiElementIds.navSettings);
  static Finder get navDiagnostics => byId(UiElementIds.navDiagnostics);

  static Finder get pageHome => byId(UiElementIds.pageHome);
  static Finder get pageTracking => byId(UiElementIds.pageTracking);
  static Finder get pageLocalLibrary => byId(UiElementIds.pageLocalLibrary);
  static Finder get pageDownloads => byId(UiElementIds.pageDownloads);
  static Finder get pageRss => byId(UiElementIds.pageRss);
  static Finder get pageSettings => byId(UiElementIds.pageSettings);
  static Finder get pageDiagnostics => byId(UiElementIds.pageDiagnostics);

  static Finder get homeSearchEntry => byId(UiElementIds.homeSearchEntry);
  static Finder get homeSearchInput => byId(UiElementIds.homeSearchInput);
  static Finder get homeSearchClose => byId(UiElementIds.homeSearchClose);
  static Finder get homeSearchRetry => byId(UiElementIds.homeSearchRetry);
  static Finder get homeRecommendationWaterfall =>
      byId(UiElementIds.homeRecommendationWaterfall);

  static Finder homeSearchResult(String subjectId) {
    return byId(UiElementIds.homeSearchResult(subjectId));
  }

  static Finder homeRecentWatchingDetail(String subjectId) {
    return byId(UiElementIds.homeRecentWatchingDetail(subjectId));
  }

  static Finder trackingItem(String subjectId) {
    return byId(UiElementIds.trackingItem(subjectId));
  }

  static Finder get videoDetailClose => byId(UiElementIds.videoDetailClose);

  static Finder get settingsSectionAppearance =>
      byId(UiElementIds.settingsSectionAppearance);
  static Finder get settingsSectionBangumi =>
      byId(UiElementIds.settingsSectionBangumi);
  static Finder get settingsSectionNetwork =>
      byId(UiElementIds.settingsSectionNetwork);
  static Finder get settingsSectionMediaLibrary =>
      byId(UiElementIds.settingsSectionMediaLibrary);
  static Finder get settingsSectionAbout =>
      byId(UiElementIds.settingsSectionAbout);
  static Finder get settingsAboutAppInfo =>
      byId(UiElementIds.settingsAboutAppInfo);
  static Finder get settingsReferenceRepositories =>
      byId(UiElementIds.settingsReferenceRepositories);
  static Finder get settingsThemeMode => byId(UiElementIds.settingsThemeMode);
  static Finder get settingsBangumiOAuthLogin =>
      byId(UiElementIds.settingsBangumiOAuthLogin);
  static Finder get settingsBangumiAccessToken =>
      byId(UiElementIds.settingsBangumiAccessToken);
  static Finder get settingsBangumiLogin =>
      byId(UiElementIds.settingsBangumiLogin);
  static Finder get settingsBangumiMirror =>
      byId(UiElementIds.settingsBangumiMirror);
  static Finder get settingsBangumiMirrorApiUrl =>
      byId(UiElementIds.settingsBangumiMirrorApiUrl);
  static Finder get settingsBangumiMirrorImageUrl =>
      byId(UiElementIds.settingsBangumiMirrorImageUrl);
  static Finder get settingsBangumiMirrorSave =>
      byId(UiElementIds.settingsBangumiMirrorSave);
  static Finder get settingsHttpProxy => byId(UiElementIds.settingsHttpProxy);
  static Finder get settingsSaveProxy => byId(UiElementIds.settingsSaveProxy);
  static Finder get settingsDnsPolicy => byId(UiElementIds.settingsDnsPolicy);
  static Finder get settingsSaveDns => byId(UiElementIds.settingsSaveDns);
  static Finder get settingsAddMediaFolder =>
      byId(UiElementIds.settingsAddMediaFolder);

  static Finder settingsEditMediaFolder(Uri folder) {
    return byId(UiElementIds.settingsEditMediaFolder(folder));
  }

  static Finder settingsRemoveMediaFolder(Uri folder) {
    return byId(UiElementIds.settingsRemoveMediaFolder(folder));
  }

  static Finder get downloadDetailScroll =>
      byId(UiElementIds.downloadDetailScroll);
  static Finder get rssItemSearch => byId(UiElementIds.rssItemSearch);
  static Finder get rssSelectVisibleDownloadable =>
      byId(UiElementIds.rssSelectVisibleDownloadable);
  static Finder get rssClearSelection => byId(UiElementIds.rssClearSelection);
  static Finder get rssDownloadSelected =>
      byId(UiElementIds.rssDownloadSelected);
  static Finder get heroCarouselCachePin =>
      byId(UiElementIds.heroCarouselCachePin);

  static Finder get playbackPage => byId(UiElementIds.playbackPage);
  static Finder get playbackPlayPause => byId(UiElementIds.playbackPlayPause);
  static Finder get playbackSeekBar => byId(UiElementIds.playbackSeekBar);
  static Finder get playbackStop => byId(UiElementIds.playbackStop);
  static Finder get playbackInspector => byId(UiElementIds.playbackInspector);
  static Finder get playbackTrackPanel => byId(UiElementIds.playbackTrackPanel);
  static Finder get playbackSubtitleOverlay =>
      byId(UiElementIds.playbackSubtitleOverlay);
  static Finder get playbackDanmakuOverlay =>
      byId(UiElementIds.playbackDanmakuOverlay);

  static Finder heroCarouselItem(String subjectId) {
    return byId(UiElementIds.heroCarouselItem(subjectId));
  }

  static Finder playbackTrack(String trackId) {
    return byId(UiElementIds.playbackTrack(trackId));
  }

  static Finder rssItemSelect(String itemId) {
    return byId(UiElementIds.rssItemSelect(itemId));
  }

  static Finder rssItemDownload(String itemId) {
    return byId(UiElementIds.rssItemDownload(itemId));
  }
}
