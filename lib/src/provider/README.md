# Provider Layer

Owns external metadata, danmaku, subtitle, RSS, rule-source, and trace provider contracts. Provider traffic must route through `ProviderGateway`; providers must not own retry, rate-limit, HTTP-cache, or negative-cache policy directly.
