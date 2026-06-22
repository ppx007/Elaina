import 'dart:async';

import 'package:elaina/elaina.dart';
import 'package:elaina/src/ui/rss/rss_page.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testHost({required Widget child}) {
  return MaterialApp(
    home: ElainaTheme(
      data: ElainaThemeData.dark,
      mode: ElainaThemeMode.dark,
      onModeChanged: (_) {},
      child: Scaffold(body: child),
    ),
  );
}

final DateTime _rssTestInstant = DateTime.utc(2026, 6, 22, 12);

void main() {
  group('RssPage Widget Tests', () {
    late _FakeRssEngine fakeEngine;
    late DeterministicRssFeedStore feedStore;
    late RssEngineRuntime rssEngineRuntime;
    late DeterministicRssAutoDownloadPolicyStore policyStore;

    setUp(() {
      feedStore = DeterministicRssFeedStore();
      fakeEngine = _FakeRssEngine(feedStore);
      policyStore = DeterministicRssAutoDownloadPolicyStore();
      rssEngineRuntime = RssEngineRuntime(
        engine: fakeEngine,
        store: feedStore,
        scheduler: _FakeFeedScheduler(),
        policyStore: policyStore,
      );
    });

    tearDown(() async {
      await rssEngineRuntime.dispose();
      fakeEngine.dispose();
    });

    testWidgets('renders RSS management workspace and empty states',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      expect(find.text('RSS 订阅'), findsOneWidget);
      expect(find.text('订阅源'), findsWidgets);
      expect(find.text('条目流'), findsOneWidget);
      expect(find.text('暂无订阅源'), findsOneWidget);
      expect(find.text('暂无条目'), findsOneWidget);
      expect(find.text('添加订阅'), findsOneWidget);
    });

    testWidgets('adds a new RSS source via dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加订阅'));
      await tester.pumpAndSettle();

      expect(find.text('添加 RSS 订阅'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '订阅源名称'),
        'My Anime Feed',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'RSS / Atom 地址'),
        'https://anime.com/feed.xml',
      );

      await tester.tap(find.text('保存订阅'));
      await tester.pumpAndSettle();

      expect(fakeEngine.registered, hasLength(1));
      expect(fakeEngine.registered.single.displayName, 'My Anime Feed');
      expect(
        fakeEngine.registered.single.uri.toString(),
        'https://anime.com/feed.xml',
      );
      expect(find.text('My Anime Feed'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid RSS URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加订阅'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '订阅源名称'),
        'Invalid Feed',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'RSS / Atom 地址'),
        'not-a-feed-url',
      );

      await tester.tap(find.text('保存订阅'));
      await tester.pumpAndSettle();

      expect(find.text('请输入 http 或 https 订阅地址'), findsOneWidget);
      expect(fakeEngine.registered, isEmpty);
      expect(find.text('添加 RSS 订阅'), findsOneWidget);
    });

    testWidgets('displays persisted feed items and filters with search',
        (WidgetTester tester) async {
      await feedStore.storeSource(_storedRssSource());
      await feedStore.storeItems(<StoredFeedItemRecord>[
        _storedFeedItemRecord(_rssItem(), acceptedAt: _rssTestInstant),
      ]);

      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anime Feed'), findsWidgets);
      expect(find.text('Episode 1'), findsOneWidget);
      expect(find.text('A new episode.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('rss-item-search')),
        'missing',
      );
      await tester.pumpAndSettle();
      expect(find.text('Episode 1'), findsNothing);
      expect(find.text('暂无条目'), findsOneWidget);
    });

    testWidgets('refreshes a source and renders accepted items',
        (WidgetTester tester) async {
      await feedStore.storeSource(_storedRssSource());
      fakeEngine.refreshItems = <FeedItem>[
        _rssItem(title: 'Fresh Episode'),
      ];

      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('同步订阅源'));
      await tester.pumpAndSettle();

      expect(fakeEngine.refreshed.single.value, 'anime-feed');
      expect(find.text('Fresh Episode'), findsOneWidget);
      expect(find.textContaining('新增 1 条'), findsOneWidget);
    });

    testWidgets('toggles auto download and removes a feed source',
        (WidgetTester tester) async {
      await feedStore.storeSource(_storedRssSource());
      await feedStore.storeItems(<StoredFeedItemRecord>[
        _storedFeedItemRecord(_rssItem(), acceptedAt: _rssTestInstant),
      ]);

      await tester.pumpWidget(
        _testHost(child: RssPage(rssEngineRuntime: rssEngineRuntime)),
      );
      await tester.pumpAndSettle();

      tester.widget<Switch>(find.byType(Switch).first).onChanged!(true);
      await tester.pumpAndSettle();
      final List<StoredRssAutoDownloadFeedActivationRecord> activations =
          await policyStore.activationsForPolicy(
        defaultRssAutoDownloadPolicyId,
      );
      expect(activations.single.sourceId, 'anime-feed');
      expect(activations.single.enabled, isTrue);

      await tester.tap(find.byTooltip('删除订阅源'));
      await tester.pumpAndSettle();
      expect(find.text('删除订阅源'), findsOneWidget);
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect((await feedStore.listSources()), isEmpty);
      expect(find.text('Anime Feed'), findsNothing);
      expect(find.text('Episode 1'), findsNothing);
    });
  });
}

