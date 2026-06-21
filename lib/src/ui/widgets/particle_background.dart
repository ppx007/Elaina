import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({
    super.key,
    this.particleCount = 50,
    this.colors = const <Color>[
      Color(0xFF00FBFB),
      Color(0xFFFF2A5F),
      Color(0xFFFCE442),
      Color(0xFFC678DD),
    ],
  });

  final int particleCount;
  final List<Color> colors;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = <_Particle>[];
  final math.Random _random = math.Random();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.repeat();
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.particleCount != widget.particleCount &&
        !_lastSize.isEmpty) {
      _initParticles(_lastSize);
      return;
    }
    if (!_sameColors(oldWidget.colors, widget.colors)) {
      _remapParticleColors();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_createParticle(size));
    }
  }

  void _remapParticleColors() {
    for (final _Particle particle in _particles) {
      particle.color = _nextParticleColor();
    }
  }

  _Particle _createParticle(Size size) {
    return _Particle(
      x: _random.nextDouble() * size.width,
      y: _random.nextDouble() * size.height,
      size: _random.nextDouble() * 3 + 1,
      speedX: _random.nextDouble() * 1 - 0.5,
      speedY: _random.nextDouble() * 1 - 0.5,
      color: _nextParticleColor(),
      opacity: _random.nextDouble() * 0.5 + 0.1,
    );
  }

  Color _nextParticleColor() {
    if (widget.colors.isEmpty) return Colors.transparent;
    return widget.colors[_random.nextInt(widget.colors.length)];
  }

  void _updateParticles(Size size) {
    if (size.isEmpty) return;

    for (int i = 0; i < _particles.length; i++) {
      final _Particle p = _particles[i];
      p.x += p.speedX;
      p.y += p.speedY;

      if (p.size > 0.2) {
        p.size -= 0.01;
      }

      // Respawn
      if (p.x < 0 ||
          p.x > size.width ||
          p.y < 0 ||
          p.y > size.height ||
          p.size <= 0.2) {
        _particles[i] = _createParticle(size);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size currentSize =
            Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastSize != currentSize) {
          _lastSize = currentSize;
          _initParticles(currentSize);
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              particles: _particles,
              updateParticles: _updateParticles,
              repaint: _controller,
            ),
          ),
        );
      },
    );
  }
}

bool _sameColors(List<Color> left, List<Color> right) {
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.color,
    required this.opacity,
  });

  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  Color color;
  double opacity;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.updateParticles,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Particle> particles;
  final ValueChanged<Size> updateParticles;

  @override
  void paint(Canvas canvas, Size size) {
    updateParticles(size);
    for (final _Particle p in particles) {
      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.particles != particles ||
        oldDelegate.updateParticles != updateParticles;
  }
}
