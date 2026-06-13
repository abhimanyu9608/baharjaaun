import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const _kHistoryKey = 'aqi_history_v2';
  static const _kLastGoodKey = 'last_good_day_v1';

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> recordAqi(int aqi, String categoryKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateStr(DateTime.now());

      final raw = prefs.getString(_kHistoryKey) ?? '[]';
      final history =
          (json.decode(raw) as List).cast<Map<String, dynamic>>();
      history.removeWhere((e) => e['d'] == today);
      history.add({'d': today, 'a': aqi});
      if (history.length > 7) {
        history.removeRange(0, history.length - 7);
      }
      await prefs.setString(_kHistoryKey, json.encode(history));

      if (categoryKey == 'GOOD') {
        await prefs.setString(_kLastGoodKey, today);
      }
    } catch (_) {}
  }

  static Future<List<int?>> getLast7Days() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey) ?? '[]';
      final history =
          (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      return List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        final ds = _dateStr(d);
        final entry = history.where((e) => e['d'] == ds).firstOrNull;
        return entry?['a'] as int?;
      });
    } catch (_) {
      return List.filled(7, null);
    }
  }

  static Future<int> daysSinceGood() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kLastGoodKey);
      if (s == null) return -1;
      final parts = s.split('-');
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return DateTime.now().difference(d).inDays;
    } catch (_) {
      return -1;
    }
  }
}
