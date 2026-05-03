import 'package:flutter/material.dart';

import 'cards_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'الإعدادات' : 'Settings';
    final cardsTitle = isArabic ? 'بطاقاتي' : 'My Cards';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            leading: const Icon(Icons.credit_card_rounded),
            title: Text(cardsTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const CardsListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
