enum VideoScalerIntent {
  adapterDefault,
  sharp,
  smooth,
  animeOptimized,
}

enum HdrHandlingIntent {
  passthrough,
  toneMapToSdr,
  adapterDefault,
}

enum DebandIntent {
  off,
  light,
  medium,
  strong,
}

enum Anime4kPresetIntent {
  off,
  restore,
  upscale,
  restoreAndUpscale,
}

final class EnhancementProfileId {
  const EnhancementProfileId(this.value) : assert(value != '', 'Enhancement profile id must not be empty.');

  final String value;
}

final class VideoEnhancementProfile {
  const VideoEnhancementProfile({
    required this.id,
    required this.label,
    required this.scaler,
    required this.hdrHandling,
    required this.deband,
    required this.anime4kPreset,
  }) : assert(label != '', 'Enhancement profile label must not be empty.');

  final EnhancementProfileId id;
  final String label;
  final VideoScalerIntent scaler;
  final HdrHandlingIntent hdrHandling;
  final DebandIntent deband;
  final Anime4kPresetIntent anime4kPreset;
}

final class RenderBudgetInput {
  const RenderBudgetInput({
    required this.frameBudget,
    required this.estimatedRenderCost,
    required this.droppedFrames,
  }) : assert(droppedFrames >= 0, 'droppedFrames must not be negative.');

  final Duration frameBudget;
  final Duration estimatedRenderCost;
  final int droppedFrames;
}

final class EnhancementCapabilityReport {
  const EnhancementCapabilityReport({required this.profile, required this.supported, this.reason});

  final VideoEnhancementProfile profile;
  final bool supported;
  final String? reason;
}

abstract interface class VideoEnhancementPipeline {
  Future<EnhancementCapabilityReport> evaluate(VideoEnhancementProfile profile);

  Future<void> apply(VideoEnhancementProfile profile);

  Future<void> disable();
}
