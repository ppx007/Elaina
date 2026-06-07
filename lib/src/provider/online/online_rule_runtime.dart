import '../../foundation/gateway/provider_gateway.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class OnlineRuleSourceId {
  const OnlineRuleSourceId(this.value)
      : assert(value != '', 'Online rule source id must not be empty.');

  final String value;
}

final class OnlineRuleManifestVersion {
  const OnlineRuleManifestVersion(this.value)
      : assert(value != '', 'Online rule manifest version must not be empty.');

  final String value;
}

enum OnlineRuleTarget {
  search,
  detail,
  episode,
  playableSource,
}

enum OnlineExtractionKind {
  cssSelector,
  xpath1,
  regex,
}

enum UnsupportedOnlineOperationKind {
  javascript,
  wasm,
  scriptlet,
  arbitraryCode,
  unsupportedSelector,
  unboundedRegex,
}

final class OnlineExtractionOperation {
  const OnlineExtractionOperation({
    this.id,
    required this.kind,
    required this.expression,
    required this.outputKey,
    this.attribute,
    this.required = false,
  })  : assert(expression != '', 'Online extraction expression must not be empty.'),
        assert(outputKey != '', 'Online extraction output key must not be empty.');

  final String? id;
  final OnlineExtractionKind kind;
  final String expression;
  final String outputKey;
  final String? attribute;
  final bool required;
}

final class OnlineRuleSet {
  OnlineRuleSet({
    this.id,
    required this.target,
    Iterable<OnlineExtractionOperation> operations =
        const <OnlineExtractionOperation>[],
  }) : operations = List<OnlineExtractionOperation>.unmodifiable(operations);

  final String? id;
  final OnlineRuleTarget target;
  final List<OnlineExtractionOperation> operations;
}

final class OnlineRuleManifest {
  OnlineRuleManifest({
    required this.sourceId,
    required this.displayName,
    required this.version,
    required this.updateUri,
    required this.checksum,
    required this.updateInterval,
    Iterable<OnlineRuleSet> ruleSets = const <OnlineRuleSet>[],
  })  : assert(displayName != '', 'Online rule display name must not be empty.'),
        assert(checksum != '', 'Online rule checksum must not be empty.'),
        assert(updateInterval > Duration.zero,
            'Online rule update interval must be positive.'),
        ruleSets = List<OnlineRuleSet>.unmodifiable(ruleSets);

  final OnlineRuleSourceId sourceId;
  final String displayName;
  final OnlineRuleManifestVersion version;
  final Uri updateUri;
  final String checksum;
  final Duration updateInterval;
  final List<OnlineRuleSet> ruleSets;
}

final class OnlineRuleValidationIssue {
  const OnlineRuleValidationIssue({
    required this.message,
    this.unsupportedKind,
    this.operationId,
  })
      : assert(message != '', 'Online rule validation issue message must not be empty.');

  final String message;
  final UnsupportedOnlineOperationKind? unsupportedKind;
  final String? operationId;
}

final class OnlineRuleValidationResult {
  OnlineRuleValidationResult(
      {Iterable<OnlineRuleValidationIssue> issues =
          const <OnlineRuleValidationIssue>[]})
      : issues = List<OnlineRuleValidationIssue>.unmodifiable(issues);

  final List<OnlineRuleValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

final class OnlineRuleEvaluationRequest {
  const OnlineRuleEvaluationRequest({
    required this.manifest,
    required this.target,
    required this.pageUri,
    required this.document,
  }) : assert(document != '', 'Online rule document must not be empty.');

  final OnlineRuleManifest manifest;
  final OnlineRuleTarget target;
  final Uri pageUri;
  final String document;
}

final class OnlineRuleEvaluationResult {
  OnlineRuleEvaluationResult({
    required this.sourceId,
    required this.target,
    Map<String, String> values = const <String, String>{},
    Iterable<OnlineRuleValidationIssue> warnings = const <OnlineRuleValidationIssue>[],
  })  : values = Map<String, String>.unmodifiable(values),
        warnings = List<OnlineRuleValidationIssue>.unmodifiable(warnings);

  final OnlineRuleSourceId sourceId;
  final OnlineRuleTarget target;
  final Map<String, String> values;
  final List<OnlineRuleValidationIssue> warnings;
}

enum OnlineRuleFailureKind {
  manifestInvalid,
  manifestDisabled,
  sourceUnsupported,
  targetMissing,
  requiredOutputMissing,
  unsupportedOperation,
  gatewayUnavailable,
  networkPolicyBlocked,
  evaluationFailed,
}

final class OnlineRuleFailure {
  const OnlineRuleFailure({
    required this.kind,
    required this.message,
    this.sourceId,
    this.target,
    this.operationId,
  }) : assert(message != '', 'Online rule failure message must not be empty.');

