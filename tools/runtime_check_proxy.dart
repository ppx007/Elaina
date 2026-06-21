import 'runtime_check_base.dart';

final class ModuleRuntimeCheck extends BaseRuntimeCheck {
  const ModuleRuntimeCheck(this.moduleName);

  @override
  final String moduleName;
}

Future<void> runModuleRuntimeCheck(
  String moduleName,
  List<String> arguments,
) {
  return ModuleRuntimeCheck(moduleName).run(arguments);
}
