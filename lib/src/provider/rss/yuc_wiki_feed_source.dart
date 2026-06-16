import 'feed_contracts.dart';

const Duration yucWikiSeasonalFeedRefreshInterval = Duration(hours: 6);

final FeedSource yucWikiSeasonalFeedSource = FeedSource(
  id: const FeedSourceId('yuc-wiki-seasonal-rss'),
  displayName: 'YucWiki Seasonal RSS',
  uri: Uri.parse('https://yuc.wiki/feed'),
  format: FeedFormat.rss,
  refreshInterval: yucWikiSeasonalFeedRefreshInterval,
);
