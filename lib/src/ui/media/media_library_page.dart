import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/media/media_library.dart';
import '../../domain/media/media_library_folder_preferences.dart';
import '../../domain/media/media_library_runtime.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_source_handoff.dart';
import '../../domain/settings/settings_domain.dart';
import '../../foundation/constants.dart';
import '../theme/elaina_theme.dart';

typedef DirectoryPathPicker = Future<String?> Function();

const double _pagePadding = 24;
const double _sectionGap = 16;
const double _toolbarGap = 10;
const double _summaryGap = 12;
const double _panelRadius = 8;
const double _panelPadding = 16;
const double _desktopBreakpoint = 980;
const double _folderPaneWidth = 320;
const double _detailPaneWidth = 380;
const double _compactFolderPaneHeight = 260;
const double _compactMediaPaneHeight = 420;
const double _compactDetailPaneMinHeight = 360;
const double _searchFieldWidth = 360;
const double _mediaRowMinHeight = 84;
const double _smallIconSize = 18;
const double _progressBarHeight = 6;
const int _progressPercentMultiplier = 100;
const int _datePartWidth = 2;
const String _datePartPadding = '0';
const String _selectedFileMediaIdPrefix = 'selected-file:';
const double _matchDialogWidth = 480;
const MediaLibraryFolderPreferenceCodec _folderPreferenceCodec =
    MediaLibraryFolderPreferenceCodec();
const ButtonStyle _compactIconButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  maximumSize: WidgetStatePropertyAll<Size>(Size.square(32)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Local media library management page.
///
/// This page manages folders, indexed files, playback handoff, and Bangumi
/// binding through MediaLibraryRuntime. It should remain a local-library
/// workspace, not a second tracking page or direct filesystem scanner.
class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({
    super.key,
    required this.mediaLibraryRuntime,
    required this.playbackController,
    required this.settingsRuntime,
    required this.onNavigateToDetail,
    this.directoryPathPicker = _defaultDirectoryPathPicker,
  });

  final MediaLibraryRuntime mediaLibraryRuntime;
  final PlaybackControllerContract playbackController;
  final SettingsRuntime settingsRuntime;
  final ValueChanged<String> onNavigateToDetail;
  final DirectoryPathPicker directoryPathPicker;

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();

  static Future<String?> _defaultDirectoryPathPicker() {
    return FilePicker.getDirectoryPath(
      dialogTitle: '选择媒体库文件夹',
      lockParentWindow: true,
    );
  }
}

