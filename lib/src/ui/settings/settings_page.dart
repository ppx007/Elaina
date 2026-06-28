import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/media/media_library_folder_preferences.dart';
import '../../domain/playback/playback_backend_selection.dart';
import '../../domain/playback/subtitle_style.dart';
import '../../domain/profile/bangumi_login_domain.dart';
import '../../domain/settings/settings_domain.dart';
import '../testing/ui_element_ids.dart';
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
const String _appDisplayName = 'Elaina';
const String _appCodeName = '1017';
const String _appVersion = '0.11';
const String _appRepositoryUrl = 'https://github.com/ppx007/Elaina';
const String _appPositioning = '端侧优先的跨平台 ACG 播放、媒体库、Bangumi 元数据、RSS 与 BT 管理工具。';
const String _appLicenseStatus = 'GPL-3.0-only';
const String _appLicenseSource = '仓库根目录 LICENSE 文件。';
const String _unverifiedOpenSourceLicense = '未声明开源许可证';
const String _officialTermsRequired = '需查看官方条款';

const List<_ReferencedProject> _referencedProjects = <_ReferencedProject>[
  _ReferencedProject(
    name: 'Bangumi API',
    relationship: 'Provider 数据源',
    description: '番剧元数据、收藏状态、授权与条目详情边界。',
    url: 'https://github.com/bangumi/api',
    licenseName: _unverifiedOpenSourceLicense,
    licenseSource: '当前仓库没有可验证 LICENSE 副本；以官方仓库为准。',
    licenseUrl: 'https://github.com/bangumi/api',
  ),
  _ReferencedProject(
    name: 'media_kit',
    relationship: '本地播放与视频渲染依赖',
    description: 'Flutter 侧媒体播放、视频渲染与 Windows native media-kit libraries。',
    url: 'https://github.com/media-kit/media-kit',
    licenseName: 'MIT License',
    licenseSource: '已由本地 pub package LICENSE 文件确认。',
    licenseUrl: 'https://pub.dev/packages/media_kit/license',
  ),
  _ReferencedProject(
    name: 'libtorrent_flutter',
    relationship: 'BT 下载运行时依赖',
    description: 'BT 任务、元数据获取和边下边播相关运行能力。',
    url: 'https://pub.dev/packages/libtorrent_flutter',
    licenseName: 'GPL-3.0',
    licenseSource: '已由本地 pub package LICENSE 文件确认。',
    licenseUrl: 'https://pub.dev/packages/libtorrent_flutter/license',
  ),
  _ReferencedProject(
    name: 'Dandanplay',
    relationship: '弹幕与匹配服务接口',
    description: '弹幕与弹弹play 数据接入边界。',
    url: 'https://www.dandanplay.com/',
    licenseName: _officialTermsRequired,
    licenseSource: '外部服务不是随应用分发的开源代码；使用条款以官方页面为准。',
    licenseUrl: 'https://www.dandanplay.com/',
  ),
  _ReferencedProject(
    name: 'Anime4K',
    relationship: '视频增强 shader 资源',
    description: '随应用分发的 Anime4K GLSL shader，用于 MPV glsl-shaders 预设。',
    url: 'https://github.com/bloc97/Anime4K',
    licenseName: 'MIT License',
    licenseSource: '随包保留 assets/anime4k/LICENSE。',
    licenseUrl: 'assets/anime4k/LICENSE',
  ),
];

