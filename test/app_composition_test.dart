import 'dart:async';
import 'dart:io';

import 'package:elaina/src/app_composition.dart';
import 'package:flutter_test/flutter_test.dart';

const String _externalLaunchTestUri =
    'https://bgm.tv/oauth/authorize?client_id=elaina-test';
const String _detachedProcessExitCodeMessage = 'Process is detached';
const String _detachedProcessStdinMessage =
    'Detached process stdin is unavailable.';
const int _detachedProcessPid = 1017;

void main() {
  test('SystemExternalUriLauncher does not observe detached process exitCode',
      () async {
    final List<_ProcessLaunchCall> calls = <_ProcessLaunchCall>[];
    final SystemExternalUriLauncher launcher = SystemExternalUriLauncher(
      startProcess: (String executable, List<String> arguments) async {
        calls.add(
          _ProcessLaunchCall(
            executable: executable,
            arguments: List<String>.unmodifiable(arguments),
          ),
        );
        return _DetachedProcessSentinel();
      },
    );

    final bool opened = await launcher.open(Uri.parse(_externalLaunchTestUri));

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      expect(opened, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.executable, isNotEmpty);
      expect(calls.single.arguments, contains(_externalLaunchTestUri));
    } else {
      expect(opened, isFalse);
      expect(calls, isEmpty);
    }
  });
}

final class _ProcessLaunchCall {
  const _ProcessLaunchCall({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

final class _DetachedProcessSentinel implements Process {
  @override
  Future<int> get exitCode => throw StateError(_detachedProcessExitCodeMessage);

  @override
  int get pid => _detachedProcessPid;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnsupportedError(_detachedProcessStdinMessage);

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return true;
  }
}
