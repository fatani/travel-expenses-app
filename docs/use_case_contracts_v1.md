# Use Case Contracts Specification v1.0
**CalmTrip Financial Core**
**تاريخ الإصدار:** 10 يونيو 2026
**الحالة:** Approved for Implementation
**آخر تحديث:** 10 يونيو 2026 — ATM Fee Financial Correction + Card Profile + Payment Channel
**يستند إلى:** Database Schema v2.0 | Financial Domain Model v2.0 | Expense Recording Specification v1.0 | Trip Financial Report Specification v2.0

---

## Schema Alignment Note

> **⚠️ Required before implementation:**
> `expenses` في Database Schema v2.0 يجب أن يتضمن الحقلين التاليين:
> ```
> is_reversed  INTEGER  NOT NULL DEFAULT 0  CHECK (is_reversed IN (0, 1))
> reversed_at  TEXT
> ```
> هذا ضروري لدعم Soft Reversal للمصروفات كما هو مُعرَّف في هذه الوثيقة.
> لا يُسمح باستخدام `DELETE` كبديل — الـ Financial Core reversal-based بالكامل.

---

## Reading Guide

كل Use Case يُعرَّف بالبنية التالية:

| القسم | المحتوى |
|-------|---------|
| **Purpose** | ما الذي يُحقّقه هذا الـ Use Case ماليًا |
| **Inputs** | كل المدخلات المطلوبة مع أنواعها |
| **Preconditions** | ما يجب التحقق منه قبل البدء |
| **Validations** | قواعد التحقق من صحة المدخلات |
| **DB Reads** | الاستعلامات المطلوبة قبل الكتابة |
| **DB Writes** | الكتابات على قاعدة البيانات بالترتيب الدقيق |
| **Atomicity** | ما يجب أن يحدث داخل transaction واحد |
| **Side Effects** | التأثيرات على الحالة خارج الكتابات المباشرة |
| **Failure Cases** | كل حالات الفشل المحتملة ورسالة الخطأ |
| **Reversal** | كيف يُعكس هذا الـ Use Case |
| **Test Cases** | حالات الاختبار المطلوبة |

---

## Global Definitions

### FIFO Lot Selection Algorithm

يُستخدم هذا الـ algorithm في كل عملية تستهلك نقداً (Cash Expense، Exchange Out، Manual Reduction).

```
INPUT:
  tripId: String
  currencyCode: String (uppercase)
  requiredAmount: Double

ALGORITHM:
  1. SELECT active lots:
     WHERE trip_id = tripId
       AND currency_code = currencyCode
       AND is_reversed = 0
       AND is_fully_consumed = 0
     ORDER BY created_at ASC, id ASC  -- FIFO: oldest first, id as tiebreaker

  2. Walk lots in order:
     remaining = requiredAmount
     consumptions = []
     FOR each lot:
       toConsume = MIN(lot.remaining_amount, remaining)
       consumptions.append({lot, toConsume})
       remaining -= toConsume
       IF remaining = 0: BREAK

  3. IF remaining > 0:
     RAISE InsufficientCashBalance(
       required: requiredAmount,
       available: requiredAmount - remaining,
       currency: currencyCode
     )

  4. RETURN consumptions  -- List of {lot, consumed_amount}
```

### Cost Basis Calculation per Consumption

```
FOR each consumption in consumptions:
  IF lot.effective_rate IS NOT NULL:
    consumption.home_amount = consumption.consumed_amount × lot.effective_rate
    consumption.home_currency_code = lot.home_currency_code
  ELSE:
    consumption.home_amount = NULL
    consumption.home_currency_code = NULL
```

### Atomic Write Order Constraint

كل Use Case يحدد الكتابات بترتيب رقمي صريح. هذا الترتيب يعكس التبعيات بين الجداول:

```
cash_lots يجب أن يُكتب قبل:
  → cash_transactions (lot_id FK)
  → currency_exchanges (to_lot_id FK)
  → expense_refunds (returned_lot_id FK)

currency_exchanges يجب أن يُكتب قبل:
  → cash_lot_consumptions (exchange_id FK)
  → cash_transactions لنوع exchange (exchange_id FK)

expenses يجب أن يُكتب قبل:
  → cash_lot_consumptions (expense_id FK)
  → cash_transactions لنوع deduction (expense_id FK)
```

---

## Use Case 1: RecordCashExpense

### Purpose
تسجيل مصروف دُفع نقداً. يُنشئ سجل المصروف، ويستهلك من لوتات النقد عبر FIFO، ويُحدّث الرصيد.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `title` | String | ✅ | وصف المصروف |
| `transactionAmount` | Double | ✅ | المبلغ المدفوع |
| `transactionCurrency` | String | ✅ | عملة الدفع (uppercase) |
| `spentAt` | DateTime | ✅ | وقت الإنفاق |
| `category` | String | ❌ | تصنيف المصروف |
| `note` | String | ❌ | ملاحظة |
| `paymentMethod` | String | ✅ | دائماً 'Cash' لهذا الـ Use Case |
| `paymentChannel` | String | ✅ | دائماً 'Cash' |
| `source` | String | ✅ | 'manual' أو 'sms' |
| `rawSmsText` | String | ❌ | نص SMS إذا كان source='sms' |

---

### Preconditions

- الرحلة موجودة: `trips WHERE id = tripId`
- الـ `home_currency_snapshot` على الرحلة ليس NULL

---

### Validations

**V-01:** `tripId` غير فارغ
**V-02:** `title` غير فارغ
**V-03:** `transactionAmount > 0`
**V-04:** `transactionCurrency` بالأحرف الكبيرة، طوله 3 أحرف
**V-05:** `spentAt` ليس في المستقبل البعيد (تحذير، ليس خطأ)
**V-06:** `paymentMethod = 'Cash'` و `paymentChannel = 'Cash'`
**V-07:** يوجد رصيد نقدي كافٍ:
```
SUM(cash_lots.remaining_amount)
WHERE trip_id = tripId
  AND currency_code = transactionCurrency
  AND is_reversed = 0
  AND is_fully_consumed = 0
≥ transactionAmount
```
إذا لم يكن كافياً: فشل بـ `InsufficientCashBalance` — لا يُسمح بالرصيد السالب.

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
      → للتحقق من الوجود، وجلب home_currency_snapshot

R-02: FIFO Lot Selection (algorithm المُعرَّف أعلاه)
      → tripId, transactionCurrency, transactionAmount
      → النتيجة: List<{lot, consumed_amount, home_amount, home_currency_code}>
```

---

### DB Writes (بالترتيب داخل Transaction واحد)

```
W-01: INSERT expenses
      id                    = newUUID()
      trip_id               = tripId
      payment_type          = 'cash'
      title                 = title
      category              = category
      transaction_amount    = transactionAmount
      transaction_currency  = transactionCurrency
      original_amount       = transactionAmount
      original_currency     = transactionCurrency
      converted_home_amount = SUM(consumptions.home_amount)  -- NULL إذا لا يوجد rate
      home_currency         = trip.home_currency_snapshot    -- NULL إذا converted_home_amount = NULL
      conversion_rate       = converted_home_amount / transactionAmount  -- NULL إذا لا يوجد
      payment_method        = 'Cash'
      payment_channel       = 'Cash'
      payment_network       = NULL
      card_profile_id       = NULL
      is_international      = (transactionCurrency ≠ trip.home_currency_snapshot) ? 1 : 0
      source                = source
      raw_sms_text          = rawSmsText
      note                  = note
      spent_at              = spentAt (UTC ISO 8601)
      created_at            = now()
      updated_at            = now()

W-02: FOR each consumption in FIFO result:
      INSERT cash_lot_consumptions
        id               = newUUID()
        lot_id           = consumption.lot.id
        consumption_type = 'cash_expense'
        expense_id       = W-01.id
        exchange_id      = NULL
        consumed_amount  = consumption.consumed_amount
        home_amount      = consumption.home_amount
        home_currency_code = consumption.home_currency_code
        is_reversed      = 0
        created_at       = now()

W-03: FOR each consumption in FIFO result:
      UPDATE cash_lots
        SET remaining_amount  = remaining_amount - consumption.consumed_amount,
            is_fully_consumed = (remaining_amount - consumption.consumed_amount = 0) ? 1 : 0
        WHERE id = consumption.lot.id

W-04: INSERT cash_transactions
        id                   = newUUID()
        trip_id              = tripId
        type                 = 'cash_expense_deduction'
        amount               = transactionAmount
        currency_code        = transactionCurrency
        home_currency_amount = W-01.converted_home_amount
        home_currency_code   = W-01.home_currency
        lot_id               = NULL  -- outflow لا يُنشئ lot
        expense_id           = W-01.id
        exchange_id          = NULL
        is_reversed          = 0
        note                 = note
        created_at           = now()

W-05: UPSERT trip_cash_balances
        SET balance_amount = balance_amount - transactionAmount
        WHERE trip_id = tripId AND currency_code = transactionCurrency
