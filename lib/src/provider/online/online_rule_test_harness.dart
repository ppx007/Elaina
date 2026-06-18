import 'online_rule_runtime.dart';

final class OnlineRuleTestDocument {
  const OnlineRuleTestDocument({
    required this.target,
    required this.pageUri,
    required this.document,
  }) : assert(document != '', 'Online rule test document must not be empty.');

  final OnlineRuleTarget target;
  final Uri pageUri;
  final String document;
}

final class OnlineRuleTestPlan {
  OnlineRuleTestPlan({
    required this.manifest,
    Iterable<OnlineRuleTestDocument> documents =
        const <OnlineRuleTestDocument>[],
  }) : documents = List<OnlineRuleTestDocument>.unmodifiable(documents);

  final OnlineRuleManifest manifest;
  final List<OnlineRuleTestDocument> documents;
}

final class OnlineRuleTestTargetReport {
  const OnlineRuleTestTargetReport({
    required this.target,
    required this.pageUri,
    required this.outcome,
    this.normalizedOutput,
  });

  final OnlineRuleTarget target;
  final Uri pageUri;
  final OnlineRuleEvaluationOutcome outcome;
  final OnlineRuleNormalizedOutput? normalizedOutput;

  bool get isSuccess => outcome.isSuccess;
}

final class OnlineRuleTestReport {
  OnlineRuleTestReport({
    required this.manifest,
    required this.validation,
    Iterable<OnlineRuleTestTargetReport> targetReports =
        const <OnlineRuleTestTargetReport>[],
  }) : targetReports =
            List<OnlineRuleTestTargetReport>.unmodifiable(targetReports);

  final OnlineRuleManifest manifest;
  final OnlineRuleValidationResult validation;
  final List<OnlineRuleTestTargetReport> targetReports;

  bool get isSuccess =>
      validation.isValid &&
      targetReports
          .every((OnlineRuleTestTargetReport report) => report.isSuccess);
}

final class OnlineRuleTestHarness {
  const OnlineRuleTestHarness({
    this.runtime = const DeterministicOnlineRuleRuntime(),
  });

  final DeterministicOnlineRuleRuntime runtime;

  Future<OnlineRuleTestReport> run(OnlineRuleTestPlan plan) async {
    final OnlineRuleValidationResult validation =
        await runtime.validateManifest(plan.manifest);
    if (!validation.isValid) {
      return OnlineRuleTestReport(
        manifest: plan.manifest,
        validation: validation,
      );
    }

    final List<OnlineRuleTestTargetReport> targetReports =
        <OnlineRuleTestTargetReport>[];
    for (final OnlineRuleTestDocument document in plan.documents) {
      final OnlineRuleEvaluationOutcome outcome = await runtime.evaluateTyped(
        OnlineRuleEvaluationRequest(
          manifest: plan.manifest,
          target: document.target,
          pageUri: document.pageUri,
          document: document.document,
        ),
      );
      final OnlineRuleNormalizationOutcome? normalization =
          outcome.isSuccess ? runtime.tryNormalize(outcome.result!) : null;
      final OnlineRuleEvaluationOutcome targetOutcome = normalization != null &&
              !normalization.isSuccess
          ? OnlineRuleEvaluationOutcome.failure(failure: normalization.failure!)
          : outcome;
      targetReports.add(
        OnlineRuleTestTargetReport(
          target: document.target,
          pageUri: document.pageUri,
          outcome: targetOutcome,
          normalizedOutput: normalization?.output,
        ),
      );
    }

    return OnlineRuleTestReport(
      manifest: plan.manifest,
      validation: validation,
      targetReports: targetReports,
    );
  }
}
