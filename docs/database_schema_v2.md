# Database Schema Specification v2.0
**CalmTrip Financial Core**
**تاريخ الإصدار:** 10 يونيو 2026
**الحالة:** APPROVED WITH ONE RECOMMENDATION — Applied
**يستبدل:** Schema v1 (database version 18)

---

## Scope & Assumptions

- لا يوجد مستخدمون في الإنتاج. البيانات التجريبية قابلة للحذف.
- الـ Schema هو المرجع الوحيد للبنية — لا migration plan مطلوب.
- قاعدة البيانات: SQLite مع `PRAGMA foreign_keys = ON` مُفعّل.
- جميع التواريخ: ISO 8601 UTC (`TEXT`).
- جميع المبالغ: `REAL` (IEEE 754 double) — الدقة مسؤولية طبقة التطبيق.
- جميع العملات: 3-letter ISO 4217 uppercase (`TEXT`).
- جميع الـ IDs الأولية: UUID v4 كـ `TEXT`، باستثناء الجداول التي تحتاج AUTOINCREMENT.
- الحذف دائماً Soft (is_reversed) لجميع الجداول المالية — لا hard deletes.

---

## Table Inventory

| # | Table | نوع | الدور |
|---|-------|-----|-------|
| 1 | `trips` | Core | سياق الرحلة المالي |
| 2 | `expenses` | Financial Event | تسجيل المصروفات |
| 3 | `cards` | Reference | بطاقات الدفع |
| 4 | `cash_lots` | Financial Lot | وحدات النقد FIFO |
| 5 | `cash_lot_consumptions` | Financial Event | استهلاك النقد من اللوتات |
| 6 | `cash_transactions` | Audit Trail | سجل كل حركة نقدية |
| 7 | `currency_exchanges` | Financial Event | عمليات الصرف كوحدة واحدة |
| 8 | `expense_refunds` | Financial Event | الاسترجاعات |
| 9 | `trip_cash_balances` | Derived Cache | الرصيد الجاري للأداء |
| 10 | `manual_exchange_rates` | Reference | معدلات الصرف اليدوية |
| 11 | `user_financial_profile` | Configuration | البيانات المالية للمستخدم |
| 12 | `settings` | Configuration | إعدادات التطبيق |

---

## Table Specifications

---

### 1. `trips`

**لماذا يوجد:**
الرحلة هي الحاوية المالية الأساسية. كل عملية مالية — مصروف، لوت نقدي، صرف، استرجاع — مرتبطة برحلة. تحتوي على ثلاث عملات تُشكّل السياق المالي الكامل للرحلة.

**القاعدة التجارية التي يدعمها:**
- الفصل بين عملة التشغيل (`base_currency`)، عملة الوجهة (`destination_currency`)، وعملة المنزل (`home_currency_snapshot`).
- الـ `home_currency_snapshot` ثابت لحظة إنشاء الرحلة — لا يتأثر بتغيير المستخدم للعملة الرئيسية لاحقاً.
- CASCADE DELETE يُنظّف كل البيانات المالية عند حذف الرحلة.

**المواصفة المرجعية:** Financial Domain Model v2.0 § Trip Context

```
trips
├── id                        TEXT        PRIMARY KEY
├── name                      TEXT        NOT NULL
├── destination               TEXT        NOT NULL
├── destination_country_code  TEXT
├── base_currency             TEXT        NOT NULL
├── destination_currency      TEXT        NOT NULL
├── home_currency_snapshot    TEXT        NOT NULL
├── start_date                TEXT                          -- ISO 8601, nullable
├── end_date                  TEXT                          -- ISO 8601, nullable
├── budget                    REAL        CHECK (budget IS NULL OR budget >= 0)
├── budget_currency           TEXT
├── is_custom_title           INTEGER     NOT NULL DEFAULT 0
├── created_at                TEXT        NOT NULL
└── updated_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (base_currency = UPPER(base_currency))
  CHECK (destination_currency = UPPER(destination_currency))
  CHECK (home_currency_snapshot = UPPER(home_currency_snapshot))
  CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date)
  CHECK (is_custom_title IN (0, 1))

INDEXES:
  None required beyond primary key.
```

---

### 2. `expenses`

**لماذا يوجد:**
يمثّل حدثاً مالياً يُقلّل ثروة المسافر. يحتوي على 5 طبقات مالية مستقلة لتغطية جميع سيناريوهات الدفع — نقد، بطاقة محلية، بطاقة دولية مع رسوم، SMS.

**التغيير من v1:**
- حذف الحقول القديمة: `amount`, `currency_code` (legacy layer مُزال).
- إضافة `payment_type` كعمود صريح بدلاً من الاستنتاج من `payment_method + payment_channel`.

**القاعدة التجارية التي يدعمها:**
- الفصل الصريح بين Cash Expense وCard Expense.
- الـ Conversion Snapshot ثابت ولا يُعاد حسابه (immutable historical fact).
- Cash expense: يُحسب `converted_home_amount` من SUM للوتات المستهلكة عبر FIFO.
- Card expense: يُحسب من معدل الصرف المقدّم أو اليدوي.

**المواصفة المرجعية:** Expense Recording Specification v1.0 § Expense Entity; Financial Domain Model v2.0 § Expense

