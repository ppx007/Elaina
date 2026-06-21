import 'runtime_check_base.dart';

final class SeasonalIndexerRuntimeCheck extends BaseRuntimeCheck {
  const SeasonalIndexerRuntimeCheck();

  @override
  String get moduleName => 'seasonal_indexer_runtime';
}

Future<void> main(List<String> args) =>
    const SeasonalIndexerRuntimeCheck().run(args);
