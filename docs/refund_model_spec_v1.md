# Refund Model Specification v1.0
# Final Version — Ready For Implementation

**Branch:** `true-cost-reporting-prelaunch`
**Date:** 2026-06-09
**Status:** Final — approved for implementation

---

## 1. Refund Entity

### 1.1 Table: `expense_refunds`

```sql
CREATE TABLE expense_refunds (
  id            TEXT     PRIMARY KEY,
  trip_id       TEXT     NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  expense_id    TEXT,                        -- nullable: standalone refund allowed
  amount        REAL     NOT NULL,
  currency_code TEXT     NOT NULL,
  home_amount   REAL,                        -- FX snapshot at time of entry
  home_currency TEXT,                        -- must match if home_amount is set
  destination   TEXT     NOT NULL,           -- 'cash' | 'card'
  note          TEXT,
  is_reversed   INTEGER  NOT NULL DEFAULT 0, -- 1 = cancelled, 0 = active
  reversed_at   TEXT,                        -- UTC ISO-8601, set when is_reversed = 1
  created_at    TEXT     NOT NULL
)
```

**Index:**
```sql
CREATE INDEX idx_expense_refunds_trip_expense
ON expense_refunds (trip_id, expense_id, destination, is_reversed, created_at);
```

### 1.2 Domain Model: `ExpenseRefund`

Fields mirror the table exactly.
- `id` — UUID string, generated on creation.
- `tripId` — required, always set.
- `expenseId` — optional link to the original expense.
- `amount` / `currencyCode` — the refunded amount in the transaction currency.
- `homeAmount` / `homeCurrency` — FX snapshot captured at entry time. Same semantics as `Expense.convertedHomeAmount`. Optional but required for Net Spending to be accurate.
- `destination` — enum: `RefundDestination.cash` | `RefundDestination.card`.
- `note` — optional, free text.
- `isReversed` — false on creation. Set to true on cancellation. Never toggled back.
- `reversedAt` — null on creation. Set to UTC now on cancellation. Immutable after set.
- `createdAt` — UTC, immutable after creation.

**Immutability rule:** A refund row is never updated except to apply a reversal. No field other than `isReversed` and `reversedAt` changes after creation.

### 1.3 Invariants

1. `amount > 0` always. A refund is never zero or negative.
2. If `homeAmount` is set, `homeCurrency` must also be set, and vice versa.
3. `destination` is always explicit — never inferred.
4. `expenseId`, when set, must reference an expense in the same `tripId`. Enforced at the repository layer, not by a DB foreign key.
5. **Over-refund is forbidden when `expenseId` is set and the linked expense has `convertedHomeAmount`.**
   Before inserting, the repository must query the active refund total for the same `expenseId`:
   ```
   existingRefundedHome = Σ home_amount
                          FROM expense_refunds
                          WHERE expense_id  = refund.expenseId
                            AND is_reversed = 0
                            AND home_currency = expense.homeCurrency
                            AND home_amount IS NOT NULL

   guard: existingRefundedHome + refund.homeAmount ≤ expense.convertedHomeAmount
   ```
   If the guard fails, the insert is rejected with a domain error — no database write occurs.
   When the expense has no `convertedHomeAmount`, or the refund has no `homeAmount`, the guard is skipped (insufficient data to enforce).

6. **`homeAmount` derivation is automatic when `expenseId` is set and the caller does not supply `homeAmount`.**
   See Section 1.4.

### 1.4 `homeAmount` Auto-Derivation

When a refund is linked to an expense (`expenseId` is set) and the caller does not supply `homeAmount`, the repository derives it automatically before the insert.

**Priority order:**

**1. Use `expense.conversionRate` directly (preferred):**
```
homeAmount   = refund.amount × expense.conversionRate
homeCurrency = expense.homeCurrency
```
Applies when `expense.conversionRate` is not null. This uses the exact FX rate that was snapshotted when the expense was recorded — the most accurate derivation.

**2. Fall back to proportional derivation:**
```
homeAmount   = (refund.amount / expense.transactionAmount) × expense.convertedHomeAmount
homeCurrency = expense.homeCurrency
```
Applies when `conversionRate` is null but `convertedHomeAmount` and `transactionAmount` are both present and `transactionAmount > 0`.

