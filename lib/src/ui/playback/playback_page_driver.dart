import 'package:flutter/foundation.dart';

import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import '../../playback/capability_matrix.dart';
import '../../playback/track_management.dart';
import 'playback_page_contract.dart';

enum PlaybackTrackPanelStatus {
  idle,
  loading,
  loaded,
  unsupported,
  failed,
}

/// UI-facing track row data.
///
/// The production page deliberately consumes this projection instead of
/// MediaTrackDescriptor so widget code never reaches into adapter-owned track
/// types. That keeps MPV/media-kit/VLC track quirks out of the UI layer.
final class PlaybackTrackItemSnapshot {
  const PlaybackTrackItemSnapshot({
    required this.id,
    required this.type,
    required this.label,
    this.languageCode,
  });

  final DomainMediaTrackId id;
  final DomainMediaTrackType type;
  final String label;
  final String? languageCode;
}

/// Snapshot for the inspector track panel.
///
/// Track discovery is intentionally lazy. Opening playback should stay cheap,
/// and adapters may need native/player state before they can enumerate tracks.
final class PlaybackTrackPanelSnapshot {
  PlaybackTrackPanelSnapshot._({
    required this.status,
    required Iterable<PlaybackTrackItemSnapshot> tracks,
    this.message,
    this.sourceUri,
  }) : tracks = List<PlaybackTrackItemSnapshot>.unmodifiable(tracks);

  const PlaybackTrackPanelSnapshot.idle({Uri? sourceUri})
      : status = PlaybackTrackPanelStatus.idle,
        tracks = const <PlaybackTrackItemSnapshot>[],
        message = null,
        sourceUri = sourceUri;

  const PlaybackTrackPanelSnapshot.loading({Uri? sourceUri})
      : status = PlaybackTrackPanelStatus.loading,
        tracks = const <PlaybackTrackItemSnapshot>[],
        message = null,
        sourceUri = sourceUri;

  PlaybackTrackPanelSnapshot.loaded(
    Iterable<PlaybackTrackItemSnapshot> tracks, {
    Uri? sourceUri,
  }) : this._(
          status: PlaybackTrackPanelStatus.loaded,
          tracks: tracks,
          sourceUri: sourceUri,
        );

  const PlaybackTrackPanelSnapshot.unsupported(
    String message, {
    Uri? sourceUri,
  })  : status = PlaybackTrackPanelStatus.unsupported,
        tracks = const <PlaybackTrackItemSnapshot>[],
        message = message,
        sourceUri = sourceUri;

  const PlaybackTrackPanelSnapshot.failed(
    String message, {
    Uri? sourceUri,
  })  : status = PlaybackTrackPanelStatus.failed,
        tracks = const <PlaybackTrackItemSnapshot>[],
        message = message,
        sourceUri = sourceUri;

  final PlaybackTrackPanelStatus status;
  final List<PlaybackTrackItemSnapshot> tracks;
  final String? message;
  final Uri? sourceUri;

  bool get hasTracks => tracks.isNotEmpty;

  List<PlaybackTrackItemSnapshot> tracksOfType(DomainMediaTrackType type) {
    return <PlaybackTrackItemSnapshot>[
      for (final PlaybackTrackItemSnapshot track in tracks)
        if (track.type == type) track,
    ];
  }
}

/// Read-only capability row shown by the playback inspector.
///
/// Capabilities are diagnostics here, not action buttons. If a capability does
/// not have a domain command contract, the page must only report its status.
final class PlaybackCapabilityItemSnapshot {
  const PlaybackCapabilityItemSnapshot({
    required this.capability,
    required this.label,
    required this.status,
  });

  final PlaybackCapability capability;
  final String label;
  final CapabilityStatus status;
}

final class PlaybackCapabilityPanelSnapshot {
  PlaybackCapabilityPanelSnapshot(
      {required Iterable<PlaybackCapabilityItemSnapshot> items})
      : items = List<PlaybackCapabilityItemSnapshot>.unmodifiable(items);

