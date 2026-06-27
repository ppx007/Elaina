import '../../playback/av_sync_guard.dart';
import '../../playback/capability_matrix.dart';
import '../download/download_domain.dart';
import '../media/media_library_runtime.dart';
import '../playback/av_sync_guard_monitor_runtime.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_state.dart';
import '../rss/rss_engine.dart';
import '../rss/rss_engine_runtime.dart';
import '../settings/settings_domain.dart';
import 'diagnostics_domain.dart';

const String diagnosticsModuleOverview = 'overview';
const String diagnosticsModulePlayback = 'playback';
const String diagnosticsModuleDownloads = 'downloads';
const String diagnosticsModuleRss = 'rss';
const String diagnosticsModuleMediaLibrary = 'media-library';
const String diagnosticsModuleProviderNetwork = 'provider-network';
const String diagnosticsModuleEvents = 'events';

enum DiagnosticsModuleHealth {
  healthy,
  warning,
  failed,
}

final class DiagnosticsTelemetrySample {
  const DiagnosticsTelemetrySample({
    required this.sampledAt,
    required this.memoryUsageBytes,
    required this.avSyncDriftMillis,
  });

  final DateTime sampledAt;
  final int memoryUsageBytes;
  final double avSyncDriftMillis;
}

final class DiagnosticsModuleSnapshot {
  const DiagnosticsModuleSnapshot({
    required this.id,
    required this.label,
    required this.health,
    required this.summary,
    this.failureMessage,
  });

  final String id;
  final String label;
  final DiagnosticsModuleHealth health;
  final String summary;
  final String? failureMessage;
}

const Duration diagnosticsBackendProbeNetworkTtl = Duration(seconds: 60);
const Duration diagnosticsBackendProbeNetworkTimeout = Duration(seconds: 3);
const String diagnosticsProbeSourceUnavailable = 'probe-unavailable';
const String diagnosticsProbeSourceRuntime = 'runtime-probe';
const String diagnosticsProbeSourceCached = 'runtime-probe-cache';

final class DiagnosticsProbeCheckResult {
  const DiagnosticsProbeCheckResult.supported({
    required this.message,
    Map<String, String> details = const <String, String>{},
  })  : supported = true,
        details = details;

  const DiagnosticsProbeCheckResult.unsupported({
    required this.message,
    Map<String, String> details = const <String, String>{},
  })  : supported = false,
        details = details;

  final bool supported;
  final String message;
  final Map<String, String> details;
}

typedef DiagnosticsAsyncProbeCheck = Future<DiagnosticsProbeCheckResult>
    Function();

final class DiagnosticsBackendProbeModuleSnapshot {
  DiagnosticsBackendProbeModuleSnapshot({
    required this.id,
    required this.label,
    required this.supported,
    required this.message,
    required this.checkedAt,
    required this.source,
    this.cached = false,
    Map<String, String> details = const <String, String>{},
  }) : details = Map<String, String>.unmodifiable(details);

  final String id;
  final String label;
  final bool supported;
  final String message;
  final DateTime checkedAt;
  final String source;
  final bool cached;
  final Map<String, String> details;
}

final class DiagnosticsBackendProbeSnapshot {
  const DiagnosticsBackendProbeSnapshot({
    this.playback,
    required this.downloads,
    required this.rss,
    required this.mediaLibrary,
    required this.providerNetwork,
  });

  final PlaybackCapabilityProbeSnapshot? playback;
  final DiagnosticsBackendProbeModuleSnapshot downloads;
  final DiagnosticsBackendProbeModuleSnapshot rss;
  final DiagnosticsBackendProbeModuleSnapshot mediaLibrary;
  final DiagnosticsBackendProbeModuleSnapshot providerNetwork;
}

abstract interface class DiagnosticsBackendProbeRuntime {
  Future<DiagnosticsBackendProbeSnapshot> probe();
}

