import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.position,
    this.types = const [],
    this.countryCode,
  });

  final String placeId;
  final String name;
  final String address;
  final LatLng position;
  final List<String> types;
  final String? countryCode;
}

class PlacesSearchException implements Exception {
  PlacesSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Places API (New) – Text Search.
/// https://developers.google.com/maps/documentation/places/web-service/text-search
class PlacesSearchService {
  PlacesSearchService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static final _endpoint = Uri.parse(
    'https://places.googleapis.com/v1/places:searchText',
  );

  Future<List<PlaceSearchResult>> search(
    String query, {
    required String apiKey,
    LatLng? near,
  }) async {
    if (apiKey.isEmpty) {
      throw PlacesSearchException(
        'No Google API key configured. Add one in Settings.',
      );
    }
    final body = <String, Object?>{
      'textQuery': query,
      'pageSize': 15,
      if (near != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': near.latitude, 'longitude': near.longitude},
            'radius': 50000.0,
          },
        },
    };
    final res = await _client
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'places.id,places.displayName,'
                'places.formattedAddress,places.location,places.types,'
                'places.addressComponents',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      String msg = 'Search failed (${res.statusCode}).';
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (err['error']?['message'] as String?) ?? msg;
      } catch (_) {}
      throw PlacesSearchException(msg);
    }
    return parseResults(res.body);
  }

  static List<PlaceSearchResult> parseResults(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final places = (json['places'] as List?) ?? const [];
    return [
      for (final p in places.cast<Map<String, dynamic>>())
        if (p['location'] != null)
          PlaceSearchResult(
            placeId: p['id'] as String? ?? '',
            name: (p['displayName']?['text'] as String?) ?? 'Unnamed place',
            address: p['formattedAddress'] as String? ?? '',
            position: LatLng(
              (p['location']['latitude'] as num).toDouble(),
              (p['location']['longitude'] as num).toDouble(),
            ),
            types: ((p['types'] as List?) ?? const []).cast<String>(),
            countryCode: _country(p['addressComponents'] as List?),
          ),
    ];
  }

  static String? _country(List? components) {
    if (components == null) return null;
    for (final c in components.cast<Map<String, dynamic>>()) {
      final types = (c['types'] as List?)?.cast<String>() ?? const [];
      if (types.contains('country')) return c['longText'] as String?;
    }
    return null;
  }
}
