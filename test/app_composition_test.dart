import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:elaina/src/app_composition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

  test('production media-kit surface leaves controls to playback page', () {
    final Video surface =
        buildElainaMediaKitVideoSurface(_FakeVideoController());

    expect(surface.controls, isNull);
    expect(elainaMediaKitVideoControls, isNull);
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

final class _FakeVideoController implements VideoController {
  @override
  ValueNotifier<int?> get id => throw UnimplementedError();

  @override
  ValueNotifier<PlatformVideoController?> get notifier =>
      throw UnimplementedError();

  @override
  Completer<PlatformVideoController> get platform => throw UnimplementedError();

  @override
  Player get player => throw UnimplementedError();

  @override
  ValueNotifier<Rect?> get rect => throw UnimplementedError();

  @override
  Future<void> setSize({int? width, int? height}) {
    throw UnimplementedError();
  }

  @override
  Future<void> get waitUntilFirstFrameRendered => throw UnimplementedError();
}