```

---

### Atomicity

W-01 → W-02 → W-03 → W-04 → W-05 كلها داخل **DB transaction واحد**.
إذا فشل أي منها: rollback كامل.

---

### Side Effects

- لا يوجد side effects خارج الـ DB transaction.
- الـ UI يُحدَّث عبر invalidation لـ providers المرتبطة بالرحلة.

---

### Failure Cases

| الكود | السبب | الحل المقترح للمستخدم |
|-------|-------|----------------------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة | لا توجد رحلة بهذا المعرف |
| `INVALID_AMOUNT` | المبلغ ≤ 0 | أدخل مبلغاً موجباً |
| `INVALID_CURRENCY` | العملة غير صالحة | تحقق من رمز العملة |
| `INSUFFICIENT_CASH` | الرصيد أقل من المبلغ | الرصيد المتاح: X — أضف نقداً أولاً |
| `NO_CASH_LOTS` | لا يوجد نقد من هذه العملة | لم تُضف هذه العملة للمحفظة بعد |
| `DB_CONSTRAINT` | انتهاك constraint في DB | خطأ داخلي — أعد المحاولة |

---

### Reversal

يُنفَّذ عبر `ReverseFinancialEvent` مع:
```
eventType = 'cash_expense'
eventId   = expense.id
```

الخطوات:
1. Mark `cash_lot_consumptions.is_reversed = 1` لكل سجل مرتبط بـ `expense_id`
2. Restore `cash_lots.remaining_amount += consumed_amount` لكل lot متأثر
3. Update `cash_lots.is_fully_consumed = 0` إذا أصبح `remaining_amount > 0`
4. Mark `cash_transactions.is_reversed = 1` للسجل المرتبط بـ `expense_id`
5. Update `trip_cash_balances += transactionAmount`
6. UPDATE expenses SET is_reversed=1, reversed_at=now(), updated_at=now() WHERE id = expense.id

---

### Test Cases

```
TC-01: Happy Path — Single Lot
  Given: Lot A = 200 USD (rate: 3.75 SAR/USD)
  Input: amount=150 USD
  Expected:
    - cash_lot_consumptions: 1 record, consumed=150, home=562.5 SAR
    - cash_lots A: remaining=50, is_fully_consumed=0
    - expenses.converted_home_amount = 562.5
    - trip_cash_balances: balance -= 150

TC-02: Happy Path — Spans Two Lots (FIFO)
  Given: Lot A = 100 USD (rate: 3.75), Lot B = 200 USD (rate: 3.80)
         Lot A created_at < Lot B created_at
  Input: amount=150 USD
  Expected:
    - cash_lot_consumptions: 2 records
      * lot_id=A, consumed=100, home=375
      * lot_id=B, consumed=50, home=190
    - Lot A: remaining=0, is_fully_consumed=1
    - Lot B: remaining=150
    - expenses.converted_home_amount = 565

TC-03: Exact Balance
  Given: Lot A = 100 USD
  Input: amount=100 USD
  Expected:
    - Lot A: remaining=0, is_fully_consumed=1
    - trip_cash_balances: balance=0

TC-04: Insufficient Balance
  Given: total available = 80 USD
  Input: amount=100 USD
  Expected: FAIL with INSUFFICIENT_CASH(available=80, required=100)

TC-05: No Lots in Currency
  Given: No USD lots for this trip
  Input: amount=50 USD
  Expected: FAIL with NO_CASH_LOTS

TC-06: Lot Without Effective Rate
  Given: Lot A = 200 USD, effective_rate=NULL
  Input: amount=100 USD
  Expected:
    - cash_lot_consumptions: consumed=100, home_amount=NULL
    - expenses.converted_home_amount = NULL
    - Operation succeeds (rate absence is not a blocking error)

TC-07: SMS Source
  Input: source='sms', rawSmsText='PURCHASE 100 USD'
  Expected: expenses.source='sms', raw_sms_text stored

TC-08: Atomicity — DB failure after W-03
  Simulate: W-04 fails
  Expected: full rollback — no consumptions, no lot changes, no expense
```

---

## Use Case 2: RecordCardExpense

### Purpose
تسجيل مصروف دُفع ببطاقة. لا يُؤثر على النقد. يُخزَّن snapshot للتحويل بعملة المنزل.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `title` | String | ✅ | وصف المصروف |
| `transactionAmount` | Double | ✅ | المبلغ بعملة المعاملة |
| `transactionCurrency` | String | ✅ | عملة المعاملة |
| `billedAmount` | Double | ❌ | المبلغ كما فاترته البطاقة (عملة أجنبية) |
| `billedCurrency` | String | ❌ | عملة الفاتورة |
| `feesAmount` | Double | ❌ | رسوم البطاقة |
| `feesCurrency` | String | ❌ | عملة الرسوم |
| `totalChargedAmount` | Double | ❌ | إجمالي ما خُصم من البطاقة |
| `totalChargedCurrency` | String | ❌ | عملة الإجمالي |
| `paymentMethod` | String | ✅ | 'Credit Card' أو 'Debit Card' |
| `paymentNetwork` | String | ❌ | 'Visa', 'Mastercard', 'Mada', إلخ |
| `paymentChannel` | String | ✅ | 'POS Purchase' أو 'Online Purchase' |
| `cardProfileId` | Integer | ❌ | معرف البطاقة |
| `convertedHomeAmount` | Double | ❌ | المبلغ بعملة المنزل (يُحسب إذا لم يُقدَّم) |
| `homeCurrency` | String | ❌ | عملة المنزل (من trip.home_currency_snapshot) |
| `conversionRate` | Double | ❌ | معدل التحويل المستخدم |
| `spentAt` | DateTime | ✅ | وقت الإنفاق |
| `category` | String | ❌ | التصنيف |
| `note` | String | ❌ | ملاحظة |
| `source` | String | ✅ | 'manual' أو 'sms' |
| `rawSmsText` | String | ❌ | نص SMS |

---

### Preconditions

- الرحلة موجودة
- إذا قُدِّم `cardProfileId`: البطاقة موجودة في `cards`

---

### Validations

**V-01:** `tripId` غير فارغ
**V-02:** `title` غير فارغ
**V-03:** `transactionAmount > 0`
**V-04:** `transactionCurrency` صالح (3 أحرف كبيرة)
**V-05:** إذا `billedAmount` موجود: `billedAmount > 0` و `billedCurrency` موجود
**V-06:** إذا `feesAmount` موجود: `feesAmount >= 0` و `feesCurrency` موجود
**V-07:** إذا `totalChargedAmount` موجود: `totalChargedAmount > 0` و `totalChargedCurrency` موجود
**V-08:** `paymentMethod IN ('Credit Card', 'Debit Card')`
**V-09:** `paymentChannel IN ('POS Purchase', 'Online Purchase')`
**V-10:** إذا `conversionRate` موجود: `conversionRate > 0`
**V-11:** Snapshot coherence:
```
(convertedHomeAmount, homeCurrency, conversionRate):
  إما الثلاثة موجودة أو الثلاثة NULL
```

### FX Resolution (إذا لم يُقدَّم convertedHomeAmount)

```
1. إذا totalChargedCurrency = trip.home_currency_snapshot:
   convertedHomeAmount = totalChargedAmount
   conversionRate = totalChargedAmount / transactionAmount

2. إذا لا: ابحث في manual_exchange_rates
   WHERE (trip_id = tripId OR trip_id IS NULL)
     AND from_currency = transactionCurrency
     AND to_currency = trip.home_currency_snapshot
   ORDER BY trip_id DESC, created_at DESC
   LIMIT 1
   → convertedHomeAmount = transactionAmount × rate.rate

3. إذا لا: convertedHomeAmount = NULL (snapshot يبقى NULL)
```

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
R-02: إذا cardProfileId موجود: SELECT card WHERE id = cardProfileId
R-03: إذا FX resolution مطلوب: SELECT manual_exchange_rates (كما موضح أعلاه)
```

---

### DB Writes (داخل Transaction واحد)

```
W-01: INSERT expenses
      id                    = newUUID()
      trip_id               = tripId
      payment_type          = 'card'
      title                 = title
      category              = category
      transaction_amount    = transactionAmount
      transaction_currency  = transactionCurrency
      billed_amount         = billedAmount
      billed_currency       = billedCurrency
      fees_amount           = feesAmount
      fees_currency         = feesCurrency
      total_charged_amount  = totalChargedAmount
      total_charged_currency = totalChargedCurrency
      original_amount       = transactionAmount
      original_currency     = transactionCurrency
      converted_home_amount = convertedHomeAmount (resolved or NULL)
      home_currency         = homeCurrency (trip.home_currency_snapshot if resolved)
      conversion_rate       = conversionRate (resolved or NULL)
      payment_method        = paymentMethod
      payment_network       = paymentNetwork
      payment_channel       = paymentChannel
      card_profile_id       = cardProfileId
      is_international      = إذا transactionCurrency ≠ trip.home_currency_snapshot
                              OR feesAmount > 0: 1 ELSE 0
      source                = source
      raw_sms_text          = rawSmsText
      note                  = note
      spent_at              = spentAt
      created_at            = now()
      updated_at            = now()
```

لا كتابات على cash_lots أو cash_transactions — البطاقة لا تُؤثر على النقد.

---

### Atomicity

