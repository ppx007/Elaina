import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/download/download_domain.dart';
import '../theme/elaina_theme.dart';

const double _pagePadding = 24;
const double _panelGap = 16;
const double _toolbarGap = 10;
const double _summaryHeight = 76;
const double _desktopDetailWidth = 420;
const double _desktopLayoutBreakpoint = 720;
const double _taskRowHeight = 76;
const int _bytesPerKiB = 1024;
const int _percentMultiplier = 100;
const ButtonStyle _taskIconButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  maximumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.downloadRuntime,
  });

  final DownloadRuntime downloadRuntime;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
    implements DownloadRuntimeObserver {
  late DownloadRuntimeSnapshot _snapshot;
  final TextEditingController _searchController = TextEditingController();
  DownloadTaskId? _selectedTaskId;
  _DownloadFilter _filter = _DownloadFilter.all;
  bool _isCreatingTask = false;
  bool _isRefreshing = false;
  Set<DownloadFileIndex> _detailSelectedFiles = <DownloadFileIndex>{};

  @override
  void initState() {
    super.initState();
    _snapshot = widget.downloadRuntime.currentSnapshot;
    widget.downloadRuntime.addObserver(this);
    _searchController.addListener(_refreshSearch);
    _syncSelection();
    _refreshTasks();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    widget.downloadRuntime.removeObserver(this);
    super.dispose();
  }

  @override
  void onDownloadRuntimeSnapshot(DownloadRuntimeSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _syncSelection();
    });
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _isRefreshing = true;
    });
    try {
      await widget.downloadRuntime.listTasks();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _syncSelection();
        });
      }
    }
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  void _syncSelection() {
    if (_snapshot.tasks.isEmpty) {
      _selectedTaskId = null;
      _detailSelectedFiles = <DownloadFileIndex>{};
      return;
    }

    final bool selectedStillExists = _snapshot.tasks.any(
      (DownloadProjection task) => task.taskId == _selectedTaskId,
    );
    if (!selectedStillExists) {
      _selectedTaskId = _snapshot.tasks.first.taskId;
    }

    final DownloadProjection? selectedTask = _selectedTask;
    if (selectedTask == null) {
      _detailSelectedFiles = <DownloadFileIndex>{};
      return;
    }
    _detailSelectedFiles = <DownloadFileIndex>{
      for (final DownloadFileProjection file in selectedTask.files)
        if (file.isSelected) file.index,
    };
  }

  DownloadProjection? get _selectedTask {
    final DownloadTaskId? selectedTaskId = _selectedTaskId;
    if (selectedTaskId == null) return null;
    for (final DownloadProjection task in _snapshot.tasks) {
      if (task.taskId == selectedTaskId) return task;
    }
    return null;
  }

  List<DownloadProjection> get _visibleTasks {
    final String query = _searchController.text.trim().toLowerCase();
    return <DownloadProjection>[
      for (final DownloadProjection task in _snapshot.tasks)
        if (_filter.matches(task) &&
            (query.isEmpty ||
                task.name.toLowerCase().contains(query) ||
                task.sourceUri.toLowerCase().contains(query) ||
                (task.infoHash?.toLowerCase().contains(query) ?? false)))
          task,
    ];
  }

  Future<void> _showCreateTaskDialog() async {
    if (!_snapshot.capabilities.canCreateTasks) {
      _showMessage(_capabilityMessage(_snapshot.capabilities));
      return;
    }

    final _DownloadAddRequest? request = await showDialog<_DownloadAddRequest>(
      context: context,
      builder: (BuildContext context) => const _AddDownloadTaskDialog(),
    );
    if (request == null) return;

    setState(() {
      _isCreatingTask = true;
    });

    try {
      final DownloadCreateResult result =
          await widget.downloadRuntime.createTaskFromUri(
        request.sourceUri,
        mode: request.mode,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showMessage(result.failureMessage ?? '创建下载任务失败。');
        return;
      }
      if (result.hasWarning) {
        _showMessage(result.warningMessage!);
      }
      final DownloadProjection task = result.task!;
      setState(() {
        _selectedTaskId = task.taskId;
      });
      if (request.mode == DownloadCreateMode.advanced) {
        setState(() {
          _isCreatingTask = false;
        });
        await _continueAdvancedAdd(task);
      }
      await _refreshTasks();
    } catch (error) {
      if (mounted) _showMessage('创建下载任务失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }

  Future<void> _continueAdvancedAdd(DownloadProjection task) async {
    if (task.files.isEmpty) {
      _showMessage('任务已暂停，等待元数据后可在详情中选择文件。');
      return;
    }
    final Set<DownloadFileIndex>? selectedFiles =
        await showDialog<Set<DownloadFileIndex>>(
      context: context,
      builder: (BuildContext context) => _FileSelectionDialog(task: task),
    );
    if (selectedFiles == null) return;
    final DownloadCommandResult selection =
        await widget.downloadRuntime.selectFiles(task.taskId, selectedFiles);
    if (!selection.isSuccess) {
      _showMessage(selection.failureMessage ?? '文件选择失败。');
      return;
    }
    final DownloadCommandResult resume =
        await widget.downloadRuntime.resume(task.taskId);
    if (!resume.isSuccess) {
      _showMessage(resume.failureMessage ?? '恢复下载任务失败。');
    }
  }

  Future<void> _pauseTask(DownloadProjection task) async {
    await _runCommand(() => widget.downloadRuntime.pause(task.taskId));
  }

  Future<void> _resumeTask(DownloadProjection task) async {
    await _runCommand(() => widget.downloadRuntime.resume(task.taskId));
  }

  Future<void> _removeTask(DownloadProjection task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除下载任务'),
        content: Text('确认删除「${task.name}」？已下载文件不会被删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除任务'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runCommand(() => widget.downloadRuntime.remove(task.taskId));
  }

  Future<void> _pauseAll() async {
    await _runCommand(widget.downloadRuntime.pauseAll);
  }

  Future<void> _resumeAll() async {
    await _runCommand(widget.downloadRuntime.resumeAll);
  }

  Future<void> _applyDetailFileSelection(DownloadProjection task) async {
    if (_detailSelectedFiles.isEmpty) return;
    final DownloadCommandResult result = await widget.downloadRuntime
        .selectFiles(task.taskId, _detailSelectedFiles);
    if (!result.isSuccess) {
      _showMessage(result.failureMessage ?? '文件选择失败。');
      return;
    }
    await _refreshTasks();
  }

  Future<void> _runCommand(
    Future<DownloadCommandResult> Function() command,
  ) async {
    final DownloadCommandResult result = await command();
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.failureMessage ?? '下载命令执行失败。');
      return;
    }
    await _refreshTasks();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DownloadProjection> visibleTasks = _visibleTasks;
    final bool hasPausableTasks = _snapshot.tasks.any(_canPause);
    final bool hasResumableTasks = _snapshot.tasks.any(_canResume);

    return Padding(
      padding: const EdgeInsets.all(_pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DownloadsToolbar(
            isCreatingTask: _isCreatingTask,
            isRefreshing: _isRefreshing,
            capabilities: _snapshot.capabilities,
            hasPausableTasks: hasPausableTasks,
            hasResumableTasks: hasResumableTasks,
            searchController: _searchController,
            onAddTask: _showCreateTaskDialog,
            onRefresh: _refreshTasks,
            onPauseAll: _pauseAll,
            onResumeAll: _resumeAll,
          ),
          const SizedBox(height: _panelGap),
          if (!_snapshot.capabilities.taskManagementAvailable)
            _CapabilityBanner(capabilities: _snapshot.capabilities),
          _SummaryStrip(tasks: _snapshot.tasks),
          const SizedBox(height: _panelGap),
          _FilterBar(
            selected: _filter,
            onChanged: (_DownloadFilter filter) {
              setState(() {
                _filter = filter;
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool desktop =
                    constraints.maxWidth >= _desktopLayoutBreakpoint;
                final Widget taskList = _TaskListPanel(
                  tasks: visibleTasks,
                  selectedTaskId: _selectedTaskId,
                  onSelect: (DownloadProjection task) {
                    setState(() {
                      _selectedTaskId = task.taskId;
                      _detailSelectedFiles = <DownloadFileIndex>{
                        for (final DownloadFileProjection file in task.files)
                          if (file.isSelected) file.index,
                      };
                    });
                  },
                  onPause: _pauseTask,
                  onResume: _resumeTask,
                  onRemove: _removeTask,
                );
                final Widget detail = _TaskDetailPanel(
                  task: _selectedTask,
                  selectedFiles: _detailSelectedFiles,
                  capabilities: _snapshot.capabilities,
                  onFileToggled: (DownloadFileIndex fileIndex, bool selected) {
                    setState(() {
                      if (selected) {
                        _detailSelectedFiles.add(fileIndex);
                      } else {
                        _detailSelectedFiles.remove(fileIndex);
                      }
                    });
                  },
                  onApplyFiles: _selectedTask == null
                      ? null
                      : () => _applyDetailFileSelection(_selectedTask!),
                );

                if (!desktop) {
                  return Column(
                    children: <Widget>[
                      Expanded(flex: 3, child: taskList),
                      const SizedBox(height: _panelGap),
                      Expanded(flex: 2, child: detail),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: taskList),
                    const SizedBox(width: _panelGap),
                    SizedBox(width: _desktopDetailWidth, child: detail),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsToolbar extends StatelessWidget {
  const _DownloadsToolbar({
    required this.isCreatingTask,
    required this.isRefreshing,
    required this.capabilities,
    required this.hasPausableTasks,
    required this.hasResumableTasks,
    required this.searchController,
    required this.onAddTask,
    required this.onRefresh,
    required this.onPauseAll,
    required this.onResumeAll,
  });

  final bool isCreatingTask;
  final bool isRefreshing;
  final DownloadCapabilityProjection capabilities;
  final bool hasPausableTasks;
  final bool hasResumableTasks;
  final TextEditingController searchController;
  final VoidCallback onAddTask;
  final VoidCallback onRefresh;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Wrap(
      spacing: _toolbarGap,
      runSpacing: _toolbarGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          '下载',
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(
          width: 280,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索任务、来源或哈希',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Tooltip(
          message: '添加下载任务',
          child: FilledButton.icon(
            onPressed: isCreatingTask || !capabilities.canCreateTasks
                ? null
                : onAddTask,
            icon: isCreatingTask
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link, size: 18),
            label: Text(isCreatingTask ? '添加中' : '添加'),
          ),
        ),
        Tooltip(
          message: '刷新任务列表',
          child: IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
        Tooltip(
          message: '暂停全部可暂停任务',
          child: OutlinedButton.icon(
            onPressed: capabilities.taskManagementAvailable && hasPausableTasks
                ? onPauseAll
                : null,
            icon: const Icon(Icons.pause, size: 18),
            label: const Text('全部暂停'),
          ),
        ),
        Tooltip(
          message: '恢复全部可恢复任务',
          child: OutlinedButton.icon(
            onPressed: capabilities.taskManagementAvailable && hasResumableTasks
                ? onResumeAll
                : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('全部恢复'),
          ),
        ),
      ],
    );
  }
}

class _CapabilityBanner extends StatelessWidget {
  const _CapabilityBanner({required this.capabilities});

  final DownloadCapabilityProjection capabilities;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: _panelGap),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentMagenta.withValues(alpha: 0.08),
        border: Border.all(color: theme.accentMagenta.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: theme.accentMagenta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _capabilityMessage(capabilities),
              style: TextStyle(color: theme.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.tasks});

  final List<DownloadProjection> tasks;

  @override
  Widget build(BuildContext context) {
    final int active = tasks.where(_isActive).length;
    final int paused = tasks
        .where((DownloadProjection task) =>
            task.state == DownloadLifecycleState.paused)
        .length;
    final int completed = tasks
        .where((DownloadProjection task) =>
            task.state == DownloadLifecycleState.completed)
        .length;
    final int failed = tasks
        .where((DownloadProjection task) =>
            task.state == DownloadLifecycleState.failed)
        .length;
    final int downloadRate = tasks.fold<int>(
      0,
      (int total, DownloadProjection task) =>
          total + task.downloadRateBytesPerSecond,
    );
    final int uploadRate = tasks.fold<int>(
      0,
      (int total, DownloadProjection task) =>
          total + task.uploadRateBytesPerSecond,
    );
    final int peers = tasks.fold<int>(
      0,
      (int total, DownloadProjection task) => total + task.connectedPeers,
    );

    return SizedBox(
      height: _summaryHeight,
      child: Row(
        children: <Widget>[
          Expanded(child: _SummaryMetric(label: '下载中', value: '$active')),
          Expanded(child: _SummaryMetric(label: '暂停', value: '$paused')),
          Expanded(child: _SummaryMetric(label: '完成', value: '$completed')),
          Expanded(child: _SummaryMetric(label: '失败', value: '$failed')),
          Expanded(
            child: _SummaryMetric(
                label: '下载速度', value: _formatSpeed(downloadRate)),
          ),
          Expanded(
            child:
                _SummaryMetric(label: '上传速度', value: _formatSpeed(uploadRate)),
          ),
          Expanded(child: _SummaryMetric(label: '连接', value: '$peers')),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final _DownloadFilter selected;
  final ValueChanged<_DownloadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final _DownloadFilter filter in _DownloadFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onChanged(filter),
          ),
      ],
    );
  }
}

class _TaskListPanel extends StatelessWidget {
  const _TaskListPanel({
    required this.tasks,
    required this.selectedTaskId,
    required this.onSelect,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final List<DownloadProjection> tasks;
  final DownloadTaskId? selectedTaskId;
  final ValueChanged<DownloadProjection> onSelect;
  final ValueChanged<DownloadProjection> onPause;
  final ValueChanged<DownloadProjection> onResume;
  final ValueChanged<DownloadProjection> onRemove;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: <Widget>[
          _TaskListHeader(theme: theme),
          Divider(height: 1, color: theme.border),
          Expanded(
            child: tasks.isEmpty
                ? const _DownloadsEmptyState()
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DownloadProjection task = tasks[index];
                      return _TaskRow(
                        task: task,
                        selected: task.taskId == selectedTaskId,
                        onSelect: () => onSelect(task),
                        onPause: () => onPause(task),
                        onResume: () => onResume(task),
                        onRemove: () => onRemove(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskListHeader extends StatelessWidget {
  const _TaskListHeader({required this.theme});

  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: _HeaderText('任务', theme: theme),
            ),
            Expanded(
              flex: 2,
              child: _HeaderText('状态', theme: theme),
            ),
            Expanded(
              flex: 2,
              child: _HeaderText('进度', theme: theme),
            ),
            Expanded(
              flex: 2,
              child: _HeaderText('速度', theme: theme),
            ),
            Expanded(
              flex: 1,
              child: _HeaderText('连接', theme: theme),
            ),
            const SizedBox(width: 112),
          ],
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {required this.theme});

  final String text;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.onBackground.withValues(alpha: 0.58),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.selected,
    required this.onSelect,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final DownloadProjection task;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final bool canPause = _canPause(task);
    final bool canResume = _canResume(task);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: selected
            ? theme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          child: SizedBox(
            height: _taskRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_sourceKindLabel(task.sourceKind)} · ${_formatSize(task.totalSizeBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onBackground.withValues(alpha: 0.58),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _StatusPill(state: task.state),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ProgressCell(progress: task.progress),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${_formatSpeed(task.downloadRateBytesPerSecond)} / ${_formatSpeed(task.uploadRateBytesPerSecond)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${task.connectedPeers}',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Tooltip(
                          message: canPause ? '暂停' : '不可暂停',
                          child: IconButton(
                            onPressed: canPause ? onPause : null,
                            icon: const Icon(Icons.pause, size: 18),
                            style: _taskIconButtonStyle,
                          ),
                        ),
                        Tooltip(
                          message: canResume ? '恢复' : '不可恢复',
                          child: IconButton(
                            onPressed: canResume ? onResume : null,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            style: _taskIconButtonStyle,
                          ),
                        ),
                        Tooltip(
                          message: '删除任务',
                          child: IconButton(
                            onPressed: onRemove,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            style: _taskIconButtonStyle,
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

class _ProgressCell extends StatelessWidget {
  const _ProgressCell({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${(progress * _percentMultiplier).toStringAsFixed(1)}%',
          style: TextStyle(color: theme.onSurface, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            color: theme.primary,
            backgroundColor: theme.onBackground.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final DownloadLifecycleState state;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final Color color = switch (state) {
      DownloadLifecycleState.downloading => theme.primary,
      DownloadLifecycleState.completed => Colors.greenAccent,
      DownloadLifecycleState.failed => theme.accentMagenta,
      DownloadLifecycleState.paused => theme.secondary,
      DownloadLifecycleState.fetchingMetadata => theme.primary,
      DownloadLifecycleState.queued ||
      DownloadLifecycleState.ready =>
        theme.onBackground,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _stateLabel(state),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TaskDetailPanel extends StatelessWidget {
  const _TaskDetailPanel({
    required this.task,
    required this.selectedFiles,
    required this.capabilities,
    required this.onFileToggled,
    required this.onApplyFiles,
  });

  final DownloadProjection? task;
  final Set<DownloadFileIndex> selectedFiles;
  final DownloadCapabilityProjection capabilities;
  final void Function(DownloadFileIndex fileIndex, bool selected) onFileToggled;
  final VoidCallback? onApplyFiles;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final DownloadProjection? task = this.task;
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: task == null
          ? const _TaskDetailEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    key: const ValueKey<String>('download-detail-scroll'),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              task.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _DetailTag(text: _stateLabel(task.state)),
                                _DetailTag(
                                  text: _sourceKindLabel(task.sourceKind),
                                ),
                                _DetailTag(
                                  text:
                                      '${task.selectedFileCount}/${task.files.length} 文件',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: theme.border),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _TaskInfoGrid(task: task),
                      ),
                      Divider(height: 1, color: theme.border),
                      _TaskFilesSection(
                        task: task,
                        selectedFiles: selectedFiles,
                        canSelectFiles: capabilities.taskManagementAvailable,
                        onFileToggled: onFileToggled,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          task.latestEvent ?? task.message ?? '暂无事件',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onBackground.withValues(alpha: 0.68),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: selectedFiles.isEmpty ? '至少选择一个文件' : '应用文件选择',
                        child: FilledButton(
                          onPressed: selectedFiles.isEmpty ||
                                  !capabilities.taskManagementAvailable
                              ? null
                              : onApplyFiles,
                          child: const Text('应用选择'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TaskInfoGrid extends StatelessWidget {
  const _TaskInfoGrid({required this.task});

  final DownloadProjection task;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InfoRow(label: '大小', value: _formatSize(task.totalSizeBytes)),
        _InfoRow(
            label: '下载', value: _formatSpeed(task.downloadRateBytesPerSecond)),
        _InfoRow(
            label: '上传', value: _formatSpeed(task.uploadRateBytesPerSecond)),
        _InfoRow(label: '连接', value: '${task.connectedPeers}'),
        _InfoRow(label: 'Info Hash', value: task.infoHash ?? '未知'),
        _InfoRow(
          label: 'Piece',
          value: task.pieceLengthBytes == null
              ? '未知'
              : _formatSize(task.pieceLengthBytes!),
        ),
        _InfoRow(label: '来源', value: task.sourceUri),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.onSurface, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFilesSection extends StatelessWidget {
  const _TaskFilesSection({
    required this.task,
    required this.selectedFiles,
    required this.canSelectFiles,
    required this.onFileToggled,
  });

  final DownloadProjection task;
  final Set<DownloadFileIndex> selectedFiles;
  final bool canSelectFiles;
  final void Function(DownloadFileIndex fileIndex, bool selected) onFileToggled;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    if (task.files.isEmpty) {
      return Center(
        child: Text(
          '等待元数据',
          style: TextStyle(color: theme.onBackground.withValues(alpha: 0.58)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '文件',
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: task.files.length,
          itemBuilder: (BuildContext context, int index) {
            final DownloadFileProjection file = task.files[index];
            final bool selected = selectedFiles.contains(file.index);
            return Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: selected,
                onChanged: canSelectFiles
                    ? (bool? value) => onFileToggled(file.index, value ?? false)
                    : null,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.onSurface, fontSize: 13),
                ),
                subtitle: Text(
                  '#${file.index.value} · ${_formatSize(file.sizeBytes)} · ${file.mediaMimeType ?? 'unknown'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onBackground.withValues(alpha: 0.58),
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.primary, fontSize: 11),
      ),
    );
  }
}

class _DownloadsEmptyState extends StatelessWidget {
  const _DownloadsEmptyState();

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.download_for_offline_outlined,
            size: 48,
            color: theme.onBackground.withValues(alpha: 0.32),
          ),
          const SizedBox(height: 12),
          Text(
            '没有下载任务',
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.62),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailEmptyState extends StatelessWidget {
  const _TaskDetailEmptyState();

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Center(
      child: Text(
        '选择一个任务',
        style: TextStyle(color: theme.onBackground.withValues(alpha: 0.58)),
      ),
    );
  }
}

class _AddDownloadTaskDialog extends StatefulWidget {
  const _AddDownloadTaskDialog();

  @override
  State<_AddDownloadTaskDialog> createState() => _AddDownloadTaskDialogState();
}

class _AddDownloadTaskDialogState extends State<_AddDownloadTaskDialog> {
  final TextEditingController _controller = TextEditingController();
  DownloadCreateMode _mode = DownloadCreateMode.quick;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickTorrentFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['torrent'],
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    _controller.text = Uri.file(path).toString();
  }

  void _submit() {
    final String value = _controller.text.trim();
    final bool isMagnet = value.startsWith('magnet:?');
    final Uri? parsed = Uri.tryParse(value);
    final bool isFileUri = parsed != null && parsed.isScheme('file');
    if (!isMagnet && !isFileUri) {
      setState(() {
        _errorText = '仅支持 magnet 链接或本地 .torrent 文件 URI。';
      });
      return;
    }
    Navigator.of(context).pop(_DownloadAddRequest(value, _mode));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加下载任务'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<DownloadCreateMode>(
              segments: const <ButtonSegment<DownloadCreateMode>>[
                ButtonSegment<DownloadCreateMode>(
                  value: DownloadCreateMode.quick,
                  label: Text('快速添加'),
                  icon: Icon(Icons.flash_on),
                ),
                ButtonSegment<DownloadCreateMode>(
                  value: DownloadCreateMode.advanced,
                  label: Text('高级添加'),
                  icon: Icon(Icons.tune),
                ),
              ],
              selected: <DownloadCreateMode>{_mode},
              onSelectionChanged: (Set<DownloadCreateMode> selection) {
                setState(() {
                  _mode = selection.single;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Magnet 或本地 torrent 文件 URI',
                errorText: _errorText,
                suffixIcon: Tooltip(
                  message: '选择 torrent 文件',
                  child: IconButton(
                    onPressed: _pickTorrentFile,
                    icon: const Icon(Icons.folder_open),
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _FileSelectionDialog extends StatefulWidget {
  const _FileSelectionDialog({required this.task});

  final DownloadProjection task;

  @override
  State<_FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<_FileSelectionDialog> {
  late Set<DownloadFileIndex> _selectedFiles;

  @override
  void initState() {
    super.initState();
    _selectedFiles = <DownloadFileIndex>{
      for (final DownloadFileProjection file in widget.task.files)
        if (file.isSelected) file.index,
    };
    if (_selectedFiles.isEmpty) {
      _selectedFiles = <DownloadFileIndex>{
        for (final DownloadFileProjection file in widget.task.files) file.index,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return AlertDialog(
      title: Text('选择文件：${widget.task.name}'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: ListView.builder(
          itemCount: widget.task.files.length,
          itemBuilder: (BuildContext context, int index) {
            final DownloadFileProjection file = widget.task.files[index];
            final bool selected = _selectedFiles.contains(file.index);
            return CheckboxListTile(
              value: selected,
              onChanged: (bool? value) {
                setState(() {
                  if (value ?? false) {
                    _selectedFiles.add(file.index);
                  } else {
                    _selectedFiles.remove(file.index);
                  }
                });
              },
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${file.path} · ${_formatSize(file.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.62),
                ),
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedFiles.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedFiles),
          child: const Text('确认选择'),
        ),
      ],
    );
  }
}

final class _DownloadAddRequest {
  const _DownloadAddRequest(this.sourceUri, this.mode);

  final String sourceUri;
  final DownloadCreateMode mode;
}

enum _DownloadFilter {
  all('全部'),
  active('下载中'),
  paused('暂停'),
  completed('完成'),
  failed('失败');

  const _DownloadFilter(this.label);

  final String label;

  bool matches(DownloadProjection task) {
    return switch (this) {
      _DownloadFilter.all => true,
      _DownloadFilter.active => _isActive(task),
      _DownloadFilter.paused => task.state == DownloadLifecycleState.paused,
      _DownloadFilter.completed =>
        task.state == DownloadLifecycleState.completed,
      _DownloadFilter.failed => task.state == DownloadLifecycleState.failed,
    };
  }
}

bool _isActive(DownloadProjection task) {
  return task.state == DownloadLifecycleState.downloading ||
      task.state == DownloadLifecycleState.fetchingMetadata ||
      task.state == DownloadLifecycleState.ready ||
      task.state == DownloadLifecycleState.queued;
}

bool _canPause(DownloadProjection task) {
  return task.state == DownloadLifecycleState.downloading ||
      task.state == DownloadLifecycleState.ready ||
      task.state == DownloadLifecycleState.fetchingMetadata ||
      task.state == DownloadLifecycleState.queued;
}

bool _canResume(DownloadProjection task) {
  return task.state == DownloadLifecycleState.paused ||
      task.state == DownloadLifecycleState.ready ||
      task.state == DownloadLifecycleState.queued;
}

String _stateLabel(DownloadLifecycleState state) {
  return switch (state) {
    DownloadLifecycleState.queued => '排队',
    DownloadLifecycleState.fetchingMetadata => '取元数据',
    DownloadLifecycleState.ready => '就绪',
    DownloadLifecycleState.downloading => '下载中',
    DownloadLifecycleState.paused => '暂停',
    DownloadLifecycleState.completed => '完成',
    DownloadLifecycleState.failed => '失败',
  };
}

String _sourceKindLabel(DownloadTaskSourceKind kind) {
  return switch (kind) {
    DownloadTaskSourceKind.magnet => 'Magnet',
    DownloadTaskSourceKind.torrentFile => 'Torrent',
    DownloadTaskSourceKind.unknown => '未知来源',
  };
}

String _capabilityMessage(DownloadCapabilityProjection capabilities) {
  return capabilities.taskManagementReason ??
      capabilities.metadataFetchingReason ??
      '当前运行环境不支持 BT 下载管理。';
}

String _formatSpeed(int bytesPerSecond) {
  return '${_formatSize(bytesPerSecond)}/s';
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < _bytesPerKiB) return '$bytes B';
  final double kib = bytes / _bytesPerKiB;
  if (kib < _bytesPerKiB) return '${kib.toStringAsFixed(1)} KiB';
  final double mib = kib / _bytesPerKiB;
  if (mib < _bytesPerKiB) return '${mib.toStringAsFixed(1)} MiB';
  final double gib = mib / _bytesPerKiB;
  return '${gib.toStringAsFixed(1)} GiB';
}
