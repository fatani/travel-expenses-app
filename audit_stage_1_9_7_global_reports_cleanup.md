# Stage 1.9.7 — Global Reports & Dead Insight Cleanup Audit

**Auditor role:** Senior Product UX Auditor · Reporting Integrity Reviewer · Flutter Architecture Analyst  
**Date:** 2026-06-01  
**Scope:** Audit only. No implementation. No code changes.

---

## 1. Executive Summary

The global report architecture is fundamentally sound and multi-currency honest. The core principle — never mixing currencies, always reporting totals per currency — holds throughout the calculator, domain model, and UI.

However, the report has accumulated four distinct categories of dead weight:

1. **Five `GlobalReportInsightType` enum variants** that the calculator never emits — dead rendering code in `_localizeInsight`.
2. **`InsightType.fees`** — declared in the enum, handled in UI rendering, handled in `TripReportCalculator`, but never emitted by `InsightEngine`. Fully dead path.
3. **`averageSpendPerTripByCurrency` and `averageDailySpendByCurrency`** — correctly computed, correctly tested, stored in the summary, have l10n keys — but never rendered anywhere in `GlobalReportsScreen`. Invisible to users.
4. **One empty state gap**: trips exist but zero expenses shows an empty `_OverviewCard` shell with no explanatory message.

The three "smart insights" that do fire (`currencyDistribution`, `categoryVariation`, `paymentVariation`) all describe facts the user can already see directly in the data below them. They add noise without adding signal.

The `activeTrips` field name is internally misleading but the l10n key already uses the correct label ("Trips with expenses"), so UX is not broken.

---

## 2. Current Global Report Architecture

### Data flow

```
GlobalReportProvider
  → GlobalReportCalculator.calculate(trips, expenses)
      → GlobalReportSummary (domain model)
          → GlobalReportsScreen (UI)
              → InsightEngine.build(expenses) → List<Insight>  (behavioral)
              → _buildSmartInsights(...)      → List<GlobalReportInsight>  (structural)
```

### What is rendered in `GlobalReportsScreen`

| UI Section | Condition |
|---|---|
| `_EmptyGlobalReportsState` | `!summary.hasTrips` |
| `_SingleTripNoteCard` | `totalTrips == 1` |
| `_SmartSummaryHeroCard` | `totalExpenseCount >= 3 && smartInsights.isNotEmpty` |
| `_BehavioralInsightsSection` | `behavioralInsights.isNotEmpty` |
| `_SummaryCards` | Always (when trips exist) |
| `_OverviewCard` | Always (when trips exist) |
| `_CurrencyBucketList` | `totalBilledByCurrency.isNotEmpty` |

### What is computed but NOT rendered

- `averageSpendPerTripByCurrency` — computed, stored, tested. Never referenced in `GlobalReportsScreen`.
- `averageDailySpendByCurrency` — same.
- `summary.topCategory` — identical value to `summary.dominantCategory`, never read in the UI. Duplication.

### `GlobalReportInsightType` — emitted vs. declared

| Variant | Emitted by calculator | UI switch case | Status |
|---|---|---|---|
| `currencyDistribution` | ✅ | ✅ | Live |
| `categoryVariation` | ✅ | ✅ | Live |
| `paymentVariation` | ✅ | ✅ | Live |
| `dominantPaymentChannel` | ❌ | ✅ | Dead |
| `dominantCategory` | ❌ | ✅ | Dead |
| `averageSpendPerTrip` | ❌ | ✅ | Dead |
| `dominantCurrency` | ❌ | ✅ | Dead |
| `internationalDomesticRatio` | ❌ | ✅ | Dead |

Five dead variants. All handled by `_localizeInsight` switch, all with l10n strings. None reachable at runtime.

---

## 3. Global Smart Insights Review

These are `GlobalReportInsight` objects produced by `_buildSmartInsights()` and rendered in `_SmartSummaryHeroCard`.

### `currencyDistribution`
**Text shown:** "You spent in multiple currencies across your trips"

**Assessment: Obvious observation.**  
The currency breakdown list (`_CurrencyBucketList`) already shows every currency with its total directly beneath. This insight tells the user something they can read in the very next card. It contains zero additional information.

**Threshold:** fires when `uniqueTransactionCurrencyCount > 1`. That means any trip with even one foreign purchase triggers it.

