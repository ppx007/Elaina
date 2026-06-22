import '../../foundation/storage/storage_contracts.dart';
import '../../playback/subtitle/subtitle_parser.dart';
import '../../playback/subtitle/subtitle_scanner.dart';
import '../../provider/subtitle/subtitle_provider.dart';
import 'subtitle_discovery.dart';

/// Runtime status tracks provider orchestration, not subtitle parsing state.
/// Parsed cue warnings stay in the subtitle runtime so provider failures remain
/// distinguishable from file-format failures.
enum SubtitleProviderRuntimeStatus {
  idle,
  searching,
  retrieving,
  ready,
  failed,
  disposed,
}

enum SubtitleProviderRuntimeFailureKind {
  disposed,
  unavailable,
  unsupported,
  providerFailure,
  retrievalFailed,
}

final class SubtitleProviderRuntimeFailure {
  const SubtitleProviderRuntimeFailure(
      {required this.kind, required this.message})
      : assert(message != '',
            'Subtitle provider runtime failure message must not be empty.');

  final SubtitleProviderRuntimeFailureKind kind;
  final String message;
}

enum SubtitleProviderActionResultKind {
  success,
  unavailable,
  unsupported,
  ignored,
  failed,
}

final class SubtitleProviderActionResult<T> {
  const SubtitleProviderActionResult._(
      {required this.kind, this.value, this.failure});

  const SubtitleProviderActionResult.success([T? value])
      : this._(kind: SubtitleProviderActionResultKind.success, value: value);

  SubtitleProviderActionResult.unavailable(String message)
      : this._(
          kind: SubtitleProviderActionResultKind.unavailable,
          failure: SubtitleProviderRuntimeFailure(
              kind: SubtitleProviderRuntimeFailureKind.unavailable,
              message: message),
        );

  SubtitleProviderActionResult.unsupported(String message)
      : this._(
          kind: SubtitleProviderActionResultKind.unsupported,
          failure: SubtitleProviderRuntimeFailure(
              kind: SubtitleProviderRuntimeFailureKind.unsupported,
              message: message),
        );

  SubtitleProviderActionResult.ignored(String message)
      : this._(
          kind: SubtitleProviderActionResultKind.ignored,
          failure: SubtitleProviderRuntimeFailure(
              kind: SubtitleProviderRuntimeFailureKind.unavailable,
              message: message),
        );

  const SubtitleProviderActionResult.failed(
      SubtitleProviderRuntimeFailure failure)
      : this._(kind: SubtitleProviderActionResultKind.failed, failure: failure);

  final SubtitleProviderActionResultKind kind;
  final T? value;
  final SubtitleProviderRuntimeFailure? failure;

  bool get isSuccess => kind == SubtitleProviderActionResultKind.success;
}

final class SubtitleProviderRuntimeSnapshot {
  SubtitleProviderRuntimeSnapshot({
    required this.status,
    this.request,
    Iterable<LocalSubtitleDiscoveryCandidate> localCandidates =
        const <LocalSubtitleDiscoveryCandidate>[],
    Iterable<ProviderSubtitleDiscoveryCandidate> providerCandidates =
        const <ProviderSubtitleDiscoveryCandidate>[],
    Iterable<SubtitleDiscoveryProviderFailure> providerFailures =
        const <SubtitleDiscoveryProviderFailure>[],
    this.handoff,
    Iterable<SubtitleProviderRuntimeFailure> failures =
        const <SubtitleProviderRuntimeFailure>[],
  })  : localCandidates =
            List<LocalSubtitleDiscoveryCandidate>.unmodifiable(localCandidates),
        providerCandidates =
            List<ProviderSubtitleDiscoveryCandidate>.unmodifiable(
                providerCandidates),
        providerFailures = List<SubtitleDiscoveryProviderFailure>.unmodifiable(
            providerFailures),
        failures = List<SubtitleProviderRuntimeFailure>.unmodifiable(failures);

  const SubtitleProviderRuntimeSnapshot.idle()
      : status = SubtitleProviderRuntimeStatus.idle,
        request = null,
        localCandidates = const <LocalSubtitleDiscoveryCandidate>[],
        providerCandidates = const <ProviderSubtitleDiscoveryCandidate>[],
        providerFailures = const <SubtitleDiscoveryProviderFailure>[],
        handoff = null,
        failures = const <SubtitleProviderRuntimeFailure>[];

