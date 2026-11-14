import 'dart:math' as math;

/// Web-Mercator (slippy map) tile helpers.
class TileRange {
  const TileRange(this.zoom, this.minX, this.maxX, this.minY, this.maxY);

  final int zoom;
  final int minX, maxX, minY, maxY;

  int get count => (maxX - minX + 1) * (maxY - minY + 1);

  bool contains(int x, int y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  Iterable<(int, int)> get tiles sync* {
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        yield (x, y);
      }
    }
  }
}

const double _maxLat = 85.05112878;

int lonToTileX(double lon, int zoom) {
  final n = 1 << zoom;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  return x.clamp(0, n - 1);
}

int latToTileY(double lat, int zoom) {
  final n = 1 << zoom;
  final clamped = lat.clamp(-_maxLat, _maxLat);
  final rad = clamped * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) /
              2.0 *
              n)
          .floor();
  return y.clamp(0, n - 1);
}

/// Tile range covering a lat/lng bounding box at [zoom].
TileRange tileRangeFor({
  required double south,
  required double west,
  required double north,
  required double east,
  required int zoom,
}) {
  final x1 = lonToTileX(west, zoom);
  final x2 = lonToTileX(east, zoom);
  final y1 = latToTileY(north, zoom); // north → smaller y
  final y2 = latToTileY(south, zoom);
  return TileRange(
    zoom,
    math.min(x1, x2),
    math.max(x1, x2),
    math.min(y1, y2),
    math.max(y1, y2),
  );
}

List<TileRange> tileRangesFor({
  required double south,
  required double west,
  required double north,
  required double east,
  required int minZoom,
  required int maxZoom,
}) => [
  for (var z = minZoom; z <= maxZoom; z++)
    tileRangeFor(south: south, west: west, north: north, east: east, zoom: z),
];

int countTiles({
  required double south,
  required double west,
  required double north,
  required double east,
  required int minZoom,
  required int maxZoom,
}) => tileRangesFor(
  south: south,
  west: west,
  north: north,
  east: east,
  minZoom: minZoom,
  maxZoom: maxZoom,
).fold(0, (sum, r) => sum + r.count);

const _subdomains = ['a', 'b', 'c'];

/// Fills `{z}/{x}/{y}/{s}` placeholders of an XYZ URL template.
String buildTileUrl(String template, int z, int x, int y) => template
    .replaceAll('{z}', '$z')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y')
    .replaceAll('{s}', _subdomains[(x + y) % _subdomains.length]);
