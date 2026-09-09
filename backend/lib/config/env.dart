import 'package:dotenv/dotenv.dart';

/// Singleton wrapper around the [DotEnv] instance.
///
/// Call [AppEnv.load] once at application startup (before any service uses it),
/// then read values anywhere via [AppEnv.get].
class AppEnv {
  static DotEnv? _env;

  AppEnv._();

  /// Load the .env file from [path] (relative to the working directory).
  /// Must be called before [get] is used.
  static void load({String path = '.env'}) {
    _env = DotEnv(includePlatformEnvironment: true)..load([path]);
  }

  /// Returns the value for [key], or null if not set.
  static String? get(String key) {
    assert(_env != null, 'AppEnv.load() must be called before AppEnv.get()');
    return _env![key];
  }
}
