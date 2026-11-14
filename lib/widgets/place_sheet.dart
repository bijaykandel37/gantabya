import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/journal_store.dart';
import '../models/place.dart';
import '../screens/map/map_views.dart';
import '../screens/places/place_form_screen.dart';
import 'format.dart';

/// Bottom sheet summary of a place, with edit / mark-visited actions.
Future<void> showPlaceSheet(BuildContext context, Place place) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final store = ctx.watch<JournalStore>();
      final p = store.placeById(place.id);
      if (p == null) return const SizedBox(height: 80);
      final trip = store.tripById(p.tripId);
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(p.category.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.name, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: placeColor(p),
                      radius: 6,
                    ),
                    label: Text(p.isVisited ? 'Visited' : 'Wishlist'),
                  ),
                  Chip(label: Text(p.category.label)),
                  if (p.visitedAt != null)
                    Chip(
                      avatar: const Icon(Icons.event, size: 16),
                      label: Text(formatDate(p.visitedAt)),
                    ),
                  if (trip != null)
                    Chip(
                      avatar: const Icon(Icons.luggage, size: 16),
                      label: Text(trip.name),
                    ),
                  if (p.rating != null) Chip(label: Text('★' * p.rating!)),
                ],
              ),
              if ((p.address ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.address!, style: theme.textTheme.bodyMedium),
              ],
              if ((p.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.notes!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 4),
              Text(formatLatLng(p.position), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!p.isVisited)
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Mark visited'),
                        onPressed: () => store.savePlace(
                          p.copyWith(
                            status: PlaceStatus.visited,
                            visitedAt: DateTime.now(),
                          ),
                        ),
                      ),
                    ),
                  if (!p.isVisited) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlaceFormScreen(place: p),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