/// Global settings center for values consumed by app runtimes.
///
/// Business objects such as RSS rules, download tasks, and media indexes stay
/// on their own pages. SettingsPage should only expose durable global
/// preferences that a runtime actually reads.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsRuntime,
    this.bangumiLoginController,
    this.onBangumiAuthChanged,
    this.onAnime4kSettingsChanged,
    this.playbackBackendSelectionRuntime,
    this.directoryPathPicker = _defaultDirectoryPathPicker,
  });

  final SettingsRuntime settingsRuntime;
  final BangumiLoginController? bangumiLoginController;
  final VoidCallback? onBangumiAuthChanged;
  final Future<void> Function()? onAnime4kSettingsChanged;
  final PlaybackBackendSelectionRuntime? playbackBackendSelectionRuntime;
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
  final TextEditingController _anime4kShaderOverrideController =
      TextEditingController();
  final TextEditingController _vlcRuntimeDirectoryController =
      TextEditingController();
  final TextEditingController _subtitleAutoSelectRegexController =
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
  String _anime4kDefaultPreset = Anime4kPresetSettings.off;
  String? _anime4kMessage;
  bool _isAnime4kSaving = false;
  PlaybackBackendMode _playbackBackendMode = PlaybackBackendMode.mediaKitMpv;
  PlaybackBackendSelectionSnapshot? _playbackBackendSnapshot;
  String? _playbackBackendMessage;
  bool _isPlaybackBackendSaving = false;
  SubtitleStyleProfile _subtitleStyleProfile = SubtitleStyleProfile.defaults;
  String? _subtitleStyleMessage;
  bool _subtitleAutoSelectEnabled = true;
  String? _subtitleAutoSelectMessage;
  bool _isSubtitleAutoSelectSaving = false;

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
    _anime4kShaderOverrideController.dispose();
    _vlcRuntimeDirectoryController.dispose();
    _subtitleAutoSelectRegexController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Load once into controllers, then persist through explicit save/apply
    // actions. Text fields should not write storage on every keystroke.
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
      final String? anime4kOverrideStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.anime4kShaderOverrideDirectory);
      final String? anime4kDefaultPresetStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.anime4kDefaultPreset);
      final String? playbackBackendModeStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.playbackBackendMode);
      final String? vlcRuntimeDirectoryStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.vlcRuntimeDirectory);
      final String? subtitleStyleStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.subtitleStyleProfile);
      final String? subtitleAutoSelectEnabledStr =
          await widget.settingsRuntime.getPreference(
        SettingsPreferenceKeys.subtitleAutoSelectEnabled,
      );
      final String? subtitleAutoSelectPatternStr =
          await widget.settingsRuntime.getPreference(
        SettingsPreferenceKeys.subtitleAutoSelectPattern,
      );
      final String? proxyUrl = await widget.settingsRuntime.getProxyUrl();
      final String? dnsPolicy = await widget.settingsRuntime.getDnsPolicy();
      final PlaybackBackendSelectionSnapshot? backendSnapshot =
          await widget.playbackBackendSelectionRuntime?.snapshot();

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
        _anime4kShaderOverrideController.text = anime4kOverrideStr ?? '';
        _anime4kDefaultPreset =
            Anime4kPresetSettings.parse(anime4kDefaultPresetStr);
        _playbackBackendMode =
            PlaybackBackendModeSettings.parse(playbackBackendModeStr);
        _vlcRuntimeDirectoryController.text = vlcRuntimeDirectoryStr ?? '';
        _playbackBackendSnapshot = backendSnapshot;
        _subtitleStyleProfile = SubtitleStyleSettings.parse(subtitleStyleStr);
        _subtitleAutoSelectEnabled = SubtitleAutoSelectSettings.parseEnabled(
          subtitleAutoSelectEnabledStr,
        );
        _subtitleAutoSelectRegexController.text =
            subtitleAutoSelectPatternStr?.trim() ?? '';
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

  Future<void> _updateSubtitleStyle(SubtitleStyleProfile profile) async {
    setState(() {
      _subtitleStyleProfile = profile;
      _subtitleStyleMessage = null;
    });
    try {
      await _savePreference(
        SettingsPreferenceKeys.subtitleStyleProfile,
        SubtitleStyleSettings.serialize(profile),
      );
      if (!mounted) return;
      setState(() {
        _subtitleStyleMessage = '字幕样式默认值已保存';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _subtitleStyleMessage = '字幕样式保存失败：$error';
      });
    }
  }

  Future<void> _saveSubtitleAutoSelectSettings() async {
    if (_isSubtitleAutoSelectSaving) return;
    final String rawPattern = _subtitleAutoSelectRegexController.text.trim();
    try {
      if (rawPattern.isNotEmpty) {
        SubtitleAutoSelectSettings.validateRegex(rawPattern);
      }
    } on FormatException catch (error) {
      setState(() {
        _subtitleAutoSelectMessage = '字幕自动选择正则无效：${error.message}';
      });
      return;
    }

    setState(() {
      _isSubtitleAutoSelectSaving = true;
      _subtitleAutoSelectMessage = null;
    });
    try {
      await _savePreference(
        SettingsPreferenceKeys.subtitleAutoSelectEnabled,
        SubtitleAutoSelectSettings.serializeEnabled(_subtitleAutoSelectEnabled),
      );
      await _savePreference(
        SettingsPreferenceKeys.subtitleAutoSelectPattern,
        SubtitleAutoSelectSettings.serializePattern(rawPattern),
      );
      if (!mounted) return;
      setState(() {
        _subtitleAutoSelectMessage = '字幕自动选择设置已保存';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _subtitleAutoSelectMessage = '字幕自动选择设置保存失败：$error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubtitleAutoSelectSaving = false;
      });
    }
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
      // Invalid mirror settings disable the mirror instead of saving a broken
      // enabled state that would fail every Bangumi request at runtime.
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

  Future<void> _saveAnime4kSettings() async {
    if (_isAnime4kSaving) return;
    setState(() {
      _isAnime4kSaving = true;
      _anime4kMessage = null;
    });
    try {
      await _savePreference(
        SettingsPreferenceKeys.anime4kShaderOverrideDirectory,
        _anime4kShaderOverrideController.text.trim(),
      );
      await _savePreference(
        SettingsPreferenceKeys.anime4kDefaultPreset,
        _anime4kDefaultPreset,
      );
      await widget.onAnime4kSettingsChanged?.call();
      if (!mounted) return;
      setState(() {
        _isAnime4kSaving = false;
        _anime4kMessage = 'Anime4K 设置已保存';
      });
      _showSnack('Anime4K 设置已保存');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnime4kSaving = false;
        _anime4kMessage = 'Anime4K 设置保存失败：$error';
      });
    }
  }

  void _setAnime4kDefaultPreset(String? value) {
    if (value == null) return;
    setState(() {
      _anime4kDefaultPreset = Anime4kPresetSettings.parse(value);
      _anime4kMessage = null;
    });
  }

  void _setPlaybackBackendMode(PlaybackBackendMode? value) {
    if (value == null) return;
    setState(() {
      _playbackBackendMode = value;
      _playbackBackendMessage = null;
    });
  }

  Future<void> _savePlaybackBackendSettings() async {
    if (_isPlaybackBackendSaving) return;
    setState(() {
      _isPlaybackBackendSaving = true;
      _playbackBackendMessage = null;
    });

    final PlaybackBackendSelectionRuntime? backendRuntime =
        widget.playbackBackendSelectionRuntime;
    try {
      if (backendRuntime == null) {
        await _savePreference(
          SettingsPreferenceKeys.playbackBackendMode,
          PlaybackBackendModeSettings.serialize(_playbackBackendMode),
        );
        await _savePreference(
          SettingsPreferenceKeys.vlcRuntimeDirectory,
          _vlcRuntimeDirectoryController.text.trim(),
        );
      } else {
        await backendRuntime.configureVlcRuntimeDirectory(
          _vlcRuntimeDirectoryController.text,
        );
        final PlaybackBackendSwitchResult result =
            await backendRuntime.selectMode(_playbackBackendMode);
        if (!result.isSuccess) {
          throw StateError(result.message ?? '播放后端切换失败');
        }
        _playbackBackendSnapshot = await backendRuntime.snapshot();
      }
      if (!mounted) return;
      setState(() {
        _isPlaybackBackendSaving = false;
        _playbackBackendMessage = '播放后端设置已保存';
      });
      _showSnack('播放后端设置已保存');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPlaybackBackendSaving = false;
        _playbackBackendMessage = '播放后端设置保存失败: $error';
      });
    }
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
              key: ValueKey<String>(_settingsSectionElementId(section)),
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
          _SettingsSection.playback => _buildPlaybackBackendSection(theme),
          _SettingsSection.videoEnhancement =>
            _buildVideoEnhancementSection(theme),
          _SettingsSection.mediaLibrary => _buildMediaLibrarySection(theme),
          _SettingsSection.about => _buildAboutSection(theme),
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
            key: const ValueKey<String>(UiElementIds.settingsThemeMode),
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
              key: const ValueKey<String>(
                  UiElementIds.settingsBangumiOAuthLogin),
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
          fieldKey:
              const ValueKey<String>(UiElementIds.settingsBangumiAccessToken),
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
              key: const ValueKey<String>(UiElementIds.settingsBangumiLogin),
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
            key: const ValueKey<String>(UiElementIds.settingsBangumiMirror),
            value: _bangumiMirrorEnabled,
            onChanged: _setBangumiMirrorEnabled,
          ),
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: 'API 镜像地址',
          subtitle: '例如 https://example.workers.dev/api。',
          controller: _bangumiMirrorApiController,
          fieldKey:
              const ValueKey<String>(UiElementIds.settingsBangumiMirrorApiUrl),
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
          fieldKey: const ValueKey<String>(
              UiElementIds.settingsBangumiMirrorImageUrl),
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
              key: const ValueKey<String>(
                  UiElementIds.settingsBangumiMirrorSave),
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
          fieldKey: const ValueKey<String>(UiElementIds.settingsHttpProxy),
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
              key: const ValueKey<String>(UiElementIds.settingsSaveProxy),
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
          fieldKey: const ValueKey<String>(UiElementIds.settingsDnsPolicy),
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
              key: const ValueKey<String>(UiElementIds.settingsSaveDns),
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

  Widget _buildPlaybackBackendSection(ElainaThemeData theme) {
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsRow(
          title: '播放后端',
          subtitle: 'MPV 是默认后端；自动备用只在 MPV 本地文件加载失败时尝试 VLC。',
          theme: theme,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _fieldMaxWidth),
            child: DropdownButtonFormField<PlaybackBackendMode>(
              key: const ValueKey<String>(
                UiElementIds.settingsPlaybackBackendMode,
              ),
              initialValue: _playbackBackendMode,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
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
              items: <DropdownMenuItem<PlaybackBackendMode>>[
                for (final PlaybackBackendMode mode
                    in PlaybackBackendMode.values)
                  DropdownMenuItem<PlaybackBackendMode>(
                    value: mode,
                    child: Text(PlaybackBackendModeSettings.label(mode)),
                  ),
              ],
              onChanged: _setPlaybackBackendMode,
            ),
          ),
        ),
        const _SettingsDivider(),
        _SettingsTextRow(
          title: 'VLC 运行时目录',
          subtitle: '留空时自动探测常见 VLC 安装目录；也可填写包含 libvlc.dll 和 plugins 的目录。',
          controller: _vlcRuntimeDirectoryController,
          fieldKey: const ValueKey<String>(
            UiElementIds.settingsVlcRuntimeDirectory,
          ),
          theme: theme,
          onChanged: (_) {
            if (_playbackBackendMessage == null) return;
            setState(() {
              _playbackBackendMessage = null;
            });
          },
          trailing: Tooltip(
            message: '保存播放后端设置',
            child: OutlinedButton.icon(
              key: const ValueKey<String>(
                UiElementIds.settingsPlaybackBackendSave,
              ),
              onPressed: _isPlaybackBackendSaving
                  ? null
                  : _savePlaybackBackendSettings,
              icon: const Icon(Icons.save_outlined, size: _smallIconSize),
              label: Text(_isPlaybackBackendSaving ? '保存中' : '保存播放后端'),
            ),
          ),
          statusText: _playbackBackendMessage,
        ),
        const _SettingsDivider(),
        _PlaybackBackendSummary(
          key: const ValueKey<String>(
            UiElementIds.settingsPlaybackBackendCapabilitySummary,
          ),
          snapshot: _playbackBackendSnapshot,
          theme: theme,
        ),
        const _SettingsDivider(),
        _SubtitleAutoSelectSettingsPanel(
          enabled: _subtitleAutoSelectEnabled,
          regexController: _subtitleAutoSelectRegexController,
          message: _subtitleAutoSelectMessage,
          isSaving: _isSubtitleAutoSelectSaving,
          theme: theme,
          onEnabledChanged: (bool value) {
            setState(() {
              _subtitleAutoSelectEnabled = value;
              _subtitleAutoSelectMessage = null;
            });
          },
          onSave: _saveSubtitleAutoSelectSettings,
        ),
        const _SettingsDivider(),
        _SubtitleStyleSettingsPanel(
          profile: _subtitleStyleProfile,
          message: _subtitleStyleMessage,
          theme: theme,
          onChanged: (SubtitleStyleProfile profile) {
            unawaited(_updateSubtitleStyle(profile));
          },
        ),
      ],
    );
  }

  Widget _buildVideoEnhancementSection(ElainaThemeData theme) {
    return _SettingsGroup(
      theme: theme,
      children: <Widget>[
        _SettingsTextRow(
          title: 'Anime4K shader 目录',
          subtitle: '可选。本地目录包含完整 shader 文件时优先使用；缺文件会回退内置 Anime4K。',
          controller: _anime4kShaderOverrideController,
          fieldKey: const ValueKey<String>(
            UiElementIds.settingsAnime4kShaderOverrideDirectory,
          ),
          theme: theme,
          onChanged: (_) {
            if (_anime4kMessage == null) return;
            setState(() {
              _anime4kMessage = null;
            });
          },
          trailing: Tooltip(
            message: '保存 Anime4K shader 目录和默认预设',
            child: OutlinedButton.icon(
              key: const ValueKey<String>(UiElementIds.settingsAnime4kSave),
              onPressed: _isAnime4kSaving ? null : _saveAnime4kSettings,
              icon: _isAnime4kSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: _smallIconSize),
              label: Text(_isAnime4kSaving ? '保存中' : '保存 Anime4K'),
            ),
          ),
          statusText: _anime4kMessage,
        ),
        const _SettingsDivider(),
        _SettingsRow(
          title: 'Anime4K 默认预设',
          subtitle: '默认保持关闭；播放页仍可临时选择预设。',
          theme: theme,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _fieldMaxWidth),
            child: DropdownButtonFormField<String>(
              key: const ValueKey<String>(
                UiElementIds.settingsAnime4kDefaultPreset,
              ),
              initialValue: _anime4kDefaultPreset,
              items: <DropdownMenuItem<String>>[
                for (final String preset in Anime4kPresetSettings.values)
                  DropdownMenuItem<String>(
                    value: preset,
                    child: Text(_anime4kPresetLabel(preset)),
                  ),
              ],
              onChanged: _setAnime4kDefaultPreset,
              decoration: InputDecoration(
                isDense: true,
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
          ),
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
              key: const ValueKey<String>(UiElementIds.settingsAddMediaFolder),
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

  Widget _buildAboutSection(ElainaThemeData theme) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SettingsGroup(
            key: const ValueKey<String>(UiElementIds.settingsAboutAppInfo),
            theme: theme,
            children: <Widget>[
              _ReadonlyInfoRow(
                title: '软件名称',
                value: _appDisplayName,
                theme: theme,
              ),
              const _SettingsDivider(),
              _ReadonlyInfoRow(
                title: '代号',
                value: _appCodeName,
                theme: theme,
              ),
              const _SettingsDivider(),
              _ReadonlyInfoRow(
                title: '版本',
                value: _appVersion,
                theme: theme,
              ),
              const _SettingsDivider(),
              _ReadonlyInfoRow(
                title: '定位',
                value: _appPositioning,
                theme: theme,
              ),
              const _SettingsDivider(),
              _ReadonlyInfoRow(
                title: '项目许可证',
                value: '$_appLicenseStatus（$_appLicenseSource）',
                theme: theme,
              ),
              const _SettingsDivider(),
              _ReadonlyInfoRow(
                title: '项目仓库',
                value: _appRepositoryUrl,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: _sectionGap),
          _SettingsGroup(
            key: const ValueKey<String>(
              UiElementIds.settingsOpenSourceLicenses,
            ),
            theme: theme,
            children: <Widget>[
              _InlineMessage(
                icon: Icons.account_tree_outlined,
                message: '引用项目与协议',
                theme: theme,
              ),
              const _SettingsDivider(),
              for (int index = 0;
                  index < _referencedProjects.length;
                  index++) ...<Widget>[
                _ReferencedProjectRow(
                  project: _referencedProjects[index],
                  theme: theme,
                ),
                if (index != _referencedProjects.length - 1)
                  const _SettingsDivider(),
              ],
            ],
          ),
          const SizedBox(height: _sectionGap),
          _SettingsGroup(
            key: const ValueKey<String>(
              UiElementIds.settingsReferenceRepositories,
            ),
            theme: theme,
            children: <Widget>[
              _SettingsRow(
                title: '第三方开源许可证',
                subtitle: 'Flutter、Dart 与 pub 依赖的许可证由 LicenseRegistry 自动汇总。',
                theme: theme,
                trailing: Tooltip(
                  message: '查看 Flutter 自动汇总的全部第三方许可证',
                  child: FilledButton.icon(
                    key: const ValueKey<String>(
                      UiElementIds.settingsThirdPartyLicensesButton,
                    ),
                    onPressed: _openThirdPartyLicenses,
                    icon: const Icon(
                      Icons.article_outlined,
                      size: _smallIconSize,
                    ),
                    label: const Text('查看全部许可证'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openThirdPartyLicenses() {
    showLicensePage(
      context: context,
      applicationName: _appDisplayName,
      applicationVersion: _appVersion,
      applicationLegalese: '第三方依赖许可证由 Flutter LicenseRegistry 自动汇总。',
    );
  }
}

enum _SettingsSection {
  appearance('外观', '主题模式和界面显示偏好。', Icons.palette_outlined),
  bangumi('Bangumi', '账号授权、access token 与镜像地址。', Icons.cloud_sync_outlined),
  network('网络', '代理和 DNS 策略。', Icons.public_outlined),
  playback('播放', '主后端、自动备用和 VLC 运行时。', Icons.play_circle_outline),
  videoEnhancement(
      '视频增强', 'Anime4K shader 路径和默认预设。', Icons.auto_awesome_outlined),
  mediaLibrary('本地媒体库', '媒体库扫描文件夹路径。', Icons.video_library_outlined),
  about('关于', '软件版本、项目仓库与参考项目。', Icons.info_outline);

  const _SettingsSection(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

final class _ReferencedProject {
  const _ReferencedProject({
    required this.name,
    required this.relationship,
    required this.description,
    required this.url,
    required this.licenseName,
    required this.licenseSource,
    required this.licenseUrl,
  });

  final String name;
  final String relationship;
  final String description;
  final String url;
  final String licenseName;
  final String licenseSource;
  final String licenseUrl;
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
          key: ValueKey<String>(_settingsSectionElementId(section)),
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
    super.key,
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

class _ReadonlyInfoRow extends StatelessWidget {
  const _ReadonlyInfoRow({
    required this.title,
    required this.value,
    required this.theme,
  });

  final String title;
  final String value;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: title,
      subtitle: '',
      theme: theme,
      trailing: Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          value,
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReferencedProjectRow extends StatelessWidget {
  const _ReferencedProjectRow({
    required this.project,
    required this.theme,
  });

  final _ReferencedProject project;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: project.name,
      subtitle: '${project.relationship}\n${project.description}',
      theme: theme,
      trailing: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(
              project.url,
              style: TextStyle(
                color: theme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              '许可证：${project.licenseName}',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              project.licenseSource,
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              project.licenseUrl,
              style: TextStyle(
                color: theme.primary,
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

class _SubtitleAutoSelectSettingsPanel extends StatelessWidget {
  const _SubtitleAutoSelectSettingsPanel({
    required this.enabled,
    required this.regexController,
    required this.message,
    required this.isSaving,
    required this.theme,
    required this.onEnabledChanged,
    required this.onSave,
  });

  final bool enabled;
  final TextEditingController regexController;
  final String? message;
  final bool isSaving;
  final ElainaThemeData theme;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>(UiElementIds.settingsSubtitleAutoSelectPanel),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '字幕自动选择',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '默认优先选择简体中文字幕。自定义正则会先匹配轨道名称、语言代码和轨道 id，未命中时再回退简体中文规则。',
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _rowGap),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '打开字幕自动选择',
                  style: TextStyle(color: theme.onSurface),
                ),
                value: enabled,
                onChanged: onEnabledChanged,
              ),
            ),
            TextField(
              key: const ValueKey<String>(
                UiElementIds.settingsSubtitleAutoSelectRegex,
              ),
              controller: regexController,
              decoration: InputDecoration(
                labelText: '自定义字幕正则',
                hintText: r'例如：简体|简中|CHS|zh-Hans',
                helperText: '留空时只使用内置简体中文字幕规则',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '保存字幕自动选择设置',
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              _StatusText(text: message!, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubtitleStyleSettingsPanel extends StatelessWidget {
  const _SubtitleStyleSettingsPanel({
    required this.profile,
    required this.message,
    required this.theme,
    required this.onChanged,
  });

  static const double _fontSizeMin = 14;
  static const double _fontSizeMax = 42;
  static const double _outlineMin = 0;
  static const double _outlineMax = 8;
  static const double _opacityMin = 0.35;
  static const double _opacityMax = 1;
  static const double _lineHeightMin = 1;
  static const double _lineHeightMax = 1.8;
  static const double _bottomInsetMin = 5;
  static const double _bottomInsetMax = 120;

  static const List<int> _colorSwatches = <int>[
    0xFFFFFFFF,
    0xFFFFF176,
    0xFF80DEEA,
    0xFFFFAB91,
    0xFFE1BEE7,
  ];

  final SubtitleStyleProfile profile;
  final String? message;
  final ElainaThemeData theme;
  final ValueChanged<SubtitleStyleProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>(UiElementIds.settingsSubtitleStylePanel),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '字幕样式默认值',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '默认只应用到无内置样式字幕；开启强制覆盖后，ASS/VTT 内置样式也会按播放器样式显示。',
              style: TextStyle(
                color: theme.onBackground.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _rowGap),
            _SettingsStyleSlider(
              label: '字号',
              value: profile.fontSize,
              min: _fontSizeMin,
              max: _fontSizeMax,
              divisions: 28,
              displayValue: '${profile.fontSize.round()} px',
              onChanged: (double value) =>
                  onChanged(profile.copyWith(fontSize: value)),
            ),
            _SettingsFontWeightControl(
              value: profile.fontWeight,
              theme: theme,
              onChanged: (SubtitleStyleFontWeight value) =>
                  onChanged(profile.copyWith(fontWeight: value)),
            ),
            _SettingsStyleSlider(
              label: '透明度',
              value: profile.textOpacity,
              min: _opacityMin,
              max: _opacityMax,
              divisions: 13,
              displayValue: '${(profile.textOpacity * 100).round()}%',
              onChanged: (double value) =>
                  onChanged(profile.copyWith(textOpacity: value)),
            ),
            _SettingsStyleSlider(
              label: '描边',
              value: profile.outlineStrength,
              min: _outlineMin,
              max: _outlineMax,
              divisions: 8,
              displayValue: profile.outlineStrength.toStringAsFixed(1),
              onChanged: (double value) =>
                  onChanged(profile.copyWith(outlineStrength: value)),
            ),
            _SettingsStyleSlider(
              label: '行距',
              value: profile.lineHeight,
              min: _lineHeightMin,
              max: _lineHeightMax,
              divisions: 8,
              displayValue: profile.lineHeight.toStringAsFixed(1),
              onChanged: (double value) =>
                  onChanged(profile.copyWith(lineHeight: value)),
            ),
            _SettingsStyleSlider(
              label: '底部位置',
              value: profile.bottomInset,
              min: _bottomInsetMin,
              max: _bottomInsetMax,
              divisions: 23,
              displayValue: '${profile.bottomInset.round()} px',
              onChanged: (double value) =>
                  onChanged(profile.copyWith(bottomInset: value)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int swatch in _colorSwatches)
                  _SettingsColorSwatch(
                    colorArgb: swatch,
                    selected: profile.textColorArgb == swatch,
                    theme: theme,
                    onTap: () =>
                        onChanged(profile.copyWith(textColorArgb: swatch)),
                  ),
              ],
            ),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('背景', style: TextStyle(color: theme.onSurface)),
                value: profile.backgroundEnabled,
                onChanged: (bool value) =>
                    onChanged(profile.copyWith(backgroundEnabled: value)),
              ),
            ),
            if (profile.backgroundEnabled)
              _SettingsStyleSlider(
                label: '背景透明',
                value: profile.backgroundOpacity,
                min: 0.1,
                max: 0.8,
                divisions: 7,
                displayValue: '${(profile.backgroundOpacity * 100).round()}%',
                onChanged: (double value) =>
                    onChanged(profile.copyWith(backgroundOpacity: value)),
              ),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '强制覆盖字幕内置样式',
                  style: TextStyle(color: theme.onSurface),
                ),
                value: profile.forceOverrideEmbeddedStyle,
                onChanged: (bool value) => onChanged(
                  profile.copyWith(forceOverrideEmbeddedStyle: value),
                ),
              ),
            ),
            if (message != null) _StatusText(text: message!, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _SettingsFontWeightControl extends StatelessWidget {
  const _SettingsFontWeightControl({
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  final SubtitleStyleFontWeight value;
  final ElainaThemeData theme;
  final ValueChanged<SubtitleStyleFontWeight> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 72,
          child: Text(
            '粗细',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: DropdownButton<SubtitleStyleFontWeight>(
            value: value,
            isExpanded: true,
            dropdownColor: theme.surface,
            underline: const SizedBox.shrink(),
            style: TextStyle(color: theme.onSurface, fontSize: 12),
            items: <DropdownMenuItem<SubtitleStyleFontWeight>>[
              for (final SubtitleStyleFontWeight weight
                  in SubtitleStyleFontWeight.values)
                DropdownMenuItem<SubtitleStyleFontWeight>(
                  value: weight,
                  child: Text(_settingsSubtitleFontWeightLabel(weight)),
                ),
            ],
            onChanged: (SubtitleStyleFontWeight? next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsStyleSlider extends StatelessWidget {
  const _SettingsStyleSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(displayValue, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

String _settingsSubtitleFontWeightLabel(SubtitleStyleFontWeight weight) {
  return switch (weight) {
    SubtitleStyleFontWeight.normal => '常规',
    SubtitleStyleFontWeight.medium => '中等',
    SubtitleStyleFontWeight.bold => '加粗',
  };
}

class _SettingsColorSwatch extends StatelessWidget {
  const _SettingsColorSwatch({
    required this.colorArgb,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final int colorArgb;
  final bool selected;
  final ElainaThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_panelRadius),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(colorArgb),
          borderRadius: BorderRadius.circular(_panelRadius),
          border: Border.all(
            color: selected ? theme.primary : theme.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _PlaybackBackendSummary extends StatelessWidget {
  const _PlaybackBackendSummary({
    super.key,
    required this.snapshot,
    required this.theme,
  });

  final PlaybackBackendSelectionSnapshot? snapshot;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final PlaybackBackendSelectionSnapshot? snapshot = this.snapshot;
    if (snapshot == null) {
      return _InlineMessage(
        icon: Icons.info_outline,
        message: '播放后端运行时未注入；当前页面只能保存偏好，无法实时探测后端能力。',
        theme: theme,
      );
    }

    final PlaybackBackendCandidateSnapshot? vlc =
        snapshot.candidateById(playbackBackendVlcFallbackId);
    final List<String> limitations = <String>[
      if (vlc != null && !vlc.available) 'VLC 不可用: ${vlc.reason ?? '未通过运行时探测'}',
      if (vlc != null && vlc.available) ...vlc.keyLimitationReasonLines(),
      if (snapshot.activeBackendId == playbackBackendVlcFallbackId &&
          limitationsWouldBeEmpty(vlc))
        'VLC 当前未隐藏 MPV 能力；请刷新探测确认能力矩阵。',
    ];

    final List<_InfoLine> lines = <_InfoLine>[
      _InfoLine(
        '配置模式',
        PlaybackBackendModeSettings.label(snapshot.configuredMode),
      ),
      _InfoLine('当前后端', snapshot.activeBackendLabel),
      if (snapshot.latestFallbackReason != null)
        _InfoLine('最近备用切换', snapshot.latestFallbackReason!),
      if (vlc?.details['libvlcPath'] != null)
        _InfoLine('VLC 路径', vlc!.details['libvlcPath']!),
      if (vlc?.details['vlcReason'] != null)
        _InfoLine('VLC 探测', vlc!.details['vlcReason']!),
      _InfoLine(
        '限制说明',
        limitations.isEmpty ? '当前后端未报告隐藏能力。' : limitations.join('\n'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InlineMessage(
          icon: Icons.fact_check_outlined,
          message: '后端能力由运行时 probe 提供；VLC 不会伪装支持 MPV-only 增强能力。',
          theme: theme,
        ),
        const SizedBox(height: 12),
        for (final _InfoLine line in lines) ...<Widget>[
          _ReadonlyInfoRow(
            title: line.label,
            value: line.value,
            theme: theme,
          ),
          if (line != lines.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  bool limitationsWouldBeEmpty(PlaybackBackendCandidateSnapshot? candidate) {
    if (candidate == null) return true;
    if (!candidate.available) return false;
    return candidate.keyLimitationReasonLines().isEmpty;
  }
}

final class _InfoLine {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;
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
                UiElementIds.settingsEditMediaFolder(folder),
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              mouseCursor: SystemMouseCursors.click,
            ),
          ),
          Tooltip(
            message: '移除文件夹',
            child: IconButton(
              key: ValueKey<String>(
                UiElementIds.settingsRemoveMediaFolder(folder),
              ),
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

String _anime4kPresetLabel(String preset) {
  return switch (Anime4kPresetSettings.parse(preset)) {
    Anime4kPresetSettings.off => '关闭',
    Anime4kPresetSettings.restore => 'Restore',
    Anime4kPresetSettings.upscale => 'Upscale',
    Anime4kPresetSettings.restoreAndUpscale => 'Restore + Upscale',
    _ => preset,
  };
}

String _settingsSectionElementId(_SettingsSection section) {
  return switch (section) {
    _SettingsSection.appearance => UiElementIds.settingsSectionAppearance,
    _SettingsSection.bangumi => UiElementIds.settingsSectionBangumi,
    _SettingsSection.network => UiElementIds.settingsSectionNetwork,
    _SettingsSection.playback => UiElementIds.settingsSectionPlayback,
    _SettingsSection.videoEnhancement =>
      UiElementIds.settingsSectionVideoEnhancement,
    _SettingsSection.mediaLibrary => UiElementIds.settingsSectionMediaLibrary,
    _SettingsSection.about => UiElementIds.settingsSectionAbout,
  };
}
