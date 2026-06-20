import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/settings/settings_domain.dart';
import '../theme/elaina_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsRuntime,
    this.onBangumiAuthChanged,
  });

  final SettingsRuntime settingsRuntime;
  final VoidCallback? onBangumiAuthChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _proxyController = TextEditingController();
  final TextEditingController _dnsController = TextEditingController();
  final TextEditingController _cacheController = TextEditingController();
  final TextEditingController _bangumiTokenController = TextEditingController();
  Timer? _bangumiAuthRefreshDebounce;

  bool _hardwareAcceleration = true;
  String _layoutPreference = 'default';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _dnsController.dispose();
    _cacheController.dispose();
    _bangumiTokenController.dispose();
    _bangumiAuthRefreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final String? hwAccStr =
          await widget.settingsRuntime.getPreference('hardware_acceleration');
      final String? layoutStr =
          await widget.settingsRuntime.getPreference('layout_preference');
      final String? cacheStr =
          await widget.settingsRuntime.getPreference('cache_size_limit_mb');
      final String? bangumiTokenStr = await widget.settingsRuntime
          .getPreference(SettingsPreferenceKeys.bangumiAccessToken);

      final String? proxyUrl = await widget.settingsRuntime.getProxyUrl();
      final String? dnsPolicy = await widget.settingsRuntime.getDnsPolicy();

      if (mounted) {
        setState(() {
          _hardwareAcceleration = hwAccStr != 'false';
          _layoutPreference = layoutStr ?? 'default';
          _cacheController.text = cacheStr ?? '1024';
          _bangumiTokenController.text = bangumiTokenStr ?? '';
          _proxyController.text = proxyUrl ?? '';
          _dnsController.text = dnsPolicy ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载设置失败: $e')),
        );
      }
    }
  }

  Future<void> _savePreference(String key, String value) async {
    await widget.settingsRuntime.setPreference(key: key, value: value);
  }

  Future<void> _saveBangumiToken(String value) async {
    await _savePreference(
      SettingsPreferenceKeys.bangumiAccessToken,
      value.trim(),
    );
    _bangumiAuthRefreshDebounce?.cancel();
    _bangumiAuthRefreshDebounce = Timer(
      const Duration(milliseconds: 600),
      () => widget.onBangumiAuthChanged?.call(),
    );
  }

  Future<void> _saveProxy() async {
    final String proxyUrl = _proxyController.text.trim();
    await widget.settingsRuntime.saveProxyUrl(proxyUrl);
  }

  Future<void> _saveDns() async {
    final String dnsPolicy = _dnsController.text.trim();
    await widget.settingsRuntime.saveDnsPolicy(dnsPolicy);
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '设置中心',
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: <Widget>[
                _buildCardSection(
                  title: '常规首选项',
                  theme: theme,
                  children: <Widget>[
                    _buildSwitchRow(
                      title: '硬件加速',
                      subtitle: '启用 GPU 硬件加速以获得更流畅的播放效果',
                      value: _hardwareAcceleration,
                      onChanged: (bool val) {
                        setState(() {
                          _hardwareAcceleration = val;
                        });
                        _savePreference(
                            'hardware_acceleration', val.toString());
                      },
                      theme: theme,
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    _buildDropdownRow(
                      title: '布局偏好',
                      subtitle: '调整播放界面的主要视图布局模式',
                      value: _layoutPreference,
                      options: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                            value: 'default', child: Text('默认')),
                        DropdownMenuItem<String>(
                            value: 'compact', child: Text('紧凑')),
                        DropdownMenuItem<String>(
                            value: 'grid', child: Text('网格')),
                      ],
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() {
                            _layoutPreference = val;
                          });
                          _savePreference('layout_preference', val);
                        }
                      },
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildCardSection(
                  title: 'Bangumi',
                  theme: theme,
                  children: <Widget>[
                    _buildTextRow(
                      title: 'Access token',
                      subtitle:
                          'Used to load the current Bangumi profile and sync progress.',
                      controller: _bangumiTokenController,
                      fieldKey: const ValueKey<String>(
                          'settings-bangumi-access-token'),
                      obscureText: true,
                      onChanged: (String val) {
                        _saveBangumiToken(val);
                      },
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildCardSection(
                  title: '缓存管理',
                  theme: theme,
                  children: <Widget>[
                    _buildTextRow(
                      title: '最大缓存限制 (MB)',
                      subtitle: '限制本地番剧分片与元数据缓存的占用空间',
                      controller: _cacheController,
                      fieldKey:
                          const ValueKey<String>('settings-cache-size-limit'),
                      keyboardType: TextInputType.number,
                      onChanged: (String val) {
                        _savePreference('cache_size_limit_mb', val.trim());
                      },
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildCardSection(
                  title: '网络与安全策略',
                  theme: theme,
                  children: <Widget>[
                    _buildTextRow(
                      title: '自定义 HTTP 代理',
                      subtitle:
                          '配置拉取番剧源和订阅时的 HTTP 代理 (例如: http://127.0.0.1:7890)',
                      controller: _proxyController,
                      fieldKey: const ValueKey<String>('settings-http-proxy'),
                      onChanged: (String _) => _saveProxy(),
                      theme: theme,
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    _buildTextRow(
                      title: 'DNS 及解析策略',
                      subtitle:
                          '设置安全 DNS 或解析通道 (例如: https://dns.google/dns-query 或 direct)',
                      controller: _dnsController,
                      fieldKey: const ValueKey<String>('settings-dns-policy'),
                      onChanged: (String _) => _saveDns(),
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
    required ElainaThemeData theme,
  }) {
    return Container(
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
            title,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 32, color: Colors.white12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ElainaThemeData theme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          // ignore: deprecated_member_use
          activeColor: theme.primary,
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required String subtitle,
    required String value,
    required List<DropdownMenuItem<String>> options,
    required ValueChanged<String?> onChanged,
    required ElainaThemeData theme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: theme.background,
              items: options,
              onChanged: onChanged,
              style: TextStyle(
                color: theme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextRow({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required ElainaThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Key? fieldKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.onBackground.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            style: TextStyle(color: theme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: theme.border, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: theme.primary, width: 1.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
