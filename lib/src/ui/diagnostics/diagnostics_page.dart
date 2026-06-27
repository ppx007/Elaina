import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/diagnostics/diagnostics_domain.dart';
import '../../domain/diagnostics/diagnostics_workbench.dart';
import '../../domain/playback/playback_state.dart';
import '../../foundation/constants.dart';
import '../testing/ui_element_ids.dart';
import '../theme/elaina_theme.dart';

const Duration diagnosticsDefaultRefreshInterval = Duration(seconds: 5);
const int diagnosticsDefaultHistoryLimit = 60;

const double _pagePadding = 24;
const double _sectionGap = 16;
const double _panelGap = 16;
const double _panelPadding = 16;
const double _panelRadius = 8;
const double _compactBreakpoint = 900;
const double _moduleRailWidth = 236;
const double _metricMinWidth = 172;
const double _chartHeight = 132;
const double _tableMinWidth = 780;
const double _tableRowHeight = 44;
const double _smallIconSize = 18;
const double _avExcellentDriftMillis = 40;
const double _avDegradedDriftMillis = 120;
const int _bytesPerMegabyte = 1024 * 1024;
const int _bytesPerKilobyte = 1024;
const int _timePartWidth = 2;
const String _timePartPad = '0';

/// Read-only diagnostics workbench.
///
/// The page intentionally receives one aggregated workbench snapshot instead of
/// constructing business runtimes itself. Diagnostics should explain the system
/// state with high detail, but it must not become a second control surface for
/// playback, downloads, RSS, providers, or storage.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    super.key,
    required this.diagnosticsWorkbenchRuntime,
    this.isActive = true,
    this.refreshInterval = diagnosticsDefaultRefreshInterval,
    this.historyLimit = diagnosticsDefaultHistoryLimit,
  });

  final DiagnosticsWorkbenchRuntime diagnosticsWorkbenchRuntime;
  final bool isActive;
  final Duration refreshInterval;
  final int historyLimit;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  final TextEditingController _eventFilterController = TextEditingController();
  final List<DiagnosticsTelemetrySample> _history =
      <DiagnosticsTelemetrySample>[];
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  String? _lastError;
  DateTime? _lastRefreshedAt;
  String _selectedModuleId = diagnosticsModuleOverview;
  String? _selectedEventId;
  DiagnosticsWorkbenchSnapshot _snapshot = DiagnosticsWorkbenchSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _eventFilterController.addListener(_onFilterChanged);
    if (widget.isActive) {
      unawaited(_refreshData(showInitialLoading: true));
    }
    _syncRefreshTimer();
  }

  @override
  void didUpdateWidget(DiagnosticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _syncRefreshTimer();
      if (!oldWidget.isActive && widget.isActive) {
        unawaited(_refreshData());
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _eventFilterController
      ..removeListener(_onFilterChanged)
      ..dispose();
    super.dispose();
  }

  void _syncRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!widget.isActive) return;
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      unawaited(_refreshData());
    });
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshData({bool showInitialLoading = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final DiagnosticsWorkbenchSnapshot rawSnapshot =
          await widget.diagnosticsWorkbenchRuntime.snapshot();
      final DiagnosticsWorkbenchSnapshot cappedSnapshot =
          _withCappedEvents(rawSnapshot);
      if (!mounted) return;
      setState(() {
        _snapshot = cappedSnapshot;
        _history.add(cappedSnapshot.sample);
        _trimHistory();
        _lastError = null;
        _lastRefreshedAt = cappedSnapshot.sample.sampledAt;
        _hasLoaded = true;
        _isRefreshing = false;
        _selectedEventId = _visibleEvents().any(
          (DiagnosticsEventProjection event) => event.id == _selectedEventId,
        )
            ? _selectedEventId
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '刷新诊断数据失败：$error';
        _hasLoaded = _hasLoaded || !showInitialLoading;
        _isRefreshing = false;
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  DiagnosticsWorkbenchSnapshot _withCappedEvents(
    DiagnosticsWorkbenchSnapshot snapshot,
  ) {
    final List<DiagnosticsEventProjection> events = snapshot.events;
    final List<DiagnosticsEventProjection> capped =
        events.length <= AppConstants.diagnosticsPageMaxDisplayEvents
            ? events
            : events
                .take(AppConstants.diagnosticsPageMaxDisplayEvents)
                .toList(growable: false);
    return DiagnosticsWorkbenchSnapshot(
      sample: snapshot.sample,
      events: List<DiagnosticsEventProjection>.unmodifiable(capped),
      diagnosticsCapabilities: snapshot.diagnosticsCapabilities,
      modules: snapshot.modules,
      playback: snapshot.playback,
      downloads: snapshot.downloads,
      rss: snapshot.rss,
      mediaLibrary: snapshot.mediaLibrary,
      providerNetwork: snapshot.providerNetwork,
    );
  }

  void _trimHistory() {
    final int limit = math.max(1, widget.historyLimit);
    if (_history.length <= limit) return;
    _history.removeRange(0, _history.length - limit);
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    if (!_hasLoaded && _isRefreshing) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < _compactBreakpoint;
        return Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildHeader(theme)),
              if (_lastError != null)
                SliverToBoxAdapter(child: _buildErrorBanner(theme)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: _sectionGap),
                  child: compact
                      ? _buildCompactWorkbench(theme)
                      : _buildWideWorkbench(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ElainaThemeData theme) {
    final String refreshText = _lastRefreshedAt == null
        ? '尚未刷新'
        : '上次刷新 ${_formatClock(_lastRefreshedAt!)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '诊断工作台',
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusPill(
                    key: const ValueKey<String>(
                      UiElementIds.diagnosticsAutoRefreshStatus,
                    ),
                    label: widget.isActive ? '自动刷新中' : '自动刷新已暂停',
                    icon: widget.isActive
                        ? Icons.sync_outlined
                        : Icons.pause_circle_outline,
                    color: widget.isActive ? theme.primary : theme.secondary,
                    theme: theme,
                  ),
                  _StatusPill(
                    label: refreshText,
                    icon: Icons.schedule_outlined,
                    color: theme.onBackground.withValues(alpha: 0.7),
                    theme: theme,
                  ),
                  if (_isRefreshing)
                    _StatusPill(
                      label: '刷新中',
                      icon: Icons.hourglass_top_outlined,
                      color: theme.primary,
                      theme: theme,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: _panelGap),
        Tooltip(
          message: '刷新诊断数据',
          child: IconButton.filledTonal(
            key: const ValueKey<String>(UiElementIds.diagnosticsRefresh),
            onPressed: _isRefreshing ? null : () => unawaited(_refreshData()),
            icon: const Icon(Icons.refresh, size: _smallIconSize),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(ElainaThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: _sectionGap),
      child: DecoratedBox(
        key: const ValueKey<String>(UiElementIds.diagnosticsErrorBanner),
        decoration: BoxDecoration(
          color: theme.accentMagenta.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_panelRadius),
          border:
              Border.all(color: theme.accentMagenta.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: theme.accentMagenta, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _lastError!,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideWorkbench(ElainaThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: _moduleRailWidth, child: _buildModuleRail(theme)),
        const SizedBox(width: _panelGap),
        Expanded(child: _buildSelectedModule(theme)),
      ],
    );
  }

  Widget _buildCompactWorkbench(ElainaThemeData theme) {
    return Column(
      children: <Widget>[
        _buildModuleRail(theme, horizontal: true),
        const SizedBox(height: _panelGap),
        _buildSelectedModule(theme),
      ],
    );
  }

  Widget _buildModuleRail(ElainaThemeData theme, {bool horizontal = false}) {
    final List<DiagnosticsModuleSnapshot> modules = _snapshot.modules.isEmpty
        ? const <DiagnosticsModuleSnapshot>[
            DiagnosticsModuleSnapshot(
              id: diagnosticsModuleOverview,
              label: '总览',
              health: DiagnosticsModuleHealth.warning,
              summary: '等待首次采样',
            ),
          ]
        : _snapshot.modules;

    // The rail is the page's information architecture. Keeping modules here
    // prevents the workbench from regressing into a single endless diagnostics
    // feed where playback, RSS, downloads, and provider state compete for space.
    final Widget content = horizontal
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final DiagnosticsModuleSnapshot module in modules)
                _ModuleNavItem(
                  module: module,
                  selected: module.id == _selectedModuleId,
                  theme: theme,
                  onTap: () => setState(() {
                    _selectedModuleId = module.id;
                  }),
                ),
            ],
          )
        : Column(
            children: <Widget>[
              for (final DiagnosticsModuleSnapshot module in modules) ...[
                _ModuleNavItem(
                  module: module,
                  selected: module.id == _selectedModuleId,
                  theme: theme,
                  onTap: () => setState(() {
                    _selectedModuleId = module.id;
                  }),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );

    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsModuleNav),
      title: '模块',
      theme: theme,
      child: content,
    );
  }

  Widget _buildSelectedModule(ElainaThemeData theme) {
    return switch (_selectedModuleId) {
      diagnosticsModulePlayback => _buildPlaybackPanel(theme),
      diagnosticsModuleDownloads => _buildDownloadPanel(theme),
      diagnosticsModuleRss => _buildRssPanel(theme),
      diagnosticsModuleMediaLibrary => _buildMediaLibraryPanel(theme),
      diagnosticsModuleProviderNetwork => _buildProviderNetworkPanel(theme),
      diagnosticsModuleEvents => _buildEventsPanel(theme),
      _ => _buildOverviewPanel(theme),
    };
  }

  Widget _buildOverviewPanel(ElainaThemeData theme) {
    final DiagnosticsEventBuckets buckets =
        DiagnosticsEventBuckets.fromEvents(_snapshot.events);
    final DiagnosticsCapabilitySummary summary =
        DiagnosticsCapabilitySummary.fromCapabilities(
      _snapshot.diagnosticsCapabilities,
    );
    return Column(
      key: const ValueKey<String>(UiElementIds.diagnosticsOverviewPanel),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: _panelGap,
          runSpacing: _panelGap,
          children: <Widget>[
            _MetricTile(
              width: _metricMinWidth,
              title: '内存占用',
              value: _formatMemory(_snapshot.sample.memoryUsageBytes),
              icon: Icons.memory_outlined,
              color: theme.primary,
              theme: theme,
            ),
            _MetricTile(
              width: _metricMinWidth,
              title: 'AV 漂移',
              value:
                  '${_snapshot.sample.avSyncDriftMillis.toStringAsFixed(1)} ms',
              subtitle: _driftStatus(_snapshot.sample.avSyncDriftMillis),
              icon: Icons.graphic_eq_outlined,
              color: _driftColor(theme, _snapshot.sample.avSyncDriftMillis),
              theme: theme,
            ),
            _MetricTile(
              width: _metricMinWidth,
              title: '事件总数',
              value: _snapshot.events.length.toString(),
              icon: Icons.receipt_long_outlined,
              color: theme.secondary,
              theme: theme,
            ),
            _MetricTile(
              width: _metricMinWidth,
              title: '能力支持',
              value: '${summary.supported}/${summary.total}',
              icon: Icons.fact_check_outlined,
              color: theme.primary,
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: _sectionGap),
        _buildTelemetryPanel(theme),
        const SizedBox(height: _sectionGap),
        _buildEventDistributionPanel(theme, buckets),
      ],
    );
  }

  Widget _buildTelemetryPanel(ElainaThemeData theme) {
    final List<double> memoryValues = <double>[
      for (final DiagnosticsTelemetrySample sample in _history)
        sample.memoryUsageBytes / _bytesPerMegabyte,
    ];
    final List<double> driftValues = <double>[
      for (final DiagnosticsTelemetrySample sample in _history)
        sample.avSyncDriftMillis.abs(),
    ];
    return _Panel(
      title: '系统状态',
      theme: theme,
      child: Column(
        children: <Widget>[
          _ChartFrame(
            key: const ValueKey<String>(UiElementIds.diagnosticsMemoryChart),
            title: '内存趋势',
            valueLabel: _formatMemory(_snapshot.sample.memoryUsageBytes),
            theme: theme,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: memoryValues,
                lineColor: theme.primary,
                fillColor: theme.primary.withValues(alpha: 0.12),
                gridColor: theme.border.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(height: _panelGap),
          _ChartFrame(
            key: const ValueKey<String>(UiElementIds.diagnosticsDriftChart),
            title: 'AV 漂移趋势',
            valueLabel:
                '${_snapshot.sample.avSyncDriftMillis.toStringAsFixed(1)} ms',
            theme: theme,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: driftValues,
                lineColor:
                    _driftColor(theme, _snapshot.sample.avSyncDriftMillis),
                fillColor: _driftColor(
                  theme,
                  _snapshot.sample.avSyncDriftMillis,
                ).withValues(alpha: 0.12),
                gridColor: theme.border.withValues(alpha: 0.45),
                threshold: _avDegradedDriftMillis,
                thresholdColor: theme.accentMagenta.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDistributionPanel(
    ElainaThemeData theme,
    DiagnosticsEventBuckets buckets,
  ) {
    return _Panel(
      title: '事件分布',
      theme: theme,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < _compactBreakpoint;
          final List<Widget> charts = <Widget>[
            _ChartFrame(
              key: const ValueKey<String>(
                UiElementIds.diagnosticsSeverityChart,
              ),
              title: '级别分布',
              valueLabel: '${_snapshot.events.length} 条',
              theme: theme,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: buckets.severityCounts,
                  colors: _severityColors(theme),
                  labelColor: theme.onBackground.withValues(alpha: 0.74),
                  gridColor: theme.border.withValues(alpha: 0.45),
                ),
              ),
            ),
            _ChartFrame(
              key: const ValueKey<String>(UiElementIds.diagnosticsModuleChart),
              title: '模块分布',
              valueLabel: '${buckets.moduleCounts.length} 个模块',
              theme: theme,
              child: CustomPaint(
                painter: _HorizontalBarChartPainter(
                  values: buckets.topModuleCounts,
                  barColor: theme.secondary,
                  labelColor: theme.onBackground.withValues(alpha: 0.74),
                  gridColor: theme.border.withValues(alpha: 0.45),
                ),
              ),
            ),
          ];
          if (compact) {
            return Column(
              children: <Widget>[
                charts[0],
                const SizedBox(height: _panelGap),
                charts[1],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: charts[0]),
              const SizedBox(width: _panelGap),
              Expanded(child: charts[1]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaybackPanel(ElainaThemeData theme) {
    final DiagnosticsPlaybackSnapshot? playback = _snapshot.playback;
    if (playback == null) {
      return _missingModulePanel(
        key: UiElementIds.diagnosticsPlaybackPanel,
        title: '播放',
        theme: theme,
      );
    }
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsPlaybackPanel),
      title: '播放诊断',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _panelGap,
            runSpacing: _panelGap,
            children: <Widget>[
              _MetricTile(
                width: _metricMinWidth,
                title: '状态',
                value: _playbackStatusLabel(playback.status),
                icon: Icons.play_circle_outline,
                color: _moduleColor(theme, _playbackHealth(playback)),
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '进度',
                value:
                    '${_formatDuration(playback.position)} / ${_formatOptionalDuration(playback.duration)}',
                icon: Icons.timeline_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '缓冲',
                value: playback.isBuffering ? '缓冲中' : '正常',
                subtitle: _formatFraction(playback.bufferedFraction),
                icon: Icons.slow_motion_video_outlined,
                color: playback.isBuffering ? theme.secondary : theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '弹幕',
                value: '${playback.visibleDanmakuCommentCount} 条',
                subtitle: '${playback.danmakuLaneCount} 轨道',
                icon: Icons.chat_bubble_outline,
                color: theme.secondary,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          _InfoGrid(
            rows: <_InfoRow>[
              _InfoRow('播放后端', playback.backendLabel),
              _InfoRow('探测来源', playback.probeSource),
              _InfoRow(
                '最近检测',
                _formatProbeClock(playback.probeCheckedAt,
                    cached: playback.probeCached),
              ),
              if (playback.probeDetails['nativeMpvCommands'] != null)
                _InfoRow(
                  'MPV 命令',
                  playback.probeDetails['nativeMpvCommands'] == 'true'
                      ? '可用'
                      : '不可用',
                ),
              if (playback.probeDetails['telemetry'] != null)
                _InfoRow(
                  'Telemetry',
                  playback.probeDetails['telemetry'] == 'true' ? '可用' : '不可用',
                ),
              if (playback.probeDetails['avSyncSampler'] != null)
                _InfoRow(
                  'AV 同步采样',
                  playback.probeDetails['avSyncSampler'] == 'true'
                      ? '可用'
                      : '不可用',
                ),
              _InfoRow('AV 同步健康', playback.avSyncHealthLabel),
              _InfoRow(
                'AV 最新漂移',
                playback.avSyncLatestDriftMillis == null
                    ? '暂无样本'
                    : '${playback.avSyncLatestDriftMillis} ms',
              ),
              _InfoRow(
                'AV 样本数',
                playback.avSyncSampleCount?.toString() ?? '0',
              ),
              _InfoRow(
                'AV 退化决策',
                playback.avSyncLatestDegradationAction ?? '未触发',
              ),
              if (playback.avSyncLastSampledAt != null)
                _InfoRow(
                  'AV 最近采样',
                  _formatClock(playback.avSyncLastSampledAt!),
                ),
              if (playback.avSyncSamplerFailure != null)
                _InfoRow('AV 采样失败', playback.avSyncSamplerFailure!),
              if (playback.probeDetails['anime4kShadersAccessible'] != null)
                _InfoRow(
                  'Anime4K shader',
                  playback.probeDetails['anime4kShadersAccessible'] == 'true'
                      ? '可访问'
                      : '不可访问',
                ),
              _InfoRow('播放源', playback.sourceUri ?? '无播放源'),
              _InfoRow('音轨', playback.activeAudioTrackId ?? '未选择'),
              _InfoRow('字幕轨', playback.activeSubtitleTrackId ?? '未选择'),
              _InfoRow('字幕文件', '${playback.subtitleTrackCount} 条可用轨'),
              _InfoRow('当前字幕', '${playback.activeSubtitleCueCount} 条 cue'),
              _InfoRow('字幕偏移', _formatDuration(playback.subtitleOffset)),
              _InfoRow('弹幕时钟', _formatDuration(playback.danmakuClockPosition)),
              if (playback.failureReason != null)
                _InfoRow('播放失败', playback.failureReason!),
              if (playback.subtitleFailure != null)
                _InfoRow('字幕失败', playback.subtitleFailure!),
              if (playback.danmakuFailure != null)
                _InfoRow('弹幕失败', playback.danmakuFailure!),
            ],
            theme: theme,
          ),
          const SizedBox(height: _panelGap),
          _WarningList(
            title: '字幕 / 弹幕警告',
            warnings: <String>[
              ...playback.subtitleWarnings,
              ...playback.danmakuWarnings,
            ],
            emptyText: '没有字幕或弹幕警告。',
            theme: theme,
          ),
          const SizedBox(height: _panelGap),
          _CapabilityList(
            key:
                const ValueKey<String>(UiElementIds.diagnosticsCapabilityChart),
            title: '播放能力矩阵',
            capabilities: playback.capabilities,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPanel(ElainaThemeData theme) {
    final DiagnosticsDownloadSnapshot? downloads = _snapshot.downloads;
    if (downloads == null) {
      return _missingModulePanel(
        key: UiElementIds.diagnosticsDownloadPanel,
        title: '下载',
        theme: theme,
      );
    }
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsDownloadPanel),
      title: '下载诊断',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _panelGap,
            runSpacing: _panelGap,
            children: <Widget>[
              _MetricTile(
                width: _metricMinWidth,
                title: '任务',
                value: downloads.totalTasks.toString(),
                subtitle: '${downloads.failedTasks} 失败',
                icon: Icons.downloading_outlined,
                color: downloads.failedTasks > 0
                    ? theme.accentMagenta
                    : theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '下载速度',
                value: _formatRate(downloads.totalDownloadRateBytesPerSecond),
                icon: Icons.south_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '上传速度',
                value: _formatRate(downloads.totalUploadRateBytesPerSecond),
                icon: Icons.north_outlined,
                color: theme.secondary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '连接',
                value: '${downloads.totalPeers} peers',
                icon: Icons.hub_outlined,
                color: theme.secondary,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          _CapabilityList(
            title: '下载能力',
            capabilities: downloads.capabilities,
            theme: theme,
          ),
          const SizedBox(height: _panelGap),
          _DownloadTaskTable(downloads: downloads, theme: theme),
        ],
      ),
    );
  }

  Widget _buildRssPanel(ElainaThemeData theme) {
    final DiagnosticsRssSnapshot? rss = _snapshot.rss;
    if (rss == null) {
      return _missingModulePanel(
        key: UiElementIds.diagnosticsRssPanel,
        title: 'RSS',
        theme: theme,
      );
    }
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsRssPanel),
      title: 'RSS 诊断',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _panelGap,
            runSpacing: _panelGap,
            children: <Widget>[
              _MetricTile(
                width: _metricMinWidth,
                title: '订阅源',
                value: rss.sourceCount.toString(),
                subtitle: '${rss.dueSourceCount} 待刷新',
                icon: Icons.rss_feed_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '新条目',
                value: rss.acceptedItemCount.toString(),
                icon: Icons.article_outlined,
                color: theme.secondary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '自动规则',
                value: rss.autoRuleCount.toString(),
                icon: Icons.rule_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '刷新失败',
                value: rss.refreshFailureCount.toString(),
                icon: Icons.error_outline,
                color: rss.refreshFailureCount > 0
                    ? theme.accentMagenta
                    : theme.primary,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          _InfoGrid(
            rows: <_InfoRow>[
              _InfoRow('运行状态', rss.status.name),
              _InfoRow('最近刷新记录', '${rss.latestRefreshCount} 个源'),
            ],
            theme: theme,
          ),
          const SizedBox(height: _panelGap),
          _WarningList(
            title: 'RSS 失败',
            warnings: rss.failures,
            emptyText: '没有 RSS 失败记录。',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaLibraryPanel(ElainaThemeData theme) {
    final DiagnosticsMediaLibrarySnapshot? library = _snapshot.mediaLibrary;
    if (library == null) {
      return _missingModulePanel(
        key: UiElementIds.diagnosticsMediaLibraryPanel,
        title: '本地媒体库',
        theme: theme,
      );
    }
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsMediaLibraryPanel),
      title: '本地媒体库诊断',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _panelGap,
            runSpacing: _panelGap,
            children: <Widget>[
              _MetricTile(
                width: _metricMinWidth,
                title: '索引媒体',
                value: library.catalogItemCount.toString(),
                icon: Icons.video_library_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '继续观看',
                value: library.continueWatchingCount.toString(),
                icon: Icons.history_outlined,
                color: theme.secondary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: 'Bangumi 绑定',
                value: library.bangumiBoundCount.toString(),
                icon: Icons.link_outlined,
                color: theme.primary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '扫描事件',
                value: library.scanEventCount.toString(),
                icon: Icons.manage_search_outlined,
                color: theme.secondary,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          _InfoGrid(
            rows: <_InfoRow>[
              _InfoRow('运行状态', library.status.name),
            ],
            theme: theme,
          ),
          const SizedBox(height: _panelGap),
          _WarningList(
            title: '媒体库失败',
            warnings: library.failureMessages,
            emptyText: '没有媒体库失败记录。',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderNetworkPanel(ElainaThemeData theme) {
    final DiagnosticsProviderNetworkSnapshot? providerNetwork =
        _snapshot.providerNetwork;
    if (providerNetwork == null) {
      return _missingModulePanel(
        key: UiElementIds.diagnosticsProviderNetworkPanel,
        title: 'Provider/网络',
        theme: theme,
      );
    }
    return _Panel(
      key: const ValueKey<String>(
        UiElementIds.diagnosticsProviderNetworkPanel,
      ),
      title: 'Provider / 网络诊断',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _panelGap,
            runSpacing: _panelGap,
            children: <Widget>[
              _MetricTile(
                width: _metricMinWidth,
                title: 'Bangumi Token',
                value: providerNetwork.bangumiTokenConfigured ? '已配置' : '未配置',
                icon: Icons.key_outlined,
                color: providerNetwork.bangumiTokenConfigured
                    ? theme.primary
                    : theme.secondary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: 'Bangumi 镜像',
                value: providerNetwork.bangumiMirrorEnabled ? '开启' : '关闭',
                subtitle: providerNetwork.bangumiMirrorValid ? '有效' : '无效',
                icon: Icons.public_outlined,
                color: providerNetwork.bangumiMirrorValid
                    ? theme.primary
                    : theme.accentMagenta,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: 'HTTP 代理',
                value: _configuredLabel(providerNetwork.httpProxyUrl),
                icon: Icons.route_outlined,
                color: theme.secondary,
                theme: theme,
              ),
              _MetricTile(
                width: _metricMinWidth,
                title: '网络事件',
                value: providerNetwork.providerNetworkEventCount.toString(),
                icon: Icons.receipt_long_outlined,
                color: theme.primary,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _panelGap),
          _InfoGrid(
            rows: <_InfoRow>[
              _InfoRow(
                  'API 镜像', providerNetwork.bangumiMirrorApiBaseUrl ?? '未配置'),
              _InfoRow(
                  '图片镜像', providerNetwork.bangumiMirrorImageBaseUrl ?? '未配置'),
              _InfoRow('DNS 策略', providerNetwork.dnsPolicy ?? '未配置'),
              _InfoRow('HTTP 代理', providerNetwork.httpProxyUrl ?? '未配置'),
              if (providerNetwork.failureMessage != null)
                _InfoRow('配置错误', providerNetwork.failureMessage!),
            ],
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsPanel(ElainaThemeData theme) {
    final List<DiagnosticsEventProjection> visibleEvents = _visibleEvents();
    final DiagnosticsEventProjection? selectedEvent =
        _selectedEvent(visibleEvents);
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsEventTable),
      title: '事件日志',
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>(UiElementIds.diagnosticsEventFilter),
            controller: _eventFilterController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '过滤模块、级别、事件或详情',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: _panelGap),
          if (visibleEvents.isEmpty)
            Text(
              '没有匹配的诊断事件。',
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            _EventTable(
              events: visibleEvents,
              selectedEventId: _selectedEventId,
              theme: theme,
              onSelect: (DiagnosticsEventProjection event) {
                setState(() {
                  _selectedEventId = event.id;
                });
              },
            ),
          if (selectedEvent != null) ...<Widget>[
            const SizedBox(height: _panelGap),
            _EventPayloadPanel(event: selectedEvent, theme: theme),
          ],
        ],
      ),
    );
  }

  Widget _missingModulePanel({
    required String key,
    required String title,
    required ElainaThemeData theme,
  }) {
    DiagnosticsModuleSnapshot? module;
    for (final DiagnosticsModuleSnapshot candidate in _snapshot.modules) {
      if (candidate.id == _selectedModuleId) {
        module = candidate;
        break;
      }
    }
    return _Panel(
      key: ValueKey<String>(key),
      title: title,
      theme: theme,
      child: Text(
        module?.failureMessage ?? '该模块暂时没有可用诊断数据。',
        style: TextStyle(
          color: theme.onBackground.withValues(alpha: 0.68),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<DiagnosticsEventProjection> _visibleEvents() {
    final String query = _eventFilterController.text.trim().toLowerCase();
    if (query.isEmpty) return _snapshot.events;
    return <DiagnosticsEventProjection>[
      for (final DiagnosticsEventProjection event in _snapshot.events)
        if (event.sourceModule.toLowerCase().contains(query) ||
            event.severity.toLowerCase().contains(query) ||
            event.eventType.toLowerCase().contains(query) ||
            event.payloadText.toLowerCase().contains(query))
          event,
    ];
  }

  DiagnosticsEventProjection? _selectedEvent(
    List<DiagnosticsEventProjection> visibleEvents,
  ) {
    final String? selectedId = _selectedEventId;
    if (selectedId == null) return null;
    for (final DiagnosticsEventProjection event in visibleEvents) {
      if (event.id == selectedId) return event;
    }
    return null;
  }
}

final class DiagnosticsEventBuckets {
  DiagnosticsEventBuckets._({
    required this.severityCounts,
    required this.moduleCounts,
  });

  factory DiagnosticsEventBuckets.fromEvents(
    Iterable<DiagnosticsEventProjection> events,
  ) {
    final Map<String, int> severityCounts = <String, int>{
      for (final _Severity severity in _Severity.values) severity.key: 0,
    };
    final Map<String, int> moduleCounts = <String, int>{};
    for (final DiagnosticsEventProjection event in events) {
      final String severity = _normalizedSeverity(event.severity);
      severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
      moduleCounts[event.sourceModule] =
          (moduleCounts[event.sourceModule] ?? 0) + 1;
    }
    return DiagnosticsEventBuckets._(
      severityCounts: severityCounts,
      moduleCounts: moduleCounts,
    );
  }

  final Map<String, int> severityCounts;
  final Map<String, int> moduleCounts;

  Map<String, int> get topModuleCounts {
    final List<MapEntry<String, int>> entries = moduleCounts.entries.toList()
      ..sort((MapEntry<String, int> left, MapEntry<String, int> right) {
        final int countCompare = right.value.compareTo(left.value);
        if (countCompare != 0) return countCompare;
        return left.key.compareTo(right.key);
      });
    return <String, int>{
      for (final MapEntry<String, int> entry in entries.take(5))
        entry.key: entry.value,
    };
  }
}

final class DiagnosticsCapabilitySummary {
  const DiagnosticsCapabilitySummary({
    required this.supported,
    required this.unsupported,
  });

  factory DiagnosticsCapabilitySummary.fromCapabilities(
    Map<String, String> capabilities,
  ) {
    int supported = 0;
    int unsupported = 0;
    for (final String value in capabilities.values) {
      if (_isSupported(value)) {
        supported++;
      } else {
        unsupported++;
      }
    }
    return DiagnosticsCapabilitySummary(
      supported: supported,
      unsupported: unsupported,
    );
  }

  final int supported;
  final int unsupported;

  int get total => supported + unsupported;
}

enum _Severity {
  info('info'),
  warning('warning'),
  error('error'),
  other('other');

  const _Severity(this.key);

  final String key;
}

final class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.title,
    required this.theme,
    required this.child,
  });

  final String title;
  final ElainaThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModuleNavItem extends StatelessWidget {
  const _ModuleNavItem({
    required this.module,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final DiagnosticsModuleSnapshot module;
  final bool selected;
  final ElainaThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _moduleColor(theme, module.health);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_panelRadius),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : theme.background.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(_panelRadius),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.52)
                  : theme.border.withValues(alpha: 0.62),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 170),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(_healthIcon(module.health), color: color, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          module.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          module.failureMessage ?? module.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onBackground.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    this.subtitle,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final ElainaThemeData theme;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(_panelRadius),
          border: Border.all(color: theme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle == null ? title : '$title · $subtitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.theme,
    required this.child,
  });

  final String title;
  final String valueLabel;
  final ElainaThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(height: _chartHeight, width: double.infinity, child: child),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows, required this.theme});

  final List<_InfoRow> rows;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final _InfoRow row in rows)
          SizedBox(
            width: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.background.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.border.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.label,
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.56),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WarningList extends StatelessWidget {
  const _WarningList({
    required this.title,
    required this.warnings,
    required this.emptyText,
    required this.theme,
  });

  final String title;
  final List<String> warnings;
  final String emptyText;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      theme: theme,
      child: warnings.isEmpty
          ? Text(
              emptyText,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $warning',
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CapabilityList extends StatelessWidget {
  const _CapabilityList({
    super.key,
    required this.title,
    required this.capabilities,
    required this.theme,
  });

  final String title;
  final List<DiagnosticsCapabilityEntry> capabilities;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      theme: theme,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final DiagnosticsCapabilityEntry capability in capabilities)
            _CapabilityChip(capability: capability, theme: theme),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.capability, required this.theme});

  final DiagnosticsCapabilityEntry capability;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color color =
        capability.supported ? theme.primary : theme.accentMagenta;
    return Tooltip(
      message: _capabilityTooltip(capability),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                capability.supported
                    ? Icons.check_circle_outline
                    : Icons.highlight_off,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                capability.label,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskTable extends StatelessWidget {
  const _DownloadTaskTable({required this.downloads, required this.theme});

  final DiagnosticsDownloadSnapshot downloads;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (downloads.tasks.isEmpty) {
      return Text(
        '没有下载任务。',
        style: TextStyle(
          color: theme.onBackground.withValues(alpha: 0.62),
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _tableMinWidth,
        child: Column(
          children: <Widget>[
            _DenseGrid(
              theme: theme,
              backgroundColor: theme.background.withValues(alpha: 0.44),
              widths: const <double>[220, 96, 88, 100, 100, 80, 96],
              children: const <Widget>[
                _HeaderCell('名称'),
                _HeaderCell('状态'),
                _HeaderCell('进度'),
                _HeaderCell('下载'),
                _HeaderCell('上传'),
                _HeaderCell('Peer'),
                _HeaderCell('文件'),
              ],
            ),
            for (final DiagnosticsDownloadTaskSnapshot task in downloads.tasks)
              _DenseGrid(
                theme: theme,
                widths: const <double>[220, 96, 88, 100, 100, 80, 96],
                children: <Widget>[
                  _BodyCell(task.name, theme: theme, bold: true),
                  _BodyCell(task.state.name, theme: theme),
                  _BodyCell(_formatPercent(task.progress), theme: theme),
                  _BodyCell(
                    _formatRate(task.downloadRateBytesPerSecond),
                    theme: theme,
                  ),
                  _BodyCell(
                    _formatRate(task.uploadRateBytesPerSecond),
                    theme: theme,
                  ),
                  _BodyCell(task.connectedPeers.toString(), theme: theme),
                  _BodyCell(
                    '${task.selectedFileCount}/${task.fileCount}',
                    theme: theme,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EventTable extends StatelessWidget {
  const _EventTable({
    required this.events,
    required this.selectedEventId,
    required this.theme,
    required this.onSelect,
  });

  final List<DiagnosticsEventProjection> events;
  final String? selectedEventId;
  final ElainaThemeData theme;
  final ValueChanged<DiagnosticsEventProjection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _tableMinWidth,
        child: Column(
          children: <Widget>[
            _DenseGrid(
              theme: theme,
              backgroundColor: theme.background.withValues(alpha: 0.44),
              widths: const <double>[90, 128, 90, 170, 302],
              children: const <Widget>[
                _HeaderCell('时间'),
                _HeaderCell('模块'),
                _HeaderCell('级别'),
                _HeaderCell('事件'),
                _HeaderCell('详情'),
              ],
            ),
            for (final DiagnosticsEventProjection event in events)
              Material(
                color: event.id == selectedEventId
                    ? theme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(event),
                  child: _DenseGrid(
                    theme: theme,
                    widths: const <double>[90, 128, 90, 170, 302],
                    children: <Widget>[
                      _BodyCell(_formatClock(event.occurredAt), theme: theme),
                      _BodyCell(event.sourceModule, theme: theme, bold: true),
                      _SeverityCell(event: event, theme: theme),
                      _BodyCell(event.eventType, theme: theme),
                      _BodyCell(event.payloadText, theme: theme, maxLines: 2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventPayloadPanel extends StatelessWidget {
  const _EventPayloadPanel({required this.event, required this.theme});

  final DiagnosticsEventProjection event;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>(UiElementIds.diagnosticsEventPayload),
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '事件详情：${event.eventType}',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              event.payloadText,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseGrid extends StatelessWidget {
  const _DenseGrid({
    required this.theme,
    required this.widths,
    required this.children,
    this.backgroundColor,
  });

  final ElainaThemeData theme;
  final List<double> widths;
  final List<Widget> children;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        border: Border(
          bottom: BorderSide(color: theme.border.withValues(alpha: 0.65)),
        ),
      ),
      child: SizedBox(
        height: _tableRowHeight,
        child: Row(
          children: <Widget>[
            for (int index = 0; index < children.length; index += 1)
              SizedBox(width: widths[index], child: children[index]),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(
    this.label, {
    required this.theme,
    this.bold = false,
    this.maxLines = 1,
  });

  final String label;
  final ElainaThemeData theme;
  final bool bold;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.76),
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SeverityCell extends StatelessWidget {
  const _SeverityCell({required this.event, required this.theme});

  final DiagnosticsEventProjection event;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color severityColor = _severityColor(theme, event.severity);
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: severityColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            event.severity,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: severityColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    this.threshold,
    this.thresholdColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final double? threshold;
  final Color? thresholdColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size, gridColor);
    if (values.isEmpty) return;
    final double maxValue = math.max(values.reduce(math.max), threshold ?? 0);
    final double minValue = values.reduce(math.min);
    final double range = math.max(1, maxValue - minValue);
    final Path linePath = Path();
    final Path fillPath = Path();
    for (int index = 0; index < values.length; index += 1) {
      final double x = values.length == 1
          ? size.width
          : size.width * index / (values.length - 1);
      final double y =
          size.height - ((values[index] - minValue) / range) * size.height;
      if (index == 0) {
        linePath.moveTo(x, y);
        fillPath
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final double? thresholdValue = threshold;
    final Color? thresholdPaintColor = thresholdColor;
    if (thresholdValue != null && thresholdPaintColor != null) {
      final double y =
          size.height - ((thresholdValue - minValue) / range) * size.height;
      canvas.drawLine(
        Offset(0, y.clamp(0, size.height)),
        Offset(size.width, y.clamp(0, size.height)),
        Paint()
          ..color = thresholdPaintColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.threshold != threshold ||
        oldDelegate.thresholdColor != thresholdColor;
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.values,
    required this.colors,
    required this.labelColor,
    required this.gridColor,
  });

  final Map<String, int> values;
  final Map<String, Color> colors;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size, gridColor);
    if (values.isEmpty) return;
    final int maxValue = math.max(1, values.values.reduce(math.max));
    final double slotWidth = size.width / values.length;
    int index = 0;
    for (final MapEntry<String, int> entry in values.entries) {
      final double height = size.height * entry.value / maxValue;
      final Rect rect = Rect.fromLTWH(
        index * slotWidth + slotWidth * 0.18,
        size.height - height,
        slotWidth * 0.64,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = colors[entry.key] ?? labelColor,
      );
      _drawSmallLabel(canvas, entry.key,
          Offset(index * slotWidth, size.height - 14), labelColor);
      index += 1;
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _HorizontalBarChartPainter extends CustomPainter {
  const _HorizontalBarChartPainter({
    required this.values,
    required this.barColor,
    required this.labelColor,
    required this.gridColor,
  });

  final Map<String, int> values;
  final Color barColor;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size, gridColor);
    if (values.isEmpty) return;
    final int maxValue = math.max(1, values.values.reduce(math.max));
    final double rowHeight = size.height / values.length;
    int index = 0;
    for (final MapEntry<String, int> entry in values.entries) {
      final double width = size.width * entry.value / maxValue;
      final Rect rect = Rect.fromLTWH(
        0,
        index * rowHeight + rowHeight * 0.25,
        width,
        rowHeight * 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = barColor,
      );
      _drawSmallLabel(
        canvas,
        '${entry.key} ${entry.value}',
        Offset(4, index * rowHeight + 2),
        labelColor,
      );
      index += 1;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalBarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.barColor != barColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor;
  }
}

void _drawGrid(Canvas canvas, Size size, Color color) {
  final Paint paint = Paint()
    ..color = color
    ..strokeWidth = 1;
  for (int index = 1; index <= 3; index += 1) {
    final double y = size.height * index / 4;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

void _drawSmallLabel(Canvas canvas, String label, Offset offset, Color color) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 120);
  painter.paint(canvas, offset);
}

String _formatMemory(int bytes) {
  return '${(bytes / _bytesPerMegabyte).toStringAsFixed(1)} MB';
}

String _formatRate(int bytesPerSecond) {
  if (bytesPerSecond >= _bytesPerMegabyte) {
    return '${(bytesPerSecond / _bytesPerMegabyte).toStringAsFixed(1)} MB/s';
  }
  return '${(bytesPerSecond / _bytesPerKilobyte).toStringAsFixed(1)} KB/s';
}

String _formatPercent(double value) {
  return '${(value * 100).clamp(0, 100).toStringAsFixed(1)}%';
}

String _formatFraction(double? value) {
  if (value == null) return '未知';
  return _formatPercent(value);
}

String _formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  final String minuteText =
      minutes.toString().padLeft(_timePartWidth, _timePartPad);
  final String secondText =
      seconds.toString().padLeft(_timePartWidth, _timePartPad);
  if (hours > 0) return '$hours:$minuteText:$secondText';
  return '$minuteText:$secondText';
}

String _formatOptionalDuration(Duration? duration) {
  if (duration == null) return '--:--';
  return _formatDuration(duration);
}

String _formatProbeClock(DateTime? time, {required bool cached}) {
  if (time == null) return '未检测';
  final String suffix = cached ? '（缓存）' : '';
  return '${_formatClock(time)}$suffix';
}

String _capabilityTooltip(DiagnosticsCapabilityEntry capability) {
  final List<String> lines = <String>[
    capability.reason ?? capability.label,
    if (capability.source != null) '来源：${capability.source}',
    if (capability.checkedAt != null)
      '检测：${_formatProbeClock(capability.checkedAt!, cached: capability.cached)}',
  ];
  return lines.join('\n');
}

String _formatClock(DateTime time) {
  final String hour =
      time.hour.toString().padLeft(_timePartWidth, _timePartPad);
  final String minute =
      time.minute.toString().padLeft(_timePartWidth, _timePartPad);
  final String second =
      time.second.toString().padLeft(_timePartWidth, _timePartPad);
  return '$hour:$minute:$second';
}

String _driftStatus(double driftMillis) {
  final double absolute = driftMillis.abs();
  if (absolute <= _avExcellentDriftMillis) return '优秀';
  if (absolute <= _avDegradedDriftMillis) return '可接受';
  return '需要关注';
}

Color _driftColor(ElainaThemeData theme, double driftMillis) {
  final double absolute = driftMillis.abs();
  if (absolute <= _avExcellentDriftMillis) return theme.primary;
  if (absolute <= _avDegradedDriftMillis) return theme.secondary;
  return theme.accentMagenta;
}

String _normalizedSeverity(String severity) {
  final String value = severity.toLowerCase();
  if (value.contains('warn')) return _Severity.warning.key;
  if (value.contains('error') || value.contains('fail')) {
    return _Severity.error.key;
  }
  if (value.contains('info')) return _Severity.info.key;
  return _Severity.other.key;
}

Color _severityColor(ElainaThemeData theme, String severity) {
  return switch (_normalizedSeverity(severity)) {
    'info' => theme.primary,
    'warning' => theme.secondary,
    'error' => theme.accentMagenta,
    _ => theme.onBackground.withValues(alpha: 0.66),
  };
}

Map<String, Color> _severityColors(ElainaThemeData theme) {
  return <String, Color>{
    _Severity.info.key: theme.primary,
    _Severity.warning.key: theme.secondary,
    _Severity.error.key: theme.accentMagenta,
    _Severity.other.key: theme.onBackground.withValues(alpha: 0.66),
  };
}

bool _isSupported(String value) {
  return value.toLowerCase() == 'supported';
}

DiagnosticsModuleHealth _playbackHealth(DiagnosticsPlaybackSnapshot playback) {
  return playback.failureReason == null
      ? DiagnosticsModuleHealth.healthy
      : DiagnosticsModuleHealth.failed;
}

Color _moduleColor(ElainaThemeData theme, DiagnosticsModuleHealth health) {
  return switch (health) {
    DiagnosticsModuleHealth.healthy => theme.primary,
    DiagnosticsModuleHealth.warning => theme.secondary,
    DiagnosticsModuleHealth.failed => theme.accentMagenta,
  };
}

IconData _healthIcon(DiagnosticsModuleHealth health) {
  return switch (health) {
    DiagnosticsModuleHealth.healthy => Icons.check_circle_outline,
    DiagnosticsModuleHealth.warning => Icons.warning_amber_outlined,
    DiagnosticsModuleHealth.failed => Icons.error_outline,
  };
}

String _playbackStatusLabel(PlaybackLifecycleStatus status) {
  return switch (status) {
    PlaybackLifecycleStatus.idle => '空闲',
    PlaybackLifecycleStatus.opening => '打开中',
    PlaybackLifecycleStatus.playing => '播放中',
    PlaybackLifecycleStatus.paused => '已暂停',
    PlaybackLifecycleStatus.buffering => '缓冲中',
    PlaybackLifecycleStatus.ended => '已结束',
    PlaybackLifecycleStatus.failed => '失败',
  };
}

String _configuredLabel(String? value) {
  return value == null || value.trim().isEmpty ? '未配置' : '已配置';
}
