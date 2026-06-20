import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/download/download_domain.dart';
import '../theme/celesteria_theme.dart';

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
  bool _isCreatingTask = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.downloadRuntime.currentSnapshot;
    widget.downloadRuntime.addObserver(this);
    _refreshTasks();
  }

  @override
  void dispose() {
    widget.downloadRuntime.removeObserver(this);
    super.dispose();
  }

  @override
  void onDownloadRuntimeSnapshot(DownloadRuntimeSnapshot snapshot) {
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
      });
    }
  }

  Future<void> _refreshTasks() async {
    await widget.downloadRuntime.listTasks();
  }

  Future<void> _showCreateTaskDialog() async {
    final String? sourceUri = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _AddDownloadTaskDialog(),
    );
    if (sourceUri == null || sourceUri.trim().isEmpty) return;

    setState(() {
      _isCreatingTask = true;
    });
    try {
      final DownloadCreateResult result =
          await widget.downloadRuntime.createTaskFromUri(sourceUri);
      if (!mounted) return;
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.failureMessage ?? 'Create task failed.')),
        );
        return;
      }
      if (result.hasWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.warningMessage!)),
        );
      }
      await _refreshTasks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create task failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }

  Future<void> _pauseTask(DownloadTaskId taskId) async {
    await widget.downloadRuntime.pause(taskId);
    if (!mounted) return;
    await _refreshTasks();
  }

  Future<void> _resumeTask(DownloadTaskId taskId) async {
    await widget.downloadRuntime.resume(taskId);
    if (!mounted) return;
    await _refreshTasks();
  }

  Future<void> _removeTask(DownloadTaskId taskId) async {
    await widget.downloadRuntime.remove(taskId);
    if (!mounted) return;
    await _refreshTasks();
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    final double kb = bytesPerSecond / 1024.0;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB/s';
    }
    final double mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB/s';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    final double kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final double gb = mb / 1024.0;
    return '${gb.toStringAsFixed(1)} GB';
  }

  static const int _totalPieceBlocks = 64;
  static const int _pieceGridColumns = 16;

  // Visual piece grid helper
  Widget _buildPieceMap(double progress, CelesteriaThemeData theme) {
    const int totalBlocks = _totalPieceBlocks;
    final int completedBlocks = (progress * totalBlocks).round();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _pieceGridColumns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: totalBlocks,
      itemBuilder: (BuildContext context, int index) {
        final bool isDone = index < completedBlocks;
        return Container(
          decoration: BoxDecoration(
            color: isDone
                ? theme.primary
                : theme.onBackground.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color:
                  isDone ? theme.primary : theme.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CelesteriaThemeData theme = CelesteriaTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '下载与缓存管理',
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isCreatingTask ? null : _showCreateTaskDialog,
                icon: _isCreatingTask
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link, size: 18),
                label: Text(_isCreatingTask ? 'Creating...' : 'Add task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: theme.background,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync_outlined),
                color: theme.primary,
                onPressed: _refreshTasks,
                tooltip: '刷新下载任务列表',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Task List
          Expanded(
            child: _snapshot.tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.download_for_offline_outlined,
                          size: 64,
                          color: theme.secondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无进行中的下载任务。',
                          style: TextStyle(
                            color: theme.onBackground.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _snapshot.tasks.length,
                    itemBuilder: (BuildContext context, int index) {
                      final task = _snapshot.tasks[index];
                      final name = task.name;
                      final isDownloading = task.state ==
                              DownloadLifecycleState.downloading ||
                          task.state == DownloadLifecycleState.fetchingMetadata;

                      final double progress = task.progress;
                      final int downloadRate = task.downloadRateBytesPerSecond;
                      final int peers = task.connectedPeers;
                      final int totalSize = task.totalSizeBytes;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: theme.border),
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Top Row: Title and status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isDownloading
                                            ? theme.primary
                                            : theme.secondary)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.state.name.toUpperCase(),
                                    style: TextStyle(
                                      color: isDownloading
                                          ? theme.primary
                                          : theme.secondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Middle row: progress details and speed
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  '已完成: ${(progress * 100.0).toStringAsFixed(1)}% (${_formatSize((totalSize * progress).round())} / ${_formatSize(totalSize)})',
                                  style: TextStyle(
                                    color: theme.onBackground
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '速度: ${_formatSpeed(downloadRate)} | 连接对等点 (Peers): $peers',
                                  style: TextStyle(
                                    color: theme.onBackground
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    theme.onBackground.withValues(alpha: 0.05),
                                color: theme.primary,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bottom row: Piece grid & control buttons
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Dynamic Piece Map
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '分片文件拼图 (Piece map)',
                                        style: TextStyle(
                                          color: theme.onBackground
                                              .withValues(alpha: 0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        child: _buildPieceMap(progress, theme),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),

                                // Controls
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        if (isDownloading)
                                          IconButton(
                                            icon: const Icon(Icons.pause),
                                            color: theme.secondary,
                                            onPressed: () =>
                                                _pauseTask(task.taskId),
                                            tooltip: '暂停下载',
                                          )
                                        else
                                          IconButton(
                                            icon: const Icon(Icons.play_arrow),
                                            color: theme.primary,
                                            onPressed: () =>
                                                _resumeTask(task.taskId),
                                            tooltip: '恢复下载',
                                          ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          color: theme.accentMagenta,
                                          onPressed: () =>
                                              _removeTask(task.taskId),
                                          tooltip: '删除任务',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    final bool isMagnet = value.startsWith('magnet:?');
    final Uri? parsed = Uri.tryParse(value);
    final bool isSupportedFileUri = parsed != null &&
        (parsed.isScheme('file') ||
            parsed.isScheme('http') ||
            parsed.isScheme('https'));
    if (!isMagnet && !isSupportedFileUri) {
      setState(() {
        _errorText = 'Use a magnet link, local file URI, or HTTP(S) URL.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add download task'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Magnet or file URL',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
