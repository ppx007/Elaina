import '../player_clock.dart';
import 'subtitle_cue.dart';
import 'subtitle_offset.dart';
import 'subtitle_parser.dart';
import 'subtitle_scanner.dart';
import 'subtitle_source.dart';

enum BasicSubtitleRuntimeStatus {
  idle,
  scanning,
  ready,
  failed,
  disposed,
}

enum BasicSubtitleRuntimeFailureKind {
  unsupportedFormat,
  disposed,
  missingTrack,
  parseFailure,
}

final class BasicSubtitleRuntimeFailure {
  const BasicSubtitleRuntimeFailure({required this.kind, required this.message})
      : assert(message != '',
            'Subtitle runtime failure message must not be empty.');

  final BasicSubtitleRuntimeFailureKind kind;
  final String message;
}

final class BasicSubtitleRuntimeSnapshot {
  BasicSubtitleRuntimeSnapshot({
    required this.status,
    List<SubtitleTrack> loadedTracks = const <SubtitleTrack>[],
    this.selectedSource,
    List<SubtitleCue> activeCues = const <SubtitleCue>[],
    this.offset = const SubtitleOffset(Duration.zero),
    List<String> warnings = const <String>[],
    this.failure,
  })  : loadedTracks = List<SubtitleTrack>.unmodifiable(<SubtitleTrack>[
          for (final SubtitleTrack track in loadedTracks) _copyTrack(track),
        ]),
        activeCues = List<SubtitleCue>.unmodifiable(activeCues),
        warnings = List<String>.unmodifiable(warnings);

  final BasicSubtitleRuntimeStatus status;
  final List<SubtitleTrack> loadedTracks;
  final SubtitleSource? selectedSource;
  final List<SubtitleCue> activeCues;
  final SubtitleOffset offset;
  final List<String> warnings;
  final BasicSubtitleRuntimeFailure? failure;

  static SubtitleTrack _copyTrack(SubtitleTrack track) {
    return SubtitleTrack(
      source: track.source,
      cues: List<SubtitleCue>.unmodifiable(track.cues),
      title: track.title,
      styleMetadata: Map<String, String>.unmodifiable(track.styleMetadata),
    );
  }
}

final class BasicSubtitleLoadResult {
  const BasicSubtitleLoadResult._(
      {this.track, this.failure, this.warnings = const <String>[]});

  const BasicSubtitleLoadResult.loaded(SubtitleTrack track,
      {List<String> warnings = const <String>[]})
      : this._(track: track, warnings: warnings);

  const BasicSubtitleLoadResult.failure(BasicSubtitleRuntimeFailure failure)
      : this._(failure: failure);

  final SubtitleTrack? track;
  final BasicSubtitleRuntimeFailure? failure;
  final List<String> warnings;

  bool get isSuccess => track != null && failure == null;
}

final class BasicSubtitleScanResult {
  const BasicSubtitleScanResult._({required this.candidates, this.failure});

  const BasicSubtitleScanResult.success(
      List<ExternalSubtitleCandidate> candidates)
      : this._(candidates: candidates);

  const BasicSubtitleScanResult.failure(BasicSubtitleRuntimeFailure failure)
      : this._(
            candidates: const <ExternalSubtitleCandidate>[], failure: failure);

  final List<ExternalSubtitleCandidate> candidates;
  final BasicSubtitleRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

final class BasicSubtitleSelectionResult {
  const BasicSubtitleSelectionResult._({this.failure});

  const BasicSubtitleSelectionResult.selected() : this._();

  const BasicSubtitleSelectionResult.failure(
      BasicSubtitleRuntimeFailure failure)
      : this._(failure: failure);

  final BasicSubtitleRuntimeFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class BasicSubtitleRuntimeObserver {
  void onSubtitleRuntimeSnapshot(BasicSubtitleRuntimeSnapshot snapshot);
}

final class BasicSubtitleRuntime {
  BasicSubtitleRuntime({
    SubtitleParserRegistry? parserRegistry,
    LocalExternalSubtitleScanner? scanner,
    SubtitleOffset offset = const SubtitleOffset(Duration.zero),
  })  : _parserRegistry =
            parserRegistry ?? BasicSubtitleParserRegistry.defaults(),
        _scanner = scanner,
        _snapshot = BasicSubtitleRuntimeSnapshot(
            status: BasicSubtitleRuntimeStatus.idle, offset: offset);

  final SubtitleParserRegistry _parserRegistry;
  final LocalExternalSubtitleScanner? _scanner;
  final List<BasicSubtitleRuntimeObserver> _observers =
      <BasicSubtitleRuntimeObserver>[];
  BasicSubtitleRuntimeSnapshot _snapshot;
  bool _disposed = false;

  BasicSubtitleRuntimeSnapshot get currentSnapshot => _snapshot;

  bool get isDisposed => _disposed;