final class DefaultDiagnosticsBackendProbeRuntime
    implements DiagnosticsBackendProbeRuntime {
  DefaultDiagnosticsBackendProbeRuntime({
    PlaybackCapabilityProbeSource? playbackProbeSource,
    required DownloadRuntime downloadRuntime,
    required RssEngineRuntime rssEngineRuntime,
    required MediaLibraryRuntime mediaLibraryRuntime,
    required SettingsRuntime settingsRuntime,
    DiagnosticsAsyncProbeCheck? rssConnectivityCheck,
    DiagnosticsAsyncProbeCheck? providerNetworkCheck,
    Duration networkTtl = diagnosticsBackendProbeNetworkTtl,
    Duration networkTimeout = diagnosticsBackendProbeNetworkTimeout,
    DateTime Function()? now,
  })  : _playbackProbeSource = playbackProbeSource,
        _downloadRuntime = downloadRuntime,
        _rssEngineRuntime = rssEngineRuntime,
        _mediaLibraryRuntime = mediaLibraryRuntime,
        _settingsRuntime = settingsRuntime,
        _rssConnectivityCheck = rssConnectivityCheck,
        _providerNetworkCheck = providerNetworkCheck,
        _networkTtl = networkTtl,
        _networkTimeout = networkTimeout,
        _now = now ?? DateTime.now;

  final PlaybackCapabilityProbeSource? _playbackProbeSource;
  final DownloadRuntime _downloadRuntime;
  final RssEngineRuntime _rssEngineRuntime;
  final MediaLibraryRuntime _mediaLibraryRuntime;
  final SettingsRuntime _settingsRuntime;
  final DiagnosticsAsyncProbeCheck? _rssConnectivityCheck;
  final DiagnosticsAsyncProbeCheck? _providerNetworkCheck;
  final Duration _networkTtl;
  final Duration _networkTimeout;
  final DateTime Function() _now;
  _CachedProbe? _rssCache;
  _CachedProbe? _providerCache;
  Future<DiagnosticsBackendProbeModuleSnapshot>? _rssInFlight;
  Future<DiagnosticsBackendProbeModuleSnapshot>? _providerInFlight;

  @override
  Future<DiagnosticsBackendProbeSnapshot> probe() async {
    final PlaybackCapabilityProbeSnapshot? playback =
        _playbackProbeSource?.currentCapabilityProbe;
    final DiagnosticsBackendProbeModuleSnapshot downloads =
        await _probeDownloads();
    final DiagnosticsBackendProbeModuleSnapshot rss = await _probeRss();
    final DiagnosticsBackendProbeModuleSnapshot mediaLibrary =
        _probeMediaLibrary();
    final DiagnosticsBackendProbeModuleSnapshot providerNetwork =
        await _probeProviderNetwork();

    return DiagnosticsBackendProbeSnapshot(
      playback: playback,
      downloads: downloads,
      rss: rss,
      mediaLibrary: mediaLibrary,
      providerNetwork: providerNetwork,
    );
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _probeDownloads() async {
    final DateTime checkedAt = _now();
    try {
      await _downloadRuntime.listTasks();
      final DownloadRuntimeSnapshot snapshot = _downloadRuntime.currentSnapshot;
      final DownloadCapabilityProjection capabilities = snapshot.capabilities;
      final List<String> unsupportedReasons = <String>[
        if (!capabilities.taskManagementAvailable)
          capabilities.taskManagementReason ?? '任务管理不可用',
        if (!capabilities.metadataFetchingAvailable)
          capabilities.metadataFetchingReason ?? '元数据读取不可用',
        if (!capabilities.backgroundDownloadAvailable)
          capabilities.backgroundDownloadReason ?? '应用内后台下载不可用',
        if (!capabilities.virtualStreamAvailable)
          capabilities.virtualStreamReason ?? '边下边播不可用',
      ];
      return DiagnosticsBackendProbeModuleSnapshot(
        id: diagnosticsModuleDownloads,
        label: '下载',
        supported: unsupportedReasons.isEmpty,
        message: unsupportedReasons.isEmpty
            ? '下载 runtime 能力已由真实任务快照确认'
            : unsupportedReasons.first,
        checkedAt: checkedAt,
        source: diagnosticsProbeSourceRuntime,
        details: <String, String>{
          'tasks': snapshot.tasks.length.toString(),
          'taskManagement': capabilities.taskManagementAvailable.toString(),
          'metadataFetching': capabilities.metadataFetchingAvailable.toString(),
          'backgroundDownload':
              capabilities.backgroundDownloadAvailable.toString(),
          'virtualStream': capabilities.virtualStreamAvailable.toString(),
        },
      );
    } on Object catch (error) {
      return _failedProbe(
        id: diagnosticsModuleDownloads,
        label: '下载',
        checkedAt: checkedAt,
        error: error,
      );
    }
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _probeRss() {
    return _cachedNetworkProbe(
      cache: _rssCache,
      inFlight: _rssInFlight,
      setCache: (_CachedProbe cache) => _rssCache = cache,
      setInFlight: (Future<DiagnosticsBackendProbeModuleSnapshot>? inFlight) =>
          _rssInFlight = inFlight,
      localProbe: _probeRssLocal,
      remoteCheck: _rssConnectivityCheck,
    );
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _probeProviderNetwork() {
    return _cachedNetworkProbe(
      cache: _providerCache,
      inFlight: _providerInFlight,
      setCache: (_CachedProbe cache) => _providerCache = cache,
      setInFlight: (Future<DiagnosticsBackendProbeModuleSnapshot>? inFlight) =>
          _providerInFlight = inFlight,
      localProbe: _probeProviderNetworkLocal,
      remoteCheck: _providerNetworkCheck,
    );
  }

  DiagnosticsBackendProbeModuleSnapshot _probeMediaLibrary() {
    final DateTime checkedAt = _now();
    try {
      final MediaLibraryRuntimeSnapshot snapshot =
          _mediaLibraryRuntime.currentSnapshot;
      final bool supported = snapshot.failures.isEmpty;
      return DiagnosticsBackendProbeModuleSnapshot(
        id: diagnosticsModuleMediaLibrary,
        label: '本地媒体库',
        supported: supported,
        message:
            supported ? '媒体库 runtime 快照可读' : snapshot.failures.first.message,
        checkedAt: checkedAt,
        source: diagnosticsProbeSourceRuntime,
        details: <String, String>{
          'catalogItems': snapshot.catalogItems.length.toString(),
          'scanEvents': snapshot.scanEvents.length.toString(),
        },
      );
    } on Object catch (error) {
      return _failedProbe(
        id: diagnosticsModuleMediaLibrary,
        label: '本地媒体库',
        checkedAt: checkedAt,
        error: error,
      );
    }
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _probeRssLocal(
    DiagnosticsAsyncProbeCheck? remoteCheck,
  ) async {
    final DateTime checkedAt = _now();
    try {
      final RssEngineRuntimeSnapshot snapshot =
          _rssEngineRuntime.currentSnapshot;
      final DiagnosticsProbeCheckResult? remote =
          await _runOptionalRemoteCheck(remoteCheck);
      final bool supported =
          snapshot.failures.isEmpty && (remote == null || remote.supported);
      return DiagnosticsBackendProbeModuleSnapshot(
        id: diagnosticsModuleRss,
        label: 'RSS',
        supported: supported,
        message: !snapshot.failures.isEmpty
            ? snapshot.failures.first.message
            : remote?.message ?? 'RSS runtime 快照可读，未配置远端连通性 probe',
        checkedAt: checkedAt,
        source: diagnosticsProbeSourceRuntime,
        details: <String, String>{
          'sources': snapshot.sources.length.toString(),
          'dueSources': snapshot.dueSources.length.toString(),
          'acceptedItems': snapshot.acceptedItems.length.toString(),
          if (remote != null) ...remote.details,
        },
      );
    } on Object catch (error) {
      return _failedProbe(
        id: diagnosticsModuleRss,
        label: 'RSS',
        checkedAt: checkedAt,
        error: error,
      );
    }
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _probeProviderNetworkLocal(
    DiagnosticsAsyncProbeCheck? remoteCheck,
  ) async {
    final DateTime checkedAt = _now();
    try {
      final String? token = await _settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiAccessToken);
      final String? proxy = await _settingsRuntime.getProxyUrl();
      final String? dns = await _settingsRuntime.getDnsPolicy();
      final DiagnosticsProbeCheckResult? remote =
          await _runOptionalRemoteCheck(remoteCheck);
      return DiagnosticsBackendProbeModuleSnapshot(
        id: diagnosticsModuleProviderNetwork,
        label: 'Provider/网络',
        supported: remote?.supported ?? true,
        message: remote?.message ?? 'Provider/网络设置可读，未配置远端连通性 probe',
        checkedAt: checkedAt,
        source: diagnosticsProbeSourceRuntime,
        details: <String, String>{
          'bangumiTokenConfigured':
              (token?.trim().isNotEmpty ?? false).toString(),
          'httpProxyConfigured': (proxy?.trim().isNotEmpty ?? false).toString(),
          'dnsPolicyConfigured': (dns?.trim().isNotEmpty ?? false).toString(),
          if (remote != null) ...remote.details,
        },
      );
    } on Object catch (error) {
      return _failedProbe(
        id: diagnosticsModuleProviderNetwork,
        label: 'Provider/网络',
        checkedAt: checkedAt,
        error: error,
      );
    }
  }

  Future<DiagnosticsProbeCheckResult?> _runOptionalRemoteCheck(
    DiagnosticsAsyncProbeCheck? check,
  ) async {
    if (check == null) return null;
    return check().timeout(_networkTimeout);
  }

  Future<DiagnosticsBackendProbeModuleSnapshot> _cachedNetworkProbe({
    required _CachedProbe? cache,
    required Future<DiagnosticsBackendProbeModuleSnapshot>? inFlight,
    required void Function(_CachedProbe cache) setCache,
    required void Function(Future<DiagnosticsBackendProbeModuleSnapshot>?)
        setInFlight,
    required Future<DiagnosticsBackendProbeModuleSnapshot> Function(
            DiagnosticsAsyncProbeCheck? remoteCheck)
        localProbe,
    required DiagnosticsAsyncProbeCheck? remoteCheck,
  }) async {
    final DateTime now = _now();
    if (cache != null &&
        now.difference(cache.snapshot.checkedAt) < _networkTtl) {
      return cache.snapshot.asCached();
    }
    if (inFlight != null) return inFlight;

    final Future<DiagnosticsBackendProbeModuleSnapshot> future =
        localProbe(remoteCheck).then(
      (DiagnosticsBackendProbeModuleSnapshot snapshot) {
        setCache(_CachedProbe(snapshot));
        return snapshot;
      },
    ).whenComplete(() => setInFlight(null));
    setInFlight(future);
    return future;
  }
}

final class _CachedProbe {
  const _CachedProbe(this.snapshot);

  final DiagnosticsBackendProbeModuleSnapshot snapshot;
}

extension on DiagnosticsBackendProbeModuleSnapshot {
  DiagnosticsBackendProbeModuleSnapshot asCached() {
    return DiagnosticsBackendProbeModuleSnapshot(
      id: id,
      label: label,
      supported: supported,
      message: message,
      checkedAt: checkedAt,
      source: diagnosticsProbeSourceCached,
      cached: true,
      details: details,
    );
  }
}

DiagnosticsBackendProbeModuleSnapshot _failedProbe({
  required String id,
  required String label,
  required DateTime checkedAt,
  required Object error,
}) {
  return DiagnosticsBackendProbeModuleSnapshot(
    id: id,
    label: label,
    supported: false,
    message: '后端探测失败: $error',
    checkedAt: checkedAt,
    source: diagnosticsProbeSourceRuntime,
    details: <String, String>{'failure': error.toString()},
  );
}

final class DiagnosticsCapabilityEntry {
  const DiagnosticsCapabilityEntry({
    required this.id,
    required this.label,
    required this.supported,
    this.reason,
    this.checkedAt,
    this.source,
    this.cached = false,
  });

  final String id;
  final String label;
  final bool supported;
  final String? reason;
  final DateTime? checkedAt;
  final String? source;
  final bool cached;
}

final class DiagnosticsPlaybackSnapshot {
  const DiagnosticsPlaybackSnapshot({
    required this.backendLabel,
    required this.probeSource,
    required this.probeCheckedAt,
    required this.probeCached,
    required this.probeDetails,
    required this.status,
    required this.position,
    required this.duration,
    required this.isBuffering,
    required this.bufferedFraction,
    required this.sourceUri,
    required this.failureReason,
    required this.activeAudioTrackId,
    required this.activeSubtitleTrackId,
    required this.subtitleTrackCount,
    required this.activeSubtitleCueCount,
    required this.subtitleOffset,
    required this.subtitleWarnings,
    required this.subtitleFailure,
    required this.danmakuClockPosition,
    required this.danmakuLaneCount,
    required this.visibleDanmakuCommentCount,
    required this.danmakuWarnings,
    required this.danmakuFailure,
    required this.capabilities,
    this.avSyncHealth,
    this.avSyncLatestDriftMillis,
    this.avSyncSampleCount,
    this.avSyncLatestDegradationAction,
    this.avSyncSamplerFailure,
    this.avSyncLastSampledAt,
  });

  factory DiagnosticsPlaybackSnapshot.fromController(
    PlaybackControllerContract controller, {
    PlaybackCapabilityProbeSnapshot? capabilityProbe,
    AVSyncGuardMonitorSnapshot? avSyncMonitor,
  }) {
    final PlaybackStateSnapshot state = controller.currentState;
    final PlaybackCapabilityMatrix matrix =
        capabilityProbe?.capabilities ?? controller.matrix;
    return DiagnosticsPlaybackSnapshot(
      backendLabel: capabilityProbe?.backendLabel ?? '未知播放后端',
      probeSource: capabilityProbe?.source ?? diagnosticsProbeSourceUnavailable,
      probeCheckedAt: capabilityProbe?.checkedAt,
      probeCached: capabilityProbe?.cached ?? false,
      probeDetails: capabilityProbe?.details ?? const <String, String>{},
      status: state.status,
      position: state.timeline.position,
      duration: state.timeline.duration,
      isBuffering: state.buffering.isBuffering,
      bufferedFraction: state.buffering.bufferedFraction,
      sourceUri: state.sourceUri?.toString(),
      failureReason: state.failureReason,
      activeAudioTrackId: state.activeTracks.audioTrackId?.value,
      activeSubtitleTrackId: state.activeTracks.subtitleTrackId?.value,
      subtitleTrackCount: state.subtitles.availableTracks.length,
      activeSubtitleCueCount: state.subtitles.activeCues.length,
      subtitleOffset: state.subtitles.offset,
      subtitleWarnings: state.subtitles.warnings,
      subtitleFailure: state.subtitles.failureReason,
      danmakuClockPosition: state.danmaku.clockPosition,
      danmakuLaneCount: state.danmaku.lanes.length,
      visibleDanmakuCommentCount: state.danmaku.lanes.fold<int>(
        0,
        (int count, DomainDanmakuLaneDescriptor lane) =>
            count + lane.comments.length,
      ),
      danmakuWarnings: state.danmaku.warnings,
      danmakuFailure: state.danmaku.failureReason,
      avSyncHealth: avSyncMonitor?.health,
      avSyncLatestDriftMillis: avSyncMonitor?.latestDriftMillis,
      avSyncSampleCount: avSyncMonitor?.sampleCount,
      avSyncLatestDegradationAction: avSyncMonitor?.latestDegradationAction,
      avSyncSamplerFailure: avSyncMonitor?.latestSampleFailure?.message ??
          avSyncMonitor?.latestGuardFailure?.message,
      avSyncLastSampledAt: avSyncMonitor?.lastSampledAt,
      capabilities: diagnosticsPlaybackCapabilities(
        matrix,
        checkedAt: capabilityProbe?.checkedAt,
        source: capabilityProbe?.source,
        cached: capabilityProbe?.cached ?? false,
      ),
    );
  }

  final String backendLabel;
  final String probeSource;
  final DateTime? probeCheckedAt;
  final bool probeCached;
  final Map<String, String> probeDetails;
  final PlaybackLifecycleStatus status;
  final Duration position;
  final Duration? duration;
  final bool isBuffering;
  final double? bufferedFraction;
  final String? sourceUri;
  final String? failureReason;
  final String? activeAudioTrackId;
  final String? activeSubtitleTrackId;
  final int subtitleTrackCount;
  final int activeSubtitleCueCount;
  final Duration subtitleOffset;
  final List<String> subtitleWarnings;
  final String? subtitleFailure;
  final Duration danmakuClockPosition;
  final int danmakuLaneCount;
  final int visibleDanmakuCommentCount;
  final List<String> danmakuWarnings;
  final String? danmakuFailure;
  final List<DiagnosticsCapabilityEntry> capabilities;
  final AVSyncHealth? avSyncHealth;
  final int? avSyncLatestDriftMillis;
  final int? avSyncSampleCount;
  final String? avSyncLatestDegradationAction;
  final String? avSyncSamplerFailure;
  final DateTime? avSyncLastSampledAt;

  String get avSyncHealthLabel {
    final AVSyncHealth? health = avSyncHealth;
    if (health == null) return '暂无样本';
    return switch (health) {
      AVSyncHealth.target => '目标内',
      AVSyncHealth.warning => '警告',
      AVSyncHealth.degraded => '已退化',
    };
  }
}

final class DiagnosticsDownloadTaskSnapshot {
  const DiagnosticsDownloadTaskSnapshot({
    required this.name,
    required this.state,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.uploadRateBytesPerSecond,
    required this.connectedPeers,
    required this.totalSizeBytes,
    required this.selectedFileCount,
    required this.fileCount,
    this.message,
  });

  final String name;
  final DownloadLifecycleState state;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int uploadRateBytesPerSecond;
  final int connectedPeers;
  final int totalSizeBytes;
  final int selectedFileCount;
  final int fileCount;
  final String? message;
}

final class DiagnosticsDownloadSnapshot {
  DiagnosticsDownloadSnapshot({
    required this.status,
    required this.totalTasks,
    required this.activeTasks,
    required this.pausedTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.totalDownloadRateBytesPerSecond,
    required this.totalUploadRateBytesPerSecond,
    required this.totalPeers,
    required Iterable<DiagnosticsCapabilityEntry> capabilities,
    required Iterable<DiagnosticsDownloadTaskSnapshot> tasks,
  })  : capabilities =
            List<DiagnosticsCapabilityEntry>.unmodifiable(capabilities),
        tasks = List<DiagnosticsDownloadTaskSnapshot>.unmodifiable(tasks);

  factory DiagnosticsDownloadSnapshot.fromRuntime(DownloadRuntime runtime) {
    final DownloadRuntimeSnapshot snapshot = runtime.currentSnapshot;
    final List<DownloadProjection> tasks = snapshot.tasks;
    return DiagnosticsDownloadSnapshot(
      status: snapshot.status,
      totalTasks: tasks.length,
      activeTasks: tasks.where(_downloadTaskIsActive).length,
      pausedTasks: tasks
          .where((DownloadProjection task) =>
              task.state == DownloadLifecycleState.paused)
          .length,
      completedTasks: tasks
          .where((DownloadProjection task) =>
              task.state == DownloadLifecycleState.completed)
          .length,
      failedTasks: tasks
          .where((DownloadProjection task) =>
              task.state == DownloadLifecycleState.failed)
          .length,
      totalDownloadRateBytesPerSecond: tasks.fold<int>(
        0,
        (int total, DownloadProjection task) =>
            total + task.downloadRateBytesPerSecond,
      ),
      totalUploadRateBytesPerSecond: tasks.fold<int>(
        0,
        (int total, DownloadProjection task) =>
            total + task.uploadRateBytesPerSecond,
      ),
      totalPeers: tasks.fold<int>(
        0,
        (int total, DownloadProjection task) => total + task.connectedPeers,
      ),
      capabilities: diagnosticsDownloadCapabilities(snapshot.capabilities),
      tasks: <DiagnosticsDownloadTaskSnapshot>[
        for (final DownloadProjection task in tasks)
          DiagnosticsDownloadTaskSnapshot(
            name: task.name,
            state: task.state,
            progress: task.progress,
            downloadRateBytesPerSecond: task.downloadRateBytesPerSecond,
            uploadRateBytesPerSecond: task.uploadRateBytesPerSecond,
            connectedPeers: task.connectedPeers,
            totalSizeBytes: task.totalSizeBytes,
            selectedFileCount: task.selectedFileCount,
            fileCount: task.files.length,
            message: task.message ?? task.latestEvent,
          ),
      ],
    );
  }

  final DownloadRuntimeStatus status;
  final int totalTasks;
  final int activeTasks;
  final int pausedTasks;
  final int completedTasks;
  final int failedTasks;
  final int totalDownloadRateBytesPerSecond;
  final int totalUploadRateBytesPerSecond;
  final int totalPeers;
  final List<DiagnosticsCapabilityEntry> capabilities;
  final List<DiagnosticsDownloadTaskSnapshot> tasks;
}

final class DiagnosticsRssSnapshot {
  DiagnosticsRssSnapshot({
    required this.status,
    required this.sourceCount,
    required this.dueSourceCount,
    required this.acceptedItemCount,
    required this.latestRefreshCount,
    required this.refreshFailureCount,
    required this.autoRuleCount,
    required Iterable<String> failures,
  }) : failures = List<String>.unmodifiable(failures);

  static Future<DiagnosticsRssSnapshot> fromRuntime(
    RssEngineRuntime runtime,
  ) async {
    final RssEngineRuntimeSnapshot snapshot = runtime.currentSnapshot;
    int autoRuleCount = 0;
    for (final FeedSource source in snapshot.sources) {
      final RssEngineActionResult<List<RssAutoDownloadRuleProjection>> rules =
          await runtime.autoDownloadRulesForSource(source.id.value);
      if (rules.isSuccess) {
        autoRuleCount += rules.value?.length ?? 0;
      }
    }
    return DiagnosticsRssSnapshot(
      status: snapshot.status,
      sourceCount: snapshot.sources.length,
      dueSourceCount: snapshot.dueSources.length,
      acceptedItemCount: snapshot.acceptedItems.length,
      latestRefreshCount: snapshot.latestRefreshes.length,
      refreshFailureCount: snapshot.latestRefreshes.values
          .where((RssRefreshOutcome outcome) => !outcome.isSuccess)
          .length,
      autoRuleCount: autoRuleCount,
      failures: <String>[
        for (final RssEngineRuntimeFailure failure in snapshot.failures)
          failure.message,
        for (final RssRefreshOutcome outcome in snapshot.latestRefreshes.values)
          if (!outcome.isSuccess) outcome.failure!.message,
      ],
    );
  }

  final RssEngineRuntimeStatus status;
  final int sourceCount;
  final int dueSourceCount;
  final int acceptedItemCount;
  final int latestRefreshCount;
  final int refreshFailureCount;
  final int autoRuleCount;
  final List<String> failures;
}

final class DiagnosticsMediaLibrarySnapshot {
  DiagnosticsMediaLibrarySnapshot({
    required this.status,
    required this.catalogItemCount,
    required this.continueWatchingCount,
    required this.bangumiBoundCount,
    required this.scanEventCount,
    required Iterable<String> failureMessages,
  }) : failureMessages = List<String>.unmodifiable(failureMessages);

  factory DiagnosticsMediaLibrarySnapshot.fromRuntime(
    MediaLibraryRuntime runtime,
  ) {
    final MediaLibraryRuntimeSnapshot snapshot = runtime.currentSnapshot;
    return DiagnosticsMediaLibrarySnapshot(
      status: snapshot.status,
      catalogItemCount: snapshot.catalogItems.length,
      continueWatchingCount: snapshot.continueWatching.length,
      bangumiBoundCount: snapshot.catalogItems
          .where((MediaLibraryCatalogItemState item) =>
              item.binding?.subjectId != null)
          .length,
      scanEventCount: snapshot.scanEvents.length,
      failureMessages: <String>[
        for (final MediaLibraryRuntimeFailure failure in snapshot.failures)
          failure.message,
      ],
    );
  }

  final MediaLibraryRuntimeStatus status;
  final int catalogItemCount;
  final int continueWatchingCount;
  final int bangumiBoundCount;
  final int scanEventCount;
  final List<String> failureMessages;
}

final class DiagnosticsProviderNetworkSnapshot {
  const DiagnosticsProviderNetworkSnapshot({
    required this.bangumiTokenConfigured,
    required this.bangumiMirrorEnabled,
    required this.bangumiMirrorApiBaseUrl,
    required this.bangumiMirrorImageBaseUrl,
    required this.bangumiMirrorValid,
    required this.httpProxyUrl,
    required this.dnsPolicy,
    required this.providerNetworkEventCount,
    this.failureMessage,
  });

  static Future<DiagnosticsProviderNetworkSnapshot> fromSettings({
    required SettingsRuntime settingsRuntime,
    required Iterable<DiagnosticsEventProjection> events,
  }) async {
    final String? token = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.bangumiAccessToken);
    final String? mirrorEnabledValue = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.bangumiMirrorEnabled);
    final bool mirrorEnabled =
        BangumiMirrorSettings.isEnabled(mirrorEnabledValue);
    final String? apiBaseUrl = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.bangumiMirrorApiBaseUrl);
    final String? imageBaseUrl = await settingsRuntime
        .getPreference(SettingsPreferenceKeys.bangumiMirrorImageBaseUrl);
    bool mirrorValid = !mirrorEnabled;
    String? failureMessage;
    if (mirrorEnabled) {
      try {
        BangumiMirrorSettings.parseBaseUri(
          apiBaseUrl ?? '',
          fieldName: 'Bangumi API 镜像地址',
        );
        BangumiMirrorSettings.parseBaseUri(
          imageBaseUrl ?? '',
          fieldName: 'Bangumi 图片镜像地址',
        );
        mirrorValid = true;
      } on FormatException catch (error) {
        failureMessage = error.message;
      }
    }
    final String? proxy = await settingsRuntime.getProxyUrl();
    final String? dns = await settingsRuntime.getDnsPolicy();
    return DiagnosticsProviderNetworkSnapshot(
      bangumiTokenConfigured: token?.trim().isNotEmpty ?? false,
      bangumiMirrorEnabled: mirrorEnabled,
      bangumiMirrorApiBaseUrl: apiBaseUrl,
      bangumiMirrorImageBaseUrl: imageBaseUrl,
      bangumiMirrorValid: mirrorValid,
      httpProxyUrl: proxy,
      dnsPolicy: dns,
      providerNetworkEventCount: events
          .where((DiagnosticsEventProjection event) =>
              _containsAny(event.sourceModule, _providerNetworkTerms) ||
              _containsAny(event.eventType, _providerNetworkTerms) ||
              _containsAny(event.payloadText, _providerNetworkTerms))
          .length,
      failureMessage: failureMessage,
    );
  }

  final bool bangumiTokenConfigured;
  final bool bangumiMirrorEnabled;
  final String? bangumiMirrorApiBaseUrl;
  final String? bangumiMirrorImageBaseUrl;
  final bool bangumiMirrorValid;
  final String? httpProxyUrl;
  final String? dnsPolicy;
  final int providerNetworkEventCount;
  final String? failureMessage;
}

final class DiagnosticsWorkbenchSnapshot {
  const DiagnosticsWorkbenchSnapshot({
    required this.sample,
    required this.events,
    required this.diagnosticsCapabilities,
    required this.modules,
    required this.playback,
    required this.downloads,
    required this.rss,
    required this.mediaLibrary,
    required this.providerNetwork,
  });

  factory DiagnosticsWorkbenchSnapshot.empty() {
    return DiagnosticsWorkbenchSnapshot(
      sample: DiagnosticsTelemetrySample(
        sampledAt: DateTime.fromMillisecondsSinceEpoch(0),
        memoryUsageBytes: 0,
        avSyncDriftMillis: 0,
      ),
      events: const <DiagnosticsEventProjection>[],
      diagnosticsCapabilities: const <String, String>{},
      modules: const <DiagnosticsModuleSnapshot>[],
      playback: null,
      downloads: null,
      rss: null,
      mediaLibrary: null,
      providerNetwork: null,
    );
  }

  final DiagnosticsTelemetrySample sample;
  final List<DiagnosticsEventProjection> events;
  final Map<String, String> diagnosticsCapabilities;
  final List<DiagnosticsModuleSnapshot> modules;
  final DiagnosticsPlaybackSnapshot? playback;
  final DiagnosticsDownloadSnapshot? downloads;
  final DiagnosticsRssSnapshot? rss;
  final DiagnosticsMediaLibrarySnapshot? mediaLibrary;
  final DiagnosticsProviderNetworkSnapshot? providerNetwork;
}

abstract interface class DiagnosticsWorkbenchRuntime {
  Future<DiagnosticsWorkbenchSnapshot> snapshot();
}

/// Read-only cross-module diagnostics facade.
///
/// The workbench samples existing projections and settings so diagnostics can
/// explain the app state without gaining authority to control playback,
/// downloads, RSS, providers, or storage. That separation is what keeps this
/// page from becoming a second, inconsistent business runtime.
final class DefaultDiagnosticsWorkbenchRuntime
    implements DiagnosticsWorkbenchRuntime {
  const DefaultDiagnosticsWorkbenchRuntime({
    required DiagnosticsRuntime diagnosticsRuntime,
    required PlaybackControllerContract playbackController,
    required DownloadRuntime downloadRuntime,
    required RssEngineRuntime rssEngineRuntime,
    required MediaLibraryRuntime mediaLibraryRuntime,
    required SettingsRuntime settingsRuntime,
    DiagnosticsBackendProbeRuntime? backendProbeRuntime,
    AVSyncGuardMonitorRuntime? avSyncGuardMonitorRuntime,
  })  : _diagnosticsRuntime = diagnosticsRuntime,
        _playbackController = playbackController,
        _downloadRuntime = downloadRuntime,
        _rssEngineRuntime = rssEngineRuntime,
        _mediaLibraryRuntime = mediaLibraryRuntime,
        _settingsRuntime = settingsRuntime,
        _backendProbeRuntime = backendProbeRuntime,
        _avSyncGuardMonitorRuntime = avSyncGuardMonitorRuntime;

  final DiagnosticsRuntime _diagnosticsRuntime;
  final PlaybackControllerContract _playbackController;
  final DownloadRuntime _downloadRuntime;
  final RssEngineRuntime _rssEngineRuntime;
  final MediaLibraryRuntime _mediaLibraryRuntime;
  final SettingsRuntime _settingsRuntime;
  final DiagnosticsBackendProbeRuntime? _backendProbeRuntime;
  final AVSyncGuardMonitorRuntime? _avSyncGuardMonitorRuntime;

  @override
  Future<DiagnosticsWorkbenchSnapshot> snapshot() async {
    final List<DiagnosticsEventProjection> events =
        await _diagnosticsRuntime.queryEvents();
    final DateTime sampledAt = DateTime.now();
    final DiagnosticsTelemetrySample sample = DiagnosticsTelemetrySample(
      sampledAt: sampledAt,
      memoryUsageBytes: _diagnosticsRuntime.getActiveMemoryUsageBytes(),
      avSyncDriftMillis: await _diagnosticsRuntime.getLatestAvSyncDrift(),
    );
    final Map<String, String> diagnosticsCapabilities =
        _diagnosticsRuntime.getCapabilitiesSupportStatus();
    final _ModuleResult<DiagnosticsBackendProbeSnapshot> backendProbe =
        await _sampleModule(
      () async => _backendProbeRuntime == null
          ? _unavailableBackendProbeSnapshot()
          : await _backendProbeRuntime.probe(),
    );
    final DiagnosticsBackendProbeSnapshot probeSnapshot =
        backendProbe.value ?? _unavailableBackendProbeSnapshot();

    final _ModuleResult<DiagnosticsPlaybackSnapshot> playback =
        await _sampleModule(
      () async => DiagnosticsPlaybackSnapshot.fromController(
        _playbackController,
        capabilityProbe: probeSnapshot.playback,
        avSyncMonitor: _avSyncGuardMonitorRuntime?.snapshot,
      ),
    );
    final _ModuleResult<DiagnosticsDownloadSnapshot> downloads =
        await _sampleModule(
      () async => DiagnosticsDownloadSnapshot.fromRuntime(_downloadRuntime),
    );
    final _ModuleResult<DiagnosticsRssSnapshot> rss = await _sampleModule(
      () => DiagnosticsRssSnapshot.fromRuntime(_rssEngineRuntime),
    );
    final _ModuleResult<DiagnosticsMediaLibrarySnapshot> mediaLibrary =
        await _sampleModule(
      () async => DiagnosticsMediaLibrarySnapshot.fromRuntime(
        _mediaLibraryRuntime,
      ),
    );
    final _ModuleResult<DiagnosticsProviderNetworkSnapshot> providerNetwork =
        await _sampleModule(
      () => DiagnosticsProviderNetworkSnapshot.fromSettings(
        settingsRuntime: _settingsRuntime,
        events: events,
      ),
    );

    return DiagnosticsWorkbenchSnapshot(
      sample: sample,
      events: List<DiagnosticsEventProjection>.unmodifiable(events.reversed),
      diagnosticsCapabilities:
          Map<String, String>.unmodifiable(diagnosticsCapabilities),
      modules: <DiagnosticsModuleSnapshot>[
        _overviewModule(events, sample),
        _playbackModule(playback),
        _downloadModule(downloads, probeSnapshot.downloads),
        _rssModule(rss, probeSnapshot.rss),
        _mediaLibraryModule(mediaLibrary, probeSnapshot.mediaLibrary),
        _providerNetworkModule(providerNetwork, probeSnapshot.providerNetwork),
        _eventsModule(events),
      ],
      playback: playback.value,
      downloads: downloads.value,
      rss: rss.value,
      mediaLibrary: mediaLibrary.value,
      providerNetwork: providerNetwork.value,
    );
  }
}

final class _ModuleResult<T> {
  const _ModuleResult.value(this.value) : failureMessage = null;

  const _ModuleResult.failure(this.failureMessage) : value = null;

  final T? value;
  final String? failureMessage;
}

Future<_ModuleResult<T>> _sampleModule<T>(Future<T> Function() read) async {
  try {
    return _ModuleResult<T>.value(await read());
  } on Object catch (error) {
    return _ModuleResult<T>.failure(error.toString());
  }
}

DiagnosticsBackendProbeSnapshot _unavailableBackendProbeSnapshot() {
  final DateTime checkedAt = DateTime.now();
  DiagnosticsBackendProbeModuleSnapshot module(String id, String label) {
    return DiagnosticsBackendProbeModuleSnapshot(
      id: id,
      label: label,
      supported: false,
      message: '未注入真实后端探测 runtime',
      checkedAt: checkedAt,
      source: diagnosticsProbeSourceUnavailable,
    );
  }

  return DiagnosticsBackendProbeSnapshot(
    playback: null,
    downloads: module(diagnosticsModuleDownloads, '下载'),
    rss: module(diagnosticsModuleRss, 'RSS'),
    mediaLibrary: module(diagnosticsModuleMediaLibrary, '本地媒体库'),
    providerNetwork: module(diagnosticsModuleProviderNetwork, 'Provider/网络'),
  );
}

DiagnosticsModuleSnapshot _overviewModule(
  List<DiagnosticsEventProjection> events,
  DiagnosticsTelemetrySample sample,
) {
  final int errorCount = events
      .where((DiagnosticsEventProjection event) =>
          event.severity.toLowerCase() == 'error')
      .length;
  final int warningCount = events
      .where((DiagnosticsEventProjection event) =>
          event.severity.toLowerCase() == 'warning')
      .length;
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleOverview,
    label: '总览',
    health: errorCount > 0
        ? DiagnosticsModuleHealth.failed
        : warningCount > 0
            ? DiagnosticsModuleHealth.warning
            : DiagnosticsModuleHealth.healthy,
    summary: '内存 ${sample.memoryUsageBytes} B，事件 ${events.length} 条',
  );
}

