import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/track.dart';
import '../../widgets/format.dart';
import '../home_shell.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trips & journeys'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Trips (${store.trips.length})'),
              Tab(text: 'GPS journeys (${store.tracks.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('New trip'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TripFormScreen()),
          ),
        ),
        body: TabBarView(
          children: [
            store.trips.isEmpty
                ? const _Empty(
                    'Group places and GPS journeys into trips —\n'
                    'e.g. "Everest Base Camp 2026".',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: store.trips.length,
                    itemBuilder: (context, i) {
                      final t = store.trips[i];
                      final places = store.placesForTrip(t.id).length;
                      final tracks = store.tracksForTrip(t.id);
                      final km = tracks.fold<double>(
                        0,
                        (s, tr) => s + tr.distanceMeters,
                      );
                      return Card(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.luggage),
                          ),
                          title: Text(t.name),
                          subtitle: Text(
                            [
                              if (t.startDate != null)
                                formatDateRange(t.startDate, t.endDate),
                              '$places places',
                              if (tracks.isNotEmpty) formatDistance(km),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TripDetailScreen(tripId: t.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            store.tracks.isEmpty
                ? const _Empty(
                    'No journeys recorded yet.\nTap the red ● button '
                    'on the map to record your route with GPS.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: store.tracks.length,
                    itemBuilder: (context, i) =>
                        TrackTile(track: store.tracks[i]),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track});
  final Track track;

  Future<void> _rename(BuildContext context) async {
    final store = context.read<JournalStore>();
    final ctrl = TextEditingController(text: track.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename journey'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) {
      await store.saveTrack(track.copyWith(name: name));
    }
  }

  Future<void> _assignTrip(BuildContext context) async {
    final store = context.read<JournalStore>();
    final tripId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add to trip'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('No trip'),
          ),
          for (final t in store.trips)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text(t.name),
            ),
        ],
      ),
    );
    if (tripId == null) return;
    await store.saveTrack(
      tripId.isEmpty
          ? track.copyWith(clearTrip: true)
          : track.copyWith(tripId: tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<JournalStore>();
    final trip = store.tripById(track.tripId);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: track.isRecording ? Colors.red.shade100 : null,
        child: Icon(
          track.isRecording ? Icons.fiber_manual_record : Icons.route,
          color: track.isRecording ? Colors.red : null,
        ),
      ),
      title: Text(track.name),
      subtitle: Text(
        [
          formatDate(track.startedAt),
          formatDistance(track.distanceMeters),
          formatDuration(track.duration),
          if (trip != null) '🧳 ${trip.name}',
        ].join(' · '),
      ),
      onTap: () {
        final shell = HomeShell.of(context);
        Navigator.of(context).popUntil((r) => r.isFirst);
        shell?.showOnMap(track);
      },
      trailing: track.isRecording
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'rename':
                    await _rename(context);
                  case 'trip':
                    await _assignTrip(context);
                  case 'delete':
                    await store.deleteTrack(track.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'trip', child: Text('Add to trip')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
    );
  }
}
