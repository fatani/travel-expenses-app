// Localization policy (see docs/architecture-principles.md):
// - Never add Arabic (or any UI copy) as string literals in Dart files.
// - All user-visible strings come from AppLocalizations (app_ar.arb / app_en.arb).
// - Code fallbacks when locale is unavailable must be English ASCII only.
// - Do not hand-edit generated app_localizations*.dart files.

import 'package:flutter/widgets.dart';

import 'package:travel_expenses/l10n/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
