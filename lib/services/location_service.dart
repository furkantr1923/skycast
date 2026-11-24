import 'package:geolocator/geolocator.dart';

import '../core/failure.dart';

/// Cihaz konumu. Yalnızca uygulama açıkken, kullanıcı izin verirse ve
/// orta doğrulukta istenir; arka planda konum takibi yapılmaz.
class LocationService {
  const LocationService();

  Future<({double lat, double lon})> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const AppFailure(FailureKind.locationDisabled, source: 'Konum');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw const AppFailure(FailureKind.permissionDenied, source: 'Konum');
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
        );
        return (lat: pos.latitude, lon: pos.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return (lat: last.latitude, lon: last.longitude);
        rethrow;
      }
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure(FailureKind.locationDisabled, source: 'Konum', detail: '$e');
    }
  }
}
