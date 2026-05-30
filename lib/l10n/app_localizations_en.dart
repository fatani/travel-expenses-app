// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CalmLedger';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRequiredField => 'Required.';

  @override
  String get commonEnterValidNumber => 'Enter a valid number.';

  @override
  String get cashWalletValidationInvalidAmount => 'Enter a valid cash amount.';

  @override
  String get cashWalletValidationInvalidCurrency => 'Enter a valid 3-letter currency code.';

  @override
  String get cashWalletValidationNegativeAmount => 'Amount cannot be negative.';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonApprox => 'Approx.';

  @override
  String get tripDetailsExportTooltip => 'Export';

  @override
  String get tripDetailsChangesSaved => 'Saved';

  @override
  String get tripDetailsExpenseDeleted => 'Expense deleted';

  @override
  String get tripDetailsSetStartEndDates => 'Set start and end dates';

  @override
  String get tripTimelineDatesPending => 'Dates pending';

  @override
  String get tripTimelineNoDates => 'No dates';

  @override
  String get tripTimelineUpcoming => 'Upcoming';

  @override
  String get tripTimelineActive => 'Active';

  @override
  String get tripTimelineTraveling => 'Traveling';

  @override
  String get tripTimelineCompleted => 'Completed';

  @override
  String get exportMenuTooltip => 'Export';

  @override
  String get exportMenuCsv => 'Export CSV';

  @override
  String get exportMenuPdf => 'Export PDF';

  @override
  String get exportNoExpenses => 'No expenses to export.';

  @override
  String get exportSuccess => 'Exported';

  @override
  String exportFailed(Object format) {
    return 'Couldn\'t export $format. Try again.';
  }

  @override
  String get settingsToggleLanguageTooltip => 'Toggle language';

  @override
  String get tripsMyTitle => 'My Trips';

  @override
  String get tripsDeleteTripToBeDeleted => 'Trip to be deleted';

  @override
  String get tripsDeleteTripAction => 'Delete trip';

  @override
  String get tripsDatesNotSet => 'Dates incomplete';

  @override
  String get tripsNewTrip => 'New Trip';

  @override
  String get tripsTitle => 'Trips';

  @override
  String get tripsLoadError => 'Couldn\'t load trips.';

  @override
  String get tripsAddButton => 'Add trip';

  @override
  String get tripsEditTooltip => 'Edit trip';

  @override
  String get tripsDeleteTooltip => 'Delete trip';

  @override
  String get tripsDeleteDialogTitle => 'Delete trip?';

  @override
  String tripsDeleteDialogMessage(Object tripName) {
    return 'This removes $tripName and its expenses.';
  }

  @override
  String get tripsDeleteError => 'Couldn\'t delete this trip. Try again.';

  @override
  String get tripsEmptyTitle => 'Track spending while you travel';

  @override
  String get tripsEmptyMessage => 'Create a trip to track cash, cards, and expenses along the way.';

  @override
  String get tripsDatesNeedAttention => 'Dates incomplete';

  @override
  String tripsBudgetLabel(Object amount) {
    return 'Budget: $amount';
  }

  @override
  String get tripFormCreateTitle => 'New Trip';

  @override
  String get tripFormEditTitle => 'Edit trip';

  @override
  String get tripFormNameLabel => 'Trip name';

  @override
  String get tripFormNameHint => 'Summer Conference';

  @override
  String get tripFormDestinationLabel => 'Destination';

  @override
  String get tripFormDestinationHint => 'Istanbul, Turkey';

  @override
  String get tripFormCurrencyLabel => 'Base currency';

  @override
  String get tripFormCurrencyLockedHint => 'Trip currency is locked after expenses, cash, or exchange records are added to keep reports consistent.';

  @override
  String get tripFormCurrencyChangeWarning => 'Changing trip currency may affect expense consistency.';

  @override
  String get tripFormBudgetLabel => 'Budget (optional)';

  @override
  String get tripFormBudgetHint => '2500';

  @override
  String get tripFormNotesLabel => 'Notes';

  @override
  String get tripFormNotesHint => 'Add an optional note';

  @override
  String get tripFormStartDateLabel => 'Start date';

  @override
  String get tripFormEndDateLabel => 'End date';

  @override
  String get tripFormSaveCreate => 'Create trip';

  @override
  String get tripFormSaveEdit => 'Save changes';

  @override
  String get tripFormBudgetNonNegative => 'Budget must be zero or more.';

  @override
  String get tripFormStartDateBeforeEnd => 'Start date must be on or before the end date.';

  @override
  String get tripFormEndDateAfterStart => 'End date must be on or after the start date.';

  @override
  String get tripFormSaveDetails => 'Save details';

  @override
  String get tripFormOverlapTitle => 'Date overlap detected';

  @override
  String get tripFormOverlapIntro => 'There is an overlap with another trip:';

  @override
  String get tripFormOverlapHint => 'You can continue if this is a sub-trip or transit.';

  @override
  String get tripFormOverlapEditDates => 'Edit dates';

  @override
  String get tripFormOverlapContinue => 'Continue';

  @override
  String tripFormOverlapMoreTrips(Object count) {
    return '+ $count more overlapping trip(s)';
  }

  @override
  String tripFormSaveError(Object error) {
    return 'Failed to save trip: $error';
  }

  @override
  String get tripFormSaveFailed => 'Couldn\'t save this trip. Please try again.';

  @override
  String get tripDetailsLoadError => 'Couldn\'t load expenses.';

  @override
  String get tripDetailsExpensesLoadError => 'Couldn\'t load expenses.';

  @override
  String get tripDetailsAddExpense => 'Add Expense';

  @override
  String get tripDetailsEditTripTooltip => 'Edit trip';

  @override
  String get tripDetailsTotalExpenses => 'Total expenses';

  @override
  String get tripDetailsExpenseCount => 'Expenses';

  @override
  String get tripDetailsTopCategory => 'Top category';

  @override
  String get tripDetailsTopCategoryNone => 'No category yet';

  @override
  String get tripDetailsExpensesSection => 'Expenses';

  @override
  String get tripDetailsAddViaSms => 'Add via Bank SMS';

  @override
  String get tripDetailsCashWalletAction => 'Cash Wallet';

  @override
  String tripDetailsCashWalletRemainingCta(Object amount) {
    return '$amount remaining';
  }

  @override
  String get cashWalletHeroTitle => 'Cash remaining';

  @override
  String get cashWalletHeroSubtitle => 'Available cash for this trip';

  @override
  String get cashWalletCurrentBalanceHelper => 'Current available balance after all transactions';

  @override
  String get cashWalletEmptyTitle => 'No cash added yet';

  @override
  String get cashWalletEmptySubtitle => 'Add cash you\'re carrying for this trip.';

  @override
  String get cashWalletHealthTitle => 'Cash status';

  @override
  String get cashWalletHealthNotEnoughData => 'Not enough data yet';

  @override
  String get cashWalletHealthExcellent => 'Plenty left';

  @override
  String get cashWalletHealthHealthy => 'On track';

  @override
  String get cashWalletHealthMedium => 'Medium';

  @override
  String get cashWalletHealthLow => 'Getting low';

  @override
  String get cashWalletHealthCritical => 'Low';

  @override
  String get cashWalletOnboardingTitle => 'How much cash are you carrying?';

  @override
  String get cashWalletOnboardingSkip => 'I\'ll add cash later';

  @override
  String get cashWalletDailyBurnTitle => 'Daily cash burn';

  @override
  String get cashWalletBurnNoData => 'Add cash expenses to estimate your burn rate';

  @override
  String cashWalletRemainingDaysMessage(Object days) {
    return 'Lasts about $days days';
  }

  @override
  String get cashWalletRemainingDaysNoData => 'We\'ll estimate remaining days after your first cash expense';

  @override
  String get cashWalletBalancesTitle => 'By currency';

  @override
  String get cashWalletRecentTransactionsTitle => 'Activity';

  @override
  String get cashWalletNoBalances => 'No cash balances yet.';

  @override
  String get cashWalletNoTransactions => 'No cash transactions yet.';

  @override
  String get cashWalletLoadError => 'Couldn\'t load cash wallet.';

  @override
  String get cashWalletAddCash => 'Add Cash';

  @override
  String get cashWalletEditCash => 'Edit cash entry';

  @override
  String get cashWalletDateLabel => 'Date';

  @override
  String get cashWalletTimeLabel => 'Time';

  @override
  String get cashWalletQuickAtmWithdrawal => 'ATM Withdrawal';

  @override
  String get cashWalletQuickAtmShort => 'ATM';

  @override
  String get quickAddQuickSave => 'Save';

  @override
  String get quickAddAddDetails => 'Add Details';

  @override
  String get quickAddMerchantPlaceholder => 'Merchant';

  @override
  String quickAddAmountInCurrency(Object currency) {
    return '$currency';
  }

  @override
  String cashWalletTripStatusDaysLeft(int days) {
    return '$days days left';
  }

  @override
  String cashWalletTripStatusStartsIn(int days) {
    return 'Starts in $days days';
  }

  @override
  String get cashWalletTripStatusStartsToday => 'Starts today';

  @override
  String get cashWalletTripStatusCompleted => 'Finished';

  @override
  String get cashWalletTripStatusActive => 'Active';

  @override
  String get cashWalletGroupToday => 'Today';

  @override
  String get cashWalletGroupYesterday => 'Yesterday';

  @override
  String get cashWalletGroupEarlier => 'Earlier';

  @override
  String get cashWalletTransactionType => 'Cash source';

  @override
  String get cashWalletTransactionTypeHelper => 'Where did this cash come from?';

  @override
  String get cashWalletTypeInitialCash => 'Initial cash';

  @override
  String get cashWalletTypeAtmWithdrawal => 'ATM withdrawal';

  @override
  String get cashWalletTypeCurrencyExchangeIn => 'Exchange office';

  @override
  String get cashWalletTypeCurrencyExchangeOut => 'Currency exchange out';

  @override
  String get cashWalletTypeManualAdjustment => 'Other cash added';

  @override
  String get cashWalletCashAmountLabel => 'Cash amount';

  @override
  String get cashWalletCashCurrencyLabel => 'Cash currency';

  @override
  String get cashWalletHomeValueLabel => 'Approximate home value (optional)';

  @override
  String get cashWalletHomeValueHelper => 'Optional — helps estimate your home currency spending.';

  @override
  String get cashWalletBalanceUnknownUntilInitial => 'Add your starting cash to begin tracking.';

  @override
  String get cashWalletBalanceUnknownExpensesFirst => 'Some expenses were recorded before adding starting cash — your balance may not reflect them yet.';

  @override
  String get cashWalletSearchHint => 'Search...';

  @override
  String get cashWalletTypeCashExpenseDeduction => 'Cash expense deduction';

  @override
  String get cashWalletTypeCashExpense => 'Cash expense';

  @override
  String get cashWalletEditExpenseAction => 'Edit expense';

  @override
  String get cashWalletDeleteTransactionTitle => 'Delete cash transaction?';

  @override
  String cashWalletDeleteTransactionTitleForType(Object transactionType) {
    return 'Delete $transactionType?';
  }

  @override
  String get cashWalletDeleteTransactionMessage => 'Your cash balance will be updated.';

  @override
  String cashWalletBalanceAfterTransaction(Object amount) {
    return 'Balance after transaction: $amount';
  }

  @override
  String cashWalletLastCashAdded(Object amount) {
    return 'Last cash added: +$amount';
  }

  @override
  String cashWalletLastAtmWithdrawal(Object amount) {
    return 'Last ATM withdrawal: +$amount';
  }

  @override
  String get cashBalanceInsufficientWarning => 'Cash balance may need adjustment';

  @override
  String get cashBalanceNoRecordedWarning => 'No cash added yet';

  @override
  String get cashBalanceAddCashAction => 'Add Cash';

  @override
  String get cashTrackingNotStarted => 'No cash added yet';

  @override
  String get manualExchangeAddRate => 'Add spending estimate';

  @override
  String get manualExchangeFromCurrency => 'Expense currency';

  @override
  String get manualExchangeToCurrency => 'Show spending in';

  @override
  String get manualExchangeRate => 'Estimated value';

  @override
  String get manualExchangeSourceNote => 'Where you saw this rate (optional)';

  @override
  String get manualExchangeSaved => 'Estimate saved.';

  @override
  String get manualExchangeSaveError => 'Couldn\'t save estimate. Try again.';

  @override
  String get tripExchangeRatesTitle => 'Spending Estimates';

  @override
  String get tripExchangeRatesSubtitle => 'This helps estimate your trip spending in your home currency.';

  @override
  String get tripExchangeRatesAddRate => 'Add Estimate';

  @override
  String get tripExchangeRatesEditRate => 'Edit Estimate';

  @override
  String get tripExchangeRatesFromCurrency => 'Expense currency';

  @override
  String get tripExchangeRatesToCurrency => 'Show spending in';

  @override
  String get tripExchangeRatesRate => 'Estimated value';

  @override
  String get tripExchangeRatesSourceNote => 'Where you saw this rate (optional)';

  @override
  String get tripExchangeRatesSourceHint => 'ATM screen, bank app, exchange counter...';

  @override
  String get tripExchangeRatesSaved => 'Estimate saved.';

  @override
  String get tripExchangeRatesUpdated => 'Estimate updated.';

  @override
  String get tripExchangeRatesEmptyTitle => 'Home currency view';

  @override
  String get tripExchangeRatesEmptyBody => 'Add an estimate when you need one. Optional.';

  @override
  String get tripExchangeRatesRateLabel => 'Estimate';

  @override
  String tripExchangeRatesRatePreview(Object fromCurrency, Object rate, Object toCurrency) {
    return 'About 1 $fromCurrency = $rate $toCurrency';
  }

  @override
  String get tripExchangeRatesValidationCurrency => 'Use a valid 3-letter currency code.';

  @override
  String get tripExchangeRatesValidationRate => 'Enter a valid estimate greater than zero.';

  @override
  String get tripExchangeRatesLoadError => 'Couldn\'t load spending estimates.';

  @override
  String get tripExchangeRatesSaveError => 'Couldn\'t save this estimate. Please try again.';

  @override
  String tripExchangeRatesMissingRateWarning(Object fromCurrency, Object toCurrency) {
    return 'Expense saved. Add a quick estimate to see $fromCurrency spending in your home currency ($toCurrency).';
  }

  @override
  String get tripDetailsSearchLabel => 'Search expenses';

  @override
  String get tripDetailsSearchHint => 'Search by title, description, or merchant';

  @override
  String get tripDetailsFilterCategory => 'Filter by category';

  @override
  String get tripDetailsFilterPaymentMethod => 'Filter by payment method';

  @override
  String get tripDetailsSortBy => 'Sort by';

  @override
  String get tripDetailsAllCategories => 'All categories';

  @override
  String get tripDetailsAllPaymentMethods => 'All payment methods';

  @override
  String get tripDetailsSortNewest => 'Newest first';

  @override
  String get tripDetailsSortOldest => 'Oldest first';

  @override
  String get tripDetailsSortHighestAmount => 'Highest amount';

  @override
  String get tripDetailsSortLowestAmount => 'Lowest amount';

  @override
  String get tripDetailsNoMatchingExpenses => 'No expenses match the current search and filters.';

  @override
  String get tripDetailsRepeatLastExpense => 'Repeat last expense';

  @override
  String get tripDetailsRepeatHint => 'Same as last time';

  @override
  String get tripDetailsClearFilters => 'Clear filters';

  @override
  String get tripDetailsFiltersAndSort => 'Filters & Sort';

  @override
  String get tripDetailsApplyFilters => 'Apply';

  @override
  String tripDetailsBaseCurrency(Object currency) {
    return 'Base currency: $currency';
  }

  @override
  String tripDetailsBudget(Object amount) {
    return 'Budget: $amount';
  }

  @override
  String get tripDetailsDeleteExpenseTitle => 'Delete expense?';

  @override
  String tripDetailsDeleteExpenseMessage(Object expenseTitle) {
    return 'This removes $expenseTitle from this trip.';
  }

  @override
  String get tripDetailsDeleteExpenseError => 'Couldn\'t delete this expense. Try again.';

  @override
  String get tripDetailsExcludedCurrenciesWarning => 'Some expenses in other currencies are not included in the totals above';

  @override
  String get tripDetailsNoExpensesInBaseCurrency => 'No expenses in this currency';

  @override
  String get tripDetailsEmptyExpensesTitle => 'No expenses yet';

  @override
  String get tripDetailsEmptyExpensesMessage => 'Record an expense for this trip.';

  @override
  String get noExpensesHeadline => 'No expenses yet';

  @override
  String get noExpensesSubtitle => 'Use the button below to add one.';

  @override
  String get noExpensesAddFirst => 'Add expense';

  @override
  String get noExpensesCashWallet => 'Cash Wallet';

  @override
  String get noExpensesCashWalletSubtitle => 'See how much cash you have left';

  @override
  String get noExpensesAddViaSms => 'Add via Bank SMS';

  @override
  String get noExpensesTipLabel => 'Note';

  @override
  String get noExpensesTipBody => 'Expenses appear here as you add them.';

  @override
  String get tripDetailsQuickAddExpenseAdded => 'Expense added';

  @override
  String get tripDetailsQuickAddRecentMerchants => 'Recent merchants';

  @override
  String get tripDetailsQuickAddMoreDetails => 'More details';

  @override
  String get tripDetailsQuickAddSave => 'Save';

  @override
  String get tripDetailsQuickAddPaymentCash => 'Cash';

  @override
  String get tripDetailsQuickAddPaymentWallet => 'Wallet';

  @override
  String get tripDetailsQuickAddPaymentCard => 'Card';

  @override
  String get cardBankSNB => 'SNB';

  @override
  String get cardBankAlRajhi => 'Al Rajhi';

  @override
  String get cardBankSAB => 'SAB';

  @override
  String get cardBankD360 => 'D360';

  @override
  String get cardBankBarq => 'Barq';

  @override
  String get cardBankOther => 'Other';

  @override
  String get cardNetworkVisa => 'Visa';

  @override
  String get cardNetworkMastercard => 'Mastercard';

  @override
  String get cardNetworkMada => 'Mada';

  @override
  String get cardNetworkOther => 'Other';

  @override
  String get cardTierInfinite => 'Infinite';

  @override
  String get cardTierSignature => 'Signature';

  @override
  String get cardTierPlatinum => 'Platinum';

  @override
  String get cardTierClassic => 'Classic';

  @override
  String get cardTierWorld => 'World';

  @override
  String get cardTierWorldElite => 'World Elite';

  @override
  String get cardTierOther => 'Other';

  @override
  String get cardFormEditTitle => 'Edit Card';

  @override
  String get cardFormAddTitle => 'Add Card';

  @override
  String get cardFormBankLabel => 'Bank';

  @override
  String get cardFormCardNetworkLabel => 'Card network';

  @override
  String get cardFormCardTierLabel => 'Card tier';

  @override
  String get cardFormLast4Label => 'Last 4 digits';

  @override
  String get cardFormLast4Hint => '1234';

  @override
  String get cardFormCardPreviewLabel => 'Card preview';

  @override
  String get cardFormSaveEdit => 'Save changes';

  @override
  String get cardFormSaveCreate => 'Add card';

  @override
  String get cardFormDuplicate => 'A card with these details already exists.';

  @override
  String get expenseFormCreateTitle => 'New Expense';

  @override
  String get expenseFormEditTitle => 'Edit Expense';

  @override
  String get expenseEditTooltip => 'Edit expense';

  @override
  String get expenseFormTitleLabel => 'Title';

  @override
  String get expenseFormTitleHint => 'Airport taxi';

  @override
  String get expenseFormTitleHelper => 'Optional. If empty, category will be used.';

  @override
  String get expenseFormAmountLabel => 'Amount';

  @override
  String get expenseFormAmountHint => '45.00';

  @override
  String get expenseFormCurrencyLabel => 'Currency';

  @override
  String get expenseFormCategoryLabel => 'Category';

  @override
  String get expenseFormPaymentMethodLabel => 'Payment method';

  @override
  String get expenseFormPaymentNetworkLabel => 'Card network';

  @override
  String get expenseFormPaymentChannelLabel => 'How you paid';

  @override
  String expenseFormChargedAmountLabel(Object currencyCode) {
    return 'Charged amount in $currencyCode';
  }

  @override
  String get expenseFormChargedAmountHelper => 'As shown in your bank/card statement';

  @override
  String get expenseFormDateLabel => 'Expense date';

  @override
  String get expenseFormTimeLabel => 'Expense time';

  @override
  String get expenseFormNoteLabel => 'Note';

  @override
  String get expenseFormNoteHint => 'Optional details';

  @override
  String get expenseFormSaveCreate => 'Add expense';

  @override
  String get expenseFormSaveEdit => 'Save changes';

  @override
  String get expenseFormAmountPositive => 'Amount must be greater than zero.';

  @override
  String get expenseCurrencyMismatchTitle => 'Currency differs from trip base currency';

  @override
  String expenseCurrencyMismatchMessage(Object expenseCurrency, Object tripCurrency) {
    return 'This expense uses $expenseCurrency while the trip base currency is $tripCurrency. You can edit it manually, or keep it as-is and it will be excluded from totals.';
  }

  @override
  String get expenseCurrencyMismatchConvertManually => 'Convert manually';

  @override
  String get expenseCurrencyMismatchKeepAsIs => 'Keep as-is';

  @override
  String expenseFormSaveError(Object error) {
    return 'Failed to save expense: $error';
  }

  @override
  String get expenseFormSaveFailed => 'Couldn\'t save this expense. Please try again.';

  @override
  String get expenseConversionContextCash => 'Estimated using trip cash value';

  @override
  String get expenseConversionContextCard => 'Based on card exchange rate';

  @override
  String get expenseConversionContextManual => 'Approximate value';

  @override
  String get expenseCategoryTransport => 'Transport';

  @override
  String get expenseCategoryAccommodation => 'Accommodation';

  @override
  String get expenseCategoryFood => 'Food';

  @override
  String get expenseCategoryVisa => 'Visa';

  @override
  String get expenseCategoryShopping => 'Shopping';

  @override
  String get expenseCategoryEntertainment => 'Entertainment';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCreditCard => 'Credit Card';

  @override
  String get paymentMethodDebitCard => 'Debit Card';

  @override
  String get paymentMethodBankTransfer => 'Bank Transfer';

  @override
  String get paymentMethodMobileWallet => 'Mobile Wallet';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentNetworkVisa => 'Visa';

  @override
  String get paymentNetworkMastercard => 'Mastercard';

  @override
  String get paymentNetworkMada => 'Mada';

  @override
  String get paymentNetworkOther => 'Other';

  @override
  String get paymentChannelApplePay => 'Apple Pay';

  @override
  String get paymentChannelGooglePay => 'Google Pay';

  @override
  String get paymentChannelCardPresent => 'POS Purchase';

  @override
  String get paymentChannelOnline => 'Online Purchase';

  @override
  String get paymentChannelOther => 'Other';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get financialSettingsTitle => 'Financial settings';

  @override
  String get financialSettingsCardSubtitle => 'Home country and home currency';

  @override
  String get financialSettingsHomeCountry => 'Home country';

  @override
  String get financialSettingsHomeCurrency => 'Home currency';

  @override
  String get financialSettingsStabilityHint => 'Changing home currency now will not change historical trip snapshots.';

  @override
  String get financialSettingsChangeCountry => 'Change home country';

  @override
  String get financialProfileMissing => 'Financial profile not found.';

  @override
  String get financialProfileLoadError => 'Couldn\'t load your financial profile.';

  @override
  String get financialOnboardingQuestion => 'Where do you live?';

  @override
  String get financialOnboardingSubtitle => 'Choose your home country so the app can set your home currency.';

  @override
  String get financialCountrySearchHint => 'Search country';

  @override
  String get financialOnboardingContinue => 'Continue';

  @override
  String get financialProfileSaveError => 'Could not save financial profile.';

  @override
  String get settingsLanguageAction => 'Language';

  @override
  String get settingsLanguageTooltip => 'Open settings';

  @override
  String get languageSectionTitle => 'App language';

  @override
  String get languageSectionDescription => 'Choose the language used across the app.';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsLanguageSaveError => 'Couldn\'t save language. Try again.';

  @override
  String get smsScreenTitle => 'Add via Bank SMS';

  @override
  String get smsInputLabel => 'Bank SMS text';

  @override
  String get smsInputHint => 'Paste the full bank SMS message here.';

  @override
  String get smsParseButton => 'Parse SMS';

  @override
  String get smsParseDetectedMessage => 'Detected values were filled below. You can edit them before saving.';

  @override
  String get smsParseNoResultMessage => 'No reliable fields found. Please complete the form manually.';

  @override
  String get smsTitleLabel => 'Merchant or description';

  @override
  String get smsTitleHint => 'Store, merchant, or short description';

  @override
  String get smsTitleHelper => 'Optional. If empty, selected category is used as title.';

  @override
  String smsCurrencyFallbackHelper(Object currency) {
    return 'Currency defaults to trip base currency: $currency';
  }

  @override
  String get smsSaveButton => 'Save expense';

  @override
  String get smsTextRequired => 'Paste the SMS text first.';

  @override
  String get smsTripMissingError => 'Trip is missing. Reopen this screen.';

  @override
  String get smsSaveError => 'Couldn\'t save this expense. Try again.';

  @override
  String get intlBreakdownTitle => 'International breakdown';

  @override
  String get intlBilled => 'Billed';

  @override
  String get intlFees => 'Fees';

  @override
  String get intlTotalCharged => 'Total charged';

  @override
  String get tripDetailsActuallyCharged => 'Total charged (SAR)';

  @override
  String tripDetailsTotalInCurrencyOnly(Object currency) {
    return 'Total in $currency only';
  }

  @override
  String tripDetailsCardChargesInCurrency(Object currency) {
    return 'Card charges in $currency';
  }

  @override
  String get tripDetailsCardChargesMultipleCurrencies => 'Card charges in multiple currencies';

  @override
  String get tripDetailsMixedValue => 'Mixed';

  @override
  String get tripDetailsTopCategoryMultiCurrency => 'Mixed currencies';

  @override
  String get tripDetailsReportTooltip => 'Trip report';

  @override
  String get tripReportsSummarySubtitle => 'Report Summary';

  @override
  String get tripReportsLoadError => 'Couldn\'t load this report.';

  @override
  String get tripReportsTotalBilled => 'Spending by currency';

  @override
  String get tripReportsTotalFees => 'Total international transaction fees';

  @override
  String get tripReportsByCategory => 'By category';

  @override
  String get tripReportsByTransactionCurrency => 'By transaction currency';

  @override
  String get tripReportsByPaymentNetwork => 'By payment network';

  @override
  String get tripReportsByPaymentChannel => 'By payment method';

  @override
  String get tripReportsOverview => 'Overview';

  @override
  String get tripReportsOverallSpending => 'Overall spending';

  @override
  String get tripReportsTotalExpenses => 'Total expenses';

  @override
  String get tripReportsDomestic => 'Domestic';

  @override
  String get tripReportsInternational => 'International';

  @override
  String get tripReportsTopCategory => 'Top category';

  @override
  String get tripPredictionSectionTitle => 'Predictions';

  @override
  String get tripPredictionBurnRateTitle => 'Current burn rate';

  @override
  String get tripPredictionForecastTitle => 'Forecast total until trip end';

  @override
  String tripReportsExpenseCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String get tripReportsSmartSummary => 'Summary';

  @override
  String get tripReportsTopSpending => 'Top spending';

  @override
  String tripReportsInsightDominantCurrency(Object currency, int percentage) {
    return 'Most of your spending was in $currency ($percentage%)';
  }

  @override
  String tripReportsInsightTopCategory(Object category) {
    return 'Top category: $category';
  }

  @override
  String tripReportsInsightDominantPaymentChannel(Object channel, int percentage) {
    return 'Most spending used $channel ($percentage%)';
  }

  @override
  String tripReportsInsightInternationalShare(int percentage) {
    return 'International spending made up $percentage% of your expenses';
  }

  @override
  String tripReportsInsightDomesticShare(int percentage) {
    return 'Domestic spending made up $percentage% of your expenses';
  }

  @override
  String get tripReportsInsightNoInternationalFees => 'No international fees were charged';

  @override
  String tripReportsInsightMultipleCurrencies(int count) {
    return 'You\'re dealing with $count different currencies on this trip';
  }

  @override
  String tripReportsInsightFeesPercentage(int percentage) {
    return 'Fees represent $percentage% of your total spending';
  }

  @override
  String get tripReportsInsightInternationalDominant => 'Most of your spending was international';

  @override
  String get tripReportsEarlyNoExpenses => 'No expenses yet';

  @override
  String get tripReportsEarlyAddFirstHint => 'Add an expense to see a report.';

  @override
  String tripReportsEarlyRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses recorded',
      one: '1 expense recorded',
    );
    return '$_temp0';
  }

  @override
  String get tripReportsEarlyAddMoreHint => 'Add more expenses for a fuller report.';

  @override
  String get globalReportsTitle => 'Global reports';

  @override
  String get globalReportsSubtitle => 'Across all trips';

  @override
  String get globalReportsTooltip => 'Global reports';

  @override
  String get globalReportsLoadError => 'Couldn\'t load the summary report.';

  @override
  String get globalReportsEmptyTitle => 'No trips yet';

  @override
  String get globalReportsEmptyMessage => 'Add a trip to see reports.';

  @override
  String get globalReportsZeroTripsTitle => 'No trips yet';

  @override
  String get globalReportsZeroTripsSubtitle => 'Add a trip to see reports across trips.';

  @override
  String get globalReportsSingleTripNote => 'Add more trips to compare across trips.';

  @override
  String get globalReportsSmartSummary => 'Summary';

  @override
  String get globalReportsOverview => 'Overview';

  @override
  String get globalReportsTotalTrips => 'Total trips';

  @override
  String get globalReportsActiveTrips => 'Trips with expenses';

  @override
  String get globalReportsTotalExpenses => 'Total expenses';

  @override
  String get globalReportsTotalFees => 'Total international transaction fees';

  @override
  String get globalReportsTrackedDays => 'Tracked trip days';

  @override
  String get globalReportsTotalBilled => 'Spending by currency';

  @override
  String get globalReportsAveragePerTrip => 'Average spending per trip';

  @override
  String get globalReportsAveragePerDay => 'Average daily spending';

  @override
  String get globalReportsTopCategory => 'Top category';

  @override
  String get globalReportsMostUsedPaymentChannel => 'Most used payment channel';

  @override
  String get globalReportsMostUsedPaymentNetwork => 'Most used payment network';

  @override
  String get globalReportsDominantCurrency => 'Dominant currency';

  @override
  String get globalReportsInternationalRatio => 'International ratio';

  @override
  String get globalReportsDomesticRatio => 'Domestic ratio';

  @override
  String globalReportsInsightDominantPaymentChannel(Object channel) {
    return 'Most of your expenses were via $channel';
  }

  @override
  String globalReportsInsightDominantCategory(Object category) {
    return 'Top spending category: $category';
  }

  @override
  String globalReportsInsightAverageSpendPerTrip(Object amount) {
    return 'Average spend per trip: $amount';
  }

  @override
  String globalReportsInsightDominantCurrency(Object currency) {
    return 'Your spending is concentrated in $currency';
  }

  @override
  String get globalReportsInsightCurrencyDistribution => 'You spent in multiple currencies across your trips';

  @override
  String get globalReportsInsightCategoryVariation => 'Your spending was spread across more than one category';

  @override
  String get globalReportsInsightPaymentVariation => 'Your payment behavior varies across channels or networks';

  @override
  String get globalReportsBehavioralInsightsTitle => 'Notes';

  @override
  String get globalReportsBehavioralInsightTitleSpike => 'Spending change';

  @override
  String get globalReportsBehavioralInsightTitleCategoryDrift => 'Category focus';

  @override
  String get globalReportsBehavioralInsightTitleFees => 'Fees';

  @override
  String globalReportsBehavioralInsightSpike(int percentage) {
    return 'Your spending in the second half is $percentage% higher than the first half.';
  }

  @override
  String get globalReportsBehavioralInsightSpikeAbove300 => 'Your spending in the second half is more than 3x the first half.';

  @override
  String get globalReportsBehavioralInsightSpikeLarge => 'Your spending in the second half is significantly higher than the first half.';

  @override
  String get globalReportsBehavioralInsightSpikeNoticeable => 'Your spending in the second half is noticeably higher than the first half.';

  @override
  String globalReportsBehavioralInsightCategoryDrift(int percentage, Object category) {
    return 'More than $percentage% of your spending was in $category.';
  }

  @override
  String globalReportsBehavioralInsightFees(int percentage) {
    return 'Fees are about $percentage% of spending.';
  }

  @override
  String get globalReportsBehavioralInsightAttributionIn => '📍 In:';

  @override
  String get globalReportsBehavioralInsightAttributionTop => '📊 Top impact:';

  @override
  String globalReportsInsightIntlDomesticRatio(int international, int domestic) {
    return 'International $international% vs domestic $domestic%';
  }

  @override
  String get createTripHeading => 'Where are you going?';

  @override
  String get createTripSubheading => 'Pick a destination. Currency is set automatically.';

  @override
  String get tripFormDestinationSearchLabel => 'Search for a country';

  @override
  String get tripFormDestinationRequired => 'Select a destination to continue';

  @override
  String get tripFormCustomTripNameLabel => 'Trip name (optional)';

  @override
  String get tripFormCustomTripNameHint => 'e.g., Summer Getaway';

  @override
  String tripFormCurrencyAutoSelected(Object currency) {
    return '$currency will be used as the trip currency';
  }

  @override
  String get tripFormAutoGeneratedTitle => 'Generated automatically';

  @override
  String get tripFormEditCustomTitle => 'Give your trip a custom name';

  @override
  String tripFormCreateWithoutCustomTitle(Object tripTitle) {
    return 'We\'ll create \"$tripTitle\" as your trip name';
  }

  @override
  String get tripFormCustomDestinationFallback => 'Can\'t find your destination? Add custom destination';

  @override
  String get tripSetupTitle => 'Before you go';

  @override
  String get tripSetupSubtitle => 'All optional — add what you know';

  @override
  String get tripSetupDatesTitle => 'Dates';

  @override
  String get tripSetupDatesHint => 'Optional';

  @override
  String get tripSetupCashTitle => 'Cash on hand';

  @override
  String get tripSetupCashHint => 'Optional · leave blank to skip';

  @override
  String get tripSetupCardsTitle => 'Cards';

  @override
  String get tripSetupCardsHint => 'Your saved payment cards';

  @override
  String get tripSetupCardsEmpty => 'None saved yet';

  @override
  String get tripSetupCardsError => 'Couldn\'t load cards';

  @override
  String get tripSetupAddCurrency => 'Add currency';

  @override
  String get tripSetupAddCard => 'Add card';

  @override
  String get tripSetupAmountLabel => 'Amount';

  @override
  String get tripSetupSearchCurrency => 'Search currency';

  @override
  String get tripSetupCreateNow => 'Create trip now';

  @override
  String get tripSetupCreateNowHint => 'Without dates, cash, or new cards';

  @override
  String get tripSetupCashSaveFailed => 'Couldn\'t save cash. Try again.';
}
