import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyStats {
  final int totalDays;
  final int worstAqi;
  final int bestAqi;
  final double avgAqi;
  final int goodDays;
  final int moderateDays;
  final int poorPlusDays;

  const MonthlyStats({
    required this.totalDays,
    required this.worstAqi,
    required this.bestAqi,
    required this.avgAqi,
    required this.goodDays,
    required this.moderateDays,
    required this.poorPlusDays,
  });

  double get cigarettesEquivalent =>
      avgAqi > 22 && totalDays > 0 ? (avgAqi / 22) * totalDays : 0;

  bool get hasData => totalDays >= 2;
}

class StatsService {
  static const _kPrefix = 'monthly_v1_';
  static const _kTodayKey = 'stats_today_v1';

  static String _monthKey() {
    final n = DateTime.now();
    return '$_kPrefix${n.year}_${n.month}';
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> recordDay(int aqi, String catKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateStr(DateTime.now());
      if (prefs.getString(_kTodayKey) == today) return;
      await prefs.setString(_kTodayKey, today);

      final key = _monthKey();
      final raw = prefs.getString(key) ?? '{}';
      final d = json.decode(raw) as Map<String, dynamic>;

      d['days'] = (d['days'] as int? ?? 0) + 1;
      d['sumAqi'] = (d['sumAqi'] as int? ?? 0) + aqi;
      d['worst'] = max(aqi, d['worst'] as int? ?? 0);
      final prevBest = d['best'] as int?;
      d['best'] = prevBest == null ? aqi : min(aqi, prevBest);

      if (catKey == 'GOOD') d['good'] = (d['good'] as int? ?? 0) + 1;
      if (catKey == 'MODERATE') d['mod'] = (d['mod'] as int? ?? 0) + 1;
      if (catKey == 'POOR' || catKey == 'VERY_POOR' || catKey == 'SEVERE') {
        d['poor'] = (d['poor'] as int? ?? 0) + 1;
      }

      await prefs.setString(key, json.encode(d));
    } catch (_) {}
  }

  static Future<MonthlyStats> getMonthlyStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_monthKey()) ?? '{}';
      final d = json.decode(raw) as Map<String, dynamic>;
      final days = d['days'] as int? ?? 0;
      return MonthlyStats(
        totalDays: days,
        worstAqi: d['worst'] as int? ?? 0,
        bestAqi: d['best'] as int? ?? 0,
        avgAqi: days > 0 ? ((d['sumAqi'] as int? ?? 0) / days) : 0,
        goodDays: d['good'] as int? ?? 0,
        moderateDays: d['mod'] as int? ?? 0,
        poorPlusDays: d['poor'] as int? ?? 0,
      );
    } catch (_) {
      return const MonthlyStats(
          totalDays: 0,
          worstAqi: 0,
          bestAqi: 0,
          avgAqi: 0,
          goodDays: 0,
          moderateDays: 0,
          poorPlusDays: 0);
    }
  }

  static int getDailyCounter() {
    final n = DateTime.now();
    final launchBase = DateTime(2025, 6, 1);
    final daysSinceLaunch = n.difference(launchBase).inDays.clamp(0, 730);
    final seed = n.year * 10000 + n.month * 100 + n.day;
    final variance = (seed % 601) - 300;
    return 4800 + (daysSinceLaunch * 28) + variance;
  }
}
