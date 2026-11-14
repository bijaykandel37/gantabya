# Gantabya (गन्तव्य) – your travel journal

A Flutter app for **Android and iOS** that keeps track of everywhere you've
been and everywhere you want to go, all on one map. It works offline.

| | |
|---|---|
| 🗺️ **One map for everything** | Visited places (green), wishlist (orange) and recorded GPS routes (blue) on one map, with filters. |
| 📍 **Places** | Long-press the map, search Google Places, or use your current location. Add a category, visit date, rating, notes and trip. |
| 🧳 **Trips** | Group places and GPS journeys into trips (e.g. *Annapurna Circuit 2026*) and show a whole trip on the map. |
| 🛰️ **GPS journeys** | Record your route with GPS, including with the screen off and no internet. You see distance, duration and altitude points. |
| ⬇️ **Offline maps** | Pick an area and zoom levels and download it. With no connection the map switches to your downloaded tiles on its own. Your places and routes still show on top. |
| 📊 **Stats** | Countries, cities, places by category and by year, and total distance tracked. |
| 💾 **Backup** | Export or restore everything as one JSON file. All data stays on the device in SQLite. |

## How maps work: Google online, downloaded tiles offline

Google Maps is the main map whenever you're online. Google Places powers search.

**Google does not allow apps to download Google map tiles for offline use.**
The Maps Platform terms forbid pre-fetching, caching or storing Google map
content, and the Google Maps SDKs have no offline-download feature for
third-party apps. An app that scraped Google tiles would break your API
agreement and could have its key revoked.

So Gantabya uses a hybrid setup:

- **Online:** Google Maps (`google_maps_flutter`).
- **Offline:** raster tiles from a provider that *does* allow offline
  downloads. These are drawn with `flutter_map` and read from files on the
  device.
- **Map mode** (chip at the top of the map, or Settings): *Automatic*
  (default: Google when online, offline tiles when not), *Google Maps*, or
  *Offline tiles*.

You choose the offline tile source in **Settings → Offline map source**. The
built-in presets are MapTiler Streets, MapTiler Outdoor (contours and trails,
good for treks), Thunderforest Outdoors, and any custom XYZ tile URL, such as
your own tile server. Most providers have a free key. Check that your plan
allows offline or bulk use. OpenStreetMap's public tile server is set as
*browse only*, because its usage policy forbids bulk downloads.

## Setup

### 1. Install Flutter
Use Flutter **3.50 or newer** (Dart 3.14 or newer). Run `flutter doctor` to
check that Android Studio and Xcode are set up.

```bash
flutter pub get
```

### 2. Create Google Maps Platform API keys
In the [Google Cloud console](https://console.cloud.google.com/google/maps-apis),
create a project, turn on billing, and enable these APIs:

- **Maps SDK for Android**
- **Maps SDK for iOS**
- **Places API (New)**, used for search

It's best to create separate keys:

| Key | Restrict it to | Where it goes |
|---|---|---|
| Android | Android apps → package `com.gantabya.gantabya` + your SHA-1 | `android/local.properties` |
| iOS | iOS apps → bundle id `com.gantabya.gantabya` | `ios/Flutter/Secrets.xcconfig` |
| Places | API restriction: *Places API (New)* only | `--dart-define` or the app's Settings |

> The Places key is sent from the app with plain HTTPS calls. A key that's
> restricted to "Android apps" or "iOS apps" will be **rejected** for those
> calls, so restrict the Places key by API instead.

**Android:** add this line to `android/local.properties` (the file is
git-ignored):
```properties
MAPS_API_KEY=AIza...your-android-key
```
You can also export `MAPS_API_KEY` as an environment variable before you build.

**iOS:** copy the example file, then fill in your key:
```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
```
```
MAPS_API_KEY = AIza...your-ios-key
```

### 3. Run
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...your-places-key
```
You can skip the dart-define and paste the Places key in **Settings → Google
Places search** instead.

### 4. Set up offline maps
1. Get a free key from a tile provider, for example
   [MapTiler](https://cloud.maptiler.com/account/keys/).
2. In the app, go to **Settings → Offline map source**, pick the provider
   and paste the key.
3. Go to the **Offline** tab and tap **Download region**. Pan and zoom so
   the area is inside the frame, choose the zoom levels, then tap
   **Download**. You'll see the tile count and an estimated size before you
   start. Downloads can be paused and resumed.

### Release builds
- **Android:** `flutter build appbundle`. Set up a release signing config in
  `android/app/build.gradle.kts` first. It uses the debug key until you do.
- **iOS:** `flutter build ipa`. The app needs iOS 16 or newer because of
  Google Maps SDK 10.
- Store review: the app asks for location *while in use*. It keeps recording
  a journey in the background through a foreground-service notification on
  Android and the background `location` mode on iOS. Mention this in your
  store listing.

## Project layout

```
lib/
  main.dart, app.dart          start-up, providers, theme
  config.dart                  build-time config (dart-define)
  models/                      Place, Trip, Track/TrackPoint, OfflineRegion
  data/
    database.dart              SQLite schema and queries (sqflite)
    journal_store.dart         ChangeNotifier over places, trips and tracks
  services/
    track_recorder.dart        the one GPS stream: blue dot + journey recording
    places_search_service.dart Google Places API (New) text search
    geocoding_service.dart     reverse geocoding (platform geocoder)
    connectivity_service.dart  online/offline
    settings_service.dart      map mode, tile provider, keys
    backup_service.dart        JSON export/import
    offline/
      tile_math.dart           slippy-map tile maths
      offline_maps_manager.dart region downloads (concurrent, resumable)
      offline_tile_provider.dart flutter_map provider: disk first, then network
      region_storage.dart      <app support>/offline_tiles/<region>/<z>/<x>/<y>
  screens/
    map/                       map screen, Google and offline renderers, search
    places/ trips/ offline/ stats/ settings/
test/                          unit tests (SQLite through sqflite_common_ffi)
```

## Tests

```bash
flutter analyze
flutter test
```

The tests cover tile maths, the offline downloader (full download,
failed-tile retry that skips tiles already saved, size limit, delete), the
offline tile provider, SQLite persistence, trip deletion, backup round-trip,
Places API parsing and errors, and travel stats.
