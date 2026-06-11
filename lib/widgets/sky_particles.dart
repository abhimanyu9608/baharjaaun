import 'dart:math';
import 'package:flutter/material.dart';
import '../models/aqi_category.dart';

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double delay;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.delay,
  });
}

class SkyParticles extends StatefulWidget {
  final AqiCategory category;
  final bool isRaining;

  const SkyParticles({
    super.key,
    required this.category,
    this.isRaining = false,
  });

  @override
  State<SkyParticles> createState() => _SkyParticlesState();
}

class _SkyParticlesState extends State<SkyParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  late List<_Particle> _rainDrops;
  final _random = Random();

  int get _smogCount {
    switch (widget.category.key) {
      case 'GOOD':
        return 8;
      case 'SATISFACTORY':
        return 14;
      case 'MODERATE':
        return 20;
      case 'POOR':
        return 40;
      case 'VERY_POOR':
        return 55;
      default:
        return 70;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _buildParticles();
  }

  void _buildParticles() {
    _particles = List.generate(_smogCount, (_) => _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: 2.0 + _random.nextDouble() * 5,
          speed: 0.04 + _random.nextDouble() * 0.08,
          opacity: 0.08 + _random.nextDouble() * 0.22,
          delay: _random.nextDouble(),
        ));
    _rainDrops = List.generate(30, (_) => _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: 1.2,
          speed: 0.35 + _random.nextDouble() * 0.2,
          opacity: 0.5 + _random.nextDouble() * 0.3,
          delay: _random.nextDouble(),
        ));
  }

  @override
  void didUpdateWidget(SkyParticles old) {
    super.didUpdateWidget(old);
    if (old.category.key != widget.category.key) {
      _buildParticles();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.expand();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context2, child2) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            rainDrops: widget.isRaining ? _rainDrops : [],
            progress: _controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final List<_Particle> rainDrops;
  final double progress;

  _ParticlePainter({
    required this.particles,
    required this.rainDrops,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final smogPaint = Paint();
    for (final p in particles) {
      final t = (progress + p.delay) % 1.0;
      final y = size.height * (p.y - t * p.speed * 3) % size.height;
      final x = size.width * p.x;
      smogPaint.color = Colors.white.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(x, y), p.size, smogPaint);
    }

    final rainPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final d in rainDrops) {
      final t = (progress + d.delay) % 1.0;
      final y = size.height * (t * d.speed * 4 % 1.0);
      final x = size.width * d.x;
      rainPaint.color = const Color(0xFFADD8E6).withValues(alpha: d.opacity);
      canvas.drawLine(Offset(x, y), Offset(x - 2, y + 14), rainPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
