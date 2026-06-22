// Screen robots provide stable user-level actions for high-churn widget tests.
// Keep text/layout finders centralized here instead of scattering them through
// page test files.
import 'package:elaina/src/domain/home/home_search_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/widget_test_waiters.dart';
import 'elaina_finders.dart';

final class ElainaRobots {
  ElainaRobots(this.tester)
      : shell = ShellRobot(tester),
        home = HomeRobot(tester),
        settings = SettingsRobot(tester),
        mediaLibrary = MediaLibraryRobot(tester),
        detail = VideoDetailRobot(tester),
        playback = PlaybackRobot(tester),
        downloads = DownloadsRobot(tester),
        rss = RssRobot(tester);

  final WidgetTester tester;
  final ShellRobot shell;
  final HomeRobot home;
  final SettingsRobot settings;
  final MediaLibraryRobot mediaLibrary;
  final VideoDetailRobot detail;
  final PlaybackRobot playback;
  final DownloadsRobot downloads;
  final RssRobot rss;
}

base class ScreenRobot {
  ScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> tapAndSettle(Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

final class ShellRobot extends ScreenRobot {
  ShellRobot(super.tester);

  Future<void> openHome() => tap(ElainaFinders.navHome);
  Future<void> openTracking() => tap(ElainaFinders.navTracking);
  Future<void> openLocalLibrary() => tap(ElainaFinders.navLocalLibrary);
  Future<void> openDownloads() => tap(ElainaFinders.navDownloads);
  Future<void> openRss() => tap(ElainaFinders.navRss);
  Future<void> openSettings() => tap(ElainaFinders.navSettings);
  Future<void> openDiagnostics() => tap(ElainaFinders.navDiagnostics);
}

final class HomeRobot extends ScreenRobot {
  HomeRobot(super.tester);

  Future<void> openSearch() async {
    await tap(ElainaFinders.homeSearchEntry);
    await tester.pumpUntilFound(ElainaFinders.homeSearchInput);
  }

  Future<void> enterSearchQuery(String query) async {
    await tester.enterText(ElainaFinders.homeSearchInput, query);
    await tester.pump(homeSearchDebounceDuration);
  }

  Future<void> retrySearch() => tap(ElainaFinders.homeSearchRetry);

  Future<void> submitFirstSearchResult() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
  }

  Future<void> closeSearchWithEscape() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pumpUntilGone(ElainaFinders.homeSearchInput);
  }

  Future<void> openRecentWatchingDetail(String subjectId) async {
    final Finder target = ElainaFinders.homeRecentWatchingDetail(subjectId);
    await _scrollHomeUntilVisible(target);
    await tap(target);
  }

  Future<void> openWaterfallRecommendation(String title) async {
    final Finder target = find.text(title);
    await _scrollHomeUntilVisible(target);
    await tap(target);
  }

  Future<void> _scrollHomeUntilVisible(Finder target) async {
    final Finder homeScrollable = find
        .descendant(
          of: ElainaFinders.pageHome,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: homeScrollable,
    );
    await tester.pump(defaultWidgetWaitPumpStep);
  }
}

final class SettingsRobot extends ScreenRobot {
  SettingsRobot(super.tester);

  Future<void> openAppearance() async {
    await tapAndSettle(ElainaFinders.settingsSectionAppearance.first);
  }

  Future<void> openBangumi() async {
    await tapAndSettle(ElainaFinders.settingsSectionBangumi.first);
  }

  Future<void> openNetwork() async {
    await tapAndSettle(ElainaFinders.settingsSectionNetwork.first);
  }

  Future<void> openMediaLibrary() async {
    await tapAndSettle(ElainaFinders.settingsSectionMediaLibrary.first);
  }

  Future<void> saveBangumiToken(String token) async {
    await tester.enterText(ElainaFinders.settingsBangumiAccessToken, token);
    await tapAndSettle(ElainaFinders.settingsBangumiLogin);
  }

  Future<void> openBangumiOAuth() {
    return tapAndSettle(ElainaFinders.settingsBangumiOAuthLogin);
  }

  Future<void> saveProxy(String proxyUrl) async {
    await tester.enterText(ElainaFinders.settingsHttpProxy, proxyUrl);
    await tapAndSettle(ElainaFinders.settingsSaveProxy);
  }

  Future<void> addMediaFolder() {
    return tapAndSettle(ElainaFinders.settingsAddMediaFolder);
  }
}

final class MediaLibraryRobot extends ScreenRobot {
  MediaLibraryRobot(super.tester);

  Future<void> open() => tap(ElainaFinders.navLocalLibrary);
}

final class VideoDetailRobot extends ScreenRobot {
  VideoDetailRobot(super.tester);

  Future<void> close() => tap(ElainaFinders.videoDetailClose);

  void expectLoaded(String title) {
    expect(find.text(title), findsWidgets);
  }
}

final class PlaybackRobot extends ScreenRobot {
  PlaybackRobot(super.tester);

  Future<void> openInspector() async {
    await tap(find.byTooltip('打开播放信息'));
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(ElainaFinders.playbackInspector);
  }

  Future<void> selectTrack(String trackId) async {
    await tap(ElainaFinders.playbackTrack(trackId));
  }

  Future<void> stop() => tap(ElainaFinders.playbackStop);
}

final class DownloadsRobot extends ScreenRobot {
  DownloadsRobot(super.tester);

  Future<void> open() => tap(ElainaFinders.navDownloads);

  Future<void> showDetailFiles() async {
    await tester.drag(
        ElainaFinders.downloadDetailScroll, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

final class RssRobot extends ScreenRobot {
  RssRobot(super.tester);

  Future<void> open() => tap(ElainaFinders.navRss);

  Future<void> searchItems(String query) async {
    await tester.enterText(ElainaFinders.rssItemSearch, query);
    await tester.pump();
  }
}
