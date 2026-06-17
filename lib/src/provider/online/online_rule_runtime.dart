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
  })  : assert(expression != '',
            'Online extraction expression must not be empty.'),
        assert(
            outputKey != '', 'Online extraction output key must not be empty.');

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
  })  : assert(
            displayName != '', 'Online rule display name must not be empty.'),
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
  }) : assert(message != '',
            'Online rule validation issue message must not be empty.');

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
    Iterable<OnlineRuleValidationIssue> warnings =
        const <OnlineRuleValidationIssue>[],
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

  const OnlineRuleDisableOutcome.disabled(
      {required OnlineRuleSourceId sourceId})
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

  const OnlineRuleEvaluationOutcome.failure(
      {required OnlineRuleFailure failure})
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

  const OnlineRuleCapabilityStatus.unsupported(this.reason) : supported = false;

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
        for (final OnlineRuleCapability capability
            in OnlineRuleCapability.values)
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
  }) : assert(cacheKey != '', 'Online rule page cache key must not be empty.');

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
  }) : assert(providerScope != '',
            'Online rule provider scope must not be empty.');

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
  }) : assert(
            cacheKey != '', 'Online rule gateway cache key must not be empty.');

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
  static const _OnlineRuleDocumentEvaluator _documentEvaluator =
      _OnlineRuleDocumentEvaluator();

  Future<OnlineRuleValidationResult> validateManifest(
      OnlineRuleManifest manifest) {
    final List<OnlineRuleValidationIssue> issues =
        <OnlineRuleValidationIssue>[];
    for (final OnlineRuleSet ruleSet in manifest.ruleSets) {
      for (final OnlineExtractionOperation operation in ruleSet.operations) {
        final UnsupportedOnlineOperationKind? unsupported =
            _unsupportedOperation(operation);
        if (unsupported != null) {
          issues.add(
            OnlineRuleValidationIssue(
              message:
                  'Unsupported online rule operation: ${unsupported.name}.',
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
    final OnlineRuleSet? ruleSet =
        _ruleSetFor(request.manifest, request.target);
    if (ruleSet == null) {
      return OnlineRuleEvaluationOutcome.failure(
        failure: OnlineRuleFailure(
          kind: OnlineRuleFailureKind.targetMissing,
          message:
              'Online rule manifest does not declare target ${request.target.name}.',
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
    final String normalizedExpression = operation.expression.toLowerCase();
    if (normalizedExpression.contains(_javascriptOperationPrefix)) {
      return UnsupportedOnlineOperationKind.javascript;
    }
    if (normalizedExpression.contains(_wasmOperationPrefix)) {
      return UnsupportedOnlineOperationKind.wasm;
    }
    if (normalizedExpression.contains(_scriptletOperationPrefix)) {
      return UnsupportedOnlineOperationKind.scriptlet;
    }
    if (normalizedExpression.contains(_arbitraryCodeOperationPrefix)) {
      return UnsupportedOnlineOperationKind.arbitraryCode;
    }
    if (operation.kind == OnlineExtractionKind.regex &&
        _looksUnboundedRegex(operation.expression)) {
      return UnsupportedOnlineOperationKind.unboundedRegex;
    }
    if (!_documentEvaluator.supports(operation)) {
      return UnsupportedOnlineOperationKind.unsupportedSelector;
    }
    return null;
  }

  bool _looksUnboundedRegex(String expression) {
    return expression.contains('(.*.*') || expression.contains('(.+)+');
  }

  String? _evaluateOperation(
      OnlineExtractionOperation operation, String document) {
    return _documentEvaluator.evaluate(operation, document);
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
    OnlineRuleCapability.regexExtraction:
        OnlineRuleCapabilityStatus.supported(),
  },
);

const String _javascriptOperationPrefix = 'javascript:';
const String _wasmOperationPrefix = 'wasm:';
const String _scriptletOperationPrefix = 'scriptlet:';
const String _arbitraryCodeOperationPrefix = 'code:';
const String _classAttributeName = 'class';
const String _idAttributeName = 'id';

final RegExp _htmlTagPattern = RegExp(
  r'<\s*(/)?\s*([A-Za-z][A-Za-z0-9_-]*)\b([^>]*)>',
  multiLine: true,
);
final RegExp _htmlAttributePattern = RegExp(
  r'''([A-Za-z_][A-Za-z0-9_-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
);
final RegExp _documentWhitespacePattern = RegExp(r'\s+');
final RegExp _cssUnsupportedCombinatorPattern = RegExp(r'[,>+~]');
final RegExp _cssTokenPattern = RegExp(
  r'''^(\*|[A-Za-z][A-Za-z0-9_-]*)?((?:[#.][A-Za-z_][A-Za-z0-9_-]*|\[[A-Za-z_][A-Za-z0-9_-]*(?:=(?:"[^"]*"|'[^']*'|[^\]]+))?\])*)$''',
);
final RegExp _cssSegmentPattern = RegExp(
  r'''([#.])([A-Za-z_][A-Za-z0-9_-]*)|\[([A-Za-z_][A-Za-z0-9_-]*)(?:=(?:"([^"]*)"|'([^']*)'|([^\]]+)))?\]''',
);
final RegExp _xpathStepPattern = RegExp(
  r'''^(\*|[A-Za-z][A-Za-z0-9_-]*)(?:\[@([A-Za-z_][A-Za-z0-9_-]*)=(?:"([^"]*)"|'([^']*)')\])?$''',
);

final class _OnlineRuleDocumentEvaluator {
  const _OnlineRuleDocumentEvaluator();

  bool supports(OnlineExtractionOperation operation) {
    return switch (operation.kind) {
      OnlineExtractionKind.regex => _supportsRegex(operation.expression),
      OnlineExtractionKind.cssSelector =>
        _CssSelector.tryParse(operation.expression) != null,
      OnlineExtractionKind.xpath1 =>
        _XPathSelector.tryParse(operation.expression) != null,
    };
  }

  String? evaluate(OnlineExtractionOperation operation, String document) {
    return switch (operation.kind) {
      OnlineExtractionKind.regex => _evaluateRegex(operation, document),
      OnlineExtractionKind.cssSelector => _evaluateCss(operation, document),
      OnlineExtractionKind.xpath1 => _evaluateXPath(operation, document),
    };
  }

  bool _supportsRegex(String expression) {
    try {
      RegExp(expression);
      return true;
    } on FormatException {
      return false;
    }
  }

  String? _evaluateRegex(OnlineExtractionOperation operation, String document) {
    final RegExpMatch? match =
        RegExp(operation.expression).firstMatch(document);
    if (match == null) {
      return null;
    }
    return match.groupCount >= 1 ? match.group(1) : match.group(0);
  }

  String? _evaluateCss(OnlineExtractionOperation operation, String document) {
    final _CssSelector? selector = _CssSelector.tryParse(operation.expression);
    if (selector == null) {
      return null;
    }
    for (final _OnlineRuleElement element
        in _OnlineRuleDocument.parse(document).elements) {
      if (selector.matches(element)) {
        return _valueFromElement(element, operation.attribute);
      }
    }
    return null;
  }

  String? _evaluateXPath(OnlineExtractionOperation operation, String document) {
    final _XPathSelector? selector =
        _XPathSelector.tryParse(operation.expression);
    if (selector == null) {
      return null;
    }
    for (final _OnlineRuleElement element
        in _OnlineRuleDocument.parse(document).elements) {
      if (selector.matches(element)) {
        return _valueFromElement(element, operation.attribute);
      }
    }
    return null;
  }

  String? _valueFromElement(_OnlineRuleElement element, String? attribute) {
    if (attribute != null && attribute != '') {
      return element.attributes[attribute];
    }
    final String text = element.normalizedText;
    return text == '' ? null : text;
  }
}

final class _OnlineRuleDocument {
  _OnlineRuleDocument._(this.elements);

  final List<_OnlineRuleElement> elements;

  factory _OnlineRuleDocument.parse(String document) {
    final List<_OnlineRuleElement> elements = <_OnlineRuleElement>[];
    final List<_OnlineRuleElement> stack = <_OnlineRuleElement>[];
    int cursor = 0;

    for (final RegExpMatch match in _htmlTagPattern.allMatches(document)) {
      _appendText(stack, document.substring(cursor, match.start));
      cursor = match.end;

      final bool closing = match.group(1) != null;
      final String tag = match.group(2)!.toLowerCase();
      final String rawAttributes = match.group(3) ?? '';
      final bool selfClosing = rawAttributes.trimRight().endsWith('/');

      if (closing) {
        _popUntil(stack, tag);
        continue;
      }

      final _OnlineRuleElement element = _OnlineRuleElement(
        tag: tag,
        attributes: _parseAttributes(rawAttributes),
        parent: stack.isEmpty ? null : stack.last,
      );
      elements.add(element);
      if (!selfClosing) {
        stack.add(element);
      }
    }

    _appendText(stack, document.substring(cursor));
    return _OnlineRuleDocument._(
        List<_OnlineRuleElement>.unmodifiable(elements));
  }

  static Map<String, String> _parseAttributes(String rawAttributes) {
    final Map<String, String> attributes = <String, String>{};
    for (final RegExpMatch match
        in _htmlAttributePattern.allMatches(rawAttributes)) {
      final String name = match.group(1)!.toLowerCase();
      final String value =
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes[name] = value;
    }
    return Map<String, String>.unmodifiable(attributes);
  }

  static void _appendText(List<_OnlineRuleElement> stack, String text) {
    if (text == '') {
      return;
    }
    for (final _OnlineRuleElement element in stack) {
      element.appendText(text);
    }
  }

  static void _popUntil(List<_OnlineRuleElement> stack, String tag) {
    while (stack.isNotEmpty) {
      final _OnlineRuleElement element = stack.removeLast();
      if (element.tag == tag) {
        return;
      }
    }
  }
}

final class _OnlineRuleElement {
  _OnlineRuleElement({
    required this.tag,
    required this.attributes,
    required this.parent,
  });

  final String tag;
  final Map<String, String> attributes;
  final _OnlineRuleElement? parent;
  final StringBuffer _text = StringBuffer();

  String get normalizedText =>
      _text.toString().replaceAll(_documentWhitespacePattern, ' ').trim();

  void appendText(String text) {
    _text.write(text);
  }

  bool hasClass(String className) {
    final String? value = attributes[_classAttributeName];
    if (value == null) {
      return false;
    }
    return value.split(_documentWhitespacePattern).contains(className);
  }
}

final class _CssSelector {
  _CssSelector._(this.parts);

  final List<_CssSelectorPart> parts;

  static _CssSelector? tryParse(String expression) {
    final String trimmed = expression.trim();
    if (trimmed == '' || _cssUnsupportedCombinatorPattern.hasMatch(trimmed)) {
      return null;
    }

    final List<_CssSelectorPart> parts = <_CssSelectorPart>[];
    for (final String token in trimmed.split(_documentWhitespacePattern)) {
      final _CssSelectorPart? part = _CssSelectorPart.tryParse(token);
      if (part == null) {
        return null;
      }
      parts.add(part);
    }
    return _CssSelector._(List<_CssSelectorPart>.unmodifiable(parts));
  }

  bool matches(_OnlineRuleElement element) {
    return _matchesPartFrom(element, parts.length - 1);
  }

  bool _matchesPartFrom(_OnlineRuleElement? element, int partIndex) {
    if (element == null) {
      return false;
    }
    if (!parts[partIndex].matches(element)) {
      return false;
    }
    if (partIndex == 0) {
      return true;
    }
    _OnlineRuleElement? ancestor = element.parent;
    while (ancestor != null) {
      if (_matchesPartFrom(ancestor, partIndex - 1)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }
}

final class _CssSelectorPart {
  _CssSelectorPart({
    this.tag,
    this.id,
    Iterable<String> classes = const <String>[],
    Map<String, String?> attributes = const <String, String?>{},
  })  : classes = List<String>.unmodifiable(classes),
        attributes = Map<String, String?>.unmodifiable(attributes);

  final String? tag;
  final String? id;
  final List<String> classes;
  final Map<String, String?> attributes;

  static _CssSelectorPart? tryParse(String token) {
    final RegExpMatch? tokenMatch = _cssTokenPattern.firstMatch(token);
    if (tokenMatch == null) {
      return null;
    }

    final String? rawTag = tokenMatch.group(1);
    final String? tag = rawTag == '*' ? null : rawTag?.toLowerCase();
    final String tail = tokenMatch.group(2) ?? '';
    final List<String> classes = <String>[];
    final Map<String, String?> attributes = <String, String?>{};
    String? id;
    int cursor = 0;

    for (final RegExpMatch segment in _cssSegmentPattern.allMatches(tail)) {
      if (segment.start != cursor) {
        return null;
      }
      cursor = segment.end;

      final String? prefix = segment.group(1);
      if (prefix == '#') {
        id = segment.group(2);
      } else if (prefix == '.') {
        classes.add(segment.group(2)!);
      } else {
        final String name = segment.group(3)!.toLowerCase();
        final String? value =
            segment.group(4) ?? segment.group(5) ?? segment.group(6)?.trim();
        attributes[name] = value;
      }
    }

    if (cursor != tail.length) {
      return null;
    }

    return _CssSelectorPart(
      tag: tag,
      id: id,
      classes: classes,
      attributes: attributes,
    );
  }

  bool matches(_OnlineRuleElement element) {
    if (tag != null && element.tag != tag) {
      return false;
    }
    if (id != null && element.attributes[_idAttributeName] != id) {
      return false;
    }
    for (final String className in classes) {
      if (!element.hasClass(className)) {
        return false;
      }
    }
    for (final MapEntry<String, String?> attribute in attributes.entries) {
      final String? elementValue = element.attributes[attribute.key];
      if (elementValue == null) {
        return false;
      }
      if (attribute.value != null && elementValue != attribute.value) {
        return false;
      }
    }
    return true;
  }
}

final class _XPathSelector {
  _XPathSelector._({
    required this.descendantSearch,
    required this.steps,
  });

  final bool descendantSearch;
  final List<_XPathStep> steps;

  static _XPathSelector? tryParse(String expression) {
    final String trimmed = expression.trim();
    final bool descendantSearch;
    final String path;
    if (trimmed.startsWith('//')) {
      descendantSearch = true;
      path = trimmed.substring(2);
    } else if (trimmed.startsWith('/')) {
      descendantSearch = false;
      path = trimmed.substring(1);
    } else {
      return null;
    }
    if (path == '' || path.contains('//')) {
      return null;
    }

    final List<_XPathStep> steps = <_XPathStep>[];
    for (final String token in path.split('/')) {
      final _XPathStep? step = _XPathStep.tryParse(token);
      if (step == null) {
        return null;
      }
      steps.add(step);
    }
    return _XPathSelector._(
      descendantSearch: descendantSearch,
      steps: List<_XPathStep>.unmodifiable(steps),
    );
  }

  bool matches(_OnlineRuleElement element) {
    if (!_matchesEndingAt(element, steps.length - 1)) {
      return false;
    }
    if (descendantSearch) {
      return true;
    }

    _OnlineRuleElement? cursor = element;
    for (int i = steps.length - 1; i >= 0; i--) {
      cursor = cursor?.parent;
    }
    return cursor == null;
  }

  bool _matchesEndingAt(_OnlineRuleElement? element, int stepIndex) {
    if (element == null) {
      return false;
    }
    if (!steps[stepIndex].matches(element)) {
      return false;
    }
    if (stepIndex == 0) {
      return true;
    }
    return _matchesEndingAt(element.parent, stepIndex - 1);
  }
}

final class _XPathStep {
  const _XPathStep({
    this.tag,
    this.attributeName,
    this.attributeValue,
  });

  final String? tag;
  final String? attributeName;
  final String? attributeValue;

  static _XPathStep? tryParse(String token) {
    final RegExpMatch? match = _xpathStepPattern.firstMatch(token);
    if (match == null) {
      return null;
    }
    final String rawTag = match.group(1)!;
    return _XPathStep(
      tag: rawTag == '*' ? null : rawTag.toLowerCase(),
      attributeName: match.group(2)?.toLowerCase(),
      attributeValue: match.group(3) ?? match.group(4),
    );
  }

  bool matches(_OnlineRuleElement element) {
    if (tag != null && element.tag != tag) {
      return false;
    }
    if (attributeName == null) {
      return true;
    }
    return element.attributes[attributeName] == attributeValue;
  }
}