W-01 فقط — transaction بسيط.

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |
| `CARD_NOT_FOUND` | البطاقة غير موجودة |
| `INVALID_AMOUNT` | المبلغ ≤ 0 |
| `INVALID_SNAPSHOT` | snapshot coherence مكسور |
| `INVALID_PAYMENT_METHOD` | paymentMethod غير مقبول |

---

### Reversal

```
UPDATE expenses
  SET is_reversed=1, reversed_at=now(), updated_at=now()
  WHERE id = expense.id
-- لا يوجد تأثير على cash_lots أو cash_transactions
```

---

### Test Cases

```
TC-01: Happy Path — Domestic Card Expense
  Input: transactionCurrency = 'SAR', totalChargedCurrency = 'SAR'
  Expected:
    - is_international = 0
    - converted_home_amount = transactionAmount

TC-02: International — Card Provides Rate
  Input: transactionCurrency='USD', totalChargedCurrency='SAR', totalChargedAmount=375
  Expected:
    - converted_home_amount = 375
    - conversion_rate = 375 / transactionAmount
    - is_international = 1

TC-03: International — Manual Rate Fallback
  Given: manual_exchange_rate USD→SAR = 3.75 (trip-scoped)
  Input: transactionCurrency='USD', amount=100, no totalCharged
  Expected:
    - converted_home_amount = 375
    - conversion_rate = 3.75

TC-04: No Rate Available
  Input: transactionCurrency='EUR', no totalCharged, no manual rate
  Expected:
    - converted_home_amount = NULL
    - conversion_rate = NULL
    - Operation succeeds

TC-05: Fees Present
  Input: feesAmount=5, feesCurrency='SAR'
  Expected: is_international = 1 regardless of transaction currency

TC-06: With Card Profile
  Given: cardProfileId = 3 (exists)
  Expected: expenses.card_profile_id = 3

TC-07: Card Profile Not Found
  Input: cardProfileId = 999 (not in DB)
  Expected: FAIL with CARD_NOT_FOUND
```

---

## Use Case 3: RecordAtmWithdrawal

### Purpose
تسجيل سحب نقدي من ATM. يُنشئ Lot جديد بـ cost basis (إذا قُدِّم معدل الصرف)، ويُحدّث الرصيد.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `receivedAmount` | Double | ✅ | المبلغ النقدي المُستلم من الـ ATM |
| `receivedCurrency` | String | ✅ | عملة النقد المُستلم |
| `chargedAmount` | Double | ❌ | إجمالي ما خُصم من البطاقة (شامل الرسوم) |
| `chargedCurrency` | String | ❌ | عملة الخصم من البطاقة |
| `feeAmount` | Double | ❌ | رسوم الـ ATM (مُخصومة من البطاقة — ليست من النقد) |
| `feeCurrency` | String | ❌* | عملة الرسوم — إلزامية إذا `feeAmount > 0` |
| `feeNote` | String | ❌ | ملاحظة على الرسوم |
| `fundingCardId` | String | ❌ | معرف البطاقة التي موّلت عملية الـ ATM |
| `note` | String | ❌ | ملاحظة عامة |
| `createdAt` | DateTime | ❌ | وقت السحب (افتراضي: now()) |

> **التمييز المالي الجوهري:**
> - `receivedAmount / receivedCurrency` = النقد الذي يدخل المحفظة
> - `chargedAmount / chargedCurrency` = ما دفعته البطاقة فعلياً (cost basis المُرشَّح)
> - `feeAmount` = رسوم الـ ATM — **مُخصومة من البطاقة، ليست من النقد**
> - `cashPortionAmount = chargedAmount - feeAmount` = الـ cost basis الحقيقي للـ Cash Lot

---

### Preconditions

- الرحلة موجودة

---

### Validations

**V-01:** `receivedAmount > 0`
**V-02:** `receivedCurrency` صالح (3 أحرف كبيرة)
**V-03:** إذا `chargedAmount` موجود: `chargedAmount > 0` و `chargedCurrency` موجود
**V-04:** Snapshot coherence:
```
(chargedAmount, chargedCurrency):
  إما كلاهما موجودان أو كلاهما NULL
```
**V-05:** `feeAmount >= 0` (القيمة الافتراضية 0 إذا لم تُقدَّم)
**V-06:** إذا `feeAmount > 0`: `feeCurrency` إلزامي وصالح — وإلا: FAIL بـ `INVALID_ATM_FEE_CURRENCY`
**V-07:** إذا `feeAmount > 0` و `chargedAmount` موجود: `feeAmount < chargedAmount`
```
cashPortionAmount = chargedAmount - feeAmount
cashPortionAmount يجب أن يكون > 0
```
إذا انتُهك: FAIL بـ `FEE_EXCEEDS_CHARGED_AMOUNT`

---

### Cost Basis Derivation

```
إذا chargedAmount موجود و feeAmount > 0:
  cashPortionAmount     = chargedAmount - feeAmount
  lotHomeCurrencyAmount = cashPortionAmount        -- الـ fee مُستبعَدة من الـ lot

إذا chargedAmount موجود و feeAmount = 0 (أو NULL):
  cashPortionAmount     = chargedAmount
  lotHomeCurrencyAmount = chargedAmount

إذا chargedAmount = NULL:
  cashPortionAmount     = NULL
  lotHomeCurrencyAmount = NULL                     -- لا يوجد cost basis
```

**القاعدة:** رسوم الـ ATM لا تُضاف إلى الـ Cash Lot.
إضافتها سيُؤدي إلى double-counting: الرسوم ستُحتسب مرة كـ cost basis للنقد، ومرة كـ Card Expense.

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
```

---

### DB Writes (داخل Transaction واحد)

```
-- Step 1: Cash Lot (Money Movement — النقد المُكتسب)
W-01: INSERT cash_lots
        id                   = newUUID()
        trip_id              = tripId
        source_type          = 'atm_withdrawal'
        source_ref_type      = 'cash_transaction'   -- يُحدَّث في W-03
        source_ref_id        = ''                   -- placeholder، يُحدَّث في W-03
        currency_code        = receivedCurrency
        original_amount      = receivedAmount
        remaining_amount     = receivedAmount
        home_currency_amount = lotHomeCurrencyAmount -- cashPortionAmount أو NULL
        home_currency_code   = chargedCurrency       -- NULL إذا لا يوجد chargedAmount
        effective_rate       = lotHomeCurrencyAmount / receivedAmount  -- NULL إذا لا يوجد
        is_fully_consumed    = 0
        is_reversed          = 0
        created_at           = createdAt ?? now()

-- Step 2: Audit Trail
W-02: INSERT cash_transactions
        id                   = newUUID()
        trip_id              = tripId
        type                 = 'atm_withdrawal'
        amount               = receivedAmount
        currency_code        = receivedCurrency
        home_currency_amount = lotHomeCurrencyAmount
        home_currency_code   = chargedCurrency
        lot_id               = W-01.id
        expense_id           = NULL
        exchange_id          = NULL
        is_reversed          = 0
        note                 = note
        created_at           = createdAt ?? now()

W-03: UPDATE cash_lots
        SET source_ref_id = W-02.id
        WHERE id = W-01.id

-- Step 3: Cash Balance Cache
W-04: UPSERT trip_cash_balances
        SET balance_amount = balance_amount + receivedAmount
        WHERE trip_id = tripId AND currency_code = receivedCurrency

-- Step 4: ATM Fee → Card Expense (اختياري — يُنفَّذ فقط إذا feeAmount > 0)
W-05 [conditional — فقط إذا feeAmount > 0]:
      INSERT expenses
        id                    = newUUID()
        trip_id               = tripId
        payment_type          = 'card'               -- ⚠️ CARD, NOT CASH
        title                 = feeNote ?? 'ATM Fee'
        category              = 'fees'
        transaction_amount    = feeAmount
        transaction_currency  = feeCurrency
        original_amount       = feeAmount
        original_currency     = feeCurrency
        converted_home_amount = feeAmount            -- إذا feeCurrency = trip.home_currency_snapshot
                                                     -- وإلا NULL (يحتاج manual rate)
        home_currency         = trip.home_currency_snapshot إذا feeCurrency يطابقه، وإلا NULL
        conversion_rate       = 1.0 إذا feeCurrency = home_currency، وإلا NULL
        payment_method        = 'Credit Card'        -- الرسوم مُخصومة من البطاقة
        payment_channel       = 'ATM Withdrawal Fee'
        payment_network       = NULL
        card_profile_id       = fundingCardId        -- NULL إذا لم تُقدَّم
        is_international      = (feeCurrency ≠ trip.home_currency_snapshot) ? 1 : 0
        source                = 'manual'
        note                  = feeNote
        spent_at              = createdAt ?? now()
        created_at            = now()
        updated_at            = now()
        is_reversed           = 0
```

> **ملاحظة التنفيذ — Circular Reference:**
> `cash_lots.source_ref_id → cash_transactions.id` و `cash_transactions.lot_id → cash_lots.id`.
> الحل: أنشئ الـ lot بـ `source_ref_id = ''`، ثم الـ transaction، ثم حدّث `source_ref_id`.
> كل ذلك داخل نفس DB transaction.

---

### Atomicity

W-01 → W-02 → W-03 → W-04 → W-05 كلها داخل **DB transaction واحد**.
إذا فشل W-05: rollback كامل بما فيه الـ Cash Lot.

---

### Financial Invariant — ATM Fee

```
ATM Fee يجب أن:
  ✅ يُسجَّل كـ Card Expense (payment_type = 'card')
  ✅ يرفع Gross Spending
  ✅ يرفع Net Spending
  ✅ يرفع Net Trip Cost
  ✅ يظهر في تقرير الإنفاق تحت category = 'fees'