```
expenses
│
├── -- Identity
├── id                        TEXT        PRIMARY KEY
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
├── title                     TEXT        NOT NULL
├── category                  TEXT
│
├── -- Payment Classification [MODIFIED from v1]
├── payment_type              TEXT        NOT NULL
│                                         CHECK (payment_type IN ('cash', 'card'))
│
├── -- Transaction Layer (what the user actually paid)
├── transaction_amount        REAL        NOT NULL  CHECK (transaction_amount > 0)
├── transaction_currency      TEXT        NOT NULL
│
├── -- Card Billing Layer (nullable — populated for card expenses only)
├── billed_amount             REAL        CHECK (billed_amount IS NULL OR billed_amount > 0)
├── billed_currency           TEXT
├── fees_amount               REAL        CHECK (fees_amount IS NULL OR fees_amount >= 0)
├── fees_currency             TEXT
├── total_charged_amount      REAL        CHECK (total_charged_amount IS NULL OR total_charged_amount > 0)
├── total_charged_currency    TEXT
│
├── -- Immutable Conversion Snapshot (write-once at creation time)
├── original_amount           REAL        CHECK (original_amount IS NULL OR original_amount > 0)
├── original_currency         TEXT
├── converted_home_amount     REAL        CHECK (converted_home_amount IS NULL OR converted_home_amount > 0)
├── home_currency             TEXT
├── conversion_rate           REAL        CHECK (conversion_rate IS NULL OR conversion_rate > 0)
│
├── -- Payment Metadata
├── payment_method            TEXT        NOT NULL
├── payment_network           TEXT
├── payment_channel           TEXT
├── card_profile_id           INTEGER     FK → cards(id) ON DELETE SET NULL
│
├── -- Classification Flags
├── is_international          INTEGER     NOT NULL DEFAULT 0
│
├── -- Source Tracking
├── source                    TEXT        NOT NULL DEFAULT 'manual'
│                                         CHECK (source IN ('manual', 'sms'))
├── note                      TEXT
├── raw_sms_text              TEXT
│
├── -- Timestamps
├── spent_at                  TEXT        NOT NULL
├── created_at                TEXT        NOT NULL
└── updated_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (transaction_currency = UPPER(transaction_currency))
  CHECK (home_currency IS NULL OR home_currency = UPPER(home_currency))
  CHECK (is_international IN (0, 1))
  -- Card-only fields must be NULL for cash expenses:
  CHECK (
    payment_type = 'cash' AND billed_amount IS NULL AND fees_amount IS NULL
    OR payment_type = 'card'
  )

FOREIGN KEYS:
  trip_id         → trips(id)  ON DELETE CASCADE
  card_profile_id → cards(id)  ON DELETE SET NULL

INDEXES:
  idx_expenses_trip_spent    ON expenses(trip_id, spent_at DESC)
  idx_expenses_trip_type     ON expenses(trip_id, payment_type)
  idx_expenses_trip_created  ON expenses(trip_id, created_at DESC)
```

---

### 3. `cards`

**لماذا يوجد:**
مرجع لبطاقات الدفع المسجّلة. يُتيح ربط المصروفات ببطاقة بعينها لأغراض التحليل.

**القاعدة التجارية التي يدعمها:**
- بطاقة واحدة يمكن أن تكون مرجعاً لمصروفات متعددة عبر رحلات متعددة.
- الحذف: SET NULL على expenses — حذف البطاقة لا يحذف المصروفات.

**المواصفة المرجعية:** Financial Domain Model v2.0 § Payment Instruments

```
cards
├── id                        INTEGER     PRIMARY KEY AUTOINCREMENT
├── name                      TEXT        NOT NULL
├── display_name              TEXT
├── bank_name                 TEXT
├── custom_bank_name          TEXT
├── card_network              TEXT
├── custom_card_network       TEXT
├── card_tier                 TEXT
├── custom_card_tier          TEXT
├── last4                     TEXT        CHECK (last4 IS NULL OR LENGTH(last4) = 4)
├── created_at                TEXT        NOT NULL
└── updated_at                TEXT        NOT NULL

INDEXES:
  None required beyond primary key.
```

---

### 4. `cash_lots` ⭐ NEW

**لماذا يوجد:**
هذا الجدول هو قلب التغيير الجوهري من v1 إلى v2. كل تدفق نقدي وارد (Initial Cash، ATM، Exchange In، Cash Refund، Manual Adjustment موجب) يُنشئ **Lot** مستقلاً بقيمة cost basis خاصة به. الـ FIFO يعني أن المصروفات تستهلك من أقدم اللوتات أولاً.

**لماذا يختلف عن Weighted Average:**
- Weighted Average يفقد هوية كل دفعة — كل النقد يُصبح كتلة واحدة بمعدل واحد.
- FIFO Lots يحتفظ بكل دفعة كوحدة مستقلة — متى دخلت، من أين، وبأي سعر.
- عند صرف العملة: cost basis ينتقل بدقة من lot العملة القديمة إلى lot العملة الجديدة.
- Net Trip Cost يصبح حساباً دقيقاً وليس تقريباً.

**القاعدة التجارية التي يدعمها:**
- FIFO Consumption: `ORDER BY created_at ASC` لتحديد أقدم lot.
- Cost Basis Tracking: `home_currency_amount` ثابت لحظة إنشاء الـ lot.
- Remaining Cash Value في التقرير: `SUM(remaining_amount × effective_rate)` للوتات الحية.

**المواصفة المرجعية:** Financial Core Gap Closure Plan § FIFO Engine; Trip Financial Report Specification v2.0 § Remaining Cash Value

