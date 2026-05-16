# Financial Conversion Model

**Version**: 1.0  
**Date**: May 16, 2026  
**Purpose**: Define product rules for currency conversion across cash and card payment channels

---

## Product Principle

The app should help the traveler understand **approximate spending value**, not manage forex accounting.

We do NOT expose accounting terms like:
- Lots
- FIFO
- FX ledger
- Forex management
- Revaluation

This is a **traveler's expense tracking app**, not an accounting system.

---

## Two-Channel Model

Travel spending occurs through two distinct payment channels, each with different conversion mechanics.

### Channel 1: Cash Transactions (Pooled Model)

**Rule 1: No Per-Expense Exchange Rate**

Cash expenses do NOT ask for exchange rate per expense. The user enters only:
- Amount spent in local currency
- Category
- Date

The effective rate is determined by the cash pool state at spend time, not by individual transaction rates.

---

### Cash Pool Mechanics

**Rule 2: Single Effective Rate Per Pool**

Each trip's cash has ONE effective exchange rate, calculated as:

```
effective_rate = total_estimated_home_currency_value / total_cash_amount
```

Example:
```
User enters initial cash:
  - 50,000 THB
  - Estimated cost: 5,250 SAR
  
Effective rate = 5,250 / 50,000 = 0.105 SAR per THB
```

All cash expenses use this pool-level rate until the pool is updated.

---

**Rule 3: Pool Updates Only on Cash Inflow**

The cash pool (and thus its effective rate) is updated ONLY when new cash enters the trip:

1. **Initial cash setup** — User enters starting cash amount + home currency value
2. **ATM withdrawal** — User enters ATM amount + home currency charged
3. **Exchange office conversion** — User enters exchange amount + home currency paid
4. **Other cash inflow** — Manual adjustments for cash received from other travelers, etc.

Between inflows, the pool rate remains static.

---

**Rule 4: User Provides Approximate Home-Currency Value**

When cash enters the trip, the user provides:
- **Cash amount** (in local currency)
- **Approximate home-currency cost** (what it cost in their home currency)

The system derives the effective rate from these two inputs. The user is NOT asked to enter the exchange rate explicitly.

```
Example Input:
  Cash: 50,000 THB
  Home Value: 5,250 SAR
  
System Output:
  Effective Rate: 0.105 SAR per THB
```

---

**Rule 5: Cash Pool State Per Trip**

Each trip maintains:
- **Total cash amount** (in local currency)
- **Total estimated home-currency value** (in home currency)
- **Effective rate** (calculated)

When the user spends cash, the expense is tracked at the current pool rate.

---

### Channel 2: Card Transactions (Per-Expense Model)

**Rule 6: Card Transactions MAY Have Per-Expense FX Rate**

Card payments settle at rates determined by the card network and bank, not by the traveler. Each card transaction may settle at a different rate.

---

**Rule 7: Derive Card FX Rate from Bank SMS**

If the bank SMS includes both:
- Foreign amount (transaction currency)
- Home-currency charged amount (settlement amount)

The system derives the card FX rate from this transaction:

```
card_fx_rate = home_currency_amount / foreign_amount

Example SMS:
  "Payment to Restaurant: 250 THB charged as 26.25 SAR"
  
Derived Rate: 26.25 / 250 = 0.105 SAR per THB
```

This rate is transaction-specific and does not affect the cash pool.

---

## Reporting Model (Future)

**Rule 8: Transparent Cash Inflow Table (Optional)**

In future reports, we may display a transparent cash inflow history:

| Event | Amount | Home Value | Effective Rate |
|-------|--------|------------|-----------------|
| Initial setup | 50,000 THB | 5,250 SAR | 0.105 |
| ATM withdrawal | +20,000 THB | +2,100 SAR | 0.105 |
| After withdrawal | 70,000 THB | 7,350 SAR | 0.105 |
| Exchange office | +10,000 THB | +980 SAR | 0.098 |
| After exchange | 80,000 THB | 8,330 SAR | 0.104125 |

This table helps the traveler understand:
- How much cash entered the trip
- What it cost in home currency
- How the effective rate evolved

---

## Conversion Rules Summary

| Aspect | Cash | Cards |
|--------|------|-------|
| **Exchange Rate** | Pool-level (single rate per trip) | Per-transaction (from bank SMS) |
| **Rate Update Trigger** | Cash inflow only (initial, ATM, exchange office) | Every card transaction (if rate available in SMS) |
| **User Input** | Cash amount + home currency cost | Amount + category + date (rate derived from SMS if available) |
| **Rate Calculation** | estimated_home_value / cash_amount | foreign_amount / home_currency_amount |
| **Reporting** | Pool history (transparent inflow table) | Transaction-level rate (if available) |

---

## Implementation Constraints

- **No Database Changes** — Do not refactor cash/card storage
- **No Architecture Changes** — Preserve existing feature modules
- **No Accounting Concepts** — Keep UI language simple (traveler-friendly, not accountant-friendly)
- **Documentation Only** — This document establishes the model; code changes follow product validation

---

## FAQ

**Q: Why not ask the user for exchange rate per cash expense?**  
A: Travelers don't know exact rates when spending. The pool model reflects reality: the traveler has cash, it cost them something to acquire, and that's the relevant cost. Rate per expense is too precise and creates friction.

**Q: Why is card different from cash?**  
A: Bank SMS provides actual settlement rate per transaction. We use that data when available. Cash doesn't have per-transaction settlement data, so we use the pool model.

**Q: Can the cash pool rate change?**  
A: Yes, only when new cash enters. If the traveler withdraws 20,000 THB more, the pool may rebalance. The effective rate is recalculated after each inflow.

**Q: What if the traveler doesn't know the home-currency cost of cash?**  
A: The app should provide guidance (e.g., "Enter what the ATM charged in your home currency" or "Approximate the cost based on your last exchange rate"). Rough estimates are acceptable.

**Q: Do we track forex P&L?**  
A: No. We're not an accounting tool. The model is descriptive (what did you spend?) not prescriptive (how much did you profit/lose on forex?).

---

## Next Steps

1. **Design Phase** — Create wireframes for cash inflow UI (initial setup, ATM, exchange office)
2. **Validation Phase** — Test with users to confirm the model feels natural
3. **Implementation Phase** — Update data layer and UI to match this model (if approved)
