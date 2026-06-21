import 'runtime_check_base.dart';

final class DandanplayRuntimeCheck extends BaseRuntimeCheck {
  const DandanplayRuntimeCheck();

  @override
  String get moduleName => 'dandanplay_runtime';
}

Future<void> main(List<String> args) =>
    const DandanplayRuntimeCheck().run(args);