**3. No derivation:**
If neither condition above is met (`convertedHomeAmount` is null, or `transactionAmount` is zero), `homeAmount` remains null. No silent zero is injected.

**Caller-supplied `homeAmount` always takes precedence.** If the caller provides an explicit value, derivation is skipped entirely.

**Derivation is recorded as-is.** The derived `homeAmount` is stored in the `expense_refunds` row as a snapshot. It is never recomputed after creation.

---

## 2. Refund Types

| Type | `destination` value | Cash Wallet Effect | Gross Spending Effect | Net Spending Effect |
|---|---|---|---|---|
| Cash Refund | `'cash'` | Balance increases by `amount` in `currency_code` | None | Reduces net by `homeAmount` |
| Card Refund | `'card'` | None | None | Reduces net by `homeAmount` |

**Rule:** Refunds never modify the original expense. Gross Spending is the sum of `Expense.convertedHomeAmount` — unchanged in all cases. Net Spending is derived, not stored.

---

## 3. Cash Refund Flow

### 3.1 Write Path

Creating a cash refund is a **two-step atomic operation** inside a single database transaction:

**Pre-insert (outside the transaction):**
1. If `expenseId` is set and `homeAmount` is not supplied by the caller, derive `homeAmount` using the rules in Section 1.4.
2. If `expenseId` is set and `homeAmount` is now available, apply the over-refund guard (Section 1.3, Invariant 5). Reject before opening the transaction if the guard fails.

**Step 1 — Insert `expense_refunds` row**
```
destination   = 'cash'
is_reversed   = 0
reversed_at   = null
amount, currency_code, home_amount, home_currency (derived or supplied)
```

**Step 2 — Insert `cash_transactions` row**
```
type                 = CashTransactionType.cashRefund  (new enum value: 'cash_refund')
amount               = refund.amount
currency_code        = refund.currencyCode
home_currency_amount = refund.homeAmount               (may be null)
home_currency_code   = refund.homeCurrency             (may be null)
expense_id           = refund.expenseId                (may be null)
is_reversed          = 0
```

If either insert fails, both are rolled back. The two rows are created together or not at all.

### 3.2 Reversal

Cancelling a cash refund is a **two-step atomic operation** inside a single database transaction:

**Step 1 — Reverse the `expense_refunds` row:**
```
UPDATE expense_refunds
SET is_reversed = 1, reversed_at = <utc_now>
WHERE id = refund.id
```

**Step 2 — Reverse the linked `cash_transactions` row:**
```
UPDATE cash_transactions
SET is_reversed = 1, reversed_at = <utc_now>
WHERE expense_id = refund.id   -- or linked by the id recorded at creation
  AND type = 'cash_refund'
  AND is_reversed = 0
```

Both updates in one transaction. If either fails, both roll back.
`CashBalanceRecompute` automatically excludes reversed rows — the wallet balance is restored without any additional logic.

No row is ever deleted by user action.

### 3.3 Cash Balance Effect

`CashTransactionTypeDelta.signedDelta` for `cashRefund` returns `+amount`.
`CashBalanceRecompute` picks this up generically — no special handling required.

---

## 4. Card Refund Flow

### 4.1 Write Path

Creating a card refund is a **single insert** into `expense_refunds`.

**Pre-insert:**
1. If `expenseId` is set and `homeAmount` is not supplied by the caller, derive `homeAmount` using the rules in Section 1.4.
2. If `expenseId` is set and `homeAmount` is now available, apply the over-refund guard (Section 1.3, Invariant 5). Reject before the insert if the guard fails.

**Insert:**
```
destination   = 'card'
is_reversed   = 0
reversed_at   = null
amount        = refund amount in transaction currency
currency_code = refund currency
home_amount   = derived or caller-supplied (may be null)
home_currency = derived or caller-supplied (may be null)
expense_id    = linked expense id (strongly recommended, nullable)
```

No `cash_transactions` row is created. Cash wallet is not touched.

### 4.2 Multiple Partial Refunds

Multiple `expense_refunds` rows may reference the same `expense_id`. There is no limit. Net Spending sums all active rows (`is_reversed = 0`).

### 4.3 Reversal

Cancelling a card refund is a **single update**:

