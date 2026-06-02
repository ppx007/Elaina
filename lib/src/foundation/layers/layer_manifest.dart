enum LayerId {
  ui,
  domain,
  playback,
  provider,
  gateway,
  storage,
  streaming,
  network,
}

final class LayerBoundary {
  const LayerBoundary({
    required this.id,
    required this.responsibility,
    required this.exposes,
    this.allowedDependencies = const <LayerId>{},
  });

  final LayerId id;
  final String responsibility;
  final String exposes;
  final Set<LayerId> allowedDependencies;
}

const List<LayerBoundary> celesteriaLayerManifest = <LayerBoundary>[
  LayerBoundary(
    id: LayerId.ui,
    responsibility: 'Screens, widgets, and user interaction state.',
    exposes: 'Presentation contracts only.',
    allowedDependencies: <LayerId>{LayerId.domain},
  ),
  LayerBoundary(
    id: LayerId.domain,
    responsibility: 'Application use flows and pure business contracts.',
    exposes: 'Service interfaces and domain value contracts.',
    allowedDependencies: <LayerId>{
      LayerId.playback,
      LayerId.provider,
      LayerId.gateway,
      LayerId.storage,
      LayerId.streaming,
    },
  ),
  LayerBoundary(
    id: LayerId.playback,
    responsibility: 'Player orchestration, capability reporting, and media-clock contracts.',
    exposes: 'PlayerAdapter and playback capability interfaces.',
    allowedDependencies: <LayerId>{LayerId.streaming},
  ),
  LayerBoundary(
    id: LayerId.provider,
    responsibility: 'External metadata, danmaku, subtitle, RSS, and source integrations.',
    exposes: 'Provider contracts without concrete transport policy.',
    allowedDependencies: <LayerId>{LayerId.gateway},
  ),
  LayerBoundary(
    id: LayerId.gateway,
    responsibility: 'Provider request governance, cache policy, retry, and rate limiting.',
    exposes: 'ProviderGateway contracts.',
    allowedDependencies: <LayerId>{LayerId.storage, LayerId.network},
  ),
  LayerBoundary(
    id: LayerId.storage,
    responsibility: 'SQLite metadata, blob cache, media cache, settings, and migrations.',
    exposes: 'Storage repositories and migration contracts.',
  ),
  LayerBoundary(
    id: LayerId.streaming,
    responsibility: 'Virtual media streams, BT streaming, piece priority, and buffered ranges.',
    exposes: 'Streaming abstractions only.',
    allowedDependencies: <LayerId>{LayerId.storage},
  ),
  LayerBoundary(
    id: LayerId.network,
    responsibility: 'DNS, proxy, SSRF guard, cookie/session isolation, and transport policy.',
    exposes: 'Network policy contracts.',
  ),
];

const Set<String> forbiddenUiConcreteDependencies = <String>{
  'mpv',
  'libmpv',
  'vlc',
  'bangumi',
  'dandanplay',
  'libtorrent',
  'yuc.wiki',
};

bool isLayerDependencyAllowed({
  required LayerId from,
  required LayerId to,
}) {
  final LayerBoundary source = celesteriaLayerManifest.firstWhere(
    (LayerBoundary boundary) => boundary.id == from,
  );
  return source.allowedDependencies.contains(to);
}
