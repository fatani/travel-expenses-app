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
  String get tripFormSaveEdit => 'Save Changes';

  @override
  String get tripFormBudgetNonNegative => 'Budget must be zero or more.';

  @override
  String get tripFormStartDateBeforeEnd => 'Start date must be on or before the end date.';

  @override
  String get tripFormEndDateAfterStart => 'End date must be on or after the start date.';

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
  String get expenseFormPaymentChannelLabel => 'Payment channel';

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
  String get tripReportsTotalFees => 'Total fees';

  @override
  String get tripReportsByCategory => 'By category';

  @override
  String get tripReportsByTransactionCurrency => 'By transaction currency';

  @override
  String get tripReportsByPaymentNetwork => 'By payment network';

  @override
  String get tripReportsByPaymentChannel => 'By payment channel';

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
  String get globalReportsSmartSummary => 'Smart summary';

  @override
  String get globalReportsOverview => 'Overview';

  @override
  String get globalReportsTotalTrips => 'Total trips';

  @override
  String get globalReportsTotalExpenses => 'Total expenses';

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
  String globalReportsInsightDominantCurrency(Object currency, int percentage) {
    return 'Most of your billed spending is in $currency ($percentage%)';
  }
}
