import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/media/media_library_folder_preferences.dart';
import '../../domain/profile/bangumi_login_domain.dart';
import '../../domain/settings/settings_domain.dart';
import '../theme/elaina_theme.dart';

typedef SettingsDirectoryPathPicker = Future<String?> Function();

const double _pagePadding = 24;
const double _sectionGap = 16;
const double _sectionRailWidth = 220;
const double _desktopBreakpoint = 820;
const double _panelRadius = 8;
const double _panelPadding = 18;
const double _rowGap = 16;
const double _fieldMaxWidth = 440;
const double _smallIconSize = 18;
const MediaLibraryFolderPreferenceCodec _folderPreferenceCodec =
    MediaLibraryFolderPreferenceCodec();

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsRuntime,
    this.bangumiLoginController,
    this.onBangumiAuthChanged,
    this.directoryPathPicker = _defaultDirectoryPathPicker,
  });

  final SettingsRuntime settingsRuntime;
  final BangumiLoginController? bangumiLoginController;
  final VoidCallback? onBangumiAuthChanged;
  final SettingsDirectoryPathPicker directoryPathPicker;

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<String?> _defaultDirectoryPathPicker() {
    return FilePicker.getDirectoryPath(
      dialogTitle: '选择媒体库文件夹',
      lockParentWindow: true,
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _proxyController = TextEditingController();
  final TextEditingController _dnsController = TextEditingController();
  final TextEditingController _bangumiTokenController = TextEditingController();
  final TextEditingController _bangumiMirrorApiController =
      TextEditingController();
  final TextEditingController _bangumiMirrorImageController =
      TextEditingController();

  _SettingsSection _selectedSection = _SettingsSection.appearance;
  bool _isLoading = true;
  bool _bangumiMirrorEnabled = false;
  bool _isBangumiOAuthOpening = false;
  bool _isBangumiTokenSaving = false;
  List<Uri> _mediaLibraryFolders = <Uri>[];
  String? _loadMessage;
  String? _bangumiAuthMessage;
  String? _bangumiMirrorMessage;
  String? _networkMessage;
  String? _mediaLibraryMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _dnsController.dispose();
    _bangumiTokenController.dispose();
    _bangumiMirrorApiController.dispose();
    _bangumiMirrorImageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final String? bangumiTokenStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiAccessToken);
      final String? bangumiMirrorEnabledStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorEnabled);
      final String? bangumiMirrorApiStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorApiBaseUrl);
      final String? bangumiMirrorImageStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiMirrorImageBaseUrl);
      final String? mediaRootsStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.mediaLibraryRoots);
      final String? proxyUrl = await widget.settingsRuntime.getProxyUrl();
      final String? dnsPolicy = await widget.settingsRuntime.getDnsPolicy();

      final _DecodedFolders decodedFolders =
          _decodeMediaLibraryFolders(mediaRootsStr);

      if (!mounted) return;
      setState(() {
        _bangumiTokenController.text = bangumiTokenStr ?? '';
        _bangumiMirrorEnabled =
            BangumiMirrorSettings.isEnabled(bangumiMirrorEnabledStr);
        _bangumiMirrorApiController.text = bangumiMirrorApiStr ?? '';
        _bangumiMirrorImageController.text = bangumiMirrorImageStr ?? '';
        _proxyController.text = proxyUrl ?? '';
        _dnsController.text = dnsPolicy ?? '';
        _mediaLibraryFolders = decodedFolders.folders;
        _mediaLibraryMessage = decodedFolders.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadMessage = '加载设置失败：$error';
        _isLoading = false;
      });
    }
  }

  _DecodedFolders _decodeMediaLibraryFolders(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const _DecodedFolders(folders: <Uri>[]);
    }
    try {
      return _DecodedFolders(
        folders: _folderPreferenceCodec.decode(rawValue),
      );
    } on FormatException catch (error) {
      return _DecodedFolders(
        folders: const <Uri>[],
        message: '媒体库路径配置无效：${error.message}',
      );
    }
  }

  Future<void> _savePreference(String key, String value) {
    return widget.settingsRuntime.setPreference(key: key, value: value);
  }

  Future<void> _startBangumiOAuth() async {
    if (_isBangumiOAuthOpening) return;
    final BangumiLoginController? loginController =
        widget.bangumiLoginController;
    if (loginController == null) {
      _showBangumiAuthMessage('Bangumi OAuth 登录控制器不可用');
      return;
    }

    setState(() {
      _isBangumiOAuthOpening = true;
      _bangumiAuthMessage = null;
    });
    final BangumiLoginStartResult result = await loginController.startLogin();
    if (!mounted) return;
    final String message = switch (result.status) {
      BangumiLoginStartStatus.opened => '已打开 Bangumi OAuth 授权页',
      BangumiLoginStartStatus.unavailable =>
        result.message ?? 'Bangumi OAuth 授权页不可用',
      BangumiLoginStartStatus.failed =>
        result.message ?? 'Bangumi OAuth 授权页打开失败',
    };
    setState(() {
      _isBangumiOAuthOpening = false;
      _bangumiAuthMessage = message;
    });
    _showSnack(message);
  }

  Future<void> _submitBangumiToken() async {
    if (_isBangumiTokenSaving) return;
    setState(() {
      _isBangumiTokenSaving = true;
      _bangumiAuthMessage = null;
    });

    final String token = _bangumiTokenController.text.trim();
    final BangumiLoginController? loginController =
        widget.bangumiLoginController;
    if (loginController == null) {
      await _savePreference(SettingsPreferenceKeys.bangumiAccessToken, token);
      widget.onBangumiAuthChanged?.call();
      if (!mounted) return;
      setState(() {
        _isBangumiTokenSaving = false;
        _bangumiAuthMessage =
            token.isEmpty ? 'Bangumi 已退出登录' : 'Bangumi token 已保存';
      });
      return;
    }

    final BangumiTokenSignInResult result =
        await loginController.signInWithAccessToken(token);
    if (!mounted) return;
    if (result.status != BangumiTokenSignInStatus.failed) {
      widget.onBangumiAuthChanged?.call();
    }
    final String message = switch (result.status) {
      BangumiTokenSignInStatus.signedIn =>
        'Bangumi 已登录：${result.profile?.displayName ?? '用户'}',
      BangumiTokenSignInStatus.signedOut => 'Bangumi 已退出登录',
      BangumiTokenSignInStatus.failed => result.message ?? 'Bangumi 登录失败',
    };
    setState(() {
      _isBangumiTokenSaving = false;
      _bangumiAuthMessage = message;
    });
    _showSnack(message);
  }

  Future<void> _setBangumiMirrorEnabled(bool value) async {
    if (!value) {
      setState(() {
        _bangumiMirrorEnabled = false;
        _bangumiMirrorMessage = 'Bangumi 镜像已关闭';
      });
      await _savePreference(
        SettingsPreferenceKeys.bangumiMirrorEnabled,
        BangumiMirrorSettings.disabledValue,
      );
      return;
    }

    final String? validationMessage = _bangumiMirrorValidationMessage();
    if (validationMessage != null) {
      setState(() {
        _bangumiMirrorEnabled = false;
        _bangumiMirrorMessage = validationMessage;
      });
      await _savePreference(
        SettingsPreferenceKeys.bangumiMirrorEnabled,
        BangumiMirrorSettings.disabledValue,
      );
      return;
    }

    await _persistBangumiMirrorUrls();
    await _savePreference(
      SettingsPreferenceKeys.bangumiMirrorEnabled,
      BangumiMirrorSettings.enabledValue,
    );
    if (!mounted) return;
    setState(() {
      _bangumiMirrorEnabled = true;
      _bangumiMirrorMessage = 'Bangumi 镜像已开启';
    });
  }

  Future<void> _saveBangumiMirrorSettings() async {
    final String? validationMessage = _bangumiMirrorValidationMessage();
    if (validationMessage != null) {
      if (_bangumiMirrorEnabled) {
        await _savePreference(
          SettingsPreferenceKeys.bangumiMirrorEnabled,
          BangumiMirrorSettings.disabledValue,
        );
      }
      if (!mounted) return;
      setState(() {
        _bangumiMirrorEnabled = false;
        _bangumiMirrorMessage = validationMessage;
      });
      return;
    }
    await _persistBangumiMirrorUrls();
    if (!mounted) return;
    setState(() {
      _bangumiMirrorMessage = 'Bangumi 镜像地址已保存';
    });
  }

  Future<void> _persistBangumiMirrorUrls() async {
    await _savePreference(
      SettingsPreferenceKeys.bangumiMirrorApiBaseUrl,
      _bangumiMirrorApiController.text.trim(),
    );
    await _savePreference(
      SettingsPreferenceKeys.bangumiMirrorImageBaseUrl,
      _bangumiMirrorImageController.text.trim(),
    );
  }

  String? _bangumiMirrorValidationMessage() {
    try {
      BangumiMirrorSettings.parseBaseUri(
        _bangumiMirrorApiController.text,
        fieldName: 'Bangumi API 镜像地址',
      );
      BangumiMirrorSettings.parseBaseUri(
        _bangumiMirrorImageController.text,
        fieldName: 'Bangumi 图片镜像地址',
      );
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _saveProxy() async {
    await widget.settingsRuntime.saveProxyUrl(_proxyController.text.trim());
    if (!mounted) return;
    setState(() {
      _networkMessage = 'HTTP 代理已保存';
    });
  }

  Future<void> _saveDns() async {
    await widget.settingsRuntime.saveDnsPolicy(_dnsController.text.trim());
    if (!mounted) return;
    setState(() {
      _networkMessage = 'DNS 策略已保存';
    });
  }

  Future<void> _pickAndAddFolder() async {
    final String? selectedPath = await widget.directoryPathPicker();
    final Uri? selectedFolder =
        _folderPreferenceCodec.directoryUriFromPath(selectedPath);
    if (selectedFolder == null) return;
    if (_folderPreferenceCodec.containsFolder(
      _mediaLibraryFolders,
      selectedFolder,
    )) {
      _showMediaLibraryMessage('该文件夹已经在媒体库路径中');
      return;
    }
    setState(() {
      _mediaLibraryFolders = <Uri>[..._mediaLibraryFolders, selectedFolder];
    });
    await _persistMediaLibraryFolders('媒体库路径已添加');
  }

  Future<void> _pickAndReplaceFolder(Uri existingFolder) async {
    final String? selectedPath = await widget.directoryPathPicker();
    final Uri? selectedFolder =
        _folderPreferenceCodec.directoryUriFromPath(selectedPath);
    if (selectedFolder == null ||
        _folderPreferenceCodec.sameFolder(existingFolder, selectedFolder)) {
      return;
    }
    setState(() {
      _mediaLibraryFolders = _folderPreferenceCodec.replaceFolder(
        folders: _mediaLibraryFolders,
        existingFolder: existingFolder,
        replacementFolder: selectedFolder,
      );
    });
    await _persistMediaLibraryFolders('媒体库路径已更新');
  }

  Future<void> _removeFolder(Uri folder) async {
    setState(() {
      _mediaLibraryFolders = <Uri>[
        for (final Uri configuredFolder in _mediaLibraryFolders)
          if (!_folderPreferenceCodec.sameFolder(configuredFolder, folder))
            configuredFolder,
      ];
    });
    await _persistMediaLibraryFolders('媒体库路径已移除');
  }

  Future<void> _persistMediaLibraryFolders(String message) async {
    await _savePreference(
      SettingsPreferenceKeys.mediaLibraryRoots,
      _folderPreferenceCodec.encode(_mediaLibraryFolders),
    );
    if (!mounted) return;
    setState(() {
      _mediaLibraryMessage = message;
    });
  }

  void _showBangumiAuthMessage(String message) {
    setState(() {
      _bangumiAuthMessage = message;
    });
    _showSnack(message);
  }

  void _showMediaLibraryMessage(String message) {
    setState(() {
      _mediaLibraryMessage = message;
    });
    _showSnack(message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadMessage != null) {
      return Center(
        child: Text(
          _loadMessage!,
          style: TextStyle(color: theme.onSurface),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(_pagePadding),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget content = _buildSectionContent(context, theme);
          if (constraints.maxWidth >= _desktopBreakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: _sectionRailWidth,
                  child: _buildSectionRail(theme),
                ),
                const SizedBox(width: _sectionGap),
                Expanded(child: content),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildCompactSectionPicker(theme),
              const SizedBox(height: _sectionGap),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionRail(ElainaThemeData theme) {
    return _SettingsPanel(
      theme: theme,
      padding: const EdgeInsets.all(10),
      child: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '设置中心',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final _SettingsSection section in _SettingsSection.values)
            _SectionButton(
              section: section,
              selected: _selectedSection == section,
              theme: theme,
              onTap: () {
                setState(() {
                  _selectedSection = section;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompactSectionPicker(ElainaThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final _SettingsSection section in _SettingsSection.values) ...[
            ChoiceChip(
              label: Text(section.label),
              avatar: Icon(section.icon, size: _smallIconSize),
              selected: _selectedSection == section,
              onSelected: (_) {
                setState(() {
                  _selectedSection = section;
                });
              },
              mouseCursor: SystemMouseCursors.click,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, ElainaThemeData theme) {
    return ListView(
      children: <Widget>[
        _SectionHeader(
          title: _selectedSection.label,
          subtitle: _selectedSection.description,
          icon: _selectedSection.icon,
          theme: theme,
        ),
        const SizedBox(height: _sectionGap),
        switch (_selectedSection) {
          _SettingsSection.appearance =>
            _buildAppearanceSection(context, theme),
          _SettingsSection.bangumi => _buildBangumiSection(theme),
          _SettingsSection.network => _buildNetworkSection(theme),
          _SettingsSection.mediaLibrary => _buildMediaLibrarySection(theme),
        },
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    ElainaThemeData theme,
  ) {
    final ElainaTheme themeController = ElainaTheme.controllerOf(context);
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsRow(
          title: '主题模式',
          subtitle: '控制应用整体明暗模式，设置会在下次启动时恢复。',
          theme: theme,
          trailing: SegmentedButton<ElainaThemeMode>(
            key: const ValueKey<String>('settings-theme-mode'),
            segments: const <ButtonSegment<ElainaThemeMode>>[
              ButtonSegment<ElainaThemeMode>(
                value: ElainaThemeMode.auto,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('跟随系统'),
              ),
              ButtonSegment<ElainaThemeMode>(
                value: ElainaThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('浅色'),
              ),
              ButtonSegment<ElainaThemeMode>(
                value: ElainaThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('深色'),
              ),
            ],
            selected: <ElainaThemeMode>{themeController.mode},
            onSelectionChanged: (Set<ElainaThemeMode> value) {
              themeController.onModeChanged(value.single);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBangumiSection(ElainaThemeData theme) {
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsRow(
          title: 'OAuth 授权页',
          subtitle: '打开 Bangumi 授权页面。当前没有回调服务，授权后仍需粘贴 access token。',
          theme: theme,
          trailing: Tooltip(
            message: '打开 Bangumi OAuth 授权页',
            child: FilledButton.icon(
              key: const ValueKey<String>('settings-bangumi-oauth-login'),
              onPressed: _isBangumiOAuthOpening ? null : _startBangumiOAuth,
              icon: _isBangumiOAuthOpening
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser, size: _smallIconSize),
              label: Text(_isBangumiOAuthOpening ? '打开中' : '打开授权页'),
            ),
          ),
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: 'Access token',
          subtitle: '用于读取 Bangumi 个人资料、追番状态和后续同步。',
          controller: _bangumiTokenController,
          fieldKey: const ValueKey<String>('settings-bangumi-access-token'),
          obscureText: true,
          theme: theme,
          onChanged: (_) {
            if (_bangumiAuthMessage == null) return;
            setState(() {
              _bangumiAuthMessage = null;
            });
          },
          onSubmitted: (_) => _submitBangumiToken(),
          trailing: Tooltip(
            message: '保存 token 并刷新 Bangumi 登录状态',
            child: ElevatedButton.icon(
              key: const ValueKey<String>('settings-bangumi-login'),
              onPressed: _isBangumiTokenSaving ? null : _submitBangumiToken,
              icon: _isBangumiTokenSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: _smallIconSize),
              label: const Text('保存并登录'),
            ),
          ),
          statusText: _bangumiAuthMessage,
        ),
        const _SettingsDivider(),
        _SettingsRow(
          title: '使用 Bangumi 镜像',
          subtitle: '开启后 Bangumi API 与图片请求会走自建镜像地址。',
          theme: theme,
          trailing: Switch(
            key: const ValueKey<String>('settings-bangumi-mirror'),
            value: _bangumiMirrorEnabled,
            onChanged: _setBangumiMirrorEnabled,
          ),
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: 'API 镜像地址',
          subtitle: '例如 https://example.workers.dev/api。',
          controller: _bangumiMirrorApiController,
          fieldKey: const ValueKey<String>('settings-bangumi-mirror-api-url'),
          theme: theme,
          onChanged: (_) {
            if (_bangumiMirrorMessage == null) return;
            setState(() {
              _bangumiMirrorMessage = null;
            });
          },
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: '图片镜像地址',
          subtitle: '例如 https://example.workers.dev/image。',
          controller: _bangumiMirrorImageController,
          fieldKey: const ValueKey<String>('settings-bangumi-mirror-image-url'),
          theme: theme,
          onChanged: (_) {
            if (_bangumiMirrorMessage == null) return;
            setState(() {
              _bangumiMirrorMessage = null;
            });
          },
          trailing: Tooltip(
            message: '保存 Bangumi 镜像地址',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('settings-bangumi-mirror-save'),
              onPressed: _saveBangumiMirrorSettings,
              icon: const Icon(Icons.save_outlined, size: _smallIconSize),
              label: const Text('保存镜像地址'),
            ),
          ),
          statusText: _bangumiMirrorMessage,
        ),
      ],
    );
  }

  Widget _buildNetworkSection(ElainaThemeData theme) {
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsTextRow(
          title: 'HTTP 代理',
          subtitle: '供 ProviderGateway 管理的网络请求使用，例如 http://127.0.0.1:7890。',
          controller: _proxyController,
          fieldKey: const ValueKey<String>('settings-http-proxy'),
          theme: theme,
          onChanged: (_) {
            if (_networkMessage == null) return;
            setState(() {
              _networkMessage = null;
            });
          },
          trailing: Tooltip(
            message: '保存 HTTP 代理',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('settings-save-proxy'),
              onPressed: _saveProxy,
              icon: const Icon(Icons.save_outlined, size: _smallIconSize),
              label: const Text('保存代理'),
            ),
          ),
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: 'DNS 策略',
          subtitle: '支持 direct、block 或 DoH 地址，例如 https://dns.google/dns-query。',
          controller: _dnsController,
          fieldKey: const ValueKey<String>('settings-dns-policy'),
          theme: theme,
          onChanged: (_) {
            if (_networkMessage == null) return;
            setState(() {
              _networkMessage = null;
            });
          },
          trailing: Tooltip(
            message: '保存 DNS 策略',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('settings-save-dns'),
              onPressed: _saveDns,
              icon: const Icon(Icons.save_outlined, size: _smallIconSize),
              label: const Text('保存 DNS'),
            ),
          ),
          statusText: _networkMessage,
        ),
      ],
    );
  }

  Widget _buildMediaLibrarySection(ElainaThemeData theme) {
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsRow(
          title: '媒体库文件夹',
          subtitle: '这些路径会被本地媒体库扫描；移除路径只影响配置，不删除本地文件。',
          theme: theme,
          trailing: Tooltip(
            message: '添加媒体库文件夹',
            child: FilledButton.icon(
              key: const ValueKey<String>('settings-add-media-folder'),
              onPressed: _pickAndAddFolder,
              icon: const Icon(Icons.create_new_folder_outlined,
                  size: _smallIconSize),
              label: const Text('添加文件夹'),
            ),
          ),
        ),
        const SizedBox(height: _rowGap),
        if (_mediaLibraryFolders.isEmpty)
          _InlineMessage(
            icon: Icons.folder_off_outlined,
            message: '还没有配置媒体库文件夹。',
            theme: theme,
          )
        else
          for (final Uri folder in _mediaLibraryFolders)
            _MediaFolderRow(
              folder: folder,
              theme: theme,
              onEdit: () => _pickAndReplaceFolder(folder),
              onRemove: () => _removeFolder(folder),
            ),
        if (_mediaLibraryMessage != null &&
            _mediaLibraryMessage!.isNotEmpty) ...<Widget>[
          const SizedBox(height: _rowGap),
          _StatusText(text: _mediaLibraryMessage!, theme: theme),
        ],
      ],
    );
  }
}

enum _SettingsSection {
  appearance('外观', '主题模式和界面显示偏好。', Icons.palette_outlined),
  bangumi('Bangumi', '账号授权、access token 与镜像地址。', Icons.cloud_sync_outlined),
  network('网络', '代理和 DNS 策略。', Icons.public_outlined),
  mediaLibrary('本地媒体库', '媒体库扫描文件夹路径。', Icons.video_library_outlined);

  const _SettingsSection(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

final class _DecodedFolders {
  const _DecodedFolders({
    required this.folders,
    this.message,
  });

  final List<Uri> folders;
  final String? message;
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.section,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final ElainaThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? theme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_panelRadius),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(_panelRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  section.icon,
                  color: selected ? theme.primary : theme.onBackground,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? theme.primary : theme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: theme.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.64),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.theme,
    required this.children,
  });

  final ElainaThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final ElainaThemeData theme;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget label = _SettingLabel(
          title: title,
          subtitle: subtitle,
          theme: theme,
        );
        if (constraints.maxWidth < _desktopBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              label,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: label),
            const SizedBox(width: 24),
            Flexible(
                child: Align(alignment: Alignment.topRight, child: trailing)),
          ],
        );
      },
    );
  }
}

