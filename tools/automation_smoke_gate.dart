import 'dart:io';

import '../lib/elaina.dart';

const FeedSourceId _feedSourceId = FeedSourceId('automation-smoke-feed');
const SeasonalFeedSourceId _seasonalSourceId =
    SeasonalFeedSourceId('automation-smoke-feed');
const AnimeSeason _season =
    AnimeSeason(year: 2026, kind: AnimeSeasonKind.summer);
const String _episodeTitle = 'Automation Smoke Episode 01';
const String _episodeGuid = 'automation-smoke-episode-01';
const String _ruleSourceId = 'automation-smoke-rule-source';
const String _ruleVersion = '1.0.0';
const String _ruleChecksum = 'sha256:automation-smoke';
const String _searchPage = 'https://source.example.test/search';
const String _detailPage = 'https://source.example.test/detail';

Future<void> main() async {
  final AutomationSmokeGateResult result = await runAutomationSmokeGate();
  stdout.writeln(
    'Automation smoke gate passed: '
    '${result.acceptedFeedItemCount} RSS item, '
    '${result.catalogEntryCount} catalog entry, '
    '${result.pendingMatchCount} pending match, '
    '${result.onlineRuleTargetReportCount} rule target reports.',
  );
}

final class AutomationSmokeGateResult {
  const AutomationSmokeGateResult({
    required this.acceptedFeedItemCount,
    required this.catalogEntryCount,
    required this.pendingMatchCount,
    required this.firstCatalogTitle,
    required this.onlineRuleTargetReportCount,
    required this.onlineRuleNormalizedOutputCount,
    required this.searchResultTitle,
    required this.detailTitle,
  });

  final int acceptedFeedItemCount;
  final int catalogEntryCount;
  final int pendingMatchCount;
  final String firstCatalogTitle;
  final int onlineRuleTargetReportCount;
  final int onlineRuleNormalizedOutputCount;
  final String searchResultTitle;
  final String detailTitle;
}

Future<AutomationSmokeGateResult> runAutomationSmokeGate() async {
  final DeterministicStorageFoundation storage =
      DeterministicStorageFoundation();
  final _SmokeFeedHttpTransport transport = _SmokeFeedHttpTransport(
    responses: <FeedHttpResponse>[
      FeedHttpResponse(
        statusCode: HttpStatus.ok,
        body: _rssBody(),
        headers: const <String, String>{HttpHeaders.etagHeader: '"smoke-v1"'},
      ),
    ],
  );
  final DeterministicSeasonalCatalogStore catalogStore =
      DeterministicSeasonalCatalogStore();
  final DeterministicBangumiMatchQueueStore queueStore =
      DeterministicBangumiMatchQueueStore();
  final SeasonalFeedFlowBootstrap flow = SeasonalFeedFlowBootstrap(
    rssStore: storage.rssFeed,
    fetcher: HttpFeedFetcher(
      gateway: DeterministicProviderGateway(storage: storage),
      transport: transport,
    ),
    parser: const RssXmlFeedParser(),
    scheduler: _SmokeFeedScheduler(),
    consumers: const <SeasonalAnimeConsumer>[
      FeedItemSeasonalAnimeConsumer(
        sourceId: _seasonalSourceId,
        season: _season,
      ),
    ],
    catalogStore: catalogStore,
    matchQueueStore: queueStore,
    clock: _smokeNow,
  );

  try {
    final SeasonalFeedFlowRefreshSnapshot refresh =
        await _runSeasonalRefresh(flow, transport);
    final OnlineRuleTestReport ruleReport =
        await _runOnlineRuleSmoke(refresh.catalogEntries.single.title);

    final OnlineRuleSearchOutput searchOutput = ruleReport
        .targetReports.first.normalizedOutput! as OnlineRuleSearchOutput;
    final OnlineRuleDetailOutput detailOutput = ruleReport
        .targetReports.last.normalizedOutput! as OnlineRuleDetailOutput;

    return AutomationSmokeGateResult(
      acceptedFeedItemCount: refresh.rssRefresh.acceptedItems.length,
      catalogEntryCount: refresh.catalogEntries.length,
      pendingMatchCount: refresh.matchQueue.pendingCount,
      firstCatalogTitle: refresh.catalogEntries.single.title,
      onlineRuleTargetReportCount: ruleReport.targetReports.length,
      onlineRuleNormalizedOutputCount: ruleReport.targetReports
          .where(
            (OnlineRuleTestTargetReport report) =>
                report.normalizedOutput != null,
          )
          .length,
      searchResultTitle: searchOutput.results.single.title,
      detailTitle: detailOutput.detail.title,
    );
  } finally {
    await flow.dispose();
  }
}

