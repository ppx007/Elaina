import 'dart:async';

import '../../playback/capability_matrix.dart';
import '../../playback/player_adapter.dart';
import '../../playback/player_telemetry.dart';
import '../../playback/track_management.dart';
import '../../playback/video_enhancement_pipeline.dart';
import '../../playback/vlc_fallback_adapter.dart';
import '../settings/settings_domain.dart';

const String playbackBackendMediaKitMpvId = 'media-kit-mpv';
const String playbackBackendVlcFallbackId = vlcFallbackAdapterId;
const String playbackBackendSelectionProbeSource = 'playback-backend-selection';
const String playbackBackendSelectionDefaultFallbackScope = 'default';

enum PlaybackBackendMode {
  mediaKitMpv,
  autoFallback,
  vlcFallback,
}

abstract final class PlaybackBackendModeSettings {
  static const String mediaKitMpv = 'mediaKitMpv';
  static const String autoFallback = 'autoFallback';
  static const String vlcFallback = 'vlcFallback';

  static const List<String> values = <String>[
    mediaKitMpv,
    autoFallback,
    vlcFallback,
  ];

  static PlaybackBackendMode parse(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return PlaybackBackendMode.mediaKitMpv;
    return switch (normalized) {
      mediaKitMpv => PlaybackBackendMode.mediaKitMpv,
      autoFallback => PlaybackBackendMode.autoFallback,
      vlcFallback => PlaybackBackendMode.vlcFallback,
      _ => throw FormatException('Invalid playback backend mode: $value'),
    };
  }

  static String serialize(PlaybackBackendMode mode) {
    return switch (mode) {
      PlaybackBackendMode.mediaKitMpv => mediaKitMpv,
      PlaybackBackendMode.autoFallback => autoFallback,
      PlaybackBackendMode.vlcFallback => vlcFallback,
    };
  }

  static String label(PlaybackBackendMode mode) {
    return switch (mode) {
      PlaybackBackendMode.mediaKitMpv => 'MPV',
      PlaybackBackendMode.autoFallback => '自动备用',
      PlaybackBackendMode.vlcFallback => 'VLC',
    };
  }
}

final class PlaybackBackendCandidateSnapshot {
  PlaybackBackendCandidateSnapshot({
    required this.id,
    required this.label,
    required this.available,
    required this.capabilities,
    required this.checkedAt,
    this.reason,
    Map<String, String> details = const <String, String>{},
  }) : details = Map<String, String>.unmodifiable(details);

  final String id;
  final String label;
  final bool available;
  final String? reason;
  final PlaybackCapabilityMatrix capabilities;
  final DateTime checkedAt;
  final Map<String, String> details;

  List<String> keyLimitationReasonLines() {
    final List<String> lines = <String>[];
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.videoEnhancement,
      '视频增强',
    );
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.hdrToneMapping,
      'HDR tone mapping',
    );
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.debandFiltering,
      'Deband',
    );
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.anime4kPreset,
      'Anime4K 预设',
    );
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.avSyncGuard,
      '音画同步守卫',
    );
    _appendUnsupportedCapability(
      lines,
      PlaybackCapability.matrixDanmaku,
      '矩阵弹幕',
    );
    return lines;
  }

  void _appendUnsupportedCapability(
    List<String> lines,
    PlaybackCapability capability,
    String label,
  ) {
    final CapabilityStatus status = capabilities.statusOf(capability);
    if (status.isSupported) return;
    lines.add('$label: ${status.reason ?? '不支持'}');
  }
}

final class PlaybackBackendSelectionSnapshot {
  PlaybackBackendSelectionSnapshot({
    required this.configuredMode,
    required this.activeBackendId,
    required this.activeBackendLabel,
    required this.candidates,
    required this.checkedAt,
    Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities =
        const <PlaybackCapability, CapabilityStatus>{},
    this.latestFallbackReason,
    this.latestFailureReason,
    this.lastSwitchedAt,
  }) : hiddenCapabilities =
            Map<PlaybackCapability, CapabilityStatus>.unmodifiable(
          hiddenCapabilities,
        );

  final PlaybackBackendMode configuredMode;
  final String activeBackendId;
  final String activeBackendLabel;
  final List<PlaybackBackendCandidateSnapshot> candidates;
  final Map<PlaybackCapability, CapabilityStatus> hiddenCapabilities;
  final String? latestFallbackReason;
  final String? latestFailureReason;
  final DateTime? lastSwitchedAt;
  final DateTime checkedAt;