```
cash_lots
│
├── id                        TEXT        PRIMARY KEY
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
│
├── -- Lot Identity
├── source_type               TEXT        NOT NULL
│                                         CHECK (source_type IN (
│                                           'initial_cash',
│                                           'atm_withdrawal',
│                                           'exchange_in',
│                                           'manual_adjustment',
│                                           'cash_refund'
│                                         ))
│
├── -- Source Traceability [ADDED per reviewer recommendation]
├── source_ref_type           TEXT        NOT NULL
│                                         CHECK (source_ref_type IN (
│                                           'cash_transaction',
│                                           'currency_exchange',
│                                           'expense_refund'
│                                         ))
├── source_ref_id             TEXT        NOT NULL
│                                         -- Polymorphic reference:
│                                         -- 'cash_transaction' → cash_transactions.id
│                                         -- 'currency_exchange' → currency_exchanges.id
│                                         -- 'expense_refund'    → expense_refunds.id
│
├── currency_code             TEXT        NOT NULL
│
├── -- Lot Amounts
├── original_amount           REAL        NOT NULL  CHECK (original_amount > 0)
├── remaining_amount          REAL        NOT NULL  CHECK (remaining_amount >= 0)
│
├── -- Cost Basis (write-once at lot creation)
├── home_currency_amount      REAL        CHECK (home_currency_amount IS NULL OR home_currency_amount > 0)
├── home_currency_code        TEXT
├── effective_rate            REAL        CHECK (effective_rate IS NULL OR effective_rate > 0)
│                                         -- Stored convenience: home_currency_amount / original_amount
│                                         -- Written once at creation, never updated
│
├── -- State
├── is_fully_consumed         INTEGER     NOT NULL DEFAULT 0  CHECK (is_fully_consumed IN (0, 1))
├── is_reversed               INTEGER     NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
├── reversed_at               TEXT
│
├── created_at                TEXT        NOT NULL
└── note                      TEXT

CONSTRAINTS:
  CHECK (remaining_amount <= original_amount)
  CHECK (currency_code = UPPER(currency_code))
  CHECK (home_currency_code IS NULL OR home_currency_code = UPPER(home_currency_code))
  CHECK (
    (home_currency_amount IS NULL AND home_currency_code IS NULL AND effective_rate IS NULL)
    OR
    (home_currency_amount IS NOT NULL AND home_currency_code IS NOT NULL AND effective_rate IS NOT NULL)
  )
  CHECK (is_reversed = 0 OR reversed_at IS NOT NULL)
  CHECK (is_fully_consumed = 0 OR remaining_amount = 0)
  CHECK (is_reversed = 0 OR is_fully_consumed = 1)
  -- source_type ↔ source_ref_type mapping:
  CHECK (
    (source_type IN ('initial_cash','atm_withdrawal','manual_adjustment')
      AND source_ref_type = 'cash_transaction')
    OR
    (source_type = 'exchange_in'
      AND source_ref_type = 'currency_exchange')
    OR
    (source_type = 'cash_refund'
      AND source_ref_type = 'expense_refund')
  )

FOREIGN KEYS:
  trip_id → trips(id) ON DELETE CASCADE
  -- source_ref_id: no DB-level FK (polymorphic) — enforced at application layer

INDEXES:
  -- Primary FIFO query index: "active lots for currency, oldest first"
  idx_cash_lots_fifo        ON cash_lots(trip_id, currency_code, is_reversed, is_fully_consumed, created_at ASC)
  -- Direct source traceability lookup:
  idx_cash_lots_source_ref  ON cash_lots(source_ref_type, source_ref_id)
  -- By source type:
  idx_cash_lots_source      ON cash_lots(trip_id, source_type)
```

**source_type ↔ source_ref_type Mapping:**

| source_type | source_ref_type | source_ref_id يشير إلى |
|-------------|-----------------|------------------------|
| `initial_cash` | `cash_transaction` | `cash_transactions.id` |
| `atm_withdrawal` | `cash_transaction` | `cash_transactions.id` |
| `manual_adjustment` | `cash_transaction` | `cash_transactions.id` |
| `exchange_in` | `currency_exchange` | `currency_exchanges.id` |
| `cash_refund` | `expense_refund` | `expense_refunds.id` |

**ملاحظة حول `effective_rate`:**
يُحسب ويُكتب مرة واحدة لحظة إنشاء الـ lot:
`effective_rate = home_currency_amount / original_amount`
يُخزَّن كـ convenience لتجنب القسمة عند كل استعلام. لا يُعدَّل أبداً.

---

### 5. `cash_lot_consumptions` ⭐ NEW

**لماذا يوجد:**
يُسجّل كل عملية استهلاك من lot بعينه. هذا هو الجدول الذي يُجسّد FIFO — كل مصروف نقدي أو عملية صرف تُنشئ سجلاً واحداً أو أكثر هنا (قد تمتد عبر عدة لوتات).

**مثال FIFO:**
مصروف نقدي بقيمة 150 USD:
- Lot A به 100 USD متبقية → consumption: 100 USD من Lot A
- Lot B به 80 USD متبقية → consumption: 50 USD من Lot B
- النتيجة: سجلّان في هذا الجدول مرتبطان بنفس expense_id

**القاعدة التجارية التي يدعمها:**
- FIFO traceability: أي نقود أنفقتها؟ من أي ATM أو دفعة أولية جاءت؟
- Cost Basis per consumption: `home_amount = consumed_amount × lot.effective_rate`
- Reversal: عند عكس مصروف، يُحدَّث `remaining_amount` في الـ lot ويُعلَّم هذا السجل كـ reversed.

**المواصفة المرجعية:** Financial Core Gap Closure Plan § FIFO Engine; Expense Recording Specification v1.0 § Cash Expense Flow

