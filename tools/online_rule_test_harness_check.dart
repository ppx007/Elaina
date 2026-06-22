// Online rule harness check keeps fixture evaluation available from the CLI.
// Provider/site-specific parser behavior should stay in provider tests.
import 'dart:io';

import '../lib/elaina.dart';

Future<void> main() async {
  const harness = OnlineRuleTestHarness();

  final success = await harness.run(
    OnlineRuleTestPlan(
      manifest: _manifest(),
      documents: <OnlineRuleTestDocument>[
        OnlineRuleTestDocument(
          target: OnlineRuleTarget.search,
          pageUri: Uri.parse('https://source.example.test/search'),
          document: _searchDocument('Harness Check'),
        ),
        OnlineRuleTestDocument(
          target: OnlineRuleTarget.detail,
          pageUri: Uri.parse('https://source.example.test/detail'),
          document: _detailDocument('Harness Detail Check'),
        ),
      ],
    ),
  );
  _expect(success.isSuccess, 'Harness success report must pass.');
  _expect(success.targetReports.length == 2,
      'Harness success report must include both targets.');
  _expect(
      success.targetReports.first.normalizedOutput is OnlineRuleSearchOutput,
      'Harness must expose normalized search output.');
  _expect(success.targetReports.last.normalizedOutput is OnlineRuleDetailOutput,
      'Harness must expose normalized detail output.');

  final invalid = await harness.run(
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
  _expect(!invalid.isSuccess, 'Invalid manifest report must fail.');
  _expect(invalid.targetReports.isEmpty,
      'Invalid manifest report must not evaluate documents.');
  _expect(
      invalid.validation.issues.single.unsupportedKind ==
          UnsupportedOnlineOperationKind.unsupportedSelector,
      'Invalid manifest report must preserve unsupported selector issue.');

  final targetFailure = await harness.run(
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
  _expect(!targetFailure.isSuccess, 'Target failure report must fail.');
  _expect(
      targetFailure.targetReports.single.outcome.failure?.kind ==
          OnlineRuleFailureKind.requiredOutputMissing,
      'Target failure report must preserve typed failure.');

  stdout.writeln('Online rule test harness check passed.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

OnlineRuleManifest _manifest() {
  return OnlineRuleManifest(
    sourceId: const OnlineRuleSourceId('harness-check-source'),
    displayName: 'Harness Check Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/harness-check.json'),
    checksum: 'sha256:harness-check',
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
    sourceId: const OnlineRuleSourceId('bad-harness-check-source'),
    displayName: 'Bad Harness Check Source',
    version: const OnlineRuleManifestVersion('1.0.0'),
    updateUri: Uri.parse('https://rules.example.test/bad-harness-check.json'),
    checksum: 'sha256:bad-harness-check',
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