  final OnlineRuleFailureKind kind;
  final String message;
  final OnlineRuleSourceId? sourceId;
  final OnlineRuleTarget? target;
  final String? operationId;
}

final class OnlineRuleRegistrationOutcome {
  const OnlineRuleRegistrationOutcome._({this.sourceId, this.failure});

  const OnlineRuleRegistrationOutcome.registered(
      {required OnlineRuleSourceId sourceId})
      : this._(sourceId: sourceId);

  const OnlineRuleRegistrationOutcome.failure(
      {required OnlineRuleFailure failure})
      : this._(failure: failure);

  final OnlineRuleSourceId? sourceId;
  final OnlineRuleFailure? failure;

  bool get isSuccess => failure == null;
}

final class OnlineRuleDisableOutcome {
  const OnlineRuleDisableOutcome._({this.sourceId, this.failure});

  const OnlineRuleDisableOutcome.disabled({required OnlineRuleSourceId sourceId})
      : this._(sourceId: sourceId);

  const OnlineRuleDisableOutcome.failure({required OnlineRuleFailure failure})
      : this._(failure: failure);

  final OnlineRuleSourceId? sourceId;
  final OnlineRuleFailure? failure;

  bool get isSuccess => failure == null;
}

final class OnlineRuleEvaluationOutcome {
  const OnlineRuleEvaluationOutcome._({this.result, this.failure});

  const OnlineRuleEvaluationOutcome.success(
      {required OnlineRuleEvaluationResult result})
      : this._(result: result);

  const OnlineRuleEvaluationOutcome.failure({required OnlineRuleFailure failure})
      : this._(failure: failure);

  final OnlineRuleEvaluationResult? result;
  final OnlineRuleFailure? failure;

  bool get isSuccess => failure == null;
}

enum OnlineRuleCapability {
  manifestValidation,
  suppliedDocumentEvaluation,
  gatewayPageRetrieval,
  cssSelectorIntent,
  xpath1Intent,
  regexExtraction,
}

final class OnlineRuleCapabilityStatus {
  const OnlineRuleCapabilityStatus.supported()
      : supported = true,
        reason = null;

  const OnlineRuleCapabilityStatus.unsupported(this.reason)
      : supported = false;

  final bool supported;
  final String? reason;
}

final class OnlineRuleCapabilityMatrix {
  const OnlineRuleCapabilityMatrix(
      {required Map<OnlineRuleCapability, OnlineRuleCapabilityStatus>
          capabilities})
      : _capabilities = capabilities;

  factory OnlineRuleCapabilityMatrix.unsupported({required String reason}) {
    return OnlineRuleCapabilityMatrix(
      capabilities: <OnlineRuleCapability, OnlineRuleCapabilityStatus>{
        for (final OnlineRuleCapability capability in OnlineRuleCapability.values)
          capability: OnlineRuleCapabilityStatus.unsupported(reason),
      },
    );
  }

  final Map<OnlineRuleCapability, OnlineRuleCapabilityStatus> _capabilities;

  OnlineRuleCapabilityStatus statusOf(OnlineRuleCapability capability) {
    return _capabilities[capability] ??
        const OnlineRuleCapabilityStatus.unsupported(
            'Online rule capability is not declared.');
  }
}

final class OnlineSearchResultRecord {
  const OnlineSearchResultRecord({
    required this.sourceId,
    required this.title,
    required this.detailUri,
    this.coverUri,
    this.summary,
  }) : assert(title != '', 'Online search result title must not be empty.');

  final OnlineRuleSourceId sourceId;
  final String title;
  final Uri detailUri;
  final Uri? coverUri;
  final String? summary;
}

final class OnlineDetailRecord {
  const OnlineDetailRecord({
    required this.sourceId,
    required this.title,
    required this.pageUri,
    this.summary,
    this.coverUri,
  }) : assert(title != '', 'Online detail title must not be empty.');

  final OnlineRuleSourceId sourceId;
  final String title;
  final Uri pageUri;
  final String? summary;
  final Uri? coverUri;
}

final class OnlineEpisodeRecord {
  const OnlineEpisodeRecord({
    required this.sourceId,
    required this.title,
    required this.episodeUri,
    this.episodeNumber,
  }) : assert(title != '', 'Online episode title must not be empty.');