```
cash_lot_consumptions
│
├── id                        TEXT        PRIMARY KEY
├── lot_id                    TEXT        NOT NULL  FK → cash_lots(id)
│
├── -- Source of Consumption
├── consumption_type          TEXT        NOT NULL
│                                         CHECK (consumption_type IN (
│                                           'cash_expense',
│                                           'exchange_out',
│                                           'manual_reduction'
│                                         ))
│
├── -- Linkage (exactly one must be non-null based on consumption_type)
├── expense_id                TEXT        FK → expenses(id) ON DELETE SET NULL
│                                         -- Populated when consumption_type = 'cash_expense'
├── exchange_id               TEXT        FK → currency_exchanges(id)
│                                         -- Populated when consumption_type = 'exchange_out'
│
├── -- Consumed Amount
├── consumed_amount           REAL        NOT NULL  CHECK (consumed_amount > 0)
│
├── -- Cost Basis Snapshot (write-once: consumed_amount × lot.effective_rate at consumption time)
├── home_amount               REAL        CHECK (home_amount IS NULL OR home_amount > 0)
├── home_currency_code        TEXT
│
├── -- Reversal
├── is_reversed               INTEGER     NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
├── reversed_at               TEXT
│
└── created_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (
    (consumption_type = 'cash_expense'     AND expense_id IS NOT NULL  AND exchange_id IS NULL)
    OR
    (consumption_type = 'exchange_out'     AND exchange_id IS NOT NULL AND expense_id IS NULL)
    OR
    (consumption_type = 'manual_reduction' AND expense_id IS NULL      AND exchange_id IS NULL)
  )
  CHECK (home_currency_code IS NULL OR home_currency_code = UPPER(home_currency_code))
  CHECK (is_reversed = 0 OR reversed_at IS NOT NULL)

FOREIGN KEYS:
  lot_id      → cash_lots(id)          -- No cascade: reversal restores lot, not deletes it
  expense_id  → expenses(id)           ON DELETE SET NULL
  exchange_id → currency_exchanges(id)

INDEXES:
  idx_lot_consumptions_lot       ON cash_lot_consumptions(lot_id, is_reversed)
  idx_lot_consumptions_expense   ON cash_lot_consumptions(expense_id, is_reversed)
  idx_lot_consumptions_exchange  ON cash_lot_consumptions(exchange_id, is_reversed)
```

---

### 6. `cash_transactions`

**لماذا يوجد:**
Audit Trail ثابت لكل حركة نقدية. كل تدفق وارد أو صادر — بغض النظر عن سببه — يُسجّل هنا بترتيب زمني. هذا الجدول هو "دفتر اليومية" الخام للنقد.

**العلاقة مع cash_lots:**
- كل inflow transaction يُنشئ lot واحداً → `lot_id` يشير إلى الـ lot المنشأ.
- كل outflow transaction يُشير إلى المصروف أو الصرف المرتبط به.
- الـ lot consumptions هي التفصيل؛ هذا الجدول هو الملخّص.

**التغيير من v1:**
- إضافة `lot_id`: ربط الـ inflow transactions باللوتات المنشأة.
- إضافة `exchange_id`: ربط exchange transactions بكيان الصرف الموحّد.

**المواصفة المرجعية:** Financial Core Gap Closure Plan § Cash Transaction Audit Trail (KEEP + MODIFY)

```
cash_transactions
│
├── id                        TEXT        PRIMARY KEY
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
│
├── -- Event Type
├── type                      TEXT        NOT NULL
│                                         CHECK (type IN (
│                                           'initial_cash',
│                                           'atm_withdrawal',
│                                           'currency_exchange_in',
│                                           'currency_exchange_out',
│                                           'manual_adjustment',
│                                           'cash_expense_deduction',
│                                           'cash_refund'
│                                         ))
│
├── -- Amount
├── amount                    REAL        NOT NULL  CHECK (amount >= 0)
├── currency_code             TEXT        NOT NULL
│
├── -- Home Currency Snapshot (write-once)
├── home_currency_amount      REAL        CHECK (home_currency_amount IS NULL OR home_currency_amount > 0)
├── home_currency_code        TEXT
│
├── -- Linkages
├── lot_id                    TEXT        FK → cash_lots(id)
│                                         -- Populated for inflow types that create a lot:
│                                         -- (initial_cash, atm_withdrawal, currency_exchange_in,
│                                         --  manual_adjustment, cash_refund)
├── expense_id                TEXT        FK → expenses(id) ON DELETE SET NULL
│                                         -- Populated for: cash_expense_deduction, cash_refund
├── exchange_id               TEXT        FK → currency_exchanges(id)
│                                         -- Populated for: currency_exchange_in, currency_exchange_out
│
├── -- Reversal
├── is_reversed               INTEGER     NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
├── reversed_at               TEXT
│
├── -- Metadata
├── note                      TEXT
└── created_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (currency_code = UPPER(currency_code))
  CHECK (home_currency_code IS NULL OR home_currency_code = UPPER(home_currency_code))
  CHECK (is_reversed = 0 OR reversed_at IS NOT NULL)
  -- Inflow types must reference their created lot:
  CHECK (
    type NOT IN ('initial_cash','atm_withdrawal','currency_exchange_in','manual_adjustment','cash_refund')
    OR lot_id IS NOT NULL
  )
  -- Exchange types must reference their exchange entity:
  CHECK (
    type NOT IN ('currency_exchange_in', 'currency_exchange_out')
    OR exchange_id IS NOT NULL
  )

FOREIGN KEYS:
  trip_id     → trips(id)            ON DELETE CASCADE
  lot_id      → cash_lots(id)
  expense_id  → expenses(id)         ON DELETE SET NULL
  exchange_id → currency_exchanges(id)

INDEXES:
  idx_cash_tx_trip_type     ON cash_transactions(trip_id, type, is_reversed)
  idx_cash_tx_trip_created  ON cash_transactions(trip_id, created_at DESC)
  idx_cash_tx_expense       ON cash_transactions(expense_id) WHERE expense_id IS NOT NULL
  idx_cash_tx_exchange      ON cash_transactions(exchange_id) WHERE exchange_id IS NOT NULL
```

---

### 7. `currency_exchanges` ⭐ NEW

**لماذا يوجد:**
في v1، عملية الصرف كانت مُسجّلة كصفّين منفصلين في `cash_transactions` بدون رابط صريح بينهما. هذا يُصعّب:
- استعلام "كل عمليات الصرف في هذه الرحلة".
- معرفة المعدل الفعلي المستخدم في عملية بعينها.
- نقل cost basis بدقة من العملة المُباعة إلى العملة المُشتراة.