### `categoryVariation`
**Text shown:** "Your spending was spread across more than one category"

**Assessment: Noise.**  
Nearly every user who has logged more than 3 expenses will have more than one category. This is the default condition, not a notable pattern. The trigger is `uniqueCategoryCount > 1` — a near-universal condition. The insight adds no value.

### `paymentVariation`
**Text shown:** "Your payment behavior varies across channels or networks"

**Assessment: Borderline noise.**  
Fires when `uniquePaymentChannelCount > 1 || uniquePaymentNetworkCount > 1`. A user who ever used both POS and online in any trip triggers this. The text is not actionable and not surprising. However, it is at least somewhat behavioral rather than purely structural.

**Overall verdict on all three smart insights:**  
They describe structure ("you have N currencies", "you have N categories") rather than patterns. They fire on low thresholds. They tell users what is already visible immediately below them. The `_SmartSummaryHeroCard` has prominent visual design (gradient card, star icon, large title) but its content does not justify that prominence. The card exists but what it says is weak.

The `take(2)` cap means at most two of the three are shown. In the common multi-currency, multi-category case, both slots are consumed by the two most obvious observations.

---

## 4. Dead Insight Review

### `InsightType.fees`

**Location of declaration:** `lib/features/insights/domain/insight.dart`

**Engine (`InsightEngine`):** Only builds `spike` and `categoryDrift`. No code path in `InsightEngine.build()` ever produces an `Insight` with `type: InsightType.fees`. The engine never emits it.

**UI handling in `GlobalReportsScreen`:**
```dart
// _behavioralInsightTitle:
InsightType.fees => context.l10n.globalReportsBehavioralInsightTitleFees,

// _behavioralInsightDescription:
InsightType.fees => context.l10n.globalReportsBehavioralInsightFees(insight.percentage ?? 0),
```
Both switch arms exist but are unreachable at runtime.

**UI handling in `TripReportCalculator`:**
```dart
case InsightType.fees:
  return Insight converted to TripReportInsightType.feesPercentage
```
This path is reachable only if an `Insight(type: InsightType.fees)` is produced upstream. It is not.

**L10n keys that exist (used nowhere at runtime):**
- `globalReportsBehavioralInsightTitleFees` → "Fees"
- `globalReportsBehavioralInsightFees` → "Fees are about {percentage}% of spending."

**Fee data that exists:** `Expense.feesAmount` and `Expense.feesCurrency` are real fields. `TripReportCalculator` aggregates them into `feesByCurrency`. Fee data collection infrastructure exists.

**Decision:**

| Option | Assessment |
|---|---|
| Implement it now | Not scoped for this stage. Fee tracking works at trip level; global fee insight requires cross-trip fee aggregation and a minimum data threshold. |
| Remove it | Cleanest option now. Remove `InsightType.fees` from the enum, remove the two dead UI switch arms in `GlobalReportsScreen`, remove the dead arm in `TripReportCalculator`. L10n keys can be retained or removed. |
| Leave it | Creates confusion: the enum, UI, and trip calculator all have the arm but it never fires. Future contributors will wonder if it's intentional. |
| Document it | Minimum if not removed: a comment on the enum variant explaining it is not yet emitted. |

**Recommendation: Remove `InsightType.fees` from the enum and all three dead switch arms.** The fee tracking infrastructure in expense and trip data is separate and is not affected. If a fees behavioral insight is implemented in the future, it can be re-added with intentional design.

---

## 5. Average Metrics Review

### `averageSpendPerTripByCurrency`

**Computed:** Yes. In `_buildAveragePerTripMetrics()`: `bucket.totalAmount / tripCount` per currency. Correct — no cross-currency mixing.

**Tested:** Yes. `global_report_calculator_test.dart` lines 144, 223 verify the math.

**L10n key:** `globalReportsAveragePerTrip` → "Average spending per trip" ✅

**Rendered:** ❌ Not referenced anywhere in `GlobalReportsScreen`.

**Is it useful?** Yes. "Average per trip per currency" is genuinely meaningful for a traveler who has made multiple trips. "My average SAR trip costs X" is a usable benchmark.

**Multi-currency truthfulness:** Safe. The metric is per-currency, not summed. A user with SAR and USD trips gets two separate averages, not a blended lie.

