import 'feed_contracts.dart';

final FeedSource yucWikiSeasonalFeedSource = FeedSource(
  id: const FeedSourceId('yuc-wiki-seasonal-rss'),
  displayName: 'YucWiki Seasonal RSS',
  uri: Uri.parse('https://yuc.wiki/feed'),
  format: FeedFormat.rss,
  refreshInterval: const Duration(hours: 6),
);
