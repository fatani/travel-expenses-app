import 'package:flutter/widgets.dart';

import 'package:travel_expenses/l10n/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
