import 'av_sync_guard.dart';

enum AVSyncSampleReadFailureKind {
  unavailable,
  propertyReadUnavailable,
  invalidPropertyValue,
  backendFailure,
  disposed,
}

final class AVSyncSampleReadFailure implements Exception {
  const AVSyncSampleReadFailure({
    required this.kind,
    required this.message,
  });

  final AVSyncSampleReadFailureKind kind;
  final String message;
}

final class AVSyncSampleReadResult {
  const AVSyncSampleReadResult._({
    this.sample,
    this.failure,
  });

  const AVSyncSampleReadResult.success(AVSyncSample sample)
      : this._(sample: sample);

  const AVSyncSampleReadResult.failure(AVSyncSampleReadFailure failure)
      : this._(failure: failure);

  final AVSyncSample? sample;
  final AVSyncSampleReadFailure? failure;

  bool get isSuccess => failure == null;
}

abstract interface class AVSyncSampleSource {
  Future<AVSyncSampleReadResult> sample();
}
