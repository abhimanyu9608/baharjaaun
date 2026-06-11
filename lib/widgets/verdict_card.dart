import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VerdictCard extends StatefulWidget {
  final String verdict;
  final String healthFact;

  const VerdictCard({
    super.key,
    required this.verdict,
    required this.healthFact,
  });

  @override
  State<VerdictCard> createState() => _VerdictCardState();
}

class _VerdictCardState extends State<VerdictCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  String _displayed = '';

  @override
  void initState() {
    super.initState();
    _displayed = widget.verdict;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(VerdictCard old) {
    super.didUpdateWidget(old);
    if (old.verdict != widget.verdict) {
      _ctrl.reverse().then((_) {
        if (mounted) {
          setState(() => _displayed = widget.verdict);
          _ctrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            offset: const Offset(0, 6),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          const BoxShadow(
            color: Color(0x40000000),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.darkInk.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text('Aaj ka faisla',
                    style: AppTheme.mono(11,
                        color: Colors.grey.shade500,
                        weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),

            // Verdict text — animates on change
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Text(
                  _displayed,
                  style: AppTheme.baloo2(20, color: AppTheme.darkInk),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Dotted divider
            Row(
              children: List.generate(
                24,
                (i) => Expanded(
                  child: Container(
                    height: 1.5,
                    color: i.isEven
                        ? AppTheme.darkInk.withValues(alpha: 0.18)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Health fact
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ℹ️', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.healthFact,
                    style: AppTheme.fredoka(14,
                        color: Colors.grey.shade600,
                        weight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
