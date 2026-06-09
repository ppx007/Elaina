import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';
import 'bangumi_auth.dart';
import 'bangumi_provider.dart';
import 'bangumi_registration.dart';

const Duration bangumiRuntimeDeduplicationWindow = Duration(seconds: 30);

ProviderRequestKey bangumiSubjectRequestKey(BangumiSubjectId id) {
  return ProviderRequestKey(
    providerId: bangumiProviderId,
    cacheKey: 'subject:${id.value}',
  );
}

ProviderRequestKey bangumiSubjectSearchRequestKey(String query) {
  return ProviderRequestKey(
    providerId: bangumiProviderId,
    cacheKey: 'subject-search:${_normalizeQuery(query)}',
  );
}

ProviderRequestKey bangumiEpisodeRequestKey(BangumiEpisodeId id) {
  return ProviderRequestKey(
    providerId: bangumiProviderId,
    cacheKey: 'episode:${id.value}',
  );
}

ProviderRequestKey bangumiSessionRequestKey() {
  return const ProviderRequestKey(
    providerId: bangumiProviderId,
    cacheKey: 'auth-session:current',
  );
}

ProviderRequestKey bangumiProgressRequestKey(BangumiProgressUpdate update) {
  return ProviderRequestKey(
    providerId: bangumiProviderId,
    cacheKey:
        'progress:${update.subjectId.value}:${update.episodeId.value}:${update.state.name}',
  );
}

ProviderGatewayRequest<T> bangumiGatewayRequest<T>({
  required ProviderRequestKey key,
  required Future<T> Function() load,
  ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkFirst,
}) {
  return ProviderGatewayRequest<T>(
    key: key,
    load: load,
    cachePolicy: cachePolicy,
    deduplicationWindow: bangumiRuntimeDeduplicationWindow,
  );
}

final class DeterministicBangumiProvider implements BangumiProvider {
  DeterministicBangumiProvider({
    required this.gateway,
    Iterable<BangumiSubject> subjects = const <BangumiSubject>[],
    Iterable<BangumiEpisode> episodes = const <BangumiEpisode>[],
  })  : _subjects = <String, BangumiSubject>{
          for (final BangumiSubject subject in subjects)
            subject.id.value: subject,
        },
        _episodes = <String, BangumiEpisode>{
          for (final BangumiEpisode episode in episodes)
            episode.id.value: episode,
        };

  final Map<String, BangumiSubject> _subjects;
  final Map<String, BangumiEpisode> _episodes;

  @override
  final ProviderGateway gateway;

  @override
  String get id => bangumiProviderId.value;

  @override
  String get displayName => 'Bangumi';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => bangumiProviderRegistration();

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: bangumiProviderId, cacheKey: cacheKey);
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return gateway.execute<T>(
      bangumiGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id) {
    return _execute(
      key: bangumiSubjectRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        final BangumiSubject? subject = _subjects[id.value];
        if (subject == null) {
          throw ProviderFailure(
            kind: ProviderFailureKind.cachedMiss,
            message: 'Bangumi subject ${id.value} was not found.',
          );
        }
        return subject;
      },
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query) {
    final String normalizedQuery = _normalizeQuery(query);
    return _execute(
      key: bangumiSubjectSearchRequestKey(query),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        if (normalizedQuery.isEmpty) return const <BangumiSubject>[];
        return _subjects.values
            .where(
              (BangumiSubject subject) =>
                  subject.title.toLowerCase().contains(normalizedQuery) ||
                  (subject.summary?.toLowerCase().contains(normalizedQuery) ??
                      false),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id) {
    return _execute(
      key: bangumiEpisodeRequestKey(id),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        final BangumiEpisode? episode = _episodes[id.value];
        if (episode == null) {
          throw ProviderFailure(
            kind: ProviderFailureKind.cachedMiss,
            message: 'Bangumi episode ${id.value} was not found.',
          );
        }
        return episode;
      },
    );
  }

  Future<AcgProviderResult<T>> _execute<T>({
    required ProviderRequestKey key,
    required Future<T> Function() load,
    required ProviderCachePolicy cachePolicy,
  }) async {
    try {
      final ProviderGatewayResponse<T> response = await gateway.execute<T>(
        bangumiGatewayRequest<T>(
            key: key, load: load, cachePolicy: cachePolicy),
      );
      return AcgProviderSuccess<T>(response.value);
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<T>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    }
  }
}

