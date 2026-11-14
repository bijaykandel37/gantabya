import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File layout: `<app support>/offline_tiles/<regionId>/<z>/<x>/<y>.tile`
class RegionStorage {
  RegionStorage(this.rootDir);

  final Directory rootDir;

  static Future<RegionStorage> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'offline_tiles'));
    await dir.create(recursive: true);
    return RegionStorage(dir);
  }

  String tilePath(String regionId, int z, int x, int y) =>
      p.join(rootDir.path, regionId, '$z', '$x', '$y.tile');

  File tileFile(String regionId, int z, int x, int y) =>
      File(tilePath(regionId, z, x, y));

  Future<void> deleteRegion(String regionId) async {
    final dir = Directory(p.join(rootDir.path, regionId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
