import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aqi_category.dart';

const String _kApiKey = '3e9b17867f04fd5281f2dde2c62eb5f7';
const String _kBaseUrl = 'https://api.openweathermap.org/data/2.5';
const int _kCacheMinutes = 45;
const int _kForecastCacheMinutes = 180;

class AqiComponents {
  final double pm25;
  final double pm10;
  final double co;
  final double no2;
  final double o3;
  final double so2;
  final double nh3;

  const AqiComponents({
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.o3,
    required this.so2,
    required this.nh3,
  });
}

class AqiResult {
  final int aqi;
  final AqiCategory category;
  final double pm25;
  final String city;
  final double? tempCelsius;
  final double? windSpeed; // m/s
  final int? humidity;     // %
  final bool fromCache;
  final AqiComponents? components;

  const AqiResult({
    required this.aqi,
    required this.category,
    required this.pm25,
    required this.city,
    this.tempCelsius,
    this.windSpeed,
    this.humidity,
    this.fromCache = false,
    this.components,
  });
}

class HourlyForecast {
  final int hour;  // 0–23 local time
  final int aqi;
  const HourlyForecast({required this.hour, required this.aqi});
}

class ForecastResult {
  final int tomorrowAqi;
  final AqiCategory tomorrowCategory;
  final String comparison; // 'BETTER', 'WORSE', 'SIMILAR'
  final List<HourlyForecast> todayHours;
  final bool fromCache;

  const ForecastResult({
    required this.tomorrowAqi,
    required this.tomorrowCategory,
    required this.comparison,
    this.todayHours = const [],
    this.fromCache = false,
  });
}

/// Returns the pollutant key most elevated above its safe threshold, or null.
String? findVillainKey(AqiComponents? c) {
  if (c == null) return null;
  final ratios = {
    'PM2.5': c.pm25 / 60.0,
    'PM10': c.pm10 / 100.0,
    'NO2': c.no2 / 80.0,
    'O3': c.o3 / 100.0,
    'SO2': c.so2 / 80.0,
    'CO': c.co / 10000.0,
    'NH3': c.nh3 / 200.0,
  };
  final max = ratios.entries.reduce((a, b) => a.value > b.value ? a : b);
  return max.value >= 1.0 ? max.key : null;
}

class AqiService {
  static String _cacheKey(double lat, double lon) {
    final rLat = lat.toStringAsFixed(2);
    final rLon = lon.toStringAsFixed(2);
    return 'aqi_cache_${rLat}_$rLon';
  }

  static String _forecastCacheKey(double lat, double lon) {
    final rLat = lat.toStringAsFixed(2);
    final rLon = lon.toStringAsFixed(2);
    return 'forecast_cache2_${rLat}_$rLon';
  }

  // ── Current AQI cache ─────────────────────────────────────────────────────

