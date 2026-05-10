import 'package:flutter/material.dart';

class TripsEmptyStateScreen extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onStartTrip;

  const TripsEmptyStateScreen({
    super.key,
    this.isArabic = true,
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
          child: PrimaryScrollController.none(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                            /// Image
                            Opacity(
                              opacity: 0.72,
                              child: Image.asset(
                                'assets/travel.png',
                                height: 140,
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// Title
                            Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),

                            const SizedBox(height: 8),

                            /// Description
                            Text(
                              data.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// Speed
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data.speed,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                              ],
                            ),

                            const SizedBox(height: 8),

                            /// Trust
                            Text(
                              data.trust,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 20),

                            _BenefitItem(icon: Icons.location_on_outlined, text: data.b1),
                            _BenefitItem(icon: Icons.attach_money, text: data.b2),
                            _BenefitItem(icon: Icons.bar_chart, text: data.b3),

                            const SizedBox(height: 20),

                            Opacity(
                              opacity: 0.5,
                              child: Column(
                                children: [
                                  _BenefitItem(icon: Icons.public, text: data.s1),
                                  _BenefitItem(icon: Icons.category, text: data.s2),
                                  _BenefitItem(icon: Icons.credit_card, text: data.s3),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// Urgency
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                                children: [
                                  TextSpan(text: data.urgency1),
                                  TextSpan(
                                    text: data.urgencyHighlight,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),

                /// CTA
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              data.cta,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: isRtl
            ? [
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, color: Colors.grey),
              ]
            : [
                Icon(icon, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}

class _Data {
  final String title, description, speed, trust;
  final String b1, b2, b3;
  final String s1, s2, s3;
  final String urgency1, urgencyHighlight;
  final String cta;

  _Data({
    required this.title,
    required this.description,
    required this.speed,
    required this.trust,
    required this.b1,
    required this.b2,
    required this.b3,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.urgency1,
    required this.urgencyHighlight,
    required this.cta,
  });
}

final _arabicData = _Data(
  title: "جاهز لرحلتك الأولى؟ ✈️",
  description: "ابدأ في تتبع مصاريف سفرك بسهولة، بدون تعقيد",
  speed: "في أقل من دقيقة",
  trust: "بدون تسجيل",
  b1: "نظّم رحلتك من أول ريال",
  b2: "ما راح يضيع ريال",
  b3: "كل ريال محسوب قدامك",
  s1: "رحلتك الأولى تبدأ الآن",
  s2: "كل مصروف له فئته",
  s3: "مصاريفك الأولى في انتظارك",
  urgency1: "كل مصروف ما تسجله… ",
  urgencyHighlight: "راح تنساه",
  cta: "ابدأ رحلتك الأولى الآن!",
);

final _englishData = _Data(
  title: "Ready for your first trip? ✈️",
  description: "Start tracking your travel expenses easily, without complexity",
  speed: "In less than a minute",
  trust: "No sign-up",
  b1: "Keep your trip organized from the first dollar",
  b2: "Don’t let a dollar slip away",
  b3: "Every dollar stays in front of you",
  s1: "Your first trip starts now",
  s2: "Every expense has a category",
  s3: "Your first expense is waiting",
  urgency1: "Every expense you don’t log… ",
  urgencyHighlight: "you’ll forget it",
  cta: "Start Your First Trip Now!",
);
