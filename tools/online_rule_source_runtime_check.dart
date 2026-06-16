import 'dart:io';

import '../lib/celesteria.dart';

Future<void> main() async {
  final store = DeterministicOnlineRuleRuntimeStore(
    seedManifests: <StoredOnlineRuleManifestRecord>[
      StoredOnlineRuleManifestRecord(
        sourceId: 'source-1',
        displayName: 'Check Source',
        version: '1.0.0',
        updateUri: Uri.parse('https://rules.example.test/manifest.json'),
        checksum: 'sha256:check',
        updateInterval: const Duration(hours: 12),
        validationState: StoredOnlineRuleValidationState.valid,
        createdAt: DateTime.utc(2026, 6, 16),
        updatedAt: DateTime.utc(2026, 6, 16),
      ),
    ],
  );
  final bus = StreamCacheInvalidationBus();
  final bootstrap = OnlineRuleSourceRuntimeBootstrap(
    store: store,
    runtimeByScope: <String, DeterministicOnlineRuleRuntime>{
      'source-1': const DeterministicOnlineRuleRuntime(),
    },
    capabilitiesByScope: <String, OnlineRuleCapabilityMatrix>{
      'source-1': const OnlineRuleCapabilityMatrix(
        capabilities: <OnlineRuleCapability, OnlineRuleCapabilityStatus>{
          OnlineRuleCapability.manifestValidation:
              OnlineRuleCapabilityStatus.supported(),
          OnlineRuleCapability.suppliedDocumentEvaluation:
              OnlineRuleCapabilityStatus.supported(),
          OnlineRuleCapability.gatewayPageRetrieval:
              OnlineRuleCapabilityStatus.unsupported('No gateway.'),
          OnlineRuleCapability.cssSelectorIntent:
              OnlineRuleCapabilityStatus.supported(),
          OnlineRuleCapability.xpath1Intent:
              OnlineRuleCapabilityStatus.supported(),
          OnlineRuleCapability.regexExtraction:
              OnlineRuleCapabilityStatus.supported(),
        },
      ),
    },
    bus: bus,
  );

  final runtime = bootstrap.createRuntime();

  final OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>
      snapshot = await runtime.snapshot('source-1');
  _expect(snapshot.isSuccess, 'Initial snapshot must succeed.');
  final OnlineRuleSourceRuntimeRestartProjection restart =
      snapshot.value!.restart;
  _expect(
      restart.manifestValidationState == StoredOnlineRuleValidationState.valid,
      'Restart projection must show valid state.');

  final validateResult = await runtime.validate(
      'source-1',
      OnlineRuleManifest(
        sourceId: const OnlineRuleSourceId('source-1'),
        displayName: 'Check Source',
        version: const OnlineRuleManifestVersion('1.0.0'),
        updateUri: Uri.parse('https://rules.example.test/manifest.json'),
        checksum: 'sha256:check',
        updateInterval: const Duration(hours: 12),
        ruleSets: <OnlineRuleSet>[
          OnlineRuleSet(
            target: OnlineRuleTarget.search,
            operations: const <OnlineExtractionOperation>[
              OnlineExtractionOperation(
                id: 'title',
                kind: OnlineExtractionKind.regex,
                expression: 'title="([^"]+)"',
                outputKey: 'title',
                required: true,
              ),
              OnlineExtractionOperation(
                id: 'detailUri',
                kind: OnlineExtractionKind.cssSelector,
                expression: '.detail-link',
                outputKey: 'detailUri',
                required: true,
              ),
            ],
          ),
        ],
      ));
  _expect(
      validateResult.isSuccess, 'Validate must succeed for valid manifest.');

  final evalResult = await runtime.evaluate(
      'source-1',
      OnlineRuleEvaluationRequest(
        manifest: OnlineRuleManifest(
          sourceId: const OnlineRuleSourceId('source-1'),
          displayName: 'Check Source',
          version: const OnlineRuleManifestVersion('1.0.0'),
          updateUri: Uri.parse('https://rules.example.test/manifest.json'),
          checksum: 'sha256:check',
          updateInterval: const Duration(hours: 12),
          ruleSets: <OnlineRuleSet>[
            OnlineRuleSet(
              target: OnlineRuleTarget.search,
              operations: const <OnlineExtractionOperation>[
                OnlineExtractionOperation(
                  id: 'title',
                  kind: OnlineExtractionKind.regex,
                  expression: 'title="([^"]+)"',
                  outputKey: 'title',
                  required: true,
                ),
                OnlineExtractionOperation(
                  id: 'detailUri',
                  kind: OnlineExtractionKind.cssSelector,
                  expression: '.detail-link',
                  outputKey: 'detailUri',
                  required: true,
                ),
              ],
            ),
          ],
        ),
        target: OnlineRuleTarget.search,
        pageUri: Uri.parse('https://source.example.test/search'),
        document:
            'title="Check Title" detailUri="https://source.example.test/detail"',
      ));
  _expect(evalResult.isSuccess, 'Evaluate must succeed.');
  _expect(evalResult.value?.latestNormalizedOutput is OnlineRuleSearchOutput,
      'Evaluate must produce search output.');

  final disableResult = await runtime.disable('source-1');
  _expect(disableResult.isSuccess, 'Disable must succeed.');
  _expect(
      disableResult.value?.validationState ==
          StoredOnlineRuleValidationState.disabled,
      'Disable must set state to disabled.');

  final reenableResult = await runtime.reenable('source-1');
  _expect(reenableResult.isSuccess, 'Reenable must succeed.');
  _expect(
      reenableResult.value?.validationState ==
          StoredOnlineRuleValidationState.valid,
      'Reenable must restore to valid.');

  final unsupportedRuntime =
      OnlineRuleSourceRuntime.unavailable(reason: 'No platform');
  _expectFailure((await unsupportedRuntime.snapshot('source-1')).isSuccess,
      'Unavailable snapshot must fail.');
  _expect(
      (await unsupportedRuntime.snapshot('source-1')).failure?.kind ==
          OnlineRuleSourceRuntimeFailureKind.unavailable,
      'Unavailable snapshot must report unavailable failure.');
  _expectFailure(
      (await unsupportedRuntime.validate(
              'source-1',
              OnlineRuleManifest(
                sourceId: const OnlineRuleSourceId('s'),
                displayName: 'X',
                version: const OnlineRuleManifestVersion('1'),
                updateUri: Uri.parse('https://x.test'),
                checksum: 'sha256:x',
                updateInterval: const Duration(hours: 1),
              )))
          .isSuccess,
      'Unavailable validate must fail.');
  _expectFailure(
      (await unsupportedRuntime.evaluate(
              'source-1',
              OnlineRuleEvaluationRequest(
                manifest: OnlineRuleManifest(
                  sourceId: const OnlineRuleSourceId('s'),
                  displayName: 'X',
                  version: const OnlineRuleManifestVersion('1'),
                  updateUri: Uri.parse('https://x.test'),
                  checksum: 'sha256:x',
                  updateInterval: const Duration(hours: 1),
                ),
                target: OnlineRuleTarget.search,
                pageUri: Uri.parse('https://x.test'),
                document: 'x',
              )))
          .isSuccess,
      'Unavailable evaluate must fail.');
  _expectFailure((await unsupportedRuntime.disable('source-1')).isSuccess,
      'Unavailable disable must fail.');
  _expectFailure((await unsupportedRuntime.reenable('source-1')).isSuccess,
      'Unavailable reenable must fail.');

  runtime.dispose();
  _expectFailure((await runtime.snapshot('source-1')).isSuccess,
      'Disposed snapshot must fail.');

  await bus.close();
  stdout.writeln('Online rule source runtime check passed.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectFailure(bool condition, String message) {
  if (condition) throw StateError(message);
}
