import 'runtime_check_base.dart';

final class AdvancedCaptionRenderingRuntimeCheck extends BaseRuntimeCheck {
  const AdvancedCaptionRenderingRuntimeCheck();

  @override
  String get moduleName => 'advanced_caption_rendering_runtime';
}

Future<void> main(List<String> args) =>
    const AdvancedCaptionRenderingRuntimeCheck().run(args);
