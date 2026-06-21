import 'runtime_check_base.dart';

final class BangumiRuntimeCheck extends BaseRuntimeCheck {
  const BangumiRuntimeCheck();

  @override
  String get moduleName => 'bangumi_runtime';
}

Future<void> main(List<String> args) => const BangumiRuntimeCheck().run(args);