ATM Fee يجب أن لا:
  ❌ يُنشئ Cash Lot
  ❌ يستهلك Cash Lot
  ❌ يُؤثر على Cash Wallet Balance
  ❌ يُضاف إلى cost basis الـ Cash Lot (double-counting)
```

**معادلة الـ Cost Basis:**
```
ATM Cash Lot Cost Basis = chargedAmount - feeAmount
```

---

### Reporting Impact

**Cash Acquisition section:**
```
Cash Received:   receivedAmount receivedCurrency
Cost Basis:      cashPortionAmount chargedCurrency  (excluding fee)
```

**Spending section:**
```
ATM Fee تظهر كمصروف عادي:
  Category: fees
  Payment Type: card
  Amount: feeAmount feeCurrency
```

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |
| `INVALID_AMOUNT` | `receivedAmount` ≤ 0 |
| `INVALID_CURRENCY` | `receivedCurrency` غير صالح |
| `INVALID_CHARGED_AMOUNT` | `chargedAmount` موجود بدون `chargedCurrency` أو العكس |
| `INVALID_ATM_FEE_CURRENCY` | `feeAmount > 0` و `feeCurrency` مفقود أو غير صالح |
| `FEE_EXCEEDS_CHARGED_AMOUNT` | `feeAmount >= chargedAmount` (لا يوجد cash portion) |

---

### Reversal

شرط مسبق: `SUM(active consumptions from lot) = 0` — الـ lot لم يُستهلك بعد.
إذا كان مستهلكاً: الـ reversal يفشل بـ `LOT_ALREADY_CONSUMED`.

```
عبر ReverseFinancialEvent(eventType='atm_withdrawal', eventId=cash_transaction.id):
  1. Mark cash_lots.is_reversed = 1, remaining_amount = 0, is_fully_consumed = 1
  2. Mark cash_transactions.is_reversed = 1
  3. Update trip_cash_balances -= receivedAmount
```

> **قرار معماري — ATM Withdrawal Reversal ≠ ATM Fee Reversal (الخيار A المعتمد):**
>
> عكس سحب الـ ATM **لا يعكس مصروف الرسوم تلقائياً**.
> الرسوم والسحب حدثان ماليان مستقلان تماماً — كل منهما يُعكس بشكل منفصل:
>
> ```
> ReverseFinancialEvent(eventType='atm_withdrawal', eventId=cash_tx.id)
>   → يعكس: cash_lot, cash_transaction, trip_cash_balances
>   → لا يمس: fee expense
>
> ReverseFinancialEvent(eventType='card_expense', eventId=fee_expense.id)
>   → يعكس: fee expense فقط
> ```
>
> **السبب:** الربط التلقائي (Cascade Reversal) يخلق Coupling غير ضروري ويُعقِّد التنفيذ.
> المستخدم قادر على عكس كل حدث على حدة إذا احتاج.
> الـ UI هو المسؤول عن تقديم "عكس العملية كاملة" كـ shortcut إذا طُلب ذلك مستقبلاً.

---

### Test Cases

```
TC-01: Happy Path — With Cost Basis, No Fee
  Input: receivedAmount=100 THB, chargedAmount=10 SAR, chargedCurrency='SAR'
  Expected:
    - cash_lots: original=100, home_amount=10, effective_rate=0.1
    - cash_transactions: type='atm_withdrawal', lot_id=lot.id
    - trip_cash_balances: THB += 100
    - no fee expense created

TC-02: Happy Path — Without Cost Basis
  Input: receivedAmount=100 THB, chargedAmount=NULL
  Expected:
    - cash_lots: effective_rate=NULL, home_currency_amount=NULL
    - Operation succeeds

TC-03: Reversal — Unconsumed Lot
  Given: lot with remaining = original_amount
  Expected: lot marked reversed, balance restored

TC-04: Reversal — Partially Consumed Lot
  Given: lot with remaining < original_amount
  Expected: FAIL with LOT_ALREADY_CONSUMED

TC-05: effective_rate Calculation
  Input: receivedAmount=200, chargedAmount=760, feeAmount=0
  Expected: lot.effective_rate = 760/200 = 3.80

TC-06: source_ref linkage
  Expected: lot.source_ref_type='cash_transaction', lot.source_ref_id=cash_tx.id

TC-ATM-FEE-01: Fee Present — Cost Basis Correct
  Input:
    receivedAmount=20000, receivedCurrency='THB'
    chargedAmount=2150,   chargedCurrency='SAR'
    feeAmount=30,         feeCurrency='SAR'
  Expected:
    - cashPortionAmount = 2150 - 30 = 2120 SAR
    - cash_lot: original=20000 THB, home_amount=2120 SAR, effective_rate=2120/20000=0.106
    - fee expense: payment_type='card', amount=30 SAR, category='fees'
    - trip_cash_balances: THB += 20000
    - trip_cash_balances: SAR unchanged (fee is Card Expense, not cash)
    - Gross Spending increases by 30 SAR

TC-ATM-FEE-02: Fee = 0 — No Fee Expense
  Input: receivedAmount=100, chargedAmount=375, feeAmount=0
  Expected:
    - cashPortionAmount = 375 (unchanged)
    - cash_lot: home_amount=375
    - no fee expense created (W-05 skipped)

TC-ATM-FEE-03: Fee Without feeCurrency
  Input: feeAmount=30, feeCurrency=NULL
  Expected: FAIL with INVALID_ATM_FEE_CURRENCY

TC-ATM-FEE-04: Fee Equals chargedAmount
  Input: chargedAmount=30, feeAmount=30
  Expected: FAIL with FEE_EXCEEDS_CHARGED_AMOUNT (cashPortionAmount = 0)

TC-ATM-FEE-05: Fee Exceeds chargedAmount
  Input: chargedAmount=25, feeAmount=30
  Expected: FAIL with FEE_EXCEEDS_CHARGED_AMOUNT

TC-ATM-FEE-06: Fee Is Card Expense — No Cash Impact
  Input: feeAmount=15, feeCurrency='SAR'
  Expected:
    - fee expense payment_type = 'card' (NOT 'cash')
    - trip_cash_balances for SAR: unchanged
    - cash_lot contains NO fee amount in home_currency_amount
```

---

## Use Case 4: RecordCurrencyExchange

### Purpose
تسجيل عملية تحويل عملة. تستهلك من لوتات العملة الأصلية عبر FIFO وتُنشئ lot جديد للعملة الجديدة مع نقل cost basis.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `fromCurrencyCode` | String | ✅ | العملة المُباعة |
| `fromAmount` | Double | ✅ | المبلغ المُباع |
| `toCurrencyCode` | String | ✅ | العملة المُستلمة |
| `toAmount` | Double | ✅ | المبلغ المُستلم |
| `note` | String | ❌ | ملاحظة |
| `createdAt` | DateTime | ❌ | وقت العملية |

**ملاحظة:** `exchange_rate` يُحسب تلقائياً: `toAmount / fromAmount`.

---

### Preconditions

- الرحلة موجودة
- يوجد رصيد كافٍ بعملة `fromCurrencyCode`

---

### Validations

**V-01:** `fromAmount > 0` و `toAmount > 0`
**V-02:** `fromCurrencyCode ≠ toCurrencyCode`
**V-03:** كلا العملتين صالحتان (3 أحرف كبيرة)
**V-04:** رصيد كافٍ بعملة `fromCurrencyCode`:
```
SUM(cash_lots.remaining_amount)
WHERE trip_id = tripId AND currency_code = fromCurrencyCode
  AND is_reversed = 0 AND is_fully_consumed = 0
≥ fromAmount
```

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
R-02: FIFO Lot Selection: tripId, fromCurrencyCode, fromAmount
      → List<{lot, consumed_amount, home_amount, home_currency_code}>
```

---

### DB Writes (داخل Transaction واحد)

