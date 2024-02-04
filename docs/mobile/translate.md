# Translate

Using built-in internationalization: <https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization>

1. Add to `lib/src/lib/localization/app_en.arb`
2. Run `flutter run`
   - This updates the generated file `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`
3. Use `AppLocalizations.of(context)!.<translation_key>`

Notes

- Can't split translations across multiple files: <https://github.com/flutter/flutter/issues/107157>