```
UPDATE expense_refunds
SET is_reversed = 1, reversed_at = <utc_now>
WHERE id = refund.id
```

No row is ever deleted by user action. No `cash_transactions` row is involved.

**Audit guarantee:** Every refund ever created — active or cancelled — is permanently recorded. The full history of a trip's refunds is always reconstructable from the database.

---

## 5. Reporting Rules

### 5.1 Gross Spending — Unchanged

```
grossSpendingHomeAmount = Σ expense.convertedHomeAmount
                          for all expenses where homeCurrency = tripHomeCurrency
```

`TripReportCalculator` receives only `List<Expense>`. Refunds are never passed to the gross loop. This is an invariant: the gross loop signature does not change.

### 5.2 Net Spending — New in Sprint 3

```
refundHomeTotal =
    Σ refund.homeAmount
      for all ExpenseRefund in trip
      where refund.isReversed  = false
        and refund.homeCurrency = tripHomeCurrency
        and refund.homeAmount  is not null

netSpendingHomeAmount = grossSpendingHomeAmount − refundHomeTotal
```

`netSpendingHomeAmount` is computed, never stored. It is added to `TripReportSummary` as a derived field.

**The `is_reversed = 0` filter is mandatory on every query that reads `expense_refunds` for reporting purposes.** A missing filter is a silent over-deduction bug.

### 5.3 `TripReportSummary` additions (Sprint 3)

```dart
final double? refundHomeAmount;       // null if no active refunds have home values
final double? netSpendingHomeAmount;  // null if gross is null
```

`netSpendingHomeAmount` is a computed getter: `grossSpendingHomeAmount - (refundHomeAmount ?? 0)`, returned as null when `grossSpendingHomeAmount` is null.

### 5.4 Currency Safety Rule

Refunds in a currency other than `tripHomeCurrency` are **excluded** from `refundHomeTotal`. Same guard as the gross loop. No silent currency mixing.

### 5.5 Refund does not affect transaction-currency totals

`TripReportSummary.totalBilledByCurrency` and `byTransactionCurrency` are sums over expenses only. Refunds are not subtracted from these buckets. They are gross buckets, not net.

---

## 6. Backup / Restore Contract

| Artifact | Change |
|---|---|
| `BackupEnvelope` | Add `expense_refunds` key; add constant `expenseRefundsKey = 'expense_refunds'`; add to `requiredPayloadKeys` |
| `BackupDataCollector` | Query `expense_refunds` table in snapshot transaction — **all rows including reversed** |
| `BackupManifest` | Add `refundCount` field (total rows, including reversed); validated as count gate |
| `BackupRestoreValidator` | Add referential integrity check: `refund.trip_id` must exist in `trips`; `refund.expense_id`, when set, must exist in `expenses`; add `destination` enum validation (`'cash'`, `'card'`); validate `is_reversed` is 0 or 1 |
| `BackupRestoreService._wipeAllTables` | Add `expense_refunds` before `expenses` in wipe order |
| `BackupRestoreService._insertRestoredRows` | Insert `expense_refunds` after `expenses` |
| `BackupPersistedEnums` | Add `cashTransactionTypes: 'cash_refund'`; add `refundDestinations: {'cash', 'card'}` |
| Old backups (no `expense_refunds` key) | Parsed leniently — missing key defaults to empty list; `refundCount` defaults to 0 if absent |

**Backup completeness:** Reversed refund rows are included in backups. A restored database contains full refund history — active and cancelled. `refundCount` in the manifest counts all rows regardless of reversal state.

**Forward-only rule:** A backup containing `expense_refunds` rows will be rejected by any app version that does not recognise the `expense_refunds` key in strict mode. This is accepted. Rollback to pre-refund app versions is not supported once refunds are recorded.

---

## 7. What is Explicitly Out of Scope (v1.0)

- Refund UI screens.
- Refund editing after creation (cancel and re-enter is the supported path).
- Refund within an SMS-parsed expense flow.
- Refund FX rate lookup from an external source — `homeAmount` is derived from the linked expense's existing snapshot (Section 1.4) or supplied by the caller. No live FX fetch.
- Budget impact from refunds.
- Per-category net spending.

---

*End of Specification v1.0 — Final Version*