DiagnosticsModuleSnapshot _playbackModule(
  _ModuleResult<DiagnosticsPlaybackSnapshot> result,
) {
  final DiagnosticsPlaybackSnapshot? playback = result.value;
  if (playback == null) {
    return _failedModule(
        diagnosticsModulePlayback, '播放', result.failureMessage);
  }
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModulePlayback,
    label: '播放',
    health: playback.failureReason == null
        ? DiagnosticsModuleHealth.healthy
        : DiagnosticsModuleHealth.failed,
    summary: '${playback.status.name} · ${playback.sourceUri ?? '无播放源'}',
    failureMessage: playback.failureReason,
  );
}

DiagnosticsModuleSnapshot _downloadModule(
  _ModuleResult<DiagnosticsDownloadSnapshot> result,
  DiagnosticsBackendProbeModuleSnapshot probe,
) {
  final DiagnosticsDownloadSnapshot? downloads = result.value;
  if (downloads == null) {
    return _failedModule(
        diagnosticsModuleDownloads, '下载', result.failureMessage);
  }
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleDownloads,
    label: '下载',
    health: downloads.failedTasks > 0 || !probe.supported
        ? DiagnosticsModuleHealth.failed
        : DiagnosticsModuleHealth.healthy,
    summary: '${downloads.totalTasks} 个任务，${downloads.failedTasks} 个失败',
  );
}