  final SubtitleProviderRuntimeStatus status;
  final SubtitleDiscoveryRequest? request;
  final List<LocalSubtitleDiscoveryCandidate> localCandidates;
  final List<ProviderSubtitleDiscoveryCandidate> providerCandidates;
  final List<SubtitleDiscoveryProviderFailure> providerFailures;
  final SubtitleProviderHandoffResult? handoff;
  final List<SubtitleProviderRuntimeFailure> failures;
}

abstract interface class SubtitleProviderRuntimeObserver {
  void onSubtitleProviderRuntimeSnapshot(
      SubtitleProviderRuntimeSnapshot snapshot);
}

/// Coordinates provider lookup, download, cache invalidation, and observers.
///
/// UI and playback code should request subtitles through this runtime instead
/// of directly calling a provider or storage cache.
final class SubtitleProviderRuntime {
  SubtitleProviderRuntime({required SubtitleDiscoveryContract discovery})
      : _discovery = discovery;

  final SubtitleDiscoveryContract _discovery;
  final List<SubtitleProviderRuntimeObserver> _observers =
      <SubtitleProviderRuntimeObserver>[];
  SubtitleProviderRuntimeSnapshot _snapshot =
      const SubtitleProviderRuntimeSnapshot.idle();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  SubtitleProviderRuntimeSnapshot get currentSnapshot => _snapshot;

