abstract interface class CelesteriaAdapter {
  String get id;
  String get displayName;
}

abstract interface class ProviderContract extends CelesteriaAdapter {
  ProviderKind get kind;
}

enum ProviderKind {
  metadata,
  danmaku,
  subtitle,
  onlineSource,
  rss,
  trace,
}

abstract interface class ProfileContract {
  String get id;
  String get label;
}

final class FeatureFlag {
  const FeatureFlag({
    required this.id,
    required this.enabledByDefault,
    required this.description,
  });

  final String id;
  final bool enabledByDefault;
  final String description;
}
