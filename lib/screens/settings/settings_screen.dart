import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../data/journal_store.dart';
import '../../services/backup_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _s = context.read<SettingsService>();
  late final _tileKey = TextEditingController(text: _s.tileApiKey);
  late final _customUrl = TextEditingController(text: _s.customTileUrl);
  late final _googleKey = TextEditingController(text: _s.googleApiKeyOverride);
  bool _busy = false;

  @override
  void dispose() {
    _tileKey.dispose();
    _customUrl.dispose();
    _googleKey.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportAndShare(context.read<JournalStore>());
    } catch (e) {
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This replaces all places, trips and journeys on '
          'this device with the ones in the backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await BackupService.pickAndImport(context.read<JournalStore>());
      if (n != null) _snack('Restored $n places.');
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final preset = s.tilePreset;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Map'),
          RadioGroup<MapMode>(
            groupValue: s.mapMode,
            onChanged: (m) => s.mapMode = m ?? s.mapMode,
            child: Column(
              children: [
                for (final m in MapMode.values)
                  RadioListTile<MapMode>(value: m, title: Text(m.label)),
              ],
            ),
          ),
          const _Header('Offline map source'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: preset.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tile provider'),
                  items: [
                    for (final p in tilePresets)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (id) =>
                      s.tilePreset = tilePresets.firstWhere((p) => p.id == id),
                ),
                const SizedBox(height: 6),
                Text(preset.help, style: theme.textTheme.bodySmall),
                if (preset.needsKey) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tileKey,
                    decoration: InputDecoration(
                      labelText: '${preset.name} API key',
                    ),
                    onChanged: (v) => s.tileApiKey = v,
                  ),
                ],
                if (preset.id == 'custom') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customUrl,
                    decoration: const InputDecoration(
                      labelText: 'Tile URL template',
                      hintText: 'https://example.com/tiles/{z}/{x}/{y}.png',
                    ),
                    onChanged: (v) => s.customTileUrl = v,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Why not Google tiles offline? Google\'s Maps Platform terms '
                  'do not allow apps to download Google map tiles for offline '
                  'use, so Gantabya uses Google Maps when online and these '
                  'downloadable tiles when offline.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const _Header('Google Places search'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _googleKey,
                  decoration: InputDecoration(
                    labelText: 'Google API key (optional override)',
                    helperText: AppConfig.googleApiKey.isEmpty
                        ? 'No key was built into the app.'
                        : 'Using the key built into the app unless set here.',
                  ),
                  onChanged: (v) => s.googleApiKeyOverride = v,
                ),
              ],
            ),
          ),
          const _Header('Journey recording'),
          ListTile(
            title: const Text('Record a point every'),
            subtitle: Slider(
              value: s.trackingDistanceFilter.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              label: '${s.trackingDistanceFilter} m',
              onChanged: (v) => s.trackingDistanceFilter = v.round(),
            ),
            trailing: Text('${s.trackingDistanceFilter} m'),
          ),
          const _Header('Your data'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export backup'),
            subtitle: const Text('Save all places, trips and journeys as JSON'),
            onTap: _busy ? null : _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore backup'),
            subtitle: const Text('Replace data on this device from a backup'),
            onTap: _busy ? null : _import,
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Gantabya',
            applicationVersion: '1.0.0',
            applicationLegalese:
                'Your travel journal stays on your device.\n'
                'Map data © Google, © OpenStreetMap contributors and the '
                'selected tile provider.',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
