import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/offline_region.dart';
import '../../models/place.dart';
import '../../models/track.dart';
import '../../models/trip.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline/offline_maps_manager.dart';
import '../../services/places_search_service.dart';
import '../../services/settings_service.dart';
import '../../services/track_recorder.dart';
import '../../widgets/format.dart';
import '../../widgets/place_sheet.dart';
import '../places/place_form_screen.dart';
import 'map_controller.dart';
import 'map_views.dart';
import 'search_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final controller = UnifiedMapController();
  bool _showVisited = true;
  bool _showWishlist = true;
  bool _showTracks = true;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    // The journal is loaded before runApp, so we can frame all places before
    // the first map build (the map reads its initial camera from controller).
    final places = context.read<JournalStore>().places;
    if (places.isNotEmpty) {
      controller.fit([for (final p in places) p.position]);
    }
  }

  Future<void> _checkPermission() async {
    final perm = await Geolocator.checkPermission();
    final ok =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!mounted) return;
    setState(() => _hasLocationPermission = ok);
    if (ok) _listenMyLocation();
  }

  void _listenMyLocation() => context.read<TrackRecorder>().watchLocation();

  Future<void> _goToMyLocation() async {
    final pos = await TrackRecorder.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      _snack('Could not get your location. Check location permission.');
      return;
    }
    setState(() => _hasLocationPermission = true);
    _listenMyLocation();
    controller.moveTo(LatLng(pos.latitude, pos.longitude), zoom: 15);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Focus a [Place], [Track], [Trip] or [OfflineRegion] (from other tabs).
  void focus(Object target) {
    final store = context.read<JournalStore>();
    switch (target) {
      case Place p:
        controller.moveTo(p.position, zoom: 15);
        _openPlace(p);
      case Track t:
        setState(() => _showTracks = true);
        controller.fit([for (final pt in t.points) pt.position]);
      case Trip trip:
        controller.fit([
          for (final p in store.placesForTrip(trip.id)) p.position,
          for (final t in store.tracksForTrip(trip.id))
            for (final pt in t.points) pt.position,
        ]);
      case OfflineRegion r:
        controller.fit([LatLng(r.south, r.west), LatLng(r.north, r.east)]);
    }
  }

  void _openPlace(Place p) => showPlaceSheet(context, p);

  Future<void> _addPlaceAt(LatLng point, {PlaceSearchResult? from}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlaceFormScreen(initialPosition: point, fromSearch: from),
      ),
    );
  }

  Future<void> _onLongPress(LatLng point) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: const Text('Add a place here'),
              subtitle: Text(formatLatLng(point)),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
          ],
        ),
      ),
    );
    if (action == 'add') await _addPlaceAt(point);
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => SearchScreen(near: controller.center)),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case Place p:
        focus(p);
      case PlaceSearchResult r:
        controller.moveTo(r.position, zoom: 15);
        await _addPlaceAt(r.position, from: r);
    }
  }

  Future<void> _toggleRecording() async {
    final recorder = context.read<TrackRecorder>();
    if (recorder.isRecording) {
      final done = await recorder.stop();
      if (done != null && mounted) {
        _snack('Saved "${done.name}" · ${formatDistance(done.distanceMeters)}');
      }
      return;
    }
    final start = await showDialog<({String name, String? tripId})>(
      context: context,
      builder: (_) => const _StartRecordingDialog(),
    );
    if (start == null || !mounted) return;
    final err = await recorder.start(
      name: start.name,
      tripId: start.tripId,
      distanceFilter: context.read<SettingsService>().trackingDistanceFilter,
    );
    if (err != null) {
      _snack(err);
    } else {
      setState(() {
        _hasLocationPermission = true;
        _showTracks = true;
      });
      _listenMyLocation();
    }
  }

  Future<void> _pickMode() async {
    final settings = context.read<SettingsService>();
    final mode = await showModalBottomSheet<MapMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<MapMode>(
          groupValue: settings.mapMode,
          onChanged: (m) => Navigator.pop(ctx, m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in MapMode.values)
                RadioListTile<MapMode>(
                  value: m,
                  title: Text(m.label),
                  subtitle: Text(switch (m) {
                    MapMode.auto =>
                      'Google Maps online, downloaded maps when offline',
                    MapMode.google => 'Always use Google Maps',
                    MapMode.offline => 'Always use downloaded / tile maps',
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    if (mode != null) settings.mapMode = mode;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    final settings = context.watch<SettingsService>();
    final online = context.watch<ConnectivityService>().isOnline;
    final offline = context.watch<OfflineMapsManager>();
    final recorder = context.watch<TrackRecorder>();

    final useGoogle = switch (settings.mapMode) {
      MapMode.google => true,
      MapMode.offline => false,
      MapMode.auto => online,
    };

    final content = MapContent(
      places: [
        for (final p in store.places)
          if ((p.isVisited && _showVisited) || (!p.isVisited && _showWishlist))
            p,
      ],
      tracks: [
        if (_showTracks)
          ...store.tracks
        else if (recorder.current != null)
          recorder.current!,
      ],
      recordingTrackId: recorder.current?.id,
    );

    final map = useGoogle
        ? GoogleMapView(
            key: const ValueKey('google'),
            controller: controller,
            content: content,
            onPlaceTap: _openPlace,
            onLongPress: _onLongPress,
            myLocationEnabled: _hasLocationPermission,
          )
        : OfflineMapView(
            key: const ValueKey('offline'),
            controller: controller,
            content: content,
            tileUrlTemplate: settings.tileUrlTemplate,
            attribution: settings.tileAttribution,
            storage: offline.storage,
            regions: offline.usableRegions,
            online: online,
            onPlaceTap: _openPlace,
            onLongPress: _onLongPress,
            myLocation: recorder.lastLocation,
          );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: map),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchBar(onTap: _openSearch),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ModeChip(
                          useGoogle: useGoogle,
                          online: online,
                          onTap: _pickMode,
                        ),
                        const SizedBox(width: 6),
                        _ToggleChip(
                          label: 'Visited ${store.visited.length}',
                          color: visitedColor,
                          selected: _showVisited,
                          onSelected: (v) => setState(() => _showVisited = v),
                        ),
                        const SizedBox(width: 6),
                        _ToggleChip(
                          label: 'Wishlist ${store.wishlist.length}',
                          color: wishlistColor,
                          selected: _showWishlist,
                          onSelected: (v) => setState(() => _showWishlist = v),
                        ),
                        const SizedBox(width: 6),
                        _ToggleChip(
                          label: 'Journeys ${store.tracks.length}',
                          color: trackColor,
                          selected: _showTracks,
                          onSelected: (v) => setState(() => _showTracks = v),
                        ),
                      ],
                    ),
                  ),
                  if (!online && !useGoogle && offline.usableRegions.isEmpty)
                    const _InfoBanner(
                      'You are offline and no map regions are downloaded yet. '
                      'Download regions from the Offline tab while connected.',
                    ),
                ],
              ),
            ),
          ),
          if (recorder.current != null)
            Positioned(
              left: 12,
              right: 84,
              bottom: 16,
              child: _RecordingPanel(track: recorder.current!),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'loc',
            tooltip: 'My location',
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'rec',
            tooltip: recorder.isRecording ? 'Stop recording' : 'Record journey',
            backgroundColor: recorder.isRecording ? recordingColor : null,
            foregroundColor: recorder.isRecording ? Colors.white : null,
            onPressed: _toggleRecording,
            child: Icon(
              recorder.isRecording
                  ? Icons.stop_rounded
                  : Icons.fiber_manual_record,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search),
              SizedBox(width: 12),
              Expanded(child: Text('Search places or your journal')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.useGoogle,
    required this.online,
    required this.onTap,
  });
  final bool useGoogle;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        online ? (useGoogle ? Icons.public : Icons.layers) : Icons.cloud_off,
        size: 18,
      ),
      label: Text(
        useGoogle ? 'Google Maps' : (online ? 'Tile map' : 'Offline maps'),
      ),
      onPressed: onTap,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
    );
  }
}

