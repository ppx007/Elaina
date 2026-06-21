import 'runtime_check_base.dart';

final class VirtualMediaStreamRuntimeCheck extends BaseRuntimeCheck {
  const VirtualMediaStreamRuntimeCheck();

  @override
  String get moduleName => 'virtual_media_stream_runtime';
}

Future<void> main(List<String> args) =>
    const VirtualMediaStreamRuntimeCheck().run(args);