final class _FakeRssEngine implements RssEngineContract {
  _FakeRssEngine(this.store);

  final RssFeedStore store;
  final List<FeedSource> registered = <FeedSource>[];
  final List<FeedSourceId> refreshed = <FeedSourceId>[];
  List<FeedItem> refreshItems = const <FeedItem>[];
  RssRefreshFailure? refreshFailure;
  final StreamController<FeedItem> _updatesController =
      StreamController<FeedItem>.broadcast();

  @override
  Future<void> registerSource(FeedSource source) async {
    registered.add(source);
    await store.storeSource(
      StoredFeedSourceRecord(
        id: source.id.value,
        displayName: source.displayName,
        uri: source.uri,
        format: source.format.name,
        refreshInterval: source.refreshInterval,
      ),
    );
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    refreshed.add(request.sourceId);
    final RssRefreshFailure? failure = refreshFailure;
    if (failure != null) {
      return RssRefreshOutcome.failure(
        sourceId: request.sourceId,
        failure: failure,
      );
    }
    await store.storeItems(
      <StoredFeedItemRecord>[
        for (final FeedItem item in refreshItems)
          _storedFeedItemRecord(item, acceptedAt: _rssTestInstant),
      ],
    );
    for (final FeedItem item in refreshItems) {
      _updatesController.add(item);
    }
    return RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: refreshItems,
    );
  }

  @override
  Stream<FeedItem> get updates => _updatesController.stream;

  void dispose() {
    _updatesController.close();
  }
}

final class _FakeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

FeedSource _rssSource({
  String id = 'anime-feed',
  String displayName = 'Anime Feed',
  String uri = 'https://example.test/rss.xml',
}) {
  return FeedSource(
    id: FeedSourceId(id),
    displayName: displayName,
    uri: Uri.parse(uri),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

StoredFeedSourceRecord _storedRssSource({
  String id = 'anime-feed',
  String displayName = 'Anime Feed',
  String uri = 'https://example.test/rss.xml',
}) {
  final FeedSource source = _rssSource(
    id: id,
    displayName: displayName,
    uri: uri,
  );
  return StoredFeedSourceRecord(
    id: source.id.value,
    displayName: source.displayName,
    uri: source.uri,
    format: source.format.name,
    refreshInterval: source.refreshInterval,
    defaultHeaders: source.defaultHeaders,
  );
}

FeedItem _rssItem({
  String id = 'item-1',
  String sourceId = 'anime-feed',
  String title = 'Episode 1',
  String summary = 'A new episode.',
  bool withEnclosure = true,
}) {
  return FeedItem(
    id: FeedItemId(id),
    sourceId: FeedSourceId(sourceId),
    dedupeKey: FeedDedupeKey(id),
    title: title,
    link: Uri.parse('https://example.test/$id'),
    publishedAt: _rssTestInstant,
    summary: summary,
    categories: const <String>['anime'],
    enclosure: withEnclosure
        ? FeedEnclosure(
            uri: Uri.parse('https://example.test/$id.torrent'),
            mimeType: 'application/x-bittorrent',
          )
        : null,
  );
}

StoredFeedItemRecord _storedFeedItemRecord(
  FeedItem item, {
  required DateTime acceptedAt,
}) {
  return StoredFeedItemRecord(
    id: item.id.value,
    sourceId: item.sourceId.value,
    dedupeKey: item.dedupeKey.value,
    title: item.title,
    link: item.link,
    publishedAt: item.publishedAt,
    summary: item.summary,
    categories: item.categories,
    enclosure: item.enclosure == null
        ? null
        : StoredFeedEnclosureRecord(
            uri: item.enclosure!.uri,
            mimeType: item.enclosure!.mimeType,
            lengthBytes: item.enclosure!.lengthBytes,
          ),
    acceptedAt: acceptedAt,
  );
}
