import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aqi_category.dart';

const String _kApiKey = '3e9b17867f04fd5281f2dde2c62eb5f7';
const String _kBaseUrl = 'https://api.openweathermap.org/data/2.5';

const int _kCacheMinutes = 45;

class AqiResult {
  final int aqi;
  final AqiCategory category;
  final double pm25;
  final String city;
  final double? tempCelsius;
  final bool fromCache;

  const AqiResult({
    required this.aqi,
    required this.category,
    required this.pm25,
    required this.city,
    this.tempCelsius,
    this.fromCache = false,
  });
}

class AqiService {
  static String _cacheKey(double lat, double lon) {
    final rLat = lat.toStringAsFixed(2);
    final rLon = lon.toStringAsFixed(2);
    return 'aqi_cache_${rLat}_$rLon';
  }

  static Future<AqiResult?> _fromCache(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(lat, lon);
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _kCacheMinutes * 60 * 1000) return null;

      final aqi = map['aqi'] as int;
      return AqiResult(
        aqi: aqi,
        category: categoryForAqi(aqi),
        pm25: (map['pm25'] as num).toDouble(),
        city: map['city'] as String,
        tempCelsius: map['temp'] != null ? (map['temp'] as num).toDouble() : null,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _toCache(double lat, double lon, AqiResult r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(lat, lon);
      final map = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'aqi': r.aqi,
        'pm25': r.pm25,
        'city': r.city,
        if (r.tempCelsius != null) 'temp': r.tempCelsius,
      };
      await prefs.setString(key, json.encode(map));
    } catch (_) {}
  }

  static Future<AqiResult> fetch(double lat, double lon) async {
    final cached = await _fromCache(lat, lon);
    if (cached != null) return cached;

    final airUri = Uri.parse(
        '$_kBaseUrl/air_pollution?lat=$lat&lon=$lon&appid=$_kApiKey');
    final weatherUri = Uri.parse(
        '$_kBaseUrl/weather?lat=$lat&lon=$lon&units=metric&appid=$_kApiKey');

    final responses = await Future.wait([
      http.get(airUri).timeout(const Duration(seconds: 10)),
      http.get(weatherUri).timeout(const Duration(seconds: 10)),
    ]);

    final airRes = responses[0];
    final weatherRes = responses[1];

    if (airRes.statusCode != 200) {
      throw Exception('Air pollution API error: ${airRes.statusCode}');
    }

    final airData = json.decode(airRes.body) as Map<String, dynamic>;
    final components =
        (airData['list'] as List)[0]['components'] as Map<String, dynamic>;
    final pm25 = (components['pm2_5'] as num).toDouble();
    final aqi = pm25ToIndiaAqi(pm25);

    String city = 'Your area';
    double? temp;

    if (weatherRes.statusCode == 200) {
      final wData = json.decode(weatherRes.body) as Map<String, dynamic>;
      city = wData['name'] as String? ?? 'Your area';
      final main = wData['main'] as Map<String, dynamic>?;
      temp = main != null ? (main['temp'] as num?)?.toDouble() : null;
    }

    final result = AqiResult(
      aqi: aqi,
      category: categoryForAqi(aqi),
      pm25: pm25,
      city: city,
      tempCelsius: temp,
    );

    await _toCache(lat, lon, result);
    return result;
  }
}