```
W-01: INSERT cash_lots  (to-currency lot)
        id                   = newUUID()  -- to_lot_id
        trip_id              = tripId
        source_type          = 'exchange_in'
        source_ref_type      = 'currency_exchange'
        source_ref_id        = W-02.id  (يُحدَّث في W-03)
        currency_code        = toCurrencyCode
        original_amount      = toAmount
        remaining_amount     = toAmount
        home_currency_amount = SUM(R-02.home_amount)  -- NULL إذا لا يوجد
        home_currency_code   = R-02[0].home_currency_code  -- NULL إذا لا يوجد
        effective_rate       = home_currency_amount / toAmount  -- NULL إذا لا يوجد
        is_fully_consumed    = 0
        is_reversed          = 0
        created_at           = createdAt ?? now()

W-02: INSERT currency_exchanges
        id                   = newUUID()
        trip_id              = tripId
        from_currency_code   = fromCurrencyCode
        from_amount          = fromAmount
        to_currency_code     = toCurrencyCode
        to_amount            = toAmount
        exchange_rate        = toAmount / fromAmount
        to_lot_id            = W-01.id
        is_reversed          = 0
        note                 = note
        created_at           = createdAt ?? now()

W-03: UPDATE cash_lots
        SET source_ref_id = W-02.id
        WHERE id = W-01.id

W-04: FOR each consumption in FIFO result:
      INSERT cash_lot_consumptions
        id               = newUUID()
        lot_id           = consumption.lot.id
        consumption_type = 'exchange_out'
        expense_id       = NULL
        exchange_id      = W-02.id
        consumed_amount  = consumption.consumed_amount
        home_amount      = consumption.home_amount
        home_currency_code = consumption.home_currency_code
        is_reversed      = 0
        created_at       = now()

W-05: FOR each consumption in FIFO result:
      UPDATE cash_lots
        SET remaining_amount  = remaining_amount - consumption.consumed_amount,
            is_fully_consumed = (result = 0) ? 1 : 0
        WHERE id = consumption.lot.id

W-06: INSERT cash_transactions (exchange_out)
        id           = newUUID()
        trip_id      = tripId
        type         = 'currency_exchange_out'
        amount       = fromAmount
        currency_code = fromCurrencyCode
        home_currency_amount = SUM(R-02.home_amount)
        home_currency_code   = R-02[0].home_currency_code
        lot_id       = NULL
        expense_id   = NULL
        exchange_id  = W-02.id
        is_reversed  = 0
        note         = note
        created_at   = createdAt ?? now()

W-07: INSERT cash_transactions (exchange_in)
        id           = newUUID()
        trip_id      = tripId
        type         = 'currency_exchange_in'
        amount       = toAmount
        currency_code = toCurrencyCode
        home_currency_amount = W-01.home_currency_amount
        home_currency_code   = W-01.home_currency_code
        lot_id       = W-01.id
        expense_id   = NULL
        exchange_id  = W-02.id
        is_reversed  = 0
        note         = note
        created_at   = createdAt ?? now()

W-08: UPSERT trip_cash_balances
        fromCurrencyCode: balance -= fromAmount
        toCurrencyCode:   balance += toAmount
```

---

### Cost Basis Transfer Logic

```
W-01.home_currency_amount = SUM(consumption.home_amount for all FIFO consumptions)

هذا هو نقل الـ cost basis:
  ما دفعته بالعملة القديمة (بعملة المنزل) يُصبح cost basis للعملة الجديدة.

مثال:
  صرف 100 USD → 90 EUR
  Lot A: 60 USD (cost: 225 SAR) → consumed_amount=60, home=225
  Lot B: 40 USD (cost: 152 SAR) → consumed_amount=40, home=152
  إجمالي cost basis: 377 SAR
  EUR lot: original=90, home_currency_amount=377, effective_rate=377/90≈4.19 SAR/EUR
```

---

### Atomicity

W-01 → W-02 → W-03 → W-04 → W-05 → W-06 → W-07 → W-08 داخل DB transaction واحد.

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |
| `SAME_CURRENCY` | from = to |
| `INVALID_AMOUNT` | أي مبلغ ≤ 0 |
| `INSUFFICIENT_CASH` | رصيد fromCurrency غير كافٍ |
| `NO_CASH_LOTS` | لا يوجد نقد بهذه العملة |

---

### Reversal

عبر `ReverseFinancialEvent(eventType='currency_exchange', eventId=exchange.id)`:

شرط مسبق: `to_lot.remaining_amount = to_lot.original_amount` — الـ to_lot لم يُستهلك.
إذا استُهلك: FAIL بـ `LOT_ALREADY_CONSUMED`.

```
1. Mark currency_exchanges.is_reversed = 1
2. Mark to_lot: is_reversed=1, remaining=0, is_fully_consumed=1
3. Mark cash_lot_consumptions.is_reversed=1 لكل consumption بـ exchange_id=exchange.id
4. Restore each from-lot: remaining += consumed_amount, is_fully_consumed=0
5. Mark cash_transactions × 2 (exchange_in + exchange_out): is_reversed=1
6. UPSERT trip_cash_balances:
   fromCurrencyCode: balance += fromAmount
   toCurrencyCode:   balance -= toAmount
```

---

### Test Cases

```
TC-01: Happy Path — Single From-Lot
  Given: Lot A = 100 USD (rate=3.75 SAR)
  Input: from=100 USD, to=90 EUR
  Expected:
    - Lot A: fully_consumed=1
    - EUR lot: original=90, home_amount=375 SAR, effective_rate=375/90≈4.17
    - currency_exchanges: exchange_rate=90/100=0.9
    - 2 cash_transactions created

TC-02: Happy Path — Multi-Lot FIFO
  Given: Lot A=60 USD (3.75), Lot B=80 USD (3.80)
  Input: from=80 USD, to=72 EUR
  Expected:
    - Lot A fully consumed (60 USD, home=225)
    - Lot B: remaining=40 (consumed 20 USD, home=76)
    - EUR lot: home_amount=301, effective_rate=301/72≈4.18

TC-03: Cost Basis Transfer — No Home Rate
  Given: Lot A = 100 USD, effective_rate=NULL
  Input: from=100 USD, to=90 EUR
  Expected:
    - EUR lot: home_currency_amount=NULL
    - Operation succeeds

TC-04: Insufficient Balance
  Given: available=50 USD
  Input: from=80 USD
  Expected: FAIL with INSUFFICIENT_CASH

TC-05: Same Currency
  Input: from='USD', to='USD'
  Expected: FAIL with SAME_CURRENCY

TC-06: Reversal — Unconsumed to_lot
  Expected: full reversal, from-lots restored

TC-07: Reversal — Consumed to_lot
  Given: to_lot has been spent on expense
  Expected: FAIL with LOT_ALREADY_CONSUMED
```

---

## Use Case 5: RecordCashRefund

### Purpose
تسجيل استرجاع مبلغ إلى النقد. يُنشئ Lot جديد بـ cost basis موروث من المصروف الأصلي (Refund Lot Inheritance). يُحدّث الرصيد.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `expenseId` | String | ❌ | المصروف المُسترجع منه — إذا NULL: Unlinked Refund |
| `amount` | Double | ✅ | مبلغ الاسترجاع |
| `currencyCode` | String | ✅ | عملة الاسترجاع |
| `homeAmount` | Double | ❌* | المبلغ بعملة المنزل (cost basis) — إلزامي للـ Unlinked Refund |
| `homeCurrency` | String | ❌* | عملة المنزل — إلزامي للـ Unlinked Refund |
| `note` | String | ❌ | ملاحظة |

> **Unlinked Refund:** استرجاع بدون `expenseId` — مثال: استرجاع من جهة خارجية غير مرتبطة بمصروف مُسجَّل.
> يُعامَل كمصدر نقدي مستقل وليس كتصحيح لمصروف موجود.

---

### Preconditions

- الرحلة موجودة
- إذا `expenseId` موجود: المصروف موجود وينتمي لنفس الرحلة وغير مُعكوس

---

### Validations

**V-01:** `amount > 0`
**V-02:** `currencyCode` صالح
**V-03:** إذا `homeAmount` موجود: `homeAmount > 0` و `homeCurrency` موجود
**V-04:** Over-refund guard (إذا `expenseId` موجود):
```
SUM(expense_refunds.home_amount)
WHERE expense_id = expenseId AND is_reversed = 0
+ homeAmount
≤ expenses.converted_home_amount WHERE id = expenseId
```
إذا انتُهك: FAIL بـ `OVER_REFUND`.

**V-05:** Unlinked Refund — إذا `expenseId = NULL`:
```
homeAmount و homeCurrency إلزاميان
لأن الـ lot لا يمكنه اشتقاق cost basis من مصروف أصلي
```
إذا انتُهك: FAIL بـ `MISSING_COST_BASIS_FOR_UNLINKED_REFUND`.

**ملاحظة:** إذا `homeAmount = NULL` أو `expenses.converted_home_amount = NULL`، تُتجاوز قاعدة V-04 فقط.

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
R-02: إذا expenseId موجود:
      SELECT expense WHERE id = expenseId AND trip_id = tripId
R-03: إذا expenseId موجود:
      SELECT SUM(home_amount) FROM expense_refunds
      WHERE expense_id = expenseId AND is_reversed = 0
```

---

### DB Writes (داخل Transaction واحد)

```
W-01: INSERT cash_lots
        id                   = newUUID()  -- returned_lot_id
        trip_id              = tripId
        source_type          = 'cash_refund'
        source_ref_type      = 'expense_refund'
        source_ref_id        = W-02.id  (يُحدَّث في W-03)
        currency_code        = currencyCode
        original_amount      = amount
        remaining_amount     = amount
        home_currency_amount = homeAmount
        home_currency_code   = homeCurrency
        effective_rate       = homeAmount / amount  -- NULL إذا لا يوجد
        is_fully_consumed    = 0
        is_reversed          = 0
        created_at           = now()

