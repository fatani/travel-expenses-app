import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../trips/domain/country_database.dart';
import '../../trips/domain/country_info.dart';
import 'user_financial_profile_controller.dart';

class FinancialProfileOnboardingScreen extends ConsumerStatefulWidget {
  const FinancialProfileOnboardingScreen({super.key});

  @override
  ConsumerState<FinancialProfileOnboardingScreen> createState() =>
      _FinancialProfileOnboardingScreenState();
}

class _FinancialProfileOnboardingScreenState
    extends ConsumerState<FinancialProfileOnboardingScreen> {
  final TextEditingController _searchController = TextEditingController();
  CountryInfo? _selectedCountry;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final query = _searchController.text.trim();
    final countries = CountryDatabase.search(query, limit: 80);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  context.l10n.financialOnboardingQuestion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.financialOnboardingSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.l10n.financialCountrySearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      itemCount: countries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final selected = _selectedCountry?.countryCode == country.countryCode;
                        return ListTile(
                          onTap: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _selectedCountry = country;
                                  });
                                },
                          leading: Text(country.flagEmoji, style: const TextStyle(fontSize: 24)),
                          title: Text(
                            country.getLocalizedName(isArabic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${country.currencyCode} • ${country.currencyName}',
                            textDirection: TextDirection.ltr,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                              : null,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: (_selectedCountry == null || _isSaving)
                        ? null
                        : _saveSelection,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(context.l10n.financialOnboardingContinue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSelection() async {
    final country = _selectedCountry;
    if (country == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(userFinancialProfileControllerProvider.notifier)
          .setHomeCountry(country);
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
