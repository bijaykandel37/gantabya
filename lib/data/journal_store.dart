import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/place.dart';
import '../models/track.dart';
import '../models/trip.dart';
import 'database.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// In-memory view of the travel journal (places, trips, tracks), backed by
/// SQLite. Screens listen to this and redraw when anything changes.
class JournalStore extends ChangeNotifier {
  JournalStore(this.db);

  final AppDatabase db;

  List<Place> _places = [];
  List<Trip> _trips = [];
  List<Track> _tracks = [];
  bool _loaded = false;

  List<Place> get places => List.unmodifiable(_places);
  List<Trip> get trips => List.unmodifiable(_trips);
  List<Track> get tracks => List.unmodifiable(_tracks);
  bool get loaded => _loaded;

  List<Place> get visited =>
      _places.where((p) => p.status == PlaceStatus.visited).toList();
  List<Place> get wishlist =>
      _places.where((p) => p.status == PlaceStatus.wishlist).toList();

  Trip? tripById(String? id) {
    if (id == null) return null;
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  Place? placeById(String id) {
    for (final p in _places) {
      if (p.id == id) return p;
    }
    return null;
  }

  Track? trackById(String id) {
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Place> placesForTrip(String tripId) =>
      _places.where((p) => p.tripId == tripId).toList();
  List<Track> tracksForTrip(String tripId) =>
      _tracks.where((t) => t.tripId == tripId).toList();

  Future<void> load() async {
    _trips = await db.trips();
    _places = await db.places();
    _tracks = await db.tracks();
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- places
  Future<void> savePlace(Place place) async {
    await db.upsertPlace(place);
    final i = _places.indexWhere((p) => p.id == place.id);
    if (i >= 0) {
      _places[i] = place;
    } else {
      _places.insert(0, place);
    }
    notifyListeners();
  }

  Future<void> deletePlace(String id) async {
    await db.deletePlace(id);
    _places.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ----------------------------------------------------------------- trips
  Future<void> saveTrip(Trip trip) async {
    await db.upsertTrip(trip);
    final i = _trips.indexWhere((t) => t.id == trip.id);
    if (i >= 0) {
      _trips[i] = trip;
    } else {
      _trips.insert(0, trip);
    }
    notifyListeners();
  }

  Future<void> deleteTrip(String id) async {
    await db.deleteTrip(id);
    _trips.removeWhere((t) => t.id == id);
    // Mirror ON DELETE SET NULL in memory.
    _places = [
      for (final p in _places) p.tripId == id ? p.copyWith(clearTrip: true) : p,
    ];
    _tracks = [
      for (final t in _tracks) t.tripId == id ? t.copyWith(clearTrip: true) : t,
    ];
    notifyListeners();
  }

  // ---------------------------------------------------------------- tracks
  /// Called by the recorder; keeps the in-memory copy in sync.
  void putTrack(Track track) {
    final i = _tracks.indexWhere((t) => t.id == track.id);
    if (i >= 0) {
      _tracks[i] = track;
    } else {
      _tracks.insert(0, track);
    }
    notifyListeners();
  }

  Future<void> saveTrack(Track track) async {
    await db.upsertTrack(track);
    putTrack(track);
  }

  Future<void> deleteTrack(String id) async {
    await db.deleteTrack(id);
    _tracks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ---------------------------------------------------------------- backup
  Future<void> replaceAll({
    required List<Trip> trips,
    required List<Place> places,
    required List<Track> tracks,
  }) async {
    await db.replaceAll(trips: trips, places: places, tracks: tracks);
    await load();
  }
}
