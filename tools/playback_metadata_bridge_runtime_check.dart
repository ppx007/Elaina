import 'runtime_check_base.dart';

final class PlaybackMetadataBridgeRuntimeCheck extends BaseRuntimeCheck {
  const PlaybackMetadataBridgeRuntimeCheck();

  @override
  String get moduleName => 'acg_data_experience';
}

Future<void> main(List<String> args) =>
    const PlaybackMetadataBridgeRuntimeCheck().run(args);
