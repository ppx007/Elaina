import 'runtime_check_base.dart';

final class VideoDetailRuntimeCheck extends BaseRuntimeCheck {
  const VideoDetailRuntimeCheck();

  @override
  String get moduleName => 'video_detail_runtime';
}

Future<void> main(List<String> args) =>
    const VideoDetailRuntimeCheck().run(args);
