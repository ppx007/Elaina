import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/media/media_library.dart';
import '../../domain/media/media_library_runtime.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_source_handoff.dart';
import '../../domain/settings/settings_domain.dart';
import '../../foundation/constants.dart';
import '../theme/elaina_theme.dart';

typedef DirectoryPathPicker = Future<String?> Function();

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
  static const String _selectedFileMediaIdPrefix = 'selected-file:';

  late MediaLibraryRuntimeSnapshot _snapshot;
  List<Uri> _configuredFolders = <Uri>[];

  @override
  void initState() {
    super.initState();
    _snapshot = widget.mediaLibraryRuntime.currentSnapshot;
    widget.mediaLibraryRuntime.addObserver(this);
    _refreshLibrary();
    _loadConfiguredFolders();
  }

  @override
  void dispose() {
    widget.mediaLibraryRuntime.removeObserver(this);
    super.dispose();
  }

  @override
  void onMediaLibraryRuntimeSnapshot(MediaLibraryRuntimeSnapshot snapshot) {
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
      });
    }
  }

  Future<void> _refreshLibrary() async {
    await widget.mediaLibraryRuntime.refresh();
  }

  Future<void> _triggerScan() async {
    if (_configuredFolders.isEmpty) {
      return;
    }
    final MediaScanScope scope = MediaScanScope(
      roots: _configuredFolders,
      extensions: AppConstants.supportedVideoExtensions,
    );
    final MediaLibraryActionResult<MediaScanResult> result =
        await widget.mediaLibraryRuntime.scan(scope);
    if (result.isSuccess && mounted) {
      final List<MediaScanCandidate> candidates =
          result.value!.candidates.toList();
      if (candidates.isNotEmpty) {
        await widget.mediaLibraryRuntime.importCandidates(candidates);
      } else {
        await _refreshLibrary();
      }
    }
  }

  Future<void> _loadConfiguredFolders() async {
    final String? rawValue = await widget.settingsRuntime
        .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
    if (!mounted || rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    final List<Uri>? loadedFolders = _decodeConfiguredFolders(rawValue);
    if (loadedFolders == null) {
      return;
    }
    setState(() {
      _configuredFolders = loadedFolders;
    });
  }

  Future<void> _persistConfiguredFolders() {
    return widget.settingsRuntime.setPreference(
      key: SettingsPreferenceKeys.mediaLibraryRoots,
      value: jsonEncode(<String>[
        for (final Uri folder in _configuredFolders) folder.toString(),
      ]),
    );
  }

  Future<void> _pickAndAddFolder() async {
    try {
      final String? selectedPath = await widget.directoryPathPicker();
      final Uri? selectedFolder = _directoryUriFromPath(selectedPath);
      if (selectedFolder == null || _containsConfiguredFolder(selectedFolder)) {
        return;
      }
      setState(() {
        _configuredFolders = <Uri>[..._configuredFolders, selectedFolder];
      });
      await _persistConfiguredFolders();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件夹出错: $error')),
      );
    }
  }

  Future<void> _pickAndReplaceFolder(Uri existingFolder) async {
    try {
      final String? selectedPath = await widget.directoryPathPicker();
      final Uri? selectedFolder = _directoryUriFromPath(selectedPath);
      if (selectedFolder == null ||
          _sameFolder(existingFolder, selectedFolder)) {
        return;
      }
      setState(() {
        _configuredFolders = _replaceConfiguredFolder(
          folders: _configuredFolders,
          existingFolder: existingFolder,
          replacementFolder: selectedFolder,
        );
      });
      await _persistConfiguredFolders();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改文件夹出错: $error')),
      );
    }
  }

  Future<void> _removeConfiguredFolder(Uri folder) async {
    setState(() {
      _configuredFolders = <Uri>[
        for (final Uri configuredFolder in _configuredFolders)
          if (!_sameFolder(configuredFolder, folder)) configuredFolder,
      ];
    });
    await _persistConfiguredFolders();
  }

  bool _containsConfiguredFolder(Uri folder) {
    for (final Uri configuredFolder in _configuredFolders) {
      if (_sameFolder(configuredFolder, folder)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _playItem(MediaLibraryItemId id) async {
    final MediaLibraryActionResult<PlaybackSourceHandoffResult> result =
        await widget.mediaLibraryRuntime.playItem(id);
    if (result.isSuccess && mounted) {
      final DomainPlaybackCommandResult openResult =
          await widget.playbackController.open(result.value!.source!);
      if (openResult.isSuccess) {
        await widget.playbackController.play();
      }
    }
  }

  Future<void> _pickAndPlayFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.video,
      );
      final PlatformFile? selectedFile =
          result == null || result.files.length != 1 ? null : result.files[0];
      final String? path = selectedFile?.path;
      if (selectedFile == null || path == null) {
        return;
      }

      final Uri fileUri = Uri.file(path);
      const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
      final PlaybackSourceHandoffResult prepared = handoff.prepare(
        PlaybackSourceHandoffInput.localMediaIdentity(
          LocalMediaIdentity(
            id: LocalMediaId(
                '$_selectedFileMediaIdPrefix${fileUri.toString()}'),
            uri: fileUri,
            basename: selectedFile.name,
          ),
        ),
      );

      if (!mounted) return;
      if (!prepared.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析文件失败: ${prepared.failure?.message}')),
        );
        return;
      }

      final DomainPlaybackCommandResult openResult =
          await widget.playbackController.open(prepared.source!);
      if (!mounted) return;
      if (!openResult.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: ${openResult.failure?.message}')),
        );
        return;
      }
      await widget.playbackController.play();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件出错: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final bool isScanning =
        _snapshot.status == MediaLibraryRuntimeStatus.scanning;
    final bool canScan = !isScanning && _configuredFolders.isNotEmpty;

    // Get scanned count from progress changed events
    int progressCount = 0;
    for (final event in _snapshot.scanEvents) {
      if (event is MediaScanProgressChanged) {
        progressCount = event.scannedCount;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  '本地媒体库',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _pickAndPlayFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('打开文件'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primary,
                      side: BorderSide(
                        color: theme.primary.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: canScan ? _triggerScan : null,
                    icon: isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_outlined, size: 18),
                    label:
                        Text(isScanning ? '正在扫描 ($progressCount)...' : '扫描本地库'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.background,
                      elevation: 4,
                      shadowColor: theme.primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Configured Folders Panel
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: theme.border, width: 1.0),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '配置的文件夹',
                        style: TextStyle(
                          color: theme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickAndAddFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('添加文件夹'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primary,
                        side: BorderSide(
                          color: theme.primary.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white10),
                if (_configuredFolders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '暂无文件夹',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.58),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ..._configuredFolders.map((Uri root) {
                  final String displayPath = root.toFilePath();
                  final int itemsCount =
                      _snapshot.catalogItems.where((itemState) {
                    return itemState.item.identity.uri
                        .toString()
                        .startsWith(root.toString());
                  }).length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                displayPath,
                                style: TextStyle(
                                  color: theme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isScanning ? '扫描中...' : '同步状态: 正常',
                                style: TextStyle(
                                  color: isScanning
                                      ? theme.primary
                                      : theme.onBackground
                                          .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$itemsCount 个视频',
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _pickAndReplaceFolder(root),
                              icon: const Icon(Icons.edit_outlined),
                              color: theme.primary,
                              tooltip: '修改文件夹',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _removeConfiguredFolder(root),
                              icon: const Icon(Icons.delete_outline),
                              color: theme.onBackground.withValues(alpha: 0.62),
                              tooltip: '移除文件夹',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Catalog Items Title
          Text(
            '已索引内容 (${_snapshot.catalogItems.length})',
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Grid list of Media Items
          Expanded(
            child: _snapshot.catalogItems.isEmpty
                ? Center(
                    child: Text(
                      '本地库中暂无视频，请点击上方“扫描本地库”开始同步。',
                      style: TextStyle(
                        color: theme.onBackground.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _snapshot.catalogItems.length,
                    itemBuilder: (BuildContext context, int index) {
                      final itemState = _snapshot.catalogItems[index];
                      final item = itemState.item;
                      final binding = itemState.binding;

                      return Container(
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: theme.border, width: 1.0),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.identity.basename,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (binding != null) ...<Widget>[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.secondary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '关联 ID: ${binding.subjectId?.value}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.secondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                if (binding != null)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    color: theme.secondary,
                                    onPressed: () => widget.onNavigateToDetail(
                                      binding.subjectId!.value,
                                    ),
                                    tooltip: '查看番剧详情',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  color: theme.primary,
                                  onPressed: () => _playItem(item.id),
                                  tooltip: '立即播放',
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

List<Uri>? _decodeConfiguredFolders(String rawValue) {
  try {
    final Object? decoded = jsonDecode(rawValue);
    if (decoded is! List<Object?>) {
      return null;
    }
    final List<Uri> folders = <Uri>[];
    for (final Object? value in decoded) {
      if (value is! String) {
        return null;
      }
      final Uri? uri = Uri.tryParse(value);
      if (uri == null || !uri.isScheme('file')) {
        return null;
      }
      folders.add(uri);
    }
    return folders;
  } on FormatException {
    return null;
  }
}

Uri? _directoryUriFromPath(String? path) {
  final String? trimmedPath = path?.trim();
  if (trimmedPath == null || trimmedPath.isEmpty) {
    return null;
  }
  return Uri.directory(trimmedPath);
}

bool _sameFolder(Uri left, Uri right) {
  return _folderKey(left) == _folderKey(right);
}

String _folderKey(Uri uri) {
  return uri.toString().toLowerCase();
}

List<Uri> _replaceConfiguredFolder({
  required List<Uri> folders,
  required Uri existingFolder,
  required Uri replacementFolder,
}) {
  final List<Uri> updatedFolders = <Uri>[];
  var replaced = false;
  for (final Uri folder in folders) {
    if (_sameFolder(folder, existingFolder)) {
      if (!updatedFolders
          .any((Uri value) => _sameFolder(value, replacementFolder))) {
        updatedFolders.add(replacementFolder);
      }
      replaced = true;
      continue;
    }
    if (!_sameFolder(folder, replacementFolder)) {
      updatedFolders.add(folder);
    }
  }
  if (!replaced &&
      !updatedFolders
          .any((Uri value) => _sameFolder(value, replacementFolder))) {
    updatedFolders.add(replacementFolder);
  }
  return updatedFolders;
}
