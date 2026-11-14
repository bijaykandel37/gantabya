import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/offline_region.dart';
import '../models/place.dart';
import '../models/track.dart';
import '../models/trip.dart';

/// Thin SQLite layer. Everything the app knows lives on the device.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// Pass [path] (e.g. [inMemoryDatabasePath]) to override the location.
  static Future<AppDatabase> open({
    String name = 'gantabya.db',
    String? path,
  }) async {
    path ??= p.join(await getDatabasesPath(), name);
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE trips (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            notes TEXT,
            start_date INTEGER,
            end_date INTEGER,
            created_at INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE places (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            status TEXT NOT NULL,
            category TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address TEXT,
            locality TEXT,
            country TEXT,
            notes TEXT,
            rating INTEGER,
            visited_at INTEGER,
            trip_id TEXT REFERENCES trips(id) ON DELETE SET NULL,
            google_place_id TEXT,
            created_at INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            trip_id TEXT REFERENCES trips(id) ON DELETE SET NULL,
            distance_m REAL NOT NULL DEFAULT 0
          )''');
        batch.execute('''
          CREATE TABLE track_points (
            track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
            seq INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            ts INTEGER NOT NULL,
            altitude REAL,
            accuracy REAL,
            speed REAL,
            PRIMARY KEY (track_id, seq)
          )''');
        batch.execute('''
          CREATE TABLE offline_regions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            south REAL NOT NULL,
            west REAL NOT NULL,
            north REAL NOT NULL,
            east REAL NOT NULL,
            min_zoom INTEGER NOT NULL,
            max_zoom INTEGER NOT NULL,
            tile_url TEXT NOT NULL,
            tile_count INTEGER NOT NULL,
            downloaded_count INTEGER NOT NULL DEFAULT 0,
            failed_count INTEGER NOT NULL DEFAULT 0,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''');
        batch.execute('CREATE INDEX idx_places_trip ON places(trip_id)');
        batch.execute('CREATE INDEX idx_tracks_trip ON tracks(trip_id)');
        await batch.commit(noResult: true);
      },
    );
    return AppDatabase._(db);
  }

  // ---------------------------------------------------------------- places
  Future<List<Place>> places() async {
    final rows = await _db.query('places', orderBy: 'created_at DESC');
    return rows.map(Place.fromMap).toList();
  }

  Future<void> upsertPlace(Place place) => _db.insert(
    'places',
    place.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> deletePlace(String id) =>
      _db.delete('places', where: 'id = ?', whereArgs: [id]);

  // ----------------------------------------------------------------- trips
  Future<List<Trip>> trips() async {
    final rows = await _db.query(
      'trips',
      orderBy: 'COALESCE(start_date, created_at) DESC',
    );
    return rows.map(Trip.fromMap).toList();
  }

  Future<void> upsertTrip(Trip trip) => _db.insert(
    'trips',
    trip.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> deleteTrip(String id) =>
      _db.delete('trips', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- tracks
  Future<List<Track>> tracks() async {
    final rows = await _db.query('tracks', orderBy: 'started_at DESC');
    final pointRows = await _db.query(
      'track_points',
      orderBy: 'track_id, seq ASC',
    );
    final byTrack = <String, List<TrackPoint>>{};
    for (final r in pointRows) {
      (byTrack[r['track_id'] as String] ??= []).add(TrackPoint.fromMap(r));
    }
    return rows
        .map((r) => Track.fromMap(r, byTrack[r['id'] as String] ?? const []))
        .toList();
  }

  Future<void> upsertTrack(Track track) => _db.insert(
    'tracks',
    track.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> addTrackPoints(
    String trackId,
    int firstSeq,
    List<TrackPoint> points,
  ) async {
    final batch = _db.batch();
    for (var i = 0; i < points.length; i++) {
      batch.insert(
        'track_points',
        points[i].toMap(trackId, firstSeq + i),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTrack(String id) =>
      _db.delete('tracks', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------- offline regions
  Future<List<OfflineRegion>> regions() async {
    final rows = await _db.query('offline_regions', orderBy: 'created_at DESC');
    return rows.map(OfflineRegion.fromMap).toList();
  }

  Future<void> upsertRegion(OfflineRegion region) => _db.insert(
    'offline_regions',
    region.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> deleteRegion(String id) =>
      _db.delete('offline_regions', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- backup
  /// Replaces all journal data (not offline regions) in one transaction.
  Future<void> replaceAll({
    required List<Trip> trips,
    required List<Place> places,
    required List<Track> tracks,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete('track_points');
      await txn.delete('tracks');
      await txn.delete('places');
      await txn.delete('trips');
      final batch = txn.batch();
      for (final t in trips) {
        batch.insert('trips', t.toMap());
      }
      for (final pl in places) {
        batch.insert('places', pl.toMap());
      }
      for (final tr in tracks) {
        batch.insert('tracks', tr.toMap());
        for (var i = 0; i < tr.points.length; i++) {
          batch.insert('track_points', tr.points[i].toMap(tr.id, i));
        }
      }
      await batch.commit(noResult: true);
    });
  }
}