  PlaybackBackendCandidateSnapshot? candidateById(String id) {
    for (final PlaybackBackendCandidateSnapshot candidate in candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  List<String> hiddenCapabilityReasonLines() {
    return <String>[
      for (final MapEntry<PlaybackCapability, CapabilityStatus> entry
          in hiddenCapabilities.entries)
        '${entry.key.name}: ${entry.value.reason ?? '不支持'}',
    ];
  }
}

enum PlaybackBackendSwitchResultKind {
  applied,
  failed,
}

final class PlaybackBackendSwitchResult {
  const PlaybackBackendSwitchResult._({
    required this.kind,
    required this.mode,
    this.message,
  });

  const PlaybackBackendSwitchResult.applied(PlaybackBackendMode mode)
      : this._(kind: PlaybackBackendSwitchResultKind.applied, mode: mode);

  const PlaybackBackendSwitchResult.failed({
    required PlaybackBackendMode mode,
    required String message,
  }) : this._(
          kind: PlaybackBackendSwitchResultKind.failed,
          mode: mode,
          message: message,
        );

  final PlaybackBackendSwitchResultKind kind;
  final PlaybackBackendMode mode;
  final String? message;

  bool get isSuccess => kind == PlaybackBackendSwitchResultKind.applied;
}

/// Selects the executable playback backend while preserving PlayerAdapter.
///
/// The controller and UI still speak to a single adapter. This runtime owns the
/// downgrade boundary so automatic fallback can record exactly which MPV-only
/// features were hidden when VLC takes over a source.
final class PlaybackBackendSelectionRuntime
    implements
        PlayerAdapter,
        PlayerTelemetrySource,
        PlaybackCapabilityProbeSource {
  PlaybackBackendSelectionRuntime({
    required SettingsRuntime settingsRuntime,
    required PlayerAdapter mediaKitMpvAdapter,
    required PlaybackCapabilityProbeSource mediaKitMpvProbeSource,
    PlayerTelemetrySource? mediaKitMpvTelemetrySource,
    required PlayerAdapter vlcFallbackAdapter,
    required PlaybackCapabilityProbeSource vlcFallbackProbeSource,
    PlayerTelemetrySource? vlcFallbackTelemetrySource,
    DateTime Function()? now,
  })  : _settingsRuntime = settingsRuntime,
        _mediaKitMpvAdapter = mediaKitMpvAdapter,
        _mediaKitMpvProbeSource = mediaKitMpvProbeSource,
        _mediaKitMpvTelemetrySource = mediaKitMpvTelemetrySource,
        _vlcFallbackAdapter = vlcFallbackAdapter,
        _vlcFallbackProbeSource = vlcFallbackProbeSource,
        _vlcFallbackTelemetrySource = vlcFallbackTelemetrySource,
        _now = now ?? DateTime.now {
    _telemetrySubscriptions
        .addAll(<StreamSubscription<PlayerTelemetrySnapshot>>[
      if (_mediaKitMpvTelemetrySource != null)
        _mediaKitMpvTelemetrySource.telemetry.listen(
          (PlayerTelemetrySnapshot telemetry) {
            if (_activeBackendId == playbackBackendMediaKitMpvId) {
              _telemetryController.add(telemetry);
            }
          },
        ),
      if (_vlcFallbackTelemetrySource != null)
        _vlcFallbackTelemetrySource.telemetry.listen(
          (PlayerTelemetrySnapshot telemetry) {
            if (_activeBackendId == playbackBackendVlcFallbackId) {
              _telemetryController.add(telemetry);
            }
          },
        ),
    ]);
  }

  final SettingsRuntime _settingsRuntime;
  final PlayerAdapter _mediaKitMpvAdapter;
  final PlaybackCapabilityProbeSource _mediaKitMpvProbeSource;
  final PlayerTelemetrySource? _mediaKitMpvTelemetrySource;
  final PlayerAdapter _vlcFallbackAdapter;
  final PlaybackCapabilityProbeSource _vlcFallbackProbeSource;
  final PlayerTelemetrySource? _vlcFallbackTelemetrySource;
  final DateTime Function() _now;
  final StreamController<PlayerTelemetrySnapshot> _telemetryController =
      StreamController<PlayerTelemetrySnapshot>.broadcast(sync: true);
  final List<StreamSubscription<PlayerTelemetrySnapshot>>
      _telemetrySubscriptions = <StreamSubscription<PlayerTelemetrySnapshot>>[];

  PlaybackBackendMode _configuredMode = PlaybackBackendMode.mediaKitMpv;
  String _activeBackendId = playbackBackendMediaKitMpvId;
  String? _latestFallbackReason;
  String? _latestFailureReason;
  DateTime? _lastSwitchedAt;
  bool _disposed = false;

  @override
  String get id => 'playback-backend-selection';

  @override
  String get displayName => 'Playback backend selection';

  String get activeBackendId => _activeBackendId;

  @override
  PlaybackCapabilityMatrix get capabilities =>
      currentCapabilityProbe.capabilities;

  @override
  PlayerTelemetrySnapshot get currentTelemetry {
    return _activeTelemetrySource?.currentTelemetry ??
        PlayerTelemetrySnapshot(
          observedAt: _now(),
          failureReason: _latestFailureReason,
        );
  }

  @override
  Stream<PlayerTelemetrySnapshot> get telemetry => _telemetryController.stream;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    final PlaybackCapabilityProbeSnapshot activeProbe = _activeProbe;
    return PlaybackCapabilityProbeSnapshot(
      capabilities: activeProbe.capabilities,
      checkedAt: _now(),
      source: playbackBackendSelectionProbeSource,
      backendLabel: activeProbe.backendLabel,
      cached: activeProbe.cached,
      details: <String, String>{
        ...activeProbe.details,
        'configuredMode': _configuredMode.name,
        'activeBackendId': _activeBackendId,
        if (_latestFallbackReason != null)
          'latestFallbackReason': _latestFallbackReason!,
        if (_latestFailureReason != null)
          'latestFailureReason': _latestFailureReason!,
        if (_lastSwitchedAt != null)
          'lastSwitchedAt': _lastSwitchedAt!.toIso8601String(),
        if (_hiddenCapabilities.isNotEmpty)
          'hiddenCapabilities': _hiddenCapabilitySummary(_hiddenCapabilities),
      },
    );
  }

  Future<PlaybackBackendSelectionSnapshot> snapshot() async {
    await _refreshConfiguredMode();
    await _refreshProbe(_mediaKitMpvProbeSource);
    await _refreshProbe(_vlcFallbackProbeSource);
    return PlaybackBackendSelectionSnapshot(
      configuredMode: _configuredMode,
      activeBackendId: _activeBackendId,
      activeBackendLabel: _activeAdapter.displayName,
      candidates: <PlaybackBackendCandidateSnapshot>[
        _candidateFromProbe(
          id: playbackBackendMediaKitMpvId,
          label: _mediaKitMpvAdapter.displayName,
          probe: _mediaKitMpvProbeSource.currentCapabilityProbe,
        ),
        _candidateFromProbe(
          id: playbackBackendVlcFallbackId,
          label: _vlcFallbackAdapter.displayName,
          probe: _vlcFallbackProbeSource.currentCapabilityProbe,
        ),
      ],
      hiddenCapabilities: _hiddenCapabilities,
      latestFallbackReason: _latestFallbackReason,
      latestFailureReason: _latestFailureReason,
      lastSwitchedAt: _lastSwitchedAt,
      checkedAt: _now(),
    );
  }

  Future<void> _refreshProbe(PlaybackCapabilityProbeSource source) async {
    if (source is RefreshablePlaybackCapabilityProbeSource) {
      await source.refreshCapabilityProbe();
    }
  }

  Future<PlaybackBackendSwitchResult> selectMode(
    PlaybackBackendMode mode,
  ) async {
    try {
      await _settingsRuntime.setPreference(
        key: SettingsPreferenceKeys.playbackBackendMode,
        value: PlaybackBackendModeSettings.serialize(mode),
      );
      _configuredMode = mode;
      _setActiveBackend(
        _defaultBackendIdForMode(mode),
        clearFallbackReason: true,
      );
      return PlaybackBackendSwitchResult.applied(mode);
    } catch (error) {
      return PlaybackBackendSwitchResult.failed(
        mode: mode,
        message: '保存播放后端失败: $error',
      );
    }
  }

  Future<void> configureVlcRuntimeDirectory(String directory) {
    return _settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.vlcRuntimeDirectory,
      value: directory.trim(),
    );
  }

