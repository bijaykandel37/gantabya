import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/offline_region.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline/offline_maps_manager.dart';
import '../../services/settings_service.dart';
import '../../widgets/format.dart';
import '../home_shell.dart';
import '../settings/settings_screen.dart';
import 'region_download_screen.dart';

class OfflineRegionsScreen extends StatelessWidget {
  const OfflineRegionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<OfflineMapsManager>();
    final settings = context.watch<SettingsService>();
    final online = context.watch<ConnectivityService>().isOnline;
    final regions = manager.regions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline maps'),
        actions: [
          IconButton(
            tooltip: 'Map source',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.download),
        label: const Text('Download region'),
        onPressed: online
            ? () {
                final map = HomeShell.globalKey.currentState?.mapController;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RegionDownloadScreen(
                      initialCenter: map?.center,
                      initialZoom: map == null
                          ? null
                          : (map.zoom < 8 ? 9 : map.zoom),
                    ),
                  ),
                );
              }
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map source: ${settings.tilePreset.name}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Download areas while you have internet. With no '
                    'connection the map switches to these downloaded tiles '
                    'automatically, with all your places and journeys on top.',
                  ),
                  const SizedBox(height: 8),
                  Text('Storage used: ${formatBytes(manager.totalBytes)}'),
                  if (!online)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'You are offline — connect to download.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (regions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No offline regions yet.\nTap "Download region" before you '
                'head somewhere without signal.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final r in regions) _RegionTile(region: r),
        ],
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({required this.region});
  final OfflineRegion region;

  Future<void> _rename(BuildContext context) async {
    final manager = context.read<OfflineMapsManager>();
    final ctrl = TextEditingController(text: region.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename region'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) await manager.rename(region.id, name);
  }

  Future<void> _delete(BuildContext context) async {
    final manager = context.read<OfflineMapsManager>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete offline region?'),
        content: Text('Frees ${formatBytes(region.sizeBytes)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await manager.delete(region.id);
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<OfflineMapsManager>();
    final downloading = manager.isDownloading(region.id);
    final online = context.watch<ConnectivityService>().isOnline;
    final statusText = switch (region.status) {
      RegionStatus.downloading =>
        'Downloading ${(region.progress * 100).toStringAsFixed(0)}%',
      RegionStatus.paused => 'Paused',
      RegionStatus.complete => 'Ready offline',
      RegionStatus.failed => '${region.failedCount} tiles failed — tap retry',
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  region.status == RegionStatus.complete
                      ? Icons.offline_pin
                      : Icons.cloud_download_outlined,
                  color: region.status == RegionStatus.complete
                      ? Colors.green
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$statusText · ${formatBytes(region.sizeBytes)} · '
                        'zoom ${region.minZoom}–${region.maxZoom} · '
                        '${formatDate(region.createdAt)}',
                      ),
                    ],
                  ),
                ),
                if (downloading)
                  IconButton(
                    tooltip: 'Pause',
                    icon: const Icon(Icons.pause),
                    onPressed: () => manager.pause(region.id),
                  )
                else if (region.status != RegionStatus.complete)
                  IconButton(
                    tooltip: 'Resume / retry',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: online ? () => manager.start(region.id) : null,
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'map':
                        HomeShell.globalKey.currentState?.showOnMap(region);
                      case 'rename':
                        await _rename(context);
                      case 'delete':
                        await _delete(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'map', child: Text('Show on map')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (region.status != RegionStatus.complete) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: LinearProgressIndicator(value: region.progress),
              ),
              const SizedBox(height: 4),
              Text(
                '${region.downloadedCount} / ${region.tileCount} tiles',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
