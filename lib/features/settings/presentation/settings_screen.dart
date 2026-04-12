import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = ref.watch(settingsControllerProvider);
    final selectedLocale = settingsState.valueOrNull?.localeCode ?? 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.languageSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.languageSectionDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'ar',
                          label: Text(l10n.languageArabic),
                        ),
                        ButtonSegment<String>(
                          value: 'en',
                          label: Text(l10n.languageEnglish),
                        ),
                      ],
                      selected: <String>{selectedLocale},
                      onSelectionChanged: settingsState.isLoading
                          ? null
                          : (selection) => _updateLocale(
                              context,
                              ref,
                              selection.isEmpty ? null : selection.first,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocale(
    BuildContext context,
    WidgetRef ref,
    String? localeCode,
  ) async {
    if (localeCode == null) {
      return;
    }

    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .updateLocale(localeCode);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsLanguageSaveError(error.toString())),
        ),
      );
    }
  }
}