W-02: INSERT expense_refunds
        id              = newUUID()
        trip_id         = tripId
        expense_id      = expenseId          -- NULL إذا Unlinked Refund
        amount          = amount
        currency_code   = currencyCode
        home_amount     = homeAmount
        home_currency   = homeCurrency
        destination     = 'cash'
        returned_lot_id = W-01.id
        is_reversed     = 0
        note            = note
        created_at      = now()
        -- is_unlinked مُشتق: expense_id IS NULL → unlinked = true (لا عمود إضافي مطلوب)

W-03: UPDATE cash_lots
        SET source_ref_id = W-02.id
        WHERE id = W-01.id

W-04: INSERT cash_transactions
        id                   = newUUID()
        trip_id              = tripId
        type                 = 'cash_refund'
        amount               = amount
        currency_code        = currencyCode
        home_currency_amount = homeAmount
        home_currency_code   = homeCurrency
        lot_id               = W-01.id
        expense_id           = expenseId
        exchange_id          = NULL
        is_reversed          = 0
        note                 = note
        created_at           = now()

W-05: UPSERT trip_cash_balances
        SET balance_amount = balance_amount + amount
        WHERE trip_id = tripId AND currency_code = currencyCode
```

---

### Refund Lot Inheritance

الـ lot الجديد يرث الـ cost basis من `homeAmount`:
```
lot.home_currency_amount = homeAmount (من المصروف الأصلي)
lot.effective_rate = homeAmount / amount
```
هذا يعني: النقد المُسترجع له نفس "ثمن الشراء" كالنقد الأصلي الذي استُخدم للمصروف.

---

### Atomicity

W-01 → W-02 → W-03 → W-04 → W-05 داخل DB transaction واحد.

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |
| `EXPENSE_NOT_FOUND` | المصروف غير موجود أو لا ينتمي للرحلة أو مُعكوس |
| `INVALID_AMOUNT` | المبلغ ≤ 0 |
| `OVER_REFUND` | الاسترجاع يتجاوز قيمة المصروف |
| `INVALID_COST_BASIS` | homeAmount بدون homeCurrency أو العكس |
| `MISSING_COST_BASIS_FOR_UNLINKED_REFUND` | Unlinked Refund بدون homeAmount/homeCurrency |

---

### Reversal

عبر `ReverseFinancialEvent(eventType='cash_refund', eventId=refund.id)`:

```
1. Mark expense_refunds.is_reversed = 1
2. Mark returned_lot: is_reversed=1, remaining=0, is_fully_consumed=1
   شرط: returned_lot.remaining = returned_lot.original (لم يُستهلك)
   إذا استُهلك: FAIL بـ LOT_ALREADY_CONSUMED
3. Mark cash_transactions.is_reversed = 1
4. Update trip_cash_balances -= amount
```

---

### Test Cases

```
TC-01: Happy Path — With Linked Expense
  Given: expense.converted_home_amount=375 SAR, no prior refunds
  Input: amount=100 USD, homeAmount=375 SAR
  Expected:
    - returned_lot: original=100, home_amount=375, rate=3.75
    - expense_refunds: destination='cash', returned_lot_id=lot.id
    - trip_cash_balances: USD += 100

TC-02: Unlinked Refund — With Cost Basis
  Input: expenseId=NULL, homeAmount=200 SAR, homeCurrency='SAR'
  Expected:
    - refund created with expense_id=NULL
    - lot created with home_amount=200, effective_rate=200/amount
    - no over-refund check performed
    - report must display this refund as "Unlinked"

TC-02b: Unlinked Refund — Missing Cost Basis
  Input: expenseId=NULL, homeAmount=NULL
  Expected: FAIL with MISSING_COST_BASIS_FOR_UNLINKED_REFUND

TC-03: Over-Refund Blocked
  Given: expense.converted_home_amount=375, prior refund home_amount=200
  Input: homeAmount=200
  Expected: FAIL with OVER_REFUND (200+200=400 > 375)

TC-04: Partial Refund
  Given: expense.converted_home_amount=375
  Input: homeAmount=100
  Expected: succeeds (100 ≤ 375)

TC-05: Refund Without Home Amount
  Input: homeAmount=NULL
  Expected: lot.effective_rate=NULL, succeeds

TC-06: Cost Basis Inheritance Check
  Input: amount=50 USD, homeAmount=190 SAR
  Expected: lot.effective_rate = 190/50 = 3.80
```

---

## Use Case 6: RecordCardRefund

### Purpose
تسجيل استرجاع لبطاقة. لا يُؤثر على النقد. يُقلّل Net Spending في التقرير.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |
| `expenseId` | String | ❌ | المصروف المُسترجع منه — إذا NULL: Unlinked Refund |
| `amount` | Double | ✅ | مبلغ الاسترجاع |
| `currencyCode` | String | ✅ | عملة الاسترجاع |
| `homeAmount` | Double | ❌ | المبلغ بعملة المنزل |
| `homeCurrency` | String | ❌ | عملة المنزل |
| `note` | String | ❌ | ملاحظة |

> **Unlinked Card Refund:** استرجاع على البطاقة بدون `expenseId`.
> لا يحتاج cost basis إلزامياً لأنه لا يُنشئ Lot.
> لكن يُسمح بـ `homeAmount` اختيارياً لتمكين Net Spending في التقرير.
> يجب أن يظهر في التقرير كـ "Unlinked" بوضوح.

---

### Validations

**V-01 → V-04:** نفس RecordCashRefund (عدا V-05 — لا ينطبق لأن Card Refund لا يُنشئ lot)
**V-05:** لا فحص على الرصيد — البطاقة لا تُؤثر على النقد
**V-06:** إذا `expenseId = NULL` و `homeAmount` موجود: `homeCurrency` إلزامي (وإلا snapshot incoherent)

---

### DB Reads

```
R-01: SELECT trip WHERE id = tripId
R-02: إذا expenseId موجود: SELECT expense
R-03: إذا expenseId موجود: SUM prior refunds (over-refund guard)
```

---

### DB Writes (داخل Transaction واحد)

```
W-01: INSERT expense_refunds
        id              = newUUID()
        trip_id         = tripId
        expense_id      = expenseId          -- NULL إذا Unlinked Refund
        amount          = amount
        currency_code   = currencyCode
        home_amount     = homeAmount
        home_currency   = homeCurrency
        destination     = 'card'
        returned_lot_id = NULL               -- دائماً NULL لـ Card Refunds
        is_reversed     = 0
        note            = note
        created_at      = now()
        -- is_unlinked مُشتق: expense_id IS NULL → unlinked = true (لا عمود إضافي مطلوب)
```

لا كتابات على cash_lots أو cash_transactions أو trip_cash_balances.

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |
| `EXPENSE_NOT_FOUND` | المصروف غير موجود |
| `OVER_REFUND` | الاسترجاع يتجاوز قيمة المصروف |

---

### Reversal

```
Mark expense_refunds.is_reversed = 1
-- لا تأثير على cash_lots أو cash_transactions
```

---

### Test Cases

```
TC-01: Happy Path — Linked
  Expected: expense_refunds.destination='card', returned_lot_id=NULL, expense_id set

TC-02: Over-Refund Blocked
  Same as TC-03 in RecordCashRefund

TC-03: No Cash Impact
  Expected: trip_cash_balances unchanged, no cash_lots created

TC-04: Net Spending Impact
  Given: expense.converted_home_amount=375, card refund home_amount=100
  Expected: TripFinancialReport.netSpending = 375 - 100 = 275

TC-05: Unlinked Card Refund — With homeAmount
  Input: expenseId=NULL, homeAmount=100, homeCurrency='SAR'
  Expected:
    - expense_id = NULL
    - home_amount stored
    - report shows as Unlinked Refund
    - contributes to Net Spending calculation

TC-06: Unlinked Card Refund — Without homeAmount
  Input: expenseId=NULL, homeAmount=NULL
  Expected: succeeds (homeAmount optional for card refund)
```

---

## Use Case 7: ReverseFinancialEvent

### Purpose
عكس أي حدث مالي سابق. الـ reversal يستعيد الحالة كما كانت قبل الحدث، مع الحفاظ على الـ audit trail.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `eventType` | Enum | ✅ | نوع الحدث |
| `eventId` | String | ✅ | معرف الحدث |

**EventType Values:**
```
'cash_expense'        → يُعكس النقد ثم يُعلَّم الـ expense كـ reversed (Soft)
'card_expense'        → يُعلَّم الـ expense كـ reversed (Soft) — لا تأثير على النقد
'atm_withdrawal'      → يُعكس cash_transaction
'currency_exchange'   → يُعكس currency_exchange
'cash_refund'         → يُعكس expense_refund (destination='cash')
'card_refund'         → يُعكس expense_refund (destination='card')
```

---

### Preconditions per Event Type

**cash_expense:**
- المصروف موجود و `expenses.is_reversed = 0`
- جميع cash_lot_consumptions المرتبطة به غير مُعكوسة

**atm_withdrawal:**
- الـ cash_transaction موجود وغير مُعكوسة
- الـ lot المُنشأ منه `remaining_amount = original_amount` (لم يُستهلك)

**currency_exchange:**
- الـ exchange موجود وغير مُعكوس
- `to_lot.remaining_amount = to_lot.original_amount` (لم يُستهلك)

**cash_refund:**
- الـ refund موجود وغير مُعكوس
- `returned_lot.remaining_amount = returned_lot.original_amount` (لم يُستهلك)

---

### DB Reads (تختلف حسب eventType)

```
cash_expense:
  R-01: SELECT expense WHERE id = eventId
  R-02: SELECT cash_lot_consumptions WHERE expense_id = eventId AND is_reversed = 0
  R-03: SELECT cash_transactions WHERE expense_id = eventId AND type = 'cash_expense_deduction'

