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
  String get tripDetailsAddViaSms => 'إضافة عبر رسالة البنك';

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
  String get tripDetailsExcludedCurrenciesWarning =>
      'بعض المصاريف بعملات أخرى غير مشمولة في الإجمالي';

  @override
  String get tripDetailsEmptyExpensesTitle => 'لا توجد مصاريف بعد';

  @override
  String get tripDetailsEmptyExpensesMessage => 'أضف أول مصروف يدوي لهذه الرحلة.';

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
  String get expenseFormDateLabel => 'تاريخ المصروف';

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
  String get expenseCurrencyMismatchTitle =>
      'عملة المصروف تختلف عن العملة الأساسية للرحلة';

  @override
  String expenseCurrencyMismatchMessage(
    Object expenseCurrency,
    Object tripCurrency,
  ) {
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
  String get settingsTitle => 'الإعدادات';

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
}
