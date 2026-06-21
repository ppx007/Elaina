import 'runtime_check_base.dart';

final class MediaLibraryRuntimeCheck extends BaseRuntimeCheck {
  const MediaLibraryRuntimeCheck();

  @override
  String get moduleName => 'media_library_runtime';
}

Future<void> main(List<String> args) =>
    const MediaLibraryRuntimeCheck().run(args);