final class DeterministicBangumiAuthProvider
    implements BangumiAuthProvider, GatewayBoundProvider {
  const DeterministicBangumiAuthProvider({
    required this.gateway,
    BangumiAuthSession? session,
    bool progressSyncAvailable = true,
    DateTime Function()? now,
  })  : _session = session,
        _progressSyncAvailable = progressSyncAvailable,
        _now = now;

  final BangumiAuthSession? _session;
  final bool _progressSyncAvailable;
  final DateTime Function()? _now;

  @override
  final ProviderGateway gateway;

  @override
  String get id => '${bangumiProviderId.value}-auth';

  @override
  String get displayName => 'Bangumi Auth';

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => bangumiProviderRegistration();

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
        providerId: bangumiProviderId, cacheKey: cacheKey);
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return gateway.execute<T>(
      bangumiGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
      ),
    );
  }

  @override
  Future<AcgProviderResult<BangumiAuthSession>> currentSession() async {
    try {
      final ProviderGatewayResponse<BangumiAuthSession?> response =
          await gateway.execute<BangumiAuthSession?>(
        bangumiGatewayRequest<BangumiAuthSession?>(
          key: bangumiSessionRequestKey(),
          cachePolicy: ProviderCachePolicy.networkFirst,
          load: () async {
            final BangumiAuthSession? session = _session;
            if (session == null ||
                session.isExpiredAt((_now ?? DateTime.now)())) {
              return null;
            }
            return session;
          },
        ),
      );
      final BangumiAuthSession? session = response.value;
      if (session == null) {
        return const AcgProviderFailure<BangumiAuthSession>(
          kind: AcgProviderFailureKind.unauthenticated,
          message: 'Bangumi auth session is not available.',
        );
      }
      return AcgProviderSuccess<BangumiAuthSession>(session);
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<BangumiAuthSession>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    }
  }

  @override
  Future<AcgProviderResult<void>> syncProgress(
    BangumiProgressUpdate update,
  ) async {
    try {
      final ProviderGatewayResponse<bool> response =
          await gateway.execute<bool>(
        bangumiGatewayRequest<bool>(
          key: bangumiProgressRequestKey(update),
          cachePolicy: ProviderCachePolicy.networkOnly,
          load: () async {
            if (!_progressSyncAvailable) {
              throw ProviderFailure(
                kind: ProviderFailureKind.retryable,
                message: 'Bangumi progress sync is unavailable.',
              );
            }
            final BangumiAuthSession? session = _session;
            if (session == null ||
                session.isExpiredAt((_now ?? DateTime.now)())) {
              return false;
            }
            return true;
          },
        ),
      );
      if (!response.value) {
        return const AcgProviderFailure<void>(
          kind: AcgProviderFailureKind.unauthenticated,
          message: 'Bangumi progress sync requires an active session.',
        );
      }
      return const AcgProviderSuccess<void>(null);
    } on ProviderFailure catch (failure) {
      return AcgProviderFailure<void>(
        kind: acgFailureKindFromGateway(failure.kind),
        message: failure.message,
      );
    }
  }
}

