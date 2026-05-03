import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/card_display_helper.dart';
import '../domain/card_profile.dart';
import 'add_card_screen.dart';
import 'cards_provider.dart';

class CardsListScreen extends ConsumerWidget {
  const CardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'بطاقاتي' : 'My Cards';
    final emptyTitle = isArabic
        ? 'لم تقم بإضافة بطاقات بعد'
        : 'No cards added yet';
    final emptyDescription = isArabic
        ? 'أضف بطاقتك لاستخدامها في تسجيل المصاريف'
        : 'Add your card to use it when recording expenses';
    final addCardText = isArabic ? 'إضافة بطاقة' : 'Add Card';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(isArabic ? 'حدث خطأ' : 'Something went wrong'),
        ),
        data: (cards) => cards.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.credit_card_off_rounded, size: 44),
                      const SizedBox(height: 16),
                      Text(
                        emptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptyDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const AddCardScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(addCardText),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cards.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final displayText = CardDisplayHelper.getDisplayString(
                    context,
                    card,
                  );
                  return Card(
                    child: ListTile(
                      onTap: () => _openEditCard(context, card: card),
                      title: Text(displayText, textAlign: TextAlign.right),
                      trailing: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: isArabic ? 'تعديل' : 'Edit',
                              onPressed: () =>
                                  _openEditCard(context, card: card),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: isArabic ? 'حذف' : 'Delete',
                              onPressed: () =>
                                  _confirmDeleteCard(context, ref, card: card),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AddCardScreen()),
        ),
        child: const Icon(Icons.add_rounded),
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
