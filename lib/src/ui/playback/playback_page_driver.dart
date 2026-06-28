import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_state.dart';
import '../../domain/playback/subtitle_style.dart';
import '../../domain/settings/settings_domain.dart';
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
    required this.id,
    required this.label,
    required this.status,
  });

  final DomainPlaybackCapabilityId id;
  final String label;
  final DomainPlaybackCapabilityStatus status;
}

final class PlaybackCapabilityPanelSnapshot {
  PlaybackCapabilityPanelSnapshot({
    required Iterable<PlaybackCapabilityItemSnapshot> items,
  }) : items = List<PlaybackCapabilityItemSnapshot>.unmodifiable(items);

  factory PlaybackCapabilityPanelSnapshot.fromMatrix(
    DomainPlaybackCapabilitySummary summary,
  ) {
    return PlaybackCapabilityPanelSnapshot(
      items: <PlaybackCapabilityItemSnapshot>[
        for (final DomainPlaybackCapabilityId id in playbackPageCapabilities)
          PlaybackCapabilityItemSnapshot(
            id: id,
            label: playbackCapabilityLabel(id),
            status: summary.statusOf(id),
          ),
      ],
    );
  }

  final List<PlaybackCapabilityItemSnapshot> items;
}

final class PlaybackVideoEnhancementPanelSnapshot {
  const PlaybackVideoEnhancementPanelSnapshot({
    required this.selectedPreset,
    required this.videoEnhancementStatus,
    required this.anime4kStatus,
    this.isApplying = false,
    this.message,
  });

  final VideoEnhancementPresetSelection selectedPreset;
  final DomainPlaybackCapabilityStatus videoEnhancementStatus;
  final DomainPlaybackCapabilityStatus anime4kStatus;
  final bool isApplying;
  final String? message;

  bool get isPresetSelectionEnabled =>
      !isApplying &&
      videoEnhancementStatus.isSupported &&
      anime4kStatus.isSupported;

  String? get unsupportedReason {
    if (!videoEnhancementStatus.isSupported) {
      return videoEnhancementStatus.reason ?? '当前后端不支持视频增强。';
    }
    if (!anime4kStatus.isSupported) {
      return anime4kStatus.reason ?? '当前后端不支持 Anime4K 预设。';
    }
    return null;
  }
}

final class PlaybackSubtitleStylePanelSnapshot {
  const PlaybackSubtitleStylePanelSnapshot({
    required this.profile,
    this.message,
    this.isSaving = false,
  });

