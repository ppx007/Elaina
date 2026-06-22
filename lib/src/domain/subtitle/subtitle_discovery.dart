// Subtitle discovery converts local file/provider candidates into comparable
// domain records. It should not parse cue text or perform provider networking.
// Ranking and confidence rules live here because both sources feed the same UI.
import '../../foundation/baseline_defaults.dart';
import '../../foundation/storage/storage_contracts.dart';
import '../../playback/subtitle/subtitle_parser.dart';
import '../../playback/subtitle/subtitle_scanner.dart';
import '../../playback/subtitle/subtitle_source.dart';
import '../../provider/provider_result.dart';
import '../../provider/subtitle/subtitle_provider.dart';
import 'subtitle_provider_bridge.dart';

final class SubtitleDiscoveryRequest {
  const SubtitleDiscoveryRequest({
    required this.media,
    required this.providerQuery,
    this.includeLocal = true,
    this.includeProviders = true,
  });

  final LocalMediaReference media;
  final SubtitleSearchQuery providerQuery;
  final bool includeLocal;
  final bool includeProviders;
}

final class LocalSubtitleDiscoveryCandidate {
  const LocalSubtitleDiscoveryCandidate({required this.candidate});

  final ExternalSubtitleCandidate candidate;
}

final class ProviderSubtitleDiscoveryCandidate {
  const ProviderSubtitleDiscoveryCandidate(
      {required this.candidate, required this.fromCache});

  final SubtitleProviderCandidate candidate;
  final bool fromCache;
}

final class SubtitleDiscoveryProviderFailure {
  const SubtitleDiscoveryProviderFailure(
      {required this.kind, required this.message})
      : assert(message != '',
            'Subtitle discovery failure message must not be empty.');

  final AcgProviderFailureKind kind;
  final String message;
}

final class SubtitleDiscoveryResult {
  const SubtitleDiscoveryResult({
    required this.localCandidates,
    required this.providerCandidates,
    this.providerFailures = const <SubtitleDiscoveryProviderFailure>[],
  });

  final List<LocalSubtitleDiscoveryCandidate> localCandidates;
  final List<ProviderSubtitleDiscoveryCandidate> providerCandidates;
  final List<SubtitleDiscoveryProviderFailure> providerFailures;
}

final class SubtitleProviderHandoffResult {
  const SubtitleProviderHandoffResult._(
      {this.file, this.parseRequest, this.failure, required this.fromCache});

  const SubtitleProviderHandoffResult.success({
    required RetrievedSubtitleFile file,
    required SubtitleParseRequest parseRequest,
    required bool fromCache,
  }) : this._(file: file, parseRequest: parseRequest, fromCache: fromCache);

  const SubtitleProviderHandoffResult.failure(
      SubtitleDiscoveryProviderFailure failure)
      : this._(failure: failure, fromCache: false);

  final RetrievedSubtitleFile? file;
  final SubtitleParseRequest? parseRequest;
  final SubtitleDiscoveryProviderFailure? failure;
  final bool fromCache;

  bool get isSuccess => file != null && parseRequest != null;
}

abstract interface class SubtitleDiscoveryContract {
  Future<SubtitleDiscoveryResult> discover(SubtitleDiscoveryRequest request);

  Future<SubtitleProviderHandoffResult> prepareProviderSubtitle(
      SubtitleProviderCandidate candidate);
}

