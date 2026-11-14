import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../config.dart';
import '../../models/offline_region.dart';
import '../../models/place.dart';
import '../../models/track.dart';
import '../../services/offline/offline_tile_provider.dart';
import '../../services/offline/region_storage.dart';
import 'map_controller.dart';

const visitedColor = Color(0xFF2E7D32);
const wishlistColor = Color(0xFFEF6C00);
const trackColor = Color(0xFF1565C0);
const recordingColor = Color(0xFFD32F2F);

Color placeColor(Place p) => p.isVisited ? visitedColor : wishlistColor;

/// What every map renderer draws.
class MapContent {
  const MapContent({
    this.places = const [],
    this.tracks = const [],
    this.recordingTrackId,
  });

  final List<Place> places;
  final List<Track> tracks;
  final String? recordingTrackId;
}

typedef PlaceTap = void Function(Place place);
typedef MapLongPress = void Function(LatLng point);

// ------------------------------------------------------------------ Google

class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    super.key,
    required this.controller,
    required this.content,
    this.onPlaceTap,
    this.onLongPress,
    this.myLocationEnabled = false,
  });

  final UnifiedMapController controller;
  final MapContent content;
  final PlaceTap? onPlaceTap;
  final MapLongPress? onLongPress;
  final bool myLocationEnabled;

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  gm.GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_move);
  }

  @override
  void dispose() {
    widget.controller.detach(_move);
    super.dispose();
  }

  void _move(LatLng target, double zoom) {
    _map?.animateCamera(
      gm.CameraUpdate.newLatLngZoom(
        gm.LatLng(target.latitude, target.longitude),
        zoom,
      ),
    );
  }

  Future<void> _updateBounds() async {
    final r = await _map?.getVisibleRegion();
    if (r == null) return;
    widget.controller.bounds = (
      r.southwest.latitude,
      r.southwest.longitude,
      r.northeast.latitude,
      r.northeast.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final markers = <gm.Marker>{
      for (final p in widget.content.places)
        gm.Marker(
          markerId: gm.MarkerId(p.id),
          position: gm.LatLng(p.latitude, p.longitude),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            p.isVisited
                ? gm.BitmapDescriptor.hueGreen
                : gm.BitmapDescriptor.hueOrange,
          ),
          infoWindow: gm.InfoWindow(
            title: '${p.category.emoji} ${p.name}',
            snippet: p.isVisited ? 'Visited' : 'Wishlist',
            onTap: () => widget.onPlaceTap?.call(p),
          ),
        ),
    };
    final polylines = <gm.Polyline>{
      for (final t in widget.content.tracks)
        if (t.points.length > 1)
          gm.Polyline(
            polylineId: gm.PolylineId(t.id),
            points: [
              for (final pt in t.points) gm.LatLng(pt.latitude, pt.longitude),
            ],
            color: t.id == widget.content.recordingTrackId
                ? recordingColor
                : trackColor,
            width: 4,
          ),
    };
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(c.center.latitude, c.center.longitude),
        zoom: c.zoom,
      ),
      onMapCreated: (m) {
        _map = m;
        // Apply any move requested before the native map existed.
        m.moveCamera(
          gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(c.center.latitude, c.center.longitude),
            c.zoom,
          ),
        );
        _updateBounds();
      },
      onCameraMove: (pos) {
        c.center = LatLng(pos.target.latitude, pos.target.longitude);
        c.zoom = pos.zoom;
      },
      onCameraIdle: _updateBounds,
      onLongPress: (p) =>
          widget.onLongPress?.call(LatLng(p.latitude, p.longitude)),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }
}

// ----------------------------------------------------------------- Offline

class OfflineMapView extends StatefulWidget {
  const OfflineMapView({
    super.key,
    required this.controller,
    required this.content,
    required this.tileUrlTemplate,
    required this.storage,
    required this.regions,
    required this.online,
    this.attribution = '',
    this.onPlaceTap,
    this.onLongPress,
    this.myLocation,
    this.extraLayers = const [],
  });

  final UnifiedMapController controller;
  final MapContent content;
  final String tileUrlTemplate;
  final RegionStorage storage;
  final List<OfflineRegion> regions;
  final bool online;
  final String attribution;
  final PlaceTap? onPlaceTap;
  final MapLongPress? onLongPress;
  final LatLng? myLocation;
  final List<Widget> extraLayers;

  @override
  State<OfflineMapView> createState() => _OfflineMapViewState();
}

class _OfflineMapViewState extends State<OfflineMapView> {
  final _map = fm.MapController();
  late OfflineFirstTileProvider _tiles = _makeProvider();

  OfflineFirstTileProvider _makeProvider() => OfflineFirstTileProvider(
    storage: widget.storage,
    regions: widget.regions,
    online: widget.online,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_move);
  }

  @override
  void didUpdateWidget(covariant OfflineMapView old) {
    super.didUpdateWidget(old);
    if (old.online != widget.online ||
        old.regions.length != widget.regions.length ||
        old.tileUrlTemplate != widget.tileUrlTemplate) {
      _tiles = _makeProvider();
    }
  }

  @override
  void dispose() {
    widget.controller.detach(_move);
    _map.dispose();
    super.dispose();
  }

  void _move(LatLng target, double zoom) {
    try {
      _map.move(target, zoom);
    } catch (_) {
      // Map not rendered yet; it will start at controller.center/zoom.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return fm.FlutterMap(
      mapController: _map,
      options: fm.MapOptions(
        initialCenter: c.center,
        initialZoom: c.zoom,
        minZoom: 2,
        maxZoom: 19,
        onLongPress: (_, p) => widget.onLongPress?.call(p),
        onPositionChanged: (camera, _) {
          c.center = camera.center;
          c.zoom = camera.zoom;
          final b = camera.visibleBounds;
          c.bounds = (b.south, b.west, b.north, b.east);
        },
      ),
      children: [
        fm.TileLayer(
          // Key forces a fresh layer when the source/connectivity changes.
          key: ValueKey(
            '${widget.tileUrlTemplate}|${widget.online}|${widget.regions.length}',
          ),
          urlTemplate: widget.tileUrlTemplate,
          userAgentPackageName: AppConfig.userAgentPackageName,
          tileProvider: _tiles,
          maxNativeZoom: 19,
        ),
        fm.PolylineLayer(
          polylines: [
            for (final t in widget.content.tracks)
              if (t.points.length > 1)
                fm.Polyline(
                  points: [for (final pt in t.points) pt.position],
                  color: t.id == widget.content.recordingTrackId
                      ? recordingColor
                      : trackColor,
                  strokeWidth: 4,
                ),
          ],
        ),
        fm.MarkerLayer(
          markers: [
            for (final p in widget.content.places)
              fm.Marker(
                point: p.position,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => widget.onPlaceTap?.call(p),
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: placeColor(p),
                  ),
                ),
              ),
            if (widget.myLocation != null)
              fm.Marker(
                point: widget.myLocation!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ...widget.extraLayers,
        if (widget.attribution.isNotEmpty)
          fm.SimpleAttributionWidget(source: Text(widget.attribution)),
      ],
    );
  }
}
