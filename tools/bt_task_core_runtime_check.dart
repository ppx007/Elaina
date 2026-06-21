import 'runtime_check_base.dart';

final class BtTaskCoreRuntimeCheck extends BaseRuntimeCheck {
  const BtTaskCoreRuntimeCheck();

  @override
  String get moduleName => 'bt_task_core_runtime';
}

Future<void> main(List<String> args) =>
    const BtTaskCoreRuntimeCheck().run(args);