class _SettingsTextRow extends StatelessWidget {
  const _SettingsTextRow({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.theme,
    this.fieldKey,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.statusText,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final ElainaThemeData theme;
  final Key? fieldKey;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final Widget field = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _fieldMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: fieldKey,
            controller: controller,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: TextStyle(color: theme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: theme.surface.withValues(alpha: 0.78),
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
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
          if (statusText != null && statusText!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _StatusText(text: statusText!, theme: theme),
          ],
        ],
      ),
    );

    return _SettingsRow(
      title: title,
      subtitle: subtitle,
      theme: theme,
      trailing: field,
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({
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
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: theme.onBackground.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MediaFolderRow extends StatelessWidget {
  const _MediaFolderRow({
    required this.folder,
    required this.theme,
    required this.onEdit,
    required this.onRemove,
  });

  final Uri folder;
  final ElainaThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.folder_outlined, color: theme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _displayPath(folder),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Tooltip(
            message: '替换文件夹',
            child: IconButton(
              key: ValueKey<String>(
                  'settings-edit-media-folder-${folder.toString()}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              mouseCursor: SystemMouseCursors.click,
            ),
          ),
          Tooltip(
            message: '移除文件夹',
            child: IconButton(
              key: ValueKey<String>(
                  'settings-remove-media-folder-${folder.toString()}'),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              mouseCursor: SystemMouseCursors.click,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.theme,
  });

  final IconData icon;
  final String message;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: theme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: theme.onBackground.withValues(alpha: 0.66),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.text,
    required this.theme,
  });

  final String text;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.onBackground.withValues(alpha: 0.72),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowGap),
      child: Divider(height: 1, color: theme.border),
    );
  }
}

String _displayPath(Uri uri) {
  if (!uri.isScheme('file')) return uri.toString();
  return uri.toFilePath();
}
