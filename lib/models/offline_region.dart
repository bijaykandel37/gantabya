import 'package:latlong2/latlong.dart';

enum RegionStatus { downloading, paused, complete, failed }

/// A rectangular area whose map tiles were downloaded for offline use.
class OfflineRegion {
  OfflineRegion({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
    required this.tileUrlTemplate,
    required this.tileCount,
    this.downloadedCount = 0,
    this.failedCount = 0,
    this.sizeBytes = 0,
    this.status = RegionStatus.downloading,
    required this.createdAt,
  });

  final String id;
  String name;
  final double south, west, north, east;
  final int minZoom, maxZoom;
  final String tileUrlTemplate;
  final int tileCount;
  int downloadedCount;
  int failedCount;
  int sizeBytes;
  RegionStatus status;
  final DateTime createdAt;

  double get progress => tileCount == 0 ? 0 : downloadedCount / tileCount;
  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);

  bool contains(double lat, double lng) =>
      lat >= south && lat <= north && lng >= west && lng <= east;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'south': south,
    'west': west,
    'north': north,
    'east': east,
    'min_zoom': minZoom,
    'max_zoom': maxZoom,
    'tile_url': tileUrlTemplate,
    'tile_count': tileCount,
    'downloaded_count': downloadedCount,
    'failed_count': failedCount,
    'size_bytes': sizeBytes,
    'status': status.name,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory OfflineRegion.fromMap(Map<String, Object?> m) => OfflineRegion(
    id: m['id'] as String,
    name: m['name'] as String,
    south: (m['south'] as num).toDouble(),
    west: (m['west'] as num).toDouble(),
    north: (m['north'] as num).toDouble(),
    east: (m['east'] as num).toDouble(),
    minZoom: (m['min_zoom'] as num).toInt(),
    maxZoom: (m['max_zoom'] as num).toInt(),
    tileUrlTemplate: m['tile_url'] as String,
    tileCount: (m['tile_count'] as num).toInt(),
    downloadedCount: (m['downloaded_count'] as num?)?.toInt() ?? 0,
    failedCount: (m['failed_count'] as num?)?.toInt() ?? 0,
    sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
    status: RegionStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => RegionStatus.paused,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (m['created_at'] as num).toInt(),
    ),
  );
}