  @override
  Future<PlaybackCommandResult> load(PlaybackSource source) async {
    if (_disposed) return _disposedResult(PlaybackOperation.load);
    await _refreshConfiguredMode();
    _latestFailureReason = null;

    switch (_configuredMode) {
      case PlaybackBackendMode.mediaKitMpv:
        _setActiveBackend(
          playbackBackendMediaKitMpvId,
          clearFallbackReason: true,
        );
        return _mediaKitMpvAdapter.load(source);
      case PlaybackBackendMode.vlcFallback:
        _setActiveBackend(
          playbackBackendVlcFallbackId,
          clearFallbackReason: true,
        );
        return _vlcFallbackAdapter.load(source);
      case PlaybackBackendMode.autoFallback:
        _setActiveBackend(
          playbackBackendMediaKitMpvId,
          clearFallbackReason: true,
        );
        final PlaybackCommandResult primary =
            await _mediaKitMpvAdapter.load(source);
        if (primary.isSuccess) return primary;
        if (!_canFallback(primary, source)) {
          _latestFailureReason = primary.failure?.message;
          return primary;
        }
        final PlaybackCommandResult fallbackSupport =
            playbackSourceSupportResult(
          source: source,
          capabilityMatrix: _vlcFallbackAdapter.capabilities,
        );
        if (!fallbackSupport.isSuccess) {
          _latestFailureReason = fallbackSupport.failure?.message;
          return primary;
        }
        final PlaybackCommandResult fallback =
            await _vlcFallbackAdapter.load(source);
        if (fallback.isSuccess) {
          _setActiveBackend(
            playbackBackendVlcFallbackId,
            reason: 'MPV 加载失败后自动切换到 VLC: ${primary.failure?.message ?? '未知失败'}',
          );
          return fallback;
        }
        _latestFailureReason =
            'MPV 失败: ${primary.failure?.message}; VLC 失败: ${fallback.failure?.message}';
        return fallback;
    }
  }