DiagnosticsModuleSnapshot _rssModule(
  _ModuleResult<DiagnosticsRssSnapshot> result,
  DiagnosticsBackendProbeModuleSnapshot probe,
) {
  final DiagnosticsRssSnapshot? rss = result.value;
  if (rss == null) {
    return _failedModule(diagnosticsModuleRss, 'RSS', result.failureMessage);
  }
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleRss,
    label: 'RSS',
    health: rss.failures.isEmpty && probe.supported
        ? DiagnosticsModuleHealth.healthy
        : DiagnosticsModuleHealth.failed,
    summary: '${rss.sourceCount} 个订阅，${rss.dueSourceCount} 个待刷新',
    failureMessage: rss.failures.isEmpty ? null : rss.failures.first,
  );
}

DiagnosticsModuleSnapshot _mediaLibraryModule(
  _ModuleResult<DiagnosticsMediaLibrarySnapshot> result,
  DiagnosticsBackendProbeModuleSnapshot probe,
) {
  final DiagnosticsMediaLibrarySnapshot? library = result.value;
  if (library == null) {
    return _failedModule(
      diagnosticsModuleMediaLibrary,
      '本地媒体库',
      result.failureMessage,
    );
  }
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleMediaLibrary,
    label: '本地媒体库',
    health: library.failureMessages.isEmpty && probe.supported
        ? DiagnosticsModuleHealth.healthy
        : DiagnosticsModuleHealth.failed,
    summary: '${library.catalogItemCount} 个索引，'
        '${library.bangumiBoundCount} 个 Bangumi 绑定',
    failureMessage:
        library.failureMessages.isEmpty ? null : library.failureMessages.first,
  );
}

