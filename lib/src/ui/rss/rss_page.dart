import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/rss/rss_engine.dart' show RssRefreshOutcome;
import '../../domain/rss/rss_engine_runtime.dart';
import '../testing/ui_element_ids.dart';
import '../theme/elaina_theme.dart';

const double _pagePadding = 24;
const double _toolbarGap = 12;
const double _sectionGap = 20;
const double _paneGap = 20;
const double _summaryGap = 12;
const double _sourcePaneWidth = 360;
const double _compactBreakpoint = 720;
const double _compactSourcePaneHeight = 360;
const double _panelRadius = 8;
const double _panelPadding = 16;
const double _sourceRowGap = 10;
const double _itemRowPadding = 14;
const double _chipRadius = 6;
const double _dialogWidth = 520;
const double _searchWidth = 280;
const double _smallIconSize = 18;
const int _itemSummaryMaxLines = 2;
const int _titleMaxLines = 2;
const int _ruleConditionMaxLines = 2;
const int _datePartWidth = 2;
const String _datePartPad = '0';
const String _torrentFileExtension = '.torrent';

const List<_RefreshIntervalOption> _refreshIntervalOptions =
    <_RefreshIntervalOption>[
  _RefreshIntervalOption(Duration(minutes: 30), '30 分钟'),
  _RefreshIntervalOption(Duration(hours: 1), '1 小时'),
  _RefreshIntervalOption(Duration(hours: 3), '3 小时'),
  _RefreshIntervalOption(Duration(hours: 6), '6 小时'),
  _RefreshIntervalOption(Duration(hours: 12), '12 小时'),
];

enum _RssItemFilter {
  all,
  withDownloadSource,
  autoDownloadMatched,
}

class RssPage extends StatefulWidget {
  const RssPage({
    super.key,
    required this.rssEngineRuntime,
  });

  final RssEngineRuntime rssEngineRuntime;

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> implements RssEngineRuntimeObserver {
  late RssEngineRuntimeSnapshot _snapshot;
  final Map<String, bool> _feedActivationStates = <String, bool>{};
  final Map<String, List<RssAutoDownloadRuleProjection>> _rulesBySource =
      <String, List<RssAutoDownloadRuleProjection>>{};
  final Map<String, RssAutoDownloadRulePreview> _previewsByRuleId =
      <String, RssAutoDownloadRulePreview>{};
  final Set<String> _matchedAutoDownloadItemIds = <String>{};
  final Set<String> _refreshingSourceIds = <String>{};
  final Set<String> _removingSourceIds = <String>{};
  final Set<String> _loadingRuleSourceIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String? _selectedSourceId;
  _RssItemFilter _itemFilter = _RssItemFilter.all;
  bool _isRefreshingRegistry = false;
  bool _isRefreshingAllSources = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.rssEngineRuntime.currentSnapshot;
    _searchController.addListener(_onSearchChanged);
    widget.rssEngineRuntime.addObserver(this);
    unawaited(_refreshRegistry());
    unawaited(_loadAutoDownloadState(_snapshot.sources));
  }

