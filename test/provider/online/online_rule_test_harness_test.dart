// Online rule harness tests verify fixture-driven rule evaluation. They should
// not become tests for a specific public website.
import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('harness reports successful multi-target rule source preview', () async {
    const OnlineRuleTestHarness harness = OnlineRuleTestHarness();

    final OnlineRuleTestReport report = await harness.run(
      OnlineRuleTestPlan(
        manifest: _manifest(),
        documents: <OnlineRuleTestDocument>[
          OnlineRuleTestDocument(
            target: OnlineRuleTarget.search,
            pageUri: Uri.parse('https://source.example.test/search'),
            document: _searchDocument('Harness Result'),
          ),
          OnlineRuleTestDocument(
            target: OnlineRuleTarget.detail,
            pageUri: Uri.parse('https://source.example.test/detail'),
            document: _detailDocument('Harness Detail'),
          ),
        ],
      ),
    );

    expect(report.isSuccess, isTrue);
    expect(report.validation.isValid, isTrue);
    expect(report.targetReports, hasLength(2));
    expect(report.targetReports.first.normalizedOutput,
        isA<OnlineRuleSearchOutput>());
    expect(report.targetReports.last.normalizedOutput,
        isA<OnlineRuleDetailOutput>());

    final OnlineRuleSearchOutput search =
        report.targetReports.first.normalizedOutput! as OnlineRuleSearchOutput;
    final OnlineRuleDetailOutput detail =
        report.targetReports.last.normalizedOutput! as OnlineRuleDetailOutput;
    expect(search.results.single.title, 'Harness Result');
    expect(detail.detail.title, 'Harness Detail');
  });

  test('harness short-circuits invalid manifests', () async {
    const OnlineRuleTestHarness harness = OnlineRuleTestHarness();

    final OnlineRuleTestReport report = await harness.run(
      OnlineRuleTestPlan(
        manifest: _unsupportedSelectorManifest(),
        documents: <OnlineRuleTestDocument>[
          OnlineRuleTestDocument(
            target: OnlineRuleTarget.search,
            pageUri: Uri.parse('https://source.example.test/search'),
            document: _searchDocument('Ignored'),
          ),
        ],
      ),
    );

    expect(report.isSuccess, isFalse);
    expect(report.validation.issues.single.unsupportedKind,
        UnsupportedOnlineOperationKind.unsupportedSelector);
    expect(report.targetReports, isEmpty);
  });

  test('harness preserves typed target evaluation failures', () async {
    const OnlineRuleTestHarness harness = OnlineRuleTestHarness();

    final OnlineRuleTestReport report = await harness.run(
      OnlineRuleTestPlan(
        manifest: _manifest(),
        documents: <OnlineRuleTestDocument>[
          OnlineRuleTestDocument(
            target: OnlineRuleTarget.search,
            pageUri: Uri.parse('https://source.example.test/search'),
            document: '<article class="result"><h2>Missing URI</h2></article>',
          ),
        ],
      ),
    );

    expect(report.isSuccess, isFalse);
    expect(report.validation.isValid, isTrue);
    expect(report.targetReports.single.outcome.failure?.kind,
        OnlineRuleFailureKind.requiredOutputMissing);
    expect(report.targetReports.single.normalizedOutput, isNull);
  });

  test('harness converts normalization failures into typed target failures',
      () async {
    const OnlineRuleTestHarness harness = OnlineRuleTestHarness();

    final OnlineRuleTestReport report = await harness.run(
      OnlineRuleTestPlan(
        manifest: _normalizationFailureManifest(),
        documents: <OnlineRuleTestDocument>[
          OnlineRuleTestDocument(
            target: OnlineRuleTarget.search,
            pageUri: Uri.parse('https://source.example.test/search'),
            document:
                '<article class="result"><h2>Missing Detail URI</h2></article>',
          ),
        ],
      ),
    );

    expect(report.isSuccess, isFalse);
    expect(report.validation.isValid, isTrue);
    expect(report.targetReports.single.outcome.failure?.kind,
        OnlineRuleFailureKind.requiredOutputMissing);
    expect(report.targetReports.single.normalizedOutput, isNull);
  });
}

OnlineRuleManifest _manifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('harness-source'),
    displayName: 'Harness Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/harness.json'),
    checksum: 'sha256:harness',
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

OnlineRuleManifest _unsupportedSelectorManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('bad-harness-source'),
    displayName: 'Bad Harness Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/bad-harness.json'),
    checksum: 'sha256:bad-harness',
    updateInterval: const Duration(hours: 12),
    ruleSets: <OnlineRuleSet>[
      OnlineRuleSet(
        target: OnlineRuleTarget.search,
        operations: const <OnlineExtractionOperation>[
          OnlineExtractionOperation(
            id: 'bad-title',
            kind: OnlineExtractionKind.cssSelector,
            expression: '.result > h2',
            outputKey: 'title',
            required: true,
          ),
        ],
      ),
    ],
  );
}

OnlineRuleManifest _normalizationFailureManifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('normalization-failure-source'),
    displayName: 'Normalization Failure Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri:
        Uri.parse('https://rules.example.test/normalization-failure.json'),
    checksum: 'sha256:normalization-failure',
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
        ],
      ),
    ],
  );
}

String _searchDocument(String title) {
  return '<article class="result">'
      '<h2>$title</h2>'
      '<a class="detail-link" href="https://source.example.test/detail">'
      'Detail</a>'
      '</article>';
}

String _detailDocument(String title) {
  return '<html><body><section id="detail">'
      '<h1>$title</h1>'
      '<a href="https://source.example.test/detail">Detail</a>'
      '</section></body></html>';
}
