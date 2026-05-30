import 'package:flutter/material.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

class TripsEmptyStateScreen extends StatelessWidget {
  final bool isArabic;
  final bool isFirstTime;
  final VoidCallback onStartTrip;

  const TripsEmptyStateScreen({
    super.key,
    this.isArabic = true,
    this.isFirstTime = true,
    required this.onStartTrip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.tripsEmptyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    height: isArabic ? 1.4 : 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.tripsEmptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF475569),
                    height: isArabic ? 1.5 : 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStartTrip,
                    child: Text(l10n.tripsAddButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
