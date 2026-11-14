import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/place.dart';
import '../../widgets/format.dart';
import '../home_shell.dart';
import '../map/map_views.dart';
import 'place_form_screen.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  String _filter = '';
  PlaceCategory? _category;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Place> _apply(List<Place> list) {
    final q = _filter.toLowerCase();
    return list
        .where((p) => _category == null || p.category == _category)
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              (p.country ?? '').toLowerCase().contains(q) ||
              (p.address ?? '').toLowerCase().contains(q) ||
              (p.notes ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    final visited = _apply(store.visited)
      ..sort(
        (a, b) =>
            (b.visitedAt ?? b.createdAt).compareTo(a.visitedAt ?? a.createdAt),
      );
    final wishlist = _apply(store.wishlist);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My places'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.filter_list),
                          hintText: 'Filter by name, country, notes…',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _filter = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<PlaceCategory?>(
                      tooltip: 'Category',
                      icon: Icon(
                        _category == null
                            ? Icons.category_outlined
                            : Icons.category,
                      ),
                      onSelected: (c) => setState(() => _category = c),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: null, child: Text('All')),
                        for (final c in PlaceCategory.values)
                          PopupMenuItem(
                            value: c,
                            child: Text('${c.emoji}  ${c.label}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'Been there (${visited.length})'),
                  Tab(text: 'Want to go (${wishlist.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add place'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaceFormScreen(
              initialStatus: _tabs.index == 0
                  ? PlaceStatus.visited
                  : PlaceStatus.wishlist,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PlaceList(
            places: visited,
            empty:
                'No visited places yet.\nLong-press the map or tap + to add '
                'where you have been.',
          ),
          _PlaceList(
            places: wishlist,
            empty:
                'Your bucket list is empty.\nSearch the map for '
                'destinations you dream of.',
          ),
        ],
      ),
    );
  }
}

class _PlaceList extends StatelessWidget {
  const _PlaceList({required this.places, required this.empty});
  final List<Place> places;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty, textAlign: TextAlign.center),
        ),
      );
    }
    final store = context.read<JournalStore>();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: places.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final p = places[i];
        final trip = store.tripById(p.tripId);
        final subtitle = [
          if (p.locality != null) p.locality!,
          if (p.country != null) p.country!,
          if (p.visitedAt != null) formatDate(p.visitedAt),
          if (trip != null) '🧳 ${trip.name}',
        ].join(' · ');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: placeColor(p).withValues(alpha: 0.15),
            child: Text(p.category.emoji),
          ),
          title: Text(p.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlaceFormScreen(place: p),
              ),
            ),
          ),
          onTap: () => HomeShell.of(context)?.showOnMap(p),
        );
      },
    );
  }
}
