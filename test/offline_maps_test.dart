import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gantabya/models/offline_region.dart';
import 'package:gantabya/services/offline/offline_maps_manager.dart';
import 'package:gantabya/services/offline/offline_tile_provider.dart';
import 'package:gantabya/services/offline/region_storage.dart';
import 'package:gantabya/services/offline/tile_math.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  late RegionStorage storage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gantabya_tiles');
    storage = RegionStorage(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<OfflineRegion> waitDone(OfflineMapsManager m, String id) async {
    for (var i = 0; i < 500 && m.isDownloading(id); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return m.regions.firstWhere((r) => r.id == id);
  }

  const bounds = (south: 27.6, west: 85.2, north: 27.8, east: 85.5);

  test('downloads every tile of a region to disk', () async {
    final requested = <String>[];
    final client = MockClient((req) async {
      requested.add(req.url.toString());
      return http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200);
    });
    final m = OfflineMapsManager(await openTestDb(), storage, client: client);
    await m.load();

    final region = await m.createRegion(
      name: 'Kathmandu',
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      minZoom: 8,
      maxZoom: 12,
      tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
    );
    final done = await waitDone(m, region.id);

    expect(done.status, RegionStatus.complete);
    expect(done.downloadedCount, done.tileCount);
    expect(requested.length, done.tileCount);
    expect(done.sizeBytes, done.tileCount * 4);
    final z12 = tileRangeFor(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      zoom: 12,
    );
    expect(
      storage.tileFile(region.id, 12, z12.minX, z12.minY).existsSync(),
      isTrue,
    );

    // Survives a restart (reloaded from SQLite).
    expect(m.usableRegions.single.id, region.id);
  });

  test('failed tiles mark the region failed; retry skips existing', () async {
    var failOnce = true;
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (failOnce && req.url.path.startsWith('/10/')) {
        return http.Response('nope', 404);
      }
      return http.Response.bytes(Uint8List.fromList([9]), 200);
    });
    final m = OfflineMapsManager(await openTestDb(), storage, client: client);
    final region = await m.createRegion(
      name: 'Test',
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      minZoom: 9,
      maxZoom: 11,
      tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
    );
    var r = await waitDone(m, region.id);
    expect(r.status, RegionStatus.failed);
    expect(r.failedCount, greaterThan(0));

    failOnce = false;
    calls = 0;
    await m.start(region.id);
    r = await waitDone(m, region.id);
    expect(r.status, RegionStatus.complete);
    expect(r.downloadedCount, r.tileCount);
    // Only the previously failed zoom-10 tiles were fetched again.
    expect(
      calls,
      tileRangeFor(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
        zoom: 10,
      ).count,
    );
  });

  test('refuses absurdly large regions', () async {
    final m = OfflineMapsManager(
      await openTestDb(),
      storage,
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(
      () => m.createRegion(
        name: 'World',
        south: -80,
        west: -180,
        north: 80,
        east: 180,
        minZoom: 0,
        maxZoom: 14,
        tileUrlTemplate: 'https://t/{z}/{x}/{y}.png',
      ),
      throwsStateError,
    );
  });

  test('delete removes tiles from disk', () async {
    final m = OfflineMapsManager(
      await openTestDb(),
      storage,
      client: MockClient(
        (_) async => http.Response.bytes(Uint8List.fromList([1]), 200),
      ),
    );
    final region = await m.createRegion(
      name: 'Tmp',
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      minZoom: 6,
      maxZoom: 8,
      tileUrlTemplate: 'https://t/{z}/{x}/{y}.png',
    );
    await waitDone(m, region.id);
    expect(Directory('${tmp.path}/${region.id}').existsSync(), isTrue);
    await m.delete(region.id);
    expect(Directory('${tmp.path}/${region.id}').existsSync(), isFalse);
    expect(m.regions, isEmpty);
  });

  test(
    'tile provider serves downloaded tiles from disk, blank when offline',
    () async {
      final region = OfflineRegion(
        id: 'r1',
        name: 'r',
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
        minZoom: 10,
        maxZoom: 10,
        tileUrlTemplate: 'x',
        tileCount: 1,
        downloadedCount: 1,
        createdAt: DateTime(2026),
      );
      final x = lonToTileX(85.3, 10), y = latToTileY(27.7, 10);
      final f = storage.tileFile('r1', 10, x, y);
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync([1]);

      final provider = OfflineFirstTileProvider(
        storage: storage,
        regions: [region],
        online: false,
      );
      final layer = TileLayer(urlTemplate: 'https://t/{z}/{x}/{y}.png');
      final hit = provider.getImageWithCancelLoadingSupport(
        TileCoordinates(x, y, 10),
        layer,
        Future<void>.value(),
      );
      expect(hit, isA<FileImage>());
      expect((hit as FileImage).file.path, f.path);

      final miss = provider.getImageWithCancelLoadingSupport(
        TileCoordinates(x + 5, y, 10),
        layer,
        Future<void>.value(),
      );
      expect(miss, isA<MemoryImage>());
    },
  );
}
