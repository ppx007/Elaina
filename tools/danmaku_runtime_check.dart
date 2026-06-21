import 'runtime_check_base.dart';

final class DanmakuRuntimeCheck extends BaseRuntimeCheck {
  const DanmakuRuntimeCheck();

  @override
  String get moduleName => 'danmaku_runtime';
}

Future<void> main(List<String> args) => const DanmakuRuntimeCheck().run(args);