  final OnlineRuleSourceId sourceId;
  final String title;
  final Uri episodeUri;
  final int? episodeNumber;
}

final class OnlinePlayableSourceRecord {
  const OnlinePlayableSourceRecord({
    required this.sourceId,
    required this.label,
    required this.uri,
    this.mimeType,
    this.quality,
  }) : assert(label != '', 'Online playable source label must not be empty.');

  final OnlineRuleSourceId sourceId;
  final String label;
  final Uri uri;
  final String? mimeType;
  final String? quality;
}

sealed class OnlineRuleNormalizedOutput {
  const OnlineRuleNormalizedOutput();
}

final class OnlineRuleSearchOutput extends OnlineRuleNormalizedOutput {
  OnlineRuleSearchOutput({required Iterable<OnlineSearchResultRecord> results})
      : results = List<OnlineSearchResultRecord>.unmodifiable(results);

  final List<OnlineSearchResultRecord> results;
}

final class OnlineRuleDetailOutput extends OnlineRuleNormalizedOutput {
  const OnlineRuleDetailOutput({required this.detail});

  final OnlineDetailRecord detail;
}

final class OnlineRuleEpisodeOutput extends OnlineRuleNormalizedOutput {
  OnlineRuleEpisodeOutput({required Iterable<OnlineEpisodeRecord> episodes})
      : episodes = List<OnlineEpisodeRecord>.unmodifiable(episodes);

  final List<OnlineEpisodeRecord> episodes;
}

final class OnlineRulePlayableSourceOutput extends OnlineRuleNormalizedOutput {
  OnlineRulePlayableSourceOutput(
      {required Iterable<OnlinePlayableSourceRecord> playableSources})
      : playableSources =
            List<OnlinePlayableSourceRecord>.unmodifiable(playableSources);

  final List<OnlinePlayableSourceRecord> playableSources;
}

final class OnlineRulePageRetrievalRequest {
  const OnlineRulePageRetrievalRequest({
    required this.sourceId,
    required this.pageUri,
    required this.cacheKey,
    this.cachePolicy = ProviderCachePolicy.networkOnly,
    this.deduplicationWindow = Duration.zero,
  })  : assert(cacheKey != '', 'Online rule page cache key must not be empty.');

  final OnlineRuleSourceId sourceId;
  final Uri pageUri;
  final String cacheKey;
  final ProviderCachePolicy cachePolicy;
  final Duration deduplicationWindow;
}

enum OnlineRuleNetworkFailureKind {
  disallowedScheme,
  loopbackAddress,
  linkLocalAddress,
  privateNetworkAddress,
  unsafeRedirect,
  blockedHost,
  unsupportedCapability,
}

final class OnlineRuleNetworkPolicyHandoff {
  const OnlineRuleNetworkPolicyHandoff({
    required this.sourceId,
    required this.providerScope,
    required this.uri,
    this.redirectedFrom,
    this.failureKind,
    this.reason,
  })  : assert(providerScope != '', 'Online rule provider scope must not be empty.');

  final OnlineRuleSourceId sourceId;
  final String providerScope;
  final Uri uri;
  final Uri? redirectedFrom;
  final OnlineRuleNetworkFailureKind? failureKind;
  final String? reason;
}

final class OnlineRuleGatewayRequestDescriptor {
  const OnlineRuleGatewayRequestDescriptor({
    required this.sourceId,
    required this.providerId,
    required this.cacheKey,
    required this.pageUri,
    required this.cachePolicy,
    required this.ratePolicy,
    required this.retryPolicy,
    this.negativeCachePolicy,
  })  : assert(cacheKey != '', 'Online rule gateway cache key must not be empty.');

  final OnlineRuleSourceId sourceId;
  final ProviderId providerId;
  final String cacheKey;
  final Uri pageUri;
  final ProviderCachePolicy cachePolicy;
  final ProviderRatePolicy ratePolicy;
  final ProviderRetryPolicy retryPolicy;
  final ProviderNegativeCachePolicy? negativeCachePolicy;

  ProviderRegistration get registration {
    return ProviderRegistration(
      providerId: providerId,
      ratePolicy: ratePolicy,
      retryPolicy: retryPolicy,
      negativeCachePolicy: negativeCachePolicy,
    );
  }

  ProviderRequestKey get requestKey {
    return ProviderRequestKey(providerId: providerId, cacheKey: cacheKey);
  }
}

final class OnlineRulePageRetrievalOutcome {
  const OnlineRulePageRetrievalOutcome._({this.document, this.failure});

  const OnlineRulePageRetrievalOutcome.retrieved({required String document})
      : this._(document: document);

  const OnlineRulePageRetrievalOutcome.failure(
      {required OnlineRuleFailure failure})
      : this._(failure: failure);

