# Stage 1.9.4 — First Expense Experience Audit
**CalmLedger · First Expense Journey · Based on actual code review**
**Date: 2026-05-30**

---

## 1. Executive Summary

The Quick Add Expense sheet is **fundamentally sound**. The critical path — FAB → amount → category → save — is fast, focused, and respects the traveler's context. The amount field auto-focuses, categories auto-suggest based on amount, payment defaults to the last used method, and the save flow has proper guards against double-submission. The sheet can realistically be completed in under 8 seconds for a simple domestic expense.

However, **one structural gap is a blocking issue for travelers**: there is no currency switching inside Quick Add. The sheet is hardcoded to the trip's base currency. Any traveler spending in a different currency is silently forced into "Add Details" — losing the entire speed benefit of Quick Add.

Beyond that, there are several small but compounding UX frictions: the currency context is too quiet (just a bare currency code below the amount), the "Repeat last" feature copies the full amount and is too hidden to be discovered, and the "Other" payment chip stores no meaningful metadata, degrading reports silently.

**Overall Score: 6.5 / 10** — Good skeleton, one structural gap, several addressable frictions.

---

## 2. Time-To-First-Expense Analysis

### Minimum interaction count (happy path, single currency, domestic trip)

| Step | Interaction | Time estimate |
|------|-------------|--------------|
| 1 | Tap FAB | ~0.5s |
| 2 | Amount keyboard appears (auto-focus) | ~0.3s |
| 3 | Type amount (e.g., "45") | ~1.5s |
| 4 | Category auto-suggests — no tap needed | 0s |
| 5 | Payment defaults from last expense — no tap needed | 0s |
| 6 | Tap Save | ~0.5s |

**Realistic minimum: ~4–6 seconds.** This is excellent.

### First-time user (no prior expense, needs to set category manually)

| Step | Interaction | Time estimate |
|------|-------------|--------------|
| 1–3 | Same as above | ~2.5s |
| 4 | Category defaults to "Other" initially, then async-loads last used (delay) | ~0.5s flicker |
| 5 | User may tap a category manually | ~1s |
| 6 | Payment defaults to Cash (no prior expense) | 0s |
| 7 | Tap Save | ~0.5s |

**First-time realistic: ~5–7 seconds.** Still good.

### Multi-currency scenario (trip = SAR, expense = EUR)

The user has no currency switch option in Quick Add. They must:
1. Tap FAB → Quick Add opens
2. Notice the currency is wrong (requires reading the small "EUR" label below amount)
3. Tap "Add Details"
4. Complete the full Expense Form screen

**Multi-currency realistic: 25–40 seconds.** This is a major regression for international travelers.

### Friction Points Identified
- Async category preference load creates a brief "Other" → correct-category flicker on first open
- Currency label (just `"SAR"`) is too small and quiet to be noticed if wrong
- No date/time shown — user logging a past expense has no time reference

---

## 3. Friction Matrix

| # | Screen | Issue | Severity |
|---|--------|-------|----------|
| F1 | Quick Add | No currency switching — locked to trip base currency | **High** |
| F2 | Quick Add | "Card" chip always saves as Credit Card/POS — Mada (debit) users get mislabeled | **High** |
| F3 | Quick Add | Currency label is `"$currency"` only — no surrounding context ("in SAR" vs just "SAR") | **Medium** |
| F4 | Quick Add | Category defaults to "Other" while async prefs load — flicker on first open | **Medium** |
| F5 | Quick Add | "Repeat last expense" copies full amount — high risk of inadvertent wrong amount | **Medium** |
| F6 | Quick Add | "Repeat last expense" is styled in very light grey (94A3B8) — hard to discover | **Medium** |
| F7 | Quick Add | "Other" payment chip saves `method:'Other', channel:'Other'` — no data for reports | **Medium** |
| F8 | Quick Add | Merchant field sits between amount and categories — breaks cognitive scan order | **Low** |
| F9 | Quick Add | Recent merchants horizontal strip (height: 30px) — small tap target, may miss on some devices | **Low** |
| F10 | Quick Add | Sheet background hardcoded `Colors.white` — will break dark mode if ever added | **Low** |
| F11 | Quick Add | No trip name visible inside the sheet — user has no confirmation of which trip they're saving to | **Low** |
| F12 | Quick Add | Save button label is "Save" — in an empty state this is clear, but after "Repeat last" the user can't see what they're saving without reading all fields | **Low** |
| F13 | Trip Details | FAB appears only after expense data loads (`maybeWhen data`) — first render shows no FAB briefly on slow reads | **Low** |

