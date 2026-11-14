import 'package:latlong2/latlong.dart';

/// Renderer-agnostic camera controller so the map screen can switch between
/// Google Maps and the offline tile map without losing its position.
class UnifiedMapController {
  LatLng center = const LatLng(27.7172, 85.3240); // Kathmandu
  double zoom = 6;

  /// Visible bounds as (south, west, north, east), when known.
  (double, double, double, double)? bounds;

  void Function(LatLng target, double zoom)? _mover;

  void attach(void Function(LatLng target, double zoom) mover) =>
      _mover = mover;
  void detach(void Function(LatLng target, double zoom) mover) {
    if (_mover == mover) _mover = null;
  }

  void moveTo(LatLng target, {double? zoom}) {
    center = target;
    if (zoom != null) this.zoom = zoom;
    _mover?.call(target, this.zoom);
  }

  /// Zooms to fit all [points].
  void fit(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      moveTo(points.first, zoom: 14);
      return;
    }
    var s = points.first.latitude, n = s;
    var w = points.first.longitude, e = w;
    for (final p in points) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    moveTo(LatLng((s + n) / 2, (w + e) / 2), zoom: zoomForSpan(n - s, e - w));
  }
}

/// Very rough zoom level that fits a span (in degrees) on a phone screen.
double zoomForSpan(double latSpan, double lngSpan) {
  final span = (latSpan > lngSpan ? latSpan : lngSpan) * 1.3;
  if (span <= 0) return 14;
  var zoom = 0.0;
  var world = 360.0;
  while (world > span && zoom < 18) {
    world /= 2;
    zoom++;
  }
  return (zoom - 1).clamp(1, 17).toDouble();
}
