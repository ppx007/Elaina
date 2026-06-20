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
    )..addListener(() {
        _updateParticles();
        setState(() {}); // Trigger repaint
      });
    _controller.repeat();
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

  _Particle _createParticle(Size size) {
    return _Particle(
      x: _random.nextDouble() * size.width,
      y: _random.nextDouble() * size.height,
      size: _random.nextDouble() * 3 + 1,
      speedX: _random.nextDouble() * 1 - 0.5,
      speedY: _random.nextDouble() * 1 - 0.5,
      color: widget.colors[_random.nextInt(widget.colors.length)],
      opacity: _random.nextDouble() * 0.5 + 0.1,
    );
  }

  void _updateParticles() {
    if (_lastSize.isEmpty) return;

    for (int i = 0; i < _particles.length; i++) {
      final _Particle p = _particles[i];
      p.x += p.speedX;
      p.y += p.speedY;

      if (p.size > 0.2) {
        p.size -= 0.01;
      }

      // Respawn
      if (p.x < 0 || p.x > _lastSize.width || p.y < 0 || p.y > _lastSize.height || p.size <= 0.2) {
        _particles[i] = _createParticle(_lastSize);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastSize != currentSize) {
          _lastSize = currentSize;
          _initParticles(currentSize);
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(particles: _particles),
          ),
        );
      },
    );
  }
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
  _ParticlePainter({required this.particles});

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Particle p in particles) {
      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
