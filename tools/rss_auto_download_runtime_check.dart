import 'runtime_check_base.dart';

final class RssAutoDownloadRuntimeCheck extends BaseRuntimeCheck {
  const RssAutoDownloadRuntimeCheck();

  @override
  String get moduleName => 'rss_auto_download_runtime';
}

Future<void> main(List<String> args) =>
    const RssAutoDownloadRuntimeCheck().run(args);