---

## 4. Amount Entry

**Verdict: Strong — one small issue**

What works:
- `TextInputType.numberWithOptions(decimal: true)` → numeric keyboard appears immediately
- `textDirection: TextDirection.ltr` for the field, regardless of locale — correct for numbers
- Auto-focus via `addPostFrameCallback` — keyboard opens before the first frame settles
- Font size 30px centered — the amount is visually dominant and easy to type into
- Input formatter blocks all non-numeric characters except one decimal point — no invalid input possible
- Validation only shows after a save attempt — no premature error during typing
- Save button disabled until a valid positive amount — natural guide

What to fix:
- The `addPostFrameCallback` approach works but on slower devices there is a visible delay between sheet opening and keyboard appearing. If the sheet has a drag handle and animation, the user may start tapping before focus lands.

---

## 5. Category Selection

**Verdict: Good — auto-suggestion is genuinely useful**

What works:
- 6 categories is the right number for Quick Add (full form has 7 — "Visa" is correctly omitted as it's a rare, large, deliberate purchase)
- Wrap layout handles RTL and LTR naturally
- `ExcludeFocus` on all chips — keyboard does not dismiss when tapping category
- Smart two-tier suggestion system:
  - **Tier 1**: Adaptive memory — learns what category you use per amount range, per trip
  - **Tier 2**: Heuristic fallback (< 20 → Food, 20-80 → Transport, 80-300 → Shopping, 300+ → Accommodation)
- Once user manually picks, system stops suggesting (`_userSelectedCategory` guard)
- Category persisted per-trip in SharedPreferences

What to fix:
- On the very first open of a new trip, `_selectedCategory` starts as `"Other"` and the prefs load is async. The user sees "Other" selected for a fraction of a second before the last-used category loads. This flicker is subtle but perceptible.
- The category chips use a `GestureDetector + Container` pattern rather than `ChoiceChip`. This works but loses accessibility semantics (selected state, screen reader announcements). The payment chips correctly use `ChoiceChip` with `Semantics` wrappers — the same pattern should apply to category chips.

---

## 6. Payment Method Review

**Verdict: Conceptually right, one hidden data quality trap**

### Current Implementation
Three chips: **Cash / Card / Other**

Default behavior: inherited from the most recent expense's payment type via `quickAddPaymentChipKeyFromExpense`. If no prior expenses, defaults to Cash.

### What works
- Three choices is exactly right — any more would overwhelm
- Default inherits from last expense — smart for habitual travelers
- Cash and Card are universally understood labels
- `ExcludeFocus` prevents keyboard dismissal on chip tap

### Issues

**"Card" chip → Credit Card mislabeling (High)**
The "Card" chip maps directly to:
```
method: 'Credit Card'
channel: 'POS Purchase'
```
A Mada debit card user, or a Visa Debit user, will have all their expenses labeled "Credit Card" in reports. This is a silent data accuracy problem. The user never sees it in Quick Add — only in reports later.

**"Other" chip → empty metadata (Medium)**
The "Other" chip maps to:
```
method: 'Other'
channel: 'Other'
```
This has no reporting value. A user who pays via Apple Pay, bank transfer, or BNPL all land in the same "Other" bucket. The reports section cannot distinguish them. For a traveler, Apple Pay is common — it has no representation.

**Label clarity for first-time users**
- "Cash" — universally clear
- "Card" — clear (EN), "بطاقة" (AR) — clear
- "Other" — ambiguous; user must guess what it covers

---

## 7. Currency Review

**Verdict: Critical gap for the core use case**

### Current Behavior
`_selectedCurrencyCode = widget.trip.baseCurrency.trim().toUpperCase()`

The currency is locked to the trip's base currency. There is no UI to change it inside Quick Add. The only currency indicator is a small label below the amount field:
```dart
l10n.quickAddAmountInCurrency(displayCurrency)
// EN: "$currency" → literally "SAR" or "EUR"
// AR: "$currency" → literally "SAR" or "EUR"
```

### Problems

**No currency switching (High)**
The entire CalmLedger value proposition is multi-currency travel. A traveler in Turkey (trip = TRY) who stops at a USD duty-free shop has no way to record that as USD in Quick Add. They must abandon Quick Add and use "Add Details" — which defeats the purpose entirely.

The currency label helps only if the user notices it. In practice, users focus on the amount field and look down at the keyboard. A small "SAR" label above the keyboard will be read by ~30% of users in a hurry.

**The label itself is too quiet (Medium)**
`"$currency"` alone (e.g., just "EUR") provides no framing. A better pattern would be "in EUR" or "EUR amount" — something that reads as context, not just a code.

**"Repeat last expense" respects the prior expense currency** — this is correct behavior and is a good save for multi-currency power users who know the feature.

### Multi-currency flow reality
```
Traveler in Japan (trip = SAR):
├── Spending SAR (cash) → Quick Add works perfectly
├── Spending JPY → Must use Add Details (30–40s instead of 5s)
└── No feedback that this is happening → Silent friction
```

---

## 8. Merchant Review

**Verdict: Good implementation, questionable positioning**

### What works
- Truly optional — if left empty, category name is used as expense title (clean fallback)
- Up to 7 recent merchants shown as scrollable chips
- Deduplication is case-insensitive — correct
- Single pass over sorted expenses — efficient
- `ExcludeFocus` on chips — keyboard stays open

### Issues

**Field positioning (Low)**
The current layout order is:
1. Amount (large, centered)
2. Currency label
3. **Merchant field** ← here
4. Recent merchant chips
5. Category chips
6. Payment row
7. Save button

The merchant field interrupts the amount→category→payment cognitive flow. The user's natural scan is: "how much did I spend? → on what category? → how did I pay?" The merchant field lands in the middle of that flow and adds a decision point that may slow users down.

A more natural order would be: Amount → Category → Payment → Merchant (optional, last).

**Recent merchant strip height (Low)**
`SizedBox(height: 30)` for the horizontal chip strip. On devices with large fonts or in RTL layouts with longer text, chips may be clipped or the tap target too small. The minimum recommended touch target is 48px per Material guidelines.

**Discoverability**
The recent merchants only appear when `_recentMerchants.isNotEmpty`. On a first-time trip, this row is invisible — which is correct. But returning travelers who haven't named their merchants consistently will see no suggestions even if they have many expenses.

---

## 9. Repeat Last Expense Review

**Verdict: Feature exists but is hidden and slightly risky**

### Implementation
```dart
if (widget.expenses.isNotEmpty && !_showRepeatHint)
  TextButton(
    onPressed: _activateRepeatLast,
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.only(top: 0, bottom: 4),
    ),
    child: Text(
      l10n.tripDetailsRepeatLastExpense,
      style: theme.textTheme.labelMedium?.copyWith(
        color: const Color(0xFF94A3B8), // very light grey
      ),
    ),
  ),
```

### What works
- Only appears when there are prior expenses — contextually appropriate
- Disappears after activation to avoid confusion
- Shows a banner: "Same as last time" — good confirmation signal
- Copies: category, payment method, currency, amount, merchant title

### Issues

**Amount is copied (Medium)**
Repeating an expense of the same category does not mean the amount is the same. A daily lunch might be "Food / Card / 42 SAR" one day and "Food / Card / 38 SAR" the next. Copying the amount creates a "trap" — the user taps Repeat, sees the amount, assumes it's ready, taps Save without changing the amount, and records the wrong value silently.

**Poor discoverability (Medium)**
Color `0xFF94A3B8` is a very light grey. The button is positioned after "Add Details" at the bottom of the sheet — below the fold on smaller phones when the keyboard is open. Many users will never find this feature.

**No confirmation step**
Repeat activates instantly with no "Are you sure?" confirmation. The undo snackbar on the Trip Details screen partially mitigates this, but the user must notice the snackbar and act within its timeout.

---

## 10. Save Confidence

**Verdict: Mostly good — one silent assumption**

What is confirmed visually before save:
- Amount: visible in the large center field
- Category: highlighted chip
- Payment method: selected chip
- Merchant: text field content

What is NOT confirmed before save:
- **Currency**: only a small code label below the amount — easy to miss
- **Date/time**: always "now" — no display, no way to know if saving at the wrong time
- **Which trip**: sheet has no trip name header — for a user with multiple trips open, there is no confirmation

After save:
- Haptic feedback (`HapticFeedback.lightImpact`) — good
- Snackbar: "Expense added" + Undo — good
- If save fails: snackbar with error message — good
- Double-save guard (`_isSubmitting`) — good
- Double-open FAB guard (`_isOpeningQuickAdd`) — good

---

## 11. Error Prevention

**What is protected:**
- Non-numeric input blocked by `TextInputFormatter`
- Multiple decimal points blocked
- Negative amounts blocked (validation: `parsed <= 0`)
- Zero amount blocked
- Double-tap FAB guarded
- Double-tap Save guarded
- "Add Details" tap guarded (`_isOpeningMoreDetails`)

**What is unprotected:**

| Risk | Description |
|------|-------------|
| Wrong currency | User types amount in EUR but trip is SAR — saves silently as SAR |
| Wrong date | Sheet always saves `DateTime.now()` — backdating not possible in Quick Add |
| Repeat-amount trap | User taps "Repeat last" and saves without changing amount |
| Card-type mislabeling | Debit card user taps "Card" → silently saved as Credit Card |
| Empty merchant fallback | When merchant is empty, category name becomes the title — user may not realize "Transport" will appear as the expense name |

---

## 12. Travel Context Assessment

**Verdict: Feels like a speed form, not yet a travel tool**

### What feels travel-native
- Amount-first UX — the most important field leads
- Currency code shown below amount — acknowledges multi-currency reality
- Category auto-suggestion by amount range — understands traveler behavior patterns
- Recent merchants — remembers the trip's context
- Payment method defaults from last expense — respects current trip patterns
- Haptic feedback on save — feels like a completed action

### What feels generic
- Sheet is pure white, no visual identity connecting it to a trip or destination
- No date/time awareness — a traveler logging 3 purchases over 2 hours is saving them all at the same "now" time
- No trip name in the sheet header — disconnecting from context
- "Other" payment option with no further breakdown — doesn't account for Apple Pay, Google Pay, tap-to-pay, which are the dominant payment patterns for travelers abroad
- No currency switching — the most common traveler scenario (spending in local currency) is either already handled (if trip is set correctly) or completely broken (multi-stop trips)

### The core tension
Quick Add is designed for speed, and it succeeds at that. But travel inherently involves complexity: multiple currencies, multiple payment methods, expenses spread across time. The current sheet handles the simple case well and silently fails the complex case. A truly travel-native Quick Add would surface the most common travel complexity (currency switching) without sacrificing speed.

---

## 13. Quick Wins
*Small changes, large impact*

**QW-1: Add a currency tap target below the amount**
Wrap the currency label `LtrText(data: l10n.quickAddAmountInCurrency(...))` in a `GestureDetector` that opens a simple currency picker. The label already shows the currency code — making it tappable costs nothing in visual real estate and solves F1 (the biggest issue).
_Impact: Unblocks entire multi-currency use case for travelers. High impact, minimal UI change._

**QW-2: Change "Other" chip label to "Apple Pay / Other"**
Or use an icon (wallet icon) for the "Other" chip. This makes Apple Pay users feel seen without adding a 4th chip.
_Impact: Reduces first-time confusion. Zero code change beyond label string._

**QW-3: Don't copy the amount in "Repeat last"**
In `_applyRepeatFromExpense`, clear the amount field after applying other fields. Or pre-fill it but place cursor at the start so the user is prompted to type a new value.
_Impact: Prevents silent wrong-amount saves. One-line change._

**QW-4: Increase "Repeat last expense" button prominence**
Change color from `0xFF94A3B8` to `0xFF64748B` (the "Add Details" color) and add a repeat icon. This alone doubles discoverability without adding visual noise.
_Impact: Feature adoption improvement. One-line color change._

**QW-5: Fix category chip accessibility semantics**
Category chips use `GestureDetector + Container`. Replace with `ChoiceChip` or add explicit `Semantics(selected: isSelected)` wrapper — matching what the payment chips already do.
_Impact: Screen reader support, zero visual change._

**QW-6: Load category preference synchronously**
Move the last-used category into the QuickAdd constructor initialization, passed from Trip Details (which can pre-read SharedPreferences on screen load). Eliminates the "Other → correct category" flicker.
_Impact: Removes confusing first-frame state. Small refactor at the calling layer._

---

## 14. Medium-Term Opportunities
*Worth scheduling, not urgent*

**MT-1: Merchant field re-ordering**
Move merchant below categories and payment, not between amount and categories. The cognitive flow becomes: Amount → Category → Payment → (optional) Merchant. Users who skip merchant lose nothing. Users who want it find it naturally at the end.

**MT-2: "Card type" disambiguation for "Card" chip**
After tapping "Card", show a brief secondary row: Visa · Mastercard · Mada · Other. This doesn't add a screen — it expands inline. Solves the Credit Card / Debit Card mislabeling for Mada users, who represent a significant portion of the Saudi audience.

**MT-3: Trip name mini-header in the sheet**
Add a one-line trip name above the amount field (e.g., small grey text "Istanbul Trip"). Costs 12px of vertical space, adds significant context for users with multiple active trips.

**MT-4: Time display on save for backdating**
Show a small timestamp below the Save button: "Saving as today, 3:41 PM — change?" Tappable to reveal a compact time picker. Does not interrupt the main flow but surfaces when the user needs it.

**MT-5: Recent merchants chip height**
Increase `SizedBox(height: 30)` to `SizedBox(height: 36)` to meet minimum 36px touch target, or add `visualDensity: VisualDensity.comfortable`. Improves tap reliability on small devices.

---

## 15. Not Recommended

**NR-1: Full date/time picker in Quick Add**
Adding a date/time picker in Quick Add would cost 2+ additional interactions every time. The 95% case is "right now." Handle backdating in "Add Details." The friction cost outweighs the benefit.

**NR-2: Card profile selection in Quick Add**
Allowing users to pick a specific saved card (SNB Infinite, Al Rajhi Visa, etc.) inside Quick Add would require a picker or additional step. The medium-term "Card type" inline row (MT-2) is enough. Full card profile selection belongs in "Add Details."

**NR-3: Splitting the Quick Add sheet into two steps (amount → details)**
A multi-step Quick Add would feel like progress but is actually more interactions. The current single-screen model is correct for Quick Add. "Add Details" already handles the complex case.

**NR-4: Mandatory merchant field**
Making merchant required would break the speed contract. The category-as-fallback-title is the right design. Merchant should always remain optional in Quick Add.

**NR-5: Category icons in Quick Add chips**
Adding emoji or icons to category chips (🍔 Food, 🚕 Transport) might seem like a quick win but adds visual noise and maintenance cost. Text labels are already localized and short. Icons should only be considered if label space becomes constrained on small screens.

**NR-6: Live exchange rate display**
Showing "42 SAR ≈ 10.3 EUR" in Quick Add requires network access, introduces latency, adds cognitive load. This belongs in reports, not in the entry flow. Travelers need speed, not precision at the moment of entry.

---

## Final Score

| Dimension | Score |
|-----------|-------|
| Time-to-first-expense | 8/10 — Fast for simple case, broken for multi-currency |
| Amount entry | 9/10 — Well designed, minor autofocus timing issue |
| Category UX | 8/10 — Auto-suggestion is smart, accessibility gap |
| Payment method | 6/10 — Right count, mislabeling trap for debit users |
| Currency handling | 3/10 — No switching in Quick Add is a structural gap |
| Merchant entry | 7/10 — Good implementation, positioning issue |
| Repeat last expense | 5/10 — Feature exists but hidden and amount-copy is risky |
| Save confidence | 7/10 — Good feedback, silent currency assumption |
| Error prevention | 7/10 — Good on input, weak on semantic errors |
| Travel context | 6/10 — Speed-first but misses core travel complexity |

**Overall: 6.5 / 10**

The foundation is production-quality. Fix F1 (currency switching) and F2 (card mislabeling), then apply the Quick Wins. That raises this to 8.5/10 without restructuring anything.
