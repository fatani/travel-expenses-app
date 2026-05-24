# Stage 3.2 — Cash Wallet UX Polish Plan

> **Scope constraint:** Clarity · Calmness · Trust  
> **Not in scope:** Features · Analytics · Forecasting · Architecture changes

---

## 1. Executive UX Assessment

### What emotional experience does the screen currently create?

The screen is **closer to an accounting ledger than a travel companion.**

A first-time user arriving at the Cash Wallet today encounters:

- A hero card with a label called **"Cash health"** — a clinical, judgmental metric that fires the moment they open the screen, even before they've added a single coin.
- The word **"Critical"** can appear immediately on a zero-balance wallet, which feels alarming rather than neutral or inviting.
- The **"Balances by currency"** section appears before transactions, suggesting the primary concern is multi-currency accounting rather than "how much cash do I have right now."
- The **"Last ATM: N/A"** line on the hero card is meaningless noise until an ATM withdrawal exists — it reads like a debug label on an empty database.
- The Add Cash sheet has **two separate helper texts** for the home value field (`helperText` + `bodySmall caption`), saying exactly the same thing twice.
- The onboarding title "How much cash are you carrying?" is good, but the skip buttons ("Skip" vs "I'll use cards only") create a visual fork that makes a new user feel they're choosing between two product philosophies rather than just deferring a step.
- **"Manual Adjustment"** as a transaction type label is pure accounting jargon. A traveler never thinks "I need to make a manual adjustment."
- **"Currency exchange out"** as a visible label in the transaction list is invisible to any non-finance user.
- The balance tile subtitle shows a full timestamp (`dd MMM yyyy, HH:mm`) that serves no purpose — no user needs to know exactly when their balance was last updated.

**Net assessment:** The screen is technically correct and financially solid. But it speaks like a bank's back-office system rather than a calm, helpful travel companion. The emotional register is: *anxious, dense, over-explained.* It should be: *clear, calm, honest, instant.*

---

## 2. UX Problems (Prioritized)

---

### HIGH Priority

---

**H1 — "Cash health" fires at zero / empty state → creates instant anxiety**

- **Psychological impact:** The word "Critical" appearing before the user has done anything creates a false alarm. The system is judging them for having no data.
- **Product impact:** This is a trust-breaking moment at the worst time — first contact.
- **Affects:** Trust · Calmness · Onboarding tone
- **Current behavior:** `_CashHealth.critical` is returned when `currentBalance <= 0`. This includes the pre-setup state (balance = 0 before any data).
- **Severity:** HIGH

---

**H2 — "Last ATM: N/A" is noise until it has real data**

- **Psychological impact:** "N/A" reads as a broken or missing data field. It draws the eye and delivers nothing.
- **Product impact:** Adds visual weight to the hero card with zero informational return.
- **Affects:** Calmness · Visual noise
- **Severity:** HIGH

---

**H3 — "Manual Adjustment" label — accounting jargon**

- **Psychological impact:** No traveler uses this mental model. It creates friction when trying to understand what the option does.
- **Product impact:** Users either skip it or use it incorrectly, reducing data quality.
- **Affects:** Usability · Wording clarity
- **Severity:** HIGH

---

**H4 — Duplicate helper text in Add Cash sheet (home value field)**

- **Current state:** `helperText: l10n.cashWalletHomeValueHelper` AND a separate `Text(l10n.cashWalletHomeValueCaption)` widget below it — both say "Optional — helps estimate your home currency spending." — verbatim duplicates.
- **Psychological impact:** Feels like the app is nervous and over-explaining. Reduces trust.
- **Affects:** Visual noise · Trust
- **Severity:** HIGH

---

**H5 — Onboarding skip row creates a confusing binary fork**

- **Current state:** Two buttons side-by-side: `TextButton("Skip")` and `OutlinedButton("I'll use cards only")`.
- **Psychological impact:** "Skip" and "I'll use cards only" feel like they do different things — but both just call `Navigator.pop(false)`. The user has to think. Any thinking during onboarding = friction.
- **Affects:** Onboarding calmness · Usability
- **Severity:** HIGH

---

**H6 — "Balances by currency" section appears before context is established**