  final SubtitleStyleProfile profile;
  final String? message;
  final bool isSaving;
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
    required this.videoEnhancement,
    required this.subtitleStyle,
    this.lastIntentResult,
  });

  final PlaybackStateSnapshot playback;
  final PlaybackPageSurfaceDescriptor surface;
  final PlaybackTrackPanelSnapshot tracks;
  final PlaybackCapabilityPanelSnapshot capabilities;
  final PlaybackVideoEnhancementPanelSnapshot videoEnhancement;
  final PlaybackSubtitleStylePanelSnapshot subtitleStyle;
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
  ControllerPlaybackPageDriver({
    required PlaybackControllerContract controller,
    SettingsRuntime? settingsRuntime,
  })  : _controller = controller,
        _settingsRuntime = settingsRuntime,
        _contract = PlaybackPageContract(controller: controller),
        _trackPanel = PlaybackTrackPanelSnapshot.idle(
          sourceUri: controller.currentState.sourceUri,
        ) {
    _controller.addPlaybackStateObserver(this);
    if (_settingsRuntime != null) {
      unawaited(_loadSubtitleStyle());
    }
  }

  final PlaybackControllerContract _controller;
  final SettingsRuntime? _settingsRuntime;
  final PlaybackPageContract _contract;
  PlaybackPageIntentResult? _lastIntentResult;
  PlaybackTrackPanelSnapshot _trackPanel;
  SubtitleStyleProfile _subtitleStyleProfile = SubtitleStyleProfile.defaults;
  String? _subtitleStyleMessage;
  bool _subtitleStyleSaving = false;
  VideoEnhancementPresetSelection _selectedVideoEnhancementPreset =
      VideoEnhancementPresetSelection.off;
  bool _videoEnhancementApplying = false;
  String? _videoEnhancementMessage;
  bool _disposed = false;

  @override
  PlaybackPageViewSnapshot get view {
    final DomainPlaybackCapabilitySummary capabilities =
        _controller.resolveCapabilitySummary();
    return PlaybackPageViewSnapshot(
      playback: _controller.currentState,
      surface: _resolveSurface(capabilities),
      tracks: _trackPanel,
      capabilities: PlaybackCapabilityPanelSnapshot.fromMatrix(capabilities),
      videoEnhancement: PlaybackVideoEnhancementPanelSnapshot(
        selectedPreset: _selectedVideoEnhancementPreset,
        videoEnhancementStatus:
            capabilities.statusOf(DomainPlaybackCapabilityId.videoEnhancement),
        anime4kStatus:
            capabilities.statusOf(DomainPlaybackCapabilityId.anime4kPreset),
        isApplying: _videoEnhancementApplying,
        message: _videoEnhancementMessage,
      ),
      subtitleStyle: PlaybackSubtitleStylePanelSnapshot(
        profile: _subtitleStyleProfile,
        message: _subtitleStyleMessage,
        isSaving: _subtitleStyleSaving,
      ),
      lastIntentResult: _lastIntentResult,
    );
  }

  @override
  Future<PlaybackPageIntentResult> dispatch(PlaybackPageIntent intent) async {
    if (intent.kind == PlaybackPageIntentKind.updateSubtitleStyle) {
      return _updateSubtitleStyle(intent.subtitleStyleProfile!);
    }
    if (intent.kind == PlaybackPageIntentKind.resetSubtitleStyle) {
      return _updateSubtitleStyle(SubtitleStyleProfile.defaults);
    }
    if (intent.kind == PlaybackPageIntentKind.applyVideoEnhancement) {
      _videoEnhancementApplying = true;
      _videoEnhancementMessage = null;
      _notifyIfActive();
    }

    final PlaybackPageIntentResult result = await _contract.dispatch(intent);
    _lastIntentResult = result;
    if (intent.kind == PlaybackPageIntentKind.applyVideoEnhancement) {
      _videoEnhancementApplying = false;
      final DomainVideoEnhancementApplyResult? enhancementResult =
          result.videoEnhancementResult;
      if (enhancementResult?.isSuccess ?? false) {
        _selectedVideoEnhancementPreset = enhancementResult!.preset;
        _videoEnhancementMessage = enhancementResult.status ==
                DomainVideoEnhancementApplyStatus.disabled
            ? '视频增强已关闭'
            : '已应用 ${videoEnhancementPresetSelectionLabel(enhancementResult.preset)}';
      } else {
        _videoEnhancementMessage = enhancementResult?.message ??
            result.reason ??
            'Anime4K 预设应用失败。';
      }
    }
    _notifyIfActive();
    return result;
  }

  @override
  Future<void> loadTracks() async {
    final Uri? sourceUri = _controller.currentState.sourceUri;
    _trackPanel = PlaybackTrackPanelSnapshot.loading(sourceUri: sourceUri);
    _notifyIfActive();

    late final DomainTrackDiscoveryResult result;
    try {
      result = await _controller.discoverDomainTracks();
    } on Object catch (error) {
      _trackPanel = PlaybackTrackPanelSnapshot.failed(
        '轨道发现失败：$error',
        sourceUri: sourceUri,
      );
      _notifyIfActive();
      return;
    }

    if (!result.isSupported) {
      _trackPanel = PlaybackTrackPanelSnapshot.unsupported(
        result.unsupportedReason ?? '当前播放后端不支持轨道发现。',
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

  PlaybackPageSurfaceDescriptor _resolveSurface(
    DomainPlaybackCapabilitySummary capabilities,
  ) {
    final DomainPlaybackCapabilityStatus matrixDanmaku = capabilities.statusOf(
      DomainPlaybackCapabilityId.matrixDanmaku,
    );
    return PlaybackPageSurfaceDescriptor.fromState(
      _controller.resolveSurfaceState(),
      subtitles: _subtitlesWithStyle(_controller.currentState.subtitles),
      danmaku: _controller.currentState.danmaku,
      matrixDanmakuSupported: matrixDanmaku.isSupported,
    );
  }

  PlaybackSubtitleStateSnapshot _subtitlesWithStyle(
    PlaybackSubtitleStateSnapshot subtitles,
  ) {
    return PlaybackSubtitleStateSnapshot(
      availableTracks: subtitles.availableTracks,
      selectedTrackId: subtitles.selectedTrackId,
      activeCues: subtitles.activeCues,
      offset: subtitles.offset,
      styleProfile: _subtitleStyleProfile,
      warnings: subtitles.warnings,
      failureReason: subtitles.failureReason,
    );
  }

  Future<void> _loadSubtitleStyle() async {
    final SettingsRuntime? settingsRuntime = _settingsRuntime;
    if (settingsRuntime == null) return;
    try {
      final String? raw = await settingsRuntime.getPreference(
        SettingsPreferenceKeys.subtitleStyleProfile,
      );
      _subtitleStyleProfile = SubtitleStyleSettings.parse(raw);
      _subtitleStyleMessage = null;
    } on Object catch (error) {
      _subtitleStyleProfile = SubtitleStyleProfile.defaults;
      _subtitleStyleMessage = '字幕样式设置无效，已使用默认值：$error';
    }
    _notifyIfActive();
  }

  Future<PlaybackPageIntentResult> _updateSubtitleStyle(
    SubtitleStyleProfile profile,
  ) async {
    final SettingsRuntime? settingsRuntime = _settingsRuntime;
    _subtitleStyleProfile = profile;
    _subtitleStyleMessage = null;
    _subtitleStyleSaving = settingsRuntime != null;
    _notifyIfActive();
    try {
      if (settingsRuntime != null) {
        await settingsRuntime.setPreference(
          key: SettingsPreferenceKeys.subtitleStyleProfile,
          value: SubtitleStyleSettings.serialize(profile),
        );
      }
      _subtitleStyleMessage = '字幕样式已保存';
      return const PlaybackPageIntentResult.executedPanel(
        PlaybackPagePanelId.tracks,
      );
    } on Object catch (error) {
      _subtitleStyleMessage = '字幕样式保存失败：$error';
      return PlaybackPageIntentResult.ignored(_subtitleStyleMessage!);
    } finally {
      _subtitleStyleSaving = false;
      _notifyIfActive();
    }
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }
}

const List<DomainPlaybackCapabilityId> playbackPageCapabilities =
    <DomainPlaybackCapabilityId>[
  DomainPlaybackCapabilityId.localFilePlayback,
  DomainPlaybackCapabilityId.httpPlayback,
  DomainPlaybackCapabilityId.hlsPlayback,
  DomainPlaybackCapabilityId.playPause,
  DomainPlaybackCapabilityId.seek,
  DomainPlaybackCapabilityId.stop,
  DomainPlaybackCapabilityId.progressReporting,
  DomainPlaybackCapabilityId.audioTrackDiscovery,
  DomainPlaybackCapabilityId.audioTrackSwitching,
  DomainPlaybackCapabilityId.subtitleTrackDiscovery,
  DomainPlaybackCapabilityId.subtitleTrackSwitching,
  DomainPlaybackCapabilityId.danmakuRendering,
  DomainPlaybackCapabilityId.videoEnhancement,
  DomainPlaybackCapabilityId.hdrToneMapping,
  DomainPlaybackCapabilityId.debandFiltering,
  DomainPlaybackCapabilityId.anime4kPreset,
  DomainPlaybackCapabilityId.avSyncGuard,
  DomainPlaybackCapabilityId.matrixDanmaku,
  DomainPlaybackCapabilityId.dualSubtitles,
  DomainPlaybackCapabilityId.pgsSubtitleRendering,
  DomainPlaybackCapabilityId.assSubtitleEnhancement,
  DomainPlaybackCapabilityId.fallbackAdapter,
];

String playbackCapabilityLabel(DomainPlaybackCapabilityId capability) {
  return switch (capability) {
    DomainPlaybackCapabilityId.localFilePlayback => '本地文件',
    DomainPlaybackCapabilityId.httpPlayback => 'HTTP 播放',
    DomainPlaybackCapabilityId.hlsPlayback => 'HLS 播放',
    DomainPlaybackCapabilityId.playPause => '播放/暂停',
    DomainPlaybackCapabilityId.seek => '进度跳转',
    DomainPlaybackCapabilityId.stop => '停止播放',
    DomainPlaybackCapabilityId.progressReporting => '进度报告',
    DomainPlaybackCapabilityId.audioTrackDiscovery => '音轨发现',
    DomainPlaybackCapabilityId.audioTrackSwitching => '音轨切换',
    DomainPlaybackCapabilityId.subtitleTrackDiscovery => '字幕发现',
    DomainPlaybackCapabilityId.subtitleTrackSwitching => '字幕切换',
    DomainPlaybackCapabilityId.danmakuRendering => '弹幕渲染',
    DomainPlaybackCapabilityId.secondaryPanels => '辅助面板',
    DomainPlaybackCapabilityId.videoEnhancement => '视频增强',
    DomainPlaybackCapabilityId.hdrToneMapping => 'HDR 映射',
    DomainPlaybackCapabilityId.debandFiltering => '去色带',
    DomainPlaybackCapabilityId.anime4kPreset => 'Anime4K 预设',
    DomainPlaybackCapabilityId.avSyncGuard => '音画同步守卫',
    DomainPlaybackCapabilityId.matrixDanmaku => '矩阵弹幕',
    DomainPlaybackCapabilityId.dualSubtitles => '双字幕',
    DomainPlaybackCapabilityId.pgsSubtitleRendering => 'PGS 字幕',
    DomainPlaybackCapabilityId.assSubtitleEnhancement => 'ASS 增强',
    DomainPlaybackCapabilityId.fallbackAdapter => '备用播放后端',
  };
}

String videoEnhancementPresetSelectionLabel(
  VideoEnhancementPresetSelection preset,
) {
  return switch (preset) {
    VideoEnhancementPresetSelection.off => '关闭',
    VideoEnhancementPresetSelection.restore => 'Restore',
    VideoEnhancementPresetSelection.upscale => 'Upscale',
    VideoEnhancementPresetSelection.restoreAndUpscale => 'Restore + Upscale',
  };
}

PlaybackTrackItemSnapshot _trackItemFromDescriptor(
  DomainMediaTrackDescriptor descriptor,
) {
  return PlaybackTrackItemSnapshot(
    id: descriptor.id,
    type: descriptor.type,
    label: descriptor.label,
    languageCode: descriptor.languageCode,
  );
}
