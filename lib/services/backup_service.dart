import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/journal_store.dart';
import '../models/place.dart';
import '../models/track.dart';
import '../models/trip.dart';

/// Export / import the whole journal as a single JSON file.
class BackupService {
  static const int formatVersion = 1;

  static String encode(JournalStore store) =>
      const JsonEncoder.withIndent(' ').convert({
        'app': 'gantabya',
        'version': formatVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'trips': [for (final t in store.trips) t.toMap()],
        'places': [for (final pl in store.places) pl.toMap()],
        'tracks': [
          for (final t in store.tracks)
            {
              ...t.toMap(),
              'points': [
                for (var i = 0; i < t.points.length; i++)
                  t.points[i].toMap(t.id, i),
              ],
            },
        ],
      });

  static ({List<Trip> trips, List<Place> places, List<Track> tracks}) decode(
    String json,
  ) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    if (m['app'] != 'gantabya') {
      throw const FormatException('Not a Gantabya backup file.');
    }
    final trips = [
      for (final t in (m['trips'] as List).cast<Map<String, dynamic>>())
        Trip.fromMap(t),
    ];
    final places = [
      for (final pl in (m['places'] as List).cast<Map<String, dynamic>>())
        Place.fromMap(pl),
    ];
    final tracks = [
      for (final t in (m['tracks'] as List).cast<Map<String, dynamic>>())
        Track.fromMap(t, [
          for (final pt
              in ((t['points'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>())
            TrackPoint.fromMap(pt),
        ]),
    ];
    return (trips: trips, places: places, tracks: tracks);
  }

  static Future<void> exportAndShare(JournalStore store) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final file = File(p.join(dir.path, 'gantabya-backup-$stamp.json'));
    await file.writeAsString(encode(store));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Gantabya backup $stamp',
      ),
    );
  }

  /// Returns the number of places imported, or null if cancelled.
  static Future<int?> pickAndImport(JournalStore store) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;
    final data = decode(await picked.xFile.readAsString());
    await store.replaceAll(
      trips: data.trips,
      places: data.places,
      tracks: data.tracks,
    );
    return data.places.length;
  }
}