- **Psychological impact:** The first thing below the hero card is a list of currency balances — which is useful for multi-currency trips but confusing on first use when it's empty or shows one currency.
- **Product impact:** For a single-currency trip, this section adds zero value but takes up space.
- **Affects:** Information hierarchy · Visual noise
- **Severity:** HIGH

---

### MEDIUM Priority

---

**M1 — "Currency exchange out" is invisible to non-finance users**

- **What it means:** Cash was given *to* the exchange desk (outflow). But "exchange out" sounds like receiving foreign currency.
- **Affects:** Wording clarity · Transaction readability
- **Severity:** MEDIUM

---

**M2 — Balance tile subtitle shows full timestamp — low-value data**

- **Current:** `dd MMM yyyy, HH:mm` (e.g., "24 May 2026, 14:33") shown as the subtitle of every currency balance tile.
- **Psychological impact:** Forces the user to process a timestamp they don't need and can't act on.
- **Affects:** Visual noise · Information density
- **Severity:** MEDIUM

---

**M3 — "Balance after transaction" in the transaction list — information overload**

- **Current:** Every transaction tile shows "Balance after transaction: 450 SAR" as a subtitle line.
- **Psychological impact:** This is useful for understanding a ledger, not for a casual "what happened" glance. It adds 1–2 extra lines of text to every row.
- **Proposed:** Collapse this to a secondary/dimmed line, or show it only on tap/expand, not by default.
- **Affects:** Information density · Transaction readability
- **Severity:** MEDIUM

---

**M4 — "Cash Wallet" as the screen/app label — "wallet" is a bank word**

- **Psychological impact:** "Wallet" implies digital payments, cards, stored value. This app tracks physical cash.
- **Potential alternatives:** "Cash Tracker," "My Cash," "Travel Cash"
- **Affects:** Emotional framing · Product identity
- **Severity:** MEDIUM

---

**M5 — Hero card title "Cash remaining" + subtitle "Available cash for this trip" — redundant**

- **Current:** Two lines that say the same thing in different words.
- **Psychological impact:** Feels padded. The number itself says "cash remaining." The subtitle adds nothing.
- **Affects:** Visual noise · Hierarchy
- **Severity:** MEDIUM

---

**M6 — "Add cash balance" vs "Add Cash" — two labels for the same CTA in different screens**

- In the hero card (has-setup state): `l10n.cashBalanceAddCashAction` = "Add cash balance"
- In the hero card (no-setup state): `l10n.cashWalletAddCash` = "Add Cash"
- In the onboarding sheet save button: `l10n.cashWalletAddCash` = "Add Cash"
- **Psychological impact:** Inconsistent CTA labels for the same action erode trust and create micro-confusion.
- **Affects:** CTA clarity · Trust
- **Severity:** MEDIUM

---

**M7 — "Cash tracking hasn't started" — used as both a status and a hero card headline**

- The string `cashTrackingNotStarted` ("Cash tracking hasn't started") AND `cashBalanceNoRecordedWarning` ("Cash tracking hasn't started") are identical — they map to the same string in both the hero card title and somewhere else. One of these is redundant.
- **Affects:** Wording clarity · Trust
- **Severity:** MEDIUM

---

**M8 — AppBar title "Cash Wallet" — context redundancy**

- The user already has a `_TripContextCard` at the top of the screen showing the trip name. The AppBar saying "Cash Wallet" adds no navigational clarity.
- **Proposed:** AppBar title = trip name (or "Cash" if you need brevity).
- **Affects:** Hierarchy · Context clarity
- **Severity:** MEDIUM

---

### LOW Priority

---

**L1 — Transaction time group header style (purple, w800) is visually heavy**

- **Current:** `color: Color(0xFF6D28D9), fontWeight: FontWeight.w800` for "Today" / "Yesterday" / "Earlier"
- **Proposed:** Lighter weight (`w600`), smaller size, and a muted color (`0xFF94A3B8`). Group headers should recede, not compete with transaction titles.
- **Affects:** Visual rhythm · Calmness
- **Severity:** LOW

---

**L2 — "Search..." hint text is too generic**

- **Current:** `cashWalletSearchHint = "Search..."`
- **Proposed:** "Search country or currency"
- **Affects:** Usability (minor)
- **Severity:** LOW

---

**L3 — The `_TripContextCard` duplicates data already in AppBar context**

- The trip name, destination, currency, and dates are visible in the context card. If the AppBar also shows the trip name, there is duplication.
- **Severity:** LOW (contextual card is actually useful — the AppBar title is what should change)