**Edge case: single trip.** `averageSpendPerTripByCurrency` when `totalTrips == 1` just returns the full trip total as the "average." This is mathematically correct but semantically odd — the average of one trip is the trip itself. The UI already shows `_SingleTripNoteCard` for this case, so this would be suppressed there.

**Edge case: multi-currency trips.** If a user has 3 trips (2 in SAR, 1 in USD), the SAR average is `total_SAR / 3` and the USD average is `total_USD / 3`. This is not misleading — it reflects "over all trips, what did I spend on average in this currency," not "per trip that used this currency." That distinction should be labeled clearly if rendered.

### `averageDailySpendByCurrency`

**Computed:** Yes. `bucket.totalAmount / trackedTripDays` per currency.

**Tested:** Yes. Line 145 verifies the math.

**L10n key:** `globalReportsAveragePerDay` → "Average daily spending" ✅

**Rendered:** ❌ Not referenced in `GlobalReportsScreen`.

**Is it useful?** Conditionally. If `trackedTripDays` is the sum of all trip durations (which it is: `sum of endDate - startDate + 1 for all trips`), then this is "total spent in this currency / total tracked days across all trips." For a traveler who does many same-currency trips this is useful. For a traveler whose SAR spending was on one 2-day trip out of 30 tracked days, the figure is deflated and misleading.

**The deeper problem:** `trackedTripDays` includes days from all trips regardless of whether expenses exist in that currency during those days. A user with 10 SAR trips and 1 USD trip: the USD average daily is computed by dividing total USD spend over the combined days of all 11 trips — most of which had no USD expenses. The result looks numerically small and is semantically wrong.

**Decision:**
- `averageSpendPerTripByCurrency`: **Worth rendering.** It is correct, tested, has l10n. Render it, suppressed when `totalTrips <= 1`.
- `averageDailySpendByCurrency`: **Do not render as-is.** The `trackedTripDays` denominator is global (all trips) while the numerator is per-currency. This produces deflated, misleading daily averages in multi-currency scenarios. Either fix the denominator (track days per currency, which requires a design decision) or suppress it entirely. For MVP: suppress rendering, leave the computed value in place since tests cover it.

---

## 6. "Active Trips" Label Review

**Field:** `GlobalReportSummary.activeTrips`

**How it is computed:**
```dart
final activeTrips = relevantExpenses
    .map((expense) => expense.tripId)
    .toSet()
    .length;
```
This is a count of distinct trip IDs that appear in at least one expense. In other words: **trips that have at least one logged expense.**

**L10n label:** `globalReportsActiveTrips` → `"Trips with expenses"` ✅

The label in the UI is already correct. The field name `activeTrips` in the Dart code is the only misleader — "active" typically implies time-based status (ongoing vs. past), but here it means "has data." This is an internal naming issue only; the user never sees the field name.

**Verdict: No UX issue.** The label shown to users is accurate. The internal field name is misleadingly named but not worth a rename that touches the domain model, calculator, summary class, tests, and rendering code at this stage. Worth noting for a future rename if a true "active = currently in progress" concept is ever introduced (conflict risk is low but real).

---

## 7. Empty / Low Data State Review

### Zero trips
**State:** `!summary.hasTrips` → `_EmptyGlobalReportsState`  
**What the user sees:** "No trips yet" + "Add trip" button  
**Assessment:** ✅ Handled correctly. Clear and actionable.

### Trips exist but zero expenses
**State:** `summary.hasTrips` is true but `totalExpenseCount == 0`  
**What the user sees:**
- No `_SingleTripNoteCard` (only shows for 1 trip, not for "0 expenses")
- No smart insights (requires ≥ 3 expenses)
- No behavioral insights (requires ≥ 5 expenses)
- `_SummaryCards` renders with values `totalTrips: N, activeTrips: 0` — this is correct numerically
- `_OverviewCard` renders a card titled "Overview" with **no rows at all** — because all `uniqueCount` values are 0 or 1, all `if` guards are false, so the card is an empty box
- `_CurrencyBucketList` not shown (empty list)

**Assessment: ⚠️ UX gap.** A user who has created trips but logged no expenses sees a blank `_OverviewCard` shell. There is no message explaining why the report is empty. The correct behavior is to either hide `_OverviewCard` when it has nothing to show, or render an "Add expenses to see a report" message when `!summary.hasExpenses`.

