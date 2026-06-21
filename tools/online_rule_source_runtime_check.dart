import 'runtime_check_base.dart';

final class OnlineRuleSourceRuntimeCheck extends BaseRuntimeCheck {
  const OnlineRuleSourceRuntimeCheck();

  @override
  String get moduleName => 'online_rule_source_runtime';
}

Future<void> main(List<String> args) =>
    const OnlineRuleSourceRuntimeCheck().run(args);
