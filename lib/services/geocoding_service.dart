import 'package:geocoding/geocoding.dart';

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.name,
    this.address,
    this.locality,
    this.country,
  });
  final String? name;
  final String? address;
  final String? locality;
  final String? country;
}

/// Uses the platform geocoder (Android Geocoder / iOS CLGeocoder).
/// Needs a connection on most devices; failures are silently ignored so the
/// app keeps working offline.
Future<ReverseGeocodeResult?> reverseGeocode(double lat, double lng) async {
  try {
    final marks = await Geocoding()
        .placemarkFromCoordinates(lat, lng)
        .timeout(const Duration(seconds: 8));
    if (marks.isEmpty) return null;
    final m = marks.first;
    final parts = [
      m.street,
      m.subLocality,
      m.locality,
      m.administrativeArea,
      m.country,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet().toList();
    return ReverseGeocodeResult(
      name: (m.name != null && m.name!.trim().isNotEmpty) ? m.name : m.locality,
      address: parts.join(', '),
      locality: m.locality,
      country: m.country,
    );
  } catch (_) {
    return null;
  }
}