  @override
  Future<PlaybackCommandResult> play() {
    return _runTransport(PlaybackOperation.play, _activeAdapter.play);
  }

  @override
  Future<PlaybackCommandResult> pause() {
    return _runTransport(PlaybackOperation.pause, _activeAdapter.pause);
  }

  @override
  Future<PlaybackCommandResult> seek(Duration position) {
    return _runTransport(
      PlaybackOperation.seek,
      () => _activeAdapter.seek(position),
    );
  }

  @override
  Future<PlaybackCommandResult> stop() {
    return _runTransport(PlaybackOperation.stop, _activeAdapter.stop);
  }

  @override
  Future<PlaybackCommandResult> dispose() async {
    if (_disposed) return _disposedResult(PlaybackOperation.dispose);
    _disposed = true;
    for (final StreamSubscription<PlayerTelemetrySnapshot> subscription
        in _telemetrySubscriptions) {
      await subscription.cancel();
    }
    await _telemetryController.close();
    final PlaybackCommandResult primary = await _mediaKitMpvAdapter.dispose();
    final PlaybackCommandResult fallback = await _vlcFallbackAdapter.dispose();
    return primary.isSuccess ? fallback : primary;
  }

  @override
  Future<TrackDiscoveryResult> discoverTracks() {
    return _activeAdapter.discoverTracks();
  }

  @override
  Future<TrackSwitchResult> switchTrack(MediaTrackId trackId) {
    return _activeAdapter.switchTrack(trackId);
  }

  @override
  Future<EnhancementApplyOutcome> applyEnhancement(
    VideoEnhancementProfile profile,
  ) {
    return _activeAdapter.applyEnhancement(profile);
  }

  @override
  Future<EnhancementDisableOutcome> disableEnhancement() {
    return _activeAdapter.disableEnhancement();
  }

  PlayerAdapter get _activeAdapter {
    return _activeBackendId == playbackBackendVlcFallbackId
        ? _vlcFallbackAdapter
        : _mediaKitMpvAdapter;
  }

  PlaybackCapabilityProbeSnapshot get _activeProbe {
    return _activeBackendId == playbackBackendVlcFallbackId
        ? _vlcFallbackProbeSource.currentCapabilityProbe
        : _mediaKitMpvProbeSource.currentCapabilityProbe;
  }

  PlayerTelemetrySource? get _activeTelemetrySource {
    return _activeBackendId == playbackBackendVlcFallbackId
        ? _vlcFallbackTelemetrySource
        : _mediaKitMpvTelemetrySource;
  }

