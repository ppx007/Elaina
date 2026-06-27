import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'capability_matrix.dart';
import 'player_telemetry.dart';
import 'vlc_fallback_adapter.dart';

const String windowsLibVlcFileName = 'libvlc.dll';
const String windowsLibVlcPluginsDirectoryName = 'plugins';
const String elainaVlcPathEnvironmentKey = 'ELAINA_VLC_PATH';
const String windowsLibVlcMethodChannelName = 'elaina/windows_libvlc_fallback';
const Duration windowsLibVlcTelemetryInterval = Duration(milliseconds: 500);

final class WindowsLibVlcRuntimeProbe {
  const WindowsLibVlcRuntimeProbe.available({
    required this.libVlcPath,
    required this.pluginsDirectory,
    this.version,
  })  : available = true,
        reason = null;

  const WindowsLibVlcRuntimeProbe.unavailable(this.reason)
      : available = false,
        libVlcPath = null,
        pluginsDirectory = null,
        version = null;

  final bool available;
  final String? reason;
  final String? libVlcPath;
  final String? pluginsDirectory;
  final String? version;
}

abstract interface class WindowsLibVlcPlatform {
  Future<Map<String, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]);
}

final class MethodChannelWindowsLibVlcPlatform
    implements WindowsLibVlcPlatform {
  MethodChannelWindowsLibVlcPlatform({
    MethodChannel channel = const MethodChannel(windowsLibVlcMethodChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<Map<String, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    final Object? result =
        await _channel.invokeMethod<Object?>(method, arguments);
    if (result is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> entry in result.entries)
          entry.key.toString(): entry.value,
      };
    }
    return const <String, Object?>{};
  }
}

final class WindowsLibVlcRuntimeResolver {
  const WindowsLibVlcRuntimeResolver({
    this.environment,
    this.fileExists,
    this.directoryExists,
    this.isWindows,
  });

  final Map<String, String>? environment;
  final bool Function(String path)? fileExists;
  final bool Function(String path)? directoryExists;
  final bool? isWindows;

  WindowsLibVlcRuntimeProbe resolve({String? configuredDirectory}) {
    final bool runsOnWindows = isWindows ?? Platform.isWindows;
    if (!runsOnWindows) {
      return const WindowsLibVlcRuntimeProbe.unavailable(
        'VLC fallback is only implemented on Windows.',
      );
    }

    final bool Function(String path) doesFileExist =
        fileExists ?? (String path) => File(path).existsSync();
    final bool Function(String path) doesDirectoryExist =
        directoryExists ?? (String path) => Directory(path).existsSync();

    final List<String> candidates = <String>[
      if (_normalize(configuredDirectory) case final String configured)
        configured,
      if (_normalize((environment ??
              Platform.environment)[elainaVlcPathEnvironmentKey])
          case final String envPath)
        envPath,
      ..._commonWindowsVlcDirectories(environment ?? Platform.environment),
    ];

    for (final String candidate in candidates) {
      final WindowsLibVlcRuntimeProbe? resolved = _resolveCandidate(
        candidate,
        fileExists: doesFileExist,
        directoryExists: doesDirectoryExist,
      );
      if (resolved != null) return resolved;
    }

    return const WindowsLibVlcRuntimeProbe.unavailable(
      '未找到 VLC 运行时。请安装 VLC 或在设置页配置包含 libvlc.dll 的目录。',
    );
  }

  WindowsLibVlcRuntimeProbe? _resolveCandidate(
    String candidate, {
    required bool Function(String path) fileExists,
    required bool Function(String path) directoryExists,
  }) {
    final String? directory = _runtimeDirectory(candidate,
        fileExists: fileExists, directoryExists: directoryExists);
    if (directory == null) return null;
    final String libVlcPath = _joinPath(directory, windowsLibVlcFileName);
    final String pluginsDirectory =
        _joinPath(directory, windowsLibVlcPluginsDirectoryName);
    if (!fileExists(libVlcPath)) return null;
    if (!directoryExists(pluginsDirectory)) {
      return WindowsLibVlcRuntimeProbe.unavailable(
        'VLC plugins 目录不存在: $pluginsDirectory',
      );
    }
    return WindowsLibVlcRuntimeProbe.available(
      libVlcPath: libVlcPath,
      pluginsDirectory: pluginsDirectory,
    );
  }

  String? _runtimeDirectory(
    String candidate, {
    required bool Function(String path) fileExists,
    required bool Function(String path) directoryExists,
  }) {
    if (fileExists(candidate) &&
        _fileName(candidate) == windowsLibVlcFileName) {
      return _parentPath(candidate);
    }
    if (directoryExists(candidate)) return candidate;
    return null;
  }

