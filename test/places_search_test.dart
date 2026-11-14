import 'package:flutter_test/flutter_test.dart';
import 'package:gantabya/services/places_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _body = '''
{
  "places": [
    {
      "id": "ChIJ123",
      "displayName": {"text": "Boudhanath Stupa", "languageCode": "en"},
      "formattedAddress": "Buddha Stupa, Kathmandu 44600, Nepal",
      "location": {"latitude": 27.7215, "longitude": 85.3620},
      "types": ["tourist_attraction", "place_of_worship"],
      "addressComponents": [
        {"longText": "Kathmandu", "types": ["locality", "political"]},
        {"longText": "Nepal", "shortText": "NP", "types": ["country", "political"]}
      ]
    },
    {"id": "no-location", "displayName": {"text": "Skip me"}}
  ]
}
''';

void main() {
  test('parses Places API (New) text search results', () {
    final r = PlacesSearchService.parseResults(_body);
    expect(r.length, 1);
    expect(r.first.name, 'Boudhanath Stupa');
    expect(r.first.position.latitude, 27.7215);
    expect(r.first.countryCode, 'Nepal');
    expect(r.first.types, contains('place_of_worship'));
  });

  test('sends key + field mask and surfaces API errors', () async {
    late http.Request seen;
    final ok = PlacesSearchService(
      client: MockClient((req) async {
        seen = req;
        return http.Response(_body, 200);
      }),
    );
    final results = await ok.search('boudha', apiKey: 'k');
    expect(results.single.placeId, 'ChIJ123');
    expect(seen.headers['X-Goog-Api-Key'], 'k');
    expect(seen.headers['X-Goog-FieldMask'], contains('places.location'));

    final bad = PlacesSearchService(
      client: MockClient(
        (_) async =>
            http.Response('{"error":{"message":"API key not valid."}}', 400),
      ),
    );
    expect(
      () => bad.search('x', apiKey: 'k'),
      throwsA(
        isA<PlacesSearchException>().having(
          (e) => e.message,
          'message',
          'API key not valid.',
        ),
      ),
    );
    expect(
      () => ok.search('x', apiKey: ''),
      throwsA(isA<PlacesSearchException>()),
    );
  });
}