atm_withdrawal:
  R-01: SELECT cash_transactions WHERE id = eventId
  R-02: SELECT cash_lots WHERE id = transaction.lot_id
  R-03: SELECT SUM(consumed) FROM cash_lot_consumptions WHERE lot_id = lot.id AND is_reversed=0

currency_exchange:
  R-01: SELECT currency_exchanges WHERE id = eventId
  R-02: SELECT cash_lots WHERE id = exchange.to_lot_id
  R-03: SELECT cash_lot_consumptions WHERE exchange_id = eventId AND is_reversed=0

cash_refund:
  R-01: SELECT expense_refunds WHERE id = eventId
  R-02: SELECT cash_lots WHERE id = refund.returned_lot_id
```

---

### DB Writes per Event Type (داخل Transaction واحد)

**cash_expense:**
```
W-01: UPDATE cash_lot_consumptions
        SET is_reversed=1, reversed_at=now()
        WHERE expense_id = eventId AND is_reversed = 0

W-02: FOR each reversed consumption:
      UPDATE cash_lots
        SET remaining_amount += consumption.consumed_amount,
            is_fully_consumed = 0
        WHERE id = consumption.lot_id

W-03: UPDATE cash_transactions
        SET is_reversed=1, reversed_at=now()
        WHERE expense_id = eventId AND type='cash_expense_deduction'

W-04: UPDATE trip_cash_balances
        SET balance_amount += expense.transaction_amount
        WHERE trip_id = expense.trip_id AND currency_code = expense.transaction_currency

W-05: UPDATE expenses
        SET is_reversed  = 1,
            reversed_at  = now(),
            updated_at   = now()
        WHERE id = eventId
```

**card_expense:**
```
W-01: UPDATE expenses
        SET is_reversed  = 1,
            reversed_at  = now(),
            updated_at   = now()
        WHERE id = eventId
```

**atm_withdrawal:**
```
W-01: UPDATE cash_lots
        SET is_reversed=1, reversed_at=now(), remaining_amount=0, is_fully_consumed=1
        WHERE id = transaction.lot_id

W-02: UPDATE cash_transactions
        SET is_reversed=1, reversed_at=now()
        WHERE id = eventId

W-03: UPDATE trip_cash_balances
        SET balance_amount -= lot.original_amount
        WHERE trip_id AND currency_code = lot.currency_code
```

**currency_exchange:**
```
W-01: UPDATE currency_exchanges
        SET is_reversed=1, reversed_at=now()
        WHERE id = eventId

W-02: UPDATE cash_lots (to_lot)
        SET is_reversed=1, reversed_at=now(), remaining_amount=0, is_fully_consumed=1
        WHERE id = exchange.to_lot_id

W-03: UPDATE cash_lot_consumptions
        SET is_reversed=1, reversed_at=now()
        WHERE exchange_id = eventId AND is_reversed=0

W-04: FOR each reversed consumption:
      UPDATE cash_lots (from-lots)
        SET remaining_amount += consumption.consumed_amount,
            is_fully_consumed = 0
        WHERE id = consumption.lot_id

W-05: UPDATE cash_transactions × 2
        SET is_reversed=1, reversed_at=now()
        WHERE exchange_id = eventId

W-06: UPSERT trip_cash_balances:
        fromCurrency: balance += exchange.from_amount
        toCurrency:   balance -= exchange.to_amount
```

**cash_refund:**
```
W-01: UPDATE expense_refunds
        SET is_reversed=1, reversed_at=now()
        WHERE id = eventId

W-02: UPDATE cash_lots (returned_lot)
        SET is_reversed=1, reversed_at=now(), remaining_amount=0, is_fully_consumed=1
        WHERE id = refund.returned_lot_id

W-03: UPDATE cash_transactions
        SET is_reversed=1, reversed_at=now()
        WHERE expense_id = refund.expense_id AND type='cash_refund'
        -- أو: WHERE lot_id = refund.returned_lot_id

W-04: UPDATE trip_cash_balances
        SET balance_amount -= refund.amount
        WHERE trip_id AND currency_code = refund.currency_code
```

**card_refund:**
```
W-01: UPDATE expense_refunds
        SET is_reversed=1, reversed_at=now()
        WHERE id = eventId
```

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `EVENT_NOT_FOUND` | الحدث غير موجود |
| `ALREADY_REVERSED` | الحدث مُعكوس سابقاً |
| `LOT_ALREADY_CONSUMED` | الـ lot استُهلك جزئياً أو كلياً — لا يمكن العكس |
| `CONSUMPTION_STILL_ACTIVE` | يوجد consumptions نشطة تعتمد على هذا الـ lot |

---

### Test Cases

```
TC-01: Reverse Cash Expense — Single Lot
  Given: expense consumed 100 USD from Lot A
  Expected: Lot A.remaining += 100, consumption reversed, balance restored

TC-02: Reverse Cash Expense — Multi-Lot
  Given: expense consumed from Lot A (60) and Lot B (40)
  Expected: both consumptions reversed, both lots restored

TC-03: Reverse ATM — Unconsumed
  Given: lot with remaining = original
  Expected: lot reversed, balance -= original_amount

TC-04: Reverse ATM — Partially Consumed
  Expected: FAIL with LOT_ALREADY_CONSUMED

TC-05: Reverse Exchange — Unconsumed to_lot
  Expected: exchange reversed, to_lot reversed, from-lots restored

TC-06: Reverse Exchange — to_lot Spent
  Expected: FAIL with LOT_ALREADY_CONSUMED

TC-07: Double Reversal
  Expected: FAIL with ALREADY_REVERSED on second attempt

TC-08: Reverse Card Expense
  Expected: expense deleted, no cash impact

TC-09: Reverse Card Refund
  Expected: refund marked reversed, no cash impact
```

---

## Use Case 8: RecomputeCashBalances

### Purpose
إعادة حساب جميع أرصدة النقد من الـ Lots مباشرة لمعالجة أي تناقض بين `trip_cash_balances` (cache) و`cash_lots` (source of truth).

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ❌ | إذا NULL: يُعيد حساب كل الرحلات |

---

### Algorithm

```
FOR each (trip_id, currency_code) in scope:

  computed_balance =
    SELECT SUM(remaining_amount)
    FROM cash_lots
    WHERE trip_id = trip_id
      AND currency_code = currency_code
      AND is_reversed = 0

  UPSERT trip_cash_balances
    SET balance_amount = computed_balance ?? 0,
        updated_at = now()
    WHERE trip_id = trip_id AND currency_code = currency_code
```

---

### DB Reads

```
R-01: SELECT DISTINCT trip_id, currency_code FROM cash_lots
      WHERE (tripId IS NULL OR trip_id = tripId)
        AND is_reversed = 0

R-02: FOR each (trip_id, currency_code):
      SELECT SUM(remaining_amount) FROM cash_lots
      WHERE trip_id = ? AND currency_code = ? AND is_reversed = 0
```

---

### DB Writes

```
FOR each (trip_id, currency_code):
  UPSERT trip_cash_balances
    SET balance_amount = computed, updated_at = now()
```

---

### Atomicity

كل رحلة في DB transaction مستقل. الفشل في رحلة واحدة لا يُوقف الباقي.

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | إذا tripId موجود ولكن الرحلة غير موجودة |
| `DB_READ_ERROR` | خطأ في قراءة cash_lots |

---

### Test Cases

```
TC-01: Single Trip — Cache Matches Reality
  Given: balance_cache=100, SUM(lots.remaining)=100
  Expected: no change (write still happens with same value)

TC-02: Single Trip — Cache Diverged
  Given: balance_cache=150, SUM(lots.remaining)=100
  Expected: balance_cache updated to 100

TC-03: Trip With No Lots
  Given: no cash_lots for trip
  Expected: trip_cash_balances.balance_amount = 0

TC-04: Multi-Currency Trip
  Given: USD lots sum=100, EUR lots sum=50
  Expected: two upserts, each correct

TC-05: All Trips Recompute
  Input: tripId=NULL
  Expected: all trips recomputed

TC-06: Consistency Invariant Post-Recompute
  After execution:
  ∀ (trip_id, currency_code):
    trip_cash_balances.balance_amount
    = SUM(cash_lots.remaining_amount WHERE is_reversed=0)
```

---

## Use Case 9: GenerateTripFinancialReport

### Purpose
إنتاج التقرير المالي الكامل لرحلة واحدة. يشمل: Gross Spending، Net Spending، Remaining Cash Value، وNet Trip Cost.

---

### Inputs

| الحقل | النوع | إلزامي | الوصف |
|-------|-------|--------|-------|
| `tripId` | String | ✅ | معرف الرحلة |

---

### Preconditions

- الرحلة موجودة

---

### DB Reads (كلها للقراءة فقط — لا كتابات)

```
R-01: SELECT trip WHERE id = tripId
      → للحصول على home_currency_snapshot, name

