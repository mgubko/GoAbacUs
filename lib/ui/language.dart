import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// The language the child picked, or null to follow the device.
final appLocale = ValueNotifier<Locale?>(null);

const _key = 'locale';

/// Each language under its own name, so it can be found whatever language
/// the screen is in now.
const languageNames = {
  'ru': 'Русский',
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
};

Future<void> loadLocale() async {
  try {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    if (code != null && languageNames.containsKey(code)) {
      appLocale.value = Locale(code);
    }
  } catch (_) {
    // No storage (tests, a broken plugin): follow the device.
  }
}

Future<void> setLocale(Locale? locale) async {
  appLocale.value = locale;
  try {
    final p = await SharedPreferences.getInstance();
    if (locale == null) {
      await p.remove(_key);
    } else {
      await p.setString(_key, locale.languageCode);
    }
  } catch (_) {}
}

/// A list of the languages; picking one switches the whole app at once.
Future<void> showLanguagePicker(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final current = appLocale.value?.languageCode;
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: const Color(0xFFF6EEE0),
      title: Text(t.menuLanguage),
      children: [
        RadioGroup<String>(
          groupValue: current ?? '',
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in ['', ...languageNames.keys])
                RadioListTile<String>(
                  value: code,
                  title: Text(
                    code.isEmpty ? t.languageSystem : languageNames[code]!,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked == null) return;
  await setLocale(picked.isEmpty ? null : Locale(picked));
}

/// A globe button that opens [showLanguagePicker].
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).menuLanguage,
    color: color,
    icon: const Icon(Icons.language),
    onPressed: () => showLanguagePicker(context),
  );
}