الحل: كيان Exchange موحّد يُسجّل العملية كاملة. الـ cash_transactions تبقى كـ audit trail فقط.

**Cost Basis Transfer:**
`to_lot.home_currency_amount` = مجموع `home_amount` في `cash_lot_consumptions` المرتبطة.
هذا يعني: النقود الجديدة بالعملة الثانية لها cost basis مساوٍ لـ cost basis النقود القديمة المُصرَّفة.

**القاعدة التجارية التي يدعمها:**
- Exchange كحدث مالي واحد لا حدثين.
- exchange_rate صريح ومخزون على العملية مباشرة.
- ربط مباشر بـ cash_lot الناتج عن العملية.

**المواصفة المرجعية:** Financial Core Gap Closure Plan § Currency Exchange Model (MODIFY); Financial Domain Model v2.0 § Money Movement

```
currency_exchanges
│
├── id                        TEXT        PRIMARY KEY
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
│
├── -- Source (العملة المُباعة / المُستهلكة)
├── from_currency_code        TEXT        NOT NULL
├── from_amount               REAL        NOT NULL  CHECK (from_amount > 0)
│
├── -- Destination (العملة المُستلمة)
├── to_currency_code          TEXT        NOT NULL
├── to_amount                 REAL        NOT NULL  CHECK (to_amount > 0)
│
├── -- Exchange Rate (صريح، محسوب: to_amount / from_amount)
├── exchange_rate             REAL        NOT NULL  CHECK (exchange_rate > 0)
│                                         -- to_amount per 1 unit of from_currency
│
├── -- Resulting Lot (العملة المُستلمة تُنشئ lot جديداً)
├── to_lot_id                 TEXT        NOT NULL  FK → cash_lots(id)
│
├── -- Reversal
├── is_reversed               INTEGER     NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
├── reversed_at               TEXT
│
├── -- Metadata
├── note                      TEXT
└── created_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (from_currency_code != to_currency_code)
  CHECK (from_currency_code = UPPER(from_currency_code))
  CHECK (to_currency_code = UPPER(to_currency_code))
  CHECK (is_reversed = 0 OR reversed_at IS NOT NULL)

FOREIGN KEYS:
  trip_id   → trips(id)      ON DELETE CASCADE
  to_lot_id → cash_lots(id)  -- No cascade: reversal marks lot as reversed

INDEXES:
  idx_exchanges_trip  ON currency_exchanges(trip_id, is_reversed, created_at DESC)
```

**ملاحظة حول Cost Basis Transfer:**
`home_currency_amount` للـ `to_lot` يُحسب ويُكتب عند إنشاء العملية من:
```
SUM(cash_lot_consumptions.home_amount)
WHERE exchange_id = this.id AND is_reversed = 0
```

---

### 8. `expense_refunds`

**لماذا يوجد:**
الاسترجاع كيان مالي مستقل — ليس مصروفاً سالباً. له destination routing (cash أو card) مختلف السلوك المالي.

**التغيير من v1:**
- إضافة `returned_lot_id`: للاسترجاعات النقدية، يُشير إلى الـ lot الجديد المُنشأ بـ cost basis موروث من المصروف الأصلي (Refund Lot Inheritance).

**القاعدة التجارية التي يدعمها:**
- Cash Refund → ينشئ lot جديد (`source_type = 'cash_refund'`) بـ cost basis مساوٍ لـ `home_amount` هذا الاسترجاع.
- Card Refund → يُسجَّل فقط كحدث، لا يُؤثر على النقد.
- Over-refund guard: SUM(refunds.home_amount) لا يتجاوز expense.converted_home_amount.
- Net Spending = Gross − Active Refunds.

**المواصفة المرجعية:** Financial Domain Model v2.0 § Refund; Trip Financial Report Specification v2.0 § Net Spending

```
expense_refunds
│
├── id                        TEXT        PRIMARY KEY
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
├── expense_id                TEXT        FK → expenses(id) ON DELETE SET NULL
│                                         -- nullable: standalone refund not tied to an expense
│
├── -- Refund Amount
├── amount                    REAL        NOT NULL  CHECK (amount > 0)
├── currency_code             TEXT        NOT NULL
│
├── -- Home Currency Snapshot (write-once, inherited from expense conversion)
├── home_amount               REAL        CHECK (home_amount IS NULL OR home_amount > 0)
├── home_currency             TEXT
│
├── -- Destination Routing
├── destination               TEXT        NOT NULL
│                                         CHECK (destination IN ('cash', 'card'))
│
├── -- Cash Refund Lot (populated only when destination = 'cash')
├── returned_lot_id           TEXT        FK → cash_lots(id)
│                                         -- The new lot created for this cash refund
│                                         -- NULL for card refunds
│
├── -- Reversal
├── is_reversed               INTEGER     NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
├── reversed_at               TEXT
│
├── -- Metadata
├── note                      TEXT
└── created_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (currency_code = UPPER(currency_code))
  CHECK (home_currency IS NULL OR home_currency = UPPER(home_currency))
  CHECK (is_reversed = 0 OR reversed_at IS NOT NULL)
  -- Cash refunds must have a lot; card refunds must not:
  CHECK (
    (destination = 'cash' AND returned_lot_id IS NOT NULL)
    OR
    (destination = 'card' AND returned_lot_id IS NULL)
  )

FOREIGN KEYS:
  trip_id         → trips(id)      ON DELETE CASCADE
  expense_id      → expenses(id)   ON DELETE SET NULL
  returned_lot_id → cash_lots(id)

INDEXES:
  idx_refunds_trip     ON expense_refunds(trip_id, is_reversed, created_at DESC)
  idx_refunds_expense  ON expense_refunds(expense_id, is_reversed) WHERE expense_id IS NOT NULL
```

