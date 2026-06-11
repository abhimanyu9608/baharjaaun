import 'dart:math';
import 'package:flutter/material.dart';
import '../models/aqi_category.dart';

// Auto-rickshaw, chai glass, pigeon — reactive to AQI category
class SideCast extends StatefulWidget {
  final AqiCategory category;

  const SideCast({super.key, required this.category});

  @override
  State<SideCast> createState() => _SideCastState();
}

class _SideCastState extends State<SideCast> with TickerProviderStateMixin {
  late AnimationController _bobController;
  late AnimationController _wingController;
  late AnimationController _steamController;
  late AnimationController _coughController;

  @override
  void initState() {
    super.initState();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _wingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..repeat(reverse: true);

    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _coughController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.category.coughs) {
      _coughController.repeat(period: const Duration(milliseconds: 2400));
    }
  }

  @override
  void didUpdateWidget(SideCast old) {
    super.didUpdateWidget(old);
    if (old.category.key != widget.category.key) {
      if (widget.category.coughs) {
        _coughController.repeat(period: const Duration(milliseconds: 2400));
      } else {
        _coughController.stop();
        _coughController.reset();
      }
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    _wingController.dispose();
    _steamController.dispose();
    _coughController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bobController,
        _wingController,
        _steamController,
        _coughController,
      ]),
      builder: (context2, child2) {
        return SizedBox(
          width: double.infinity,
          height: 130,
          child: Stack(
            children: [
              // Auto-rickshaw (left)
              Positioned(
                left: 8,
                bottom: reduced ? 20 : 20 + sin(_bobController.value * pi) * 5,
                child: _buildAutoRickshaw(),
              ),
              // Pigeon (upper middle)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(child: _buildPigeon(reduced)),
              ),
              // Chai glass (right)
              Positioned(
                right: 8,
                bottom: reduced ? 18 : 18 + sin(_bobController.value * pi + 1) * 4,
                child: _buildChaiGlass(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoRickshaw() {
    final coughs = widget.category.coughs;
    final coughOpacity = coughs
        ? TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
          ]).evaluate(AlwaysStoppedAnimation(_coughController.value))
        : 0.0;
    final coughY = coughs ? _coughController.value * -20.0 : 0.0;

    return SizedBox(
      width: 90,
      height: 76,
      child: Stack(
        children: [
          // Wheels
          Positioned(
            bottom: 0,
            left: 6,
            child: _buildWheel(),
          ),
          Positioned(
            bottom: 0,
            right: 10,
            child: _buildWheel(),
          ),
          // Body
          Positioned(
            bottom: 12,
            left: 0,
            child: Container(
              width: 90,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Yellow roof
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDD835),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  // Eyes (windshield)
                  Positioned(
                    top: 18,
                    left: 8,
                    child: Row(
                      children: [
                        _autoEye(),
                        const SizedBox(width: 8),
                        _autoEye(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Cough puff
          if (coughs)
            Positioned(
              bottom: 50,
              right: 4,
              child: Opacity(
                opacity: coughOpacity,
                child: Transform.translate(
                  offset: Offset(0, coughY),
                  child: Text('khuk!',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF757575), width: 2),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF9E9E9E),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _autoEye() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildPigeon(bool reduced) {
    final coughs = widget.category.coughs;
    final wingAngle = reduced
        ? 0.2
        : sin(_wingController.value * pi) * 0.45;

    return Opacity(
      opacity: coughs ? 0.6 : 1.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 50,
            height: 38,
            child: Stack(
              children: [
                // Body
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: Container(
                    width: 32,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E9E9E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                // Wing
                Positioned(
                  bottom: 10,
                  left: 6,
                  child: Transform.rotate(
                    angle: -wingAngle,
                    origin: const Offset(0, 6),
                    child: Container(
                      width: 20,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF757575),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                // Head
                Positioned(
                  top: 0,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF757575),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        // Eye
                        Positioned(
                          top: 5,
                          left: 3,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Beak
                        Positioned(
                          top: 7,
                          right: 1,
                          child: Container(
                            width: 7,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8F00),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (coughs)
            Positioned(
              top: -14,
              right: 0,
              child: Text('kaff!',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  )),
            ),
        ],
      ),
    );
  }

  Widget _buildChaiGlass() {
    final steamOpacity =
        (sin(_steamController.value * pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0);
    final steamY = -(_steamController.value * 14);

    return SizedBox(
      width: 46,
      height: 68,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Steam
          Positioned(
            top: 0,
            child: Opacity(
              opacity: steamOpacity,
              child: Transform.translate(
                offset: Offset(0, steamY),
                child: Container(
                  width: 20,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          // Glass body
          Positioned(
            bottom: 0,
            child: Container(
              width: 36,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(color: const Color(0xFF6D4C41), width: 2),
              ),
              child: Stack(
                children: [
                  // Chai color fill
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4873C),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  // Face
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chaiDot(),
                        const SizedBox(width: 6),
                        _chaiDot(),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 8,
                    right: 8,
                    child: CustomPaint(
                      size: const Size(20, 8),
                      painter: _SmilePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chaiDot() {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: Color(0xFF3E2723),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(2, 2);
    path.quadraticBezierTo(size.width / 2, size.height + 2, size.width - 2, 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
