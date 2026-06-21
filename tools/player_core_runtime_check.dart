import 'runtime_check_base.dart';

final class PlayerCoreRuntimeCheck extends BaseRuntimeCheck {
  const PlayerCoreRuntimeCheck();

  @override
  String get moduleName => 'player_core';
}

Future<void> main(List<String> args) =>
    const PlayerCoreRuntimeCheck().run(args);