  void addObserver(BasicSubtitleRuntimeObserver observer) {
    if (_disposed) {
      throw StateError('BasicSubtitleRuntime has been disposed.');
    }
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  void removeObserver(BasicSubtitleRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<BasicSubtitleScanResult> scan(SubtitleScanRequest request) async {
    if (_disposed) return BasicSubtitleScanResult.failure(_disposedFailure());
    final LocalExternalSubtitleScanner? scanner = _scanner;
    if (scanner == null) {
      return const BasicSubtitleScanResult.success(
          <ExternalSubtitleCandidate>[]);
    }
    _publish(_copySnapshot(status: BasicSubtitleRuntimeStatus.scanning));
    final List<ExternalSubtitleCandidate> candidates =
        await scanner.scan(request);
    _publish(_copySnapshot(status: BasicSubtitleRuntimeStatus.ready));
    return BasicSubtitleScanResult.success(
        List<ExternalSubtitleCandidate>.unmodifiable(candidates));
  }

  Future<BasicSubtitleLoadResult> load(SubtitleParseRequest request) async {
    if (_disposed) return BasicSubtitleLoadResult.failure(_disposedFailure());
    final SubtitleParser? parser =
        _parserRegistry.parserFor(request.source.format);
    if (parser == null) {
      final BasicSubtitleRuntimeFailure failure = BasicSubtitleRuntimeFailure(
        kind: BasicSubtitleRuntimeFailureKind.unsupportedFormat,
        message: 'No parser is registered for ${request.source.format.name}.',
      );
      _publish(_copySnapshot(
          status: BasicSubtitleRuntimeStatus.failed, failure: failure));
      return BasicSubtitleLoadResult.failure(failure);
    }
    try {
      final SubtitleParseResult result = await parser.parse(request);
      final List<SubtitleTrack> tracks = <SubtitleTrack>[
        ..._snapshot.loadedTracks,
        result.track
      ];
      _publish(
        BasicSubtitleRuntimeSnapshot(
          status: BasicSubtitleRuntimeStatus.ready,
          loadedTracks: tracks,
          selectedSource: _snapshot.selectedSource ?? result.track.source,
          activeCues: _snapshot.activeCues,
          offset: _snapshot.offset,
          warnings: <String>[..._snapshot.warnings, ...result.warnings],
        ),
      );
      return BasicSubtitleLoadResult.loaded(result.track,
          warnings: result.warnings);
    } on Object catch (error) {
      final BasicSubtitleRuntimeFailure failure = BasicSubtitleRuntimeFailure(
        kind: BasicSubtitleRuntimeFailureKind.parseFailure,
        message: error.toString(),
      );
      _publish(_copySnapshot(
          status: BasicSubtitleRuntimeStatus.failed, failure: failure));
      return BasicSubtitleLoadResult.failure(failure);
    }
  }

  BasicSubtitleSelectionResult select(SubtitleSource source) {
    if (_disposed)
      return BasicSubtitleSelectionResult.failure(_disposedFailure());
    final bool exists = _snapshot.loadedTracks
        .any((SubtitleTrack track) => track.source.id == source.id);
    if (!exists) {
      return const BasicSubtitleSelectionResult.failure(
        BasicSubtitleRuntimeFailure(
          kind: BasicSubtitleRuntimeFailureKind.missingTrack,
          message: 'Subtitle source has not been loaded.',
        ),
      );
    }
    _publish(_copySnapshot(selectedSource: source));
    return const BasicSubtitleSelectionResult.selected();
  }

  BasicSubtitleRuntimeSnapshot resolveActiveCues(PlayerClockSnapshot clock) {
    if (_disposed)
      return _copySnapshot(
          status: BasicSubtitleRuntimeStatus.disposed,
          failure: _disposedFailure());
    final SubtitleSource? selected = _snapshot.selectedSource;
    final SubtitleTrack? track =
        selected == null ? null : _trackForSource(selected);
    final List<SubtitleCue> active = track == null
        ? const <SubtitleCue>[]
        : SubtitleCueResolver(offset: _snapshot.offset)
            .activeCues(track: track, clock: clock);
    _publish(_copySnapshot(activeCues: active));
    return _snapshot;
  }

  void setOffset(SubtitleOffset offset) {
    if (_disposed) return;
    _publish(_copySnapshot(offset: offset));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(_copySnapshot(
        status: BasicSubtitleRuntimeStatus.disposed,
        failure: _disposedFailure()));
    _observers.clear();
  }

  BasicSubtitleRuntimeSnapshot _copySnapshot({
    BasicSubtitleRuntimeStatus? status,
    List<SubtitleTrack>? loadedTracks,
    SubtitleSource? selectedSource,
    List<SubtitleCue>? activeCues,
    SubtitleOffset? offset,
    List<String>? warnings,
    BasicSubtitleRuntimeFailure? failure,
  }) {
    return BasicSubtitleRuntimeSnapshot(
      status: status ?? _snapshot.status,
      loadedTracks: loadedTracks ?? _snapshot.loadedTracks,
      selectedSource: selectedSource ?? _snapshot.selectedSource,
      activeCues: activeCues ?? _snapshot.activeCues,
      offset: offset ?? _snapshot.offset,
      warnings: warnings ?? _snapshot.warnings,
      failure: failure,
    );
  }

  BasicSubtitleRuntimeFailure _disposedFailure() {
    return const BasicSubtitleRuntimeFailure(
      kind: BasicSubtitleRuntimeFailureKind.disposed,
      message: 'BasicSubtitleRuntime has been disposed.',
    );
  }

  SubtitleTrack? _trackForSource(SubtitleSource source) {
    for (final SubtitleTrack track in _snapshot.loadedTracks) {
      if (track.source.id == source.id) return track;
    }
    return null;
  }

  void _publish(BasicSubtitleRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    for (final BasicSubtitleRuntimeObserver observer
        in List<BasicSubtitleRuntimeObserver>.of(_observers)) {
      observer.onSubtitleRuntimeSnapshot(snapshot);
    }
  }
}
