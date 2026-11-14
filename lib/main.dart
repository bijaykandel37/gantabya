import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/journal_store.dart';
import 'services/connectivity_service.dart';
import 'services/offline/offline_maps_manager.dart';
import 'services/offline/region_storage.dart';
import 'services/settings_service.dart';
import 'services/track_recorder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.open();
  final settings = await SettingsService.load();
  final journal = JournalStore(db);
  final offline = OfflineMapsManager(db, await RegionStorage.create());
  await Future.wait([journal.load(), offline.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider.value(value: offline),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => TrackRecorder(journal)),
      ],
      child: const GantabyaApp(),
    ),
  );
}
