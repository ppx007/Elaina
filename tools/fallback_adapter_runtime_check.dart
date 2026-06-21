import 'runtime_check_base.dart';

final class FallbackAdapterRuntimeCheck extends BaseRuntimeCheck {
  const FallbackAdapterRuntimeCheck();

  @override
  String get moduleName => 'fallback_adapter_runtime';
}

Future<void> main(List<String> args) =>
    const FallbackAdapterRuntimeCheck().run(args);
