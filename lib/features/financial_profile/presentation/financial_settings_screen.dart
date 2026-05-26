import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../trips/domain/country_database.dart';
import '../../trips/domain/country_info.dart';
import '../../../shared/widgets/calm_load_error_panel.dart';
import 'user_financial_profile_controller.dart';

class FinancialSettingsScreen extends ConsumerStatefulWidget {
  const FinancialSettingsScreen({super.key});

  @override
  ConsumerState<FinancialSettingsScreen> createState() =>
      _FinancialSettingsScreenState();
}

class _FinancialSettingsScreenState extends ConsumerState<FinancialSettingsScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final profileAsync = ref.watch(userFinancialProfileControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Text(context.l10n.financialSettingsTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CalmLoadErrorPanel(
          title: context.l10n.financialProfileLoadError,
          retryLabel: context.l10n.commonTryAgain,
          onRetry: () {
            ref.invalidate(userFinancialProfileControllerProvider);
          },
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(context.l10n.financialProfileMissing),
            );
          }

          final localizedCountry =
              isArabic ? profile.homeCountryArabic : profile.homeCountryEnglish;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE6EAF4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.financialSettingsHomeCountry,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedCountry,
                      style: const TextStyle(
                        fontSize: 21,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.financialSettingsHomeCurrency,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.homeCurrencyCode,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.financialSettingsStabilityHint,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _changeHomeCountry,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.public_rounded),
                  label: Text(context.l10n.financialSettingsChangeCountry),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeHomeCountry() async {
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final selected = await showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CountrySelectorSheet(isArabic: isArabic),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(userFinancialProfileControllerProvider.notifier)
          .setHomeCountry(selected);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.financialProfileSaveError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _CountrySelectorSheet extends StatefulWidget {
  const _CountrySelectorSheet({required this.isArabic});

  final bool isArabic;

  @override
  State<_CountrySelectorSheet> createState() => _CountrySelectorSheetState();
}

class _CountrySelectorSheetState extends State<_CountrySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final countries = CountryDatabase.search(query, limit: 90);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.l10n.financialCountrySearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(country),
                      leading: Text(country.flagEmoji, style: const TextStyle(fontSize: 22)),
                      title: Text(country.getLocalizedName(widget.isArabic)),
                      subtitle: Text(
                        '${country.currencyCode} • ${country.currencyName}',
                        textDirection: TextDirection.ltr,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
