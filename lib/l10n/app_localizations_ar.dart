// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'متتبع مصاريف السفر';

  @override
  String get commonTryAgain => 'إعادة المحاولة';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRequiredField => 'هذا الحقل مطلوب.';

  @override
  String get commonEnterValidNumber => 'أدخل رقماً صالحاً.';

  @override
  String get tripsTitle => 'الرحلات';

  @override
  String get tripsLoadError => 'تعذر تحميل الرحلات.';

  @override
  String get tripsAddButton => 'إضافة رحلة';

  @override
  String get tripsEditTooltip => 'تعديل الرحلة';

  @override
  String get tripsDeleteTooltip => 'حذف الرحلة';

  @override
  String get tripsDeleteDialogTitle => 'حذف الرحلة؟';

  @override
  String tripsDeleteDialogMessage(Object tripName) {
    return 'سيؤدي هذا إلى حذف $tripName وجميع المصاريف المرتبطة بها نهائياً.';
  }

  @override
  String tripsDeleteError(Object error) {
    return 'فشل حذف الرحلة: $error';
  }

  @override
  String get tripsEmptyTitle => 'لا توجد رحلات بعد';

  @override
  String get tripsEmptyMessage => 'أنشئ رحلتك الأولى لبدء تتبع مصاريف السفر.';

  @override
  String get tripsDatesNeedAttention => 'الرجاء مراجعة التواريخ';

  @override
  String tripsBudgetLabel(Object amount) {
    return 'الميزانية: $amount';
  }

  @override
  String get tripFormCreateTitle => 'رحلة جديدة';

  @override
  String get tripFormEditTitle => 'تعديل الرحلة';

  @override
  String get tripFormNameLabel => 'اسم الرحلة';

  @override
  String get tripFormNameHint => 'مؤتمر الصيف';

  @override
  String get tripFormDestinationLabel => 'الوجهة';

  @override
  String get tripFormDestinationHint => 'إسطنبول، تركيا';

  @override
  String get tripFormCurrencyLabel => 'العملة الأساسية';

  @override
  String get tripFormBudgetLabel => 'الميزانية (اختياري)';

  @override
  String get tripFormBudgetHint => '2500';

  @override
  String get tripFormStartDateLabel => 'تاريخ البداية';

  @override
  String get tripFormEndDateLabel => 'تاريخ النهاية';

  @override
  String get tripFormSaveCreate => 'إنشاء الرحلة';

  @override
  String get tripFormSaveEdit => 'حفظ التغييرات';

  @override
  String get tripFormBudgetNonNegative => 'يجب أن تكون الميزانية صفراً أو أكثر.';

  @override
  String get tripFormStartDateBeforeEnd => 'يجب ألا يكون تاريخ البداية بعد تاريخ النهاية.';

  @override
  String get tripFormEndDateAfterStart => 'يجب أن يكون تاريخ النهاية في نفس يوم البداية أو بعده.';

  @override
  String get tripFormSaveDetails => 'حفظ التخصيصات';

  @override
  String get tripFormOverlapTitle => 'يوجد تداخل في التواريخ';

  @override
  String get tripFormOverlapIntro => 'يوجد تداخل مع رحلة أخرى:';

  @override
  String get tripFormOverlapHint => 'يمكنك المتابعة إذا كانت هذه رحلة فرعية أو ترانزيت.';

  @override
  String get tripFormOverlapEditDates => 'تعديل التواريخ';

  @override
  String get tripFormOverlapContinue => 'متابعة';

  @override
  String tripFormOverlapMoreTrips(Object count) {
    return '+ $count رحلة متداخلة إضافية';
  }

  @override
  String tripFormSaveError(Object error) {
    return 'فشل حفظ الرحلة: $error';
  }

  @override
  String get tripDetailsLoadError => 'تعذر تحميل المصاريف.';

  @override
  String get tripDetailsAddExpense => 'إضافة مصروف';

  @override
  String get tripDetailsEditTripTooltip => 'تعديل الرحلة';

  @override
  String get tripDetailsTotalExpenses => 'إجمالي المصاريف';

  @override
  String get tripDetailsExpenseCount => 'عدد المصاريف';

  @override
  String get tripDetailsTopCategory => 'أعلى فئة إنفاق';

  @override
  String get tripDetailsTopCategoryNone => 'لا توجد فئة بعد';

  @override
  String get tripDetailsExpensesSection => 'المصاريف';

  @override
  String get tripDetailsAddViaSms => 'إضافة من رسالة البنك';

  @override
  String get tripDetailsCashWalletAction => 'إدارة الكاش';

  @override
  String tripDetailsCashWalletRemainingCta(Object amount) {
    return '$amount متبقي';
  }

  @override
  String get cashWalletHeroTitle => 'الكاش المتبقي';

  @override
  String get cashWalletHeroSubtitle => 'الرصيد المتاح لهذه الرحلة';

  @override
  String get cashWalletCurrentBalanceHelper => 'الرصيد الحالي المتاح بعد جميع العمليات';

  @override
  String get cashWalletEmptyTitle => 'لم تضف أي كاش لهذه الرحلة بعد';

  @override
  String get cashWalletEmptySubtitle => 'أضف الكاش الذي تحمله لتتبع المتبقي أثناء السفر';

  @override
  String get cashWalletTripDatesPending => 'التواريخ غير محددة';

  @override
  String get cashWalletHealthTitle => 'حالة الكاش';

  @override
  String get cashWalletHealthNotEnoughData => 'لم نحسب الحالة بعد';

  @override
  String get cashWalletHealthExcellent => 'ممتاز';

  @override
  String get cashWalletHealthHealthy => 'جيد';

  @override
  String get cashWalletHealthMedium => 'متوسط';

  @override
  String get cashWalletHealthLow => 'منخفض';

  @override
  String get cashWalletHealthCritical => 'حرج';

  @override
  String get cashWalletLastAtmNotAvailable => 'آخر ATM: —';

  @override
  String get cashWalletOnboardingTitle => 'كم كاش تحمل معك؟';

  @override
  String get cashWalletOnboardingSkip => 'تخطي';

  @override
  String get cashWalletOnboardingCardsOnly => 'سأستخدم البطاقة فقط';

  @override
  String get cashWalletDailyBurnTitle => 'متوسط الصرف اليومي';

  @override
  String get cashWalletBurnNoData => 'ابدأ بإضافة مصروفات كاش لحساب معدل الصرف';

  @override
  String cashWalletRemainingDaysMessage(Object days) {
    return 'يكفي تقريبًا $days أيام';
  }

  @override
  String get cashWalletRemainingDaysNoData => 'سنحسب المدة المتوقعة بعد أول مصروف كاش';

  @override
  String get cashWalletBalancesTitle => 'الأرصدة حسب العملة';

  @override
  String get cashWalletRecentTransactionsTitle => 'آخر حركات الكاش';

  @override
  String get cashWalletNoBalances => 'لا توجد أرصدة كاش بعد.';

  @override
  String get cashWalletNoTransactions => 'لا توجد حركات كاش بعد.';

  @override
  String get cashWalletAddCash => 'إضافة كاش';

  @override
  String get cashWalletEditCash => 'تعديل حركة الكاش';

  @override
  String get cashWalletQuickAtmWithdrawal => 'سحب ATM';

  @override
  String get cashWalletQuickAtmShort => 'ATM';

  @override
  String cashWalletTripStatusDaysLeft(int days) {
    return 'متبقي $days أيام';
  }

  @override
  String cashWalletTripStatusStartsIn(int days) {
    return 'تبدأ بعد $days أيام';
  }

  @override
  String get cashWalletTripStatusStartsToday => 'تبدأ اليوم';

  @override
  String get cashWalletTripStatusCompleted => 'انتهت';

  @override
  String get cashWalletTripStatusActive => 'جارية';

  @override
  String get cashWalletGroupToday => 'اليوم';

  @override
  String get cashWalletGroupYesterday => 'أمس';

  @override
  String get cashWalletGroupEarlier => 'أقدم';

  @override
  String get cashWalletTransactionType => 'نوع الحركة';

  @override
  String get cashWalletTransactionTypeHelper => 'اختر نوع العملية التي قمت بها';

  @override
  String get cashWalletTypeInitialCash => 'كاش بداية الرحلة';

  @override
  String get cashWalletTypeAtmWithdrawal => 'سحب من صراف';

  @override
  String get cashWalletTypeCurrencyExchangeIn => 'تحويل عملة داخل';

  @override
  String get cashWalletTypeCurrencyExchangeOut => 'تحويل عملة خارج';

  @override
  String get cashWalletTypeManualAdjustment => 'تصحيح الرصيد';

  @override
  String get cashWalletTypeCashExpenseDeduction => 'خصم مصروف كاش';

  @override
  String get cashWalletTypeCashExpense => 'مصروف كاش';

  @override
  String get cashWalletEditExpenseAction => 'تعديل المصروف';

  @override
  String get cashWalletDeleteTransactionTitle => 'حذف حركة الكاش؟';

  @override
  String cashWalletDeleteTransactionTitleForType(Object transactionType) {
    return 'حذف $transactionType؟';
  }

  @override
  String get cashWalletDeleteTransactionMessage => 'سيتم عكس أثر هذه الحركة على الرصيد.';

  @override
  String cashWalletBalanceAfterTransaction(Object amount) {
    return 'الرصيد بعد العملية: $amount';
  }

  @override
  String cashWalletLastCashAdded(Object amount) {
    return 'آخر إضافة كاش: +$amount';
  }

  @override
  String cashWalletLastAtmWithdrawal(Object amount) {
    return 'آخر سحب ATM: +$amount';
  }

  @override
  String get cashBalanceInsufficientWarning => 'رصيد الكاش غير كافٍ';

  @override
  String get cashBalanceNoRecordedWarning => 'لا يوجد رصيد كاش مسجل لهذه الرحلة';

  @override
  String get cashBalanceAddCashAction => 'إضافة كاش';

  @override
  String get manualExchangeAddRate => 'إضافة سعر صرف';

  @override
  String get manualExchangeFromCurrency => 'من عملة';

  @override
  String get manualExchangeToCurrency => 'إلى عملة';

  @override
  String get manualExchangeRate => 'سعر الصرف';

  @override
  String get manualExchangeSourceNote => 'ملاحظة المصدر';

  @override
  String get manualExchangeSaved => 'تم حفظ سعر الصرف';

  @override
  String get tripExchangeRatesTitle => 'أسعار التحويل';

  @override
  String get tripExchangeRatesSubtitle => 'إدارة أسعار التحويل اليدوية لهذه الرحلة';

  @override
  String get tripExchangeRatesAddRate => 'إضافة سعر';

  @override
  String get tripExchangeRatesEditRate => 'تعديل السعر';

  @override
  String get tripExchangeRatesFromCurrency => 'من عملة';

  @override
  String get tripExchangeRatesToCurrency => 'إلى عملة';

  @override
  String get tripExchangeRatesRate => 'السعر';

  @override
  String get tripExchangeRatesSourceNote => 'ملاحظة المصدر';

  @override
  String get tripExchangeRatesSourceHint => 'لوحة الصراف، تطبيق البنك، مكتب صرافة...';

  @override
  String get tripExchangeRatesSaved => 'تم حفظ سعر التحويل';

  @override
  String get tripExchangeRatesUpdated => 'تم تحديث سعر التحويل';

  @override
  String get tripExchangeRatesEmptyTitle => 'لا توجد أسعار تحويل بعد';

  @override
  String get tripExchangeRatesEmptyBody => 'أضف أسعارك اليدوية هنا. تُستخدم لتقدير قيمة المصروف بعملة الوطن بدون منع حفظ المصروف.';

  @override
  String get tripExchangeRatesRateLabel => 'السعر';

  @override
  String tripExchangeRatesRatePreview(Object fromCurrency, Object rate, Object toCurrency) {
    return '1 $fromCurrency = $rate $toCurrency';
  }

  @override
  String get tripExchangeRatesValidationCurrency => 'استخدم رمز عملة صحيح من 3 أحرف.';

  @override
  String get tripExchangeRatesValidationRate => 'أدخل سعر تحويل صحيح أكبر من صفر.';

  @override
  String get tripExchangeRatesLoadError => 'تعذر تحميل أسعار التحويل.';

  @override
  String tripExchangeRatesMissingRateWarning(Object fromCurrency, Object toCurrency) {
    return 'تم حفظ المصروف. لا يوجد سعر تحويل يدوي لـ $fromCurrency -> $toCurrency.';
  }

  @override
  String get tripDetailsSearchLabel => 'البحث في المصاريف';

  @override
  String get tripDetailsSearchHint => 'ابحث بالعنوان أو الوصف أو اسم التاجر';

  @override
  String get tripDetailsFilterCategory => 'تصفية حسب الفئة';

  @override
  String get tripDetailsFilterPaymentMethod => 'تصفية حسب طريقة الدفع';

  @override
  String get tripDetailsSortBy => 'الترتيب حسب';

  @override
  String get tripDetailsAllCategories => 'كل الفئات';

  @override
  String get tripDetailsAllPaymentMethods => 'كل طرق الدفع';

  @override
  String get tripDetailsSortNewest => 'الأحدث أولاً';

  @override
  String get tripDetailsSortOldest => 'الأقدم أولاً';

  @override
  String get tripDetailsSortHighestAmount => 'الأعلى مبلغاً';

  @override
  String get tripDetailsSortLowestAmount => 'الأقل مبلغاً';

  @override
  String get tripDetailsNoMatchingExpenses => 'لا توجد مصاريف تطابق البحث والتصفيات الحالية.';

  @override
  String get tripDetailsClearFilters => 'مسح التصفيات';

  @override
  String get tripDetailsFiltersAndSort => 'التصفية والترتيب';

  @override
  String get tripDetailsApplyFilters => 'تطبيق';

  @override
  String tripDetailsBaseCurrency(Object currency) {
    return 'العملة الأساسية: $currency';
  }

  @override
  String tripDetailsBudget(Object amount) {
    return 'الميزانية: $amount';
  }

  @override
  String get tripDetailsDeleteExpenseTitle => 'حذف المصروف؟';

  @override
  String tripDetailsDeleteExpenseMessage(Object expenseTitle) {
    return 'سيؤدي هذا إلى حذف $expenseTitle من هذه الرحلة.';
  }

  @override
  String tripDetailsDeleteExpenseError(Object error) {
    return 'فشل حذف المصروف: $error';
  }

  @override
  String get tripDetailsExcludedCurrenciesWarning => 'بعض المصاريف بعملات أخرى غير مشمولة في الإجمالي';

  @override
  String get tripDetailsNoExpensesInBaseCurrency => 'لا توجد مصاريف بهذه العملة';

  @override
  String get tripDetailsEmptyExpensesTitle => 'لا توجد مصاريف لهذه الرحلة';

  @override
  String get tripDetailsEmptyExpensesMessage => 'أضف أول مصروف لهذه الرحلة';

  @override
  String get noExpensesHeadline => 'أضف أول مصروف الآن';

  @override
  String get noExpensesSubtitle => 'أضف مصروفك الأول خلال ثواني';

  @override
  String get noExpensesAddFirst => 'أضف أول مصروف';

  @override
  String get noExpensesCashWallet => 'إدارة الكاش';

  @override
  String get noExpensesCashWalletSubtitle => 'أضف الكاش الذي معك لتعرف كم تبقّى';

  @override
  String get noExpensesAddViaSms => 'إضافة من رسالة البنك';

  @override
  String get noExpensesTipLabel => 'نصيحة';

  @override
  String get noExpensesTipBody => 'بمجرد إضافة أول مصروف، ستفهم أين تذهب أموالك';

  @override
  String get tripDetailsQuickAddExpenseAdded => 'تم إضافة المصروف';

  @override
  String get tripDetailsQuickAddRecentMerchants => 'المحلات الأخيرة';

  @override
  String get tripDetailsQuickAddMoreDetails => 'تفاصيل إضافية';

  @override
  String get tripDetailsQuickAddSave => 'حفظ';

  @override
  String get tripDetailsQuickAddPaymentCash => 'نقدي';

  @override
  String get tripDetailsQuickAddPaymentWallet => 'محفظة';

  @override
  String get tripDetailsQuickAddPaymentCard => 'بطاقة';

  @override
  String get cardBankSNB => 'بنك الأهلي';

  @override
  String get cardBankAlRajhi => 'مصرف الراجحي';

  @override
  String get cardBankSAB => 'البنك السعودي للاستثمار';

  @override
  String get cardBankD360 => 'D360';

  @override
  String get cardBankBarq => 'برق';

  @override
  String get cardBankOther => 'أخرى';

  @override
  String get cardNetworkVisa => 'فيزا';

  @override
  String get cardNetworkMastercard => 'ماستركارد';

  @override
  String get cardNetworkMada => 'مدى';

  @override
  String get cardNetworkOther => 'أخرى';

  @override
  String get cardTierInfinite => 'إنفينيت';

  @override
  String get cardTierSignature => 'سيجنتشر';

  @override
  String get cardTierPlatinum => 'بلاتينيوم';

  @override
  String get cardTierClassic => 'كلاسيك';

  @override
  String get cardTierWorld => 'وورلد';

  @override
  String get cardTierWorldElite => 'وورلد إليت';

  @override
  String get cardTierOther => 'أخرى';

  @override
  String get cardFormEditTitle => 'تعديل البطاقة';

  @override
  String get cardFormAddTitle => 'إضافة بطاقة';

  @override
  String get cardFormBankLabel => 'البنك';

  @override
  String get cardFormCardNetworkLabel => 'شبكة البطاقة';

  @override
  String get cardFormCardTierLabel => 'فئة البطاقة';

  @override
  String get cardFormLast4Label => 'آخر 4 أرقام';

  @override
  String get cardFormLast4Hint => '1234';

  @override
  String get cardFormCardPreviewLabel => 'معاينة البطاقة';

  @override
  String get cardFormSaveEdit => 'حفظ التغييرات';

  @override
  String get cardFormSaveCreate => 'إضافة بطاقة';

  @override
  String get cardFormDuplicate => 'توجد بطاقة بهذه التفاصيل بالفعل.';

  @override
  String get expenseFormCreateTitle => 'مصروف جديد';

  @override
  String get expenseFormEditTitle => 'تعديل المصروف';

  @override
  String get expenseFormTitleLabel => 'العنوان';

  @override
  String get expenseFormTitleHint => 'تاكسي المطار';

  @override
  String get expenseFormTitleHelper => 'اختياري. إذا تُرك فارغاً فسيتم استخدام الفئة.';

  @override
  String get expenseFormAmountLabel => 'المبلغ';

  @override
  String get expenseFormAmountHint => '45.00';

  @override
  String get expenseFormCurrencyLabel => 'العملة';

  @override
  String get expenseFormCategoryLabel => 'الفئة';

  @override
  String get expenseFormPaymentMethodLabel => 'طريقة الدفع';

  @override
  String get expenseFormPaymentNetworkLabel => 'شبكة البطاقة';

  @override
  String get expenseFormPaymentChannelLabel => 'قناة الدفع';

  @override
  String get expenseFormDateLabel => 'تاريخ المصروف';

  @override
  String get expenseFormTimeLabel => 'وقت المصروف';

  @override
  String get expenseFormNoteLabel => 'ملاحظة';

  @override
  String get expenseFormNoteHint => 'تفاصيل اختيارية';

  @override
  String get expenseFormSaveCreate => 'إنشاء المصروف';

  @override
  String get expenseFormSaveEdit => 'حفظ التغييرات';

  @override
  String get expenseFormAmountPositive => 'يجب أن يكون المبلغ أكبر من صفر.';

  @override
  String get expenseCurrencyMismatchTitle => 'عملة المصروف تختلف عن العملة الأساسية للرحلة';

  @override
  String expenseCurrencyMismatchMessage(Object expenseCurrency, Object tripCurrency) {
    return 'هذا المصروف بعملة $expenseCurrency بينما العملة الأساسية للرحلة هي $tripCurrency. يمكنك التعديل يدوياً، أو الإبقاء عليه كما هو وسيتم استبعاده من الإجماليات.';
  }

  @override
  String get expenseCurrencyMismatchConvertManually => 'التعديل يدوياً';

  @override
  String get expenseCurrencyMismatchKeepAsIs => 'الإبقاء كما هو';

  @override
  String expenseFormSaveError(Object error) {
    return 'فشل حفظ المصروف: $error';
  }

  @override
  String get expenseCategoryTransport => 'مواصلات';

  @override
  String get expenseCategoryAccommodation => 'إقامة';

  @override
  String get expenseCategoryFood => 'طعام';

  @override
  String get expenseCategoryVisa => 'تأشيرة';

  @override
  String get expenseCategoryShopping => 'تسوق';

  @override
  String get expenseCategoryEntertainment => 'ترفيه';

  @override
  String get expenseCategoryOther => 'أخرى';

  @override
  String get paymentMethodCash => 'نقداً';

  @override
  String get paymentMethodCreditCard => 'بطاقة ائتمان';

  @override
  String get paymentMethodDebitCard => 'بطاقة خصم';

  @override
  String get paymentMethodBankTransfer => 'تحويل بنكي';

  @override
  String get paymentMethodMobileWallet => 'محفظة إلكترونية';

  @override
  String get paymentMethodOther => 'أخرى';

  @override
  String get paymentNetworkVisa => 'فيزا';

  @override
  String get paymentNetworkMastercard => 'ماستركارد';

  @override
  String get paymentNetworkMada => 'مدى';

  @override
  String get paymentNetworkOther => 'أخرى';

  @override
  String get paymentChannelApplePay => 'أبل باي';

  @override
  String get paymentChannelGooglePay => 'جوجل باي';

  @override
  String get paymentChannelCardPresent => 'شراء عبر نقاط البيع';

  @override
  String get paymentChannelOnline => 'شراء عبر الإنترنت';

  @override
  String get paymentChannelOther => 'أخرى';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get financialSettingsTitle => 'الإعدادات المالية';

  @override
  String get financialSettingsCardSubtitle => 'بلد الإقامة والعملة الرئيسية';

  @override
  String get financialSettingsHomeCountry => 'بلد الإقامة';

  @override
  String get financialSettingsHomeCurrency => 'العملة الرئيسية';

  @override
  String get financialSettingsStabilityHint => 'تغيير العملة الرئيسية الآن لن يغيّر لقطات العملات للرحلات السابقة.';

  @override
  String get financialSettingsChangeCountry => 'تغيير بلد الإقامة';

  @override
  String get financialProfileMissing => 'الملف المالي غير موجود.';

  @override
  String get financialOnboardingQuestion => 'أين تقيم؟';

  @override
  String get financialOnboardingSubtitle => 'اختر بلد إقامتك ليتم ضبط عملتك الرئيسية تلقائيًا.';

  @override
  String get financialCountrySearchHint => 'ابحث عن بلد';

  @override
  String get financialOnboardingContinue => 'متابعة';

  @override
  String get financialProfileSaveError => 'تعذر حفظ الملف المالي.';

  @override
  String get settingsLanguageAction => 'اللغة';

  @override
  String get settingsLanguageTooltip => 'فتح الإعدادات';

  @override
  String get languageSectionTitle => 'لغة التطبيق';

  @override
  String get languageSectionDescription => 'اختر اللغة المستخدمة في التطبيق.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String settingsLanguageSaveError(Object error) {
    return 'فشل حفظ اللغة: $error';
  }

  @override
  String get smsScreenTitle => 'إضافة عبر رسالة البنك';

  @override
  String get smsInputLabel => 'نص رسالة البنك';

  @override
  String get smsInputHint => 'الصق رسالة البنك كاملة هنا.';

  @override
  String get smsParseButton => 'تحليل الرسالة';

  @override
  String get smsParseDetectedMessage => 'تم تعبئة الحقول المكتشفة أدناه. يمكنك تعديلها قبل الحفظ.';

  @override
  String get smsParseNoResultMessage => 'لم يتم العثور على بيانات موثوقة. يرجى إكمال الحقول يدوياً.';

  @override
  String get smsTitleLabel => 'التاجر أو الوصف';

  @override
  String get smsTitleHint => 'اسم المتجر أو وصف مختصر';

  @override
  String get smsTitleHelper => 'اختياري. إذا تُرك فارغاً فسيتم استخدام الفئة كعنوان.';

  @override
  String smsCurrencyFallbackHelper(Object currency) {
    return 'العملة الافتراضية هي العملة الأساسية للرحلة: $currency';
  }

  @override
  String get smsSaveButton => 'حفظ المصروف';

  @override
  String get smsTextRequired => 'يرجى لصق نص الرسالة أولاً.';

  @override
  String get smsTripMissingError => 'بيانات الرحلة غير متوفرة. أعد فتح هذه الشاشة.';

  @override
  String smsSaveError(Object error) {
    return 'فشل حفظ مصروف الرسالة: $error';
  }

  @override
  String get intlBreakdownTitle => 'تفاصيل الدفع الدولي';

  @override
  String get intlBilled => 'المبلغ المخصوم';

  @override
  String get intlFees => 'الرسوم';

  @override
  String get intlTotalCharged => 'إجمالي الخصم';

  @override
  String get tripDetailsActuallyCharged => 'إجمالي المخصوم';

  @override
  String get tripDetailsReportTooltip => 'تقرير الرحلة';

  @override
  String get tripReportsSummarySubtitle => 'ملخص التقرير';

  @override
  String tripReportsLoadError(Object error) {
    return 'تعذر تحميل التقرير: $error';
  }

  @override
  String get tripReportsTotalBilled => 'إجمالي المبلغ المخصوم';

  @override
  String get tripReportsTotalFees => 'إجمالي رسوم العمليات الدولية';

  @override
  String get tripReportsByCategory => 'حسب الفئة';

  @override
  String get tripReportsByTransactionCurrency => 'حسب عملة العملية';

  @override
  String get tripReportsByPaymentNetwork => 'حسب شبكة البطاقة';

  @override
  String get tripReportsByPaymentChannel => 'حسب قناة الدفع';

  @override
  String get tripReportsOverview => 'نظرة عامة';

  @override
  String get tripReportsTotalExpenses => 'إجمالي المصاريف';

  @override
  String get tripReportsDomestic => 'محلي';

  @override
  String get tripReportsInternational => 'دولي';

  @override
  String get tripReportsTopCategory => 'أعلى فئة';

  @override
  String get tripPredictionSectionTitle => 'التوقعات';

  @override
  String get tripPredictionBurnRateTitle => 'معدل الحرق الحالي';

  @override
  String get tripPredictionForecastTitle => 'التوقع الإجمالي حتى نهاية الرحلة';

  @override
  String tripReportsExpenseCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مصروف',
      many: '$count مصروفًا',
      few: '$count مصاريف',
      two: 'مصروفان',
      one: 'مصروف واحد',
      zero: '0 مصروف',
    );
    return '$_temp0';
  }

  @override
  String get tripReportsSmartSummary => 'ملخص ذكي';

  @override
  String get tripReportsTopSpending => 'الأعلى إنفاقًا';

  @override
  String tripReportsInsightDominantCurrency(Object currency, int percentage) {
    return 'معظم إنفاقك كان بعملة $currency ($percentage%)';
  }

  @override
  String tripReportsInsightTopCategory(Object category) {
    return 'أعلى فئة: $category';
  }

  @override
  String tripReportsInsightDominantPaymentChannel(Object channel, int percentage) {
    return 'معظم الإنفاق تم عبر $channel ($percentage%)';
  }

  @override
  String tripReportsInsightInternationalShare(int percentage) {
    return 'الإنفاق الدولي شكّل $percentage% من مصاريفك';
  }

  @override
  String tripReportsInsightDomesticShare(int percentage) {
    return 'الإنفاق المحلي شكّل $percentage% من مصاريفك';
  }

  @override
  String get tripReportsInsightNoInternationalFees => 'لم يتم فرض أي رسوم على عملياتك الدولية';

  @override
  String tripReportsInsightMultipleCurrencies(int count) {
    return 'تتعامل مع $count عملات مختلفة خلال هذه الرحلة';
  }

  @override
  String tripReportsInsightFeesPercentage(int percentage) {
    return 'الرسوم تمثّل $percentage% من إجمالي إنفاقك';
  }

  @override
  String get tripReportsInsightInternationalDominant => 'أغلب إنفاقك كان دوليًا';

  @override
  String get globalReportsTitle => 'التقرير الشامل';

  @override
  String get globalReportsSubtitle => 'عبر جميع الرحلات';

  @override
  String get globalReportsTooltip => 'التقرير الشامل';

  @override
  String globalReportsLoadError(Object error) {
    return 'تعذر تحميل التقرير الشامل: $error';
  }

  @override
  String get globalReportsEmptyTitle => 'لا توجد رحلات للتحليل';

  @override
  String get globalReportsEmptyMessage => 'أنشئ رحلة أولاً لعرض الرؤية المالية الشاملة.';

  @override
  String get globalReportsZeroTripsTitle => 'لا توجد رحلات بعد';

  @override
  String get globalReportsZeroTripsSubtitle => 'أضف أول رحلة لتبدأ في تتبع مصاريفك ورؤية التقارير الشاملة';

  @override
  String get globalReportsSingleTripNote => 'أضف رحلات أكثر للحصول على مقارنات أذكى بين رحلاتك';

  @override
  String get globalReportsSmartSummary => 'ملخص ذكي';

  @override
  String get globalReportsOverview => 'نظرة عامة';

  @override
  String get globalReportsTotalTrips => 'إجمالي الرحلات';

  @override
  String get globalReportsActiveTrips => 'رحلات بها مصاريف';

  @override
  String get globalReportsTotalExpenses => 'إجمالي المصاريف';

  @override
  String get globalReportsTotalFees => 'إجمالي رسوم العمليات الدولية';

  @override
  String get globalReportsTrackedDays => 'عدد أيام الرحلات المحتسبة';

  @override
  String get globalReportsTotalBilled => 'إجمالي المبلغ المخصوم';

  @override
  String get globalReportsAveragePerTrip => 'متوسط الصرف لكل رحلة';

  @override
  String get globalReportsAveragePerDay => 'متوسط الصرف اليومي';

  @override
  String get globalReportsTopCategory => 'أعلى فئة';

  @override
  String get globalReportsMostUsedPaymentChannel => 'قناة الدفع الأكثر استخدامًا';

  @override
  String get globalReportsMostUsedPaymentNetwork => 'شبكة البطاقة الأكثر استخدامًا';

  @override
  String get globalReportsDominantCurrency => 'العملة الأبرز';

  @override
  String get globalReportsInternationalRatio => 'النسبة الدولية';

  @override
  String get globalReportsDomesticRatio => 'النسبة المحلية';

  @override
  String globalReportsInsightDominantPaymentChannel(Object channel) {
    return 'أغلب مصاريفك كانت عبر $channel';
  }

  @override
  String globalReportsInsightDominantCategory(Object category) {
    return 'أكثر فئة إنفاقًا: $category';
  }

  @override
  String globalReportsInsightAverageSpendPerTrip(Object amount) {
    return 'متوسط صرفك لكل رحلة: $amount';
  }

  @override
  String globalReportsInsightDominantCurrency(Object currency) {
    return 'إنفاقك يتركز على عملة $currency';
  }

  @override
  String get globalReportsInsightCurrencyDistribution => 'أنفقت بعملات متعددة خلال رحلاتك';

  @override
  String get globalReportsInsightCategoryVariation => 'وتوزع إنفاقك بين أكثر من فئة';

  @override
  String get globalReportsInsightPaymentVariation => 'نمط الدفع لديك متنوع عبر أكثر من قناة أو شبكة';

  @override
  String get globalReportsBehavioralInsightsTitle => 'إشارات ذكية';

  @override
  String get globalReportsBehavioralInsightTitleSpike => 'ارتفاع الإنفاق';

  @override
  String get globalReportsBehavioralInsightTitleCategoryDrift => 'تركيز الفئة';

  @override
  String get globalReportsBehavioralInsightTitleFees => 'تنبيه الرسوم';

  @override
  String globalReportsBehavioralInsightSpike(int percentage) {
    return 'إنفاقك في النصف الثاني من الرحلة أعلى بنسبة $percentage% مقارنة بالنصف الأول.';
  }

  @override
  String get globalReportsBehavioralInsightSpikeAbove300 => 'إنفاقك في النصف الثاني أعلى بأكثر من 3 أضعاف مقارنة بالنصف الأول.';

  @override
  String get globalReportsBehavioralInsightSpikeLarge => 'إنفاقك في النصف الثاني أعلى بشكل كبير مقارنة بالنصف الأول.';

  @override
  String get globalReportsBehavioralInsightSpikeNoticeable => 'إنفاقك في النصف الثاني أعلى بشكل ملحوظ مقارنة بالنصف الأول.';

  @override
  String globalReportsBehavioralInsightCategoryDrift(int percentage, Object category) {
    return 'أكثر من $percentage% من إنفاقك كان على فئة $category.';
  }

  @override
  String globalReportsBehavioralInsightFees(int percentage) {
    return 'الرسوم تستهلك حوالي $percentage% من إنفاقك. جرّب وسيلة دفع برسوم أقل.';
  }

  @override
  String get globalReportsBehavioralInsightAttributionIn => '📍 في:';

  @override
  String get globalReportsBehavioralInsightAttributionTop => '📊 الأعلى تأثيرًا:';

  @override
  String globalReportsInsightIntlDomesticRatio(int international, int domestic) {
    return 'الدولي $international% مقابل المحلي $domestic%';
  }

  @override
  String get createTripHeading => 'إلى أين تسافر؟';

  @override
  String get createTripSubheading => 'اختر وجهتك وسنجهز العملة تلقائيًا';

  @override
  String get tripFormDestinationSearchLabel => 'ابحث عن دولة';

  @override
  String get tripFormDestinationRequired => 'اختر وجهة للمتابعة';

  @override
  String get tripFormCustomTripNameLabel => 'اسم الرحلة (اختياري)';

  @override
  String get tripFormCustomTripNameHint => 'مثلاً: رحلة الصيف';

  @override
  String tripFormCurrencyAutoSelected(Object currency) {
    return 'تم تعيين العملة إلى $currency';
  }

  @override
  String get tripFormAutoGeneratedTitle => 'تم إنشاؤه تلقائياً';

  @override
  String get tripFormEditCustomTitle => 'أعط رحلتك اسماً مخصصاً';

  @override
  String tripFormCreateWithoutCustomTitle(Object tripTitle) {
    return 'سننشئ \"$tripTitle\" كاسم رحلتك';
  }

  @override
  String get tripFormCustomDestinationFallback => 'لم تجد وجهتك؟ أضف وجهة مخصصة';
}