---

**L4 — "Dates pending" fallback label is ambiguous**

- `cashWalletTripDatesPending = "Dates pending"` — if no dates are set, showing this as a chip may confuse users into thinking they need to do something.
- **Proposed:** Simply don't show the date chip if dates aren't set.
- **Severity:** LOW

---

**L5 — Delete confirmation says "This will reverse its effect on the balance" — too technical**

- **Proposed:** "Your cash balance will be updated."
- **Affects:** Wording calmness
- **Severity:** LOW

---

## 3. Recommended UX Changes

---

### RC-1 — Suppress "Cash health" pill until meaningful data exists

| | |
|---|---|
| **Current** | Health pill always renders: shows "Critical" when balance ≤ 0 (including initial empty state) |
| **Proposed** | Only render the health pill after `totalCashIn > 0` for the primary currency. Before that: no pill, or a neutral "Getting started" state with no color coding |
| **Reasoning** | The health indicator is meaningful only after the user has established a baseline. Showing "Critical" at zero is a false alarm that causes anxiety at first use. |
| **Difficulty** | Small — one `if (_hasCashSetup && totalCashIn > 0)` guard around the `_HeroPill` widget |

---

### RC-2 — Hide "Last ATM" line until an ATM withdrawal exists

| | |
|---|---|
| **Current** | Always renders: "Last ATM: N/A" when no withdrawal exists |
| **Proposed** | Render this line only when `lastAtmWithdrawalEvent != null` |
| **Reasoning** | "N/A" is noise. The user doesn't need to know there's an ATM field that's empty. |
| **Difficulty** | Small — one `if (lastAtmWithdrawalEvent != null)` guard |

---

### RC-3 — Collapse the duplicate home value helper text

| | |
|---|---|
| **Current** | `helperText` on the TextField + a separate `Text` widget below it — both identical |
| **Proposed** | Keep only the `helperText` on the TextField. Remove the standalone `Text` widget. |
| **Reasoning** | Saying the same thing twice signals insecurity. One clear explanation is more trustworthy than two. |
| **Difficulty** | Small — delete 6 lines of code |

---

### RC-4 — Replace the onboarding skip row with a single quiet link

| | |
|---|---|
| **Current** | Two buttons: `TextButton("Skip")` and `OutlinedButton("I'll use cards only")` — both do `Navigator.pop(false)` |
| **Proposed** | Single centered `TextButton`: "I'll add cash later" — one tap, one path, no decision required |
| **Reasoning** | Both buttons do the same thing. The visual fork creates false complexity at the most sensitive moment. "I'll add cash later" is honest, calm, and non-judgmental. |
| **Difficulty** | Small — replace 12 lines with 6 |

---

### RC-5 — Move "Balances by currency" below "Recent transactions"

| | |
|---|---|
| **Current** | Order: Hero card → Balances by currency → Recent transactions |
| **Proposed** | Order: Hero card → Recent transactions → Balances by currency |
| **Reasoning** | The most actionable information for a traveling user is "what just happened" (transactions), not "what is my multi-currency accounting state" (balances). The balance total is already shown in the hero card. The breakdown by currency is secondary detail. |
| **Difficulty** | Small — swap two sections in the `ListView` children list |

---

### RC-6 — Suppress balance tile timestamp subtitle

| | |
|---|---|
| **Current** | Each balance tile shows `dd MMM yyyy, HH:mm` as subtitle |
| **Proposed** | Remove the timestamp entirely. The tile is: currency code (title) + amount (trailing). That's sufficient. |
| **Reasoning** | The user does not care when the balance was last computed. This timestamp adds visual weight with zero decision-making value. |
| **Difficulty** | Small — remove one `subtitle` property from `_BalanceTile` |

---

### RC-7 — Make "Balance after transaction" collapsed by default

| | |
|---|---|
| **Current** | Always visible as a subtitle line on every transaction tile |
| **Proposed** | Show it only when the transaction tile is expanded (a gentle downward chevron), OR reduce it to a dimmed `bodySmall` with less visual weight so it doesn't compete with the transaction type label |
| **Reasoning** | Most users glance at the list to understand what happened, not to audit a running ledger. The running balance is important information but secondary to the transaction label and amount. |
| **Difficulty** | Medium — requires adding an expansion widget or a visual hierarchy rework of the tile |