  List<String> _commonWindowsVlcDirectories(Map<String, String> env) {
    return <String>[
      if (_normalize(env['ProgramFiles']) case final String programFiles)
        _joinPath(programFiles, 'VideoLAN\\VLC'),
      if (_normalize(env['ProgramFiles(x86)'])
          case final String programFilesX86)
        _joinPath(programFilesX86, 'VideoLAN\\VLC'),
    ];
  }

  static String? _normalize(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _joinPath(String directory, String fileName) {
    if (directory.endsWith(r'\') || directory.endsWith('/')) {
      return '$directory$fileName';
    }
    return '$directory\\$fileName';
  }

  static String _parentPath(String path) {
    final int slash = path.lastIndexOf('/');
    final int backslash = path.lastIndexOf(r'\');
    final int index = slash > backslash ? slash : backslash;
    if (index <= 0) return '';
    return path.substring(0, index);
  }

  static String _fileName(String path) {
    final int slash = path.lastIndexOf('/');
    final int backslash = path.lastIndexOf(r'\');
    final int index = slash > backslash ? slash : backslash;
    if (index < 0 || index == path.length - 1) return path;
    return path.substring(index + 1);
  }
}

final class WindowsLibVlcFallbackBackend
    implements
        VlcFallbackBackend,
        PlayerTelemetrySource,
        RefreshablePlaybackCapabilityProbeSource {
  WindowsLibVlcFallbackBackend({
    required Future<String?> Function() runtimeDirectoryProvider,
    WindowsLibVlcPlatform? platform,
    WindowsLibVlcRuntimeResolver resolver =
        const WindowsLibVlcRuntimeResolver(),
    DateTime Function()? now,
  })  : _runtimeDirectoryProvider = runtimeDirectoryProvider,
        _platform = platform ?? MethodChannelWindowsLibVlcPlatform(),
        _resolver = resolver,
        _now = now ?? DateTime.now;

  final Future<String?> Function() _runtimeDirectoryProvider;
  final WindowsLibVlcPlatform _platform;
  final WindowsLibVlcRuntimeResolver _resolver;
  final DateTime Function() _now;
  final StreamController<PlayerTelemetrySnapshot> _telemetryController =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);
  PlayerTelemetrySnapshot _currentTelemetry = PlayerTelemetrySnapshot();
  final ValueNotifier<int?> _textureId = ValueNotifier<int?>(null);
  WindowsLibVlcRuntimeProbe _runtimeProbe =
      const WindowsLibVlcRuntimeProbe.unavailable(
    'VLC runtime has not been probed yet.',
  );
  int? _backendId;
  Timer? _telemetryTimer;
  bool _disposed = false;

  @override
  PlayerTelemetrySnapshot get currentTelemetry => _currentTelemetry;

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => _telemetryController.stream;

  ValueListenable<int?> get textureIdListenable => _textureId;

  int? get textureId => _textureId.value;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    final bool available = _runtimeProbe.available;
    return PlaybackCapabilityProbeSnapshot(
      capabilities: vlcFallbackLocalFilePlaybackCapabilities(
        backendAvailable: available,
        telemetryAvailable: available,
      ),
      checkedAt: _now(),
      source: vlcFallbackProbeSource,
      backendLabel: vlcFallbackDisplayName,
      details: <String, String>{
        'backend': vlcFallbackDisplayName,
        'backendAvailable': available.toString(),
        'nativeVlcBridge': available.toString(),
        if (_runtimeProbe.reason != null) 'vlcReason': _runtimeProbe.reason!,
        if (_runtimeProbe.libVlcPath != null)
          'libvlcPath': _runtimeProbe.libVlcPath!,
        if (_runtimeProbe.pluginsDirectory != null)
          'vlcPluginsDirectory': _runtimeProbe.pluginsDirectory!,
        if (_runtimeProbe.version != null)
          'libvlcVersion': _runtimeProbe.version!,
        'videoSurface': available.toString(),
        'anime4kSupported': 'false',
        'anime4kReason': vlcFallbackMpvOnlyEnhancementReason,
        'hdrDebandSupported': 'false',
        'hdrDebandReason': vlcFallbackMpvOnlyEnhancementReason,
        'avSyncSampler': 'false',
        'avSyncSamplerReason': vlcFallbackAvSyncSamplerReason,
      },
    );
  }

  @override
  Future<void> refreshCapabilityProbe() async {
    if (_disposed) return;
    final String? configuredDirectory = await _runtimeDirectoryProvider();
    _runtimeProbe = _resolver.resolve(configuredDirectory: configuredDirectory);
    if (!_runtimeProbe.available) return;
    try {
      final Map<String, Object?> result = await _platform.invoke(
        'probeRuntime',
        <String, Object?>{
          'libvlcPath': _runtimeProbe.libVlcPath,
          'pluginsDirectory': _runtimeProbe.pluginsDirectory,
        },
      );
      final bool bridgeAvailable = result['available'] == true;
      if (!bridgeAvailable) {
        _runtimeProbe = WindowsLibVlcRuntimeProbe.unavailable(
          result['reason']?.toString() ?? 'VLC native bridge is unavailable.',
        );
        return;
      }
      _runtimeProbe = WindowsLibVlcRuntimeProbe.available(
        libVlcPath: _runtimeProbe.libVlcPath!,
        pluginsDirectory: _runtimeProbe.pluginsDirectory!,
        version: result['version']?.toString(),
      );
    } on MissingPluginException {
      _runtimeProbe = const WindowsLibVlcRuntimeProbe.unavailable(
        'Windows VLC native bridge is not registered.',
      );
    } on Object catch (error) {
      _runtimeProbe = WindowsLibVlcRuntimeProbe.unavailable(
        'VLC native bridge probe failed: $error',
      );
    }
  }

  @override
  Future<void> openLocalFile(Uri uri) async {
    final int backendId = await _ensureBackend();
    await _invokeCommand('openLocalFile', <String, Object?>{
      'backendId': backendId,
      'path': uri.isScheme('file') ? uri.toFilePath() : uri.toString(),
    });
    _startTelemetryTimer();
  }

  @override
  Future<void> play() async {
    await _invokeCommand(
        'play', <String, Object?>{'backendId': await _ensureBackend()});
  }

  @override
  Future<void> pause() async {
    await _invokeCommand(
        'pause', <String, Object?>{'backendId': await _ensureBackend()});
  }

  @override
  Future<void> seek(Duration position) async {
    await _invokeCommand('seek', <String, Object?>{
      'backendId': await _ensureBackend(),
      'positionMs': position.inMilliseconds,
    });
  }

  @override
  Future<void> stop() async {
    await _invokeCommand(
        'stop', <String, Object?>{'backendId': await _ensureBackend()});
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _telemetryTimer?.cancel();
    final int? backendId = _backendId;
    if (backendId != null) {
      await _platform
          .invoke('dispose', <String, Object?>{'backendId': backendId});
    }
    _textureId.dispose();
    await _telemetryController.close();
  }

  Future<int> _ensureBackend() async {
    if (_disposed) {
      throw StateError('WindowsLibVlcFallbackBackend has been disposed.');
    }
    final int? existing = _backendId;
    if (existing != null) return existing;
    await refreshCapabilityProbe();
    if (!_runtimeProbe.available) {
      throw StateError(_runtimeProbe.reason ?? 'VLC runtime is unavailable.');
    }
    final Map<String, Object?> result = await _platform.invoke(
      'initialize',
      <String, Object?>{
        'libvlcPath': _runtimeProbe.libVlcPath,
        'pluginsDirectory': _runtimeProbe.pluginsDirectory,
      },
    );
    final Object? id = result['backendId'];
    final Object? textureId = result['textureId'];
    if (id is int && textureId is int) {
      _backendId = id;
      _textureId.value = textureId;
      return id;
    }
    throw StateError(
      'VLC native bridge did not return backend and texture ids.',
    );
  }

  Future<void> _invokeCommand(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      await _platform.invoke(method, arguments);
      await _refreshTelemetry();
    } on Object catch (error) {
      _publishTelemetry(_currentTelemetry.copyWith(
        failureReason: 'VLC command failed: $error',
        observedAt: _now(),
      ));
      rethrow;
    }
  }

  void _startTelemetryTimer() {
    _telemetryTimer ??= Timer.periodic(
      windowsLibVlcTelemetryInterval,
      (_) => unawaited(_refreshTelemetry()),
    );
  }

  Future<void> _refreshTelemetry() async {
    final int? backendId = _backendId;
    if (_disposed || backendId == null) return;
    try {
      final Map<String, Object?> result = await _platform.invoke(
        'telemetry',
        <String, Object?>{'backendId': backendId},
      );
      _publishTelemetry(PlayerTelemetrySnapshot(
        playing: result['playing'] == true,
        completed: result['completed'] == true,
        buffering: result['buffering'] == true,
        position: Duration(milliseconds: _intValue(result['positionMs'])),
        duration: Duration(milliseconds: _intValue(result['durationMs'])),
        bufferedPosition:
            Duration(milliseconds: _intValue(result['bufferedPositionMs'])),
        observedAt: _now(),
        failureReason: result['failureReason']?.toString(),
      ));
    } on Object catch (error) {
      _publishTelemetry(_currentTelemetry.copyWith(
        failureReason: 'VLC telemetry failed: $error',
        observedAt: _now(),
      ));
    }
  }

  void _publishTelemetry(PlayerTelemetrySnapshot telemetry) {
    _currentTelemetry = telemetry;
    if (!_telemetryController.isClosed) {
      _telemetryController.add(telemetry);
    }
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
