import 'dart:async';

// App smoke widget tests use the shared harness for navigation reachability.
// Page-specific behavior belongs in focused UI suites to keep this file stable.
// Add broad shell coverage here only when multiple pages must boot together.
import 'package:elaina/elaina.dart';
import 'package:elaina/src/domain/diagnostics/diagnostics_domain.dart';
import 'package:elaina/src/ui/diagnostics/diagnostics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'framework/elaina_test_framework.dart';
import 'support/widget_test_waiters.dart';

const Duration popupMenuTransitionWait = Duration(milliseconds: 300);

void main() {
  testWidgets('Elaina app shell smoke test', (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpApp(tester);
    addTearDown(fixture.dispose);

    expect(find.text('Elaina'), findsOneWidget);
    expect(ElainaFinders.navHome, findsOneWidget);
    expect(ElainaFinders.navSettings, findsOneWidget);
  });

  testWidgets(
      'diagnostics refresh starts only while diagnostics page is active',
      (WidgetTester tester) async {
    final _CountingDiagnosticsRuntime diagnosticsRuntime =
        _CountingDiagnosticsRuntime();
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      diagnosticsRuntime: diagnosticsRuntime,
    );
    addTearDown(fixture.dispose);

    expect(diagnosticsRuntime.queryEventsCalls, 0);

    await fixture.robot.shell.openDiagnostics();
    await tester.pumpUntilFound(ElainaFinders.pageDiagnostics);
    await tester.pump();

    expect(diagnosticsRuntime.queryEventsCalls, greaterThanOrEqualTo(1));
    final int callsAfterOpen = diagnosticsRuntime.queryEventsCalls;

    await tester.pump(diagnosticsDefaultRefreshInterval);
    await tester.pump();
    expect(diagnosticsRuntime.queryEventsCalls, greaterThan(callsAfterOpen));

    await fixture.robot.shell.openHome();
    await tester.pump();
    final int callsAfterLeaving = diagnosticsRuntime.queryEventsCalls;

    await tester.pump(diagnosticsDefaultRefreshInterval);
    await tester.pump();

    expect(diagnosticsRuntime.queryEventsCalls, callsAfterLeaving);
  });

  testWidgets('home search opens typeahead and Enter opens first result',
      (WidgetTester tester) async {
    final RecordingHomeSearchProvider searchProvider =
        RecordingHomeSearchProvider(
      snapshotsByQuery: <String, HomeSearchSnapshot>{
        'fri': HomeSearchSnapshot.loaded(
          const <HomeSearchItem>[
            HomeSearchItem(
              subjectId: 'search-frieren',
              title: 'Frieren',
              summary: 'Journey after the end.',
              score: 9.1,
              collectionTotal: 120000,
              episodeCount: 28,
            ),
          ],
        ),
      },
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeSearchProvider: searchProvider,
    );
    addTearDown(fixture.dispose);

    await fixture.robot.home.openSearch();
    final TextField input =
        tester.widget<TextField>(ElainaFinders.homeSearchInput);
    expect(input.focusNode?.hasFocus, isTrue);

    await fixture.robot.home.enterSearchQuery('f');
    expect(searchProvider.searchedQueries, isEmpty);

    await fixture.robot.home.enterSearchQuery('fri');
    await tester.pumpUntilFound(find.text('Frieren'));

    expect(searchProvider.searchedQueries, <String>['fri']);
    expect(ElainaFinders.homeSearchResult('search-frieren'), findsOneWidget);

    await fixture.robot.home.submitFirstSearchResult();
    await tester.pumpUntilFound(find.text('Mock Title'));

    expect(ElainaFinders.homeSearchInput, findsNothing);
    fixture.robot.detail.expectLoaded('Mock Title');
  });

  testWidgets('home search closes with Escape', (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeSearchProvider: RecordingHomeSearchProvider(),
    );
    addTearDown(fixture.dispose);

    await fixture.robot.home.openSearch();
    await fixture.robot.home.closeSearchWithEscape();

    expect(ElainaFinders.homeSearchInput, findsNothing);
  });

  testWidgets('home search supports Chinese queries',
      (WidgetTester tester) async {
    final RecordingHomeSearchProvider searchProvider =
        RecordingHomeSearchProvider(
      snapshotsByQuery: <String, HomeSearchSnapshot>{
        '电视': HomeSearchSnapshot.loaded(
          const <HomeSearchItem>[
            HomeSearchItem(
              subjectId: 'search-tv',
              title: '电视动画',
              summary: '中文搜索候选',
              score: 8.0,
              collectionTotal: 24000,
              episodeCount: 12,
            ),
          ],
        ),
      },
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeSearchProvider: searchProvider,
    );
    addTearDown(fixture.dispose);

    await fixture.robot.home.openSearch();
    await fixture.robot.home.enterSearchQuery('电视');
    await tester.pumpUntilFound(find.text('电视动画'));

    expect(searchProvider.searchedQueries, <String>['电视']);
    expect(ElainaFinders.homeSearchResult('search-tv'), findsOneWidget);

    await fixture.robot.home.submitFirstSearchResult();
    await tester.pumpUntilFound(find.text('Mock Title'));

    expect(ElainaFinders.homeSearchInput, findsNothing);
    fixture.robot.detail.expectLoaded('Mock Title');
  });

  testWidgets('home search retry recovers from provider failure',
      (WidgetTester tester) async {
    final RecordingHomeSearchProvider searchProvider =
        RecordingHomeSearchProvider(
      queuedSnapshotsByQuery: <String, List<HomeSearchSnapshot>>{
        'bad': <HomeSearchSnapshot>[
          const HomeSearchSnapshot.failed('Bangumi temporarily failed.'),
          HomeSearchSnapshot.loaded(
            const <HomeSearchItem>[
              HomeSearchItem(
                subjectId: 'retry-subject',
                title: 'Recovered Anime',
              ),
            ],
          ),
        ],
      },
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeSearchProvider: searchProvider,
    );
    addTearDown(fixture.dispose);

    await fixture.robot.home.openSearch();
    await fixture.robot.home.enterSearchQuery('bad');
    await tester.pumpUntilFound(find.text('Bangumi temporarily failed.'));

    await fixture.robot.home.retrySearch();
    await tester.pumpUntilFound(find.text('Recovered Anime'));

    expect(searchProvider.searchedQueries, <String>['bad', 'bad']);
  });

  testWidgets('home search ignores stale typeahead results',
      (WidgetTester tester) async {
    final Completer<HomeSearchSnapshot> oldSearch =
        Completer<HomeSearchSnapshot>();
    final Completer<HomeSearchSnapshot> newSearch =
        Completer<HomeSearchSnapshot>();
    final RecordingHomeSearchProvider searchProvider =
        RecordingHomeSearchProvider(
      pendingByQuery: <String, Completer<HomeSearchSnapshot>>{
        'sl': oldSearch,
        'slow': newSearch,
      },
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeSearchProvider: searchProvider,
    );
    addTearDown(fixture.dispose);

    await fixture.robot.home.openSearch();
    await fixture.robot.home.enterSearchQuery('sl');
    expect(searchProvider.searchedQueries, <String>['sl']);

    await fixture.robot.home.enterSearchQuery('slow');
    expect(searchProvider.searchedQueries, <String>['sl', 'slow']);

    newSearch.complete(
      HomeSearchSnapshot.loaded(
        const <HomeSearchItem>[
          HomeSearchItem(subjectId: 'new-result', title: 'New Result'),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpUntilFound(find.text('New Result'));

    oldSearch.complete(
      HomeSearchSnapshot.loaded(
        const <HomeSearchItem>[
          HomeSearchItem(subjectId: 'old-result', title: 'Old Result'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('New Result'), findsOneWidget);
    expect(find.text('Old Result'), findsNothing);
  });

  testWidgets('Elaina app shell greets signed-in profile',
      (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      profileProvider: const RecordingUserProfileProvider(
        UserProfileSnapshot(displayName: 'Alice'),
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpUntilFound(find.textContaining('Alice'));

    expect(find.textContaining('Alice'), findsOneWidget);
  });

  testWidgets(
      'Elaina app shell shows popular hero and signed-out recent watching state',
      (WidgetTester tester) async {
    final RecordingHomeRecommendationProvider homeRecommendationProvider =
        RecordingHomeRecommendationProvider(
      popularSnapshot: HomeRecommendationSnapshot.loaded(
        <HomeRecommendationItem>[
          const HomeRecommendationItem(
            subjectId: '100',
            title: 'Official Trends Hero Anime',
            rank: 1,
            score: 9.3,
            collectionTotal: 120000,
            episodeCount: 12,
          ),
        ],
      ),
      recentItems: const <HomeRecommendationItem>[
        HomeRecommendationItem(
          subjectId: '100',
          title: 'Official Trends Hero Anime',
          rank: 1,
          score: 9.3,
          collectionTotal: 120000,
          episodeCount: 12,
        ),
        HomeRecommendationItem(
          subjectId: '101',
          title: 'Recent API Popular Anime',
          score: 8.1,
          collectionTotal: 42000,
          episodeCount: 13,
        ),
      ],
      recentItemsByCategory: const <HomeRecommendationCategory,
          Iterable<HomeRecommendationItem>>{
        HomeRecommendationCategory.yuri: <HomeRecommendationItem>[
          HomeRecommendationItem(
            subjectId: '102',
            title: 'Yuri API Popular Anime',
            score: 8.4,
            collectionTotal: 52000,
            episodeCount: 12,
          ),
        ],
      },
      recentPageLimit: 1,
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeRecommendationProvider: homeRecommendationProvider,
    );
    addTearDown(fixture.dispose);

    await tester.pumpUntilFound(find.text('Recent API Popular Anime'));

    expect(find.text(HomeRecommendationCategory.popular.label), findsOneWidget);
    expect(ElainaFinders.homeRecommendationCategoryMenu, findsOneWidget);
    expect(
      homeRecommendationProvider.recentPopularCategories.first.id,
      HomeRecommendationCategory.popular.id,
    );
    expect(ElainaFinders.heroCarouselItem('100'), findsOneWidget);
    expect(
      find.descendant(
        of: ElainaFinders.heroCarouselItem('100'),
        matching: find.text('Official Trends Hero Anime'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: ElainaFinders.heroCarouselPoster('100'),
        matching: find.text('Official Trends Hero Anime'),
      ),
      findsNothing,
    );
    expect(find.text('Recent API Popular Anime'), findsOneWidget);
    expect(ElainaFinders.homeRecommendationWaterfall, findsOneWidget);

    await tester.tap(ElainaFinders.heroCarouselItem('100'));
    await tester.pump();
    await tester.pumpUntilFound(find.text('Mock Title'));
    fixture.robot.detail.expectLoaded('Mock Title');

    await fixture.robot.detail.close();
    await tester.pumpUntilGone(find.text('Mock Title'));

    await fixture.robot.home.openWaterfallRecommendation(
      'Recent API Popular Anime',
    );
    await tester.pumpUntilFound(find.text('Mock Title'));
    fixture.robot.detail.expectLoaded('Mock Title');

    await fixture.robot.detail.close();
    await tester.pumpUntilGone(find.text('Mock Title'));

    await tester.scrollUntilVisible(
      ElainaFinders.homeRecommendationCategoryMenu,
      300,
      scrollable: find
          .descendant(
            of: ElainaFinders.pageHome,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump(defaultWidgetWaitPumpStep);
    await tester.tap(ElainaFinders.homeRecommendationCategoryMenu);
    await tester
        .pumpUntilFound(ElainaFinders.homeRecommendationCategory('yuri'));
    await tester.pump(popupMenuTransitionWait);
    await tester.tap(find.text(HomeRecommendationCategory.yuri.label).last);
    await tester.pumpUntilFound(find.text('Yuri API Popular Anime'));

    expect(find.text('Recent API Popular Anime'), findsNothing);
    expect(
      homeRecommendationProvider.recentPopularCategories.last.id,
      HomeRecommendationCategory.yuri.id,
    );
  });

  testWidgets('Elaina app shell shows signed-in recent watching items',
      (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      profileProvider: const RecordingUserProfileProvider(
        UserProfileSnapshot(displayName: 'Alice'),
      ),
      bangumiTrackingProvider: RecordingBangumiTrackingProvider(
        BangumiTrackingSnapshot.loaded(
          <BangumiTrackingItem>[
            BangumiTrackingItem(
              subjectId: '200',
              title: 'Recently Watched Anime',
              status: BangumiTrackingStatus.watching,
              watchedEpisodes: 3,
              totalEpisodes: 12,
              updatedAt: DateTime.utc(2026, 6, 20),
            ),
            BangumiTrackingItem(
              subjectId: '201',
              title: 'Planned Anime',
              status: BangumiTrackingStatus.planned,
              watchedEpisodes: 0,
              totalEpisodes: 12,
              updatedAt: DateTime.utc(2026, 6, 21),
            ),
          ],
        ),
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpUntilFound(find.text('Recently Watched Anime'));

    expect(find.text('Recently Watched Anime'), findsOneWidget);
    expect(ElainaFinders.homeRecentWatchingPoster('200'), findsOneWidget);
    expect(
      find.descendant(
        of: ElainaFinders.homeRecentWatchingPoster('200'),
        matching: find.text('Recently Watched Anime'),
      ),
      findsNothing,
    );
    expect(find.text('Planned Anime'), findsNothing);

    await fixture.robot.home.openRecentWatchingDetail('200');
    await tester.pumpUntilFound(find.text('Mock Title'));
    fixture.robot.detail.expectLoaded('Mock Title');
  });

  testWidgets('theme switching does not reload home or tracking providers',
      (WidgetTester tester) async {
    final RecordingHomeRecommendationProvider homeProvider =
        RecordingHomeRecommendationProvider(
      popularSnapshot: HomeRecommendationSnapshot.loaded(
        const <HomeRecommendationItem>[
          HomeRecommendationItem(
            subjectId: 'theme-hero',
            title: 'Theme Hero Anime',
            score: 8.8,
          ),
        ],
      ),
      recentItems: const <HomeRecommendationItem>[
        HomeRecommendationItem(
          subjectId: 'theme-more',
          title: 'Theme More Anime',
          score: 8.1,
        ),
      ],
      recentPageLimit: 1,
    );
    final RecordingBangumiTrackingProvider trackingProvider =
        RecordingBangumiTrackingProvider(
      BangumiTrackingSnapshot.loaded(
        <BangumiTrackingItem>[
          BangumiTrackingItem(
            subjectId: 'theme-tracking',
            title: 'Theme Tracking Anime',
            status: BangumiTrackingStatus.watching,
            watchedEpisodes: 2,
            totalEpisodes: 12,
            updatedAt: DateTime.utc(2026, 6, 21),
          ),
        ],
      ),
    );
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeRecommendationProvider: homeProvider,
      bangumiTrackingProvider: trackingProvider,
    );
    addTearDown(fixture.dispose);

    await tester.pumpUntilFound(find.text('Theme Tracking Anime'));

    final int heroTrendCalls = homeProvider.heroTrendCalls;
    final int waterfallRecentPopularCalls =
        homeProvider.waterfallRecentPopularCalls;
    final int trackingCalls = trackingProvider.currentAnimeCollectionCalls;

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();

    expect(homeProvider.heroTrendCalls, heroTrendCalls);
    expect(
      homeProvider.waterfallRecentPopularCalls,
      waterfallRecentPopularCalls,
    );
    expect(trackingProvider.currentAnimeCollectionCalls, trackingCalls);
    expect(find.text('Theme Tracking Anime'), findsOneWidget);
  });
}

final class _CountingDiagnosticsRuntime implements DiagnosticsRuntime {
  int queryEventsCalls = 0;

  @override
  Future<List<DiagnosticsEventProjection>> queryEvents() async {
    queryEventsCalls += 1;
    return <DiagnosticsEventProjection>[
      DiagnosticsEventProjection(
        id: 'shell-diagnostics-event',
        eventType: 'shell_probe',
        severity: 'INFO',
        occurredAt: DateTime(2026, 6, 23, 12),
        sourceModule: 'shell',
        correlationId: 'shell-correlation',
        payloadText: 'Shell diagnostics probe.',
      ),
    ];
  }

  @override
  Map<String, String> getCapabilitiesSupportStatus() {
    return const <String, String>{'snapshotQuery': 'Supported'};
  }

  @override
  Future<double> getLatestAvSyncDrift() async => 8.0;

  @override
  int getActiveMemoryUsageBytes() => 128 * 1024 * 1024;
}