final class BangumiProviderRuntime
    implements BangumiProvider, BangumiAuthProvider {
  BangumiProviderRuntime({
    required ProviderGateway gateway,
    Iterable<BangumiSubject> subjects = const <BangumiSubject>[],
    Iterable<BangumiEpisode> episodes = const <BangumiEpisode>[],
    BangumiAuthSession? session,
    bool progressSyncAvailable = true,
    DateTime Function()? now,
  })  : _gateway = gateway,
        _metadataProvider = DeterministicBangumiProvider(
          gateway: gateway,
          subjects: subjects,
          episodes: episodes,
        ),
        _authProvider = DeterministicBangumiAuthProvider(
          gateway: gateway,
          session: session,
          progressSyncAvailable: progressSyncAvailable,
          now: now,
        );

  final ProviderGateway _gateway;
  final DeterministicBangumiProvider _metadataProvider;
  final DeterministicBangumiAuthProvider _authProvider;
  bool _registered = false;
  bool _disposed = false;

  DeterministicBangumiProvider get metadataProvider => _metadataProvider;

  DeterministicBangumiAuthProvider get authProvider => _authProvider;

  bool get isDisposed => _disposed;

  @override
  ProviderGateway get gateway => _gateway;

  @override
  String get id => _metadataProvider.id;

  @override
  String get displayName => _metadataProvider.displayName;

  @override
  ProviderKind get kind => _metadataProvider.kind;

  @override
  ProviderRegistration get registration => _metadataProvider.registration;

  Future<void> initialize() => _ensureRegistered();

  void dispose() {
    _disposed = true;
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) =>
      _metadataProvider.requestKey(cacheKey);

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    if (_disposed) {
      return Future<ProviderGatewayResponse<T>>.error(
        const ProviderFailure(
          kind: ProviderFailureKind.terminal,
          message: 'Bangumi provider runtime has been disposed.',
        ),
      );
    }
    await _ensureRegistered();
    return _metadataProvider.executeGatewayRequest<T>(
      cacheKey: cacheKey,
      load: load,
      cachePolicy: cachePolicy,
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(
      BangumiSubjectId id) async {
    if (_disposed) return _disposedFailure<BangumiSubject>();
    await _ensureRegistered();
    return _metadataProvider.lookupSubject(id);
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
      String query) async {
    if (_disposed) return _disposedFailure<List<BangumiSubject>>();
    await _ensureRegistered();
    return _metadataProvider.searchSubjects(query);
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
      BangumiEpisodeId id) async {
    if (_disposed) return _disposedFailure<BangumiEpisode>();
    await _ensureRegistered();
    return _metadataProvider.lookupEpisode(id);
  }

  @override
  Future<AcgProviderResult<BangumiAuthSession>> currentSession() async {
    if (_disposed) return _disposedFailure<BangumiAuthSession>();
    await _ensureRegistered();
    return _authProvider.currentSession();
  }

  @override
  Future<AcgProviderResult<void>> syncProgress(
      BangumiProgressUpdate update) async {
    if (_disposed) return _disposedFailure<void>();
    await _ensureRegistered();
    return _authProvider.syncProgress(update);
  }

  Future<void> _ensureRegistered() async {
    if (_registered) return;
    await _gateway.registerProvider(registration);
    _registered = true;
  }

  AcgProviderFailure<T> _disposedFailure<T>() {
    return AcgProviderFailure<T>(
      kind: AcgProviderFailureKind.unavailable,
      message: 'Bangumi provider runtime has been disposed.',
    );
  }
}

final class BangumiProviderBootstrap {
  BangumiProviderBootstrap({
    required ProviderGateway gateway,
    Iterable<BangumiSubject> subjects = const <BangumiSubject>[],
    Iterable<BangumiEpisode> episodes = const <BangumiEpisode>[],
    BangumiAuthSession? session,
    bool progressSyncAvailable = true,
    DateTime Function()? now,
  }) : runtime = BangumiProviderRuntime(
          gateway: gateway,
          subjects: subjects,
          episodes: episodes,
          session: session,
          progressSyncAvailable: progressSyncAvailable,
          now: now,
        );

  final BangumiProviderRuntime runtime;

  BangumiProvider get provider => runtime;

  BangumiAuthProvider get authProvider => runtime;

  Future<void> initialize() => runtime.initialize();

  void dispose() => runtime.dispose();
}

String _normalizeQuery(String query) => query.trim().toLowerCase();
