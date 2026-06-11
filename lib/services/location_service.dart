import 'package:geolocator/geolocator.dart';

// TODO: manual city picker enhancement for v2
class LocationResult {
  final double lat;
  final double lon;
  final bool isDefault;

  const LocationResult({
    required this.lat,
    required this.lon,
    required this.isDefault,
  });
}

const double _kDelhiLat = 28.6139;
const double _kDelhiLon = 77.2090;

class LocationService {
  static const LocationResult _delhi = LocationResult(
    lat: _kDelhiLat,
    lon: _kDelhiLon,
    isDefault: true,
  );

  static Future<LocationResult> getLocation() async {
    // Hard outer timeout — Chrome on HTTP often silently stalls geolocation
    return _getLocationInner().timeout(
      const Duration(seconds: 8),
      onTimeout: () => _delhi,
    );
  }

  static Future<LocationResult> _getLocationInner() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (!serviceEnabled) return _delhi;

      var permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3),
              onTimeout: () => LocationPermission.denied);

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 6),
                onTimeout: () => LocationPermission.denied);
        if (permission == LocationPermission.denied) return _delhi;
      }
      if (permission == LocationPermission.deniedForever) return _delhi;

      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 6), onTimeout: () {
        throw TimeoutException('Location timed out');
      });

      return LocationResult(
        lat: pos.latitude,
        lon: pos.longitude,
        isDefault: false,
      );
    } catch (_) {
      return _delhi;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
