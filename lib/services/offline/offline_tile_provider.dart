import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/offline_region.dart';
import 'region_storage.dart';
import 'tile_math.dart';

/// Serves tiles from downloaded regions first, then (if allowed) from the
/// network. With no network and no downloaded tile, shows a blank tile.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider({
    required this.storage,
    required this.regions,
    required this.online,
    super.headers,
  });

  final RegionStorage storage;
  final List<OfflineRegion> regions;
  final bool online;

  /// Shares [headers] so the User-Agent set by [TileLayer] is used.
  late final NetworkTileProvider _network = NetworkTileProvider(
    headers: headers,
    silenceExceptions: true,
  );

  File? _findLocal(int z, int x, int y) {
    for (final r in regions) {
      if (z < r.minZoom || z > r.maxZoom) continue;
      final range = tileRangeFor(
        south: r.south,
        west: r.west,
        north: r.north,
        east: r.east,
        zoom: z,
      );
      if (!range.contains(x, y)) continue;
      final f = storage.tileFile(r.id, z, x, y);
      if (f.existsSync()) return f;
    }
    return null;
  }

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final local = _findLocal(coordinates.z, coordinates.x, coordinates.y);
    if (local != null) return FileImage(local);
    if (online) {
      return _network.getImageWithCancelLoadingSupport(
        coordinates,
        options,
        cancelLoading,
      );
    }
    return MemoryImage(transparentPng);
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}

/// 1x1 transparent PNG.
final Uint8List transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