---

### 9. `trip_cash_balances`

**لماذا يوجد:**
Cache مُشتق لأداء القراءة. القيمة الحقيقية مشتقة من:
```sql
SELECT SUM(remaining_amount)
FROM cash_lots
WHERE trip_id = ? AND currency_code = ? AND is_reversed = 0
```
لكن هذا الحساب يُستدعى كثيراً عند عرض الـ UI. الـ cache يتجنب full scan على cash_lots في كل render.

**قاعدة التناسق:**
كل عملية تُغيّر `cash_lots.remaining_amount` يجب أن تُحدّث هذا الجدول atomically داخل نفس DB transaction.

> **تحذير:** هذا الجدول مصدر بيانات ثانوي. المصدر الأول هو `cash_lots`. في حالة تعارض القيمتين، `cash_lots` هو الصحيح ويجب إعادة حساب `trip_cash_balances` منه.

**المواصفة المرجعية:** Trip Financial Report Specification v2.0 § Cash Balance Display

```
trip_cash_balances
│
├── trip_id                   TEXT        NOT NULL  FK → trips(id) ON DELETE CASCADE
├── currency_code             TEXT        NOT NULL
├── balance_amount            REAL        NOT NULL DEFAULT 0
│                                         -- Mirrors SUM(cash_lots.remaining_amount)
│                                         -- for active (non-reversed) lots
└── updated_at                TEXT        NOT NULL

PRIMARY KEY: (trip_id, currency_code)

CONSTRAINTS:
  CHECK (currency_code = UPPER(currency_code))
  CHECK (balance_amount >= 0)

FOREIGN KEYS:
  trip_id → trips(id) ON DELETE CASCADE

INDEXES:
  None required beyond primary key.
```

---

### 10. `manual_exchange_rates`

**لماذا يوجد:**
المستخدم يُدخل يدوياً معدل الصرف الذي استخدمه. يُستخدم كـ fallback عند حساب `converted_home_amount` للمصروفات حين لا تتوفر بيانات من البطاقة أو اللوتات.

**المواصفة المرجعية:** Expense Recording Specification v1.0 § FX Resolution Hierarchy

```
manual_exchange_rates
│
├── id                        INTEGER     PRIMARY KEY AUTOINCREMENT
├── trip_id                   TEXT        FK → trips(id) ON DELETE CASCADE
│                                         -- nullable = global rate (not trip-scoped)
├── from_currency             TEXT        NOT NULL
├── to_currency               TEXT        NOT NULL
├── rate                      REAL        NOT NULL  CHECK (rate > 0)
├── source_note               TEXT
└── created_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (from_currency != to_currency)
  CHECK (from_currency = UPPER(from_currency))
  CHECK (to_currency = UPPER(to_currency))

FOREIGN KEYS:
  trip_id → trips(id) ON DELETE CASCADE

INDEXES:
  idx_manual_rates_lookup  ON manual_exchange_rates(trip_id, from_currency, to_currency, created_at DESC)
```

---

### 11. `user_financial_profile`

**لماذا يوجد:**
Singleton (id = 1 دائماً). يُعرّف العملة الأساسية للمستخدم التي تُستخدم كـ home currency في جميع التحويلات.

```
user_financial_profile
│
├── id                        INTEGER     PRIMARY KEY CHECK (id = 1)  -- Singleton
├── home_country_code         TEXT        NOT NULL
├── home_country_english      TEXT        NOT NULL
├── home_country_arabic       TEXT        NOT NULL
├── home_currency_code        TEXT        NOT NULL
├── onboarding_completed      INTEGER     NOT NULL DEFAULT 0  CHECK (onboarding_completed IN (0, 1))
├── created_at                TEXT        NOT NULL
└── updated_at                TEXT        NOT NULL

CONSTRAINTS:
  CHECK (home_currency_code = UPPER(home_currency_code))
```

---

### 12. `settings`

```
settings
│
├── id                        INTEGER     PRIMARY KEY CHECK (id = 1)  -- Singleton
├── currency_code             TEXT        NOT NULL
├── locale_code               TEXT        NOT NULL
├── created_at                TEXT        NOT NULL
└── updated_at                TEXT        NOT NULL
```

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        user_financial_profile                        │
│                        settings                                      │
│                        (Singletons — no FK dependencies)             │
└─────────────────────────────────────────────────────────────────────┘

                        ┌──────────┐
                        │  cards   │
                        └────┬─────┘
                             │ ON DELETE SET NULL
                             ↓
┌────────────────────────────────────────────────────────────────────────────────┐
│                                   trips                                         │
│  id, base_currency, destination_currency, home_currency_snapshot, ...          │
└───┬────────────────────────────────────────────────────────────────────────────┘
    │ ON DELETE CASCADE (all financial tables below)
    │
    ├──────────────────────────────────────────────────────────────────┐
    │                                                                  │
    ▼                                                                  ▼
┌──────────────┐                                          ┌───────────────────────┐
│   expenses   │◄─────────────────────────────────────────│  expense_refunds      │
│              │  expense_id (SET NULL on delete)         │                       │
│ payment_type │                                          │ destination: cash/card │
│ (cash/card)  │                                          │ returned_lot_id ──────┼──┐
└──────┬───────┘                                          └───────────────────────┘  │
       │                                                                              │
       │ expense_id (SET NULL)                                                        │
       ▼                                                                              │
