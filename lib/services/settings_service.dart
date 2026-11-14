import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Which renderer the main map uses.
enum MapMode {
  /// Google Maps while online, downloaded offline tiles when there is no
  /// connection.
  auto('Automatic'),
  google('Google Maps'),
  offline('Offline tiles');

  const MapMode(this.label);
  final String label;
}

/// A raster tile source used for the offline map.
class TileProviderPreset {
  const TileProviderPreset({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.needsKey,
    required this.allowsBulkDownload,
    this.attribution = '',
    this.help = '',
  });

  final String id;
  final String name;

  /// Use `{z}`, `{x}`, `{y}` and optionally `{s}` (subdomain) and `{key}`.
  final String urlTemplate;
  final bool needsKey;

  /// Whether the app may bulk-download from this source for offline use.
  final bool allowsBulkDownload;
  final String attribution;
  final String help;
}

const tilePresets = <TileProviderPreset>[
  TileProviderPreset(
    id: 'osm',
    name: 'OpenStreetMap (browse only)',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    needsKey: false,
    allowsBulkDownload: false,
    attribution: '© OpenStreetMap contributors',
    help:
        'Free for light, interactive use. The OSM tile usage policy forbids '
        'bulk downloads, so pick a keyed provider below to download regions.',
  ),
  TileProviderPreset(
    id: 'maptiler',
    name: 'MapTiler Streets',
    urlTemplate: 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key={key}',
    needsKey: true,
    allowsBulkDownload: true,
    attribution: '© MapTiler © OpenStreetMap contributors',
    help: 'Free key at maptiler.com (check that your plan allows offline use).',
  ),
  TileProviderPreset(
    id: 'maptiler_outdoor',
    name: 'MapTiler Outdoor (trekking)',
    urlTemplate: 'https://api.maptiler.com/maps/outdoor-v2/256/{z}/{x}/{y}.png?key={key}',
    needsKey: true,
    allowsBulkDownload: true,
    attribution: '© MapTiler © OpenStreetMap contributors',
    help: 'Contours and trails — great for treks.',
  ),
  TileProviderPreset(
    id: 'thunderforest',
    name: 'Thunderforest Outdoors',
    urlTemplate:
        'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey={key}',
    needsKey: true,
    allowsBulkDownload: true,
    attribution: '© Thunderforest © OpenStreetMap contributors',
    help: 'Key at thunderforest.com (check that your plan allows offline use).',
  ),
  TileProviderPreset(
    id: 'custom',
    name: 'Custom tile server',
    urlTemplate: '',
    needsKey: false,
    allowsBulkDownload: true,
    help:
        'Any XYZ raster tile URL you are allowed to download from, e.g. '
        'your own tile server.',
  ),
];

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async =>
      SettingsService(await SharedPreferences.getInstance());

  // ------------------------------------------------------------- map mode
  MapMode get mapMode => MapMode.values.firstWhere(
    (m) => m.name == _prefs.getString('map_mode'),
    orElse: () => MapMode.auto,
  );
  set mapMode(MapMode v) {
    _prefs.setString('map_mode', v.name);
    notifyListeners();
  }

  // -------------------------------------------------------- tile provider
  TileProviderPreset get tilePreset => tilePresets.firstWhere(
    (p) => p.id == _prefs.getString('tile_preset'),
    orElse: () => tilePresets.first,
  );
  set tilePreset(TileProviderPreset v) {
    _prefs.setString('tile_preset', v.id);
    notifyListeners();
  }

  String get tileApiKey => _prefs.getString('tile_key') ?? '';
  set tileApiKey(String v) {
    _prefs.setString('tile_key', v.trim());
    notifyListeners();
  }

  String get customTileUrl => _prefs.getString('tile_custom_url') ?? '';
  set customTileUrl(String v) {
    _prefs.setString('tile_custom_url', v.trim());
    notifyListeners();
  }

  /// Fully resolved tile URL template (`{key}` substituted).
  String get tileUrlTemplate {
    final preset = tilePreset;
    final raw = preset.id == 'custom' ? customTileUrl : preset.urlTemplate;
    if (raw.isEmpty) return tilePresets.first.urlTemplate;
    return raw.replaceAll('{key}', tileApiKey);
  }

  String get tileAttribution => tilePreset.attribution;

  /// Null when downloads are allowed, otherwise the reason they are not.
  String? get downloadBlockedReason {
    final preset = tilePreset;
    if (!preset.allowsBulkDownload) {
      return '${preset.name} does not allow bulk downloads. '
          'Choose a tile provider in Settings first.';
    }
    if (preset.needsKey && tileApiKey.isEmpty) {
      return 'Add your ${preset.name} API key in Settings first.';
    }
    if (preset.id == 'custom' && customTileUrl.isEmpty) {
      return 'Enter your custom tile URL in Settings first.';
    }
    return null;
  }

  // ----------------------------------------------------------- google key
  /// Key used for Google Places search. Defaults to the build-time key.
  String get googleApiKey {
    final override = _prefs.getString('google_key') ?? '';
    return override.isNotEmpty ? override : AppConfig.googleApiKey;
  }

  String get googleApiKeyOverride => _prefs.getString('google_key') ?? '';
  set googleApiKeyOverride(String v) {
    _prefs.setString('google_key', v.trim());
    notifyListeners();
  }

  // ------------------------------------------------------------- tracking
  /// Minimum distance (m) between recorded GPS points.
  int get trackingDistanceFilter => _prefs.getInt('track_filter') ?? 15;
  set trackingDistanceFilter(int v) {
    _prefs.setInt('track_filter', v);
    notifyListeners();
  }
}
