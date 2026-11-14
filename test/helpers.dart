import 'dart:io';

import 'package:gantabya/data/database.dart';
import 'package:gantabya/data/journal_store.dart';
import 'package:gantabya/models/place.dart';
import 'package:gantabya/models/track.dart';
import 'package:gantabya/models/trip.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiReady = false;

Future<AppDatabase> openTestDb() async {
  if (!_ffiReady) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }
  // A fresh file per call: sqflite shares one ':memory:' instance otherwise.
  final dir = Directory.systemTemp.createTempSync('gantabya_db');
  return AppDatabase.open(path: '${dir.path}/test.db');
}

Place samplePlace({
  String? id,
  String name = 'Pokhara',
  PlaceStatus status = PlaceStatus.visited,
  PlaceCategory category = PlaceCategory.city,
  String? country = 'Nepal',
  String? locality = 'Pokhara',
  String? tripId,
  DateTime? visitedAt,
  double lat = 28.2096,
  double lng = 83.9856,
}) => Place(
  id: id ?? newId(),
  name: name,
  status: status,
  category: category,
  latitude: lat,
  longitude: lng,
  country: country,
  locality: locality,
  tripId: tripId,
  visitedAt: visitedAt ?? DateTime(2025, 10, 3),
  notes: 'Phewa lake at sunrise',
  rating: 5,
  createdAt: DateTime(2025, 10, 3, 12),
);

Trip sampleTrip({String? id, String name = 'Annapurna Circuit'}) => Trip(
  id: id ?? newId(),
  name: name,
  startDate: DateTime(2025, 10, 1),
  endDate: DateTime(2025, 10, 20),
  createdAt: DateTime(2025, 9, 1),
);

Track sampleTrack({String? id, String? tripId}) => Track(
  id: id ?? newId(),
  name: 'Thorong La',
  tripId: tripId,
  startedAt: DateTime(2025, 10, 10, 4),
  endedAt: DateTime(2025, 10, 10, 14),
  distanceMeters: 15400,
  points: [
    for (var i = 0; i < 5; i++)
      TrackPoint(
        latitude: 28.79 + i * 0.001,
        longitude: 83.93 + i * 0.001,
        timestamp: DateTime(2025, 10, 10, 4, i),
        altitude: 4500.0 + i * 50,
      ),
  ],
);
