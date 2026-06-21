import 'runtime_check_base.dart';

final class AvSyncGuardRuntimeCheck extends BaseRuntimeCheck {
  const AvSyncGuardRuntimeCheck();

  @override
  String get moduleName => 'av_sync_guard_runtime';
}

Future<void> main(List<String> args) =>
    const AvSyncGuardRuntimeCheck().run(args);
