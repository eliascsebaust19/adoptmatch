/// Platform-agnostic hook for the web URL strategy.
///
/// Kept behind a conditional import so the mobile and desktop builds never pull
/// in `dart:ui_web` / `flutter_web_plugins`.
export 'url_strategy_io.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