DiagnosticsModuleSnapshot _providerNetworkModule(
  _ModuleResult<DiagnosticsProviderNetworkSnapshot> result,
  DiagnosticsBackendProbeModuleSnapshot probe,
) {
  final DiagnosticsProviderNetworkSnapshot? providerNetwork = result.value;
  if (providerNetwork == null) {
    return _failedModule(
      diagnosticsModuleProviderNetwork,
      'Provider/网络',
      result.failureMessage,
    );
  }
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleProviderNetwork,
    label: 'Provider/网络',
    health: providerNetwork.failureMessage == null && probe.supported
        ? DiagnosticsModuleHealth.healthy
        : DiagnosticsModuleHealth.failed,
    summary:
        providerNetwork.bangumiMirrorEnabled ? 'Bangumi 镜像已开启' : 'Bangumi 镜像关闭',
    failureMessage: providerNetwork.failureMessage,
  );
}

DiagnosticsModuleSnapshot _eventsModule(
    List<DiagnosticsEventProjection> events) {
  return DiagnosticsModuleSnapshot(
    id: diagnosticsModuleEvents,
    label: '事件日志',
    health: DiagnosticsModuleHealth.healthy,
    summary: '${events.length} 条诊断事件',
  );
}

DiagnosticsModuleSnapshot _failedModule(
  String id,
  String label,
  String? message,
) {
  return DiagnosticsModuleSnapshot(
    id: id,
    label: label,
    health: DiagnosticsModuleHealth.failed,
    summary: '采样失败',
    failureMessage: message ?? '模块采样失败。',
  );
}

