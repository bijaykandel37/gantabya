import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/journal_store.dart';
import '../../models/trip.dart';
import '../../widgets/format.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.trip});
  final Trip? trip;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.trip?.name ?? '');
  late final _notes = TextEditingController(text: widget.trip?.notes ?? '');
  late DateTime? _start = widget.trip?.startDate;
  late DateTime? _end = widget.trip?.endDate;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (r != null) {
      setState(() {
        _start = r.start;
        _end = r.end;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = context.read<JournalStore>();
    final notes = _notes.text.trim();
    final trip = Trip(
      id: widget.trip?.id ?? newId(),
      name: _name.text.trim(),
      notes: notes.isEmpty ? null : notes,
      startDate: _start,
      endDate: _end,
      createdAt: widget.trip?.createdAt ?? DateTime.now(),
    );
    await store.saveTrip(trip);
    if (mounted) Navigator.pop(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null ? 'New trip' : 'Edit trip'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Trip name',
                hintText: 'e.g. Annapurna Circuit',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: const Text('Dates'),
              subtitle: Text(
                _start == null ? 'Not set' : formatDateRange(_start, _end),
              ),
              onTap: _pickRange,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 8,
            ),
          ],
        ),
      ),
    );
  }
}
