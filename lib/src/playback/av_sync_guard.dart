import 'video_enhancement_pipeline.dart';

final class AVSyncSample {
  const AVSyncSample({
    required this.audioPosition,
    required this.videoPosition,
    required this.renderDelay,
    required this.droppedFrames,
    this.enhancementPressure,
  }) : assert(droppedFrames >= 0, 'droppedFrames must not be negative.');

  final Duration audioPosition;
  final Duration videoPosition;
  final Duration renderDelay;
  final int droppedFrames;
  final RenderBudgetInput? enhancementPressure;

  Duration get absoluteDrift {
    final int difference = audioPosition.inMicroseconds - videoPosition.inMicroseconds;
    return Duration(microseconds: difference.abs());
  }
}

enum AVSyncHealth {
  target,
  warning,
  degraded,
}

enum AVSyncDegradationAction {
  keepCurrentProfile,
  reduceEnhancementIntensity,
  disableAdvancedCaptions,
  disableEnhancementProfile,
}

final class AVSyncPolicy {
  AVSyncPolicy({
    this.targetDrift = const Duration(milliseconds: 40),
    this.degradationDrift = const Duration(milliseconds: 120),
    Iterable<AVSyncDegradationAction> degradationOrder = const <AVSyncDegradationAction>[
      AVSyncDegradationAction.reduceEnhancementIntensity,
      AVSyncDegradationAction.disableAdvancedCaptions,
      AVSyncDegradationAction.disableEnhancementProfile,
    ],
  }) : degradationOrder = List<AVSyncDegradationAction>.unmodifiable(degradationOrder);

  final Duration targetDrift;
  final Duration degradationDrift;
  final List<AVSyncDegradationAction> degradationOrder;
}

final class AVSyncDecision {
  const AVSyncDecision({required this.health, required this.action, required this.reason});

  final AVSyncHealth health;
  final AVSyncDegradationAction action;
  final String reason;
}

abstract interface class AVSyncGuard {
  AVSyncPolicy get policy;

  AVSyncDecision evaluate(AVSyncSample sample);

  Stream<AVSyncDecision> watchDecisions();
}
