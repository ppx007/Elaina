import 'dart:async';

// Settings domain stores only global options that runtime code actually reads.
// Page-specific business objects stay in their own domain pages.
import '../../foundation/constants.dart';
import '../../foundation/storage/storage_contracts.dart';

abstract final class SettingsPreferenceKeys {
  static const String themeMode = 'theme_mode';
  static const String bangumiAccessToken = 'bangumi_access_token';
  static const String bangumiMirrorEnabled = 'bangumi_mirror_enabled';
  static const String bangumiMirrorApiBaseUrl = 'bangumi_mirror_api_base_url';
  static const String bangumiMirrorImageBaseUrl =
      'bangumi_mirror_image_base_url';
  static const String mediaLibraryRoots = 'media_library_roots';
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
