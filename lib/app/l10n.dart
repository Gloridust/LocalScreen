import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// Shorthand for the generated localizations.
extension L10nContext on BuildContext {
  /// The [AppLocalizations] of this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Picks Chinese for any `zh*` locale and English otherwise.
Locale resolveAppLocale(Iterable<Locale>? preferred) {
  for (final l in preferred ?? const <Locale>[]) {
    if (l.languageCode == 'zh') return const Locale('zh');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}
