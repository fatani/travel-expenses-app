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
    final data = isArabic
        ? (isFirstTime ? _arabicFirstTimeData : _arabicReturningData)
        : (isFirstTime ? _englishFirstTimeData : _englishReturningData);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FB),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: 0.68,
                          child: Image.asset('assets/travel.png', height: 120),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onStartTrip,
                    child: Ink(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          data.cta,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Data {
  final String title;
  final String description;
  final String cta;

  _Data({
    required this.title,
    required this.description,
    required this.cta,
  });
}

final _arabicFirstTimeData = _Data(
  title: 'ابدأ رحلتك الأولى',
  description: 'أنشئ رحلة وابدأ تسجيل مصاريفك.',
  cta: 'إضافة رحلة',
);

final _arabicReturningData = _Data(
  title: 'لا توجد رحلات حالياً',
  description: 'يمكنك إضافة رحلة جديدة في أي وقت.',
  cta: 'إضافة رحلة جديدة',
);

final _englishFirstTimeData = _Data(
  title: 'Start your first trip',
  description: 'Create a trip and begin logging expenses.',
  cta: 'Add trip',
);

final _englishReturningData = _Data(
  title: 'No trips right now',
  description: 'You can add a new trip anytime.',
  cta: 'Add new trip',
);
