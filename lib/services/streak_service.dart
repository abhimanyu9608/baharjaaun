import 'package:shared_preferences/shared_preferences.dart';

class StreakResult {
  final int count;
  final bool isFirstOpenToday;
  const StreakResult({required this.count, required this.isFirstOpenToday});
}

class StreakService {
  static const _kDateKey = 'streak_date';
  static const _kCountKey = 'streak_count';

  static Future<StreakResult> checkAndUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayStr();
      final lastDate = prefs.getString(_kDateKey);
      int count = prefs.getInt(_kCountKey) ?? 0;

      if (lastDate == today) {
        return StreakResult(count: count, isFirstOpenToday: false);
      }

      if (lastDate == null) {
        count = 1;
      } else if (_isYesterday(lastDate)) {
        count += 1;
      } else {
        count = 1;
      }

      await prefs.setString(_kDateKey, today);
      await prefs.setInt(_kCountKey, count);
      return StreakResult(count: count, isFirstOpenToday: true);
    } catch (_) {
      return const StreakResult(count: 0, isFirstOpenToday: false);
    }
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static bool _isYesterday(String dateStr) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    return dateStr == yStr;
  }
}
