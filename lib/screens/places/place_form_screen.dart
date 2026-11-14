import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/place.dart';
import '../../services/geocoding_service.dart';
import '../../services/places_search_service.dart';
import '../../services/track_recorder.dart';
import '../../widgets/format.dart';

/// Create or edit a place. Works fully offline (reverse geocoding is a
/// best-effort extra when online).
class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({
    super.key,
    this.place,
    this.initialPosition,
    this.fromSearch,
    this.initialTripId,
    this.initialStatus,
  });

  final Place? place;
  final LatLng? initialPosition;
  final PlaceSearchResult? fromSearch;
  final String? initialTripId;
  final PlaceStatus? initialStatus;

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _address;
  late PlaceStatus _status;
  late PlaceCategory _category;
  DateTime? _visitedAt;
  int? _rating;
  String? _tripId;
  String? _country;
  String? _locality;
  LatLng? _position;
  bool _geocoding = false;

  bool get _isNew => widget.place == null;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    final s = widget.fromSearch;
    _name = TextEditingController(text: p?.name ?? s?.name ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _address = TextEditingController(text: p?.address ?? s?.address ?? '');
    _status = p?.status ?? widget.initialStatus ?? PlaceStatus.visited;
    _category = p?.category ?? guessCategory(s?.types ?? const []);
    _visitedAt = p?.visitedAt ?? (_isNew ? DateTime.now() : null);
    _rating = p?.rating;
    _tripId = p?.tripId ?? widget.initialTripId;
    _country = p?.country ?? s?.countryCode;
    _locality = p?.locality;
    _position = p?.position ?? s?.position ?? widget.initialPosition;

    if (_isNew && _position != null) _lookupAddress();
    if (_isNew && _position == null) _useCurrentLocation();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _lookupAddress() async {
    final pos = _position;
    if (pos == null) return;
    setState(() => _geocoding = true);
    final r = await reverseGeocode(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _geocoding = false;
      if (r == null) return;
      if (_name.text.isEmpty && r.name != null) _name.text = r.name!;
      if (_address.text.isEmpty && r.address != null) {
        _address.text = r.address!;
      }
      _country ??= r.country;
      _locality ??= r.locality;
    });
  }

  Future<void> _useCurrentLocation() async {
    final pos = await TrackRecorder.currentPosition();
    if (!mounted || pos == null) return;
    setState(() => _position = LatLng(pos.latitude, pos.longitude));
    _lookupAddress();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _visitedAt ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _visitedAt = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pos = _position;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location yet. Long-press the map to pick one.'),
        ),
      );
      return;
    }
    final store = context.read<JournalStore>();
    final existing = widget.place;
    String? nn(String s) => s.trim().isEmpty ? null : s.trim();
    final place = Place(
      id: existing?.id ?? newId(),
      name: _name.text.trim(),
      status: _status,
      category: _category,
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: nn(_address.text),
      locality: _locality,
      country: _country,
      notes: nn(_notes.text),
      rating: _rating,
      visitedAt: _status == PlaceStatus.visited ? _visitedAt : null,
      tripId: _tripId,
      googlePlaceId: existing?.googlePlaceId ?? widget.fromSearch?.placeId,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await store.savePlace(place);
    if (mounted) Navigator.pop(context, place);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete place?'),
        content: Text('"${widget.place!.name}" will be removed.'),
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
    if (ok != true || !mounted) return;
    await context.read<JournalStore>().deletePlace(widget.place!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<JournalStore>().trips;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New place' : 'Edit place'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SegmentedButton<PlaceStatus>(
              segments: const [
                ButtonSegment(
                  value: PlaceStatus.visited,
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Been there'),
                ),
                ButtonSegment(
                  value: PlaceStatus.wishlist,
                  icon: Icon(Icons.star_outline),
                  label: Text('Want to go'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                suffixIcon: _geocoding
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PlaceCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in PlaceCategory.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text('${c.emoji}  ${c.label}'),
                  ),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: trips.any((t) => t.id == _tripId) ? _tripId : null,
              decoration: const InputDecoration(labelText: 'Trip'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No trip')),
                for (final t in trips)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _tripId = v),
            ),
            if (_status == PlaceStatus.visited) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Visited on'),
                subtitle: Text(
                  _visitedAt == null ? 'Not set' : formatDate(_visitedAt),
                ),
                onTap: _pickDate,
              ),
              Row(
                children: [
                  const Text('Rating'),
                  const SizedBox(width: 8),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _rating = _rating == i ? null : i),
                      icon: Icon(
                        (_rating ?? 0) >= i ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes / memories',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_drop_outlined),
              title: Text(
                _position == null
                    ? 'Getting location…'
                    : formatLatLng(_position!),
              ),
              subtitle: Text([?_locality, ?_country].join(', ')),
              trailing: IconButton(
                tooltip: 'Use my current location',
                icon: const Icon(Icons.my_location),
                onPressed: _useCurrentLocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps Google place types to our categories.
PlaceCategory guessCategory(List<String> types) {
  bool has(String t) => types.contains(t);
  if (has('restaurant') ||
      has('cafe') ||
      has('bar') ||
      has('food') ||
      has('bakery')) {
    return PlaceCategory.food;
  }
  if (has('lodging') || has('hotel')) return PlaceCategory.stay;
  if (has('hindu_temple') ||
      has('church') ||
      has('mosque') ||
      has('place_of_worship') ||
      has('buddhist_temple')) {
    return PlaceCategory.temple;
  }
  if (has('natural_feature') || has('park') || has('national_park')) {
    return PlaceCategory.nature;
  }
  if (has('beach')) return PlaceCategory.beach;
  if (has('tourist_attraction') ||
      has('museum') ||
      has('historical_landmark')) {
    return PlaceCategory.landmark;
  }
  if (has('locality') ||
      has('political') ||
      has('administrative_area_level_1')) {
    return PlaceCategory.city;
  }
  return PlaceCategory.other;
}