  factory PlaybackCapabilityPanelSnapshot.fromMatrix(
    PlaybackCapabilityMatrix matrix,
  ) {
    return PlaybackCapabilityPanelSnapshot(
      items: <PlaybackCapabilityItemSnapshot>[
        for (final PlaybackCapability capability in playbackPageCapabilities)
          PlaybackCapabilityItemSnapshot(
            capability: capability,
            label: playbackCapabilityLabel(capability),
            status: matrix.statusOf(capability),
          ),
      ],
    );
  }

  final List<PlaybackCapabilityItemSnapshot> items;
}

/// Complete UI read model for the production playback page.
///
/// Keeping the page on this single read model prevents individual widgets from
/// mixing controller state, surface controls, track discovery, and capability
/// matrix reads in slightly different ways.
final class PlaybackPageViewSnapshot {
  const PlaybackPageViewSnapshot({
    required this.playback,
    required this.surface,
    required this.tracks,
    required this.capabilities,
    this.lastIntentResult,
  });

  final PlaybackStateSnapshot playback;
  final PlaybackPageSurfaceDescriptor surface;
  final PlaybackTrackPanelSnapshot tracks;
  final PlaybackCapabilityPanelSnapshot capabilities;
  final PlaybackPageIntentResult? lastIntentResult;
}

/// Boundary used by the production page.
///
/// The UI talks in page intents and read models; the concrete implementation is
/// responsible for translating them to the PlaybackPageContract and controller.
abstract interface class PlaybackPageDriver implements Listenable {
  PlaybackPageViewSnapshot get view;

  Future<PlaybackPageIntentResult> dispatch(PlaybackPageIntent intent);

  Future<void> loadTracks();
}

final class ControllerPlaybackPageDriver extends ChangeNotifier
    implements PlaybackPageDriver, PlaybackStateObserver {
  ControllerPlaybackPageDriver({required PlaybackControllerContract controller})
      : _controller = controller,
        _contract = PlaybackPageContract(controller: controller),
        _trackPanel = PlaybackTrackPanelSnapshot.idle(
            sourceUri: controller.currentState.sourceUri) {
    _controller.addPlaybackStateObserver(this);
  }

  final PlaybackControllerContract _controller;
  final PlaybackPageContract _contract;
  PlaybackPageIntentResult? _lastIntentResult;
  PlaybackTrackPanelSnapshot _trackPanel;
  bool _disposed = false;

  @override
  PlaybackPageViewSnapshot get view {
    return PlaybackPageViewSnapshot(
      playback: _controller.currentState,
      surface: _contract.resolveSurface(),
      tracks: _trackPanel,
      capabilities:
          PlaybackCapabilityPanelSnapshot.fromMatrix(_controller.matrix),
      lastIntentResult: _lastIntentResult,
    );
  }

  @override
  Future<PlaybackPageIntentResult> dispatch(PlaybackPageIntent intent) async {
    final PlaybackPageIntentResult result = await _contract.dispatch(intent);
    _lastIntentResult = result;
    _notifyIfActive();
    return result;
  }

  @override
  Future<void> loadTracks() async {
    final Uri? sourceUri = _controller.currentState.sourceUri;
    _trackPanel = PlaybackTrackPanelSnapshot.loading(sourceUri: sourceUri);
    _notifyIfActive();

    late final TrackDiscoveryResult result;
    try {
      result = await _controller.discoverTracks();
    } on Object catch (error) {
      _trackPanel = PlaybackTrackPanelSnapshot.failed(
        '轨道发现失败：$error',
        sourceUri: sourceUri,
      );
      _notifyIfActive();
      return;
    }

    if (!_hasTrackDiscoveryCapability(result.capabilityMatrix)) {
      _trackPanel = PlaybackTrackPanelSnapshot.unsupported(
        '当前播放后端不支持轨道发现。',
        sourceUri: sourceUri,
      );
      _notifyIfActive();
      return;
    }

    _trackPanel = PlaybackTrackPanelSnapshot.loaded(
      result.tracks.map(_trackItemFromDescriptor),
      sourceUri: sourceUri,
    );
    _notifyIfActive();
  }

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    // Track lists belong to the loaded source. A new source invalidates the
    // previous native enumeration instead of pretending the old rows still
    // describe the current file or stream.
    if (snapshot.sourceUri != _trackPanel.sourceUri) {
      _trackPanel =
          PlaybackTrackPanelSnapshot.idle(sourceUri: snapshot.sourceUri);
    }
    _notifyIfActive();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removePlaybackStateObserver(this);
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }
}

