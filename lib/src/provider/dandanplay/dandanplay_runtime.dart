import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../provider_result.dart';
import 'dandanplay_comments.dart';
import 'dandanplay_provider.dart';
import 'dandanplay_registration.dart';

const Duration dandanplayRuntimeDeduplicationWindow = Duration(seconds: 30);

ProviderRequestKey dandanplayMatchRequestKey(String filename) {
  return ProviderRequestKey(
    providerId: dandanplayProviderId,
    cacheKey: 'match:${_normalizeQuery(filename)}',
  );
}

ProviderRequestKey dandanplaySearchRequestKey(String query) {
  return ProviderRequestKey(
    providerId: dandanplayProviderId,
    cacheKey: 'search:${_normalizeQuery(query)}',
  );
}

ProviderRequestKey dandanplayCommentsRequestKey(DandanplayEpisodeId episodeId) {
  return ProviderRequestKey(
    providerId: dandanplayProviderId,
    cacheKey: 'comments:${episodeId.value}',
  );
}

ProviderRequestKey dandanplayPostCommentRequestKey(DandanplayCommentPost post) {
  return ProviderRequestKey(
    providerId: dandanplayProviderId,
    cacheKey:
        'post-comment:${post.episodeId.value}:${post.comment.timestamp.inMilliseconds}:${_stableTextHash(post.comment.text)}',
  );
}

ProviderGatewayRequest<T> dandanplayGatewayRequest<T>({
  required ProviderRequestKey key,
  required Future<T> Function() load,
  ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkFirst,
}) {
  return ProviderGatewayRequest<T>(
    key: key,
    load: load,
    cachePolicy: cachePolicy,
    deduplicationWindow: dandanplayRuntimeDeduplicationWindow,
  );
}

final class DeterministicDandanplayProvider implements DandanplayProvider {
  DeterministicDandanplayProvider({
    required this.gateway,
    Map<String, List<DandanplayMatchCandidate>> matchCandidatesByFilename =
        const <String, List<DandanplayMatchCandidate>>{},
    Iterable<DandanplayMatchCandidate> searchCandidates =
        const <DandanplayMatchCandidate>[],
  })  : _matchCandidatesByFilename = <String, List<DandanplayMatchCandidate>>{
          for (final MapEntry<String, List<DandanplayMatchCandidate>> entry
              in matchCandidatesByFilename.entries)
            _normalizeQuery(entry.key):
                List<DandanplayMatchCandidate>.unmodifiable(
              entry.value,
            ),
        },
        _searchCandidates = List<DandanplayMatchCandidate>.unmodifiable(
          searchCandidates,
        );

  final Map<String, List<DandanplayMatchCandidate>> _matchCandidatesByFilename;
  final List<DandanplayMatchCandidate> _searchCandidates;

  @override
  final ProviderGateway gateway;

  @override
  String get id => dandanplayProviderId.value;

  @override
  String get displayName => 'Dandanplay';

  @override
  ProviderKind get kind => ProviderKind.danmaku;