┌─────────────────────┐                                                              │
│ cash_lot_consumptions│◄─────────────────────────────────────────────────────────┐  │
│                     │  exchange_id                                               │  │
│ consumption_type:   │                                                            │  │
│  - cash_expense     │                                                            │  │
│  - exchange_out     │──── lot_id ────┐                                          │  │
│  - manual_reduction │               │                                           │  │
└─────────────────────┘               │                                           │  │
                                      ▼                                           │  │
                              ┌──────────────┐                                   │  │
                              │  cash_lots   │◄──────────────────────────────────┘  │
                              │              │◄─────────────────────────────────────┘
                              │ source_type  │  returned_lot_id (from expense_refunds)
                              │ source_ref_* │◄─── to_lot_id ───┐
                              └──────┬───────┘                  │
                                     │                   ┌───────────────────┐
                                     │ lot_id            │ currency_exchanges │
                                     ▼                   │                   │
                              ┌──────────────┐           │ from_currency     │
                              │cash_transact.│           │ from_amount       │
                              │              │           │ to_currency       │
                              │ type:        │           │ to_amount         │
                              │ -initial_cash│           │ exchange_rate     │
                              │ -atm_with.   │◄──────────│ to_lot_id         │
                              │ -exch_in/out │ exchange_id└───────────────────┘
                              │ -manual_adj  │
                              │ -cash_exp_ded│
                              │ -cash_refund │
                              └──────────────┘
                                     ▲
                    ┌────────────────┤
                    │                │
            ┌───────────────┐ ┌──────────────────┐
            │ manual_exchange│ │ trip_cash_balances│
            │ _rates        │ │ (derived cache)   │
            └───────────────┘ └──────────────────┘
```

### اتجاه الكتابة لكل حدث مالي

```
ATM Withdrawal:
  1. INSERT cash_lots (source_type='atm_withdrawal', source_ref_type='cash_transaction', source_ref_id=↓)
  2. INSERT cash_transactions (type='atm_withdrawal', lot_id=↑)
  3. UPDATE trip_cash_balances (+amount)

Cash Expense:
  1. INSERT expenses (payment_type='cash')
  2. FIFO → INSERT cash_lot_consumptions × N (consumption_type='cash_expense', expense_id=↑)
  3. UPDATE cash_lots.remaining_amount × N
  4. INSERT cash_transactions (type='cash_expense_deduction', expense_id=↑)
  5. UPDATE trip_cash_balances (-amount)

Currency Exchange:
  1. INSERT cash_lots (source_type='exchange_in', source_ref_type='currency_exchange', source_ref_id=↓)
  2. INSERT currency_exchanges (to_lot_id=↑)
  3. FIFO → INSERT cash_lot_consumptions × N (consumption_type='exchange_out', exchange_id=↑)
  4. UPDATE cash_lots.remaining_amount × N (from-currency lots)
  5. UPDATE to_lot.home_currency_amount = SUM(consumptions.home_amount)
  6. INSERT cash_transactions × 2 (exchange_out + exchange_in, exchange_id=↑)
  7. UPDATE trip_cash_balances × 2 (−from_currency, +to_currency)

Cash Refund:
  1. INSERT cash_lots (source_type='cash_refund', source_ref_type='expense_refund', source_ref_id=↓)
  2. INSERT expense_refunds (destination='cash', returned_lot_id=↑)
  3. INSERT cash_transactions (type='cash_refund', lot_id=↑, expense_id=expense)
  4. UPDATE trip_cash_balances (+amount)

Card Refund:
  1. INSERT expense_refunds (destination='card', returned_lot_id=NULL)
  -- No cash_lots or cash_transactions involvement
```

---

## Database Invariants

### I-01: Cash Balance Consistency
```
∀ (trip_id, currency_code):
  trip_cash_balances.balance_amount
  =
  SUM(cash_lots.remaining_amount)
  WHERE trip_id = trip_id
    AND currency_code = currency_code
    AND is_reversed = 0
```

### I-02: Lot Amount Integrity
```
∀ lot:
  lot.remaining_amount
  =
  lot.original_amount
  − SUM(cash_lot_consumptions.consumed_amount)
    WHERE lot_id = lot.id AND is_reversed = 0
```

### I-03: Lot Full Consumption Flag
```
∀ lot:
  lot.is_fully_consumed = 1  ⟺  lot.remaining_amount = 0
```

### I-04: No Over-Consumption
```
∀ lot:
  SUM(active consumptions.consumed_amount) ≤ lot.original_amount
```

### I-05: No Over-Refund
```
∀ expense_id:
  SUM(expense_refunds.home_amount WHERE expense_id = ? AND is_reversed = 0)
  ≤
  expenses.converted_home_amount WHERE id = expense_id
```

### I-06: Effective Rate Consistency
```
∀ lot WHERE effective_rate IS NOT NULL:
  lot.effective_rate ≈ lot.home_currency_amount / lot.original_amount
  (within floating-point tolerance)
```

### I-07: Exchange Cost Basis Transfer
```
∀ exchange:
  exchange.to_lot.home_currency_amount
  =
  SUM(cash_lot_consumptions.home_amount)
  WHERE exchange_id = exchange.id AND is_reversed = 0
```

### I-08: Cash Refund Lot Inheritance
```
∀ refund WHERE destination = 'cash':
  refund.returned_lot.home_currency_amount = refund.home_amount
  refund.returned_lot.source_type = 'cash_refund'
```

### I-09: Reversal Completeness
```
∀ reversed lot:
  ALL consumptions from this lot must be is_reversed = 1
  BEFORE the lot itself is marked is_reversed = 1
```

### I-10: Payment Type Consistency
```
∀ expense WHERE payment_type = 'cash':
  EXISTS cash_transactions WHERE expense_id = expense.id AND type = 'cash_expense_deduction'
  AND EXISTS cash_lot_consumptions WHERE expense_id = expense.id

∀ expense WHERE payment_type = 'card':
  NOT EXISTS cash_transactions WHERE expense_id = expense.id
  NOT EXISTS cash_lot_consumptions WHERE expense_id = expense.id
```

### I-11: Source Reference Traceability
```
∀ lot:
  EXISTS record IN (source_ref_type → table) WHERE id = lot.source_ref_id
