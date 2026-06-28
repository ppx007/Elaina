import 'dart:async';
import 'dart:convert';

// Settings domain stores only global options that runtime code actually reads.
// Page-specific business objects stay in their own domain pages.
import '../../foundation/constants.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../playback/subtitle_style.dart';

export '../playback/subtitle_auto_selection.dart'
    show
        SubtitleAutoSelectPreferences,
        SubtitleAutoSelectSettings,
        subtitleAutoSelectDisabledValue,
        subtitleAutoSelectEnabledValue;

abstract final class SettingsPreferenceKeys {
  static const String themeMode = 'theme_mode';
  static const String bangumiAccessToken = 'bangumi_access_token';
  static const String bangumiMirrorEnabled = 'bangumi_mirror_enabled';
  static const String bangumiMirrorApiBaseUrl = 'bangumi_mirror_api_base_url';
  static const String bangumiMirrorImageBaseUrl =
      'bangumi_mirror_image_base_url';
  static const String mediaLibraryRoots = 'media_library_roots';
  static const String anime4kShaderOverrideDirectory =
      'anime4k_shader_override_directory';
  static const String anime4kDefaultPreset = 'anime4k_default_preset';
  static const String playbackBackendMode = 'playback_backend_mode';
  static const String vlcRuntimeDirectory = 'vlc_runtime_directory';
  static const String subtitleStyleProfile = 'subtitle_style_profile';
  static const String subtitleAutoSelectEnabled =
      'subtitle_auto_select_enabled';
  static const String subtitleAutoSelectPattern =
      'subtitle_auto_select_pattern';
}

abstract final class SettingsThemeModePreference {
  static const String auto = 'auto';
  static const String light = 'light';
  static const String dark = 'dark';

  static String parse(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return auto;
    return switch (normalized) {
      auto || light || dark => normalized,
      _ => throw FormatException('Invalid theme mode: $value'),
    };
  }
}

abstract final class BangumiMirrorSettings {
  static const String enabledValue = 'true';
  static const String disabledValue = 'false';

  static bool isEnabled(String? value) => value == enabledValue;

  static Uri parseBaseUri(String value, {required String fieldName}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$fieldName is required.');
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !_isHttpUri(uri) || uri.host.isEmpty) {
      throw FormatException(
          '$fieldName must be an absolute http or https URL.');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw FormatException('$fieldName must not include query or fragment.');
    }
    return uri.replace(path: _trimTrailingSlash(uri.path));
  }

  static bool _isHttpUri(Uri uri) {
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  static String _trimTrailingSlash(String path) {
    if (path.length <= 1 || !path.endsWith('/')) return path;
    return path.substring(0, path.length - 1);
  }
}

abstract final class Anime4kPresetSettings {
  static const String off = 'off';
  static const String restore = 'restore';
  static const String upscale = 'upscale';
  static const String restoreAndUpscale = 'restoreAndUpscale';

  static const List<String> values = <String>[
    off,
    restore,
    upscale,
    restoreAndUpscale,
  ];

  static String parse(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return off;
    return switch (normalized) {
      off || restore || upscale || restoreAndUpscale => normalized,
      _ => throw FormatException('Invalid Anime4K preset: $value'),
    };
  }
}

abstract final class SubtitleStyleSettings {
  static const String _fontFamily = 'fontFamily';
  static const String _fontSize = 'fontSize';
  static const String _fontWeight = 'fontWeight';
  static const String _textColorArgb = 'textColorArgb';
  static const String _textOpacity = 'textOpacity';
  static const String _outlineStrength = 'outlineStrength';
  static const String _backgroundEnabled = 'backgroundEnabled';
  static const String _backgroundOpacity = 'backgroundOpacity';
  static const String _lineHeight = 'lineHeight';
  static const String _bottomInset = 'bottomInset';
  static const String _forceOverrideEmbeddedStyle =
      'forceOverrideEmbeddedStyle';

