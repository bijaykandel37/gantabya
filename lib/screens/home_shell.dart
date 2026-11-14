import 'package:material_ui/material_ui.dart';

import 'map/map_controller.dart';
import 'map/map_screen.dart';
import 'offline/offline_regions_screen.dart';
import 'places/places_screen.dart';
import 'stats/stats_screen.dart';
import 'trips/trips_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Lets other screens jump to the map tab and focus something.
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>() ??
      globalKey.currentState;

  static final globalKey = GlobalKey<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _mapKey = GlobalKey<MapScreenState>();

  UnifiedMapController? get mapController => _mapKey.currentState?.controller;

  void showOnMap(Object target) {
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mapKey.currentState?.focus(target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapScreen(key: _mapKey),
      const PlacesScreen(),
      const TripsScreen(),
      const OfflineRegionsScreen(),
      const StatsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Places',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_for_offline_outlined),
            selectedIcon: Icon(Icons.download_for_offline),
            label: 'Offline',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
