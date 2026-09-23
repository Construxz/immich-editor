import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show storage;

/// Display language chosen in the settings; null follows the device (D-43).
final appLocale = ValueNotifier<Locale?>(null);

const _key = 'language'; // persisted: do not rename

Future<void> readLanguage() async {
  final code = await storage.read(key: _key);
  appLocale.value = code == null ? null : Locale(code);
}

Future<void> setLanguage(Locale? locale) async {
  appLocale.value = locale;
  locale == null
      ? await storage.delete(key: _key)
      : await storage.write(key: _key, value: locale.languageCode);
}

/// German or English; any other device language gets English.
Locale resolveLocale(Locale? device) =>
    AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == device?.languageCode,
      orElse: () => const Locale('en'),
    );

/// Texts for code without a BuildContext (errors, progress steps). Widgets use
/// `AppLocalizations.of(context)` so they rebuild when the language changes.
AppLocalizations get l10n => lookupAppLocalizations(
  resolveLocale(appLocale.value ?? PlatformDispatcher.instance.locale),
);
