import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../data/database.dart';
import '../../data/journal_store.dart' show newId;
import '../../models/offline_region.dart';
import 'region_storage.dart';
import 'tile_math.dart';

class _Job {
  bool cancelled = false;
}

/// Owns the list of offline regions and runs their tile downloads.
///
/// Downloads keep running while you move around the app and can be paused
/// and resumed; already-downloaded tiles are skipped on resume.
class OfflineMapsManager extends ChangeNotifier {
  OfflineMapsManager(this._db, this.storage, {http.Client? client})
    : _clientOverride = client;

  final AppDatabase _db;
  final RegionStorage storage;
  final http.Client? _clientOverride;

  static const int concurrency = 4;
  static const int maxAttempts = 3;

  List<OfflineRegion> _regions = [];
  final Map<String, _Job> _jobs = {};

  List<OfflineRegion> get regions => List.unmodifiable(_regions);

  /// Regions that have at least some tiles on disk.
  List<OfflineRegion> get usableRegions =>
      _regions.where((r) => r.downloadedCount > 0).toList();

  int get totalBytes => _regions.fold(0, (s, r) => s + r.sizeBytes);

  bool isDownloading(String id) => _jobs.containsKey(id);

  Future<void> load() async {
    _regions = await _db.regions();
    // Anything that was mid-download when the app died is now paused.
    for (final r in _regions) {
      if (r.status == RegionStatus.downloading) {
        r.status = RegionStatus.paused;
        await _db.upsertRegion(r);
      }
    }
    notifyListeners();
  }

  Future<OfflineRegion> createRegion({
    required String name,
    required double south,
    required double west,
    required double north,
    required double east,
    required int minZoom,
    required int maxZoom,
    required String tileUrlTemplate,
  }) async {
    final count = countTiles(
      south: south,
      west: west,
      north: north,
      east: east,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    if (count > AppConfig.maxTilesPerRegion) {
      throw StateError(
        'Region too large ($count tiles). '
        'Reduce the area or the maximum zoom.',
      );
    }
    final region = OfflineRegion(
      id: newId(),
      name: name,
      south: south,
      west: west,
      north: north,
      east: east,
      minZoom: minZoom,
      maxZoom: maxZoom,
      tileUrlTemplate: tileUrlTemplate,
      tileCount: count,
      createdAt: DateTime.now(),
    );
    await _db.upsertRegion(region);
    _regions.insert(0, region);
    notifyListeners();
    unawaited(start(region.id));
    return region;
  }

  OfflineRegion? _byId(String id) {
    for (final r in _regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> start(String id) async {
    final region = _byId(id);
    if (region == null || _jobs.containsKey(id)) return;
    final job = _Job();
    _jobs[id] = job;
    region
      ..status = RegionStatus.downloading
      ..downloadedCount = 0
      ..failedCount = 0
      ..sizeBytes = 0;
    notifyListeners();

    final client = _clientOverride ?? http.Client();
    final tiles = <(int, int, int)>[
      for (final range in tileRangesFor(
        south: region.south,
        west: region.west,
        north: region.north,
        east: region.east,
        minZoom: region.minZoom,
        maxZoom: region.maxZoom,
      ))
        for (final (x, y) in range.tiles) (range.zoom, x, y),
    ];
    var next = 0;

    final ticker = Timer.periodic(const Duration(milliseconds: 700), (_) {
      notifyListeners();
    });

    Future<void> worker() async {
      while (!job.cancelled) {
        if (next >= tiles.length) return;
        final (z, x, y) = tiles[next++];
        final file = storage.tileFile(region.id, z, x, y);
        if (await file.exists()) {
          region.downloadedCount++;
          region.sizeBytes += await file.length();
          continue;
        }
        final bytes = await _fetch(
          client,
          buildTileUrl(region.tileUrlTemplate, z, x, y),
          job,
        );
        if (job.cancelled) return;
        if (bytes == null) {
          region.failedCount++;
          continue;
        }
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: false);
        region.downloadedCount++;
        region.sizeBytes += bytes.length;
      }
    }

    try {
      await Future.wait(List.generate(concurrency, (_) => worker()));
    } finally {
      ticker.cancel();
      if (_clientOverride == null) client.close();
      _jobs.remove(id);
    }

    if (_byId(id) == null) return; // deleted while downloading
    if (job.cancelled) {
      region.status = RegionStatus.paused;
    } else if (region.failedCount > 0) {
      region.status = RegionStatus.failed;
    } else {
      region.status = RegionStatus.complete;
    }
    await _db.upsertRegion(region);
    notifyListeners();
  }

  Future<Uint8List?> _fetch(http.Client client, String url, _Job job) async {
    for (var attempt = 1; attempt <= maxAttempts && !job.cancelled; attempt++) {
      try {
        final res = await client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent':
                    '${AppConfig.userAgentPackageName} (offline maps)',
              },
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
        // Client errors (bad key, forbidden, missing) will not get better.
        if (res.statusCode >= 400 &&
            res.statusCode < 500 &&
            res.statusCode != 429) {
          return null;
        }
      } catch (_) {
        // Network error / timeout – retry.
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
    return null;
  }

  void pause(String id) {
    _jobs[id]?.cancelled = true;
  }

  Future<void> rename(String id, String name) async {
    final r = _byId(id);
    if (r == null) return;
    r.name = name;
    await _db.upsertRegion(r);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _jobs[id]?.cancelled = true;
    _regions.removeWhere((r) => r.id == id);
    notifyListeners();
    await _db.deleteRegion(id);
    await storage.deleteRegion(id);
  }

  @override
  void dispose() {
    for (final j in _jobs.values) {
      j.cancelled = true;
    }
    super.dispose();
  }
}

/// Human-readable byte size.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