Future<SeasonalFeedFlowRefreshSnapshot> _runSeasonalRefresh(
  SeasonalFeedFlowBootstrap flow,
  _SmokeFeedHttpTransport transport,
) async {
  final SeasonalFeedFlowActionResult<FeedSource> registered =
      await flow.registerSource(_feedSource());
  _expect(registered.isSuccess, 'Automation smoke gate must register source.');

  final SeasonalFeedFlowActionResult<SeasonalFeedFlowRefreshSnapshot>
      refreshed = await flow.refreshSource(_feedSourceId);
  _expect(refreshed.isSuccess, 'Automation smoke gate refresh must succeed.');
  final SeasonalFeedFlowRefreshSnapshot snapshot = refreshed.value!;

  _expect(
    snapshot.rssRefresh.acceptedItems.single.title == _episodeTitle,
    'Automation smoke gate must accept the RSS item.',
  );
  _expect(
    snapshot.catalogEntries.single.title == _episodeTitle,
    'Automation smoke gate must project the seasonal catalog entry.',
  );
  _expect(
    snapshot.matchQueue.pendingCount == 1,
    'Automation smoke gate must project pending Bangumi match work.',
  );
  _expect(
    transport.requests.single.headers[HttpHeaders.acceptHeader] ==
        defaultFeedAcceptHeader,
    'Automation smoke gate must use the Step 46 feed fetcher.',
  );

  return snapshot;
}

Future<OnlineRuleTestReport> _runOnlineRuleSmoke(String title) async {
  const OnlineRuleTestHarness harness = OnlineRuleTestHarness();
  final OnlineRuleTestReport report = await harness.run(
    OnlineRuleTestPlan(
      manifest: _manifest(),
      documents: <OnlineRuleTestDocument>[
        OnlineRuleTestDocument(
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse(_searchPage),
          document: _searchDocument(title),
        ),
        OnlineRuleTestDocument(
          target: OnlineRuleTarget.detail,
          pageUri: Uri.parse(_detailPage),
          document: _detailDocument(title),
        ),
      ],
    ),
  );

  _expect(report.isSuccess, 'Automation smoke gate rule report must pass.');
  _expect(
    report.targetReports.length == 2,
    'Automation smoke gate must report both rule targets.',
  );
  _expect(
    report.targetReports.every(
      (OnlineRuleTestTargetReport targetReport) =>
          targetReport.normalizedOutput != null,
    ),
    'Automation smoke gate must expose normalized rule outputs.',
  );

  return report;
}

FeedSource _feedSource() {
  return FeedSource(
    id: _feedSourceId,
    displayName: 'Automation Smoke Feed',
    uri: Uri.parse('https://example.test/automation-smoke.xml'),
    format: FeedFormat.rss,
    refreshInterval: const Duration(hours: 1),
  );
}

String _rssBody() {
  return '''
<rss version="2.0">
  <channel>
    <item>
      <title>$_episodeTitle</title>
      <guid>$_episodeGuid</guid>
      <link>/anime/$_episodeGuid</link>
      <pubDate>Wed, 17 Jun 2026 12:00:00 GMT</pubDate>
      <description>Automation smoke gate feed item.</description>
    </item>
  </channel>
</rss>
''';
}

OnlineRuleManifest _manifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId(_ruleSourceId),
    displayName: 'Automation Smoke Rule Source',
    version: const OnlineRuleManifestVersion(_ruleVersion),
    updateUri: Uri.parse('https://rules.example.test/automation-smoke.json'),
    checksum: _ruleChecksum,
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'search-title',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.result h2',
            outputKey: 'title',
            required: true,
          ),
          OnlineExtractionOperation(
            id: 'search-detail',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.detail-link',
            outputKey: 'detailUri',
            attribute: 'href',
            required: true,
          ),
        ],
      ),
      OnlineRuleSet(
        target: OnlineRuleTarget.detail,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'detail-title',
            kind: OnlineExtractionKind.xpath1,
            expression: '//section[@id="detail"]/h1',
            outputKey: 'title',
            required: true,
          ),
          OnlineExtractionOperation(
            id: 'detail-page',
            kind: OnlineExtractionKind.xpath1,
            expression: '//section[@id="detail"]/a',
            outputKey: 'pageUri',
            attribute: 'href',
            required: true,
          ),
        ],
      ),
    ],
  );
}

String _searchDocument(String title) {
  return '<article class="result">'
      '<h2>$title</h2>'
      '<a class="detail-link" href="$_detailPage">Detail</a>'
      '</article>';
}

String _detailDocument(String title) {
  return '<html><body><section id="detail">'
      '<h1>$title</h1>'
      '<a href="$_detailPage">Detail</a>'
      '</section></body></html>';
}

DateTime _smokeNow() => DateTime.utc(2026, 6, 17, 12);

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _SmokeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

final class _SmokeFeedHttpTransport implements FeedHttpTransport {
  _SmokeFeedHttpTransport({required this.responses});

  final List<FeedHttpResponse> responses;
  final List<FeedHttpRequest> requests = <FeedHttpRequest>[];
  int _index = 0;

  @override
  Future<FeedHttpResponse> send(FeedHttpRequest request) {
    requests.add(request);
    final FeedHttpResponse response =
        responses[_index < responses.length ? _index : responses.length - 1];
    _index += 1;
    return Future<FeedHttpResponse>.value(response);
  }
}