  final String? document;
  final OnlineRuleFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class OnlineRuleRuntime implements GatewayBoundProvider {
  Future<OnlineRuleValidationResult> validateManifest(
      OnlineRuleManifest manifest);

  Future<AcgProviderResult<OnlineRuleManifest>> refreshManifest(
      OnlineRuleSourceId sourceId);

  Future<AcgProviderResult<OnlineRuleEvaluationResult>> evaluate(
      OnlineRuleEvaluationRequest request);
}

final class DeterministicOnlineRuleRuntime {
  const DeterministicOnlineRuleRuntime({
    this.enabled = true,
    this.capabilities = _defaultCapabilities,
  });

  final bool enabled;
  final OnlineRuleCapabilityMatrix capabilities;

  Future<OnlineRuleValidationResult> validateManifest(
      OnlineRuleManifest manifest) {
    final List<OnlineRuleValidationIssue> issues = <OnlineRuleValidationIssue>[];
    for (final OnlineRuleSet ruleSet in manifest.ruleSets) {
      for (final OnlineExtractionOperation operation in ruleSet.operations) {
        final UnsupportedOnlineOperationKind? unsupported =
            _unsupportedOperation(operation);
        if (unsupported != null) {
          issues.add(
            OnlineRuleValidationIssue(
              message: 'Unsupported online rule operation: ${unsupported.name}.',
              unsupportedKind: unsupported,
              operationId: operation.id,
            ),
          );
        }
      }
    }
    return Future<OnlineRuleValidationResult>.value(
        OnlineRuleValidationResult(issues: issues));
  }

  Future<OnlineRuleEvaluationOutcome> evaluateTyped(
      OnlineRuleEvaluationRequest request) async {
    if (!enabled) {
      return OnlineRuleEvaluationOutcome.failure(
        failure: OnlineRuleFailure(
          kind: OnlineRuleFailureKind.manifestDisabled,
          message: 'Online rule runtime is disabled.',
          sourceId: request.manifest.sourceId,
          target: request.target,
        ),
      );
    }
    final OnlineRuleValidationResult validation =
        await validateManifest(request.manifest);
    if (!validation.isValid) {
      return OnlineRuleEvaluationOutcome.failure(
        failure: OnlineRuleFailure(
          kind: OnlineRuleFailureKind.manifestInvalid,
          message: validation.issues.first.message,
          sourceId: request.manifest.sourceId,
          target: request.target,
          operationId: validation.issues.first.operationId,
        ),
      );
    }
    final OnlineRuleSet? ruleSet = _ruleSetFor(request.manifest, request.target);
    if (ruleSet == null) {
      return OnlineRuleEvaluationOutcome.failure(
        failure: OnlineRuleFailure(
          kind: OnlineRuleFailureKind.targetMissing,
          message: 'Online rule manifest does not declare target ${request.target.name}.',
          sourceId: request.manifest.sourceId,
          target: request.target,
        ),
      );
    }

    final Map<String, String> values = <String, String>{};
    final List<OnlineRuleValidationIssue> warnings =
        <OnlineRuleValidationIssue>[];
    for (final OnlineExtractionOperation operation in ruleSet.operations) {
      final String? value = _evaluateOperation(operation, request.document);
      if (value == null || value == '') {
        if (operation.required) {
          return OnlineRuleEvaluationOutcome.failure(
            failure: OnlineRuleFailure(
              kind: OnlineRuleFailureKind.requiredOutputMissing,
              message:
                  'Required online rule output ${operation.outputKey} was not produced.',
              sourceId: request.manifest.sourceId,
              target: request.target,
              operationId: operation.id,
            ),
          );
        }
        warnings.add(OnlineRuleValidationIssue(
          message: 'Optional output ${operation.outputKey} was not produced.',
          operationId: operation.id,
        ));
      } else {
        values[operation.outputKey] = value;
      }
    }

    return OnlineRuleEvaluationOutcome.success(
      result: OnlineRuleEvaluationResult(
        sourceId: request.manifest.sourceId,
        target: request.target,
        values: values,
        warnings: warnings,
      ),
    );
  }

