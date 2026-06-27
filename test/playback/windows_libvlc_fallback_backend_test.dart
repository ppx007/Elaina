import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolver reports unsupported outside Windows', () {
    final WindowsLibVlcRuntimeResolver resolver =
        WindowsLibVlcRuntimeResolver(isWindows: false);

    final WindowsLibVlcRuntimeProbe probe = resolver.resolve();

    expect(probe.available, isFalse);
    expect(probe.reason, contains('Windows'));
  });

  test('resolver accepts configured VLC runtime directory', () {
    final WindowsLibVlcRuntimeResolver resolver = WindowsLibVlcRuntimeResolver(
      isWindows: true,
      fileExists: (String path) => path == r'D:\VLC\libvlc.dll',
      directoryExists: (String path) =>
          path == r'D:\VLC' || path == r'D:\VLC\plugins',
    );

    final WindowsLibVlcRuntimeProbe probe =
        resolver.resolve(configuredDirectory: r'D:\VLC');

    expect(probe.available, isTrue);
    expect(probe.libVlcPath, r'D:\VLC\libvlc.dll');
    expect(probe.pluginsDirectory, r'D:\VLC\plugins');
  });

  test('backend uses platform bridge for commands and telemetry', () async {
    final _FakeWindowsLibVlcPlatform platform = _FakeWindowsLibVlcPlatform();
    final WindowsLibVlcFallbackBackend backend = WindowsLibVlcFallbackBackend(
      runtimeDirectoryProvider: () async => r'D:\VLC',
      platform: platform,
      resolver: WindowsLibVlcRuntimeResolver(
        isWindows: true,
        fileExists: (String path) => path == r'D:\VLC\libvlc.dll',
        directoryExists: (String path) =>
            path == r'D:\VLC' || path == r'D:\VLC\plugins',
      ),
      now: () => DateTime.utc(2026),
    );

    await backend.refreshCapabilityProbe();
    expect(
      backend.currentCapabilityProbe.capabilities
          .supports(PlaybackCapability.fallbackAdapter),
      isTrue,
    );

    await backend.openLocalFile(Uri.file('D:/media/vlc.mkv'));
    expect(backend.textureId, 71);
    await backend.play();
    await backend.seek(const Duration(seconds: 12));

    expect(platform.calls.map((MapEntry<String, Map<String, Object?>> entry) {
      return entry.key;
    }),
        containsAllInOrder(<String>[
          'probeRuntime',
          'initialize',
          'openLocalFile',
          'telemetry',
          'play',
          'telemetry',
          'seek',
          'telemetry',
        ]));
    expect(backend.currentTelemetry.position, const Duration(seconds: 12));

    await backend.dispose();
  });
}

final class _FakeWindowsLibVlcPlatform implements WindowsLibVlcPlatform {
  final List<MapEntry<String, Map<String, Object?>>> calls =
      <MapEntry<String, Map<String, Object?>>>[];
  int _positionMs = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    calls.add(MapEntry<String, Map<String, Object?>>(method, arguments));
    return switch (method) {
      'probeRuntime' => <String, Object?>{
          'available': true,
          'version': '3.0-test',
        },
      'initialize' => <String, Object?>{'backendId': 7, 'textureId': 71},
      'openLocalFile' => <String, Object?>{'ok': true},
      'play' => <String, Object?>{'ok': true},
      'seek' => _seek(arguments),
      'telemetry' => <String, Object?>{
          'playing': true,
          'completed': false,
          'buffering': false,
          'positionMs': _positionMs,
          'durationMs': 120000,
          'bufferedPositionMs': _positionMs,
        },
      'dispose' => <String, Object?>{'ok': true},
      _ => <String, Object?>{'ok': true},
    };
  }

  Map<String, Object?> _seek(Map<String, Object?> arguments) {
    _positionMs = arguments['positionMs']! as int;
    return <String, Object?>{'ok': true};
  }
}
