import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'framework/elaina_test_framework.dart';
import 'support/widget_test_waiters.dart';

void main() {
  testWidgets('Elaina app shell smoke test', (WidgetTester tester) async {
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpApp(tester);
    addTearDown(fixture.dispose);

    expect(find.text('Elaina'), findsOneWidget);
    expect(ElainaFinders.navHome, findsOneWidget);
    expect(ElainaFinders.navSettings, findsOneWidget);
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
    final ElainaAppFixture fixture = await ElainaTestHarness.pumpShell(
      tester,
      homeRecommendationProvider: RecordingHomeRecommendationProvider(
        popularSnapshot: HomeRecommendationSnapshot.loaded(
          <HomeRecommendationItem>[
            const HomeRecommendationItem(
              subjectId: '100',
              title: 'Recent Hot Anime',
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
            title: 'Recent Hot Anime',
            rank: 1,
            score: 9.3,
            collectionTotal: 120000,
            episodeCount: 12,
          ),
          HomeRecommendationItem(
            subjectId: '101',
            title: 'Six Month Hot Anime',
            score: 8.1,
            collectionTotal: 42000,
            episodeCount: 13,
          ),
        ],
        recentPageLimit: 1,
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpUntilFound(find.text('Six Month Hot Anime'));

    expect(find.text('Recent Hot Anime'), findsWidgets);
    expect(find.text('Six Month Hot Anime'), findsOneWidget);
    expect(ElainaFinders.homeRecommendationWaterfall, findsOneWidget);

    await tester.tap(find.text('Recent Hot Anime').first);
    await tester.pump();
    await tester.pumpUntilFound(find.text('Mock Title'));
    fixture.robot.detail.expectLoaded('Mock Title');

    await fixture.robot.detail.close();
    await tester.pumpUntilGone(find.text('Mock Title'));

    await fixture.robot.home.openWaterfallRecommendation('Six Month Hot Anime');
    await tester.pumpUntilFound(find.text('Mock Title'));
    fixture.robot.detail.expectLoaded('Mock Title');
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

    final int popularCalls = homeProvider.popularCalls;
    final int recentPopularCalls = homeProvider.recentPopularCalls;
    final int trackingCalls = trackingProvider.currentAnimeCollectionCalls;

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();

    expect(homeProvider.popularCalls, popularCalls);
    expect(homeProvider.recentPopularCalls, recentPopularCalls);
    expect(trackingProvider.currentAnimeCollectionCalls, trackingCalls);
    expect(find.text('Theme Tracking Anime'), findsOneWidget);
  });
}
