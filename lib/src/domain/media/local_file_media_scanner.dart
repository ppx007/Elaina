import 'dart:convert';
import 'dart:io';

import '../../foundation/baseline_defaults.dart';
import 'media_library.dart';

const String localFileMediaScannerScanIdPrefix = 'local-file-scan';
const String localFileMediaScannerMediaIdPrefix = 'local-file';

typedef MediaScanIdFactory = MediaScanId Function();

final class LocalFileMediaLibraryScanner implements MediaLibraryScanner {
  LocalFileMediaLibraryScanner({
    MediaScanIdFactory? scanIdFactory,
    DateTime Function()? clock,
  })  : _scanIdFactory = scanIdFactory ?? _defaultScanIdFactory,
        _clock = clock ?? _defaultClock;

  final MediaScanIdFactory _scanIdFactory;
  final DateTime Function() _clock;
  final Map<String, List<MediaScanEvent>> _eventsByScanId =
      <String, List<MediaScanEvent>>{};
  final Set<String> _cancelledScanIds = <String>{};

  @override
  Future<void> cancel(MediaScanId scanId) async {
    if (_cancelledScanIds.add(scanId.value)) {
      _record(
        scanId,
        MediaScanCancelled(
          scanId: scanId,
          failure: MediaScanFailure(
            kind: MediaScanFailureKind.cancelled,
            uri: Uri(),
            message: 'Media scan was cancelled.',
          ),
        ),
      );
    }
  }

  @override
  Future<MediaScanResult> scan(MediaScanScope scope) async {
    final MediaScanId scanId = _scanIdFactory();
    if (_cancelledScanIds.contains(scanId.value)) {
      final MediaScanFailure failure = MediaScanFailure(
        kind: MediaScanFailureKind.cancelled,
        uri: _firstRootOrEmpty(scope),
        message: 'Media scan was cancelled.',
      );
      _record(scanId, MediaScanCancelled(scanId: scanId, failure: failure));
      return MediaScanResult(
        scanId: scanId,
        candidates: const <MediaScanCandidate>[],
        failures: <MediaScanFailure>[failure],
      );
    }

    final MediaScanScopeNormalizationResult normalization =
        normalizeMediaScanScope(scope);
    final NormalizedMediaScanScope? normalized = normalization.scope;
    if (normalized == null) {
      for (final MediaScanFailure failure in normalization.failures) {
        _record(scanId, MediaScanFailed(scanId: scanId, failure: failure));
      }
      return MediaScanResult(
        scanId: scanId,
        candidates: const <MediaScanCandidate>[],
        failures: normalization.failures,
      );
    }

    final List<MediaScanCandidate> candidates = <MediaScanCandidate>[];
    final List<MediaScanFailure> failures = <MediaScanFailure>[];
    for (final Uri root in normalized.roots) {
      await _scanRoot(
        scanId: scanId,
        root: root,
        scope: normalized,
        candidates: candidates,
        failures: failures,
      );
    }

    final MediaScanResult result = MediaScanResult(
      scanId: scanId,
      candidates: candidates,
      failures: failures,
    );
    _record(scanId, MediaScanCompleted(scanId: scanId, result: result));
    return result;
  }

  @override
  Stream<MediaScanEvent> watch(MediaScanId scanId) {
    return Stream<MediaScanEvent>.fromIterable(
      _eventsByScanId[scanId.value] ?? const <MediaScanEvent>[],
    );
  }

  Future<void> _scanRoot({
    required MediaScanId scanId,
    required Uri root,
    required NormalizedMediaScanScope scope,
    required List<MediaScanCandidate> candidates,
    required List<MediaScanFailure> failures,
  }) async {
    final Directory directory = Directory.fromUri(root);
    if (!directory.existsSync()) {
      _recordFailure(
        scanId: scanId,
        failures: failures,
        failure: MediaScanFailure(
          kind: MediaScanFailureKind.discoveryFailed,
          uri: root,
          message: 'Media scan root does not exist.',
        ),
      );
      return;
    }

    try {
      await for (final FileSystemEntity entity in directory.list(
        recursive: scope.recursive,
        followLinks: false,
      )) {
        if (_cancelledScanIds.contains(scanId.value)) {
          final MediaScanFailure failure = MediaScanFailure(
            kind: MediaScanFailureKind.cancelled,
            uri: root,
            message: 'Media scan was cancelled.',
          );
          _record(scanId, MediaScanCancelled(scanId: scanId, failure: failure));
          failures.add(failure);
          return;
        }
        if (entity is! File) continue;
        final Uri uri = entity.uri;
        final String basename = _basenameFromUri(uri);
        if (!scope.accepts(uri, basename: basename)) continue;
        final FileStat stat = await entity.stat();
        final MediaScanCandidate candidate = MediaScanCandidate(
          identity: LocalMediaIdentity(
            id: LocalMediaId(_mediaIdFor(uri)),
            uri: uri,
            basename: basename,
          ),
          sizeBytes: stat.size,
          discoveredAt: _clock(),
        );
        candidates.add(candidate);
        _record(
          scanId,
          MediaScanCandidateDiscovered(
            scanId: scanId,
            candidate: candidate,
          ),
        );
        _record(
          scanId,
          MediaScanProgressChanged(
            scanId: scanId,
            scannedCount: candidates.length,
          ),
        );
      }
    } on FileSystemException catch (error) {
      _recordFailure(
        scanId: scanId,
        failures: failures,
        failure: MediaScanFailure(
          kind: MediaScanFailureKind.unreadableEntry,
          uri: root,
          message: 'Media scan root could not be read: ${error.message}',
        ),
      );
    }
  }

  void _recordFailure({
    required MediaScanId scanId,
    required List<MediaScanFailure> failures,
    required MediaScanFailure failure,
  }) {
    failures.add(failure);
    _record(scanId, MediaScanFailed(scanId: scanId, failure: failure));
  }

  void _record(MediaScanId scanId, MediaScanEvent event) {
    _eventsByScanId
        .putIfAbsent(scanId.value, () => <MediaScanEvent>[])
        .add(event);
  }

  static MediaScanId _defaultScanIdFactory() {
    return MediaScanId(
      '$localFileMediaScannerScanIdPrefix-'
      '${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  static DateTime _defaultClock() => deterministicContractEpoch;
}

String _mediaIdFor(Uri uri) {
  final String encoded = base64Url.encode(utf8.encode(uri.toString()));
  return '$localFileMediaScannerMediaIdPrefix-${encoded.replaceAll('=', '')}';
}

String _basenameFromUri(Uri uri) {
  if (uri.pathSegments.isEmpty) return 'media';
  final String basename = uri.pathSegments.last;
  return basename.isEmpty ? 'media' : basename;
}

Uri _firstRootOrEmpty(MediaScanScope scope) {
  if (scope.roots.isEmpty) return Uri();
  return scope.roots.first;
}
