class AppConstants {
  // Feed Scheduler Defaults
  static const Duration defaultFeedRefreshInterval = Duration(hours: 1);

  // Diagnostics Policy Defaults
  static const int diagnosticsRetentionMaxEvents = 1000;
  static const Duration diagnosticsRetentionMaxAge = Duration(days: 7);
  static const int diagnosticsPageMaxDisplayEvents = 100;

  // Media Library Defaults
  static const Set<String> supportedVideoExtensions = <String>{'mkv', 'mp4', 'avi', 'mov', 'flv', 'wmv', 'webm'};
  static const List<String> defaultMediaLibraryRoots = <String>['file:///D:/media/', 'file:///C:/Users/Public/Videos/'];

  // Settings Policy Defaults
  static const String defaultNetworkPolicyDomainPattern = 'example.test';
}
