import 'package:flutter_test/flutter_test.dart';
import 'package:gantabya/models/offline_region.dart';
import 'package:gantabya/models/place.dart';
import 'package:gantabya/models/track.dart';
import 'package:gantabya/models/trip.dart';
import 'package:gantabya/screens/map/map_controller.dart';
import 'package:gantabya/screens/places/place_form_screen.dart';

import 'helpers.dart';

void main() {
  test('Place survives a map round-trip', () {
    final p = samplePlace(tripId: 't1');
    final back = Place.fromMap(p.toMap());
    expect(back.toMap(), p.toMap());
    expect(back.isVisited, isTrue);
  });

  test('Place.copyWith can clear optional fields', () {
    final p = samplePlace(tripId: 't1');
    final c = p.copyWith(clearTrip: true, clearRating: true);
    expect(c.tripId, isNull);
    expect(c.rating, isNull);
    expect(c.name, p.name);
  });

  test('unknown category falls back to other', () {
    expect(PlaceCategory.fromName('spaceport'), PlaceCategory.other);
  });

  test('Trip, Track and OfflineRegion round-trip', () {
    final trip = sampleTrip();
    expect(Trip.fromMap(trip.toMap()).toMap(), trip.toMap());

    final track = sampleTrack();
    final back = Track.fromMap(track.toMap(), track.points);
    expect(back.toMap(), track.toMap());
    expect(back.points.length, 5);
    expect(back.isRecording, isFalse);
    expect(back.duration, const Duration(hours: 10));

    final region = OfflineRegion(
      id: 'r',
      name: 'Kathmandu',
      south: 27.6,
      west: 85.2,
      north: 27.8,
      east: 85.5,
      minZoom: 5,
      maxZoom: 14,
      tileUrlTemplate: 'https://t/{z}/{x}/{y}.png',
      tileCount: 100,
      downloadedCount: 40,
      status: RegionStatus.paused,
      createdAt: DateTime(2026),
    );
    final r2 = OfflineRegion.fromMap(region.toMap());
    expect(r2.toMap(), region.toMap());
    expect(r2.progress, 0.4);
    expect(r2.contains(27.7, 85.3), isTrue);
    expect(r2.contains(28.7, 85.3), isFalse);
  });

  test('guessCategory maps Google place types', () {
    expect(guessCategory(['restaurant', 'food']), PlaceCategory.food);
    expect(guessCategory(['lodging']), PlaceCategory.stay);
    expect(
      guessCategory(['hindu_temple', 'tourist_attraction']),
      PlaceCategory.temple,
    );
    expect(guessCategory(['locality', 'political']), PlaceCategory.city);
    expect(guessCategory([]), PlaceCategory.other);
  });

  test('zoomForSpan gets smaller as the span grows', () {
    expect(zoomForSpan(0.01, 0.01), greaterThan(zoomForSpan(1, 1)));
    expect(zoomForSpan(1, 1), greaterThan(zoomForSpan(40, 40)));
    expect(zoomForSpan(0, 0), 14);
  });
}