### One trip
**State:** `totalTrips == 1`  
**What the user sees:** `_SingleTripNoteCard` ("Add more trips to compare across trips.") + rest of report if expenses exist  
**Assessment:** ✅ Handled. The note is honest — the global report is more meaningful with multiple trips.

**Edge case:** One trip with zero expenses → single trip note shown, but same empty `_OverviewCard` issue applies.

### Multiple trips with little data (< 3 expenses)
**State:** `totalExpenseCount < 3`  
**What the user sees:** No smart insights (suppressed correctly), no behavioral insights, summary cards, possibly an empty or near-empty `_OverviewCard`  
**Assessment:** ✅ Suppression thresholds are correct (3 for smart insights, 5 for behavioral). No false insights fire with thin data.

### Multi-currency global data
**State:** Multiple currencies across trips  
**What the user sees:** `_CurrencyBucketList` with separate totals per currency. `dominantCurrency` shown if multi-currency.  
**Assessment:** ✅ Multi-currency truthfulness is maintained throughout. No cross-currency totals are created anywhere in the calculator or UI.

---

## 8. Friction Matrix

| Finding | Type | Severity | Affects User |
|---|---|---|---|
| `averageSpendPerTripByCurrency` never rendered | Dead computed value | Medium | ✅ Yes — useful metric hidden from user |
| `averageDailySpendByCurrency` never rendered | Dead computed value with flawed denominator | Medium | ✅ Yes — hiding it is the right call, but the why is undocumented |
| `InsightType.fees` never emitted | Dead enum variant + 3 dead switch arms | Low | ❌ No user impact — purely internal noise |
| 5 dead `GlobalReportInsightType` variants | Dead enum variants + dead `_localizeInsight` arms | Low | ❌ No user impact — unreachable code |
| `topCategory` field duplicate of `dominantCategory` | Dead field in domain model | Low | ❌ No user impact |
| Empty `_OverviewCard` when 0 expenses | Missing empty state | Medium | ✅ Yes — blank card, no explanation |
| Smart insights describe obvious observations | Signal quality | Medium | ✅ Yes — hero card fires with low-value content |
| `paymentVariation` insight is near-universal | Near-always-true threshold | Low | ✅ Yes — minor noise |
| `categoryVariation` insight is near-universal | Near-always-true threshold | Medium | ✅ Yes — fires for virtually every user |
| `activeTrips` internal field name misleads contributors | Internal naming | Low | ❌ No user impact |

---

## 9. Quick Wins

These are low-risk, high-clarity improvements that require minimal code changes.

**QW-1: Remove `InsightType.fees` from the enum and all dead switch arms**
- `insight.dart`: remove `fees` case
- `global_reports_screen.dart`: remove two switch arms from `_behavioralInsightTitle` and `_behavioralInsightDescription`
- `trip_report_calculator.dart`: remove the unreachable `case InsightType.fees:` arm
- L10n keys: retain (removing them risks breaking something; they do no harm)
- Risk: none. These paths are provably unreachable.

**QW-2: Remove five dead `GlobalReportInsightType` variants**
- Remove `dominantPaymentChannel`, `dominantCategory`, `averageSpendPerTrip`, `dominantCurrency`, `internationalDomesticRatio` from the enum
- Remove their arms from `_localizeInsight` in `global_reports_screen.dart`
- Their l10n keys can be retained or removed
- Risk: low. Verify with `fvm flutter analyze` — compiler enforces exhaustive switch.

**QW-3: Remove duplicate `topCategory` field from `GlobalReportSummary`**
- `dominantCategory` and `topCategory` are identical at all times (`dominantCategory: topCategory` in constructor call)
- `topCategory` is never read in the UI — only `dominantCategory` is used in `_OverviewCard`
- Remove `topCategory` from `GlobalReportSummary` constructor and field
- Update `GlobalReportCalculator` to stop passing it
- Update tests if they reference `topCategory` directly
- Risk: low but touches domain model and calculator.

**QW-4: Fix empty state when trips exist but expenses = 0**
- In `_OverviewCard` or in `_GlobalReportBody`: add `if (!summary.hasExpenses)` guard
- Show a small explanatory message instead of an empty card shell
- Risk: minimal, single widget change.

---

## 10. Medium-Term Opportunities

