import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlay renderer projects visible comments into a Matrix4 frame', () {
    final MatrixDanmakuOverlayRenderer renderer = MatrixDanmakuOverlayRenderer(
      captionRenderer: _captionRenderer(_matrix()),
      capabilityMatrix: _matrix(),
    );

    final MatrixDanmakuOverlayRenderResult result = renderer.renderFrame(
      frame: DanmakuRenderFrame(
        clock: const PlayerClockSnapshot(
          position: Duration(seconds: 12),
          isPlaying: true,
          playbackSpeed: 1,
        ),
        lanes: <DanmakuRenderLane>[
          DanmakuRenderLane(
            mode: DanmakuMode.scrolling,
            comments: const <DanmakuComment>[
              DanmakuComment(
                id: DanmakuCommentId('comment-1'),
                timestamp: Duration(seconds: 10),
                text: 'matrix hello',
                mode: DanmakuMode.scrolling,
                colorArgb: 0xFFFFFFFF,
              ),
            ],
          ),
        ],
      ),
      transform: _identityTransform(),
      profile: _profile(),
    );

    expect(result.isSuccess, isTrue);
    expect(result.frame!.rendererSource,
        matrixDanmakuFlutterOverlayRendererSource);
    expect(result.frame!.renderedCommentCount, 1);
    expect(result.frame!.comments.single.text, 'matrix hello');
  });

  test('overlay renderer rejects disabled profile and unsupported capability',
      () {
    final MatrixDanmakuOverlayRenderer disabledRenderer =
        MatrixDanmakuOverlayRenderer(
      captionRenderer: _captionRenderer(_matrix()),
      capabilityMatrix: _matrix(),
    );
    final MatrixDanmakuOverlayRenderResult disabled =
        disabledRenderer.renderFrame(
      frame: _emptyFrame(),
      transform: _identityTransform(),
      profile: _profile(matrixDanmakuEnabled: false),
    );

    expect(disabled.isSuccess, isFalse);
    expect(
      disabled.failure!.kind,
      MatrixDanmakuOverlayFailureKind.featureDisabled,
    );

    final MatrixDanmakuOverlayRenderer unsupportedRenderer =
        MatrixDanmakuOverlayRenderer(
      captionRenderer: _captionRenderer(_matrix(matrixSupported: false)),
      capabilityMatrix: _matrix(matrixSupported: false),
    );
    final MatrixDanmakuOverlayRenderResult unsupported =
        unsupportedRenderer.renderFrame(
      frame: _emptyFrame(),
      transform: _identityTransform(),
      profile: _profile(),
    );

    expect(unsupported.isSuccess, isFalse);
    expect(
      unsupported.failure!.kind,
      MatrixDanmakuOverlayFailureKind.capabilityUnsupported,
    );
  });

  test('capability probe marks Matrix4 danmaku supported only with renderer',
      () {
    final _FakeProbeSource source = _FakeProbeSource(_matrix());

    final PlaybackCapabilityProbeSnapshot supported =
        MatrixDanmakuOverlayCapabilityProbeSource(
      delegate: source,
      rendererAvailable: true,
    ).currentCapabilityProbe;

    expect(
      supported.capabilities.supports(PlaybackCapability.matrixDanmaku),
      isTrue,
    );
    expect(
      supported.details['matrixDanmakuRenderer'],
      matrixDanmakuFlutterOverlayRendererSource,
    );

    final PlaybackCapabilityProbeSnapshot unavailable =
        MatrixDanmakuOverlayCapabilityProbeSource(
      delegate: source,
      rendererAvailable: false,
    ).currentCapabilityProbe;

    expect(
      unavailable.capabilities.supports(PlaybackCapability.matrixDanmaku),
      isFalse,
    );
    expect(unavailable.details['matrixDanmakuRenderer'], 'unavailable');
  });
}

DanmakuRenderFrame _emptyFrame() {
  return DanmakuRenderFrame(
    clock: const PlayerClockSnapshot(
      position: Duration.zero,
      isPlaying: true,
      playbackSpeed: 1,
    ),
    lanes: <DanmakuRenderLane>[
      DanmakuRenderLane(
        mode: DanmakuMode.scrolling,
        comments: const <DanmakuComment>[],
      ),
    ],
  );
}

CaptionTransform4 _identityTransform() {
  return CaptionTransform4.identity();
}

AdvancedCaptionProfile _profile({bool matrixDanmakuEnabled = true}) {
  return AdvancedCaptionProfile(
    id: const AdvancedCaptionProfileId('profile'),
    label: 'Profile',
    matrixDanmakuEnabled: matrixDanmakuEnabled,
    dualSubtitlesEnabled: true,
    pgsRenderingEnabled: true,
    assEnhancementEnabled: true,
  );
}

DeterministicAdvancedCaptionRenderer _captionRenderer(
  PlaybackCapabilityMatrix matrix,
) {
  return DeterministicAdvancedCaptionRenderer(
    captionStore: DeterministicAdvancedCaptionStore(),
    capabilityMatrix: matrix,
    profile: _profile(),
  );
}

PlaybackCapabilityMatrix _matrix({bool matrixSupported = true}) {
  return PlaybackCapabilityMatrix(
    capabilities: <PlaybackCapability, CapabilityStatus>{
      PlaybackCapability.danmakuRendering: const CapabilityStatus.supported(),
      PlaybackCapability.matrixDanmaku: matrixSupported
          ? const CapabilityStatus.supported()
          : const CapabilityStatus.unsupported(
              'Matrix renderer missing.',
            ),
      PlaybackCapability.dualSubtitles: const CapabilityStatus.supported(),
      PlaybackCapability.pgsSubtitleRendering:
          const CapabilityStatus.supported(),
      PlaybackCapability.assSubtitleEnhancement:
          const CapabilityStatus.supported(),
    },
  );
}

final class _FakeProbeSource implements PlaybackCapabilityProbeSource {
  const _FakeProbeSource(this.capabilities);

  final PlaybackCapabilityMatrix capabilities;

  @override
  PlaybackCapabilityProbeSnapshot get currentCapabilityProbe {
    return PlaybackCapabilityProbeSnapshot(
      capabilities: capabilities,
      checkedAt: DateTime.utc(2026, 6, 27),
      source: 'fake',
      backendLabel: 'fake-backend',
    );
  }
}
