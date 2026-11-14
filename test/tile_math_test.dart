import 'package:flutter_test/flutter_test.dart';
import 'package:gantabya/services/offline/tile_math.dart';

void main() {
  test('lat/lng to tile matches the slippy-map formula', () {
    expect(lonToTileX(85.3240, 10), 754);
    expect(latToTileY(27.7172, 10), 429);
    expect(lonToTileX(0, 1), 1);
    expect(latToTileY(0, 1), 1);
  });

  test('tile indices are clamped at the edges of the world', () {
    expect(lonToTileX(-180, 2), 0);
    expect(lonToTileX(180, 2), 3);
    expect(latToTileY(89.9, 2), 0);
    expect(latToTileY(-89.9, 2), 3);
  });

  test('tile range and count for a bounding box', () {
    final r = tileRangeFor(
      south: 27.6,
      west: 85.2,
      north: 27.8,
      east: 85.5,
      zoom: 12,
    );
    expect(r.minX, lessThanOrEqualTo(r.maxX));
    expect(r.minY, lessThanOrEqualTo(r.maxY));
    expect(r.count, r.tiles.length);
    expect(r.contains(r.minX, r.minY), isTrue);
    expect(r.contains(r.maxX + 1, r.minY), isFalse);

    final total = countTiles(
      south: 27.6,
      west: 85.2,
      north: 27.8,
      east: 85.5,
      minZoom: 0,
      maxZoom: 12,
    );
    final manual = [
      for (var z = 0; z <= 12; z++)
        tileRangeFor(
          south: 27.6,
          west: 85.2,
          north: 27.8,
          east: 85.5,
          zoom: z,
        ).count,
    ].reduce((a, b) => a + b);
    expect(total, manual);
    // Zoom 0 is always exactly one tile.
    expect(
      countTiles(
        south: 27.6,
        west: 85.2,
        north: 27.8,
        east: 85.5,
        minZoom: 0,
        maxZoom: 0,
      ),
      1,
    );
  });

  test('buildTileUrl fills placeholders', () {
    expect(
      buildTileUrl('https://t/{z}/{x}/{y}.png', 5, 10, 12),
      'https://t/5/10/12.png',
    );
    expect(
      buildTileUrl('https://{s}.t/{z}/{x}/{y}.png', 1, 0, 0),
      'https://a.t/1/0/0.png',
    );
  });
}