  static SubtitleStyleProfile parse(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return SubtitleStyleProfile.defaults;
    final Object? decoded = jsonDecode(normalized);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Subtitle style profile must be a JSON map.');
    }
    return SubtitleStyleProfile(
      fontFamily: _string(decoded, _fontFamily),
      fontSize: _double(decoded, _fontSize),
      fontWeight: _fontWeightValue(decoded[_fontWeight]),
      textColorArgb: _int(decoded, _textColorArgb),
      textOpacity: _double(decoded, _textOpacity),
      outlineStrength: _double(decoded, _outlineStrength),
      backgroundEnabled: _bool(decoded, _backgroundEnabled),
      backgroundOpacity: _double(decoded, _backgroundOpacity),
      lineHeight: _double(decoded, _lineHeight),
      bottomInset: _double(decoded, _bottomInset),
      forceOverrideEmbeddedStyle: _bool(decoded, _forceOverrideEmbeddedStyle),
    );
  }

  static String serialize(SubtitleStyleProfile profile) {
    return jsonEncode(<String, Object?>{
      _fontFamily: profile.fontFamily,
      _fontSize: profile.fontSize,
      _fontWeight: profile.fontWeight.name,
      _textColorArgb: profile.textColorArgb,
      _textOpacity: profile.textOpacity,
      _outlineStrength: profile.outlineStrength,
      _backgroundEnabled: profile.backgroundEnabled,
      _backgroundOpacity: profile.backgroundOpacity,
      _lineHeight: profile.lineHeight,
      _bottomInset: profile.bottomInset,
      _forceOverrideEmbeddedStyle: profile.forceOverrideEmbeddedStyle,
    });
  }

  static String _string(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      return SubtitleStyleProfile.defaults.fontFamily;
    }
    if (value is String) return value;
    throw FormatException('Subtitle style field $key must be a string.');
  }

  static double _double(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      return switch (key) {
        _fontSize => SubtitleStyleProfile.defaultFontSize,
        _textOpacity => SubtitleStyleProfile.defaultTextOpacity,
        _outlineStrength => SubtitleStyleProfile.defaultOutlineStrength,
        _backgroundOpacity => SubtitleStyleProfile.defaultBackgroundOpacity,
        _lineHeight => SubtitleStyleProfile.defaultLineHeight,
        _bottomInset => SubtitleStyleProfile.defaultBottomInset,
        _ => throw FormatException('Subtitle style field $key is required.'),
      };
    }
    if (value is num) return value.toDouble();
    throw FormatException('Subtitle style field $key must be numeric.');
  }

  static int _int(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) return SubtitleStyleProfile.defaultTextColorArgb;
    if (value is int) return value;
    throw FormatException('Subtitle style field $key must be an integer.');
  }

  static bool _bool(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      return switch (key) {
        _backgroundEnabled => SubtitleStyleProfile.defaultBackgroundEnabled,
        _forceOverrideEmbeddedStyle =>
          SubtitleStyleProfile.defaultForceOverrideEmbeddedStyle,
        _ => throw FormatException('Subtitle style field $key is required.'),
      };
    }
    if (value is bool) return value;
    throw FormatException('Subtitle style field $key must be boolean.');
  }

  static SubtitleStyleFontWeight _fontWeightValue(Object? value) {
    final String normalized = value as String? ?? '';
    if (normalized.isEmpty) return SubtitleStyleFontWeight.bold;
    return SubtitleStyleFontWeight.values.firstWhere(
      (SubtitleStyleFontWeight weight) => weight.name == normalized,
      orElse: () => throw FormatException(
        'Invalid subtitle font weight: $value',
      ),
    );
  }
}

abstract interface class SettingsRuntime {
  Future<String?> getPreference(String key);
  Future<void> setPreference({required String key, required String value});

  Future<String?> getProxyUrl();
  Future<void> saveProxyUrl(String proxyUrl);

  Future<String?> getDnsPolicy();
  Future<void> saveDnsPolicy(String dnsPolicy);
}

final class SettingsRuntimeAdapter implements SettingsRuntime {
  SettingsRuntimeAdapter({
    required SettingsStore settingsStore,
    required NetworkPolicyStore networkPolicyStore,
  })  : _settingsStore = settingsStore,
        _networkPolicyStore = networkPolicyStore;

  final SettingsStore _settingsStore;
  final NetworkPolicyStore _networkPolicyStore;

