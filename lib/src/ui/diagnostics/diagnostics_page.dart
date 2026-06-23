import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/diagnostics/diagnostics_domain.dart';
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
const double _compactBreakpoint = 860;
const double _metricMinWidth = 170;
const double _chartHeight = 132;
const double _eventTableMinWidth = 760;
const double _eventRowHeight = 42;
const double _smallIconSize = 18;
const double _avExcellentDriftMillis = 40;
const double _avDegradedDriftMillis = 120;
const int _bytesPerMegabyte = 1024 * 1024;
const int _timePartWidth = 2;
const String _timePartPad = '0';

/// Read-only diagnostics dashboard for local runtime observations.
///
/// The page polls [DiagnosticsRuntime] while visible because the diagnostics
/// boundary currently exposes query methods rather than a push stream.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    super.key,
    required this.diagnosticsRuntime,
    this.isActive = true,
    this.refreshInterval = diagnosticsDefaultRefreshInterval,
    this.historyLimit = diagnosticsDefaultHistoryLimit,
  });

  final DiagnosticsRuntime diagnosticsRuntime;
  final bool isActive;
  final Duration refreshInterval;
  final int historyLimit;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  String? _lastError;
  DateTime? _lastRefreshedAt;
  DiagnosticsDashboardSnapshot _snapshot = DiagnosticsDashboardSnapshot.empty();
  final List<DiagnosticsTelemetrySample> _history =
      <DiagnosticsTelemetrySample>[];

  @override
  void initState() {
    super.initState();
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

  Future<void> _refreshData({bool showInitialLoading = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final List<DiagnosticsEventProjection> allEvents =
          await widget.diagnosticsRuntime.queryEvents();
      final List<DiagnosticsEventProjection> cappedEvents =
          _capEvents(allEvents).reversed.toList(growable: false);
      final Map<String, String> capabilities =
          widget.diagnosticsRuntime.getCapabilitiesSupportStatus();
      final double drift =
          await widget.diagnosticsRuntime.getLatestAvSyncDrift();
      final int memory = widget.diagnosticsRuntime.getActiveMemoryUsageBytes();
      final DateTime sampledAt = DateTime.now();
      final DiagnosticsTelemetrySample sample = DiagnosticsTelemetrySample(
        sampledAt: sampledAt,
        memoryUsageBytes: memory,
        avSyncDriftMillis: drift,
      );

      if (!mounted) return;
      setState(() {
        _history.add(sample);
        _trimHistory();
        _snapshot = DiagnosticsDashboardSnapshot(
          events: cappedEvents,
          capabilities: capabilities,
          currentSample: sample,
        );
        _lastError = null;
        _lastRefreshedAt = sampledAt;
        _hasLoaded = true;
        _isRefreshing = false;
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

  List<DiagnosticsEventProjection> _capEvents(
      List<DiagnosticsEventProjection> events) {
    if (events.length <= AppConstants.diagnosticsPageMaxDisplayEvents) {
      return List<DiagnosticsEventProjection>.unmodifiable(events);
    }
    return List<DiagnosticsEventProjection>.unmodifiable(
      events.sublist(
          events.length - AppConstants.diagnosticsPageMaxDisplayEvents),
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
    if (!_hasLoaded && _snapshot.events.isEmpty && _isRefreshing) {
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
                  child: _buildMetrics(theme),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: _sectionGap),
                  child: compact
                      ? _buildCompactCharts(theme)
                      : _buildWideCharts(theme),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: _sectionGap),
                  child: _buildCapabilities(theme),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: _sectionGap),
                  child: _buildEventTable(theme),
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
                '诊断中心',
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
                    label: widget.isActive ? '自动刷新中' : '自动刷新已暂停',
                    icon: widget.isActive
                        ? Icons.sync_outlined
                        : Icons.pause_circle_outline,
                    color: widget.isActive ? theme.primary : theme.secondary,
                    theme: theme,
                    key: const ValueKey<String>(
                      UiElementIds.diagnosticsAutoRefreshStatus,
                    ),
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

  Widget _buildMetrics(ElainaThemeData theme) {
    final DiagnosticsEventBuckets buckets =
        DiagnosticsEventBuckets.fromEvents(_snapshot.events);
    final int warningCount = buckets.severityCounts[_Severity.warning.key] ?? 0;
    final int errorCount = buckets.severityCounts[_Severity.error.key] ?? 0;
    return Wrap(
      spacing: _panelGap,
      runSpacing: _panelGap,
      children: <Widget>[
        _MetricTile(
          width: _metricMinWidth,
          title: '内存占用',
          value: _formatMemory(_snapshot.currentSample.memoryUsageBytes),
          icon: Icons.memory_outlined,
          color: theme.primary,
          theme: theme,
        ),
        _MetricTile(
          width: _metricMinWidth,
          title: 'AV 漂移',
          value:
              '${_snapshot.currentSample.avSyncDriftMillis.toStringAsFixed(1)} ms',
          subtitle: _driftStatus(_snapshot.currentSample.avSyncDriftMillis),
          icon: Icons.graphic_eq_outlined,
          color: _driftColor(theme, _snapshot.currentSample.avSyncDriftMillis),
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
          title: '警告 / 错误',
          value: '$warningCount / $errorCount',
          icon: Icons.warning_amber_outlined,
          color: errorCount > 0 ? theme.accentMagenta : theme.secondary,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildWideCharts(ElainaThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _buildTelemetryCharts(theme)),
        const SizedBox(width: _panelGap),
        Expanded(child: _buildEventCharts(theme)),
      ],
    );
  }

  Widget _buildCompactCharts(ElainaThemeData theme) {
    return Column(
      children: <Widget>[
        _buildTelemetryCharts(theme),
        const SizedBox(height: _panelGap),
        _buildEventCharts(theme),
      ],
    );
  }

  Widget _buildTelemetryCharts(ElainaThemeData theme) {
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
            valueLabel: _formatMemory(_snapshot.currentSample.memoryUsageBytes),
            theme: theme,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: memoryValues,
                lineColor: theme.primary,
                fillColor: theme.primary.withValues(alpha: 0.12),
                gridColor: theme.border.withValues(alpha: 0.45),
              ),
              size: const Size(double.infinity, _chartHeight),
            ),
          ),
          const SizedBox(height: _panelGap),
          _ChartFrame(
            key: const ValueKey<String>(UiElementIds.diagnosticsDriftChart),
            title: 'AV 漂移趋势',
            valueLabel:
                '${_snapshot.currentSample.avSyncDriftMillis.toStringAsFixed(1)} ms',
            theme: theme,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: driftValues,
                lineColor: _driftColor(
                    theme, _snapshot.currentSample.avSyncDriftMillis),
                fillColor: _driftColor(
                  theme,
                  _snapshot.currentSample.avSyncDriftMillis,
                ).withValues(alpha: 0.12),
                gridColor: theme.border.withValues(alpha: 0.45),
                threshold: _avDegradedDriftMillis,
                thresholdColor: theme.accentMagenta.withValues(alpha: 0.65),
              ),
              size: const Size(double.infinity, _chartHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCharts(ElainaThemeData theme) {
    final DiagnosticsEventBuckets buckets =
        DiagnosticsEventBuckets.fromEvents(_snapshot.events);
    return _Panel(
      title: '事件分布',
      theme: theme,
      child: Column(
        children: <Widget>[
          _ChartFrame(
            key: const ValueKey<String>(UiElementIds.diagnosticsSeverityChart),
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
              size: const Size(double.infinity, _chartHeight),
            ),
          ),
          const SizedBox(height: _panelGap),
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
              size: const Size(double.infinity, _chartHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilities(ElainaThemeData theme) {
    final DiagnosticsCapabilitySummary summary =
        DiagnosticsCapabilitySummary.fromCapabilities(_snapshot.capabilities);
    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsCapabilityChart),
      title: '能力矩阵',
      theme: theme,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < _compactBreakpoint;
          final Widget chart = SizedBox(
            width: compact ? double.infinity : 220,
            height: 180,
            child: CustomPaint(
              painter: _DonutChartPainter(
                supported: summary.supported,
                unsupported: summary.unsupported,
                supportedColor: theme.primary,
                unsupportedColor: theme.accentMagenta,
                trackColor: theme.border.withValues(alpha: 0.45),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${summary.supported}/${summary.total}',
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Supported',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final Widget matrix = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MapEntry<String, String> entry
                  in _snapshot.capabilities.entries)
                _CapabilityChip(entry: entry, theme: theme),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[chart, const SizedBox(height: 12), matrix],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              chart,
              const SizedBox(width: _panelGap),
              Expanded(child: matrix),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventTable(ElainaThemeData theme) {
    if (_snapshot.events.isEmpty) {
      return _Panel(
        key: const ValueKey<String>(UiElementIds.diagnosticsEventTable),
        title: '事件日志',
        theme: theme,
        child: Text(
          '暂无诊断事件',
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.62),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _Panel(
      key: const ValueKey<String>(UiElementIds.diagnosticsEventTable),
      title: '事件日志',
      theme: theme,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _eventTableMinWidth,
          child: Column(
            children: <Widget>[
              _EventHeader(theme: theme),
              for (final DiagnosticsEventProjection event in _snapshot.events)
                _EventRow(event: event, theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

final class DiagnosticsDashboardSnapshot {
  const DiagnosticsDashboardSnapshot({
    required this.events,
    required this.capabilities,
    required this.currentSample,
  });

  factory DiagnosticsDashboardSnapshot.empty() {
    return DiagnosticsDashboardSnapshot(
      events: const <DiagnosticsEventProjection>[],
      capabilities: const <String, String>{},
      currentSample: DiagnosticsTelemetrySample(
        sampledAt: DateTime.fromMillisecondsSinceEpoch(0),
        memoryUsageBytes: 0,
        avSyncDriftMillis: 0,
      ),
    );
  }

  final List<DiagnosticsEventProjection> events;
  final Map<String, String> capabilities;
  final DiagnosticsTelemetrySample currentSample;
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

final class DiagnosticsEventBuckets {
  DiagnosticsEventBuckets._({
    required this.severityCounts,
    required this.moduleCounts,
  });

  factory DiagnosticsEventBuckets.fromEvents(
      Iterable<DiagnosticsEventProjection> events) {
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
      Map<String, String> capabilities) {
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

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.entry,
    required this.theme,
  });

  final MapEntry<String, String> entry;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bool supported = _isSupported(entry.value);
    final Color color = supported ? theme.primary : theme.accentMagenta;
    return DecoratedBox(
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
              supported ? Icons.check_circle_outline : Icons.highlight_off,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.key}: ${entry.value}',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.theme});

  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _EventGrid(
      theme: theme,
      backgroundColor: theme.background.withValues(alpha: 0.44),
      children: const <Widget>[
        _EventHeaderCell('时间'),
        _EventHeaderCell('模块'),
        _EventHeaderCell('级别'),
        _EventHeaderCell('事件'),
        _EventHeaderCell('详情'),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.theme,
  });

  final DiagnosticsEventProjection event;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color severityColor = _severityColor(theme, event.severity);
    return _EventGrid(
      theme: theme,
      children: <Widget>[
        _EventBodyCell(_formatClock(event.occurredAt), theme: theme),
        _EventBodyCell(event.sourceModule, theme: theme, bold: true),
        Align(
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
        ),
        _EventBodyCell(event.eventType, theme: theme),
        _EventBodyCell(event.payloadText, theme: theme, maxLines: 2),
      ],
    );
  }
}

class _EventGrid extends StatelessWidget {
  const _EventGrid({
    required this.theme,
    required this.children,
    this.backgroundColor,
  });

  final ElainaThemeData theme;
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
        height: _eventRowHeight,
        child: Row(
          children: <Widget>[
            SizedBox(width: 84, child: children[0]),
            SizedBox(width: 120, child: children[1]),
            SizedBox(width: 96, child: children[2]),
            SizedBox(width: 150, child: children[3]),
            Expanded(child: children[4]),
          ],
        ),
      ),
    );
  }
}

class _EventHeaderCell extends StatelessWidget {
  const _EventHeaderCell(this.label);

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

class _EventBodyCell extends StatelessWidget {
  const _EventBodyCell(
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
    final double maxValue = math.max(
      values.reduce(math.max),
      threshold ?? 0,
    );
    final double minValue = values.reduce(math.min);
    final double range = math.max(1, maxValue - minValue);
    final Path linePath = Path();
    final Path fillPath = Path();
    for (int index = 0; index < values.length; index++) {
      final double x = values.length == 1
          ? size.width
          : size.width * index / (values.length - 1);
      final double y =
          size.height - ((values[index] - minValue) / range) * size.height;
      if (index == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final double? thresholdValue = threshold;
    final Color? lineThresholdColor = thresholdColor;
    if (thresholdValue != null && lineThresholdColor != null) {
      final double y =
          size.height - ((thresholdValue - minValue) / range) * size.height;
      if (y >= 0 && y <= size.height) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..color = lineThresholdColor
            ..strokeWidth = 1,
        );
      }
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
    final double barWidth = size.width / values.length;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    int index = 0;
    for (final MapEntry<String, int> entry in values.entries) {
      final double height = (entry.value / maxValue) * (size.height - 28);
      final Rect rect = Rect.fromLTWH(
        index * barWidth + 8,
        size.height - height - 24,
        math.max(8, barWidth - 16),
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = colors[entry.key] ?? labelColor,
      );
      textPainter.text = TextSpan(
        text: '${entry.key}\n${entry.value}',
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.layout(maxWidth: barWidth);
      textPainter.paint(
        canvas,
        Offset(index * barWidth, size.height - 22),
      );
      index++;
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
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    int index = 0;
    for (final MapEntry<String, int> entry in values.entries) {
      final double y = index * rowHeight + 6;
      final double width = (entry.value / maxValue) * (size.width - 116);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(104, y, math.max(4, width), rowHeight - 12),
          const Radius.circular(5),
        ),
        Paint()..color = barColor,
      );
      textPainter.text = TextSpan(
        text: entry.key,
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.layout(maxWidth: 96);
      textPainter.paint(canvas, Offset(0, y + 2));
      textPainter.text = TextSpan(
        text: entry.value.toString(),
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.layout(maxWidth: 32);
      textPainter.paint(canvas, Offset(size.width - 28, y + 2));
      index++;
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

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.supported,
    required this.unsupported,
    required this.supportedColor,
    required this.unsupportedColor,
    required this.trackColor,
  });

  final int supported;
  final int unsupported;
  final Color supportedColor;
  final Color unsupportedColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 10;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2, false, paint..color = trackColor);
    final int total = supported + unsupported;
    if (total == 0) return;
    final double supportedSweep = math.pi * 2 * supported / total;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      supportedSweep,
      false,
      paint..color = supportedColor,
    );
    if (unsupported > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + supportedSweep,
        math.pi * 2 - supportedSweep,
        false,
        paint..color = unsupportedColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.supported != supported ||
        oldDelegate.unsupported != unsupported ||
        oldDelegate.supportedColor != supportedColor ||
        oldDelegate.unsupportedColor != unsupportedColor ||
        oldDelegate.trackColor != trackColor;
  }
}

void _drawGrid(Canvas canvas, Size size, Color color) {
  final Paint gridPaint = Paint()
    ..color = color
    ..strokeWidth = 1;
  for (final double fraction in const <double>[0.25, 0.5, 0.75]) {
    final double y = size.height * fraction;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
  }
}

String _formatMemory(int bytes) {
  return '${(bytes / _bytesPerMegabyte).toStringAsFixed(1)} MB';
}

String _formatClock(DateTime time) {
  return '${time.hour.toString().padLeft(_timePartWidth, _timePartPad)}:'
      '${time.minute.toString().padLeft(_timePartWidth, _timePartPad)}:'
      '${time.second.toString().padLeft(_timePartWidth, _timePartPad)}';
}

String _driftStatus(double driftMillis) {
  final double absolute = driftMillis.abs();
  if (absolute < _avExcellentDriftMillis) return '优秀';
  if (absolute < _avDegradedDriftMillis) return '正常';
  return '需降级';
}

Color _driftColor(ElainaThemeData theme, double driftMillis) {
  final double absolute = driftMillis.abs();
  if (absolute < _avExcellentDriftMillis) return theme.primary;
  if (absolute < _avDegradedDriftMillis) return theme.secondary;
  return theme.accentMagenta;
}

String _normalizedSeverity(String severity) {
  final String value = severity.toLowerCase();
  if (value == _Severity.info.key) return _Severity.info.key;
  if (value == _Severity.warning.key || value == 'warn') {
    return _Severity.warning.key;
  }
  if (value == _Severity.error.key || value == 'fatal') {
    return _Severity.error.key;
  }
  return _Severity.other.key;
}

Color _severityColor(ElainaThemeData theme, String severity) {
  return switch (_normalizedSeverity(severity)) {
    'info' => theme.primary,
    'warning' => theme.secondary,
    'error' => theme.accentMagenta,
    _ => theme.onBackground.withValues(alpha: 0.72),
  };
}

Map<String, Color> _severityColors(ElainaThemeData theme) {
  return <String, Color>{
    _Severity.info.key: theme.primary,
    _Severity.warning.key: theme.secondary,
    _Severity.error.key: theme.accentMagenta,
    _Severity.other.key: theme.onBackground.withValues(alpha: 0.72),
  };
}

bool _isSupported(String value) {
  return value.toLowerCase() == 'supported';
}
