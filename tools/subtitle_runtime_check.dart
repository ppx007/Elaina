import 'runtime_check_base.dart';

final class SubtitleRuntimeCheck extends BaseRuntimeCheck {
  const SubtitleRuntimeCheck();

  @override
  String get moduleName => 'subtitle_runtime';
}

Future<void> main(List<String> args) => const SubtitleRuntimeCheck().run(args);
