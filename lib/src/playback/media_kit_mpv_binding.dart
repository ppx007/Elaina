import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'capability_matrix.dart';
import 'mpv_adapter_facade.dart';
import 'player_adapter.dart';
import 'track_management.dart';

typedef MediaKitMpvBackendFactory = MediaKitMpvBackend Function();

const String windowsLibMpvFileName = 'libmpv-2.dll';
const String celesteriaLibMpvPathEnvironmentKey = 'CELESTERIA_LIBMPV_PATH';

abstract interface class MediaKitMpvBackend {
  Future<void> openLocalFile(Uri uri);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

final class MediaKitMpvBackendAdapter implements MediaKitMpvBackend {
  MediaKitMpvBackendAdapter({
    Player? player,
    String? libmpvPath,
  }) {
    if (player != null) {
      _player = player;
      return;
    }
    MediaKit.ensureInitialized(
      libmpv: BundledMpvLibraryResolver.resolveWindowsLibMpvPath(
        explicitLibMpvPath: libmpvPath,
      ),
    );
    _player = Player();
  }

  late final Player _player;

  @override
  Future<void> openLocalFile(Uri uri) {
    return _player.open(Media(uri.toString()), play: false);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final class MediaKitMpvBinding implements MpvAdapterBinding {
  MediaKitMpvBinding({
    MediaKitMpvBackend? backend,
    MediaKitMpvBackendFactory? backendFactory,
    String? libmpvPath,
  })  : assert(
          backend == null || backendFactory == null,
          'Provide either a backend instance or a backend factory, not both.',
        ),
        _backend = backend,
        _backendFactory = backendFactory ??
            (() => MediaKitMpvBackendAdapter(libmpvPath: libmpvPath));

  MediaKitMpvBackend? _backend;
  final MediaKitMpvBackendFactory _backendFactory;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.load);
    if (disposed != null) return disposed;
    if (source is! LocalFilePlaybackSource) {
      return _failure(
        operation: PlaybackOperation.load,
        kind: PlaybackFailureKind.unsupported,
        message: 'MediaKit MPV binding supports local file playback only.',
      );
    }

    return _runBackendCommand(
      PlaybackOperation.load,
      (MediaKitMpvBackend backend) => backend.openLocalFile(source.uri),
    );
  }

  @override
  Future<PlaybackCommandResult> play() {
    return _recordCommand(
        PlaybackOperation.play, (MediaKitMpvBackend backend) => backend.play());
  }

  @override
  Future<PlaybackCommandResult> pause() {
    return _recordCommand(PlaybackOperation.pause,
        (MediaKitMpvBackend backend) => backend.pause());
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) async {
    final PlaybackCommandResult? disposed =
        _rejectIfDisposed(PlaybackOperation.seek);
    if (disposed != null) return disposed;
    return _runBackendCommand(
      PlaybackOperation.seek,
      (MediaKitMpvBackend backend) => backend.seek(position),
    );
  }

  @override
  Future<PlaybackCommandResult> stop() {
    return _recordCommand(
        PlaybackOperation.stop, (MediaKitMpvBackend backend) => backend.stop());
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    if (_disposed) return _disposedFailure(PlaybackOperation.dispose);
    final MediaKitMpvBackend? backend = _backend;
    if (backend != null) {
      final PlaybackCommandResult result = await _runBackendCommand(
        PlaybackOperation.dispose,
        (MediaKitMpvBackend backend) => backend.dispose(),
      );
      if (!result.isSuccess) return result;
    }
    _disposed = true;
    return const PlaybackCommandResult.success();
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() async {
    return TrackDiscoveryResult.unsupported(
      reason: 'Track discovery is not implemented by the concrete MPV binding.',
    );
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) async {
    return const TrackSwitchResult.unsupported(
      'Track switching is not implemented by the concrete MPV binding.',
    );
  }

  Future<PlaybackCommandResult> _recordCommand(
    PlaybackOperation operation,
    Future<void> Function(MediaKitMpvBackend backend) command,
  ) async {
    final PlaybackCommandResult? disposed = _rejectIfDisposed(operation);
    if (disposed != null) return disposed;
    return _runBackendCommand(operation, command);
  }

  Future<PlaybackCommandResult> _runBackendCommand(
    PlaybackOperation operation,
    Future<void> Function(MediaKitMpvBackend backend) command,
  ) async {
    try {
      final MediaKitMpvBackend backend = _backend ??= _backendFactory();
      await command(backend);
      return const PlaybackCommandResult.success();
    } catch (error) {
      return _failure(
        operation: operation,
        kind: PlaybackFailureKind.operationFailed,
        message: 'Concrete MPV operation failed: $error',
      );
    }
  }

  PlaybackCommandResult? _rejectIfDisposed(PlaybackOperation operation) {
    if (!_disposed) return null;
    return _disposedFailure(operation);
  }

  PlaybackCommandResult _disposedFailure(PlaybackOperation operation) {
    return _failure(
      operation: operation,
      kind: PlaybackFailureKind.disposed,
      message: 'MediaKit MPV binding has been disposed.',
    );
  }

  PlaybackCommandResult _failure({
    required PlaybackOperation operation,
    required PlaybackFailureKind kind,
    required String message,
  }) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: kind,
        message: message,
      ),
    );
  }
}

