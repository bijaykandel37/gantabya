/// Build-time configuration.
///
/// Pass the key with:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=xxxx
///
/// The same Google Cloud key is used for the Places API (search). The native
/// Maps SDK key is configured separately for Android/iOS – see README.md.
class AppConfig {
  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  /// Sent with every tile request (tile servers require an identifying UA).
  static const String userAgentPackageName = 'com.gantabya.app';

  /// Safety cap for a single offline download.
  static const int maxTilesPerRegion = 150000;

  /// Rough average size of a raster tile, used for size estimates only.
  static const int estimatedBytesPerTile = 18 * 1024;
}
