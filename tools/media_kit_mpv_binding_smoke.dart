import 'dart:async';
import 'dart:io';

import 'package:celesteria/celesteria.dart';

Future<void> main(List<String> args) async {
  final _SmokeArguments? parsed = _SmokeArguments.parse(args);
  if (parsed == null) {
    stderr.writeln(
      'Usage: dart run tools/media_kit_mpv_binding_smoke.dart '
      '[--libmpv <libmpv-2.dll-or-directory>] <local-media-file>',
    );
    exitCode = 64;
    return;
  }

  final File mediaFile = File(parsed.mediaPath).absolute;
  if (!mediaFile.existsSync()) {
    stderr.writeln('Local media file does not exist: ${mediaFile.path}');
    exitCode = 66;
    return;
  }

  final PlayerCoreRuntime runtime = PlayerCoreRuntime.bound(
    binding: MediaKitMpvBinding(libmpvPath: parsed.libmpvPath),
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

final class _SmokeArguments {
  const _SmokeArguments({
    required this.mediaPath,
    this.libmpvPath,
  });

  final String mediaPath;
  final String? libmpvPath;

  static _SmokeArguments? parse(List<String> args) {
    String? libmpvPath;
    final List<String> positional = <String>[];
    for (int index = 0; index < args.length; index += 1) {
      final String arg = args[index];
      if (arg == '--libmpv') {
        index += 1;
        if (index >= args.length) return null;
        libmpvPath = args[index];
        continue;
      }
      positional.add(arg);
    }
    if (positional.length != 1) return null;
    return _SmokeArguments(
      mediaPath: positional.single,
      libmpvPath: libmpvPath,
    );
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