  @override
  ProviderRegistration get registration => dandanplayProviderRegistration();

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: dandanplayProviderId,
      cacheKey: cacheKey,
    );
  }

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) {
    return gateway.execute<T>(
      dandanplayGatewayRequest<T>(
        key: requestKey(cacheKey),
        load: load,
        cachePolicy: cachePolicy,
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchLocalMedia(
    String filename,
  ) {
    return _execute<List<DandanplayMatchCandidate>>(
      key: dandanplayMatchRequestKey(filename),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        final String normalizedFilename = _normalizeQuery(filename);
        final List<DandanplayMatchCandidate>? candidates =
            _matchCandidatesByFilename[normalizedFilename];
        if (candidates == null) {
          throw ProviderFailure(
            kind: ProviderFailureKind.cachedMiss,
            message: 'Dandanplay match for $filename was not found.',
          );
        }
        return candidates;
      },
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> search(
    String query,
  ) {
    final String normalizedQuery = _normalizeQuery(query);
    return _execute<List<DandanplayMatchCandidate>>(
      key: dandanplaySearchRequestKey(query),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        if (normalizedQuery.isEmpty) return const <DandanplayMatchCandidate>[];
        return _searchCandidates
            .where(
              (DandanplayMatchCandidate candidate) =>
                  candidate.title.toLowerCase().contains(normalizedQuery) ||
                  candidate.animeId.value.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                  candidate.episodeId.value.toLowerCase().contains(
                        normalizedQuery,
                      ),
            )
            .toList(growable: false);
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
        dandanplayGatewayRequest<T>(
          key: key,
          load: load,
          cachePolicy: cachePolicy,
        ),
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

final class DeterministicDandanplayCommentProvider
    implements DandanplayCommentProvider {
  DeterministicDandanplayCommentProvider({
    required ProviderGateway gateway,
    Map<String, List<DandanplayComment>> commentsByEpisodeId =
        const <String, List<DandanplayComment>>{},
    bool postingAvailable = true,
  })  : _gateway = gateway,
        _commentsByEpisodeId = <String, List<DandanplayComment>>{
          for (final MapEntry<String, List<DandanplayComment>> entry
              in commentsByEpisodeId.entries)
            entry.key: List<DandanplayComment>.unmodifiable(entry.value),
        },
        _postingAvailable = postingAvailable;

  final ProviderGateway _gateway;
  final Map<String, List<DandanplayComment>> _commentsByEpisodeId;
  final bool _postingAvailable;
  final List<DandanplayCommentPost> _postedComments = <DandanplayCommentPost>[];

  List<DandanplayCommentPost> get postedComments =>
      List<DandanplayCommentPost>.unmodifiable(_postedComments);

  @override
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
    DandanplayEpisodeId episodeId,
  ) {
    return _execute<List<DandanplayComment>>(
      key: dandanplayCommentsRequestKey(episodeId),
      cachePolicy: ProviderCachePolicy.networkFirst,
      load: () async {
        final List<DandanplayComment>? comments =
            _commentsByEpisodeId[episodeId.value];
        if (comments == null) {
          throw ProviderFailure(
            kind: ProviderFailureKind.cachedMiss,
            message:
                'Dandanplay comments for ${episodeId.value} were not found.',
          );
        }
        return comments;
      },
    );
  }

  @override
  Future<AcgProviderResult<void>> postComment(DandanplayCommentPost post) {
    return _execute<void>(
      key: dandanplayPostCommentRequestKey(post),
      cachePolicy: ProviderCachePolicy.networkOnly,
      load: () async {
        if (!_postingAvailable) {
          throw ProviderFailure(
            kind: ProviderFailureKind.retryable,
            message: 'Dandanplay comment posting is unavailable.',
          );
        }
        _postedComments.add(post);
      },
    );
  }

  Future<AcgProviderResult<T>> _execute<T>({
    required ProviderRequestKey key,
    required Future<T> Function() load,
    required ProviderCachePolicy cachePolicy,
  }) async {
    try {
      final ProviderGatewayResponse<T> response = await _gateway.execute<T>(
        dandanplayGatewayRequest<T>(
          key: key,
          load: load,
          cachePolicy: cachePolicy,
        ),
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

final class DandanplayProviderRuntime
    implements DandanplayProvider, DandanplayCommentProvider {
  DandanplayProviderRuntime({
    required ProviderGateway gateway,
    Map<String, List<DandanplayMatchCandidate>> matchCandidatesByFilename =
        const <String, List<DandanplayMatchCandidate>>{},
    Iterable<DandanplayMatchCandidate> searchCandidates =
        const <DandanplayMatchCandidate>[],
    Map<String, List<DandanplayComment>> commentsByEpisodeId =
        const <String, List<DandanplayComment>>{},
    bool postingAvailable = true,
  })  : _gateway = gateway,
        _provider = DeterministicDandanplayProvider(
          gateway: gateway,
          matchCandidatesByFilename: matchCandidatesByFilename,
          searchCandidates: searchCandidates,
        ),
        _commentProvider = DeterministicDandanplayCommentProvider(
          gateway: gateway,
          commentsByEpisodeId: commentsByEpisodeId,
          postingAvailable: postingAvailable,
        );

  final ProviderGateway _gateway;
  final DeterministicDandanplayProvider _provider;
  final DeterministicDandanplayCommentProvider _commentProvider;
  bool _registered = false;
  bool _disposed = false;

  DeterministicDandanplayProvider get provider => _provider;

  DeterministicDandanplayCommentProvider get commentProvider =>
      _commentProvider;

  bool get isDisposed => _disposed;

  @override
  ProviderGateway get gateway => _gateway;

  @override
  String get id => _provider.id;

  @override
  String get displayName => _provider.displayName;

  @override
  ProviderKind get kind => _provider.kind;

  @override
  ProviderRegistration get registration => _provider.registration;

  Future<void> initialize() => _ensureRegistered();

  void dispose() {
    _disposed = true;
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) =>
      _provider.requestKey(cacheKey);

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
          message: 'Dandanplay provider runtime has been disposed.',
        ),
      );
    }
    await _ensureRegistered();
    return _provider.executeGatewayRequest<T>(
      cacheKey: cacheKey,
      load: load,
      cachePolicy: cachePolicy,
    );
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchLocalMedia(
    String filename,
  ) async {
    if (_disposed) {
      return _disposedFailure<List<DandanplayMatchCandidate>>();
    }
    await _ensureRegistered();
    return _provider.matchLocalMedia(filename);
  }

  @override
  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> search(
    String query,
  ) async {
    if (_disposed) {
      return _disposedFailure<List<DandanplayMatchCandidate>>();
    }
    await _ensureRegistered();
    return _provider.search(query);
  }

  @override
  Future<AcgProviderResult<List<DandanplayComment>>> commentsForEpisode(
    DandanplayEpisodeId episodeId,
  ) async {
    if (_disposed) return _disposedFailure<List<DandanplayComment>>();
    await _ensureRegistered();
    return _commentProvider.commentsForEpisode(episodeId);
  }

  @override
  Future<AcgProviderResult<void>> postComment(
    DandanplayCommentPost post,
  ) async {
    if (_disposed) return _disposedFailure<void>();
    await _ensureRegistered();
    return _commentProvider.postComment(post);
  }

  Future<void> _ensureRegistered() async {
    if (_registered) return;
    await _gateway.registerProvider(registration);
    _registered = true;
  }

  AcgProviderFailure<T> _disposedFailure<T>() {
    return AcgProviderFailure<T>(
      kind: AcgProviderFailureKind.unavailable,
      message: 'Dandanplay provider runtime has been disposed.',
    );
  }
}

final class DandanplayProviderBootstrap {
  DandanplayProviderBootstrap({
    required ProviderGateway gateway,
    Map<String, List<DandanplayMatchCandidate>> matchCandidatesByFilename =
        const <String, List<DandanplayMatchCandidate>>{},
    Iterable<DandanplayMatchCandidate> searchCandidates =
        const <DandanplayMatchCandidate>[],
    Map<String, List<DandanplayComment>> commentsByEpisodeId =
        const <String, List<DandanplayComment>>{},
    bool postingAvailable = true,
  }) : runtime = DandanplayProviderRuntime(
          gateway: gateway,
          matchCandidatesByFilename: matchCandidatesByFilename,
          searchCandidates: searchCandidates,
          commentsByEpisodeId: commentsByEpisodeId,
          postingAvailable: postingAvailable,
        );

  final DandanplayProviderRuntime runtime;

  DandanplayProvider get provider => runtime;

  DandanplayCommentProvider get commentProvider => runtime;

  Future<void> initialize() => runtime.initialize();

  void dispose() => runtime.dispose();
}

String _normalizeQuery(String value) => value.trim().toLowerCase();

String _stableTextHash(String text) {
  var hash = 0x811c9dc5;
  for (final int codeUnit in text.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