---

### RC-8 — Normalize CTA label to "Add Cash" everywhere

| | |
|---|---|
| **Current** | "Add Cash" (no-setup hero) vs "Add cash balance" (has-setup hero) vs "Add Cash" (onboarding sheet save) |
| **Proposed** | Unify to "Add Cash" for all three instances |
| **Reasoning** | Consistent CTAs reduce cognitive micro-friction. The user shouldn't have to wonder if these two buttons do different things. |
| **Difficulty** | Small — update one ARB string (`cashBalanceAddCashAction`) |

---

### RC-9 — Conditionally show "Dates pending" chip

| | |
|---|---|
| **Current** | Always shows "Dates pending" chip when trip has no dates |
| **Proposed** | Don't render the date `_InfoChip` at all when dates are absent |
| **Reasoning** | "Dates pending" implies a to-do. The chip is passive information, not an action. Better to show nothing than show something that looks like a broken state. |
| **Difficulty** | Small — one null check |

---

## 4. Copywriting Improvements

---

### CW-1 — Cash Health Labels

| Current | Proposed | Reasoning |
|---|---|---|
| `Critical` | `Running low` | "Critical" is an alarm-level word. "Running low" is honest and calm. |
| `Low` | `Getting low` | Softer, less alarming |
| `Healthy` | `Looking good` | More human, less clinical |
| `Excellent` | `In great shape` | Warm, conversational |
| `Cash health` (pill label) | `Cash status` | "Health" is a medical metaphor. "Status" is neutral. |

---

### CW-2 — Transaction Type Labels

| Current | Proposed | Reasoning |
|---|---|---|
| `Initial cash` | `Starting cash` | More natural. "Initial" is a form field word. |
| `ATM withdrawal` | `ATM withdrawal` | ✅ Keep — this is already clear and universally understood |
| `Exchange office` | `Exchange office` | ✅ Keep — good, human label |
| `Currency exchange out` | `Exchanged away` | "Out" is direction-neutral jargon. "Exchanged away" explains the direction in plain English. |
| `Manual adjustment` | `Other cash added` | ✅ Already updated in ARB — this is correct, keep it |
| `Cash expense` | `Cash expense` | ✅ Keep — clear and direct |

---

### CW-3 — Hero Card Copy

| Current | Proposed | Reasoning |
|---|---|---|
| `Cash remaining` (title) | *(remove — the number speaks for itself)* | The hero number IS the message. A title above it is redundant labeling. |
| `Available cash for this trip` (subtitle) | *(remove — or keep as `for {trip.destination}` only if needed)* | Redundant with the screen context. If kept, add the destination for personalisation. |
| `Cash tracking hasn't started` | `No cash added yet` | More direct. Avoids the meta-commentary ("tracking hasn't started"). |
| `Current cash balance is unknown until you add an initial balance.` | `Add your starting cash to begin tracking.` | Shorter, action-oriented, removes the word "unknown" which sounds broken. |
| `Current cash balance is unknown. Cash expenses were recorded before adding an initial balance.` | `Some expenses were recorded before adding starting cash — your balance may not reflect them yet.` | Honest, but calm. Removes "unknown" and explains what happened without blame. |

---

### CW-4 — Add Cash Sheet Labels

| Current | Proposed | Reasoning |
|---|---|---|
| `How much cash are you carrying?` (onboarding title) | `How much cash are you starting with?` | "Carrying" sounds like they need to answer right now in the airport. "Starting with" is a calm planning question. |
| `Add Cash` (onboarding sheet title, same as CTA) | `Starting Cash` | The title and the save button currently say the same thing. Differentiate: title = context, button = action. |
| `Cash amount` (field label) | `Amount` | Already has a currency selector next to it. "Cash amount" is redundant given the context. |
| `Cash currency` (field label) | `Currency` | Same — context already established. |
| `Cash source` (dropdown label) | `Where did this come from?` | The current helper text is `cashWalletTransactionTypeHelper = "Where did this cash come from?"`. The label and helper say the same thing. Keep only the helper, or promote it to label. |
| `Optional — helps estimate your home currency spending.` (duplicate) | Remove one copy entirely | See RC-3 |
| `Approximate home value (optional)` (field label) | `Value in {homeCurrency} (optional)` | More specific. The word "approximate" implies imprecision anxiety before the user has typed anything. |
| `Edit cash entry` (sheet title) | `Edit entry` | "Cash" is already the context of the entire screen. No need to repeat it in every title. |

