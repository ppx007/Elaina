import 'runtime_check_base.dart';

final class NetworkPolicyRuntimeCheck extends BaseRuntimeCheck {
  const NetworkPolicyRuntimeCheck();

  @override
  String get moduleName => 'network_policy_runtime';
}

Future<void> main(List<String> args) =>
    const NetworkPolicyRuntimeCheck().run(args);
