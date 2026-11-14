import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../services/offline/offline_maps_manager.dart';
import '../../services/offline/tile_math.dart';
import '../../services/settings_service.dart';
import '../settings/settings_screen.dart';

/// Pan/zoom the map so the area you want sits inside the frame, choose the
/// zoom levels, then download.
class RegionDownloadScreen extends StatefulWidget {
  const RegionDownloadScreen({super.key, this.initialCenter, this.initialZoom});

  final LatLng? initialCenter;
  final double? initialZoom;

  @override
  State<RegionDownloadScreen> createState() => _RegionDownloadScreenState();
}

class _RegionDownloadScreenState extends State<RegionDownloadScreen> {
  final _map = fm.MapController();
  final _name = TextEditingController();
  fm.LatLngBounds? _bounds;
  double _zoom = 10;
  RangeValues _zooms = const RangeValues(6, 15);
  bool _zoomsTouched = false;
  bool _starting = false;

  @override
  void dispose() {
    _map.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onCamera(fm.MapCamera camera) {
    setState(() {
      _bounds = camera.visibleBounds;
      _zoom = camera.zoom;
      if (!_zoomsTouched) {
        final z = camera.zoom.floor();
        _zooms = RangeValues(
          (z - 4).clamp(1, 16).toDouble(),
          (z + 4).clamp(z, 17).clamp(1, 17).toDouble(),
        );
      }
    });
  }

  int get _tileCount {
    final b = _bounds;
    if (b == null) return 0;
    return countTiles(
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
      minZoom: _zooms.start.round(),
      maxZoom: _zooms.end.round(),
    );
  }

  Future<void> _download() async {
    final b = _bounds;
    if (b == null) return;
    final settings = context.read<SettingsService>();
    final manager = context.read<OfflineMapsManager>();
    final name = _name.text.trim().isEmpty
        ? 'Region ${manager.regions.length + 1}'
        : _name.text.trim();
    setState(() => _starting = true);
    try {
      await manager.createRegion(
        name: name,
        south: b.south,
        west: b.west,
        north: b.north,
        east: b.east,
        minZoom: _zooms.start.round(),
        maxZoom: _zooms.end.round(),
        tileUrlTemplate: settings.tileUrlTemplate,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final blocked = settings.downloadBlockedReason;
    final count = _tileCount;
    final tooBig = count > AppConfig.maxTilesPerRegion;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Download map region')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                fm.FlutterMap(
                  mapController: _map,
                  options: fm.MapOptions(
                    initialCenter:
                        widget.initialCenter ?? const LatLng(27.9881, 86.9250),
                    initialZoom: widget.initialZoom ?? 10,
                    minZoom: 2,
                    maxZoom: 18,
                    onMapReady: () => _onCamera(_map.camera),
                    onPositionChanged: (camera, _) => _onCamera(camera),
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: settings.tileUrlTemplate,
                      userAgentPackageName: AppConfig.userAgentPackageName,
                    ),
                    if (settings.tileAttribution.isNotEmpty)
                      fm.SimpleAttributionWidget(
                        source: Text(settings.tileAttribution),
                      ),
                  ],
                ),
                // The whole visible map is the selection; draw a frame to say so.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Everything inside the frame will be saved. Zoom: '
                        '${_zoom.toStringAsFixed(1)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Region name',
                      hintText: 'e.g. Pokhara & Annapurna',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zoom levels ${_zooms.start.round()} – ${_zooms.end.round()}'
                    '  (higher = more street detail)',
                    style: theme.textTheme.bodySmall,
                  ),
                  RangeSlider(
                    values: _zooms,
                    min: 1,
                    max: 18,
                    divisions: 17,
                    labels: RangeLabels(
                      '${_zooms.start.round()}',
                      '${_zooms.end.round()}',
                    ),
                    onChanged: (v) => setState(() {
                      _zooms = v;
                      _zoomsTouched = true;
                    }),
                  ),
                  Text(
                    '$count tiles · ~${formatBytes(count * AppConfig.estimatedBytesPerTile)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tooBig ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (tooBig)
                    Text(
                      'Too large (max ${AppConfig.maxTilesPerRegion} tiles). '
                      'Zoom in or lower the max zoom.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  if (blocked != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      blocked,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      child: const Text('Open settings'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Download'),
                    onPressed:
                        blocked != null || tooBig || count == 0 || _starting
                        ? null
                        : _download,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
