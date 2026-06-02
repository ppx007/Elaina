import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class OnlineRuleSourceId {
  const OnlineRuleSourceId(this.value) : assert(value != '', 'Online rule source id must not be empty.');

  final String value;
}

final class OnlineRuleManifestVersion {
  const OnlineRuleManifestVersion(this.value) : assert(value != '', 'Online rule manifest version must not be empty.');

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
    required this.kind,
    required this.expression,
    required this.outputKey,
    this.attribute,
    this.required = false,
  })  : assert(expression != '', 'Online extraction expression must not be empty.'),
        assert(outputKey != '', 'Online extraction output key must not be empty.');

  final OnlineExtractionKind kind;
  final String expression;
  final String outputKey;
  final String? attribute;
  final bool required;
}

final class OnlineRuleSet {
  OnlineRuleSet({
    required this.target,
    Iterable<OnlineExtractionOperation> operations = const <OnlineExtractionOperation>[],
  }) : operations = List<OnlineExtractionOperation>.unmodifiable(operations);

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
        assert(updateInterval > Duration.zero, 'Online rule update interval must be positive.'),
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
  const OnlineRuleValidationIssue({required this.message, this.unsupportedKind})
      : assert(message != '', 'Online rule validation issue message must not be empty.');

  final String message;
  final UnsupportedOnlineOperationKind? unsupportedKind;
}

final class OnlineRuleValidationResult {
  OnlineRuleValidationResult({Iterable<OnlineRuleValidationIssue> issues = const <OnlineRuleValidationIssue>[]})
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

abstract interface class OnlineRuleRuntime implements GatewayBoundProvider {
  Future<OnlineRuleValidationResult> validateManifest(OnlineRuleManifest manifest);

  Future<AcgProviderResult<OnlineRuleManifest>> refreshManifest(OnlineRuleSourceId sourceId);

  Future<AcgProviderResult<OnlineRuleEvaluationResult>> evaluate(OnlineRuleEvaluationRequest request);
}
