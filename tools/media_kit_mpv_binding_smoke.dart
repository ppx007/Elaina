import 'dart:async';
import 'dart:io';

import 'package:celesteria/celesteria.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
        'Usage: dart run tools/media_kit_mpv_binding_smoke.dart <local-media-file>');
    exitCode = 64;
    return;
  }

  final File mediaFile = File(args.single).absolute;
  if (!mediaFile.existsSync()) {
    stderr.writeln('Local media file does not exist: ${mediaFile.path}');
    exitCode = 66;
    return;
  }

  final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
    binding: MediaKitMpvBinding(),
    capabilities: mediaKitLocalFilePlaybackCapabilities(),
  );

  try {
    await _expectSuccess(
      'open',
      runtime.controller.open(LocalFilePlaybackSource(uri: mediaFile.uri)),
    );
    await _expectSuccess('play', runtime.controller.play());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _expectSuccess('pause', runtime.controller.pause());
    await _expectSuccess('seek', runtime.controller.seek(Duration.zero));
    await _expectSuccess('stop', runtime.controller.stop());
    stdout.writeln('MediaKit MPV binding smoke passed: ${mediaFile.path}');
  } catch (error) {
    stderr.writeln('MediaKit MPV binding smoke failed: $error');
    exitCode = 1;
  } finally {
    await runtime.dispose();
  }
}

Future<void> _expectSuccess(
  String operation,
  Future<PlaybackCommandResult> command,
) async {
  final PlaybackCommandResult result = await command;
  if (result.isSuccess) return;
  final PlaybackFailure? failure = result.failure;
  throw StateError(
    '$operation failed: ${failure?.kind.name ?? 'unknown'} '
    '${failure?.message ?? 'No failure message.'}',
  );
}
