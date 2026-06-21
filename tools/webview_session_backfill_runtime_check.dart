import 'runtime_check_base.dart';

final class WebviewSessionBackfillRuntimeCheck extends BaseRuntimeCheck {
  const WebviewSessionBackfillRuntimeCheck();

  @override
  String get moduleName => 'webview_session_backfill_runtime';
}

Future<void> main(List<String> args) =>
    const WebviewSessionBackfillRuntimeCheck().run(args);
