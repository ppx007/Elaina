import 'advanced_caption_rendering.dart';
import 'av_sync_guard.dart';
import 'capability_matrix.dart';
import 'danmaku/danmaku_event.dart';
import 'danmaku/danmaku_renderer.dart';

const String matrixDanmakuFlutterOverlayRendererSource =
    'flutter-custom-painter-overlay';
const String matrixDanmakuUnsupportedReason =
    'Matrix4 danmaku overlay renderer is not available.';
const String matrixDanmakuBasicDanmakuUnsupportedReason =
    'Matrix4 danmaku requires basic danmaku rendering support.';

final class MatrixDanmakuOverlayComment {
  const MatrixDanmakuOverlayComment({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mode,
    this.colorArgb,
  });

  final DanmakuCommentId id;
  final Duration timestamp;
  final String text;
  final DanmakuMode mode;
  final int? colorArgb;
}

final class MatrixDanmakuOverlayFrame {
  MatrixDanmakuOverlayFrame({
    required this.clockPosition,
    required this.transform,
    required Iterable<MatrixDanmakuOverlayComment> comments,
    required this.rendererSource,
    this.failureReason,
  }) : comments = List<MatrixDanmakuOverlayComment>.unmodifiable(comments);

  final Duration clockPosition;
  final CaptionTransform4 transform;
  final List<MatrixDanmakuOverlayComment> comments;
  final String rendererSource;
  final String? failureReason;

  int get renderedCommentCount => comments.length;

  bool get hasVisibleComments => comments.isNotEmpty;
}

enum MatrixDanmakuOverlayFailureKind {
  capabilityUnsupported,
  featureDisabled,
}

final class MatrixDanmakuOverlayFailure implements Exception {
  const MatrixDanmakuOverlayFailure({
    required this.kind,
    required this.message,
  });

  final MatrixDanmakuOverlayFailureKind kind;
  final String message;
}

final class MatrixDanmakuOverlayRenderResult {
  const MatrixDanmakuOverlayRenderResult._({this.frame, this.failure});

  const MatrixDanmakuOverlayRenderResult.rendered(
      MatrixDanmakuOverlayFrame frame)
      : this._(frame: frame);

  const MatrixDanmakuOverlayRenderResult.rejected(
    MatrixDanmakuOverlayFailure failure,
  ) : this._(failure: failure);

  final MatrixDanmakuOverlayFrame? frame;
  final MatrixDanmakuOverlayFailure? failure;

  bool get isSuccess => failure == null;
}

final class MatrixDanmakuOverlayRenderer implements AdvancedCaptionRenderer {
  MatrixDanmakuOverlayRenderer({
    required this.captionRenderer,
    required this.capabilityMatrix,
    this.rendererSource = matrixDanmakuFlutterOverlayRendererSource,
  });

  final AdvancedCaptionRenderer captionRenderer;
  final PlaybackCapabilityMatrix capabilityMatrix;
  final String rendererSource;

  MatrixDanmakuOverlayRenderResult renderFrame({
    required DanmakuRenderFrame frame,
    required CaptionTransform4 transform,
    required AdvancedCaptionProfile profile,
  }) {
    final CapabilityStatus status =
        capabilityMatrix.statusOf(PlaybackCapability.matrixDanmaku);
    if (!profile.matrixDanmakuEnabled) {
      return const MatrixDanmakuOverlayRenderResult.rejected(
        MatrixDanmakuOverlayFailure(
          kind: MatrixDanmakuOverlayFailureKind.featureDisabled,
          message: 'Matrix4 danmaku is disabled by profile.',
        ),
      );
    }
    if (!status.isSupported) {
      return MatrixDanmakuOverlayRenderResult.rejected(
        MatrixDanmakuOverlayFailure(
          kind: MatrixDanmakuOverlayFailureKind.capabilityUnsupported,
          message: status.reason ?? matrixDanmakuUnsupportedReason,
        ),
      );
    }
    return MatrixDanmakuOverlayRenderResult.rendered(
      MatrixDanmakuOverlayFrame(
        clockPosition: frame.clock.position,
        transform: transform,
        comments: <MatrixDanmakuOverlayComment>[
          for (final DanmakuRenderLane lane in frame.lanes)
            for (final DanmakuComment comment in lane.comments)
              MatrixDanmakuOverlayComment(
                id: comment.id,
                timestamp: comment.timestamp,
                text: comment.text,
                mode: comment.mode,
                colorArgb: comment.colorArgb,
              ),
        ],
        rendererSource: rendererSource,
      ),
    );
  }

  @override
  List<AdvancedCaptionCapability> get capabilities =>
      captionRenderer.capabilities;

  @override
  Future<CaptionEvaluationOutcome> evaluate(AdvancedCaptionProfile profile) {
    return captionRenderer.evaluate(profile);
  }

  @override
  Future<CaptionRenderOutcome> renderMatrixDanmaku(
    MatrixDanmakuRequest request,
  ) {
    return captionRenderer.renderMatrixDanmaku(request);
  }

  @override
  Future<CaptionRenderOutcome> renderDualSubtitles(
    DualSubtitleRequest request,
  ) {
    return captionRenderer.renderDualSubtitles(request);
  }

  @override
  Future<CaptionRenderOutcome> renderAdvancedSubtitle(
    AdvancedSubtitleRequest request,
  ) {
    return captionRenderer.renderAdvancedSubtitle(request);
  }

  @override
  Future<CaptionDisableOutcome> disable() {
    return captionRenderer.disable();
  }

  @override
  Future<CaptionDegradationOutcome> acceptDegradation(
    AVSyncDegradationAction action, {
    required String reason,
  }) {
    return captionRenderer.acceptDegradation(action, reason: reason);
  }
}

final class MatrixDanmakuOverlayCapabilityProbeSource
    implements PlaybackCapabilityProbeSource {
  const MatrixDanmakuOverlayCapabilityProbeSource({
    required this.delegate,
    required this.rendererAvailable,
    this.rendererSource = matrixDanmakuFlutterOverlayRendererSource,
  });

  final PlaybackCapabilityProbeSource delegate;
  final bool rendererAvailable;
  final String rendererSource;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    final PlaybackCapabilityProbeSnapshot base =
        delegate.currentCapabilityProbe;
    final PlaybackCapabilityMatrix baseMatrix = base.capabilities;
    final CapabilityStatus basicDanmaku =
        baseMatrix.statusOf(PlaybackCapability.danmakuRendering);
    final CapabilityStatus matrixStatus = rendererAvailable
        ? (basicDanmaku.isSupported
            ? const CapabilityStatus.supported()
            : CapabilityStatus.unsupported(
                basicDanmaku.reason ??
                    matrixDanmakuBasicDanmakuUnsupportedReason,
              ))
        : const CapabilityStatus.unsupported(matrixDanmakuUnsupportedReason);
    return PlaybackCapabilityProbeSnapshot(
      capabilities: baseMatrix.withCapabilityStatus(
        PlaybackCapability.matrixDanmaku,
        matrixStatus,
      ),
      checkedAt: base.checkedAt,
      source: base.source,
      backendLabel: base.backendLabel,
      cached: base.cached,
      details: <String, String>{
        ...base.details,
        'matrixDanmakuRenderer':
            rendererAvailable ? rendererSource : 'unavailable',
        'matrixDanmakuBasicDanmaku': basicDanmaku.isSupported.toString(),
      },
    );
  }
}
