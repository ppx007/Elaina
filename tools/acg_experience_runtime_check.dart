import 'runtime_check_base.dart';

final class AcgExperienceRuntimeCheck extends BaseRuntimeCheck {
  const AcgExperienceRuntimeCheck();

  @override
  String get moduleName => 'acg_data_experience';
}

Future<void> main(List<String> args) =>
    const AcgExperienceRuntimeCheck().run(args);