  static Future<AqiResult?> _fromCache(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(lat, lon));
      if (raw == null) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _kCacheMinutes * 60 * 1000) return null;

      final aqi = map['aqi'] as int;
      AqiComponents? components;
      if (map['comp'] != null) {
        final c = map['comp'] as Map<String, dynamic>;
        components = AqiComponents(
          pm25: (c['pm25'] as num).toDouble(),
          pm10: (c['pm10'] as num).toDouble(),
          co: (c['co'] as num).toDouble(),
          no2: (c['no2'] as num).toDouble(),
          o3: (c['o3'] as num).toDouble(),
          so2: (c['so2'] as num).toDouble(),
          nh3: (c['nh3'] as num).toDouble(),
        );
      }

      return AqiResult(
        aqi: aqi,
        category: categoryForAqi(aqi),
        pm25: (map['pm25'] as num).toDouble(),
        city: map['city'] as String,
        tempCelsius: map['temp'] != null ? (map['temp'] as num).toDouble() : null,
        windSpeed: map['wind'] != null ? (map['wind'] as num).toDouble() : null,
        humidity: map['hum'] as int?,
        fromCache: true,
        components: components,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _toCache(double lat, double lon, AqiResult r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        'ts': DateTime.now().millisecondsSinceEpoch,
        'aqi': r.aqi,
        'pm25': r.pm25,
        'city': r.city,
        if (r.tempCelsius != null) 'temp': r.tempCelsius,
        if (r.windSpeed != null) 'wind': r.windSpeed,
        if (r.humidity != null) 'hum': r.humidity,
        if (r.components != null) 'comp': {
          'pm25': r.components!.pm25,
          'pm10': r.components!.pm10,
          'co': r.components!.co,
          'no2': r.components!.no2,
          'o3': r.components!.o3,
          'so2': r.components!.so2,
          'nh3': r.components!.nh3,
        },
      };
      await prefs.setString(_cacheKey(lat, lon), json.encode(map));
    } catch (_) {}
  }

  static Future<AqiResult> fetch(double lat, double lon) async {
    final cached = await _fromCache(lat, lon);
    if (cached != null) return cached;

    final airUri = Uri.parse('$_kBaseUrl/air_pollution?lat=$lat&lon=$lon&appid=$_kApiKey');
    final weatherUri = Uri.parse('$_kBaseUrl/weather?lat=$lat&lon=$lon&units=metric&appid=$_kApiKey');

    final responses = await Future.wait([
      http.get(airUri).timeout(const Duration(seconds: 10)),
      http.get(weatherUri).timeout(const Duration(seconds: 10)),
    ]);

    final airRes = responses[0];
    final weatherRes = responses[1];

    if (airRes.statusCode != 200) throw Exception('Air pollution API error: ${airRes.statusCode}');

    final airData = json.decode(airRes.body) as Map<String, dynamic>;
    final comp = (airData['list'] as List)[0]['components'] as Map<String, dynamic>;
    final pm25 = (comp['pm2_5'] as num).toDouble();
    final aqi = pm25ToIndiaAqi(pm25);

    final components = AqiComponents(
      pm25: pm25,
      pm10: (comp['pm10'] as num?)?.toDouble() ?? 0,
      co: (comp['co'] as num?)?.toDouble() ?? 0,
      no2: (comp['no2'] as num?)?.toDouble() ?? 0,
      o3: (comp['o3'] as num?)?.toDouble() ?? 0,
      so2: (comp['so2'] as num?)?.toDouble() ?? 0,
      nh3: (comp['nh3'] as num?)?.toDouble() ?? 0,
    );

    String city = 'Your area';
    double? temp;
    double? windSpeed;
    int? humidity;

    if (weatherRes.statusCode == 200) {
      final wData = json.decode(weatherRes.body) as Map<String, dynamic>;
      city = wData['name'] as String? ?? 'Your area';
      final main = wData['main'] as Map<String, dynamic>?;
      temp = main != null ? (main['temp'] as num?)?.toDouble() : null;
      humidity = main != null ? (main['humidity'] as int?) : null;
      final wind = wData['wind'] as Map<String, dynamic>?;
      windSpeed = wind != null ? (wind['speed'] as num?)?.toDouble() : null;
    }

    final result = AqiResult(
      aqi: aqi,
      category: categoryForAqi(aqi),
      pm25: pm25,
      city: city,
      tempCelsius: temp,
      windSpeed: windSpeed,
      humidity: humidity,
      components: components,
    );

    await _toCache(lat, lon, result);
    return result;
  }

  // ── Forecast (3-hr cache, tomorrow's AQI + today's remaining hours) ───────

  static Future<ForecastResult?> fetchForecast(
      double lat, double lon, int todayAqi) async {
    final cached = await _forecastFromCache(lat, lon);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse('$_kBaseUrl/air_pollution/forecast?lat=$lat&lon=$lon&appid=$_kApiKey');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final list = data['list'] as List;
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      // Tomorrow's entries → average AQI
      final tomorrowEntries = list.where((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch((e['dt'] as int) * 1000);
        return dt.day == tomorrow.day && dt.month == tomorrow.month;
      }).toList();

      if (tomorrowEntries.isEmpty) return null;

      final avgPm25 = tomorrowEntries
              .map((e) => (e['components']['pm2_5'] as num).toDouble())
              .reduce((a, b) => a + b) /
          tomorrowEntries.length;

      final tomorrowAqi = pm25ToIndiaAqi(avgPm25);
      final tomorrowCat = categoryForAqi(tomorrowAqi);
      final diff = tomorrowAqi - todayAqi;
      final comparison = diff > 30 ? 'WORSE' : diff < -30 ? 'BETTER' : 'SIMILAR';

      // Today's remaining hours (current + future hours today)
      final todayHours = list
          .where((e) {
            final dt = DateTime.fromMillisecondsSinceEpoch((e['dt'] as int) * 1000);
            return dt.day == now.day && dt.month == now.month && dt.hour >= now.hour;
          })
          .map((e) {
            final dt = DateTime.fromMillisecondsSinceEpoch((e['dt'] as int) * 1000);
            final pm = (e['components']['pm2_5'] as num).toDouble();
            return HourlyForecast(hour: dt.hour, aqi: pm25ToIndiaAqi(pm));
          })
          .toList();

      final result = ForecastResult(
        tomorrowAqi: tomorrowAqi,
        tomorrowCategory: tomorrowCat,
        comparison: comparison,
        todayHours: todayHours,
      );

      await _forecastToCache(lat, lon, result);
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<ForecastResult?> _forecastFromCache(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_forecastCacheKey(lat, lon));
      if (raw == null) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _kForecastCacheMinutes * 60 * 1000) return null;

      final tomorrowAqi = map['tomorrowAqi'] as int;
      final hoursRaw = map['hours'] as List? ?? [];
      final todayHours = hoursRaw
          .map((e) => HourlyForecast(hour: e['h'] as int, aqi: e['a'] as int))
          .toList();

      return ForecastResult(
        tomorrowAqi: tomorrowAqi,
        tomorrowCategory: categoryForAqi(tomorrowAqi),
        comparison: map['comparison'] as String,
        todayHours: todayHours,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _forecastToCache(double lat, double lon, ForecastResult r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _forecastCacheKey(lat, lon),
        json.encode({
          'ts': DateTime.now().millisecondsSinceEpoch,
          'tomorrowAqi': r.tomorrowAqi,
          'comparison': r.comparison,
          'hours': r.todayHours.map((h) => {'h': h.hour, 'a': h.aqi}).toList(),
        }),
      );
    } catch (_) {}
  }
}
