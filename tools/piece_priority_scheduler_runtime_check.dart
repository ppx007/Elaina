import 'runtime_check_base.dart';

final class PiecePrioritySchedulerRuntimeCheck extends BaseRuntimeCheck {
  const PiecePrioritySchedulerRuntimeCheck();

  @override
  String get moduleName => 'piece_priority_scheduler_runtime';
}

Future<void> main(List<String> args) =>
    const PiecePrioritySchedulerRuntimeCheck().run(args);