class _RecordingPanel extends StatefulWidget {
  const _RecordingPanel({required this.track});
  final Track track;

  @override
  State<_RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<_RecordingPanel> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: recordingColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${formatDistance(t.distanceMeters)} · '
                    '${formatDuration(t.duration)} · ${t.points.length} pts',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartRecordingDialog extends StatefulWidget {
  const _StartRecordingDialog();

  @override
  State<_StartRecordingDialog> createState() => _StartRecordingDialogState();
}

class _StartRecordingDialogState extends State<_StartRecordingDialog> {
  late final _name = TextEditingController(
    text: 'Journey ${DateFormat('d MMM, HH:mm').format(DateTime.now())}',
  );
  String? _tripId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<JournalStore>().trips;
    return AlertDialog(
      title: const Text('Record a journey'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _tripId,
            decoration: const InputDecoration(labelText: 'Trip (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No trip')),
              for (final t in trips)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _tripId = v),
          ),
          const SizedBox(height: 12),
          Text(
            'Your route is recorded with GPS — even with no internet and with '
            'the screen off. Keep an eye on battery on long treks.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Start'),
          onPressed: () => Navigator.pop(context, (
            name: _name.text.trim().isEmpty ? 'Journey' : _name.text.trim(),
            tripId: _tripId,
          )),
        ),
      ],
    );
  }
}
