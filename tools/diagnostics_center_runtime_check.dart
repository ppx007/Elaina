import 'runtime_check_base.dart';

final class DiagnosticsCenterRuntimeCheck extends BaseRuntimeCheck {
  const DiagnosticsCenterRuntimeCheck();

  @override
  String get moduleName => 'diagnostics_center_runtime';
}

Future<void> main(List<String> args) =>
    const DiagnosticsCenterRuntimeCheck().run(args);
