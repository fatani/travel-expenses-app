// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Travel Expense Tracker';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRequiredField => 'This field is required.';

  @override
  String get commonEnterValidNumber => 'Enter a valid number.';

  @override
  String get tripsTitle => 'Trips';

  @override
  String get tripsLoadError => 'Could not load trips.';

  @override
  String get tripsAddButton => 'Add Trip';

  @override
  String get tripsEditTooltip => 'Edit trip';

  @override
  String get tripsDeleteTooltip => 'Delete trip';

  @override
  String get tripsDeleteDialogTitle => 'Delete trip?';

  @override
  String tripsDeleteDialogMessage(Object tripName) {
    return 'This will permanently remove $tripName and its linked expenses.';
  }

  @override
  String tripsDeleteError(Object error) {
    return 'Failed to delete trip: $error';
  }

  @override
  String get tripsEmptyTitle => 'No trips yet';

  @override
  String get tripsEmptyMessage => 'Create your first trip to start tracking travel expenses.';

  @override
  String get tripsDatesNeedAttention => 'Dates need attention';

  @override
  String tripsBudgetLabel(Object amount) {
    return 'Budget: $amount';
  }

  @override
  String get tripFormCreateTitle => 'New Trip';

  @override
  String get tripFormEditTitle => 'Edit Trip';

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
  String get tripFormBudgetLabel => 'Budget (optional)';

  @override
  String get tripFormBudgetHint => '2500';

  @override
  String get tripFormStartDateLabel => 'Start date';

  @override
  String get tripFormEndDateLabel => 'End date';

  @override
  String get tripFormSaveCreate => 'Create Trip';

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
  String get tripDetailsLoadError => 'Could not load expenses.';

  @override
  String get tripDetailsAddExpense => 'Add Expense';

  @override
  String get tripDetailsEditTripTooltip => 'Edit trip';

  @override
  String get tripDetailsTotalExpenses => 'Total expenses';

  @override
  String get tripDetailsExpenseCount => 'Expense count';

  @override
  String get tripDetailsTopCategory => 'Top spending category';

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
  String get cashWalletEmptyTitle => 'You haven’t added travel cash yet';

  @override
  String get cashWalletEmptySubtitle => 'Add the cash you carry to track what remains during your trip';

  @override
  String get cashWalletTripDatesPending => 'Dates pending';

  @override
  String get cashWalletHealthTitle => 'Cash health';

  @override
  String get cashWalletHealthNotEnoughData => 'We need cash spending data first';

  @override
  String get cashWalletHealthExcellent => 'Excellent';

  @override
  String get cashWalletHealthHealthy => 'Healthy';

  @override
  String get cashWalletHealthMedium => 'Medium';

  @override
  String get cashWalletHealthLow => 'Low';

  @override
  String get cashWalletHealthCritical => 'Critical';

  @override
  String get cashWalletLastAtmNotAvailable => 'Last ATM: —';

  @override
  String get cashWalletOnboardingTitle => 'How much cash are you carrying?';

  @override
  String get cashWalletOnboardingSkip => 'Skip';

  @override
  String get cashWalletOnboardingCardsOnly => 'I\'ll use cards only';

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
  String get cashWalletBalancesTitle => 'Balances by currency';

  @override
  String get cashWalletRecentTransactionsTitle => 'Recent cash transactions';

  @override
  String get cashWalletNoBalances => 'No cash balances yet.';

  @override
  String get cashWalletNoTransactions => 'No cash transactions yet.';

  @override
  String get cashWalletAddCash => 'Add Cash';

  @override
  String get cashWalletEditCash => 'Edit Cash Movement';

  @override
  String get cashWalletQuickAtmWithdrawal => 'ATM Withdrawal';

  @override
  String get cashWalletQuickAtmShort => 'ATM';

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
  String get cashWalletTransactionType => 'Transaction type';

  @override
  String get cashWalletTransactionTypeHelper => 'Choose the cash action you performed';

  @override
  String get cashWalletTypeInitialCash => 'Trip starting cash';

  @override
  String get cashWalletTypeAtmWithdrawal => 'ATM withdrawal';

  @override
  String get cashWalletTypeCurrencyExchangeIn => 'Currency exchange in';

  @override
  String get cashWalletTypeCurrencyExchangeOut => 'Currency exchange out';

  @override
  String get cashWalletTypeManualAdjustment => 'Balance correction';

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
  String get cashWalletDeleteTransactionMessage => 'This will reverse its effect on the balance.';

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
  String get cashBalanceInsufficientWarning => 'Cash balance is insufficient';

  @override
  String get cashBalanceNoRecordedWarning => 'No cash balance recorded for this trip';

  @override
  String get cashBalanceAddCashAction => 'Add Cash';

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
  String get manualExchangeSaved => 'Estimate saved. We\'ll use it to show spending in your home currency.';

  @override
  String get manualExchangeSaveError => 'Couldn\'t save this estimate. Please try again.';

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
  String get tripExchangeRatesSaved => 'Estimate saved. We\'ll use it for this trip\'s home-currency spending.';

  @override
  String get tripExchangeRatesUpdated => 'Estimate updated. Your home-currency spending view is refreshed.';

  @override
  String get tripExchangeRatesEmptyTitle => 'See your spending in your home currency';

  @override
  String get tripExchangeRatesEmptyBody => 'Add a quick estimate when you need it. It\'s optional and never blocks saving expenses.';

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
    return 'This will remove $expenseTitle from this trip.';
  }

  @override
  String tripDetailsDeleteExpenseError(Object error) {
    return 'Failed to delete expense: $error';
  }

  @override
  String get tripDetailsExcludedCurrenciesWarning => 'Some expenses in other currencies are not included in the total';

  @override
  String get tripDetailsNoExpensesInBaseCurrency => 'No expenses in this currency';

  @override
  String get tripDetailsEmptyExpensesTitle => 'No expenses yet';

  @override
  String get tripDetailsEmptyExpensesMessage => 'Add your first manual expense for this trip.';

  @override
  String get noExpensesHeadline => 'Add your first expense now';

  @override
  String get noExpensesSubtitle => 'Add your first expense in seconds';

  @override
  String get noExpensesAddFirst => 'Add First Expense';

  @override
  String get noExpensesCashWallet => 'Cash Wallet';

  @override
  String get noExpensesCashWalletSubtitle => 'Track how much cash you still have';

  @override
  String get noExpensesAddViaSms => 'Add via Bank SMS';

  @override
  String get noExpensesTipLabel => 'Tip';

  @override
  String get noExpensesTipBody => 'Once you add your first expense, you\'ll understand where your money goes';

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
  String get cardFormSaveEdit => 'Save Changes';

  @override
  String get cardFormSaveCreate => 'Add Card';

  @override
  String get cardFormDuplicate => 'A card with these details already exists.';

  @override
  String get expenseFormCreateTitle => 'New Expense';

  @override
  String get expenseFormEditTitle => 'Edit Expense';

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
  String get expenseFormDateLabel => 'Expense date';

  @override
  String get expenseFormTimeLabel => 'Expense time';

  @override
  String get expenseFormNoteLabel => 'Note';

  @override
  String get expenseFormNoteHint => 'Optional details';

  @override
  String get expenseFormSaveCreate => 'Create Expense';

  @override
  String get expenseFormSaveEdit => 'Save Changes';

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
  String settingsLanguageSaveError(Object error) {
    return 'Failed to save language: $error';
  }

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
  String get smsSaveButton => 'Save Expense';

  @override
  String get smsTextRequired => 'Paste the SMS text first.';

  @override
  String get smsTripMissingError => 'Trip is missing. Reopen this screen.';

  @override
  String smsSaveError(Object error) {
    return 'Failed to save SMS expense: $error';
  }

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
  String get tripDetailsReportTooltip => 'Trip report';

  @override
  String get tripReportsSummarySubtitle => 'Report Summary';

  @override
  String tripReportsLoadError(Object error) {
    return 'Failed to load report: $error';
  }

  @override
  String get tripReportsTotalBilled => 'Total billed';

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
  String get tripReportsSmartSummary => 'Smart summary';

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
  String get tripReportsEarlyNoExpenses => 'No expenses recorded yet.';

  @override
  String get tripReportsEarlyAddFirstHint => 'Add your first expense to start tracking your spending.';

  @override
  String tripReportsEarlyRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You\'ve recorded $count expenses so far.',
      one: 'You\'ve recorded 1 expense so far.',
    );
    return '$_temp0';
  }

  @override
  String get tripReportsEarlyAddMoreHint => 'Add more expenses to see clearer spending patterns.';

  @override
  String get globalReportsTitle => 'Global reports';

  @override
  String get globalReportsSubtitle => 'Across all trips';

  @override
  String get globalReportsTooltip => 'Global reports';

  @override
  String globalReportsLoadError(Object error) {
    return 'Failed to load global report: $error';
  }

  @override
  String get globalReportsEmptyTitle => 'No trips to analyze';

  @override
  String get globalReportsEmptyMessage => 'Create a trip first to unlock global financial insights.';

  @override
  String get globalReportsZeroTripsTitle => 'No trips yet';

  @override
  String get globalReportsZeroTripsSubtitle => 'Add your first trip to start tracking expenses and see global reports.';

  @override
  String get globalReportsSingleTripNote => 'Add more trips to unlock smarter cross-trip comparisons.';

  @override
  String get globalReportsSmartSummary => 'Smart summary';

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
  String get globalReportsTotalBilled => 'Total billed';

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
  String get globalReportsBehavioralInsightsTitle => 'Behavioral insights';

  @override
  String get globalReportsBehavioralInsightTitleSpike => 'Spending Spike';

  @override
  String get globalReportsBehavioralInsightTitleCategoryDrift => 'Category Concentration';

  @override
  String get globalReportsBehavioralInsightTitleFees => 'Fees Alert';

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
    return 'Fees are taking about $percentage% of your spending. Consider a lower-fee payment method.';
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
  String get createTripHeading => 'Where are you traveling?';

  @override
  String get createTripSubheading => 'Choose your destination and we\'ll set the currency automatically';

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
}