**MT-1: Render `averageSpendPerTripByCurrency`**
- The computation is correct and multi-currency safe
- Condition: render only when `totalTrips >= 2` (average of one trip is trivial)
- Placement: inside `_OverviewCard` or as a separate section after currency totals
- Multi-currency handling: display one row per currency (same pattern as `_CurrencyBucketList`)
- Risk: low. Requires UI wiring only.

**MT-2: Fix `averageDailySpendByCurrency` denominator before rendering**
- Current denominator is `sum of all trip days` regardless of currency
- Correct denominator would be `sum of days for trips that contain at least one expense in that currency`
- This requires the calculator to track "which trip days used which currency" — a moderate data model change
- Do not render until the denominator is fixed
- Risk: medium if fixed; low if left suppressed.

**MT-3: Raise or redesign smart insight thresholds**
- `categoryVariation` fires when `uniqueCategoryCount > 1` — this is nearly universal
- `paymentVariation` fires when `uniquePaymentChannelCount > 1 || uniquePaymentNetworkCount > 1` — near-universal
- If smart insights are kept, they need higher thresholds or richer text (e.g., "80% of spending was in Food" rather than "your spending covered multiple categories")
- Alternatively: remove `categoryVariation` and `paymentVariation` from smart insights entirely and rely on the `_OverviewCard` facts to convey the same information more precisely

**MT-4: Implement `InsightType.fees` properly if desired**
- Infrastructure exists: `Expense.feesAmount`, `TripReportCalculator.feesByCurrency`
- What is missing: `InsightEngine` never computes a fees insight
- A global fees insight would need: sum of fee amounts across all expenses in a single currency, percentage of fees vs. total spend in that currency, minimum threshold (e.g., fees > 2% of spend)
- Multi-currency challenge: fees may be in a different currency than the transaction; this needs careful denominator handling
- Verdict: feasible but not trivial. Defer to a focused fees insight sprint.

---

## 11. Not Recommended

**❌ Do not render `averageDailySpendByCurrency` as-is.**  
The denominator (`trackedTripDays`) is global across all trips, making the per-currency daily average misleading for users with mixed-currency trip histories. Fix the denominator first.

**❌ Do not add cross-currency global totals.**  
The current architecture correctly refuses to sum across currencies. Do not introduce exchange rate assumptions to produce a "total in base currency" at the global report level.

**❌ Do not raise `_buildSmartInsights` complexity to compensate for weak thresholds.**  
If the thresholds are too low, the correct fix is to raise them or replace the insights with more specific text — not to add percentage logic and conditional branching to existing weak insights.

**❌ Do not add AI summaries or narrative text to the global report.**  
Out of scope. The problem here is signal quality, not prose quality.

**❌ Do not rename `activeTrips` field as a standalone change.**  
The UX label is already correct. A rename touches the model, calculator, tests, and screen with zero user-visible benefit at this stage.

**❌ Do not add charts.**  
The currency breakdown list is already readable. Charts require effort that is not justified by the current data density.

---

## 12. Final Recommendation

### Do now (Stage 1.9.7 cleanup)

1. **Remove `InsightType.fees`** — enum, three dead switch arms, no user impact, zero risk.
2. **Remove five dead `GlobalReportInsightType` variants** — enum and `_localizeInsight` switch arms.
3. **Remove duplicate `topCategory` field** from `GlobalReportSummary` and calculator.
4. **Fix the zero-expenses-but-trips-exist empty state** — hide or caption the empty `_OverviewCard`.

### Do next (Stage 1.9.8 or later)

5. **Render `averageSpendPerTripByCurrency`** — it is already computed, tested, and has a l10n key. Wire it to the UI when `totalTrips >= 2`.
6. **Reconsider `categoryVariation` and `paymentVariation` smart insights** — either raise thresholds significantly, replace with richer text, or remove them. `currencyDistribution` is at least somewhat meaningful (user may not notice they used foreign currencies). The other two fire too easily to carry information.

### Leave for later

7. **`averageDailySpendByCurrency`** — computation stays (tests pass), do not render until denominator is fixed.
8. **`InsightType.fees` behavioral insight** — feasible but needs dedicated design. Fee infrastructure is in place.

### Verification after implementation

After each change in this stage:
```
fvm flutter analyze
fvm flutter test
```

Pay particular attention to exhaustive switch warnings after enum variant removal — Dart's exhaustive switch enforcement is the safety net here.