---

### CW-5 — System / Status Messages

| Current | Proposed | Reasoning |
|---|---|---|
| `Last ATM: N/A` | *(hidden until real data)* | See RC-2 |
| `This will reverse its effect on the balance.` | `Your cash balance will be updated.` | "Reverse its effect" is a software concept. "Will be updated" is the user-visible outcome. |
| `No cash balances yet.` | `No balances to show yet.` | Warmer, sounds less like an error. |
| `No cash transactions yet.` | `No activity yet.` | Shorter. The section header already says "Recent cash transactions." |
| `Dates pending` | *(hide chip entirely)* | See RC-9 |
| `I'll use cards only` (onboarding button) | *(remove — replace with single "I'll add cash later")* | See RC-4 |
| `Skip` (onboarding button) | *(remove — fold into single "I'll add cash later")* | See RC-4 |

---

### CW-6 — Screen / Navigation Labels

| Current | Proposed | Reasoning |
|---|---|---|
| `Cash Wallet` (AppBar title) | Trip name — or `Cash` | "Wallet" is a bank/fintech word. The screen is not a wallet, it's a cash tracker. Using the trip name (from `_TripContextCard`) reinforces context without repeating it. |
| `Balances by currency` (section header) | `By currency` | Shorter. The section is inside a cash wallet — "balances" is implied. |
| `Recent cash transactions` (section header) | `Activity` | One word, warm, universally understood. Removes jargon. |

---

## 5. Information Hierarchy Recommendations

### What should appear FIRST

The primary answer to the user's only real question — **"How much cash do I have right now?"** — must be the single most prominent thing on screen.

**Proposed hierarchy (top to bottom):**

1. **Trip context chip** — small, anchoring (keep as is, already good)
2. **Hero card** — the balance number, LARGE. Nothing else competing with it.
3. **Primary CTAs** — "Add Cash" and "ATM" (already in hero card — good)
4. **Recent activity** — "Activity" section (transactions)
5. **By currency breakdown** — secondary detail (move below transactions)

### What should be REDUCED

- Hero card title/subtitle text block — currently 2 lines before you even see the number. Either remove both, or keep only the subtitle as `bodySmall` metadata, not a featured heading.
- Health pill — reduce visual prominence. Make it `bodySmall` level, not `bodyMedium w800`. It's supplementary context, not a headline.
- Balance tile timestamp — remove entirely (see RC-6).
- "Balance after transaction" row in transaction tiles — reduce visual weight.

### What should be HIDDEN until relevant

- Health pill — hidden until `totalCashIn > 0` (RC-1)
- "Last ATM" line — hidden until an ATM withdrawal exists (RC-2)
- "Dates pending" chip — hidden when dates are null (RC-9)
- The "Balances by currency" section itself could be collapsed by default when there is only one currency — shown expanded only for multi-currency trips.

---

## 6. Empty State & Onboarding Recommendations

### Empty State — "No cash setup"

**Current behavior:** Hero card shows a travel image + "Cash tracking hasn't started" + helper text + two CTAs.

**What works:** The image is warm. Two CTAs (Add Cash / ATM) are correct.

**What to fix:**
- The title "Cash tracking hasn't started" is meta-commentary, not a human message. → Replace with `"No cash added yet"`.
- The body text starting with "Current cash balance is **unknown**" uses an alarming word for what is actually a neutral state (no data entered). → Replace with `"Add your starting cash to begin tracking."` (one sentence, action-forward).

### Empty State — "Expenses before cash setup"

**Current behavior:** Shows "Current cash balance is unknown. Cash expenses were recorded before adding an initial balance."

**What to fix:**
- "unknown" feels broken. Rephrase to be honest but calm: `"Some expenses were recorded before adding starting cash — your balance may not reflect them yet."`
- This is not an error. It's an edge case. Tone should match: informational, not alarming.

### Onboarding Sheet (First Use)

**Current behavior:** Auto-opens `_AddCashSheet` with `isOnboarding: true`. Shows a reduced form (no type selector, no date/time). Two skip buttons at the bottom.

