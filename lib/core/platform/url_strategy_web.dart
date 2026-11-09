import 'package:flutter_web_plugins/url_strategy.dart';

/// Browsers need path-based URLs for the Supabase OAuth redirect to keep the
/// `?code=` query string. With the default hash strategy the code lands after
/// `/#/auth-callback`, where the auth client cannot read it.
void configureUrlStrategyForBrowser() {
  usePathUrlStrategy();
}
