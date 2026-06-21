import 'runtime_check_base.dart';

final class RssEngineRuntimeCheck extends BaseRuntimeCheck {
  const RssEngineRuntimeCheck();

  @override
  String get moduleName => 'rss_engine_runtime';
}

Future<void> main(List<String> args) => const RssEngineRuntimeCheck().run(args);
