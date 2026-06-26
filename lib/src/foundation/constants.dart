class AppConstants {
  // Feed Scheduler Defaults
  static const Duration defaultFeedRefreshInterval = Duration(hours: 1);

  // Diagnostics Policy Defaults
  static const int diagnosticsRetentionMaxEvents = 1000;
  static const Duration diagnosticsRetentionMaxAge = Duration(days: 7);
  static const int diagnosticsPageMaxDisplayEvents = 100;

  // Media Library Defaults
  static const Set<String> supportedVideoExtensions = <String>{
    'avi',
    'asf',
    'divx',
    'f4v',
    'flv',
    'm2ts',
    'm4v',
    'mkv',
    'mov',
    'mp4',
    'mpeg',
    'mpg',
    'mts',
    'ogm',
    'ogv',
    'rm',
    'rmvb',
    'ts',
    'webm',
    'wmv',
  };

  // Settings Policy Defaults
  static const String defaultNetworkPolicyId = 'default-policy';
  static const String defaultNetworkPolicyDomainPattern = 'example.test';
}