  @override
  void dispose() {
    widget.rssEngineRuntime.removeObserver(this);
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void onRssEngineRuntimeSnapshot(RssEngineRuntimeSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      if (_selectedSourceId != null &&
          !snapshot.sources.any(
            (FeedSource source) => source.id.value == _selectedSourceId,
          )) {
        _selectedSourceId = null;
      }
    });
    unawaited(_loadAutoDownloadState(snapshot.sources));
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshRegistry() async {
    if (_isRefreshingRegistry) return;
    setState(() {
      _isRefreshingRegistry = true;
    });
    try {
      final RssEngineActionResult<List<FeedSource>> result =
          await widget.rssEngineRuntime.listSources();
      if (!mounted) return;
      if (!result.isSuccess) {
        _showMessage(result.failure?.message ?? '刷新订阅源失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingRegistry = false;
        });
      }
    }
  }

  Future<void> _loadAutoDownloadState(Iterable<FeedSource> sources) async {
    final List<FeedSource> sourceList = List<FeedSource>.of(sources);
    final Map<String, bool> nextStates = <String, bool>{};
    final Map<String, List<RssAutoDownloadRuleProjection>> nextRules =
        <String, List<RssAutoDownloadRuleProjection>>{};
    for (final FeedSource source in sourceList) {
      final String sourceId = source.id.value;
      nextStates[sourceId] =
          await widget.rssEngineRuntime.isAutoDownloadEnabled(sourceId);
      final RssEngineActionResult<List<RssAutoDownloadRuleProjection>> rules =
          await widget.rssEngineRuntime.autoDownloadRulesForSource(sourceId);
      nextRules[sourceId] =
          rules.value ?? const <RssAutoDownloadRuleProjection>[];
    }
    final RssEngineActionResult<Set<String>> matched =
        await widget.rssEngineRuntime.autoDownloadMatchedItemIds();
    if (!mounted) return;
    setState(() {
      _feedActivationStates
        ..removeWhere(
            (String sourceId, bool _) => !nextStates.containsKey(sourceId))
        ..addAll(nextStates);
      _rulesBySource
        ..removeWhere(
            (String sourceId, List<RssAutoDownloadRuleProjection> _) =>
                !nextRules.containsKey(sourceId))
        ..addAll(nextRules);
      _matchedAutoDownloadItemIds
        ..clear()
        ..addAll(matched.value ?? const <String>{});
    });
  }

  Future<void> _reloadSourceRules(String sourceId) async {
    setState(() {
      _loadingRuleSourceIds.add(sourceId);
    });
    try {
      final RssEngineActionResult<List<RssAutoDownloadRuleProjection>> rules =
          await widget.rssEngineRuntime.autoDownloadRulesForSource(sourceId);
      final RssEngineActionResult<Set<String>> matched =
          await widget.rssEngineRuntime.autoDownloadMatchedItemIds();
      if (!mounted) return;
      if (!rules.isSuccess) {
        _showMessage(rules.failure?.message ?? '加载自动下载规则失败');
        return;
      }
      setState(() {
        _rulesBySource[sourceId] = rules.value!;
        _matchedAutoDownloadItemIds
          ..clear()
          ..addAll(matched.value ?? const <String>{});
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRuleSourceIds.remove(sourceId);
        });
      }
    }
  }

  Future<void> _toggleAutoDownload(String sourceId, bool enabled) async {
    await widget.rssEngineRuntime.setAutoDownloadEnabled(sourceId, enabled);
    if (!mounted) return;
    setState(() {
      _feedActivationStates[sourceId] = enabled;
    });
    unawaited(_reloadSourceRules(sourceId));
  }

  Future<void> _refreshSource(FeedSource source) async {
    final String sourceId = source.id.value;
    if (_refreshingSourceIds.contains(sourceId)) return;
    setState(() {
      _refreshingSourceIds.add(sourceId);
    });
    RssEngineActionResult<RssEngineRefreshSnapshot>? result;
    try {
      result = await widget.rssEngineRuntime.refreshSource(source.id);
      await _reloadSourceRules(sourceId);
    } finally {
      if (mounted) {
        setState(() {
          _refreshingSourceIds.remove(sourceId);
        });
      }
    }
    if (!mounted) return;
    _showMessage(_refreshResultMessage(source.displayName, result));
  }

  Future<void> _refreshAllSources() async {
    final List<FeedSource> sources = List<FeedSource>.of(_snapshot.sources);
    if (_isRefreshingAllSources) return;
    if (sources.isEmpty) {
      _showMessage('暂无订阅源');
      return;
    }

    setState(() {
      _isRefreshingAllSources = true;
      _refreshingSourceIds.addAll(
        sources.map((FeedSource source) => source.id.value),
      );
    });

    int successCount = 0;
    int newItemCount = 0;
    int failureCount = 0;
    try {
      for (final FeedSource source in sources) {
        final RssEngineActionResult<RssEngineRefreshSnapshot> result =
            await widget.rssEngineRuntime.refreshSource(source.id);
        if (result.isSuccess && result.value != null) {
          successCount += 1;
          newItemCount += result.value!.acceptedItems.length;
        } else {
          failureCount += 1;
        }
      }
      await _loadAutoDownloadState(sources);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingAllSources = false;
          _refreshingSourceIds.removeAll(
            sources.map((FeedSource source) => source.id.value),
          );
        });
      }
    }

    if (!mounted) return;
    if (failureCount == 0) {
      _showMessage('同步完成：$successCount 个源，新增 $newItemCount 条');
    } else {
      _showMessage('同步完成：$successCount 个成功，$failureCount 个失败');
    }
  }

  Future<void> _removeSource(FeedSource source) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final ElainaThemeData theme = ElainaTheme.of(context);
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelRadius),
            side: BorderSide(color: theme.border),
          ),
          title: Text('删除订阅源', style: TextStyle(color: theme.onSurface)),
          content: Text(
            '删除「${source.displayName}」以及已解析条目。',
            style: TextStyle(color: theme.onBackground),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline, size: _smallIconSize),
              label: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final String sourceId = source.id.value;
    setState(() {
      _removingSourceIds.add(sourceId);
    });
    RssEngineActionResult<bool>? result;
    try {
      result = await widget.rssEngineRuntime.removeSource(source.id);
    } finally {
      if (mounted) {
        setState(() {
          _removingSourceIds.remove(sourceId);
        });
      }
    }
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        if (_selectedSourceId == sourceId) _selectedSourceId = null;
        _feedActivationStates.remove(sourceId);
        _rulesBySource.remove(sourceId);
      });
      _showMessage('已删除订阅源');
    } else {
      _showMessage(result.failure?.message ?? '删除订阅源失败');
    }
  }

  Future<void> _addNewFeed() async {
    final ElainaThemeData theme = ElainaTheme.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _AddFeedDialog(
          theme: theme,
          rssEngineRuntime: widget.rssEngineRuntime,
          refreshRegistry: _refreshRegistry,
        );
      },
    );
    unawaited(_loadAutoDownloadState(_snapshot.sources));
  }

  Future<void> _openRuleDialog(
    FeedSource source, {
    RssAutoDownloadRuleProjection? rule,
  }) async {
    final RssAutoDownloadRuleDraft? draft =
        await showDialog<RssAutoDownloadRuleDraft>(
      context: context,
      builder: (BuildContext context) {
        return _AutoDownloadRuleDialog(
          theme: ElainaTheme.of(context),
          source: source,
          initialRule: rule,
        );
      },
    );
    if (draft == null) return;
    final RssEngineActionResult<RssAutoDownloadRuleProjection> saved =
        await widget.rssEngineRuntime.saveAutoDownloadRule(draft);
    if (!mounted) return;
    if (!saved.isSuccess) {
      _showMessage(saved.failure?.message ?? '保存自动下载规则失败');
      return;
    }
    await _reloadSourceRules(source.id.value);
    _showMessage('自动下载规则已保存');
  }

  Future<void> _deleteRule(
    FeedSource source,
    RssAutoDownloadRuleProjection rule,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除自动下载规则'),
          content: Text('删除「${rule.label}」后不会再匹配新的 RSS 条目。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final RssEngineActionResult<bool> result =
        await widget.rssEngineRuntime.removeAutoDownloadRule(rule.ruleId);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.failure?.message ?? '删除自动下载规则失败');
      return;
    }
    _previewsByRuleId.remove(rule.ruleId);
    await _reloadSourceRules(source.id.value);
    _showMessage('自动下载规则已删除');
  }

  Future<void> _toggleRuleEnabled(
    FeedSource source,
    RssAutoDownloadRuleProjection rule,
    bool enabled,
  ) async {
    final RssEngineActionResult<RssAutoDownloadRuleProjection> result =
        await widget.rssEngineRuntime.saveAutoDownloadRule(
      rule.toDraft().copyWith(enabled: enabled),
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.failure?.message ?? '更新自动下载规则失败');
      return;
    }
    await _reloadSourceRules(source.id.value);
  }

  Future<void> _previewRule(RssAutoDownloadRuleProjection rule) async {
    final RssEngineActionResult<RssAutoDownloadRulePreview> result =
        await widget.rssEngineRuntime.previewAutoDownloadRule(rule.toDraft());
    if (!mounted) return;
    if (!result.isSuccess || result.value == null) {
      _showMessage(result.failure?.message ?? '预览自动下载规则失败');
      return;
    }
    setState(() {
      _previewsByRuleId[rule.ruleId] = result.value!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final List<FeedItem> visibleItems = _visibleItems;
    final Map<String, FeedSource> sourceById = _sourceById;
    final int autoDownloadCount =
        _feedActivationStates.values.where((bool enabled) => enabled).length;
    final int ruleCount = _rulesBySource.values.fold<int>(
      0,
      (int total, List<RssAutoDownloadRuleProjection> rules) =>
          total + rules.length,
    );
    final bool isBusy = _isRefreshingRegistry || _isRefreshingAllSources;

    return Padding(
      padding: const EdgeInsets.all(_pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildToolbar(theme, isBusy: isBusy),
          const SizedBox(height: _sectionGap),
          _buildSummary(
            theme,
            autoDownloadCount: autoDownloadCount,
            ruleCount: ruleCount,
          ),
          const SizedBox(height: _sectionGap),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget sourcePane = _buildSourcePane(theme);
                final Widget itemPane =
                    _buildItemPane(theme, sourceById, visibleItems);
                if (constraints.maxWidth < _compactBreakpoint) {
                  return Column(
                    children: <Widget>[
                      SizedBox(
                        height: _compactSourcePaneHeight,
                        child: sourcePane,
                      ),
                      const SizedBox(height: _paneGap),
                      Expanded(child: itemPane),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: _sourcePaneWidth, child: sourcePane),
                    const SizedBox(width: _paneGap),
                    Expanded(child: itemPane),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ElainaThemeData theme, {required bool isBusy}) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'RSS 订阅',
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Tooltip(
          message: '刷新订阅源列表',
          child: IconButton(
            onPressed: isBusy ? null : _refreshRegistry,
            icon: _isRefreshingRegistry
                ? _smallProgress(theme)
                : const Icon(Icons.refresh_outlined),
            color: theme.primary,
          ),
        ),
        const SizedBox(width: _toolbarGap),
        OutlinedButton.icon(
          onPressed:
              isBusy || _snapshot.sources.isEmpty ? null : _refreshAllSources,
          icon: _isRefreshingAllSources
              ? _smallProgress(theme)
              : const Icon(Icons.sync, size: _smallIconSize),
          label: const Text('同步全部'),
        ),
        const SizedBox(width: _toolbarGap),
        FilledButton.icon(
          onPressed: isBusy ? null : _addNewFeed,
          icon: const Icon(Icons.add_link, size: _smallIconSize),
          label: const Text('添加订阅'),
        ),
      ],
    );
  }

  Widget _buildSummary(
    ElainaThemeData theme, {
    required int autoDownloadCount,
    required int ruleCount,
  }) {
    final int warningCount = _snapshot.latestRefreshes.values
        .where((RssRefreshOutcome outcome) => !outcome.isSuccess)
        .length;
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildMetric(
            theme,
            icon: Icons.rss_feed,
            label: '订阅源',
            value: _snapshot.sources.length.toString(),
          ),
        ),
        const SizedBox(width: _summaryGap),
        Expanded(
          child: _buildMetric(
            theme,
            icon: Icons.rule,
            label: '自动规则',
            value: ruleCount.toString(),
          ),
        ),
        const SizedBox(width: _summaryGap),
        Expanded(
          child: _buildMetric(
            theme,
            icon: Icons.download_done_outlined,
            label: '启用自动下载',
            value: autoDownloadCount.toString(),
          ),
        ),
        const SizedBox(width: _summaryGap),
        Expanded(
          child: _buildMetric(
            theme,
            icon: Icons.article_outlined,
            label: '已解析条目',
            value: _snapshot.acceptedItems.length.toString(),
          ),
        ),
        const SizedBox(width: _summaryGap),
        Expanded(
          child: _buildMetric(
            theme,
            icon: Icons.error_outline,
            label: '失败刷新',
            value: warningCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(
    ElainaThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(_panelPadding),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: theme.primary, size: 20),
          const SizedBox(width: _toolbarGap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePane(ElainaThemeData theme) {
    return _buildPanel(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '订阅源',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusChip(
                theme,
                label: '${_snapshot.sources.length}',
                color: theme.primary,
              ),
            ],
          ),
          const SizedBox(height: _sourceRowGap),
          Expanded(
            child: _snapshot.sources.isEmpty
                ? _buildEmptyState(theme, icon: Icons.rss_feed, text: '暂无订阅源')
                : ListView.separated(
                    itemCount: _snapshot.sources.length + 1,
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(height: 1, color: theme.border);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) return _buildAllSourcesRow(theme);
                      final FeedSource source = _snapshot.sources[index - 1];
                      return _buildSourceRow(
                        theme,
                        source,
                        itemCount: _sourceItemCount(source.id.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSourcesRow(ElainaThemeData theme) {
    final bool selected = _selectedSourceId == null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSourceId = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _panelPadding,
            vertical: _itemRowPadding,
          ),
          color: selected ? theme.primary.withValues(alpha: 0.08) : null,
          child: Row(
            children: <Widget>[
              Icon(Icons.all_inbox_outlined, color: theme.primary),
              const SizedBox(width: _toolbarGap),
              Expanded(
                child: Text(
                  '全部订阅',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              _buildStatusChip(
                theme,
                label: _snapshot.acceptedItems.length.toString(),
                color: theme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceRow(
    ElainaThemeData theme,
    FeedSource source, {
    required int itemCount,
  }) {
    final String sourceId = source.id.value;
    final bool selected = _selectedSourceId == sourceId;
    final bool autoDownloadEnabled = _feedActivationStates[sourceId] ?? false;
    final bool isRefreshing = _refreshingSourceIds.contains(sourceId);
    final bool isRemoving = _removingSourceIds.contains(sourceId);
    final RssEngineCursorSnapshot? cursor = _cursorFor(sourceId);
    final RssRefreshOutcome? latestRefresh =
        _snapshot.latestRefreshes[sourceId];
    final bool latestFailed = latestRefresh != null && !latestRefresh.isSuccess;
    final int ruleCount = _rulesBySource[sourceId]?.length ?? 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSourceId = sourceId;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(_itemRowPadding),
          color: selected ? theme.primary.withValues(alpha: 0.08) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      source.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildStatusChip(
                    theme,
                    label: latestFailed ? '失败' : '$itemCount 条',
                    color: latestFailed
                        ? Theme.of(context).colorScheme.error
                        : theme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                source.uri.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.56),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: _sourceRowGap),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _buildStatusChip(
                    theme,
                    label: _formatFeedFormat(source.format),
                    color: theme.secondary,
                  ),
                  _buildStatusChip(
                    theme,
                    label: _formatDuration(source.refreshInterval),
                    color: theme.primary,
                  ),
                  _buildStatusChip(
                    theme,
                    label: '$ruleCount 条规则',
                    color: theme.accentMagenta,
                  ),
                  _buildStatusChip(
                    theme,
                    label: cursor == null
                        ? '未同步'
                        : '同步 ${_formatDate(cursor.refreshedAt)}',
                    color: theme.onBackground.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: _sourceRowGap),
              Row(
                children: <Widget>[
                  Text(
                    '自动下载',
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  Switch(
                    value: autoDownloadEnabled,
                    onChanged: isRemoving
                        ? null
                        : (bool enabled) =>
                            _toggleAutoDownload(sourceId, enabled),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: '同步订阅源',
                    child: IconButton(
                      onPressed: isRefreshing || isRemoving
                          ? null
                          : () => _refreshSource(source),
                      icon: isRefreshing
                          ? _smallProgress(theme)
                          : const Icon(Icons.sync, size: _smallIconSize),
                    ),
                  ),
                  Tooltip(
                    message: '删除订阅源',
                    child: IconButton(
                      onPressed:
                          isRemoving ? null : () => _removeSource(source),
                      icon: isRemoving
                          ? _smallProgress(theme)
                          : const Icon(Icons.delete_outline,
                              size: _smallIconSize),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemPane(
    ElainaThemeData theme,
    Map<String, FeedSource> sourceById,
    List<FeedItem> visibleItems,
  ) {
    final FeedSource? selectedSource =
        _selectedSourceId == null ? null : sourceById[_selectedSourceId!];

    return _buildPanel(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _toolbarGap,
            runSpacing: _toolbarGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                selectedSource == null ? '条目流' : selectedSource.displayName,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusChip(
                theme,
                label: '${visibleItems.length} 条',
                color: theme.primary,
              ),
              SizedBox(
                width: _searchWidth,
                child: TextField(
                  key: const ValueKey<String>(UiElementIds.rssItemSearch),
                  controller: _searchController,
                  style: TextStyle(color: theme.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: _smallIconSize),
                    hintText: '搜索标题、简介或分类',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_panelRadius),
                    ),
                  ),
                ),
              ),
              SegmentedButton<_RssItemFilter>(
                segments: const <ButtonSegment<_RssItemFilter>>[
                  ButtonSegment<_RssItemFilter>(
                    value: _RssItemFilter.all,
                    icon: Icon(Icons.list_alt, size: _smallIconSize),
                    label: Text('全部'),
                  ),
                  ButtonSegment<_RssItemFilter>(
                    value: _RssItemFilter.withDownloadSource,
                    icon: Icon(Icons.attach_file, size: _smallIconSize),
                    label: Text('含资源'),
                  ),
                  ButtonSegment<_RssItemFilter>(
                    value: _RssItemFilter.autoDownloadMatched,
                    icon: Icon(Icons.rule, size: _smallIconSize),
                    label: Text('命中自动下载'),
                  ),
                ],
                selected: <_RssItemFilter>{_itemFilter},
                onSelectionChanged: (Set<_RssItemFilter> selection) {
                  setState(() {
                    _itemFilter = selection.single;
                  });
                },
              ),
            ],
          ),
          if (selectedSource != null) ...<Widget>[
            const SizedBox(height: _sourceRowGap),
            _buildRulesSection(theme, selectedSource),
          ],
          if (_snapshot.failures.isNotEmpty) ...<Widget>[
            const SizedBox(height: _sourceRowGap),
            _buildFailureStrip(theme, _snapshot.failures.last.message),
          ],
          const SizedBox(height: _sourceRowGap),
          Expanded(
            child: visibleItems.isEmpty
                ? _buildEmptyState(
                    theme,
                    icon: Icons.article_outlined,
                    text: '暂无条目',
                  )
                : ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(height: 1, color: theme.border);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return _buildItemRow(
                        theme,
                        visibleItems[index],
                        sourceById[visibleItems[index].sourceId.value],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection(ElainaThemeData theme, FeedSource source) {
    final String sourceId = source.id.value;
    final List<RssAutoDownloadRuleProjection> rules =
        _rulesBySource[sourceId] ?? const <RssAutoDownloadRuleProjection>[];
    final bool loading = _loadingRuleSourceIds.contains(sourceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '自动下载规则',
                style: TextStyle(
                  color: theme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (loading) _smallProgress(theme),
            const SizedBox(width: _toolbarGap),
            OutlinedButton.icon(
              onPressed: () => _openRuleDialog(source),
              icon: const Icon(Icons.add, size: _smallIconSize),
              label: const Text('添加规则'),
            ),
          ],
        ),
        const SizedBox(height: _sourceRowGap),
        if (rules.isEmpty)
          Text(
            '未配置规则；即使打开自动下载开关，也不会自动下载全量资源。',
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final RssAutoDownloadRuleProjection rule in rules)
                _buildRuleRow(theme, source, rule),
            ],
          ),
      ],
    );
  }

  Widget _buildRuleRow(
    ElainaThemeData theme,
    FeedSource source,
    RssAutoDownloadRuleProjection rule,
  ) {
    final RssAutoDownloadRulePreview? preview = _previewsByRuleId[rule.ruleId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Switch(
            value: rule.enabled,
            onChanged: (bool enabled) =>
                _toggleRuleEnabled(source, rule, enabled),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  rule.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _ruleConditionText(rule),
                  maxLines: _ruleConditionMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onBackground.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(width: _toolbarGap),
            _buildStatusChip(
              theme,
              label: '命中 ${preview.matchedCount}',
              color: theme.primary,
            ),
          ],
          Tooltip(
            message: '预览规则',
            child: IconButton(
              onPressed: () => _previewRule(rule),
              icon: const Icon(Icons.visibility_outlined, size: _smallIconSize),
            ),
          ),
          Tooltip(
            message: '编辑规则',
            child: IconButton(
              onPressed: () => _openRuleDialog(source, rule: rule),
              icon: const Icon(Icons.edit_outlined, size: _smallIconSize),
            ),
          ),
          Tooltip(
            message: '删除规则',
            child: IconButton(
              onPressed: () => _deleteRule(source, rule),
              icon: const Icon(Icons.delete_outline, size: _smallIconSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    ElainaThemeData theme,
    FeedItem item,
    FeedSource? source,
  ) {
    final bool matched = _matchedAutoDownloadItemIds.contains(item.id.value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _itemRowPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  maxLines: _titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ),
              if (_hasDownloadSource(item))
                _buildStatusChip(
                  theme,
                  label: '资源',
                  color: theme.primary,
                ),
              if (matched) ...<Widget>[
                const SizedBox(width: 6),
                _buildStatusChip(
                  theme,
                  label: '自动下载',
                  color: theme.accentMagenta,
                ),
              ],
            ],
          ),
          if (item.summary != null &&
              item.summary!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              item.summary!.trim(),
              maxLines: _itemSummaryMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _buildMutedMeta(
                  theme, Icons.schedule, _formatDate(item.publishedAt)),
              if (source != null)
                _buildMutedMeta(theme, Icons.rss_feed, source.displayName),
              for (final String category in item.categories.take(3))
                _buildStatusChip(
                  theme,
                  label: category,
                  color: theme.secondary,
                ),
              if (item.link != null)
                _buildMutedMeta(theme, Icons.link, item.link!.host),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(ElainaThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(_panelPadding),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: child,
    );
  }

  Widget _buildFailureStrip(ElainaThemeData theme, String message) {
    final Color error = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_sourceRowGap),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: error.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: error, fontSize: 12),
      ),
    );
  }

  Widget _buildEmptyState(
    ElainaThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: theme.onBackground.withValues(alpha: 0.38)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.56),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    ElainaThemeData theme, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMutedMeta(ElainaThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 14,
          color: theme.onBackground.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _smallProgress(ElainaThemeData theme) {
    return SizedBox.square(
      dimension: _smallIconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: theme.primary,
      ),
    );
  }

  Map<String, FeedSource> get _sourceById {
    return <String, FeedSource>{
      for (final FeedSource source in _snapshot.sources)
        source.id.value: source,
    };
  }

  List<FeedItem> get _visibleItems {
    final String query = _searchController.text.trim().toLowerCase();
    final List<FeedItem> items = <FeedItem>[
      for (final FeedItem item in _snapshot.acceptedItems)
        if ((_selectedSourceId == null ||
                item.sourceId.value == _selectedSourceId) &&
            _matchesItemFilter(item) &&
            _matchesQuery(item, query))
          item,
    ];
    items.sort(_compareFeedItemsByDate);
    return items;
  }

  bool _matchesItemFilter(FeedItem item) {
    return switch (_itemFilter) {
      _RssItemFilter.all => true,
      _RssItemFilter.withDownloadSource => _hasDownloadSource(item),
      _RssItemFilter.autoDownloadMatched =>
        _matchedAutoDownloadItemIds.contains(item.id.value),
    };
  }

  bool _matchesQuery(FeedItem item, String query) {
    if (query.isEmpty) return true;
    final FeedSource? source = _sourceById[item.sourceId.value];
    return item.title.toLowerCase().contains(query) ||
        (item.summary?.toLowerCase().contains(query) ?? false) ||
        item.categories.any(
          (String category) => category.toLowerCase().contains(query),
        ) ||
        (source?.displayName.toLowerCase().contains(query) ?? false);
  }

  int _sourceItemCount(String sourceId) {
    return _snapshot.acceptedItems
        .where((FeedItem item) => item.sourceId.value == sourceId)
        .length;
  }

  RssEngineCursorSnapshot? _cursorFor(String sourceId) {
    for (final RssEngineCursorSnapshot cursor in _snapshot.cursors) {
      if (cursor.sourceId.value == sourceId) return cursor;
    }
    return null;
  }

  String _refreshResultMessage(
    String sourceName,
    RssEngineActionResult<RssEngineRefreshSnapshot>? result,
  ) {
    if (result != null && result.isSuccess && result.value != null) {
      return '$sourceName 同步完成：新增 ${result.value!.acceptedItems.length} 条';
    }
    return '$sourceName 同步失败：${result?.failure?.message ?? '未知错误'}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog({
    required this.theme,
    required this.rssEngineRuntime,
    required this.refreshRegistry,
  });

  final ElainaThemeData theme;
  final RssEngineRuntime rssEngineRuntime;
  final Future<void> Function() refreshRegistry;

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _ruleLabelController;
  late final TextEditingController _titleContainsController;
  late final TextEditingController _titleRegexController;
  late final TextEditingController _excludeController;
  late final TextEditingController _categoryController;
  FeedFormat _selectedFormat = FeedFormat.rss;
  Duration _selectedRefreshInterval = _refreshIntervalOptions[1].duration;
  String? _nameErrorText;
  String? _urlErrorText;
  String? _formErrorText;
  bool _createAutoDownloadRule = false;
  bool _requireDownloadSource = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _ruleLabelController = TextEditingController(text: '新番自动下载');
    _titleContainsController = TextEditingController();
    _titleRegexController = TextEditingController();
    _excludeController = TextEditingController();
    _categoryController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _ruleLabelController.dispose();
    _titleContainsController.dispose();
    _titleRegexController.dispose();
    _excludeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_panelRadius),
        side: BorderSide(color: widget.theme.border),
      ),
      title: Text(
        '添加 RSS 订阅',
        style: TextStyle(
          color: widget.theme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: _dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _nameController,
                style: TextStyle(color: widget.theme.onSurface),
                onChanged: (_) => _clearNameError(),
                decoration: InputDecoration(
                  labelText: '订阅源名称',
                  errorText: _nameErrorText,
                ),
              ),
              const SizedBox(height: _toolbarGap),
              TextField(
                controller: _urlController,
                style: TextStyle(color: widget.theme.onSurface),
                onChanged: (_) => _clearUrlError(),
                decoration: InputDecoration(
                  labelText: 'RSS / Atom 地址',
                  errorText: _urlErrorText,
                ),
              ),
              const SizedBox(height: _toolbarGap),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<FeedFormat>(
                      initialValue: _selectedFormat,
                      decoration: const InputDecoration(labelText: '格式'),
                      items: const <DropdownMenuItem<FeedFormat>>[
                        DropdownMenuItem<FeedFormat>(
                          value: FeedFormat.rss,
                          child: Text('RSS'),
                        ),
                        DropdownMenuItem<FeedFormat>(
                          value: FeedFormat.atom,
                          child: Text('Atom'),
                        ),
                      ],
                      onChanged: (FeedFormat? value) {
                        if (value == null) return;
                        setState(() {
                          _selectedFormat = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: _toolbarGap),
                  Expanded(
                    child: DropdownButtonFormField<Duration>(
                      initialValue: _selectedRefreshInterval,
                      decoration: const InputDecoration(labelText: '刷新间隔'),
                      items: <DropdownMenuItem<Duration>>[
                        for (final _RefreshIntervalOption option
                            in _refreshIntervalOptions)
                          DropdownMenuItem<Duration>(
                            value: option.duration,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: (Duration? value) {
                        if (value == null) return;
                        setState(() {
                          _selectedRefreshInterval = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _toolbarGap),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('同时创建自动下载规则'),
                value: _createAutoDownloadRule,
                onChanged: (bool? value) {
                  setState(() {
                    _createAutoDownloadRule = value ?? false;
                  });
                },
              ),
              if (_createAutoDownloadRule) ...<Widget>[
                _RuleFields(
                  theme: widget.theme,
                  ruleLabelController: _ruleLabelController,
                  titleContainsController: _titleContainsController,
                  titleRegexController: _titleRegexController,
                  excludeController: _excludeController,
                  categoryController: _categoryController,
                  requireDownloadSource: _requireDownloadSource,
                  onRequireDownloadSourceChanged: (bool value) {
                    setState(() {
                      _requireDownloadSource = value;
                    });
                  },
                ),
              ],
              if (_formErrorText != null) ...<Widget>[
                const SizedBox(height: _toolbarGap),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formErrorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: _smallIconSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_link, size: _smallIconSize),
          label: Text(_isSubmitting ? '保存中' : '保存订阅'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String url = _urlController.text.trim();
    final Uri? parsedUri = Uri.tryParse(url);
    final String? nameError = name.isEmpty ? '请输入订阅源名称' : null;
    final String? urlError = _feedUrlError(url, parsedUri);
    if (nameError != null || urlError != null || parsedUri == null) {
      setState(() {
        _nameErrorText = nameError;
        _urlErrorText = urlError;
        _formErrorText = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _nameErrorText = null;
      _urlErrorText = null;
      _formErrorText = null;
    });

    final RssEngineActionResult<FeedSource> result =
        await widget.rssEngineRuntime.registerSourceParams(
      id: _feedSourceIdForUri(parsedUri),
      displayName: name,
      uri: parsedUri,
      format: _selectedFormat,
      refreshInterval: _selectedRefreshInterval,
    );
    if (!mounted) return;
    if (!result.isSuccess || result.value == null) {
      setState(() {
        _isSubmitting = false;
        _formErrorText = result.failure?.message ?? '保存订阅失败';
      });
      return;
    }

    if (_createAutoDownloadRule) {
      final FeedSource source = result.value!;
      await widget.rssEngineRuntime.setAutoDownloadEnabled(
        source.id.value,
        true,
      );
      final RssEngineActionResult<RssAutoDownloadRuleProjection> rule =
          await widget.rssEngineRuntime.saveAutoDownloadRule(
        _draftFromFields(source.id.value),
      );
      if (!mounted) return;
      if (!rule.isSuccess) {
        setState(() {
          _isSubmitting = false;
          _formErrorText = rule.failure?.message ?? '自动下载规则保存失败';
        });
        return;
      }
    }

    await widget.refreshRegistry();
    if (mounted) Navigator.of(context).pop();
  }

  RssAutoDownloadRuleDraft _draftFromFields(String sourceId) {
    return RssAutoDownloadRuleDraft(
      sourceId: sourceId,
      label: _ruleLabelController.text.trim(),
      titleContains: _titleContainsController.text.trim(),
      titleRegex: _titleRegexController.text.trim(),
      excludeTitleContains: _excludeController.text.trim(),
      categoryContains: _categoryController.text.trim(),
      requireDownloadSource: _requireDownloadSource,
    );
  }

  void _clearNameError() {
    if (_nameErrorText == null && _formErrorText == null) return;
    setState(() {
      _nameErrorText = null;
      _formErrorText = null;
    });
  }

  void _clearUrlError() {
    if (_urlErrorText == null && _formErrorText == null) return;
    setState(() {
      _urlErrorText = null;
      _formErrorText = null;
    });
  }

  String? _feedUrlError(String url, Uri? parsedUri) {
    if (url.isEmpty) return '请输入订阅地址';
    if (parsedUri == null) return '请输入有效订阅地址';
    final String scheme = parsedUri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || parsedUri.host.isEmpty) {
      return '请输入 http 或 https 订阅地址';
    }
    return null;
  }
}

class _AutoDownloadRuleDialog extends StatefulWidget {
  const _AutoDownloadRuleDialog({
    required this.theme,
    required this.source,
    this.initialRule,
  });

  final ElainaThemeData theme;
  final FeedSource source;
  final RssAutoDownloadRuleProjection? initialRule;

  @override
  State<_AutoDownloadRuleDialog> createState() =>
      _AutoDownloadRuleDialogState();
}

class _AutoDownloadRuleDialogState extends State<_AutoDownloadRuleDialog> {
  late final TextEditingController _ruleLabelController;
  late final TextEditingController _titleContainsController;
  late final TextEditingController _titleRegexController;
  late final TextEditingController _excludeController;
  late final TextEditingController _categoryController;
  late bool _enabled;
  late bool _requireDownloadSource;

  @override
  void initState() {
    super.initState();
    final RssAutoDownloadRuleProjection? rule = widget.initialRule;
    _ruleLabelController = TextEditingController(text: rule?.label ?? '新番自动下载');
    _titleContainsController =
        TextEditingController(text: rule?.titleContains ?? '');
    _titleRegexController = TextEditingController(text: rule?.titleRegex ?? '');
    _excludeController =
        TextEditingController(text: rule?.excludeTitleContains ?? '');
    _categoryController =
        TextEditingController(text: rule?.categoryContains ?? '');
    _enabled = rule?.enabled ?? true;
    _requireDownloadSource = rule?.requireDownloadSource ?? true;
  }

  @override
  void dispose() {
    _ruleLabelController.dispose();
    _titleContainsController.dispose();
    _titleRegexController.dispose();
    _excludeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.initialRule != null;
    return AlertDialog(
      title: Text(editing ? '编辑自动下载规则' : '添加自动下载规则'),
      content: SizedBox(
        width: _dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用规则'),
                value: _enabled,
                onChanged: (bool value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
              _RuleFields(
                theme: widget.theme,
                ruleLabelController: _ruleLabelController,
                titleContainsController: _titleContainsController,
                titleRegexController: _titleRegexController,
                excludeController: _excludeController,
                categoryController: _categoryController,
                requireDownloadSource: _requireDownloadSource,
                onRequireDownloadSourceChanged: (bool value) {
                  setState(() {
                    _requireDownloadSource = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft()),
          child: const Text('保存规则'),
        ),
      ],
    );
  }

  RssAutoDownloadRuleDraft _draft() {
    final RssAutoDownloadRuleProjection? rule = widget.initialRule;
    return RssAutoDownloadRuleDraft(
      ruleId: rule?.ruleId,
      sourceId: widget.source.id.value,
      label: _ruleLabelController.text.trim(),
      enabled: _enabled,
      priority: rule?.priority ?? rssAutoDownloadDefaultRulePriority,
      titleContains: _titleContainsController.text.trim(),
      titleRegex: _titleRegexController.text.trim(),
      excludeTitleContains: _excludeController.text.trim(),
      categoryContains: _categoryController.text.trim(),
      requireDownloadSource: _requireDownloadSource,
    );
  }
}

class _RuleFields extends StatelessWidget {
  const _RuleFields({
    required this.theme,
    required this.ruleLabelController,
    required this.titleContainsController,
    required this.titleRegexController,
    required this.excludeController,
    required this.categoryController,
    required this.requireDownloadSource,
    required this.onRequireDownloadSourceChanged,
  });

  final ElainaThemeData theme;
  final TextEditingController ruleLabelController;
  final TextEditingController titleContainsController;
  final TextEditingController titleRegexController;
  final TextEditingController excludeController;
  final TextEditingController categoryController;
  final bool requireDownloadSource;
  final ValueChanged<bool> onRequireDownloadSourceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: ruleLabelController,
          style: TextStyle(color: theme.onSurface),
          decoration: const InputDecoration(labelText: '规则名称'),
        ),
        const SizedBox(height: _toolbarGap),
        TextField(
          controller: titleContainsController,
          style: TextStyle(color: theme.onSurface),
          decoration: const InputDecoration(labelText: '标题包含'),
        ),
        const SizedBox(height: _toolbarGap),
        TextField(
          controller: titleRegexController,
          style: TextStyle(color: theme.onSurface),
          decoration: const InputDecoration(labelText: '标题正则'),
        ),
        const SizedBox(height: _toolbarGap),
        TextField(
          controller: excludeController,
          style: TextStyle(color: theme.onSurface),
          decoration: const InputDecoration(labelText: '排除词（逗号或换行）'),
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: _toolbarGap),
        TextField(
          controller: categoryController,
          style: TextStyle(color: theme.onSurface),
          decoration: const InputDecoration(labelText: '分类包含'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('必须含下载资源'),
          value: requireDownloadSource,
          onChanged: (bool? value) {
            onRequireDownloadSourceChanged(value ?? false);
          },
        ),
      ],
    );
  }
}

final class _RefreshIntervalOption {
  const _RefreshIntervalOption(this.duration, this.label);

  final Duration duration;
  final String label;
}

extension on RssAutoDownloadRuleDraft {
  RssAutoDownloadRuleDraft copyWith({
    bool? enabled,
  }) {
    return RssAutoDownloadRuleDraft(
      ruleId: ruleId,
      sourceId: sourceId,
      label: label,
      enabled: enabled ?? this.enabled,
      priority: priority,
      titleContains: titleContains,
      titleRegex: titleRegex,
      excludeTitleContains: excludeTitleContains,
      categoryContains: categoryContains,
      requireDownloadSource: requireDownloadSource,
    );
  }
}

String _feedSourceIdForUri(Uri uri) {
  return 'source-${Uri.encodeComponent(uri.toString())}';
}

String _formatFeedFormat(FeedFormat format) {
  return switch (format) {
    FeedFormat.rss => 'RSS',
    FeedFormat.atom => 'Atom',
  };
}

String _formatDuration(Duration duration) {
  for (final _RefreshIntervalOption option in _refreshIntervalOptions) {
    if (option.duration == duration) return option.label;
  }
  if (duration.inHours > 0 &&
      duration.inMinutes % Duration.minutesPerHour == 0) {
    return '${duration.inHours} 小时';
  }
  return '${duration.inMinutes} 分钟';
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) return '未知日期';
  final DateTime local = dateTime.toLocal();
  final String month =
      local.month.toString().padLeft(_datePartWidth, _datePartPad);
  final String day = local.day.toString().padLeft(_datePartWidth, _datePartPad);
  final String hour =
      local.hour.toString().padLeft(_datePartWidth, _datePartPad);
  final String minute =
      local.minute.toString().padLeft(_datePartWidth, _datePartPad);
  return '${local.year}-$month-$day $hour:$minute';
}

int _compareFeedItemsByDate(FeedItem left, FeedItem right) {
  final DateTime? leftDate = left.publishedAt;
  final DateTime? rightDate = right.publishedAt;
  if (leftDate == null && rightDate == null) {
    return left.title.compareTo(right.title);
  }
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  return rightDate.compareTo(leftDate);
}

bool _hasDownloadSource(FeedItem item) {
  final Uri? enclosureUri = item.enclosure?.uri;
  if (enclosureUri != null && _isDownloadUri(enclosureUri)) return true;
  final Uri? link = item.link;
  return link != null && _isDownloadUri(link);
}

bool _isDownloadUri(Uri uri) {
  return uri.scheme == 'magnet' ||
      uri.path.toLowerCase().endsWith(_torrentFileExtension);
}

String _ruleConditionText(RssAutoDownloadRuleProjection rule) {
  final List<String> parts = <String>[
    if (rule.titleContains.trim().isNotEmpty)
      '标题包含「${rule.titleContains.trim()}」',
    if (rule.titleRegex.trim().isNotEmpty) '正则 /${rule.titleRegex.trim()}/',
    if (rule.categoryContains.trim().isNotEmpty)
      '分类包含「${rule.categoryContains.trim()}」',
    if (rule.excludeTitleContains.trim().isNotEmpty)
      '排除「${rule.excludeTitleContains.trim()}」',
    if (rule.requireDownloadSource) '必须含资源',
  ];
  return parts.isEmpty ? '未配置条件' : parts.join(' · ');
}
