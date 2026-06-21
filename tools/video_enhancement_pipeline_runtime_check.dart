import 'runtime_check_base.dart';

final class VideoEnhancementPipelineRuntimeCheck extends BaseRuntimeCheck {
  const VideoEnhancementPipelineRuntimeCheck();

  @override
  String get moduleName => 'video_enhancement_pipeline_runtime';
}

Future<void> main(List<String> args) =>
    const VideoEnhancementPipelineRuntimeCheck().run(args);
