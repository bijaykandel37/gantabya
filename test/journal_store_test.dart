import 'package:flutter_test/flutter_test.dart';
import 'package:gantabya/data/journal_store.dart';
import 'package:gantabya/models/place.dart';
import 'package:gantabya/screens/stats/stats_screen.dart';
import 'package:gantabya/services/backup_service.dart';

import 'helpers.dart';

void main() {
  test('places, trips and tracks persist and reload', () async {
    final db = await openTestDb();
    final store = JournalStore(db);
    await store.load();

    final trip = sampleTrip();
    await store.saveTrip(trip);
    await store.savePlace(samplePlace(tripId: trip.id));
    await store.savePlace(
      samplePlace(
        name: 'Tokyo',
        status: PlaceStatus.wishlist,
        country: 'Japan',
        locality: 'Tokyo',
      ),
    );
    final track = sampleTrack(tripId: trip.id);
    await store.saveTrack(track);
    await db.addTrackPoints(track.id, 0, track.points);

    final reloaded = JournalStore(db);
    await reloaded.load();
    expect(reloaded.places.length, 2);
    expect(reloaded.visited.single.name, 'Pokhara');
    expect(reloaded.wishlist.single.name, 'Tokyo');
    expect(reloaded.placesForTrip(trip.id).length, 1);
    expect(reloaded.tracks.single.points.length, 5);
    expect(reloaded.tracksForTrip(trip.id).length, 1);
  });

  test('deleting a trip keeps its places and journeys, unassigned', () async {
    final db = await openTestDb();
    final store = JournalStore(db);
    final trip = sampleTrip();
    await store.saveTrip(trip);
    await store.savePlace(samplePlace(tripId: trip.id));
    await store.saveTrack(sampleTrack(tripId: trip.id));

    await store.deleteTrip(trip.id);
    expect(store.places.single.tripId, isNull);
    expect(store.tracks.single.tripId, isNull);

    final reloaded = JournalStore(db);
    await reloaded.load();
    expect(reloaded.trips, isEmpty);
    expect(reloaded.places.single.tripId, isNull);
    expect(reloaded.tracks.single.tripId, isNull);
  });

  test('backup export → import restores everything', () async {
    final source = JournalStore(await openTestDb());
    final trip = sampleTrip();
    await source.saveTrip(trip);
    await source.savePlace(samplePlace(tripId: trip.id));
    await source.saveTrack(sampleTrack(tripId: trip.id));
    final json = BackupService.encode(source);

    final target = JournalStore(await openTestDb());
    await target.savePlace(samplePlace(name: 'Will be replaced'));
    final data = BackupService.decode(json);
    await target.replaceAll(
      trips: data.trips,
      places: data.places,
      tracks: data.tracks,
    );

    expect(target.places.single.name, 'Pokhara');
    expect(target.trips.single.name, trip.name);
    expect(target.tracks.single.points.length, 5);
    expect(target.tracks.single.points.last.altitude, 4700);
  });

  test('decode rejects unrelated JSON', () {
    expect(
      () => BackupService.decode('{"app":"other"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('travel stats', () {
    final stats = TravelStats.compute(
      [
        samplePlace(),
        samplePlace(name: 'Lakeside', category: PlaceCategory.food),
        samplePlace(
          name: 'Kyoto',
          country: 'Japan',
          locality: 'Kyoto',
          visitedAt: DateTime(2024, 4, 1),
        ),
        samplePlace(
          name: 'Paris',
          status: PlaceStatus.wishlist,
          country: 'France',
        ),
      ],
      12345,
      2,
      3,
    );
    expect(stats.visited, 3);
    expect(stats.wishlist, 1);
    expect(stats.countries, {'Nepal': 2, 'Japan': 1});
    expect(stats.cities, 2);
    expect(stats.years['2025'], 3); // wishlist sample also has a date
    expect(stats.years['2024'], 1);
    expect(stats.categories.keys.first, 'city');
  });
}
