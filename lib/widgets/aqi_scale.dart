import 'package:flutter/material.dart';
import '../models/aqi_category.dart';
import '../theme/app_theme.dart';

class AqiScale extends StatelessWidget {
  const AqiScale({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('AQI ka matlab?',
                  style: AppTheme.baloo2(17, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Text('India AQI 0–500 · CPCB scale · based on PM2.5',
              style: AppTheme.mono(10, color: Colors.white54)),
          const SizedBox(height: 14),
          ...kAllCategories.map((cat) => _ScaleRow(cat: cat)),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  final AqiCategory cat;
  const _ScaleRow({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cat.bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: cat.bgColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(cat.label,
                style: AppTheme.fredoka(14.5,
                    weight: FontWeight.w600, color: Colors.white)),
          ),
          Text('${cat.min}–${cat.max}',
              style: AppTheme.mono(11.5, color: Colors.white60)),
        ],
      ),
    );
  }
}