```
مُطبَّق على مستوى التطبيق (polymorphic reference لا يدعمه SQLite FK).

---

## Validation Constraints

### VC-01: Currency Format
جميع حقول العملات: NOT NULL عند الاستخدام، UPPERCASE، LENGTH = 3، ISO 4217.

### VC-02: Amount Positivity
- الـ amounts الفعلية: `> 0`
- الـ amounts القابلة للصفر (initial_cash = 0 مقبول): `>= 0`
- الـ snapshots الاختيارية: `IS NULL` مقبول

### VC-03: Snapshot Coherence
```
(home_currency_amount, home_currency_code, effective_rate):
  إما الثلاثة NOT NULL معاً أو الثلاثة NULL معاً
```

### VC-04: Timestamp Ordering
```
trip: end_date >= start_date (إذا كلاهما NOT NULL)
lot/transaction: reversed_at >= created_at (إذا NOT NULL)
```

### VC-05: Exchange Validity
```
exchange_rate > 0
from_amount > 0
to_amount > 0
from_currency_code ≠ to_currency_code
```

### VC-06: Refund Destination Integrity
```
destination = 'cash'  →  returned_lot_id IS NOT NULL
destination = 'card'  →  returned_lot_id IS NULL
```

### VC-07: Singleton Tables
```
user_financial_profile.id = 1 (ONLY)
settings.id = 1 (ONLY)
```

---

## Reversal Strategy

كل الجداول المالية تستخدم **Soft Reversal** — لا حذف حقيقي.

### مبدأ الاتجاه العكسي

| الحدث الأصلي | الحدث العكسي |
|-------------|-------------|
| Lot created (remaining = X) | is_reversed=1, remaining=0, is_fully_consumed=1 |
| Consumption (consumed = Y) | is_reversed=1, restore lot.remaining += Y |
| Cash deducted from balance | balance += amount |
| Cash added to balance | balance -= amount |

### قواعد الترتيب عند العكس

```
عكس Cash Expense:
  1. Mark cash_lot_consumptions.is_reversed = 1 (لكل سجل مرتبط)
  2. Restore cash_lots.remaining_amount += consumed_amount (لكل lot)
  3. Update cash_lots.is_fully_consumed = 0 إذا remaining > 0
  4. Mark cash_transactions.is_reversed = 1
  5. Update trip_cash_balances += expense.transaction_amount

عكس Currency Exchange:
  1. Mark currency_exchanges.is_reversed = 1
  2. Mark to_lot.is_reversed = 1, remaining = 0
  3. Mark cash_lot_consumptions.is_reversed = 1 (exchange_out type)
  4. Restore from-currency lots' remaining_amount
  5. Mark cash_transactions × 2 as is_reversed = 1
  6. Update trip_cash_balances × 2

عكس Cash Refund:
  1. Mark expense_refunds.is_reversed = 1
  2. Mark returned_lot.is_reversed = 1, remaining = 0
  3. Mark cash_transactions (cash_refund).is_reversed = 1
  4. Update trip_cash_balances -= refund.amount

عكس Card Refund:
  1. Mark expense_refunds.is_reversed = 1
  -- لا تأثير على cash_lots أو cash_transactions

عكس ATM Withdrawal / Initial Cash:
  شرط مسبق: SUM(active consumptions from this lot) = 0
  1. Mark cash_lots.is_reversed = 1
  2. Mark cash_transactions.is_reversed = 1
  3. Update trip_cash_balances -= original_amount
```

### ما لا يمكن عكسه مباشرة

الـ lot الذي استُهلك جزئياً أو كلياً **لا يمكن عكسه مباشرة**.
يجب أولاً عكس جميع الـ consumptions المرتبطة به، ثم عكسه.
هذا يحمي من انتهاك I-02 و I-04.

---

## Net Trip Cost — مسار الحساب في التقارير

```
Gross Spending    = SUM(expenses.converted_home_amount)
                    WHERE trip_id = X AND home_currency = trip.home_currency_snapshot

Active Refunds    = SUM(expense_refunds.home_amount)
                    WHERE trip_id = X AND is_reversed = 0
                    AND home_currency = trip.home_currency_snapshot

Net Spending      = Gross Spending − Active Refunds

Remaining Cash    = SUM(cash_lots.remaining_amount × cash_lots.effective_rate)
                    WHERE trip_id = X
                      AND is_reversed = 0
                      AND is_fully_consumed = 0
                      AND home_currency_code = trip.home_currency_snapshot

Net Trip Cost     = Net Spending − Remaining Cash
```

جميع المعطيات لهذا الحساب موجودة مباشرة في الجداول — لا يحتاج join معقد ولا إعادة حساب.

---

## Changes Summary: v1 → v2

| العنصر | v1 | v2 |
|--------|----|----|
| Cash Balance Model | Weighted Average | FIFO Cash Lots |
| Cost Basis per inflow | لا يوجد | `cash_lots.home_currency_amount` |
| FIFO Consumption | لا يوجد | `cash_lot_consumptions` |
| Source Traceability | لا يوجد | `cash_lots.source_ref_type + source_ref_id` |
| Currency Exchange | صفّان منفصلان | كيان موحّد `currency_exchanges` |
| Exchange Rate (explicit) | غير مخزون | `currency_exchanges.exchange_rate` |
| Cost Basis Transfer | غير موجود | `to_lot.home_currency_amount` = SUM(consumptions) |
| Refund Lot Inheritance | غير موجود | `expense_refunds.returned_lot_id` → cash_lots |
| Payment Type | ضمني | صريح: `expenses.payment_type` |
| Net Trip Cost | غير محسوب | مشتق مباشرة من الجداول |
| Legacy amount/currency | موجود | محذوف |
| Cash Transactions | Audit Trail + Balance Source | Audit Trail فقط |