  OnlineRuleNormalizedOutput normalize(OnlineRuleEvaluationResult result) {
    return switch (result.target) {
      OnlineRuleTarget.search => OnlineRuleSearchOutput(
          results: <OnlineSearchResultRecord>[
            OnlineSearchResultRecord(
              sourceId: result.sourceId,
              title: _requiredValue(result, 'title'),
              detailUri: Uri.parse(_requiredValue(result, 'detailUri')),
              coverUri: _optionalUri(result.values['coverUri']),
              summary: result.values['summary'],
            ),
          ],
        ),
      OnlineRuleTarget.detail => OnlineRuleDetailOutput(
          detail: OnlineDetailRecord(
            sourceId: result.sourceId,
            title: _requiredValue(result, 'title'),
            pageUri: Uri.parse(_requiredValue(result, 'pageUri')),
            summary: result.values['summary'],
            coverUri: _optionalUri(result.values['coverUri']),
          ),
        ),
      OnlineRuleTarget.episode => OnlineRuleEpisodeOutput(
          episodes: <OnlineEpisodeRecord>[
            OnlineEpisodeRecord(
              sourceId: result.sourceId,
              title: _requiredValue(result, 'title'),
              episodeUri: Uri.parse(_requiredValue(result, 'episodeUri')),
              episodeNumber: int.tryParse(result.values['episodeNumber'] ?? ''),
            ),
          ],
        ),
      OnlineRuleTarget.playableSource => OnlineRulePlayableSourceOutput(
          playableSources: <OnlinePlayableSourceRecord>[
            OnlinePlayableSourceRecord(
              sourceId: result.sourceId,
              label: _requiredValue(result, 'label'),
              uri: Uri.parse(_requiredValue(result, 'uri')),
              mimeType: result.values['mimeType'],
              quality: result.values['quality'],
            ),
          ],
        ),
    };
  }

  OnlineRuleSet? _ruleSetFor(
      OnlineRuleManifest manifest, OnlineRuleTarget target) {
    for (final OnlineRuleSet ruleSet in manifest.ruleSets) {
      if (ruleSet.target == target) {
        return ruleSet;
      }
    }
    return null;
  }

  UnsupportedOnlineOperationKind? _unsupportedOperation(
      OnlineExtractionOperation operation) {
    if (operation.expression.contains('javascript:')) {
      return UnsupportedOnlineOperationKind.javascript;
    }
    if (operation.expression.contains('wasm:')) {
      return UnsupportedOnlineOperationKind.wasm;
    }
    if (operation.expression.contains('scriptlet:')) {
      return UnsupportedOnlineOperationKind.scriptlet;
    }
    if (operation.kind == OnlineExtractionKind.regex &&
        _looksUnboundedRegex(operation.expression)) {
      return UnsupportedOnlineOperationKind.unboundedRegex;
    }
    return null;
  }

  bool _looksUnboundedRegex(String expression) {
    return expression.contains('(.*.*') || expression.contains('(.+)+');
  }

  String? _evaluateOperation(
      OnlineExtractionOperation operation, String document) {
    return switch (operation.kind) {
      OnlineExtractionKind.regex => _evaluateRegex(operation, document),
      OnlineExtractionKind.cssSelector => _evaluateMarker(operation, document),
      OnlineExtractionKind.xpath1 => _evaluateMarker(operation, document),
    };
  }

  String? _evaluateRegex(OnlineExtractionOperation operation, String document) {
    final RegExpMatch? match = RegExp(operation.expression).firstMatch(document);
    if (match == null) {
      return null;
    }
    return match.groupCount >= 1 ? match.group(1) : match.group(0);
  }

  String? _evaluateMarker(OnlineExtractionOperation operation, String document) {
    final RegExp marker = RegExp(
      '${RegExp.escape(operation.outputKey)}\\s*=\\s*"([^"]*)"',
      multiLine: true,
    );
    return marker.firstMatch(document)?.group(1);
  }

  String _requiredValue(OnlineRuleEvaluationResult result, String key) {
    final String? value = result.values[key];
    if (value == null || value == '') {
      throw StateError('Normalized online rule output missing $key.');
    }
    return value;
  }

  Uri? _optionalUri(String? value) {
    if (value == null || value == '') {
      return null;
    }
    return Uri.parse(value);
  }
}

const OnlineRuleCapabilityMatrix _defaultCapabilities =
    OnlineRuleCapabilityMatrix(
  capabilities: <OnlineRuleCapability, OnlineRuleCapabilityStatus>{
    OnlineRuleCapability.manifestValidation:
        OnlineRuleCapabilityStatus.supported(),
    OnlineRuleCapability.suppliedDocumentEvaluation:
        OnlineRuleCapabilityStatus.supported(),
    OnlineRuleCapability.gatewayPageRetrieval:
        OnlineRuleCapabilityStatus.supported(),
    OnlineRuleCapability.cssSelectorIntent:
        OnlineRuleCapabilityStatus.supported(),
    OnlineRuleCapability.xpath1Intent: OnlineRuleCapabilityStatus.supported(),
    OnlineRuleCapability.regexExtraction: OnlineRuleCapabilityStatus.supported(),
  },
);
