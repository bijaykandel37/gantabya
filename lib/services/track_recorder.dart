import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/journal_store.dart';
import '../models/track.dart';

/// Owns the app's single GPS stream: it feeds the "you are here" dot on the
/// map and records journeys. Recording keeps running in the background
/// (Android foreground-service notification / iOS background location).
///
/// geolocator shares one native stream per app and ignores the settings of
/// later callers, so everything must go through this class.
class TrackRecorder extends ChangeNotifier {
  TrackRecorder(this._store);

  final JournalStore _store;

  StreamSubscription<Position>? _sub;
  Track? _current;
  final List<TrackPoint> _pending = [];
  int _persistedCount = 0;
  Timer? _flushTimer;
  String? lastError;
  bool _watching = false;
  LatLng? lastLocation;

  Track? get current => _current;
  bool get isRecording => _current != null;

  /// Ensures location services + permission. Returns an error message or null.
  static Future<String?> ensurePermission({bool background = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location services are turned off.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission denied.';
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable it in system '
          'settings.';
    }
    return null;
  }

  static Future<Position?> currentPosition() async {
    if (await ensurePermission() != null) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  LocationSettings _settings(int distanceFilter) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Gantabya is recording your journey',
            notificationText: 'Tap to open. Stop recording from the app.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        );
    }
  }

  Future<String?> start({
    required String name,
    String? tripId,
    int distanceFilter = 15,
  }) async {
    if (isRecording) return null;
    final err = await ensurePermission(background: true);
    if (err != null) {
      lastError = err;
      notifyListeners();
      return err;
    }
    final track = Track(
      id: newId(),
      name: name,
      startedAt: DateTime.now(),
      tripId: tripId,
    );
    _current = track;
    _pending.clear();
    _persistedCount = 0;
    lastError = null;
    await _store.saveTrack(track);

    _sub =
        Geolocator.getPositionStream(
          locationSettings: _settings(distanceFilter),
        ).listen(
          _onPosition,
          onError: (Object e) {
            lastError = e.toString();
            notifyListeners();
          },
        );
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) => _flush());
    notifyListeners();
    return null;
  }

  static const _watchSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20,
  );

  Future<void> _subscribe(LocationSettings settings) async {
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e) {
        lastError = e.toString();
        notifyListeners();
      },
    );
  }

  /// Start following the device location for the map (no recording).
  /// Call after location permission was granted.
  Future<void> watchLocation() async {
    _watching = true;
    if (_sub == null) await _subscribe(_watchSettings);
  }

  void _onPosition(Position pos) {
    lastLocation = LatLng(pos.latitude, pos.longitude);
    final track = _current;
    if (track == null) {
      notifyListeners();
      return;
    }
    // Ignore very inaccurate fixes.
    if (pos.accuracy > 60) return;
    final point = TrackPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
    );
    var distance = track.distanceMeters;
    if (track.points.isNotEmpty) {
      final last = track.points.last;
      distance += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
    }
    _pending.add(point);
    // Append in place: copying the list per fix is O(n²) on long treks.
    track.points.add(point);
    _current = track.copyWith(distanceMeters: distance);
    _store.putTrack(_current!);
    notifyListeners();
  }

  Future<void> _flush() async {
    final track = _current;
    if (track == null || _pending.isEmpty) return;
    final batch = List<TrackPoint>.of(_pending);
    _pending.clear();
    await _store.db.addTrackPoints(track.id, _persistedCount, batch);
    _persistedCount += batch.length;
    await _store.db.upsertTrack(track);
  }

  Future<Track?> stop() async {
    final track = _current;
    if (track == null) return null;
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
    final done = track.copyWith(endedAt: DateTime.now());
    _current = null;
    await _store.saveTrack(done);
    if (_watching) await _subscribe(_watchSettings);
    notifyListeners();
    return done;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}