final class DeterministicSubtitleDiscoveryContract
    implements SubtitleDiscoveryContract {
  DeterministicSubtitleDiscoveryContract({
    required this.provider,
    required this.cache,
    LocalExternalSubtitleScanner? localScanner,
    DateTime Function()? clock,
  })  : _localScanner = localScanner,
        _clock = clock ?? _defaultClock;

  final SubtitleProvider provider;
  final SubtitleCacheStore cache;
  final LocalExternalSubtitleScanner? _localScanner;
  final DateTime Function() _clock;

  @override
  Future<SubtitleDiscoveryResult> discover(
      SubtitleDiscoveryRequest request) async {
    final List<LocalSubtitleDiscoveryCandidate> localCandidates =
        <LocalSubtitleDiscoveryCandidate>[];
    if (request.includeLocal && _localScanner != null) {
      final List<ExternalSubtitleCandidate> scannedCandidates =
          await _localScanner.scan(SubtitleScanRequest(media: request.media));
      localCandidates.addAll(<LocalSubtitleDiscoveryCandidate>[
        for (final ExternalSubtitleCandidate candidate in scannedCandidates)
          LocalSubtitleDiscoveryCandidate(candidate: candidate),
      ]);
    }

    final List<ProviderSubtitleDiscoveryCandidate> providerCandidates =
        <ProviderSubtitleDiscoveryCandidate>[];
    final List<SubtitleDiscoveryProviderFailure> providerFailures =
        <SubtitleDiscoveryProviderFailure>[];
    if (request.includeProviders) {
      final String providerId = provider.subtitleProviderId.value;
      final String queryKey = subtitleSearchQueryKey(request.providerQuery);
      final DateTime now = _clock();
      final StoredSubtitleSearchCacheRecord? cached = await cache.searchResults(
          providerId: providerId, queryKey: queryKey, now: now);
      if (cached != null) {
        providerCandidates.addAll(<ProviderSubtitleDiscoveryCandidate>[
          for (final StoredSubtitleSearchCandidateRecord record
              in cached.candidates)
            ProviderSubtitleDiscoveryCandidate(
                candidate: _candidateFromRecord(record), fromCache: true),
        ]);
      } else {
        final AcgProviderResult<List<SubtitleProviderCandidate>> result =
            await provider.searchSubtitles(request.providerQuery);
        switch (result) {
          case AcgProviderSuccess<List<SubtitleProviderCandidate>>(
              :final value
            ):
            await cache.storeSearchResults(
              StoredSubtitleSearchCacheRecord(
                providerId: providerId,
                queryKey: queryKey,
                candidates: <StoredSubtitleSearchCandidateRecord>[
                  for (final SubtitleProviderCandidate candidate in value)
                    _candidateRecordFromProvider(candidate),
                ],
                cachedAt: now,
                expiresAt: now.add(provider.cachePolicy.searchTtl),
              ),
            );
            providerCandidates.addAll(<ProviderSubtitleDiscoveryCandidate>[
              for (final SubtitleProviderCandidate candidate in value)
                ProviderSubtitleDiscoveryCandidate(
                    candidate: candidate, fromCache: false),
            ]);
          case AcgProviderFailure<List<SubtitleProviderCandidate>>(
              :final kind,
              :final message
            ):
            providerFailures.add(
                SubtitleDiscoveryProviderFailure(kind: kind, message: message));
        }
      }
    }

    return SubtitleDiscoveryResult(
        localCandidates: localCandidates,
        providerCandidates: providerCandidates,
        providerFailures: providerFailures);
  }

  @override
  Future<SubtitleProviderHandoffResult> prepareProviderSubtitle(
      SubtitleProviderCandidate candidate) async {
    final String providerId = candidate.providerId.value;
    final DateTime now = _clock();
    final StoredSubtitleContentCacheRecord? cached = await cache.content(
      providerId: providerId,
      candidateReference: candidate.reference,
      now: now,
    );
    if (cached != null) {
      final RetrievedSubtitleFile file = RetrievedSubtitleFile(
        candidate: candidate,
        content: cached.content,
        encodingHint: cached.encodingHint,
        cachedUri: cached.cachedUri,
      );
      return SubtitleProviderHandoffResult.success(
        file: file,
        parseRequest: subtitleParseRequestFromProviderFile(
            file, _sourceUriFor(candidate, cachedUri: cached.cachedUri)),
        fromCache: true,
      );
    }

    final AcgProviderResult<RetrievedSubtitleFile> result =
        await provider.retrieveSubtitle(candidate);
    switch (result) {
      case AcgProviderSuccess<RetrievedSubtitleFile>(:final value):
        await cache.storeContent(
          StoredSubtitleContentCacheRecord(
            providerId: providerId,
            candidateReference: candidate.reference,
            content: value.content,
            encodingHint: value.encodingHint,
            cachedUri: value.cachedUri,
            cachedAt: now,
            expiresAt: now.add(provider.cachePolicy.fileTtl),
          ),
        );
        return SubtitleProviderHandoffResult.success(
          file: value,
          parseRequest: subtitleParseRequestFromProviderFile(
              value, _sourceUriFor(candidate, cachedUri: value.cachedUri)),
          fromCache: false,
        );
      case AcgProviderFailure<RetrievedSubtitleFile>(
          :final kind,
          :final message
        ):
        return SubtitleProviderHandoffResult.failure(
            SubtitleDiscoveryProviderFailure(kind: kind, message: message));
    }
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

String subtitleSearchQueryKey(SubtitleSearchQuery query) {
  final String localMediaUri = query.localMediaUri?.toString() ?? '';
  return <String>[
    query.title.trim().toLowerCase(),
    query.languageCode.trim().toLowerCase(),
    query.seasonNumber?.toString() ?? '',
    query.episodeNumber?.toString() ?? '',
    localMediaUri.trim().toLowerCase(),
  ].join('|');
}

StoredSubtitleSearchCandidateRecord _candidateRecordFromProvider(
    SubtitleProviderCandidate candidate) {
  return StoredSubtitleSearchCandidateRecord(
    id: candidate.id,
    providerId: candidate.providerId.value,
    title: candidate.title,
    format: candidate.format.name,
    reference: candidate.reference,
    confidence: candidate.confidence,
    languageCode: candidate.languageCode,
    sourceUri: candidate.sourceUri,
  );
}

SubtitleProviderCandidate _candidateFromRecord(
    StoredSubtitleSearchCandidateRecord record) {
  return SubtitleProviderCandidate(
    id: record.id,
    providerId: SubtitleProviderId(record.providerId),
    title: record.title,
    format: _providerFormatFromName(record.format),
    reference: record.reference,
    confidence: record.confidence,
    languageCode: record.languageCode,
    sourceUri: record.sourceUri,
  );
}

ProviderSubtitleFormat _providerFormatFromName(String name) {
  return switch (name) {
    'srt' => ProviderSubtitleFormat.srt,
    'vtt' => ProviderSubtitleFormat.vtt,
    'ass' => ProviderSubtitleFormat.ass,
    _ => ProviderSubtitleFormat.srt,
  };
}

Uri _sourceUriFor(SubtitleProviderCandidate candidate, {Uri? cachedUri}) {
  return cachedUri ??
      candidate.sourceUri ??
      Uri(
        scheme: 'subtitle-provider',
        host: candidate.providerId.value,
        path: '/${Uri.encodeComponent(candidate.reference)}',
      );
}