  void addObserver(SubtitleProviderRuntimeObserver observer) {
    if (_disposed)
      throw StateError('SubtitleProviderRuntime has been disposed.');
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void removeObserver(SubtitleProviderRuntimeObserver observer) {
    _observers.remove(observer);
  }

  Future<SubtitleProviderActionResult<SubtitleDiscoveryResult>> discover(
      SubtitleDiscoveryRequest request) async {
    if (_disposed) return _disposedResult();
    _publish(SubtitleProviderRuntimeSnapshot(
        status: SubtitleProviderRuntimeStatus.searching, request: request));
    final SubtitleDiscoveryResult result = await _discovery.discover(request);
    final List<SubtitleProviderRuntimeFailure> failures =
        <SubtitleProviderRuntimeFailure>[
      for (final SubtitleDiscoveryProviderFailure failure
          in result.providerFailures)
        SubtitleProviderRuntimeFailure(
            kind: SubtitleProviderRuntimeFailureKind.providerFailure,
            message: failure.message),
    ];
    _publish(SubtitleProviderRuntimeSnapshot(
      status: failures.isEmpty
          ? SubtitleProviderRuntimeStatus.ready
          : SubtitleProviderRuntimeStatus.failed,
      request: request,
      localCandidates: result.localCandidates,
      providerCandidates: result.providerCandidates,
      providerFailures: result.providerFailures,
      failures: failures,
    ));
    return SubtitleProviderActionResult<SubtitleDiscoveryResult>.success(
        result);
  }

  Future<SubtitleProviderActionResult<SubtitleProviderHandoffResult>>
      prepareProviderSubtitle(SubtitleProviderCandidate candidate) async {
    if (_disposed) return _disposedResult();
    _publish(SubtitleProviderRuntimeSnapshot(
      status: SubtitleProviderRuntimeStatus.retrieving,
      request: _snapshot.request,
      localCandidates: _snapshot.localCandidates,
      providerCandidates: _snapshot.providerCandidates,
      providerFailures: _snapshot.providerFailures,
    ));
    final SubtitleProviderHandoffResult result =
        await _discovery.prepareProviderSubtitle(candidate);
    if (!result.isSuccess) {
      final SubtitleProviderRuntimeFailure failure =
          SubtitleProviderRuntimeFailure(
        kind: SubtitleProviderRuntimeFailureKind.retrievalFailed,
        message:
            result.failure?.message ?? 'Subtitle provider retrieval failed.',
      );
      _publish(SubtitleProviderRuntimeSnapshot(
        status: SubtitleProviderRuntimeStatus.failed,
        request: _snapshot.request,
        localCandidates: _snapshot.localCandidates,
        providerCandidates: _snapshot.providerCandidates,
        providerFailures: _snapshot.providerFailures,
        handoff: result,
        failures: <SubtitleProviderRuntimeFailure>[failure],
      ));
      return SubtitleProviderActionResult<SubtitleProviderHandoffResult>.failed(
          failure);
    }
    _publish(SubtitleProviderRuntimeSnapshot(
      status: SubtitleProviderRuntimeStatus.ready,
      request: _snapshot.request,
      localCandidates: _snapshot.localCandidates,
      providerCandidates: _snapshot.providerCandidates,
      providerFailures: _snapshot.providerFailures,
      handoff: result,
    ));
    return SubtitleProviderActionResult<SubtitleProviderHandoffResult>.success(
        result);
  }

  Future<SubtitleProviderActionResult<SubtitleParseRequest>>
      prepareParserRequest(SubtitleProviderCandidate candidate) async {
    final SubtitleProviderActionResult<SubtitleProviderHandoffResult> result =
        await prepareProviderSubtitle(candidate);
    final SubtitleParseRequest? parseRequest = result.value?.parseRequest;
    if (!result.isSuccess || parseRequest == null) {
      return SubtitleProviderActionResult<SubtitleParseRequest>.failed(
        result.failure ??
            const SubtitleProviderRuntimeFailure(
                kind: SubtitleProviderRuntimeFailureKind.retrievalFailed,
                message: 'Subtitle parser request is unavailable.'),
      );
    }
    return SubtitleProviderActionResult<SubtitleParseRequest>.success(
        parseRequest);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publish(SubtitleProviderRuntimeSnapshot(
      status: SubtitleProviderRuntimeStatus.disposed,
      request: _snapshot.request,
      localCandidates: _snapshot.localCandidates,
      providerCandidates: _snapshot.providerCandidates,
      providerFailures: _snapshot.providerFailures,
      handoff: _snapshot.handoff,
      failures: const <SubtitleProviderRuntimeFailure>[
        SubtitleProviderRuntimeFailure(
            kind: SubtitleProviderRuntimeFailureKind.disposed,
            message: 'SubtitleProviderRuntime has been disposed.'),
      ],
    ));
    _observers.clear();
  }

  void _publish(SubtitleProviderRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    for (final SubtitleProviderRuntimeObserver observer
        in List<SubtitleProviderRuntimeObserver>.of(_observers)) {
      observer.onSubtitleProviderRuntimeSnapshot(snapshot);
    }
  }

  SubtitleProviderActionResult<T> _disposedResult<T>() {
    return SubtitleProviderActionResult<T>.failed(
      const SubtitleProviderRuntimeFailure(
          kind: SubtitleProviderRuntimeFailureKind.disposed,
          message: 'SubtitleProviderRuntime has been disposed.'),
    );
  }
}

final class SubtitleProviderBootstrap {
  SubtitleProviderBootstrap({
    required SubtitleProvider provider,
    required SubtitleCacheStore cache,
    LocalExternalSubtitleScanner? localScanner,
    DateTime Function()? clock,
  }) : runtime = SubtitleProviderRuntime(
          discovery: DeterministicSubtitleDiscoveryContract(
            provider: provider,
            cache: cache,
            localScanner: localScanner,
            clock: clock,
          ),
        );

  const SubtitleProviderBootstrap.fromDiscovery({required this.runtime});

  final SubtitleProviderRuntime runtime;

  Future<SubtitleProviderActionResult<SubtitleDiscoveryResult>> discover(
          SubtitleDiscoveryRequest request) =>
      runtime.discover(request);

  Future<SubtitleProviderActionResult<SubtitleProviderHandoffResult>>
      prepareProviderSubtitle(SubtitleProviderCandidate candidate) {
    return runtime.prepareProviderSubtitle(candidate);
  }

  Future<SubtitleProviderActionResult<SubtitleParseRequest>>
      prepareParserRequest(SubtitleProviderCandidate candidate) {
    return runtime.prepareParserRequest(candidate);
  }

  void dispose() => runtime.dispose();
}