**What works:** Auto-opening on first visit is smart — removes the need for the user to discover the feature. The simplified form is correct product thinking.

**What to fix:**

1. **Title:** `"How much cash are you carrying?"` → `"How much cash are you starting with?"` (calmer, less urgent)
2. **Sheet title vs. CTA conflict:** Both the sheet header and the save button currently say "Add Cash." Differentiate: sheet title = `"Starting Cash"`, save button = `"Save"` or `"Let's go"`.
3. **Skip row:** Replace two buttons (`Skip` + `I'll use cards only`) with one centered `TextButton`: `"I'll add cash later"`. Both buttons did the same thing (`Navigator.pop(false)`). The cognitive load of two options is unjustified.
4. **Home value field in onboarding:** This field is optional and adds complexity for a first-time user. Consider showing it collapsed/hidden in onboarding mode, with a `"+ Add home value"` expander. Most users should not see it on first run.

### Financial Profile Onboarding

**Current state:** "Where do you live?" + "Choose your home country so the app can set your home currency."

This is actually quite good. The question is direct and human.

**Minor suggestion:** The CTA button says `financialOnboardingContinue = "Continue"`. Consider `"Set my home currency"` to be more specific about what the user is doing — reduces anxiety about "what does continuing do."

---

## 7. Transaction List Polish Recommendations

### Current state assessment

Each transaction tile currently renders (top-to-bottom, left-to-right):

- **Title:** Transaction type label (e.g., "ATM withdrawal") — good
- **Subtitle line 1:** `dd MMM yyyy, HH:mm | note` — the timestamp format is overly precise
- **Subtitle line 2:** "Balance after transaction: 450 SAR" — always visible
- **Subtitle line 3 (conditional):** Action buttons (Edit expense / Edit / Delete)
- **Trailing:** Signed amount with +/- color coding — good

**Problems with density:**
- A single transaction tile can span 4–5 lines of content. On a screen with 10 transactions, this creates a wall of text.
- The timestamp `dd MMM yyyy, HH:mm` is overkill since transactions are already grouped by Today / Yesterday / Earlier. Once grouped, users only need the time, not the full date.

**Proposed improvements:**

1. **Timestamp format:** Within Today/Yesterday groups → show only time (`HH:mm`). In "Earlier" group → show `dd MMM`. Remove full `yyyy` from all in-group display.
2. **"Balance after transaction":** Reduce to `bodySmall` with color `0xFF94A3B8` — present but not competing. Or make it appear only on a long-press / expand gesture.
3. **Action buttons (Edit / Delete):** These are currently always visible on editable transactions, which adds 1–2 rows of buttons to every applicable tile. Consider replacing with a swipe action or a `...` (more) icon on the trailing edge that reveals a bottom sheet with options. This would clean up the tile significantly. *(This is the most impactful visual change in this section.)*
4. **Transaction type label color:** Currently `Color(0xFF1F2937)` — neutral, correct. Keep.
5. **Note display:** Currently concatenated with `|` separator: `"24 May 2026, 14:33 | Taxi"`. Consider showing the note on a separate line at `bodySmall` level with an italic style — cleaner visual separation.

---

## 8. Health / Status Label Recommendations

### Should "Cash Health" exist at all?

**Yes — but with conditions.**

The concept of health is useful because it answers the emotional question "am I in trouble?" without requiring the user to do math. The problem is not the concept, it's the activation conditions and the vocabulary.

**Current logic issues:**
- Health = `critical` when `balance <= 0`. This fires on empty wallets too.
- Health = `good` when `totalCashIn <= 0` (defensive fallback). This is internally inconsistent: if there's no data, why is health "good"?

**Proposed activation rules:**

| Condition | Show health? | Display |
|---|---|---|
| No cash setup (`!_hasCashSetup`) | No | Hidden entirely |
| Cash setup but `totalCashIn <= 0` | No | Hidden entirely |
| `remainingRatio >= 0.65` | Yes | `In great shape` (green-tinted) |
| `remainingRatio >= 0.35` | Yes | `Looking good` (neutral) |
| `remainingRatio >= 0.15` | Yes | `Getting low` (amber) |
| `remainingRatio < 0.15` | Yes | `Running low` (warm red) |
| `balance <= 0` with prior inflows | Yes | `Out of cash` (red) |

