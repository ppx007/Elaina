import 'package:flutter/material.dart';

import '../../domain/diagnostics/diagnostics_domain.dart';
import '../../foundation/constants.dart';
import '../theme/celesteria_theme.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    super.key,
    required this.diagnosticsRuntime,
  });

  final DiagnosticsRuntime diagnosticsRuntime;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<DiagnosticsEventProjection> _events = <DiagnosticsEventProjection>[];
  Map<String, String> _capabilities = <String, String>{};
  double _avSyncDrift = 0.0;
  int _memoryUsageBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<DiagnosticsEventProjection> allEvents = await widget.diagnosticsRuntime.queryEvents();
      final List<DiagnosticsEventProjection> cappedEvents = allEvents.length > AppConstants.diagnosticsPageMaxDisplayEvents
          ? allEvents.sublist(allEvents.length - AppConstants.diagnosticsPageMaxDisplayEvents)
          : allEvents;

      final Map<String, String> caps = widget.diagnosticsRuntime.getCapabilitiesSupportStatus();
      final double drift = await widget.diagnosticsRuntime.getLatestAvSyncDrift();
      final int memory = widget.diagnosticsRuntime.getActiveMemoryUsageBytes();

      if (mounted) {
        setState(() {
          _events = cappedEvents.reversed.toList(); // Newest first
          _capabilities = caps;
          _avSyncDrift = drift;
          _memoryUsageBytes = memory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新诊断数据失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CelesteriaThemeData theme = CelesteriaTheme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '诊断中心',
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.primary,
                  side: BorderSide(color: theme.border, width: 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新诊断数据', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _refreshData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: theme.primary,
            labelColor: theme.primary,
            unselectedLabelColor: theme.onBackground.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const <Tab>[
              Tab(text: '系统状态与功能矩阵'),
              Tab(text: '时序日志事件'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildSystemOverview(theme),
                _buildTimelineTable(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverview(CelesteriaThemeData theme) {
    final double driftAbs = _avSyncDrift.abs();
    final String syncStatus = driftAbs < 40.0
        ? '优秀 (<40ms)'
        : driftAbs < 120.0
            ? '正常 (<120ms)'
            : '需降级警告 (>120ms)';
    final Color syncColor = driftAbs < 40.0
        ? theme.primary
        : driftAbs < 120.0
            ? theme.secondary
            : theme.accentMagenta;

    return ListView(
      children: <Widget>[
        // Telemetry stats row
        Row(
          children: <Widget>[
            Expanded(
              child: _buildTelemetryCard(
                title: '当前内存占用',
                value: '${(_memoryUsageBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                icon: Icons.memory,
                color: theme.primary,
                theme: theme,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTelemetryCard(
                title: '音画同步偏离值 (AV Drift)',
                value: '${_avSyncDrift.toStringAsFixed(1)} ms',
                subtitle: '状态: $syncStatus',
                icon: Icons.sync,
                color: syncColor,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Capabilities checklist
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '功能支持矩阵 (Capabilities Support Matrix)',
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 32, color: Colors.white12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _capabilities.entries.map((MapEntry<String, String> entry) {
                  final bool isSupported = entry.value.toLowerCase() == 'supported';
                  return Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isSupported
                            ? theme.primary.withValues(alpha: 0.2)
                            : theme.accentMagenta.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          isSupported ? Icons.check_circle_outline : Icons.highlight_off,
                          color: isSupported ? theme.primary : theme.accentMagenta,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                entry.key,
                                style: TextStyle(
                                  color: theme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSupported ? theme.primary : theme.accentMagenta,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required CelesteriaThemeData theme,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: theme.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: theme.onBackground.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTable(CelesteriaThemeData theme) {
    if (_events.isEmpty) {
      return Center(
        child: Text(
          '暂无时序日志事件',
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: theme.border, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
            dataRowMaxHeight: 64,
            columns: const <DataColumn>[
              DataColumn(label: Text('时间', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('模块', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('级别', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('事件类型', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('详细信息', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _events.map((DiagnosticsEventProjection event) {
              final String timeStr = '${event.occurredAt.hour.toString().padLeft(2, '0')}:'
                  '${event.occurredAt.minute.toString().padLeft(2, '0')}:'
                  '${event.occurredAt.second.toString().padLeft(2, '0')}';

              Color severityColor = theme.onBackground.withValues(alpha: 0.8);
              if (event.severity.toLowerCase() == 'warning') {
                severityColor = theme.secondary;
              } else if (event.severity.toLowerCase() == 'error') {
                severityColor = theme.accentMagenta;
              } else if (event.severity.toLowerCase() == 'info') {
                severityColor = theme.primary;
              }

              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(timeStr, style: const TextStyle(fontSize: 13))),
                  DataCell(Text(event.sourceModule, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        event.severity,
                        style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  DataCell(Text(event.eventType, style: const TextStyle(fontSize: 13))),
                  DataCell(
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        event.payloadText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(color: theme.onBackground.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