  Map<PlaybackCapability, CapabilityStatus> get _hiddenCapabilities {
    if (_activeBackendId != playbackBackendVlcFallbackId) {
      return const <PlaybackCapability, CapabilityStatus>{};
    }
    return <PlaybackCapability, CapabilityStatus>{
      for (final PlaybackCapability capability in PlaybackCapability.values)
        if (_mediaKitMpvAdapter.capabilities.supports(capability) &&
            !_vlcFallbackAdapter.capabilities.supports(capability))
          capability: _vlcFallbackAdapter.capabilities.statusOf(capability),
    };
  }

  Future<void> _refreshConfiguredMode() async {
    final String? value = await _settingsRuntime.getPreference(
      SettingsPreferenceKeys.playbackBackendMode,
    );
    _configuredMode = PlaybackBackendModeSettings.parse(value);
    if (_configuredMode != PlaybackBackendMode.autoFallback) {
      _setActiveBackend(
        _defaultBackendIdForMode(_configuredMode),
        clearFallbackReason: true,
      );
    }
  }

  String _defaultBackendIdForMode(PlaybackBackendMode mode) {
    return switch (mode) {
      PlaybackBackendMode.mediaKitMpv ||
      PlaybackBackendMode.autoFallback =>
        playbackBackendMediaKitMpvId,
      PlaybackBackendMode.vlcFallback => playbackBackendVlcFallbackId,
    };
  }

  void _setActiveBackend(
    String backendId, {
    String? reason,
    bool clearFallbackReason = false,
  }) {
    if (_activeBackendId != backendId) {
      _lastSwitchedAt = _now();
    }
    _activeBackendId = backendId;
    if (clearFallbackReason) {
      _latestFallbackReason = null;
    } else if (reason != null) {
      _latestFallbackReason = reason;
    }
    final PlayerTelemetrySnapshot telemetry = currentTelemetry;
    if (!_telemetryController.isClosed) {
      _telemetryController.add(telemetry);
    }
  }

  bool _canFallback(PlaybackCommandResult result, PlaybackSource source) {
    if (source is! LocalFilePlaybackSource) return false;
    final PlaybackFailure? failure = result.failure;
    if (failure == null) return false;
    return switch (failure.kind) {
      PlaybackFailureKind.operationFailed ||
      PlaybackFailureKind.adapterUnavailable ||
      PlaybackFailureKind.unsupported =>
        true,
      PlaybackFailureKind.invalidSource ||
      PlaybackFailureKind.disposed =>
        false,
    };
  }

  Future<PlaybackCommandResult> _runTransport(
    PlaybackOperation operation,
    Future<PlaybackCommandResult> Function() command,
  ) async {
    if (_disposed) return _disposedResult(operation);
    await _refreshConfiguredMode();
    return command();
  }

  PlaybackCommandResult _disposedResult(PlaybackOperation operation) {
    return PlaybackCommandResult.failure(
      PlaybackFailure(
        operation: operation,
        kind: PlaybackFailureKind.disposed,
        message: 'PlaybackBackendSelectionRuntime has been disposed.',
      ),
    );
  }

  PlaybackBackendCandidateSnapshot _candidateFromProbe({
    required String id,
    required String label,
    required PlaybackCapabilityProbeSnapshot probe,
  }) {
    final bool available = probe.capabilities.supports(
      id == playbackBackendVlcFallbackId
          ? PlaybackCapability.fallbackAdapter
          : PlaybackCapability.localFilePlayback,
    );
    return PlaybackBackendCandidateSnapshot(
      id: id,
      label: label,
      available: available,
      reason: available
          ? null
          : probe.capabilities
              .statusOf(id == playbackBackendVlcFallbackId
                  ? PlaybackCapability.fallbackAdapter
                  : PlaybackCapability.localFilePlayback)
              .reason,
      capabilities: probe.capabilities,
      checkedAt: probe.checkedAt,
      details: probe.details,
    );
  }

  static String _hiddenCapabilitySummary(
    Map<PlaybackCapability, CapabilityStatus> hidden,
  ) {
    return hidden.entries
        .map((MapEntry<PlaybackCapability, CapabilityStatus> entry) {
      return '${entry.key.name}: ${entry.value.reason ?? 'unsupported'}';
    }).join('; ');
  }
}