  static const String _proxyUrlKey = 'network_proxy_url';
  static const String _dnsPolicyKey = 'dns_policy';
  static const String _policyId = AppConstants.defaultNetworkPolicyId;
  static const String _proxyRuleId = 'rule-proxy';
  static const String _dnsRuleId = 'rule-dns';

  @override
  Future<String?> getPreference(String key) {
    return _settingsStore.readString(key);
  }

  @override
  Future<void> setPreference({required String key, required String value}) {
    return _settingsStore.writeString(key: key, value: value);
  }

  @override
  Future<String?> getProxyUrl() async {
    return _settingsStore.readString(_proxyUrlKey);
  }

  @override
  Future<void> saveProxyUrl(String proxyUrl) async {
    await _settingsStore.writeString(key: _proxyUrlKey, value: proxyUrl);

    final List<StoredNetworkPolicyRuleRecord> existingRules =
        await _networkPolicyStore.rulesForPolicy(_policyId);

    final List<StoredNetworkPolicyRuleRecord> updatedRules = existingRules
        .where((StoredNetworkPolicyRuleRecord rule) => rule.id != _proxyRuleId)
        .toList();

    if (proxyUrl.isNotEmpty) {
      updatedRules.add(StoredNetworkPolicyRuleRecord(
        id: _proxyRuleId,
        policyId: _policyId,
        order: updatedRules.length + 1,
        matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
        pattern: AppConstants.defaultNetworkPolicyDomainPattern,
        action: StoredNetworkPolicyAction.proxyTag,
        proxyTag: proxyUrl,
        auditLabel: 'user-proxy',
      ));
    }

    await _networkPolicyStore.storeRules(
        policyId: _policyId, rules: updatedRules);
  }

  @override
  Future<String?> getDnsPolicy() async {
    return _settingsStore.readString(_dnsPolicyKey);
  }

  @override
  Future<void> saveDnsPolicy(String dnsPolicy) async {
    await _settingsStore.writeString(key: _dnsPolicyKey, value: dnsPolicy);

    final List<StoredNetworkPolicyRuleRecord> existingRules =
        await _networkPolicyStore.rulesForPolicy(_policyId);

    final List<StoredNetworkPolicyRuleRecord> updatedRules = existingRules
        .where((StoredNetworkPolicyRuleRecord rule) => rule.id != _dnsRuleId)
        .toList();

    if (dnsPolicy.isNotEmpty) {
      StoredNetworkPolicyAction action = StoredNetworkPolicyAction.systemDns;
      Uri? endpoint;
      if (dnsPolicy.startsWith('https://')) {
        action = StoredNetworkPolicyAction.doh;
        endpoint = Uri.tryParse(dnsPolicy);
      } else if (dnsPolicy.toLowerCase() == 'direct') {
        action = StoredNetworkPolicyAction.direct;
      } else if (dnsPolicy.toLowerCase() == 'block') {
        action = StoredNetworkPolicyAction.block;
      }

      updatedRules.add(StoredNetworkPolicyRuleRecord(
        id: _dnsRuleId,
        policyId: _policyId,
        order: updatedRules.length + 1,
        matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
        pattern: AppConstants.defaultNetworkPolicyDomainPattern,
        action: action,
        resolverEndpoint: endpoint,
        auditLabel: 'user-dns',
      ));
    }

    await _networkPolicyStore.storeRules(
        policyId: _policyId, rules: updatedRules);
  }
}

final class FakeSettingsRuntime implements SettingsRuntime {
  final Map<String, String> _prefs = <String, String>{};
  String? _proxyUrl;
  String? _dnsPolicy;

  @override
  Future<String?> getPreference(String key) async => _prefs[key];

  @override
  Future<void> setPreference(
      {required String key, required String value}) async {
    _prefs[key] = value;
  }

  @override
  Future<String?> getProxyUrl() async => _proxyUrl;

  @override
  Future<void> saveProxyUrl(String proxyUrl) async {
    _proxyUrl = proxyUrl;
  }

  @override
  Future<String?> getDnsPolicy() async => _dnsPolicy;

  @override
  Future<void> saveDnsPolicy(String dnsPolicy) async {
    _dnsPolicy = dnsPolicy;
  }
}
