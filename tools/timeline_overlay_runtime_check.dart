import 'runtime_check_base.dart';

final class TimelineOverlayRuntimeCheck extends BaseRuntimeCheck {
  const TimelineOverlayRuntimeCheck();

  @override
  String get moduleName => 'timeline_overlay_runtime';
}

Future<void> main(List<String> args) =>
    const TimelineOverlayRuntimeCheck().run(args);