**Visual weight recommendation:**
- Downgrade the health pill from `bodyMedium w800 [valueColor]` to `labelMedium w600`. It should feel like a status badge, not a headline.
- The pill's white rounded container already does good visual work. The text inside should be quieter.

**Position:** Keep in the hero card (correct placement). But ensure it's visually subordinate to the balance number — the number is truth, the health label is context.

---

## 9. Stage 3.2 Suggested Scope

### Must Do Now
*(High-trust, low-risk, high-calm-return)*

| ID | Change | Difficulty |
|---|---|---|
| RC-2 | Hide "Last ATM: N/A" until real data | Small |
| RC-3 | Remove duplicate home value helper text | Small |
| RC-4 | Replace onboarding skip fork with single "I'll add cash later" | Small |
| RC-6 | Remove balance tile timestamp subtitle | Small |
| RC-8 | Normalize CTA to "Add Cash" everywhere | Small |
| RC-9 | Hide "Dates pending" chip when no dates | Small |
| RC-1 | Suppress health pill until `totalCashIn > 0` | Small |
| RC-5 | Move "Balances by currency" below "Recent activity" | Small |
| CW-1 | Replace health labels (Critical→Running low, etc.) | Small |
| CW-2 | Fix "Currency exchange out" → "Exchanged away" | Small |
| CW-3 | Hero card copy (remove redundant title/subtitle) | Small |
| CW-4 | Onboarding sheet copy (title, field labels, CTA) | Small |
| CW-5 | Delete confirmation wording | Small |
| CW-6 | Section headers → "Activity" / "By currency" | Small |

All of these are **ARB string changes + minor widget guards**. No architecture changes. No new screens. Combined effort: 1–2 focused sessions.

---

### Should Do
*(Medium impact, slightly more careful execution)*

| ID | Change | Difficulty |
|---|---|---|
| RC-7 | Reduce "Balance after transaction" visual weight | Medium |
| TL-1 | Timestamp format in transaction list (time-only within group) | Small |
| TL-2 | Note display on separate line | Small |
| HS-1 | Health pill visual downgrade (labelMedium w600) | Small |
| HS-2 | Fix health logic: `good` fallback when no data → hidden | Small |
| M4 | Rename screen/section from "Cash Wallet" to "Cash" or "Travel Cash" | Medium (involves AppBar + navigation labels) |

---

### Can Wait
*(Lower urgency, or requires more user testing before deciding)*

| ID | Change | Difficulty |
|---|---|---|
| TL-3 | Replace inline Edit/Delete buttons with swipe-to-reveal or `...` menu | Medium–Large |
| M4 | Full rename of "wallet" concept throughout | Medium |
| FO-1 | Hide home value field in onboarding until expanded | Medium |
| FO-2 | Collapse "By currency" section for single-currency trips | Small–Medium |
| FP-1 | Change financial onboarding CTA to "Set my home currency" | Small — but needs Arabic translation review |

---

## 10. Final Recommendation

### Should Stage 3.2 remain lightweight or become larger?

**Stay lightweight. Deliver high-impact, low-risk changes only.**

Here is the honest calculation:

The "Must Do Now" column above is **14 changes** — all of them small. They touch ARB strings, a few conditional widget guards, and section order in a `ListView`. None of them introduce new state, new providers, new screens, or new architecture. The risk of regression is nearly zero.

Together, these 14 changes will:
- Eliminate all false-alarm UX (Critical health on empty wallet, N/A ATM, "unknown balance")
- Remove every piece of duplicate or noisy text
- Replace all accounting jargon with human language
- Calm the onboarding to a single, confident path
- Correct the information hierarchy so the number is king

The "Should Do" items are worth a Stage 3.2.1 pass (same philosophy, slightly more effort).

The "Can Wait" items should be deferred until you have real user feedback on the "Must Do Now" changes — they involve behavioral shifts (swipe gestures, section collapsing) that need validation.

**The goal of Stage 3.2 is not redesign. It is subtraction.** Every item in the "Must Do Now" list removes something — noise, duplication, jargon, or a false alarm. The screen after Stage 3.2 should feel noticeably calmer despite looking almost identical. That is the right kind of polish.

---

*Document produced for: Travel Expenses Pro — Stage 3.2 UX Polish Planning*  
*Scope: Planning & review only. No code changes in this stage.*
