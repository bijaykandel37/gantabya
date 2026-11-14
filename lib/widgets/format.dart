import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

String formatDistance(double meters) => meters < 1000
    ? '${meters.toStringAsFixed(0)} m'
    : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 2 : 1)} km';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

String formatLatLng(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

String formatDate(DateTime? d) => d == null ? '' : DateFormat.yMMMd().format(d);

String formatDateRange(DateTime? a, DateTime? b) {
  if (a == null && b == null) return '';
  if (a != null && b != null) return '${formatDate(a)} – ${formatDate(b)}';
  return formatDate(a ?? b);
}
