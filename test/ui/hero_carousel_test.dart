import 'package:elaina/src/ui/theme/elaina_theme.dart';
// Hero carousel tests focus on image-provider lifecycle and cyclic reuse.
// Bangumi ranking windows are tested at provider/home composition boundaries.
import 'package:elaina/src/ui/widgets/hero_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/elaina_test_framework.dart';
import '../support/network_image_test_overrides.dart';

void main() {
  const int expectedCyclicHeroItemCount = 7;

  testWidgets('pins seven hero poster providers for cyclic carousel reuse',
      (WidgetTester tester) async {
    await withMockedNetworkImages(() async {
      final List<HeroCarouselItem> items = <HeroCarouselItem>[
        for (int index = 0; index < expectedCyclicHeroItemCount; index++)
          HeroCarouselItem(
            subjectId: 'subject-$index',
            title: 'Anime $index',
            symbol: 'A$index',
            coverUri: Uri.parse('https://example.invalid/cover-$index.jpg'),
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ElainaTheme(
            data: ElainaThemeData.dark,
            mode: ElainaThemeMode.dark,
            onModeChanged: (_) {},
            child: Scaffold(
              body: HeroCarousel(
                autoScroll: false,
                items: items,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final Finder cachePin = ElainaFinders.heroCarouselCachePin;
      expect(cachePin, findsOneWidget);
      expect(
        find.descendant(of: cachePin, matching: find.byType(Image)),
        findsNWidgets(expectedCyclicHeroItemCount),
      );
      expect(find.text('Anime 0'), findsOneWidget);
    });
  });

  testWidgets('keeps poster decoration after a full seven item loop',
      (WidgetTester tester) async {
    await withMockedNetworkImages(() async {
      final List<HeroCarouselItem> items = <HeroCarouselItem>[
        for (int index = 0; index < expectedCyclicHeroItemCount; index++)
          HeroCarouselItem(
            subjectId: 'subject-$index',
            title: 'Anime $index',
            symbol: 'A$index',
            coverUri: Uri.parse('https://example.invalid/cover-$index.jpg'),
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ElainaTheme(
            data: ElainaThemeData.dark,
            mode: ElainaThemeMode.dark,
            onModeChanged: (_) {},
            child: Scaffold(
              body: HeroCarousel(
                autoScroll: false,
                items: items,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final ScrollableState scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable));
      final Finder firstCard = ElainaFinders.heroCarouselItem('subject-0');
      final Finder secondCard = ElainaFinders.heroCarouselItem('subject-1');
      final double renderedItemPitch =
          tester.getTopLeft(secondCard).dx - tester.getTopLeft(firstCard).dx;
      final double completeLoopOffset =
          expectedCyclicHeroItemCount * renderedItemPitch;

      scrollable.position.jumpTo(completeLoopOffset);
      await tester.pump();

      final Finder secondLoopFirstCard =
          ElainaFinders.heroCarouselItem('subject-0');
      expect(secondLoopFirstCard, findsOneWidget);
      expect(find.text('Anime 0'), findsOneWidget);
      expect(
        find.descendant(
          of: secondLoopFirstCard,
          matching: find.byWidgetPredicate((Widget widget) {
            if (widget is! DecoratedBox) return false;
            final Decoration decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.image?.image is NetworkImage;
          }),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('does not refetch hero posters when only theme changes',
      (WidgetTester tester) async {
    await withMockedNetworkImages(() async {
      final List<HeroCarouselItem> items = <HeroCarouselItem>[
        for (int index = 0; index < expectedCyclicHeroItemCount; index++)
          HeroCarouselItem(
            subjectId: 'theme-subject-$index',
            title: 'Theme Anime $index',
            symbol: 'T$index',
            coverUri: Uri.parse(
              'https://example.invalid/theme-cover-$index.jpg',
            ),
          ),
      ];

      Widget host(ElainaThemeData themeData, ElainaThemeMode mode) {
        return MaterialApp(
          home: ElainaTheme(
            data: themeData,
            mode: mode,
            onModeChanged: (_) {},
            child: Scaffold(
              body: HeroCarousel(
                autoScroll: false,
                items: items,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        host(ElainaThemeData.dark, ElainaThemeMode.dark),
      );
      await tester.pumpAndSettle();
      final Finder cachePin = ElainaFinders.heroCarouselCachePin;
      final List<ImageProvider<Object>> darkProviders = tester
          .widgetList<Image>(
            find.descendant(of: cachePin, matching: find.byType(Image)),
          )
          .map((Image image) => image.image)
          .toList(growable: false);
      expect(darkProviders, hasLength(expectedCyclicHeroItemCount));

      await tester.pumpWidget(
        host(ElainaThemeData.light, ElainaThemeMode.light),
      );
      await tester.pumpAndSettle();
      final List<ImageProvider<Object>> lightProviders = tester
          .widgetList<Image>(
            find.descendant(of: cachePin, matching: find.byType(Image)),
          )
          .map((Image image) => image.image)
          .toList(growable: false);

      expect(lightProviders, hasLength(darkProviders.length));
      for (int index = 0; index < darkProviders.length; index++) {
        expect(identical(lightProviders[index], darkProviders[index]), isTrue);
      }
      expect(find.text('Theme Anime 0'), findsOneWidget);
    });
  });
}
