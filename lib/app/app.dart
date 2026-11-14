import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs/preferences.dart';
import '../features/discovery/home_screen.dart';
import 'l10n.dart';
import 'router.dart';
import 'session_coordinator.dart';
import 'theme/lumen.dart';

/// Root widget: theme, localization and the navigator.
class LocalScreenApp extends ConsumerWidget {
  /// Creates the app.
  const LocalScreenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'LocalScreen',
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildLsTheme(LsTokens.light),
      darkTheme: buildLsTheme(LsTokens.dark),
      themeMode: prefs.themeMode,
      themeAnimationDuration: const LsMotion().base.duration,
      themeAnimationCurve: const LsMotion().base.curve,
      locale: prefs.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      home: const SessionCoordinator(child: HomeScreen()),
    );
  }
}