class _MediaLibraryPageState extends State<MediaLibraryPage>
    implements MediaLibraryRuntimeObserver {
  late MediaLibraryRuntimeSnapshot _snapshot;
  final TextEditingController _searchController = TextEditingController();
  List<Uri> _configuredFolders = <Uri>[];
  MediaLibraryItemId? _selectedItemId;
  _MediaLibraryFilter _filter = _MediaLibraryFilter.all;
  bool _isRefreshing = false;
  String? _lastScanSummary;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.mediaLibraryRuntime.currentSnapshot;
    _searchController.addListener(_onSearchChanged);
    widget.mediaLibraryRuntime.addObserver(this);
    unawaited(_refreshLibrary());
    unawaited(_loadConfiguredFolders());
  }

  @override
  void didUpdateWidget(MediaLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaLibraryRuntime != widget.mediaLibraryRuntime) {
      oldWidget.mediaLibraryRuntime.removeObserver(this);
      _snapshot = widget.mediaLibraryRuntime.currentSnapshot;
      widget.mediaLibraryRuntime.addObserver(this);
      unawaited(_refreshLibrary());
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    widget.mediaLibraryRuntime.removeObserver(this);
    super.dispose();
  }

  @override
  void onMediaLibraryRuntimeSnapshot(MediaLibraryRuntimeSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _selectedItemId = _resolvedSelectedItemId(_visibleItems);
    });
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _selectedItemId = _resolvedSelectedItemId(_visibleItems);
    });
  }

  List<_MediaLibraryViewItem> get _viewItems {
    // Projection is rebuilt from the runtime snapshot so sorting and folder
    // attribution remain pure UI read-model work. Mutation stays in the
    // runtime/storage layer.
    final List<_MediaLibraryViewItem> items = <_MediaLibraryViewItem>[
      for (final MediaLibraryCatalogItemState itemState
          in _snapshot.catalogItems)
        _MediaLibraryViewItem(
          state: itemState,
          folder: _folderFor(itemState.item.identity.uri),
        ),
    ];
    items.sort(_compareMediaLibraryViewItems);
    return items;
  }

  List<_MediaLibraryViewItem> get _visibleItems {
    final String query = _searchController.text.trim().toLowerCase();
    return <_MediaLibraryViewItem>[
      for (final _MediaLibraryViewItem item in _viewItems)
        if (_filter.matches(item) && item.matchesQuery(query)) item,
    ];
  }

  _MediaLibraryViewItem? get _selectedItem {
    final List<_MediaLibraryViewItem> items = _visibleItems;
    final MediaLibraryItemId? selectedId = _selectedItemId;
    if (selectedId != null) {
      for (final _MediaLibraryViewItem item in items) {
        if (item.item.id.value == selectedId.value) return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  Future<void> _refreshLibrary() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }
    try {
      final MediaLibraryActionResult<MediaLibraryRuntimeSnapshot> result =
          await widget.mediaLibraryRuntime.refresh();
      if (!mounted) return;
      if (!result.isSuccess) {
        _showMessage(result.failure?.message ?? '刷新媒体库失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _triggerScan() async {
    if (_configuredFolders.isEmpty) {
      _showMessage('请先添加媒体库文件夹');
      return;
    }

    final MediaScanScope scope = MediaScanScope(
      roots: _configuredFolders,
      extensions: AppConstants.supportedVideoExtensions,
    );
    final MediaLibraryActionResult<MediaScanResult> scan =
        await widget.mediaLibraryRuntime.scan(scope);
    if (!mounted) return;
    if (!scan.isSuccess) {
      _showMessage(scan.failure?.message ?? '扫描本地库失败');
      return;
    }

    final MediaScanResult scanResult = scan.value!;
    if (scanResult.candidates.isEmpty) {
      await _refreshLibrary();
      _setScanSummary(
        '扫描完成：未发现可导入视频，${scanResult.failures.length} 个失败项。',
      );
      return;
    }

    final MediaLibraryActionResult<MediaImportResult> imported = await widget
        .mediaLibraryRuntime
        .importCandidates(scanResult.candidates);
    if (!mounted) return;
    if (!imported.isSuccess) {
      _showMessage(imported.failure?.message ?? '导入扫描结果失败');
      return;
    }

    final MediaImportResult importResult = imported.value!;
    _setScanSummary(
      '扫描完成：导入 ${importResult.importedCount} 个，'
      '跳过重复 ${importResult.skippedDuplicateCount} 个，'
      '失败 ${importResult.failureCount + scanResult.failures.length} 个。',
    );
  }

  Future<void> _loadConfiguredFolders() async {
    final String? rawValue = await widget.settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    if (!mounted || rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    try {
      final List<Uri> loadedFolders = _folderPreferenceCodec.decode(rawValue);
      if (!mounted) return;
      setState(() {
        _configuredFolders = loadedFolders;
      });
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage('媒体库文件夹配置无效：${error.message}');
      }
    }
  }

  Future<void> _persistConfiguredFolders() {
    return widget.settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.mediaLibraryRoots,
      value: _folderPreferenceCodec.encode(_configuredFolders),
    );
  }

  Future<void> _pickAndAddFolder() async {
    try {
      final String? selectedPath = await widget.directoryPathPicker();
      final Uri? selectedFolder =
          _folderPreferenceCodec.directoryUriFromPath(selectedPath);
      if (selectedFolder == null) return;
      if (_folderPreferenceCodec.containsFolder(
        _configuredFolders,
        selectedFolder,
      )) {
        _showMessage('该文件夹已经在媒体库中');
        return;
      }
      setState(() {
        _configuredFolders = <Uri>[..._configuredFolders, selectedFolder];
      });
      await _persistConfiguredFolders();
    } catch (error) {
      if (mounted) _showMessage('选择文件夹出错：$error');
    }
  }

  Future<void> _pickAndReplaceFolder(Uri existingFolder) async {
    try {
      final String? selectedPath = await widget.directoryPathPicker();
      final Uri? selectedFolder =
          _folderPreferenceCodec.directoryUriFromPath(selectedPath);
      if (selectedFolder == null ||
          _folderPreferenceCodec.sameFolder(existingFolder, selectedFolder)) {
        return;
      }
      setState(() {
        _configuredFolders = _folderPreferenceCodec.replaceFolder(
          folders: _configuredFolders,
          existingFolder: existingFolder,
          replacementFolder: selectedFolder,
        );
      });
      await _persistConfiguredFolders();
    } catch (error) {
      if (mounted) _showMessage('修改文件夹出错：$error');
    }
  }

  Future<void> _removeConfiguredFolder(Uri folder) async {
    setState(() {
      _configuredFolders = <Uri>[
        for (final Uri configuredFolder in _configuredFolders)
          if (!_folderPreferenceCodec.sameFolder(configuredFolder, folder))
            configuredFolder,
      ];
    });
    await _persistConfiguredFolders();
  }

  Future<void> _playItem(MediaLibraryItemId id) async {
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> result =
        await widget.mediaLibraryRuntime.playItem(id);
    await _openPreparedSource(result);
  }

  Future<void> _pickAndPlayFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedVideoExtensions.toList(),
      );
      final PlatformFile? selectedFile =
          result == null || result.files.length != 1 ? null : result.files[0];
      final String? path = selectedFile?.path;
      if (selectedFile == null || path == null) {
        return;
      }

      final Uri fileUri = Uri.file(path);
      // Single-file playback still goes through the media-library handoff path.
      // That keeps validation and PlaybackSource construction out of the UI.
      final MediaScanCandidate candidate = MediaScanCandidate(
        identity: LocalMediaIdentity(
          id: LocalMediaId('$_selectedFileMediaIdPrefix${fileUri.toString()}'),
          uri: fileUri,
          basename: selectedFile.name,
        ),
        sizeBytes: selectedFile.size,
      );
      await _openPreparedSource(
        widget.mediaLibraryRuntime.playCandidate(candidate),
      );
    } catch (error) {
      if (mounted) _showMessage('选择文件出错：$error');
    }
  }

  Future<void> _openPreparedSource(
    MediaLibraryActionResult<PlaybackSourceHandoffResult> result,
  ) async {
    // The runtime prepares a PlaybackSource; the page only opens and starts it.
    // This is the boundary that prevents UI widgets from constructing adapter
    // specific playback sources.
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.failure?.message ?? '准备播放失败');
      return;
    }
    final DomainPlaybackCommandResult openResult =
        await widget.playbackController.open(result.value!.source!);
    if (!mounted) return;
    if (!openResult.isSuccess) {
      _showMessage(openResult.failure?.message ?? '打开媒体失败');
      return;
    }
    final DomainPlaybackCommandResult playResult =
        await widget.playbackController.play();
    if (!mounted || playResult.isSuccess) return;
    _showMessage(playResult.failure?.message ?? '开始播放失败');
  }

  Future<void> _matchBangumi(LocalMediaId mediaId) async {
    final MediaLibraryActionResult<LocalMediaBangumiMatchResult> result =
        await widget.mediaLibraryRuntime.searchBangumiMatches(mediaId);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.failure?.message ?? '匹配失败');
      return;
    }

    final LocalMediaBangumiMatchResult matchResult = result.value!;
    if (matchResult.candidates.isEmpty) {
      _showMessage(matchResult.query.isEmpty ? '无法从文件名生成搜索词' : '未找到匹配候选');
      return;
    }

    final LocalMediaBangumiMatchCandidate? selected =
        await showDialog<LocalMediaBangumiMatchCandidate>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ElainaThemeData theme = ElainaTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelRadius),
            side: BorderSide(color: theme.border),
          ),
          title:
              Text('选择 Bangumi 条目', style: TextStyle(color: theme.onSurface)),
          content: SizedBox(
            width: _matchDialogWidth,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: matchResult.candidates.length,
              separatorBuilder: (BuildContext context, int index) =>
                  Divider(height: 1, color: theme.border),
              itemBuilder: (BuildContext context, int index) {
                final LocalMediaBangumiMatchCandidate candidate =
                    matchResult.candidates[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(
                      candidate.title,
                      style: TextStyle(color: theme.onSurface),
                    ),
                    subtitle: Text(
                      'ID: ${candidate.subjectId.value} · 匹配度 ${_percentLabel(candidate.confidence)}',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.62),
                      ),
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => Navigator.of(dialogContext).pop(candidate),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) return;

    final MediaLibraryActionResult<ProviderBinding> saved =
        await widget.mediaLibraryRuntime.confirmBangumiMatch(
      mediaId: mediaId,
      candidate: selected,
    );
    if (!mounted) return;
    _showMessage(saved.isSuccess ? '已关联 Bangumi 条目' : '保存关联失败');
  }

  Future<void> _removeItem(_MediaLibraryViewItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ElainaThemeData theme = ElainaTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelRadius),
            side: BorderSide(color: theme.border),
          ),
          title: Text('移除索引', style: TextStyle(color: theme.onSurface)),
          content: Text(
            '确认从媒体库索引中移除「${item.title}」？本地文件不会被删除。',
            style: TextStyle(color: theme.onBackground),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline, size: _smallIconSize),
              label: const Text('移除索引'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final MediaLibraryActionResult<bool> removed =
        await widget.mediaLibraryRuntime.remove(item.item.id);
    if (!mounted) return;
    if (!removed.isSuccess) {
      _showMessage(removed.failure?.message ?? '移除索引失败');
      return;
    }
    setState(() {
      _selectedItemId = _resolvedSelectedItemId(_visibleItems);
    });
    _showMessage('已移除索引，本地文件已保留');
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final List<_MediaLibraryViewItem> visibleItems = _visibleItems;
    final _MediaLibraryViewItem? selectedItem = _selectedItem;
    final _MediaLibrarySummary summary = _MediaLibrarySummary.from(
      folders: _configuredFolders,
      items: _viewItems,
    );
    final bool isScanning =
        _snapshot.status == MediaLibraryRuntimeStatus.scanning;
    final int progressCount = _scanProgressCount(_snapshot.scanEvents);

    return Padding(
      padding: const EdgeInsets.all(_pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildToolbar(theme, isScanning, progressCount),
          const SizedBox(height: _sectionGap),
          _SummaryStrip(
            summary: summary,
            scanStatus: _scanStatusLabel(isScanning, progressCount),
            theme: theme,
          ),
          const SizedBox(height: _sectionGap),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= _desktopBreakpoint) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: _folderPaneWidth,
                        child: _buildFolderPane(theme),
                      ),
                      const SizedBox(width: _sectionGap),
                      Expanded(
                        child: _buildMediaPane(theme, visibleItems),
                      ),
                      const SizedBox(width: _sectionGap),
                      SizedBox(
                        width: _detailPaneWidth,
                        child: _buildDetailPane(theme, selectedItem),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: _compactFolderPaneHeight,
                        child: _buildFolderPane(theme),
                      ),
                      const SizedBox(height: _sectionGap),
                      SizedBox(
                        height: _compactMediaPaneHeight,
                        child: _buildMediaPane(theme, visibleItems),
                      ),
                      const SizedBox(height: _sectionGap),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _compactDetailPaneMinHeight,
                        ),
                        child: _buildDetailPane(theme, selectedItem),
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

  Widget _buildToolbar(
    ElainaThemeData theme,
    bool isScanning,
    int progressCount,
  ) {
    final bool canScan = !isScanning && _configuredFolders.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '本地媒体库',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastScanSummary ?? '管理本地文件夹、索引视频与 Bangumi 绑定',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _toolbarGap),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: _toolbarGap,
                runSpacing: _toolbarGap,
                children: <Widget>[
                  Tooltip(
                    message: '添加媒体库文件夹',
                    child: FilledButton.icon(
                      onPressed: _pickAndAddFolder,
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: _smallIconSize,
                      ),
                      label: const Text('添加文件夹'),
                      style: _buttonStyle(theme),
                    ),
                  ),
                  Tooltip(
                    message: canScan ? '扫描所有已配置文件夹' : '请先添加文件夹',
                    child: ElevatedButton.icon(
                      onPressed: canScan ? _triggerScan : null,
                      icon: isScanning
                          ? const SizedBox.square(
                              dimension: _smallIconSize,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_outlined,
                              size: _smallIconSize),
                      label: Text(
                        isScanning ? '扫描中 $progressCount' : '扫描本地库',
                      ),
                      style: _buttonStyle(theme),
                    ),
                  ),
                  Tooltip(
                    message: '打开一个未入库的本地视频',
                    child: OutlinedButton.icon(
                      onPressed: _pickAndPlayFile,
                      icon: const Icon(Icons.folder_open, size: _smallIconSize),
                      label: const Text('打开文件'),
                      style: _outlinedButtonStyle(theme),
                    ),
                  ),
                  Tooltip(
                    message: '刷新媒体库投影',
                    child: IconButton(
                      onPressed: _isRefreshing ? null : _refreshLibrary,
                      mouseCursor: SystemMouseCursors.click,
                      icon: _isRefreshing
                          ? const SizedBox.square(
                              dimension: _smallIconSize,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: _sectionGap),
        Wrap(
          spacing: _toolbarGap,
          runSpacing: _toolbarGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _searchFieldWidth),
              child: TextField(
                controller: _searchController,
                cursorColor: theme.primary,
                style: TextStyle(color: theme.onSurface),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜索文件名、路径或 Bangumi ID',
                  hintStyle: TextStyle(
                    color: theme.onBackground.withValues(alpha: 0.52),
                  ),
                  filled: true,
                  fillColor: theme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_panelRadius),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_panelRadius),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_panelRadius),
                    borderSide: BorderSide(color: theme.primary),
                  ),
                ),
              ),
            ),
            _FilterBar(
              selected: _filter,
              theme: theme,
              onSelected: (_MediaLibraryFilter filter) {
                setState(() {
                  _filter = filter;
                  _selectedItemId = _resolvedSelectedItemId(_visibleItems);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFolderPane(ElainaThemeData theme) {
    return _LibraryPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PanelHeader(
            title: '媒体库文件夹',
            subtitle: '${_configuredFolders.length} 个路径',
            theme: theme,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _configuredFolders.isEmpty
                ? _InlineEmptyState(
                    icon: Icons.folder_off_outlined,
                    title: '暂无文件夹',
                    message: '添加本地文件夹后才能扫描媒体库。',
                    theme: theme,
                  )
                : ListView.separated(
                    itemCount: _configuredFolders.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(height: 1, color: theme.border),
                    itemBuilder: (BuildContext context, int index) {
                      final Uri folder = _configuredFolders[index];
                      return _FolderRow(
                        folder: folder,
                        indexedCount: _indexedCountFor(folder),
                        isScanning: _snapshot.status ==
                            MediaLibraryRuntimeStatus.scanning,
                        theme: theme,
                        onEdit: () => _pickAndReplaceFolder(folder),
                        onRemove: () => _removeConfiguredFolder(folder),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPane(
    ElainaThemeData theme,
    List<_MediaLibraryViewItem> visibleItems,
  ) {
    final String emptyTitle =
        _snapshot.catalogItems.isEmpty ? '还没有索引媒体' : '没有符合条件的媒体';
    final String emptyMessage = _snapshot.catalogItems.isEmpty
        ? '添加文件夹并扫描后，本地视频会出现在这里。'
        : '调整搜索词或筛选条件后再试。';
    final _MediaLibraryViewItem? selectedItem = _selectedItem;
    return _LibraryPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PanelHeader(
            title: '索引媒体',
            subtitle:
                '${visibleItems.length} / ${_snapshot.catalogItems.length} 个文件',
            theme: theme,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleItems.isEmpty
                ? _InlineEmptyState(
                    icon: Icons.video_library_outlined,
                    title: emptyTitle,
                    message: emptyMessage,
                    theme: theme,
                  )
                : ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(height: 1, color: theme.border),
                    itemBuilder: (BuildContext context, int index) {
                      final _MediaLibraryViewItem item = visibleItems[index];
                      final bool selected =
                          selectedItem?.item.id.value == item.item.id.value;
                      return _MediaRow(
                        item: item,
                        selected: selected,
                        theme: theme,
                        onSelected: () {
                          setState(() {
                            _selectedItemId = item.item.id;
                          });
                        },
                        onPlay: () => _playItem(item.item.id),
                        onMatch: () => _matchBangumi(item.mediaId),
                        onOpenDetail: item.subjectId == null
                            ? null
                            : () => widget.onNavigateToDetail(item.subjectId!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(
    ElainaThemeData theme,
    _MediaLibraryViewItem? item,
  ) {
    return _LibraryPanel(
      theme: theme,
      child: item == null
          ? _InlineEmptyState(
              icon: Icons.touch_app_outlined,
              title: '选择一个媒体文件',
              message: '选择后可以播放、匹配 Bangumi、打开详情或移除索引。',
              theme: theme,
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PanelHeader(
                    title: '媒体详情',
                    subtitle: item.bindingLabel,
                    theme: theme,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailField(
                    label: '文件路径',
                    value: item.displayPath,
                    theme: theme,
                  ),
                  _DetailField(
                    label: '所属文件夹',
                    value: item.folder == null
                        ? '未匹配已配置文件夹'
                        : _displayPath(item.folder!),
                    theme: theme,
                  ),
                  _DetailField(
                    label: '时长',
                    value: _durationLabel(item.item.duration),
                    theme: theme,
                  ),
                  _DetailField(
                    label: '加入时间',
                    value: _dateTimeLabel(item.item.addedAt),
                    theme: theme,
                  ),
                  if (item.continueWatching != null) ...<Widget>[
                    _DetailField(
                      label: '观看进度',
                      value: _percentLabel(item.progress),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: _progressBarHeight,
                        backgroundColor: theme.border.withValues(alpha: 0.5),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _DetailActions(
                    item: item,
                    theme: theme,
                    onPlay: () => _playItem(item.item.id),
                    onMatch: () => _matchBangumi(item.mediaId),
                    onOpenDetail: item.subjectId == null
                        ? null
                        : () => widget.onNavigateToDetail(item.subjectId!),
                    onRemove: () => _removeItem(item),
                  ),
                ],
              ),
            ),
    );
  }

  void _setScanSummary(String message) {
    if (!mounted) return;
    setState(() {
      _lastScanSummary = message;
    });
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Uri? _folderFor(Uri mediaUri) {
    for (final Uri folder in _configuredFolders) {
      if (mediaUri.toString().startsWith(folder.toString())) {
        return folder;
      }
    }
    return null;
  }

  int _indexedCountFor(Uri folder) {
    var count = 0;
    for (final MediaLibraryCatalogItemState itemState
        in _snapshot.catalogItems) {
      if (itemState.item.identity.uri
          .toString()
          .startsWith(folder.toString())) {
        count += 1;
      }
    }
    return count;
  }

  MediaLibraryItemId? _resolvedSelectedItemId(
    List<_MediaLibraryViewItem> visibleItems,
  ) {
    final MediaLibraryItemId? selectedId = _selectedItemId;
    if (selectedId != null) {
      for (final _MediaLibraryViewItem item in visibleItems) {
        if (item.item.id.value == selectedId.value) return selectedId;
      }
    }
    return visibleItems.isEmpty ? null : visibleItems.first.item.id;
  }

  String _scanStatusLabel(bool isScanning, int progressCount) {
    if (isScanning) return '扫描中 $progressCount';
    if (_snapshot.failures.isNotEmpty) return '最近扫描有失败';
    return _lastScanSummary ?? '就绪';
  }
}

enum _MediaLibraryFilter {
  all,
  continueWatching,
  bound,
  unbound;

  String get label {
    return switch (this) {
      _MediaLibraryFilter.all => '全部',
      _MediaLibraryFilter.continueWatching => '继续观看',
      _MediaLibraryFilter.bound => '已绑定',
      _MediaLibraryFilter.unbound => '未绑定',
    };
  }

  IconData get icon {
    return switch (this) {
      _MediaLibraryFilter.all => Icons.video_library_outlined,
      _MediaLibraryFilter.continueWatching => Icons.play_circle_outline,
      _MediaLibraryFilter.bound => Icons.link,
      _MediaLibraryFilter.unbound => Icons.link_off,
    };
  }

  bool matches(_MediaLibraryViewItem item) {
    return switch (this) {
      _MediaLibraryFilter.all => true,
      _MediaLibraryFilter.continueWatching => item.continueWatching != null,
      _MediaLibraryFilter.bound => item.binding != null,
      _MediaLibraryFilter.unbound => item.binding == null,
    };
  }
}

final class _MediaLibraryViewItem {
  const _MediaLibraryViewItem({
    required this.state,
    required this.folder,
  });

  final MediaLibraryCatalogItemState state;
  final Uri? folder;

  MediaLibraryItem get item => state.item;
  LocalMediaId get mediaId => item.identity.id;
  ProviderBinding? get binding => state.binding;
  ContinueWatchingState? get continueWatching => state.continueWatching;
  String get title => item.identity.basename;
  String get displayPath => _displayPath(item.identity.uri);
  String? get subjectId => binding?.subjectId?.value;
  double get progress => continueWatching?.progress ?? 0;
  DateTime? get updatedAt => continueWatching?.updatedAt;

  String get bindingLabel {
    final String? id = subjectId;
    if (id == null) return '未绑定 Bangumi';
    return 'Bangumi ID: $id';
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        displayPath.toLowerCase().contains(query) ||
        (subjectId?.toLowerCase().contains(query) ?? false);
  }
}

final class _MediaLibrarySummary {
  const _MediaLibrarySummary({
    required this.folderCount,
    required this.itemCount,
    required this.boundCount,
    required this.continueWatchingCount,
  });

  factory _MediaLibrarySummary.from({
    required Iterable<Uri> folders,
    required Iterable<_MediaLibraryViewItem> items,
  }) {
    var itemCount = 0;
    var boundCount = 0;
    var continueWatchingCount = 0;
    for (final _MediaLibraryViewItem item in items) {
      itemCount += 1;
      if (item.binding != null) boundCount += 1;
      if (item.continueWatching != null) continueWatchingCount += 1;
    }
    return _MediaLibrarySummary(
      folderCount: folders.length,
      itemCount: itemCount,
      boundCount: boundCount,
      continueWatchingCount: continueWatchingCount,
    );
  }

  final int folderCount;
  final int itemCount;
  final int boundCount;
  final int continueWatchingCount;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.summary,
    required this.scanStatus,
    required this.theme,
  });

  final _MediaLibrarySummary summary;
  final String scanStatus;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _MetricTile(
            icon: Icons.folder_outlined,
            label: '文件夹',
            value: '${summary.folderCount}',
            theme: theme,
          ),
          const SizedBox(width: _summaryGap),
          _MetricTile(
            icon: Icons.movie_outlined,
            label: '索引视频',
            value: '${summary.itemCount}',
            theme: theme,
          ),
          const SizedBox(width: _summaryGap),
          _MetricTile(
            icon: Icons.link,
            label: 'Bangumi 绑定',
            value: '${summary.boundCount}',
            theme: theme,
          ),
          const SizedBox(width: _summaryGap),
          _MetricTile(
            icon: Icons.play_circle_outline,
            label: '继续观看',
            value: '${summary.continueWatchingCount}',
            theme: theme,
          ),
          const SizedBox(width: _summaryGap),
          _MetricTile(
            icon: Icons.radar_outlined,
            label: '扫描状态',
            value: scanStatus,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: _LibraryPanel(
        theme: theme,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.primary, size: 22),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.58),
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
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.theme,
    required this.onSelected,
  });

  final _MediaLibraryFilter selected;
  final ElainaThemeData theme;
  final ValueChanged<_MediaLibraryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final _MediaLibraryFilter filter in _MediaLibraryFilter.values)
          Tooltip(
            message: '筛选：${filter.label}',
            child: ChoiceChip(
              avatar: Icon(
                filter.icon,
                size: 16,
                color: selected == filter ? theme.background : theme.primary,
              ),
              label: Text(filter.label),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
              mouseCursor: SystemMouseCursors.click,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected == filter ? theme.background : theme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: theme.primary,
              backgroundColor: theme.surface,
              side: BorderSide(
                color: selected == filter ? theme.primary : theme.border,
              ),
            ),
          ),
      ],
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(_panelPadding),
  });

  final ElainaThemeData theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_panelRadius),
        side: BorderSide(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.indexedCount,
    required this.isScanning,
    required this.theme,
    required this.onEdit,
    required this.onRemove,
  });

  final Uri folder;
  final int indexedCount;
  final bool isScanning;
  final ElainaThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.folder_outlined, color: theme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _displayPath(folder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isScanning ? '扫描中' : '$indexedCount 个视频',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isScanning
                        ? theme.primary
                        : theme.onBackground.withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: '修改文件夹',
            child: IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              mouseCursor: SystemMouseCursors.click,
              style: _compactIconButtonStyle,
            ),
          ),
          Tooltip(
            message: '移除文件夹',
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              mouseCursor: SystemMouseCursors.click,
              style: _compactIconButtonStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.selected,
    required this.theme,
    required this.onSelected,
    required this.onPlay,
    required this.onMatch,
    required this.onOpenDetail,
  });

  final _MediaLibraryViewItem item;
  final bool selected;
  final ElainaThemeData theme;
  final VoidCallback onSelected;
  final VoidCallback onPlay;
  final VoidCallback onMatch;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onSelected,
        child: Ink(
          color: selected ? theme.primary.withValues(alpha: 0.08) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _mediaRowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? theme.primary : theme.border,
                      ),
                    ),
                    child: Icon(
                      Icons.movie_filter_outlined,
                      color: theme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.displayPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onBackground.withValues(alpha: 0.58),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _StatusPill(
                              icon: Icons.timer_outlined,
                              label: _durationLabel(item.item.duration),
                              theme: theme,
                            ),
                            if (item.continueWatching != null)
                              _StatusPill(
                                icon: Icons.play_circle_outline,
                                label: '已观看 ${_percentLabel(item.progress)}',
                                theme: theme,
                              ),
                            _StatusPill(
                              icon: item.binding == null
                                  ? Icons.link_off
                                  : Icons.link,
                              label: item.bindingLabel,
                              theme: theme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 4,
                    children: <Widget>[
                      Tooltip(
                        message: '播放',
                        child: IconButton(
                          onPressed: onPlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                          color: theme.primary,
                          mouseCursor: SystemMouseCursors.click,
                          style: _compactIconButtonStyle,
                        ),
                      ),
                      Tooltip(
                        message: '匹配 Bangumi',
                        child: IconButton(
                          onPressed: onMatch,
                          icon: const Icon(Icons.travel_explore),
                          color: theme.onSurface,
                          mouseCursor: SystemMouseCursors.click,
                          style: _compactIconButtonStyle,
                        ),
                      ),
                      Tooltip(
                        message:
                            item.subjectId == null ? '尚未绑定 Bangumi' : '打开番剧详情',
                        child: IconButton(
                          onPressed: onOpenDetail,
                          icon: const Icon(Icons.info_outline),
                          color: theme.secondary,
                          mouseCursor: SystemMouseCursors.click,
                          style: _compactIconButtonStyle,
                        ),
                      ),
                    ],
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

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.item,
    required this.theme,
    required this.onPlay,
    required this.onMatch,
    required this.onOpenDetail,
    required this.onRemove,
  });

  final _MediaLibraryViewItem item;
  final ElainaThemeData theme;
  final VoidCallback onPlay;
  final VoidCallback onMatch;
  final VoidCallback? onOpenDetail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Tooltip(
          message: '播放当前媒体',
          child: FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: _smallIconSize),
            label: const Text('播放'),
            style: _buttonStyle(theme),
          ),
        ),
        const SizedBox(height: 10),
        Tooltip(
          message: '搜索并绑定 Bangumi 条目',
          child: OutlinedButton.icon(
            onPressed: onMatch,
            icon: const Icon(Icons.travel_explore, size: _smallIconSize),
            label: const Text('匹配 Bangumi'),
            style: _outlinedButtonStyle(theme),
          ),
        ),
        const SizedBox(height: 10),
        Tooltip(
          message: item.subjectId == null ? '尚未绑定 Bangumi' : '打开番剧详情',
          child: OutlinedButton.icon(
            onPressed: onOpenDetail,
            icon: const Icon(Icons.info_outline, size: _smallIconSize),
            label: const Text('打开番剧详情'),
            style: _outlinedButtonStyle(theme),
          ),
        ),
        const SizedBox(height: 10),
        Tooltip(
          message: '只移除索引，不删除本地文件',
          child: OutlinedButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: _smallIconSize),
            label: const Text('移除索引'),
            style: _dangerButtonStyle(theme),
          ),
        ),
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: theme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String message;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: theme.primary.withValues(alpha: 0.72), size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _compareMediaLibraryViewItems(
  _MediaLibraryViewItem left,
  _MediaLibraryViewItem right,
) {
  final DateTime? leftUpdated = left.updatedAt;
  final DateTime? rightUpdated = right.updatedAt;
  if (leftUpdated != null && rightUpdated != null) {
    final int updated = rightUpdated.compareTo(leftUpdated);
    if (updated != 0) return updated;
  } else if (leftUpdated != null) {
    return -1;
  } else if (rightUpdated != null) {
    return 1;
  }
  final int added = right.item.addedAt.compareTo(left.item.addedAt);
  if (added != 0) return added;
  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}

