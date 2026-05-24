import 'package:flutter/material.dart';

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
    final data = isArabic ? _arabicData : _englishData;

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
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStartTrip,
                    child: Text(data.cta),
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

class _Data {
  final String title;
  final String cta;

  const _Data({
    required this.title,
    required this.cta,
  });
}

const _arabicData = _Data(
  title: 'لا توجد رحلات',
  cta: 'إضافة رحلة',
);

const _englishData = _Data(
  title: 'No trips yet',
  cta: 'Add trip',
);
