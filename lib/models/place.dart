import 'package:latlong2/latlong.dart';

enum PlaceStatus { visited, wishlist }

enum PlaceCategory {
  city('City', '🏙️'),
  nature('Nature', '🏞️'),
  mountain('Mountain / Trek', '🏔️'),
  beach('Beach', '🏖️'),
  landmark('Landmark', '🏛️'),
  temple('Temple / Religious', '🛕'),
  food('Food & Drink', '🍜'),
  stay('Stay', '🏨'),
  other('Other', '📍');

  const PlaceCategory(this.label, this.emoji);
  final String label;
  final String emoji;

  static PlaceCategory fromName(String? name) => PlaceCategory.values
      .firstWhere((c) => c.name == name, orElse: () => PlaceCategory.other);
}

class Place {
  Place({
    required this.id,
    required this.name,
    required this.status,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.locality,
    this.country,
    this.notes,
    this.rating,
    this.visitedAt,
    this.tripId,
    this.googlePlaceId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final PlaceStatus status;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final String? address;
  final String? locality;
  final String? country;
  final String? notes;
  final int? rating;
  final DateTime? visitedAt;
  final String? tripId;
  final String? googlePlaceId;
  final DateTime createdAt;

  LatLng get position => LatLng(latitude, longitude);
  bool get isVisited => status == PlaceStatus.visited;

  Place copyWith({
    String? name,
    PlaceStatus? status,
    PlaceCategory? category,
    double? latitude,
    double? longitude,
    String? address,
    String? locality,
    String? country,
    String? notes,
    int? rating,
    DateTime? visitedAt,
    String? tripId,
    bool clearTrip = false,
    bool clearVisitedAt = false,
    bool clearRating = false,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      locality: locality ?? this.locality,
      country: country ?? this.country,
      notes: notes ?? this.notes,
      rating: clearRating ? null : (rating ?? this.rating),
      visitedAt: clearVisitedAt ? null : (visitedAt ?? this.visitedAt),
      tripId: clearTrip ? null : (tripId ?? this.tripId),
      googlePlaceId: googlePlaceId,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'status': status.name,
    'category': category.name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'locality': locality,
    'country': country,
    'notes': notes,
    'rating': rating,
    'visited_at': visitedAt?.millisecondsSinceEpoch,
    'trip_id': tripId,
    'google_place_id': googlePlaceId,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Place.fromMap(Map<String, Object?> m) => Place(
    id: m['id'] as String,
    name: m['name'] as String,
    status: PlaceStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => PlaceStatus.visited,
    ),
    category: PlaceCategory.fromName(m['category'] as String?),
    latitude: (m['latitude'] as num).toDouble(),
    longitude: (m['longitude'] as num).toDouble(),
    address: m['address'] as String?,
    locality: m['locality'] as String?,
    country: m['country'] as String?,
    notes: m['notes'] as String?,
    rating: (m['rating'] as num?)?.toInt(),
    visitedAt: _date(m['visited_at']),
    tripId: m['trip_id'] as String?,
    googlePlaceId: m['google_place_id'] as String?,
    createdAt: _date(m['created_at']) ?? DateTime.now(),
  );
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
