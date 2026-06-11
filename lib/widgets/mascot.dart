import 'dart:math';
import 'package:flutter/material.dart';
import '../models/aqi_category.dart';

class Mascot extends StatefulWidget {
  final AqiCategory category;
  final bool isRaining;

  const Mascot({super.key, required this.category, this.isRaining = false});

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late AnimationController _bobController;
  late AnimationController _blinkController;
  late AnimationController _maskController;
  late AnimationController _coughController;
  late AnimationController _sweatController;

  late Animation<double> _bob;
  late Animation<double> _blinkScale;
  late Animation<double> _maskScale;
  late Animation<double> _coughOpacity;
  late Animation<double> _coughY;
  late Animation<double> _sweatY;

  @override
  void initState() {
    super.initState();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _bob = Tween<double>(begin: 0, end: -8)
        .animate(CurvedAnimation(parent: _bobController, curve: Curves.easeInOut));

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _blinkScale = Tween<double>(begin: 1.0, end: 0.05)
        .animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
    _scheduleBlink();

    _maskController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _maskScale = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _maskController, curve: Curves.elasticOut));
    if (widget.category.wearsMask) _maskController.forward();

    _coughController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _coughOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_coughController);
    _coughY = Tween<double>(begin: 0, end: -30)
        .animate(CurvedAnimation(parent: _coughController, curve: Curves.easeOut));
    if (widget.category.coughs) {
      _coughController.repeat(period: const Duration(milliseconds: 2800));
    }

    _sweatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sweatY = Tween<double>(begin: 0, end: 20)
        .animate(CurvedAnimation(parent: _sweatController, curve: Curves.easeIn));
    if (widget.category.isHot && !widget.category.coughs && !widget.isRaining) {
      _sweatController.repeat();
    }
  }

  void _scheduleBlink() async {
    if (!mounted) return;
    if (widget.category.mood == AqiMood.dead) return;
    await Future.delayed(Duration(milliseconds: 2800 + Random().nextInt(1600)));
    if (!mounted) return;
    await _blinkController.forward();
    await _blinkController.reverse();
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(Mascot old) {
    super.didUpdateWidget(old);
    if (old.category.key != widget.category.key) {
      if (widget.category.wearsMask) {
        _maskController.forward();
      } else {
        _maskController.reverse();
      }
      if (widget.category.coughs) {
        _coughController.repeat(period: const Duration(milliseconds: 2800));
        _sweatController.stop();
      } else {
        _coughController.stop();
        _coughController.reset();
        if (widget.category.isHot) {
          _sweatController.repeat();
        } else {
          _sweatController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    _blinkController.dispose();
    _maskController.dispose();
    _coughController.dispose();
    _sweatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced) {
      return _buildStatic();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bobController,
        _blinkController,
        _maskController,
        _coughController,
        _sweatController,
      ]),
      builder: (context2, child2) {
        return Transform.translate(
          offset: Offset(0, _bob.value),
          child: _buildBody(),
        );
      },
    );
  }

  Widget _buildStatic() {
    return _buildBody(staticMode: true);
  }

  Widget _buildBody({bool staticMode = false}) {
    final mood = widget.category.mood;
    final isDead = mood == AqiMood.dead;

    return SizedBox(
      width: 90,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sweat drops
          if (widget.category.isHot && !widget.category.coughs && !staticMode && !widget.isRaining)
            Positioned(
              top: 12,
              right: 10,
              child: Opacity(
                opacity: (sin(_sweatController.value * pi) * 0.9).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, _sweatY.value * 0.3),
                  child: Container(
                    width: 6,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6).withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Cough puff
          if (widget.category.coughs && !staticMode)
            Positioned(
              top: 20,
              right: 2,
              child: Opacity(
                opacity: _coughOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _coughY.value),
                  child: Text('khok!',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),

          // Body (torso)
          Positioned(
            bottom: 10,
            child: Container(
              width: 54,
              height: 58,
              decoration: BoxDecoration(
                color: _shirtColor(),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Left arm
          Positioned(
            bottom: 30,
            left: 4,
            child: Transform.rotate(
              angle: staticMode ? -0.3 : sin(_bobController.value * pi * 2) * 0.25 - 0.3,
              origin: const Offset(8, 0),
              child: Container(
                width: 16,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8BEAC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Right arm
          Positioned(
            bottom: 30,
            right: 4,
            child: Transform.rotate(
              angle: staticMode ? 0.3 : sin(_bobController.value * pi * 2 + pi) * 0.25 + 0.3,
              origin: const Offset(8, 0),
              child: Container(
                width: 16,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8BEAC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Head
          Positioned(
            top: 0,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF5C9A0),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  // Hair
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D2B1F),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  // Eyebrows
                  Positioned(
                    top: 20,
                    left: 10,
                    child: _buildEyebrow(left: true, mood: mood),
                  ),
                  Positioned(
                    top: 20,
                    right: 10,
                    child: _buildEyebrow(left: false, mood: mood),
                  ),

                  // Eyes
                  Positioned(
                    top: 28,
                    left: 11,
                    child: _buildEye(isDead: isDead, staticMode: staticMode),
                  ),
                  Positioned(
                    top: 28,
                    right: 11,
                    child: _buildEye(isDead: isDead, staticMode: staticMode),
                  ),

                  // Mouth (hidden if masked)
                  if (!widget.category.wearsMask || staticMode)
                    Positioned(
                      bottom: 10,
                      left: 14,
                      right: 14,
                      child: ScaleTransition(
                        scale: widget.category.wearsMask
                            ? Tween(begin: 1.0, end: 0.0).animate(_maskController)
                            : const AlwaysStoppedAnimation(1.0),
                        child: _buildMouth(mood),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Mask overlay
          Positioned(
            top: 32,
            child: ScaleTransition(
              scale: staticMode
                  ? AlwaysStoppedAnimation(widget.category.wearsMask ? 1.0 : 0.0)
                  : _maskScale,
              child: Container(
                width: 56,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Center(
                  child: Container(
                    height: 2,
                    width: 36,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyebrow({required bool left, required AqiMood mood}) {
    double rotation = 0;
    if (mood == AqiMood.angry) rotation = left ? 0.4 : -0.4;
    if (mood == AqiMood.sad) rotation = left ? -0.25 : 0.25;
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: const Color(0xFF3D2B1F),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEye({required bool isDead, required bool staticMode}) {
    if (isDead) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(painter: _XEyePainter()),
      );
    }
    final blink = staticMode ? 1.0 : _blinkScale.value;
    return Transform.scale(
      scaleY: blink,
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMouth(AqiMood mood) {
    return CustomPaint(
      size: const Size(34, 16),
      painter: _MouthPainter(mood: mood),
    );
  }

  Color _shirtColor() {
    switch (widget.category.mood) {
      case AqiMood.happy:
        return const Color(0xFF64B5F6);
      case AqiMood.meh:
        return const Color(0xFFFFCC80);
      case AqiMood.sad:
        return const Color(0xFFEF9A9A);
      case AqiMood.angry:
        return const Color(0xFFEF5350);
      case AqiMood.dead:
        return const Color(0xFF90A4AE);
    }
  }
}

class _XEyePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(2, 2), Offset(size.width - 2, size.height - 2), paint);
    canvas.drawLine(Offset(size.width - 2, 2), Offset(2, size.height - 2), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MouthPainter extends CustomPainter {
  final AqiMood mood;
  _MouthPainter({required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (mood) {
      case AqiMood.happy:
        path.moveTo(cx - 12, cy - 2);
        path.quadraticBezierTo(cx, cy + 10, cx + 12, cy - 2);
        break;
      case AqiMood.meh:
        path.moveTo(cx - 10, cy + 2);
        path.lineTo(cx + 10, cy + 2);
        break;
      case AqiMood.sad:
      case AqiMood.angry:
        path.moveTo(cx - 12, cy + 6);
        path.quadraticBezierTo(cx, cy - 4, cx + 12, cy + 6);
        break;
      case AqiMood.dead:
        path.moveTo(cx - 10, cy + 2);
        path.lineTo(cx + 10, cy + 2);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MouthPainter old) => old.mood != mood;
}
