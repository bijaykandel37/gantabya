import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/place.dart';
import '../../widgets/format.dart';
import '../home_shell.dart';
import '../map/map_views.dart';
import '../places/place_form_screen.dart';
import 'trip_form_screen.dart';
import 'trips_screen.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  Future<void> _delete(BuildContext context) async {
    final store = context.read<JournalStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text(
          'Places and journeys in this trip are kept, just unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    await store.deleteTrip(tripId);
  }

  Future<void> _addExisting(BuildContext context) async {
    final store = context.read<JournalStore>();
    final candidates = store.places.where((p) => p.tripId != tripId).toList();
    final picked = await showModalBottomSheet<Place>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => candidates.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('All your places are already in this trip.'),
            )
          : ListView(
              children: [
                for (final p in candidates)
                  ListTile(
                    leading: Text(
                      p.category.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.country ?? ''),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
    );
    if (picked != null) await store.savePlace(picked.copyWith(tripId: tripId));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    final trip = store.tripById(tripId);
    if (trip == null) return const Scaffold();
    final places = store.placesForTrip(tripId);
    final tracks = store.tracksForTrip(tripId);
    final km = tracks.fold<double>(0, (s, t) => s + t.distanceMeters);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TripFormScreen(trip: trip),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trip.startDate != null)
                  Text(
                    formatDateRange(trip.startDate, trip.endDate),
                    style: theme.textTheme.titleMedium,
                  ),
                const SizedBox(height: 4),
                Text(
                  '${places.length} places · ${tracks.length} journeys · '
                  '${formatDistance(km)} tracked',
                ),
                if ((trip.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(trip.notes!),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Show on map'),
                      onPressed: () {
                        final shell = HomeShell.of(context);
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        shell?.showOnMap(trip);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('New place'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PlaceFormScreen(initialTripId: tripId),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add existing'),
                      onPressed: () => _addExisting(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _Section('Places'),
          if (places.isEmpty) const ListTile(title: Text('No places yet')),
          for (final p in places)
            ListTile(
              leading: Icon(Icons.location_on, color: placeColor(p)),
              title: Text(p.name),
              subtitle: Text(
                [
                  p.isVisited ? 'Visited' : 'Wishlist',
                  if (p.visitedAt != null) formatDate(p.visitedAt),
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Remove from trip',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => store.savePlace(p.copyWith(clearTrip: true)),
              ),
              onTap: () {
                final shell = HomeShell.of(context);
                Navigator.of(context).popUntil((r) => r.isFirst);
                shell?.showOnMap(p);
              },
            ),
          _Section('GPS journeys'),
          if (tracks.isEmpty)
            const ListTile(
              title: Text('No journeys'),
              subtitle: Text(
                'Start recording from the map and pick this trip.',
              ),
            ),
          for (final t in tracks) TrackTile(track: t),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