final class BundledMpvLibraryResolver {
  const BundledMpvLibraryResolver._();

  static String? resolveWindowsLibMpvPath({
    String? explicitLibMpvPath,
    Map<String, String>? environment,
    String? executablePath,
    bool? isWindows,
    bool Function(String path)? fileExists,
    bool Function(String path)? directoryExists,
  }) {
    final bool runsOnWindows = isWindows ?? Platform.isWindows;
    if (!runsOnWindows) return null;

    final bool Function(String path) doesFileExist =
        fileExists ?? (String path) => File(path).existsSync();
    final bool Function(String path) doesDirectoryExist =
        directoryExists ?? (String path) => Directory(path).existsSync();

    final String? explicit = _resolveCandidate(
      explicitLibMpvPath,
      fileExists: doesFileExist,
      directoryExists: doesDirectoryExist,
    );
    if (explicit != null) return explicit;

    final Map<String, String> env = environment ?? Platform.environment;
    final String? envCandidate = _resolveCandidate(
      env[celesteriaLibMpvPathEnvironmentKey],
      fileExists: doesFileExist,
      directoryExists: doesDirectoryExist,
    );
    if (envCandidate != null) return envCandidate;

    final String resolvedExecutable =
        executablePath ?? Platform.resolvedExecutable;
    final String executableDirectory = _parentPath(resolvedExecutable);
    if (executableDirectory.isEmpty) return null;

    final String bundledCandidate = _joinPath(
      executableDirectory,
      windowsLibMpvFileName,
    );
    if (doesFileExist(bundledCandidate)) return bundledCandidate;

    return null;
  }

  static String? _resolveCandidate(
    String? candidate, {
    required bool Function(String path) fileExists,
    required bool Function(String path) directoryExists,
  }) {
    final String? normalized = _normalizeCandidate(candidate);
    if (normalized == null) return null;
    if (fileExists(normalized)) return normalized;
    if (directoryExists(normalized)) {
      final String dllPath = _joinPath(normalized, windowsLibMpvFileName);
      if (fileExists(dllPath)) return dllPath;
    }
    return null;
  }

  static String? _normalizeCandidate(String? candidate) {
    final String? trimmed = candidate?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _parentPath(String path) {
    final int slash = path.lastIndexOf('/');
    final int backslash = path.lastIndexOf('\\');
    final int index = slash > backslash ? slash : backslash;
    if (index <= 0) return '';
    return path.substring(0, index);
  }

  static String _joinPath(String directory, String fileName) {
    if (directory.endsWith('/') || directory.endsWith('\\')) {
      return '$directory$fileName';
    }
    final String separator = directory.contains('\\') ? '\\' : '/';
    return '$directory$separator$fileName';
  }
}

PlaybackCapabilityMatrix mediaKitLocalFilePlaybackCapabilities() {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
      PlaybackCapability.playPause: CapabilityStatus.supported(),
      PlaybackCapability.seek: CapabilityStatus.supported(),
      PlaybackCapability.stop: CapabilityStatus.supported(),
    },
  );
}
