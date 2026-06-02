import 'danmaku/danmaku_event.dart';
import 'subtitle/subtitle_source.dart';

enum AdvancedCaptionFeature {
  matrixDanmaku,
  dualSubtitles,
  pgsRendering,
  assEnhancement,
}

final class CaptionTransform4 {
  CaptionTransform4({required Iterable<double> values})
      : assert(values.length == 16, 'Matrix4 transform must contain 16 values.'),
        values = List<double>.unmodifiable(values);

  final List<double> values;
}

final class MatrixDanmakuRequest {
  MatrixDanmakuRequest({required Iterable<DanmakuComment> comments, required this.transform})
      : comments = List<DanmakuComment>.unmodifiable(comments);

  final List<DanmakuComment> comments;
  final CaptionTransform4 transform;
}

final class DualSubtitleRequest {
  const DualSubtitleRequest({required this.primary, required this.secondary});

  final SubtitleSource primary;
  final SubtitleSource secondary;
}

enum AdvancedSubtitleRenderIntent {
  pgsImageSubtitle,
  assEnhancedLayout,
}

final class AdvancedSubtitleRequest {
  const AdvancedSubtitleRequest({required this.source, required this.intent});

  final SubtitleSource source;
  final AdvancedSubtitleRenderIntent intent;
}

final class AdvancedCaptionCapability {
  const AdvancedCaptionCapability({required this.feature, required this.supported, this.reason});

  final AdvancedCaptionFeature feature;
  final bool supported;
  final String? reason;
}

abstract interface class AdvancedCaptionRenderer {
  List<AdvancedCaptionCapability> get capabilities;

  Future<void> renderMatrixDanmaku(MatrixDanmakuRequest request);

  Future<void> renderDualSubtitles(DualSubtitleRequest request);

  Future<void> renderAdvancedSubtitle(AdvancedSubtitleRequest request);
}
