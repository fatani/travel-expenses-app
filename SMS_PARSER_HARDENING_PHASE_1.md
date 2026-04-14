# SMS Parsing System - Phase 1 Hardening Complete

## Overview
The SMS parsing system has been hardened to reliably handle multiple SMS format variations safely, following the principle: **"It is better to leave a field empty than to fill it with a wrong value."**

## Architecture

### Multi-Parser Strategy
- **SmsParserService**: Entry point that normalizes input and selects the appropriate parser
- **SmsMessageParser** (abstract): Base interface with `canParse()` and `parse()` contract
- **SaudiBankSmsParser**: SNB-specific parser with Arabic/English multi-pattern support
- **GenericSmsParser**: Fallback parser for any detected SMS content
- **_BaseSmsMessageParser**: Shared extraction logic (keywords, regex, scoring)

### Input Normalization
All incoming SMS text is cleaned before parsing:
- Remove hidden bidi directional marks (U+200E, U+200F, U+202A-202E, U+2066-2069, U+061C)
- Unify non-breaking spaces (U+00A0) to regular spaces
- Convert Arabic decimal separators (٫ → ., ٬ → ,)
- Convert Arabic-Indic digits (٠-٩ → 0-9, ۰-۹ → 0-9)

This ensures regex patterns match reliably regardless of hidden Unicode marks in real SMS.

## Enhanced Detection & Extraction

### Parser Selection
**SaudiBankSmsParser** activates when SMS contains at least one of:
- `بطاقة ائتمانية` (credit card)
- `التاريخ` (date marker in Arabic)
- `الصرف المتبقي` (remaining balance in Arabic)

Once selected, parser uses explicit line-by-line strategy instead of fragile single-keyword checks.

### Amount Extraction (Two-Pass)
1. **Pass 1 (Labeled)**: Prioritize lines containing `مبلغ` (amount) or `amount`
2. **Pass 2 (Plain)**: Fallback to any line with currency pattern if labeled lines absent
3. **Scoring**: 
   - Line after transaction line = score 3 (highest confidence)
   - Transaction line itself = score 2
   - Other lines = score 1

### Balance Line Rejection
Explicitly ignore lines containing any of:
- `المتبقي` (remaining)
- `الرصيد` (balance)
- `remaining balance`
- `available balance`
- `balance`
- `available`

### Merchant Extraction
Prefer lines starting with:
- `من <merchant>` (Arabic: "from")
- `from <merchant>` (English)
- `at <merchant>`

### Date/Time Extraction
Support both formats:
- ISO: `YYYY-MM-DD HH:mm`
- Slash: `DD/MM/YY HH:mm`

Prefers lines explicitly marked with `التاريخ` (date) keyword.

### Ambiguity Handling
If multiple distinct amounts score equally, **leave amount null** rather than guess.

## Test Coverage

### Test Suite (12 tests, 100% passing)
1. **English card purchase** - basic fallback case
2. **Arabic SNB without مبلغ label** - uses plain amount
3. **SNB with مبلغ label** - prefers labeled amount
4. **SNB with hidden bidi marks** - normalization coverage
5. **Amount then currency format** - `46.00 SAR`
6. **Currency then amount format** - `SAR 87.25`
7. **Mixed Arabic/English** - hybrid SMS support
8. **Ambiguous multiple amounts** - safely returns null
9. **Hardened: Arabic SNB balance test** - `46.00` NOT `5859.81`
10. **Hardened: English-like with balance** - ignores `900.00` balance
11. **Hardened: Generic mixed (USD)** - `125.00` NOT `2000.00`
12. **Hardened: Low-confidence SMS** - keeps fields null/empty

### Production SMS Scenarios Tested
- ✅ Real SNB Arabic with hidden bidi marks
- ✅ English-like format with balance line
- ✅ Generic mixed Arabic/English transaction
- ✅ Low-confidence SMS (no clear pattern)
- ✅ Ambiguous multiple amounts (safe fallback)

## Field Population Contract

### Parse Result Fields
```dart
class SmsParseResult {
  final String rawText;
  final double? amount;          // null if uncertain
  final String? currencyCode;    // null if missing
  final DateTime? spentAt;       // null if no date found
  final String? merchant;        // null/empty if unclear
  final String? suggestedCategory; // null if no match
}
```

### UI Integration
**SmsExpenseScreen** maps parsed result to form controllers with safe fallbacks:
- Amount → `_amountController` (if not null)
- Currency → `_currencyController` (fallback to trip.baseCurrency)
- Merchant → `_titleController` (if not empty)
- Date → `_expenseDate` (if not null)
- Category → `_selectedCategory` (fallback logic: Food → Starbucks/restaurant, Transport → uber/taxi, Other → default)
- Payment Method → auto-detected from SMS content (Apple Pay → Mobile Wallet, بطاقة → Credit Card, etc.)

## Verification Status

### Code Quality
- ✅ No analyzer errors or warnings
- ✅ All 12 tests passing (parser + parser-specific)
- ✅ Zero hardcoded Magic strings (all localized via l10n)

### Manual Testing
- ✅ App launches cleanly on emulator-5554
- ✅ SMS screen accessible and functional
- ✅ Parse button triggers correct flow

### Production Readiness
- ✅ No AI/OCR dependencies
- ✅ No device SMS permissions required
- ✅ No network calls
- ✅ Fully deterministic and testable
- ✅ RTL/Arabic support verified
- ✅ Beta label stays visible on SMS action

## Design Principles Applied

1. **Empty is Better Than Wrong**: Uncertain fields left null/empty, never guessed
2. **Explicit Over Implicit**: Clear parser selection and line-by-line extraction
3. **Fail Safe**: Generic parser fallback ensures something is always attempted
4. **Normalization First**: Clean input before attempting pattern matching
5. **Score-Based Confidence**: Higher-confidence amounts scored higher
6. **Multi-Pattern Support**: Handles Arabic, English, mixed, and generic formats

## Known Limitations (By Design)

- Category suggestion remains rule-based, not ML-powered (per requirements)
- No OCR for image-based SMS
- No network-based merchant validation
- Merchant extraction assumes line-start pattern (works for real SMS)
- Currency defaults to trip.baseCurrency if missing (safe fallback)

## Future Enhancements (Out of Scope)

- Additional bank parsers (optional, framework supports)
- User-configurable parser rules (out of scope)
- Merchant logo lookup (would require network)
- ML-based category suggestion (violates no-AI constraint)

## Conclusion

The SMS parsing system is now **hardened, tested, and ready for Phase 1 closure**. It safely handles multiple real-world SMS format variations, avoids confidence-breaking wrong values, and maintains complete determinism for testing and validation.

The multi-parser architecture is extensible for adding more bank-specific parsers in the future without breaking existing functionality.

---
**Status**: ✅ Phase 1 Hardening Complete - Awaiting User Confirmation (تم)