int _scanProgressCount(Iterable<MediaScanEvent> events) {
  var progressCount = 0;
  for (final MediaScanEvent event in events) {
    if (event is MediaScanProgressChanged) {
      progressCount = event.scannedCount;
    }
  }
  return progressCount;
}

ButtonStyle _buttonStyle(ElainaThemeData theme) {
  return ButtonStyle(
    mouseCursor: WidgetStateProperty.resolveWith(_buttonCursor),
    backgroundColor: WidgetStatePropertyAll<Color>(theme.primary),
    foregroundColor: WidgetStatePropertyAll<Color>(theme.background),
  );
}

ButtonStyle _outlinedButtonStyle(ElainaThemeData theme) {
  return ButtonStyle(
    mouseCursor: WidgetStateProperty.resolveWith(_buttonCursor),
    foregroundColor: WidgetStatePropertyAll<Color>(theme.primary),
    side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: theme.primary)),
  );
}

ButtonStyle _dangerButtonStyle(ElainaThemeData theme) {
  return ButtonStyle(
    mouseCursor: WidgetStateProperty.resolveWith(_buttonCursor),
    foregroundColor: WidgetStatePropertyAll<Color>(theme.onBackground),
    side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: theme.border)),
  );
}

MouseCursor _buttonCursor(Set<WidgetState> states) {
  if (states.contains(WidgetState.disabled)) {
    return SystemMouseCursors.basic;
  }
  return SystemMouseCursors.click;
}

String _displayPath(Uri uri) {
  if (!uri.isScheme('file')) return uri.toString();
  return uri.toFilePath();
}

String _durationLabel(Duration? duration) {
  if (duration == null) return '未知时长';
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(Duration.minutesPerHour);
  final int seconds = duration.inSeconds.remainder(Duration.secondsPerMinute);
  if (hours > 0) {
    return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  return '$minutes:${_twoDigits(seconds)}';
}

String _dateTimeLabel(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)} '
      '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String _percentLabel(double ratio) {
  return '${(ratio * _progressPercentMultiplier).round()}%';
}

String _twoDigits(int value) {
  return value.toString().padLeft(_datePartWidth, _datePartPadding);
}
