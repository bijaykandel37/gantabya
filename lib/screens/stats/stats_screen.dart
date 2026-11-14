import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/place.dart';
import '../../widgets/format.dart';
import '../settings/settings_screen.dart';

/// Pure function so it can be unit-tested.
class TravelStats {
  TravelStats.from(JournalStore store)
    : this.compute(
        store.places,
        store.tracks.fold(0.0, (s, t) => s + t.distanceMeters),
        store.trips.length,
        store.tracks.length,
      );

  TravelStats.compute(
    List<Place> places,
    this.distanceMeters,
    this.trips,
    this.journeys,
  ) : visited = places.where((p) => p.isVisited).length,
      wishlist = places.where((p) => !p.isVisited).length,
      countries = _countBy(
        places.where((p) => p.isVisited && p.country != null),
        (p) => p.country!,
      ),
      cities = places
          .where((p) => p.isVisited && p.locality != null)
          .map((p) => '${p.locality}|${p.country}')
          .toSet()
          .length,
      categories = _countBy(
        places.where((p) => p.isVisited),
        (p) => p.category.name,
      ),
      years = _countBy(
        places.where((p) => p.visitedAt != null),
        (p) => '${p.visitedAt!.year}',
      );

  final int visited;
  final int wishlist;
  final Map<String, int> countries;
  final int cities;
  final Map<String, int> categories;
  final Map<String, int> years;
  final double distanceMeters;
  final int trips;
  final int journeys;

  static Map<String, int> _countBy(
    Iterable<Place> places,
    String Function(Place) key,
  ) {
    final m = <String, int>{};
    for (final p in places) {
      m.update(key(p), (v) => v + 1, ifAbsent: () => 1);
    }
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    final s = TravelStats.from(store);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My travels'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              _Stat('Places visited', '${s.visited}', Icons.place),
              _Stat('Countries', '${s.countries.length}', Icons.flag),
              _Stat('Cities / towns', '${s.cities}', Icons.location_city),
              _Stat('Wishlist', '${s.wishlist}', Icons.star),
              _Stat('Trips', '${s.trips}', Icons.luggage),
              _Stat(
                'GPS distance',
                formatDistance(s.distanceMeters),
                Icons.route,
              ),
            ],
          ),
          if (s.countries.isNotEmpty) ...[
            _Title('Countries'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in s.countries.entries)
                  Chip(label: Text('${e.key} · ${e.value}')),
              ],
            ),
          ],
          if (s.categories.isNotEmpty) ...[
            _Title('What you visit'),
            for (final e in s.categories.entries)
              _Bar(
                label: () {
                  final c = PlaceCategory.fromName(e.key);
                  return '${c.emoji}  ${c.label}';
                }(),
                value: e.value,
                max: s.categories.values.first,
              ),
          ],
          if (s.years.isNotEmpty) ...[
            _Title('Places by year'),
            for (final e
                in (s.years.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key))))
              _Bar(
                label: e.key,
                value: e.value,
                max: s.years.values.reduce((a, b) => a > b ? a : b),
              ),
          ],
          if (s.visited == 0 && s.wishlist == 0)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Your travel stats will appear here as you add places and '
                'record journeys.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max});
  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 10,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('$value', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
