import 'runtime_check_base.dart';

final class SubtitleProviderRuntimeCheck extends BaseRuntimeCheck {
  const SubtitleProviderRuntimeCheck();

  @override
  String get moduleName => 'subtitle_provider_runtime';
}

Future<void> main(List<String> args) =>
    const SubtitleProviderRuntimeCheck().run(args);