const List<PlaybackCapability> playbackPageCapabilities = <PlaybackCapability>[
  PlaybackCapability.localFilePlayback,
  PlaybackCapability.httpPlayback,
  PlaybackCapability.hlsPlayback,
  PlaybackCapability.playPause,
  PlaybackCapability.seek,
  PlaybackCapability.stop,
  PlaybackCapability.progressReporting,
  PlaybackCapability.audioTrackDiscovery,
  PlaybackCapability.audioTrackSwitching,
  PlaybackCapability.subtitleTrackDiscovery,
  PlaybackCapability.subtitleTrackSwitching,
  PlaybackCapability.danmakuRendering,
  PlaybackCapability.videoEnhancement,
  PlaybackCapability.hdrToneMapping,
  PlaybackCapability.debandFiltering,
  PlaybackCapability.anime4kPreset,
  PlaybackCapability.avSyncGuard,
  PlaybackCapability.matrixDanmaku,
  PlaybackCapability.dualSubtitles,
  PlaybackCapability.pgsSubtitleRendering,
  PlaybackCapability.assSubtitleEnhancement,
  PlaybackCapability.fallbackAdapter,
];

String playbackCapabilityLabel(PlaybackCapability capability) {
  return switch (capability) {
    PlaybackCapability.localFilePlayback => '本地文件',
    PlaybackCapability.httpPlayback => 'HTTP 播放',
    PlaybackCapability.hlsPlayback => 'HLS 播放',
    PlaybackCapability.playPause => '播放/暂停',
    PlaybackCapability.seek => '进度跳转',
    PlaybackCapability.stop => '停止播放',
    PlaybackCapability.progressReporting => '进度报告',
    PlaybackCapability.audioTrackDiscovery => '音轨发现',
    PlaybackCapability.audioTrackSwitching => '音轨切换',
    PlaybackCapability.subtitleTrackDiscovery => '字幕发现',
    PlaybackCapability.subtitleTrackSwitching => '字幕切换',
    PlaybackCapability.danmakuRendering => '弹幕渲染',
    PlaybackCapability.secondaryPanels => '辅助面板',
    PlaybackCapability.videoEnhancement => '视频增强',
    PlaybackCapability.hdrToneMapping => 'HDR 映射',
    PlaybackCapability.debandFiltering => '去色带',
    PlaybackCapability.anime4kPreset => 'Anime4K 预设',
    PlaybackCapability.avSyncGuard => '音画同步守卫',
    PlaybackCapability.matrixDanmaku => '矩阵弹幕',
    PlaybackCapability.dualSubtitles => '双字幕',
    PlaybackCapability.pgsSubtitleRendering => 'PGS 字幕',
    PlaybackCapability.assSubtitleEnhancement => 'ASS 增强',
    PlaybackCapability.fallbackAdapter => '备用播放后端',
  };
}

PlaybackTrackItemSnapshot _trackItemFromDescriptor(
  MediaTrackDescriptor descriptor,
) {
  return PlaybackTrackItemSnapshot(
    id: DomainMediaTrackId(descriptor.id.value),
    type: switch (descriptor.type) {
      MediaTrackType.audio => DomainMediaTrackType.audio,
      MediaTrackType.subtitle => DomainMediaTrackType.subtitle,
    },
    label: descriptor.label,
    languageCode: descriptor.languageCode,
  );
}

bool _hasTrackDiscoveryCapability(PlaybackCapabilityMatrix matrix) {
  return matrix.supports(PlaybackCapability.audioTrackDiscovery) ||
      matrix.supports(PlaybackCapability.subtitleTrackDiscovery);
}
