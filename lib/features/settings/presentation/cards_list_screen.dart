import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/card_profile.dart';
import '../domain/card_display_helper.dart';
import 'add_card_screen.dart';
import 'cards_provider.dart';

class CardsListScreen extends ConsumerWidget {
  const CardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'بطاقاتي' : 'My Cards';
    final emptyTitle = isArabic ? 'بطاقاتي' : 'My Cards';
    final emptyDescription = isArabic
        ? 'أضف بطاقتك لتسريع تسجيل المصاريف'
        : 'Add your card for faster expense entry';
    final addCardText = isArabic ? 'إضافة بطاقة' : 'Add Card';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(title: Text(title)),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(isArabic ? 'حدث خطأ' : 'Something went wrong'),
        ),
        data: (cards) => cards.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF7C3AED).withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.12),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.credit_card_rounded,
                                    size: 34,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              emptyTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              emptyDescription,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: cards.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        final bankLabel =
                          CardDisplayHelper.getBankLabel(context, card) ??
                          card.name;
                        final networkLabel =
                          CardDisplayHelper.getNetworkLabel(context, card) ?? '';
                        final tierLabel =
                          CardDisplayHelper.getTierLabel(context, card) ?? '';
                        final typeLabel = tierLabel.isEmpty
                            ? networkLabel
                            : '$networkLabel $tierLabel';
                        final networkBadgeLabel = networkLabel.isEmpty
                          ? (isArabic ? 'بطاقة' : 'Card')
                          : networkLabel;
                        final last4 = card.last4?.trim().isNotEmpty == true
                            ? card.last4!.trim()
                            : '----';

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _openEditCard(context, card: card),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: 0.06),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFFE6EAF4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bankLabel,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3E8FF),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFFEDE9FE),
                                          ),
                                        ),
                                        child: Text(
                                          networkBadgeLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6B21A8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Text(
                                        '••••$last4',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF334155),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const Spacer(),
                                      _SoftActionIcon(
                                        tooltip: isArabic ? 'تعديل' : 'Edit',
                                        icon: Icons.edit_outlined,
                                        color: const Color(0xFF475569),
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        borderColor: const Color(0xFFE2E8F0),
                                        onTap: () =>
                                            _openEditCard(context, card: card),
                                      ),
                                      const SizedBox(width: 8),
                                      _SoftActionIcon(
                                        tooltip: isArabic ? 'حذف' : 'Delete',
                                        icon: Icons.delete_outline_rounded,
                                        color: const Color(0xFFB91C1C),
                                        backgroundColor: const Color(0xFFFEE2E2),
                                        borderColor: const Color(0xFFFECACA),
                                        onTap: () => _confirmDeleteCard(
                                          context,
                                          ref,
                                          card: card,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AddCardScreen()),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          addCardText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Future<void> _openEditCard(
    BuildContext context, {
    required CardProfile card,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddCardScreen(
          cardId: card.id,
          initialCardName: card.name,
          initialBankName: card.bankName,
          initialCardNetwork: card.cardNetwork,
          initialCardTier: card.cardTier,
          initialCustomBankName: card.customBankName,
          initialCustomCardNetwork: card.customCardNetwork,
          initialCustomCardTier: card.customCardTier,
          initialLast4: card.last4,
          initialDisplayName: card.displayName,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCard(
    BuildContext context,
    WidgetRef ref, {
    required CardProfile card,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'حذف البطاقة' : 'Delete card';
    final message = isArabic
        ? 'هل تريد حذف هذه البطاقة؟'
        : 'Do you want to delete this card?';
    final confirm = isArabic ? 'حذف' : 'Delete';
    final cancel = isArabic ? 'إلغاء' : 'Cancel';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirm),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      ref.read(cardsProvider.notifier).deleteCard(card.id);
    }
  }
}

class _SoftActionIcon extends StatelessWidget {
  const _SoftActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF334155),
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.borderColor = const Color(0xFFE2E8F0),
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