bool _downloadTaskIsActive(DownloadProjection task) {
  return switch (task.state) {
    DownloadLifecycleState.queued ||
    DownloadLifecycleState.fetchingMetadata ||
    DownloadLifecycleState.ready ||
    DownloadLifecycleState.downloading =>
      true,
    DownloadLifecycleState.paused ||
    DownloadLifecycleState.completed ||
    DownloadLifecycleState.failed =>
      false,
  };
}

List<DiagnosticsCapabilityEntry> diagnosticsPlaybackCapabilities(
  PlaybackCapabilityMatrix matrix, {
  DateTime? checkedAt,
  String? source,
  bool cached = false,
}) {
  return <DiagnosticsCapabilityEntry>[
    for (final PlaybackCapability capability in PlaybackCapability.values)
      DiagnosticsCapabilityEntry(
        id: capability.name,
        label: _playbackCapabilityLabel(capability),
        supported: matrix.supports(capability),
        reason: matrix.statusOf(capability).reason,
        checkedAt: checkedAt,
        source: source,
        cached: cached,
      ),
  ];
}

List<DiagnosticsCapabilityEntry> diagnosticsDownloadCapabilities(
  DownloadCapabilityProjection capabilities,
) {
  return <DiagnosticsCapabilityEntry>[
    DiagnosticsCapabilityEntry(
      id: 'taskManagement',
      label: '任务管理',
      supported: capabilities.taskManagementAvailable,
      reason: capabilities.taskManagementReason,
    ),
    DiagnosticsCapabilityEntry(
      id: 'metadataFetching',
      label: '元数据获取',
      supported: capabilities.metadataFetchingAvailable,
      reason: capabilities.metadataFetchingReason,
    ),
    DiagnosticsCapabilityEntry(
      id: 'backgroundDownload',
      label: '后台下载',
      supported: capabilities.backgroundDownloadAvailable,
      reason: capabilities.backgroundDownloadReason,
    ),
    DiagnosticsCapabilityEntry(
      id: 'virtualStream',
      label: '虚拟流',
      supported: capabilities.virtualStreamAvailable,
      reason: capabilities.virtualStreamReason,
    ),
  ];
}

String _playbackCapabilityLabel(PlaybackCapability capability) {
  return switch (capability) {
    PlaybackCapability.localFilePlayback => '本地文件播放',
    PlaybackCapability.httpPlayback => 'HTTP 播放',
    PlaybackCapability.hlsPlayback => 'HLS 播放',
    PlaybackCapability.playPause => '播放/暂停',
    PlaybackCapability.seek => '进度跳转',
    PlaybackCapability.stop => '停止播放',
    PlaybackCapability.progressReporting => '进度报告',
    PlaybackCapability.audioTrackDiscovery => '音轨发现',
    PlaybackCapability.audioTrackSwitching => '音轨切换',
    PlaybackCapability.subtitleTrackDiscovery => '字幕轨发现',
    PlaybackCapability.subtitleTrackSwitching => '字幕轨切换',
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

const List<String> _providerNetworkTerms = <String>[
  'provider',
  'gateway',
  'network',
  'bangumi',
  'proxy',
  'dns',
];

bool _containsAny(String value, Iterable<String> terms) {
  final String normalized = value.toLowerCase();
  return terms.any(normalized.contains);
}
