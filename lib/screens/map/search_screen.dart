import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/place.dart';
import '../../services/connectivity_service.dart';
import '../../services/places_search_service.dart';
import '../../services/settings_service.dart';
import 'map_views.dart';

/// Searches your own journal (works offline) and Google Places (online).
/// Pops with a [Place] or a [PlaceSearchResult].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.near});
  final LatLng? near;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _service = PlacesSearchService();
  Timer? _debounce;
  List<PlaceSearchResult> _remote = [];
  String? _error;
  bool _loading = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _searchRemote(q),
    );
  }

  Future<void> _searchRemote(String q) async {
    q = q.trim();
    final online = context.read<ConnectivityService>().isOnline;
    final key = context.read<SettingsService>().googleApiKey;
    if (q.length < 3 || !online || key.isEmpty) {
      setState(() {
        _remote = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.search(q, apiKey: key, near: widget.near);
      if (!mounted || id != _requestId) return;
      setState(() => _remote = r);
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<JournalStore>();
    final online = context.watch<ConnectivityService>().isOnline;
    final hasKey = context.watch<SettingsService>().googleApiKey.isNotEmpty;
    final q = _query.text.trim().toLowerCase();
    final local = q.isEmpty
        ? <Place>[]
        : store.places
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    (p.address ?? '').toLowerCase().contains(q) ||
                    (p.country ?? '').toLowerCase().contains(q),
              )
              .take(20)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search a destination…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _searchRemote,
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        children: [
          if (local.isNotEmpty) const _Header('In your journal'),
          for (final p in local)
            ListTile(
              leading: Icon(Icons.location_on, color: placeColor(p)),
              title: Text(p.name),
              subtitle: Text(p.address ?? p.country ?? ''),
              onTap: () => Navigator.pop(context, p),
            ),
          if (!online)
            const _Hint(
              'You are offline — only your saved places are searched.',
            )
          else if (!hasKey)
            const _Hint('Add a Google API key (Settings) to search the world.')
          else if (_error != null)
            _Hint(_error!)
          else if (_remote.isNotEmpty)
            const _Header('Google Places'),
          for (final r in _remote)
            ListTile(
              leading: const Icon(Icons.travel_explore),
              title: Text(r.name),
              subtitle: Text(r.address),
              trailing: const Icon(Icons.add_location_alt_outlined),
              onTap: () => Navigator.pop(context, r),
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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