R-02: SELECT * FROM expenses
      WHERE trip_id = tripId
        AND is_reversed = 0          -- استثناء المصروفات المُعكوسة
      ORDER BY spent_at DESC

R-03: SELECT * FROM expense_refunds
      WHERE trip_id = tripId AND is_reversed = 0

R-04: SELECT * FROM cash_lots
      WHERE trip_id = tripId AND is_reversed = 0

R-05: FOR each unique currency_code in R-04:
      -- effective_rate موجود مباشرة في cash_lots
      -- لا حاجة لحساب weighted average
```

---

### Computation

```
-- 1. Gross Spending
grossSpending = SUM(expenses.converted_home_amount)
                WHERE home_currency = trip.home_currency_snapshot
                  AND converted_home_amount IS NOT NULL
                  AND is_reversed = 0          -- استثناء المصروفات المُعكوسة
grossCurrency = trip.home_currency_snapshot

-- 2. Active Refunds (linked + unlinked)
-- Unlinked Refunds (expense_id IS NULL) مُدرجة في الحساب شرط وجود home_amount
activeRefunds = SUM(expense_refunds.home_amount)
                WHERE home_currency = trip.home_currency_snapshot
                  AND is_reversed = 0
                  AND home_amount IS NOT NULL
                  -- شامل unlinked (expense_id IS NULL) و linked (expense_id IS NOT NULL)

-- 3. Net Spending
netSpending = grossSpending - (activeRefunds ?? 0)

-- 4. Remaining Cash Value (FIFO-based)
-- NOTE: lot.effective_rate هو الـ cost basis الحقيقي المخزون على كل lot.
-- derivedDisplayRate هو معدل مُشتق للعرض فقط — يُجمع اللوتات المتعددة لعرض رقم واحد.
-- لا يُستخدم derivedDisplayRate في أي حساب مالي — الحساب الحقيقي هو SUM(remaining × lot.effective_rate).

remainingCashValues = []
FOR each currency_code WITH active lots (is_reversed=0, is_fully_consumed=0, remaining_amount > 0):
  activeLots = lots WHERE currency_code AND home_currency_code = trip.home_currency_snapshot
                      AND effective_rate IS NOT NULL

  IF activeLots is empty: SKIP this currency

  totalRemaining     = SUM(lot.remaining_amount) over activeLots
  totalHomeValue     = SUM(lot.remaining_amount × lot.effective_rate) over activeLots
  derivedDisplayRate = totalHomeValue / totalRemaining   -- للعرض فقط

  remainingCashValues.append({
    currencyCode:       currency_code,
    balance:            totalRemaining,
    derivedDisplayRate: derivedDisplayRate,    -- RENAMED: display only, not cost basis
    homeAmount:         totalHomeValue,         -- الحساب الحقيقي: SUM(remaining × lot.effective_rate)
    homeCurrency:       trip.home_currency_snapshot
  })

-- 5. Total Remaining Cash Value
totalRemainingCashHomeAmount = SUM(remainingCashValues.homeAmount)

-- 6. Net Trip Cost
netTripCost = netSpending - totalRemainingCashHomeAmount
```

---

### Report Output Structure

```
TripFinancialReport {
  tripId:                    String
  tripName:                  String
  homeCurrency:              String

  -- Counts
  totalExpenseCount:         Int
  internationalExpenseCount: Int
  domesticExpenseCount:      Int

  -- Spending Totals
  totalBilledByCurrency:     List<{currency, totalAmount, count}>
  totalFeesByCurrency:       List<{currency, totalAmount, count}>

  -- Breakdowns
  byCategory:                List<{key, currency, totalAmount, count}>
  byTransactionCurrency:     List<{currency, totalAmount, count}>
  byPaymentNetwork:          List<{key, currency, totalAmount, count}>
  byPaymentChannel:          List<{key, currency, totalAmount, count}>

  -- Home Currency Financials
  grossSpendingHomeAmount:   Double?
  grossSpendingHomeCurrency: String?
  refundHomeAmount:          Double?
  netSpendingHomeAmount:     Double?

  -- Cash Position
  remainingCashValues:       List<{currency, balance, derivedDisplayRate, homeAmount, homeCurrency}>
  --                                                    ↑ display only — not lot-level cost basis
  totalRemainingCashHome:    Double?

  -- Net Trip Cost
  netTripCostHomeAmount:     Double?
  netTripCostHomeCurrency:   String?

  -- Insights
  smartInsights:             List<Insight>
}
```

---

### Net Trip Cost — الحالات الممكنة

| grossSpending | remainingCash | netTripCost | الحالة |
|---------------|--------------|-------------|--------|
| NULL | any | NULL | لا يوجد بيانات تحويل |
| موجود | NULL | = netSpending | لا يوجد نقد بـ rate |
| موجود | موجود | = netSpending - remaining | الحالة المثالية |

---

### Failure Cases

| الكود | السبب |
|-------|-------|
| `TRIP_NOT_FOUND` | الرحلة غير موجودة |

---

### Test Cases

```
TC-01: Empty Trip
  Given: no expenses, no lots
  Expected:
    - totalExpenseCount = 0
    - grossSpending = NULL
    - netTripCost = NULL

TC-02: Card Expenses Only
  Given: 3 card expenses totaling 375 SAR converted
  Expected:
    - grossSpending = 375
    - remainingCashValues = []
    - netTripCost = 375

TC-03: Cash Expenses + Remaining Balance
  Given:
    - ATM: 200 USD, cost basis 750 SAR → lot (remaining=100 USD, rate=3.75)
    - Cash expense: 100 USD, cost basis 375 SAR
  Expected:
    - grossSpending = 375 SAR
    - remainingCashValues: [{USD, 100, 3.75, 375 SAR}]
    - netTripCost = 375 - 375 = 0

TC-04: Net Spending with Refund
  Given: card expense=375 SAR, card refund=100 SAR
  Expected:
    - grossSpending = 375
    - activeRefunds = 100
    - netSpending = 275
    - netTripCost = 275

TC-05: Multiple Currencies — Remaining Cash
  Given: USD lot (50 rem, rate=3.75) + EUR lot (30 rem, rate=4.10)
  Expected:
    - remainingCashValues: 2 entries
    - totalRemainingCash = (50×3.75) + (30×4.10) = 187.5 + 123 = 310.5

TC-06: Lots Without Effective Rate
  Given: lot with effective_rate=NULL
  Expected: lot excluded from remainingCashValues, no error

TC-07: Multi-Lot Weighted Effective Rate
  Given: USD lot A: remaining=100, rate=3.75
         USD lot B: remaining=50,  rate=3.80
  Expected:
    - weighted rate = (100×3.75 + 50×3.80) / 150 = 565/150 ≈ 3.767
    - homeAmount = 150 × 3.767 ≈ 565

TC-08: Reversed Refund Excluded
  Given: refund (home=100) with is_reversed=1
  Expected: refund NOT included in activeRefunds

TC-09: Home Currency Mismatch
  Given: some expenses with home_currency='USD', trip.home_currency_snapshot='SAR'
  Expected: only SAR expenses included in grossSpending
```

---

## Appendix A: Use Case Interaction Matrix

| Use Case | expenses | cash_lots | cash_lot_consumptions | cash_transactions | currency_exchanges | expense_refunds | trip_cash_balances |
|----------|----------|-----------|----------------------|-------------------|-------------------|-----------------|-------------------|
| RecordCashExpense | W | R+W | W | W | — | — | W |
| RecordCardExpense | W | — | — | — | — | — | — |
| RecordAtmWithdrawal | — | W | — | W | — | — | W |
| RecordCurrencyExchange | — | W | W | W | W | — | W |
| RecordCashRefund | — | W | — | W | — | W | W |
| RecordCardRefund | — | — | — | — | — | W | — |
| ReverseFinancialEvent | W | W | W | W | W | W | W |
| RecomputeCashBalances | — | R | — | — | — | — | W |
| GenerateTripFinancialReport | R | R | — | — | — | R | R |

---

## Appendix B: Financial Invariants Enforced per Use Case

| Invariant | RecordCash | RecordATM | RecordExchange | RecordRefund | Reverse | Report |
|-----------|-----------|-----------|---------------|-------------|---------|--------|
| I-01: Balance Consistency | ✅ | ✅ | ✅ | ✅ | ✅ | (verified) |
| I-02: Lot Amount Integrity | ✅ | — | ✅ | — | ✅ | — |
| I-03: Fully Consumed Flag | ✅ | — | ✅ | — | ✅ | — |
| I-04: No Over-Consumption | ✅ (FIFO guard) | — | ✅ | — | — | — |
| I-05: No Over-Refund | — | — | — | ✅ | — | — |
| I-06: Effective Rate | — | ✅ | ✅ | ✅ | — | (read) |
| I-07: Exchange Cost Basis | — | — | ✅ | — | — | — |
| I-08: Refund Lot Inheritance | — | — | — | ✅ | — | — |
| I-09: Reversal Completeness | — | — | — | — | ✅ | — |
| I-10: Payment Type | ✅ | — | — | — | — | — |
| I-11: Source Ref Traceability | — | ✅ | ✅ | ✅ | — | — |
