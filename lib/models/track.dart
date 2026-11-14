import 'package:latlong2/latlong.dart';

class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? accuracy;
  final double? speed;

  LatLng get position => LatLng(latitude, longitude);

  Map<String, Object?> toMap(String trackId, int seq) => {
    'track_id': trackId,
    'seq': seq,
    'latitude': latitude,
    'longitude': longitude,
    'ts': timestamp.millisecondsSinceEpoch,
    'altitude': altitude,
    'accuracy': accuracy,
    'speed': speed,
  };

  factory TrackPoint.fromMap(Map<String, Object?> m) => TrackPoint(
    latitude: (m['latitude'] as num).toDouble(),
    longitude: (m['longitude'] as num).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
    altitude: (m['altitude'] as num?)?.toDouble(),
    accuracy: (m['accuracy'] as num?)?.toDouble(),
    speed: (m['speed'] as num?)?.toDouble(),
  );
}

/// A recorded GPS journey.
class Track {
  Track({
    required this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.tripId,
    this.distanceMeters = 0,
    List<TrackPoint>? points,
  }) : points = points ?? [];

  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? tripId;
  final double distanceMeters;
  final List<TrackPoint> points;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
  bool get isRecording => endedAt == null;

  Track copyWith({
    String? name,
    DateTime? endedAt,
    String? tripId,
    bool clearTrip = false,
    double? distanceMeters,
    List<TrackPoint>? points,
  }) => Track(
    id: id,
    name: name ?? this.name,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    tripId: clearTrip ? null : (tripId ?? this.tripId),
    distanceMeters: distanceMeters ?? this.distanceMeters,
    points: points ?? this.points,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'started_at': startedAt.millisecondsSinceEpoch,
    'ended_at': endedAt?.millisecondsSinceEpoch,
    'trip_id': tripId,
    'distance_m': distanceMeters,
  };

  factory Track.fromMap(
    Map<String, Object?> m, [
    List<TrackPoint> points = const [],
  ]) => Track(
    id: m['id'] as String,
    name: m['name'] as String,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (m['started_at'] as num).toInt(),
    ),
    endedAt: m['ended_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((m['ended_at'] as num).toInt()),
    tripId: m['trip_id'] as String?,
    distanceMeters: (m['distance_m'] as num?)?.toDouble() ?? 0,
    points: List.of(points),
  );
}
