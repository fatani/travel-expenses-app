import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Travel Expense Tracker'**
  String get appName;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRequiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get commonRequiredField;

  /// No description provided for @commonEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get commonEnterValidNumber;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsTitle;

  /// No description provided for @tripsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load trips.'**
  String get tripsLoadError;

  /// No description provided for @tripsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get tripsAddButton;

  /// No description provided for @tripsEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripsEditTooltip;

  /// No description provided for @tripsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete trip'**
  String get tripsDeleteTooltip;

  /// No description provided for @tripsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete trip?'**
  String get tripsDeleteDialogTitle;

  /// No description provided for @tripsDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove {tripName} and its linked expenses.'**
  String tripsDeleteDialogMessage(Object tripName);

  /// No description provided for @tripsDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete trip: {error}'**
  String tripsDeleteError(Object error);

  /// No description provided for @tripsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get tripsEmptyTitle;

  /// No description provided for @tripsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first trip to start tracking travel expenses.'**
  String get tripsEmptyMessage;

  /// No description provided for @tripsDatesNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'Dates need attention'**
  String get tripsDatesNeedAttention;

  /// No description provided for @tripsBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget: {amount}'**
  String tripsBudgetLabel(Object amount);

  /// No description provided for @tripFormCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Trip'**
  String get tripFormCreateTitle;

  /// No description provided for @tripFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get tripFormEditTitle;

  /// No description provided for @tripFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip name'**
  String get tripFormNameLabel;

  /// No description provided for @tripFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'Summer Conference'**
  String get tripFormNameHint;

  /// No description provided for @tripFormDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get tripFormDestinationLabel;

  /// No description provided for @tripFormDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Istanbul, Turkey'**
  String get tripFormDestinationHint;

  /// No description provided for @tripFormCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get tripFormCurrencyLabel;

  /// No description provided for @tripFormBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget (optional)'**
  String get tripFormBudgetLabel;

  /// No description provided for @tripFormBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'2500'**
  String get tripFormBudgetHint;

  /// No description provided for @tripFormStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get tripFormStartDateLabel;

  /// No description provided for @tripFormEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get tripFormEndDateLabel;

  /// No description provided for @tripFormSaveCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Trip'**
  String get tripFormSaveCreate;

  /// No description provided for @tripFormSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get tripFormSaveEdit;

  /// No description provided for @tripFormBudgetNonNegative.
  ///
  /// In en, this message translates to:
  /// **'Budget must be zero or more.'**
  String get tripFormBudgetNonNegative;

  /// No description provided for @tripFormStartDateBeforeEnd.
  ///
  /// In en, this message translates to:
  /// **'Start date must be on or before the end date.'**
  String get tripFormStartDateBeforeEnd;

  /// No description provided for @tripFormEndDateAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date.'**
  String get tripFormEndDateAfterStart;

  /// No description provided for @tripFormSaveDetails.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get tripFormSaveDetails;

  /// No description provided for @tripFormSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save trip: {error}'**
  String tripFormSaveError(Object error);

  /// No description provided for @tripDetailsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses.'**
  String get tripDetailsLoadError;

  /// No description provided for @tripDetailsAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get tripDetailsAddExpense;

  /// No description provided for @tripDetailsEditTripTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripDetailsEditTripTooltip;

  /// No description provided for @tripDetailsTotalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get tripDetailsTotalExpenses;

  /// No description provided for @tripDetailsExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'Expense count'**
  String get tripDetailsExpenseCount;

  /// No description provided for @tripDetailsTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Top spending category'**
  String get tripDetailsTopCategory;

  /// No description provided for @tripDetailsTopCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category yet'**
  String get tripDetailsTopCategoryNone;

  /// No description provided for @tripDetailsExpensesSection.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get tripDetailsExpensesSection;

  /// No description provided for @tripDetailsAddViaSms.
  ///
  /// In en, this message translates to:
  /// **'Add via Bank SMS'**
  String get tripDetailsAddViaSms;

  /// No description provided for @tripDetailsCashWalletAction.
  ///
  /// In en, this message translates to:
  /// **'Cash Wallet'**
  String get tripDetailsCashWalletAction;

  /// No description provided for @tripDetailsCashWalletRemainingCta.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String tripDetailsCashWalletRemainingCta(Object amount);

  /// No description provided for @cashWalletHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash remaining'**
  String get cashWalletHeroTitle;

  /// No description provided for @cashWalletHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Available cash for this trip'**
  String get cashWalletHeroSubtitle;

  /// No description provided for @cashWalletCurrentBalanceHelper.
  ///
  /// In en, this message translates to:
  /// **'Current available balance after all transactions'**
  String get cashWalletCurrentBalanceHelper;

  /// No description provided for @cashWalletEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven’t added travel cash yet'**
  String get cashWalletEmptyTitle;

  /// No description provided for @cashWalletEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add the cash you carry to track what remains during your trip'**
  String get cashWalletEmptySubtitle;

  /// No description provided for @cashWalletTripDatesPending.
  ///
  /// In en, this message translates to:
  /// **'Dates pending'**
  String get cashWalletTripDatesPending;

  /// No description provided for @cashWalletHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash health'**
  String get cashWalletHealthTitle;

  /// No description provided for @cashWalletHealthNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'We need cash spending data first'**
  String get cashWalletHealthNotEnoughData;

  /// No description provided for @cashWalletHealthHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get cashWalletHealthHealthy;

  /// No description provided for @cashWalletHealthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get cashWalletHealthMedium;

  /// No description provided for @cashWalletHealthLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get cashWalletHealthLow;

  /// No description provided for @cashWalletHealthCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get cashWalletHealthCritical;

  /// No description provided for @cashWalletDailyBurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily cash burn'**
  String get cashWalletDailyBurnTitle;

  /// No description provided for @cashWalletBurnNoData.
  ///
  /// In en, this message translates to:
  /// **'Add cash expenses to estimate your burn rate'**
  String get cashWalletBurnNoData;

  /// No description provided for @cashWalletRemainingDaysMessage.
  ///
  /// In en, this message translates to:
  /// **'Lasts about {days} days'**
  String cashWalletRemainingDaysMessage(Object days);

  /// No description provided for @cashWalletRemainingDaysNoData.
  ///
  /// In en, this message translates to:
  /// **'We\'ll estimate remaining days after your first cash expense'**
  String get cashWalletRemainingDaysNoData;

  /// No description provided for @cashWalletBalancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances by currency'**
  String get cashWalletBalancesTitle;

  /// No description provided for @cashWalletRecentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent cash transactions'**
  String get cashWalletRecentTransactionsTitle;

  /// No description provided for @cashWalletNoBalances.
  ///
  /// In en, this message translates to:
  /// **'No cash balances yet.'**
  String get cashWalletNoBalances;

  /// No description provided for @cashWalletNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No cash transactions yet.'**
  String get cashWalletNoTransactions;

  /// No description provided for @cashWalletAddCash.
  ///
  /// In en, this message translates to:
  /// **'Add Cash'**
  String get cashWalletAddCash;

  /// No description provided for @cashWalletQuickAtmWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'ATM Withdrawal'**
  String get cashWalletQuickAtmWithdrawal;

  /// No description provided for @cashWalletQuickAtmShort.
  ///
  /// In en, this message translates to:
  /// **'ATM'**
  String get cashWalletQuickAtmShort;

  /// No description provided for @cashWalletTripStatusDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String cashWalletTripStatusDaysLeft(int days);

  /// No description provided for @cashWalletTripStatusStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {days} days'**
  String cashWalletTripStatusStartsIn(int days);

  /// No description provided for @cashWalletTripStatusStartsToday.
  ///
  /// In en, this message translates to:
  /// **'Starts today'**
  String get cashWalletTripStatusStartsToday;

  /// No description provided for @cashWalletTripStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get cashWalletTripStatusCompleted;

  /// No description provided for @cashWalletTripStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get cashWalletTripStatusActive;

  /// No description provided for @cashWalletGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get cashWalletGroupToday;

  /// No description provided for @cashWalletGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get cashWalletGroupYesterday;

  /// No description provided for @cashWalletGroupEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get cashWalletGroupEarlier;

  /// No description provided for @cashWalletTransactionType.
  ///
  /// In en, this message translates to:
  /// **'Transaction type'**
  String get cashWalletTransactionType;

  /// No description provided for @cashWalletTransactionTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'Choose the cash action you performed'**
  String get cashWalletTransactionTypeHelper;

  /// No description provided for @cashWalletTypeInitialCash.
  ///
  /// In en, this message translates to:
  /// **'Trip starting cash'**
  String get cashWalletTypeInitialCash;

  /// No description provided for @cashWalletTypeAtmWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'ATM withdrawal'**
  String get cashWalletTypeAtmWithdrawal;

  /// No description provided for @cashWalletTypeCurrencyExchangeIn.
  ///
  /// In en, this message translates to:
  /// **'Currency exchange in'**
  String get cashWalletTypeCurrencyExchangeIn;

  /// No description provided for @cashWalletTypeCurrencyExchangeOut.
  ///
  /// In en, this message translates to:
  /// **'Currency exchange out'**
  String get cashWalletTypeCurrencyExchangeOut;

  /// No description provided for @cashWalletTypeManualAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Balance correction'**
  String get cashWalletTypeManualAdjustment;

  /// No description provided for @cashWalletTypeCashExpenseDeduction.
  ///
  /// In en, this message translates to:
  /// **'Cash expense deduction'**
  String get cashWalletTypeCashExpenseDeduction;

  /// No description provided for @cashWalletTypeCashExpense.
  ///
  /// In en, this message translates to:
  /// **'Cash expense'**
  String get cashWalletTypeCashExpense;

  /// No description provided for @cashWalletBalanceAfterTransaction.
  ///
  /// In en, this message translates to:
  /// **'Balance after transaction: {amount}'**
  String cashWalletBalanceAfterTransaction(Object amount);

  /// No description provided for @cashWalletLastCashAdded.
  ///
  /// In en, this message translates to:
  /// **'Last cash added: +{amount}'**
  String cashWalletLastCashAdded(Object amount);

  /// No description provided for @cashWalletLastAtmWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Last ATM withdrawal: +{amount}'**
  String cashWalletLastAtmWithdrawal(Object amount);

  /// No description provided for @cashBalanceInsufficientWarning.
  ///
  /// In en, this message translates to:
  /// **'Cash balance is insufficient'**
  String get cashBalanceInsufficientWarning;

  /// No description provided for @cashBalanceNoRecordedWarning.
  ///
  /// In en, this message translates to:
  /// **'No cash balance recorded for this trip'**
  String get cashBalanceNoRecordedWarning;

  /// No description provided for @cashBalanceAddCashAction.
  ///
  /// In en, this message translates to:
  /// **'Add Cash'**
  String get cashBalanceAddCashAction;

  /// No description provided for @manualExchangeAddRate.
  ///
  /// In en, this message translates to:
  /// **'Add exchange rate'**
  String get manualExchangeAddRate;

  /// No description provided for @manualExchangeFromCurrency.
  ///
  /// In en, this message translates to:
  /// **'From currency'**
  String get manualExchangeFromCurrency;

  /// No description provided for @manualExchangeToCurrency.
  ///
  /// In en, this message translates to:
  /// **'To currency'**
  String get manualExchangeToCurrency;

  /// No description provided for @manualExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get manualExchangeRate;

  /// No description provided for @manualExchangeSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Source note'**
  String get manualExchangeSourceNote;

  /// No description provided for @manualExchangeSaved.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate saved'**
  String get manualExchangeSaved;

  /// No description provided for @tripDetailsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search expenses'**
  String get tripDetailsSearchLabel;

  /// No description provided for @tripDetailsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title, description, or merchant'**
  String get tripDetailsSearchHint;

  /// No description provided for @tripDetailsFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get tripDetailsFilterCategory;

  /// No description provided for @tripDetailsFilterPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Filter by payment method'**
  String get tripDetailsFilterPaymentMethod;

  /// No description provided for @tripDetailsSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get tripDetailsSortBy;

  /// No description provided for @tripDetailsAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get tripDetailsAllCategories;

  /// No description provided for @tripDetailsAllPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'All payment methods'**
  String get tripDetailsAllPaymentMethods;

  /// No description provided for @tripDetailsSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get tripDetailsSortNewest;

  /// No description provided for @tripDetailsSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get tripDetailsSortOldest;

  /// No description provided for @tripDetailsSortHighestAmount.
  ///
  /// In en, this message translates to:
  /// **'Highest amount'**
  String get tripDetailsSortHighestAmount;

  /// No description provided for @tripDetailsSortLowestAmount.
  ///
  /// In en, this message translates to:
  /// **'Lowest amount'**
  String get tripDetailsSortLowestAmount;

  /// No description provided for @tripDetailsNoMatchingExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses match the current search and filters.'**
  String get tripDetailsNoMatchingExpenses;

  /// No description provided for @tripDetailsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get tripDetailsClearFilters;

  /// No description provided for @tripDetailsFiltersAndSort.
  ///
  /// In en, this message translates to:
  /// **'Filters & Sort'**
  String get tripDetailsFiltersAndSort;

  /// No description provided for @tripDetailsApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tripDetailsApplyFilters;

  /// No description provided for @tripDetailsBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency: {currency}'**
  String tripDetailsBaseCurrency(Object currency);

  /// No description provided for @tripDetailsBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget: {amount}'**
  String tripDetailsBudget(Object amount);

  /// No description provided for @tripDetailsDeleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete expense?'**
  String get tripDetailsDeleteExpenseTitle;

  /// No description provided for @tripDetailsDeleteExpenseMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove {expenseTitle} from this trip.'**
  String tripDetailsDeleteExpenseMessage(Object expenseTitle);

  /// No description provided for @tripDetailsDeleteExpenseError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete expense: {error}'**
  String tripDetailsDeleteExpenseError(Object error);

  /// No description provided for @tripDetailsExcludedCurrenciesWarning.
  ///
  /// In en, this message translates to:
  /// **'Some expenses in other currencies are not included in the total'**
  String get tripDetailsExcludedCurrenciesWarning;

  /// No description provided for @tripDetailsNoExpensesInBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this currency'**
  String get tripDetailsNoExpensesInBaseCurrency;

  /// No description provided for @tripDetailsEmptyExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get tripDetailsEmptyExpensesTitle;

  /// No description provided for @tripDetailsEmptyExpensesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first manual expense for this trip.'**
  String get tripDetailsEmptyExpensesMessage;

  /// No description provided for @noExpensesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Add your first expense now'**
  String get noExpensesHeadline;

  /// No description provided for @noExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first expense in seconds'**
  String get noExpensesSubtitle;

  /// No description provided for @noExpensesAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add First Expense'**
  String get noExpensesAddFirst;

  /// No description provided for @noExpensesCashWallet.
  ///
  /// In en, this message translates to:
  /// **'Cash Wallet'**
  String get noExpensesCashWallet;

  /// No description provided for @noExpensesCashWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track how much cash you still have'**
  String get noExpensesCashWalletSubtitle;

  /// No description provided for @noExpensesAddViaSms.
  ///
  /// In en, this message translates to:
  /// **'Add via Bank SMS'**
  String get noExpensesAddViaSms;

  /// No description provided for @noExpensesTipLabel.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get noExpensesTipLabel;

  /// No description provided for @noExpensesTipBody.
  ///
  /// In en, this message translates to:
  /// **'Once you add your first expense, you\'ll understand where your money goes'**
  String get noExpensesTipBody;

  /// No description provided for @tripDetailsQuickAddExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'Expense added'**
  String get tripDetailsQuickAddExpenseAdded;

  /// No description provided for @tripDetailsQuickAddRecentMerchants.
  ///
  /// In en, this message translates to:
  /// **'Recent merchants'**
  String get tripDetailsQuickAddRecentMerchants;

  /// No description provided for @tripDetailsQuickAddMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get tripDetailsQuickAddMoreDetails;

  /// No description provided for @tripDetailsQuickAddSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tripDetailsQuickAddSave;

  /// No description provided for @tripDetailsQuickAddPaymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get tripDetailsQuickAddPaymentCash;

  /// No description provided for @tripDetailsQuickAddPaymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get tripDetailsQuickAddPaymentWallet;

  /// No description provided for @tripDetailsQuickAddPaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get tripDetailsQuickAddPaymentCard;

  /// No description provided for @cardBankSNB.
  ///
  /// In en, this message translates to:
  /// **'SNB'**
  String get cardBankSNB;

  /// No description provided for @cardBankAlRajhi.
  ///
  /// In en, this message translates to:
  /// **'Al Rajhi'**
  String get cardBankAlRajhi;

  /// No description provided for @cardBankSAB.
  ///
  /// In en, this message translates to:
  /// **'SAB'**
  String get cardBankSAB;

  /// No description provided for @cardBankD360.
  ///
  /// In en, this message translates to:
  /// **'D360'**
  String get cardBankD360;

  /// No description provided for @cardBankBarq.
  ///
  /// In en, this message translates to:
  /// **'Barq'**
  String get cardBankBarq;

  /// No description provided for @cardBankOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cardBankOther;

  /// No description provided for @cardNetworkVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get cardNetworkVisa;

  /// No description provided for @cardNetworkMastercard.
  ///
  /// In en, this message translates to:
  /// **'Mastercard'**
  String get cardNetworkMastercard;

  /// No description provided for @cardNetworkMada.
  ///
  /// In en, this message translates to:
  /// **'Mada'**
  String get cardNetworkMada;

  /// No description provided for @cardNetworkOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cardNetworkOther;

  /// No description provided for @cardTierInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite'**
  String get cardTierInfinite;

  /// No description provided for @cardTierSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get cardTierSignature;

  /// No description provided for @cardTierPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get cardTierPlatinum;

  /// No description provided for @cardTierClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get cardTierClassic;

  /// No description provided for @cardTierWorld.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get cardTierWorld;

  /// No description provided for @cardTierWorldElite.
  ///
  /// In en, this message translates to:
  /// **'World Elite'**
  String get cardTierWorldElite;

  /// No description provided for @cardTierOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cardTierOther;

  /// No description provided for @cardFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get cardFormEditTitle;

  /// No description provided for @cardFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get cardFormAddTitle;

  /// No description provided for @cardFormBankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get cardFormBankLabel;

  /// No description provided for @cardFormCardNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Card network'**
  String get cardFormCardNetworkLabel;

  /// No description provided for @cardFormCardTierLabel.
  ///
  /// In en, this message translates to:
  /// **'Card tier'**
  String get cardFormCardTierLabel;

  /// No description provided for @cardFormLast4Label.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits'**
  String get cardFormLast4Label;

  /// No description provided for @cardFormLast4Hint.
  ///
  /// In en, this message translates to:
  /// **'1234'**
  String get cardFormLast4Hint;

  /// No description provided for @cardFormCardPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Card preview'**
  String get cardFormCardPreviewLabel;

  /// No description provided for @cardFormSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get cardFormSaveEdit;

  /// No description provided for @cardFormSaveCreate.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get cardFormSaveCreate;

  /// No description provided for @cardFormDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A card with these details already exists.'**
  String get cardFormDuplicate;

  /// No description provided for @expenseFormCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get expenseFormCreateTitle;

  /// No description provided for @expenseFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get expenseFormEditTitle;

  /// No description provided for @expenseFormTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get expenseFormTitleLabel;

  /// No description provided for @expenseFormTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Airport taxi'**
  String get expenseFormTitleHint;

  /// No description provided for @expenseFormTitleHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional. If empty, category will be used.'**
  String get expenseFormTitleHelper;

  /// No description provided for @expenseFormAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseFormAmountLabel;

  /// No description provided for @expenseFormAmountHint.
  ///
  /// In en, this message translates to:
  /// **'45.00'**
  String get expenseFormAmountHint;

  /// No description provided for @expenseFormCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get expenseFormCurrencyLabel;

  /// No description provided for @expenseFormCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseFormCategoryLabel;

  /// No description provided for @expenseFormPaymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get expenseFormPaymentMethodLabel;

  /// No description provided for @expenseFormPaymentNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Card network'**
  String get expenseFormPaymentNetworkLabel;

  /// No description provided for @expenseFormPaymentChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment channel'**
  String get expenseFormPaymentChannelLabel;

  /// No description provided for @expenseFormDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense date'**
  String get expenseFormDateLabel;

  /// No description provided for @expenseFormTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense time'**
  String get expenseFormTimeLabel;

  /// No description provided for @expenseFormNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get expenseFormNoteLabel;

  /// No description provided for @expenseFormNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get expenseFormNoteHint;

  /// No description provided for @expenseFormSaveCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Expense'**
  String get expenseFormSaveCreate;

  /// No description provided for @expenseFormSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get expenseFormSaveEdit;

  /// No description provided for @expenseFormAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero.'**
  String get expenseFormAmountPositive;

  /// No description provided for @expenseCurrencyMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency differs from trip base currency'**
  String get expenseCurrencyMismatchTitle;

  /// No description provided for @expenseCurrencyMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This expense uses {expenseCurrency} while the trip base currency is {tripCurrency}. You can edit it manually, or keep it as-is and it will be excluded from totals.'**
  String expenseCurrencyMismatchMessage(Object expenseCurrency, Object tripCurrency);

  /// No description provided for @expenseCurrencyMismatchConvertManually.
  ///
  /// In en, this message translates to:
  /// **'Convert manually'**
  String get expenseCurrencyMismatchConvertManually;

  /// No description provided for @expenseCurrencyMismatchKeepAsIs.
  ///
  /// In en, this message translates to:
  /// **'Keep as-is'**
  String get expenseCurrencyMismatchKeepAsIs;

  /// No description provided for @expenseFormSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save expense: {error}'**
  String expenseFormSaveError(Object error);

  /// No description provided for @expenseCategoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get expenseCategoryTransport;

  /// No description provided for @expenseCategoryAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get expenseCategoryAccommodation;

  /// No description provided for @expenseCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get expenseCategoryFood;

  /// No description provided for @expenseCategoryVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get expenseCategoryVisa;

  /// No description provided for @expenseCategoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get expenseCategoryShopping;

  /// No description provided for @expenseCategoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get expenseCategoryEntertainment;

  /// No description provided for @expenseCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get paymentMethodCreditCard;

  /// No description provided for @paymentMethodDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit Card'**
  String get paymentMethodDebitCard;

  /// No description provided for @paymentMethodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentMethodBankTransfer;

  /// No description provided for @paymentMethodMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile Wallet'**
  String get paymentMethodMobileWallet;

  /// No description provided for @paymentMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// No description provided for @paymentNetworkVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get paymentNetworkVisa;

  /// No description provided for @paymentNetworkMastercard.
  ///
  /// In en, this message translates to:
  /// **'Mastercard'**
  String get paymentNetworkMastercard;

  /// No description provided for @paymentNetworkMada.
  ///
  /// In en, this message translates to:
  /// **'Mada'**
  String get paymentNetworkMada;

  /// No description provided for @paymentNetworkOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentNetworkOther;

  /// No description provided for @paymentChannelApplePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get paymentChannelApplePay;

  /// No description provided for @paymentChannelGooglePay.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get paymentChannelGooglePay;

  /// No description provided for @paymentChannelCardPresent.
  ///
  /// In en, this message translates to:
  /// **'POS Purchase'**
  String get paymentChannelCardPresent;

  /// No description provided for @paymentChannelOnline.
  ///
  /// In en, this message translates to:
  /// **'Online Purchase'**
  String get paymentChannelOnline;

  /// No description provided for @paymentChannelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentChannelOther;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @financialSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial settings'**
  String get financialSettingsTitle;

  /// No description provided for @financialSettingsCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home country and home currency'**
  String get financialSettingsCardSubtitle;

  /// No description provided for @financialSettingsHomeCountry.
  ///
  /// In en, this message translates to:
  /// **'Home country'**
  String get financialSettingsHomeCountry;

  /// No description provided for @financialSettingsHomeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get financialSettingsHomeCurrency;

  /// No description provided for @financialSettingsStabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Changing home currency now will not change historical trip snapshots.'**
  String get financialSettingsStabilityHint;

  /// No description provided for @financialSettingsChangeCountry.
  ///
  /// In en, this message translates to:
  /// **'Change home country'**
  String get financialSettingsChangeCountry;

  /// No description provided for @financialProfileMissing.
  ///
  /// In en, this message translates to:
  /// **'Financial profile not found.'**
  String get financialProfileMissing;

  /// No description provided for @financialOnboardingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where do you live?'**
  String get financialOnboardingQuestion;

  /// No description provided for @financialOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your home country so the app can set your home currency.'**
  String get financialOnboardingSubtitle;

  /// No description provided for @financialCountrySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get financialCountrySearchHint;

  /// No description provided for @financialOnboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get financialOnboardingContinue;

  /// No description provided for @financialProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save financial profile.'**
  String get financialProfileSaveError;

  /// No description provided for @settingsLanguageAction.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageAction;

  /// No description provided for @settingsLanguageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get settingsLanguageTooltip;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used across the app.'**
  String get languageSectionDescription;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsLanguageSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save language: {error}'**
  String settingsLanguageSaveError(Object error);

  /// No description provided for @smsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add via Bank SMS'**
  String get smsScreenTitle;

  /// No description provided for @smsInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank SMS text'**
  String get smsInputLabel;

  /// No description provided for @smsInputHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the full bank SMS message here.'**
  String get smsInputHint;

  /// No description provided for @smsParseButton.
  ///
  /// In en, this message translates to:
  /// **'Parse SMS'**
  String get smsParseButton;

  /// No description provided for @smsParseDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Detected values were filled below. You can edit them before saving.'**
  String get smsParseDetectedMessage;

  /// No description provided for @smsParseNoResultMessage.
  ///
  /// In en, this message translates to:
  /// **'No reliable fields found. Please complete the form manually.'**
  String get smsParseNoResultMessage;

  /// No description provided for @smsTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant or description'**
  String get smsTitleLabel;

  /// No description provided for @smsTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Store, merchant, or short description'**
  String get smsTitleHint;

  /// No description provided for @smsTitleHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional. If empty, selected category is used as title.'**
  String get smsTitleHelper;

  /// No description provided for @smsCurrencyFallbackHelper.
  ///
  /// In en, this message translates to:
  /// **'Currency defaults to trip base currency: {currency}'**
  String smsCurrencyFallbackHelper(Object currency);

  /// No description provided for @smsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get smsSaveButton;

  /// No description provided for @smsTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the SMS text first.'**
  String get smsTextRequired;

  /// No description provided for @smsTripMissingError.
  ///
  /// In en, this message translates to:
  /// **'Trip is missing. Reopen this screen.'**
  String get smsTripMissingError;

  /// No description provided for @smsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save SMS expense: {error}'**
  String smsSaveError(Object error);

  /// No description provided for @intlBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'International breakdown'**
  String get intlBreakdownTitle;

  /// No description provided for @intlBilled.
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get intlBilled;

  /// No description provided for @intlFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get intlFees;

  /// No description provided for @intlTotalCharged.
  ///
  /// In en, this message translates to:
  /// **'Total charged'**
  String get intlTotalCharged;

  /// No description provided for @tripDetailsActuallyCharged.
  ///
  /// In en, this message translates to:
  /// **'Total charged (SAR)'**
  String get tripDetailsActuallyCharged;

  /// No description provided for @tripDetailsReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Trip report'**
  String get tripDetailsReportTooltip;

  /// No description provided for @tripReportsSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report Summary'**
  String get tripReportsSummarySubtitle;

  /// No description provided for @tripReportsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load report: {error}'**
  String tripReportsLoadError(Object error);

  /// No description provided for @tripReportsTotalBilled.
  ///
  /// In en, this message translates to:
  /// **'Total billed'**
  String get tripReportsTotalBilled;

  /// No description provided for @tripReportsTotalFees.
  ///
  /// In en, this message translates to:
  /// **'Total international transaction fees'**
  String get tripReportsTotalFees;

  /// No description provided for @tripReportsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get tripReportsByCategory;

  /// No description provided for @tripReportsByTransactionCurrency.
  ///
  /// In en, this message translates to:
  /// **'By transaction currency'**
  String get tripReportsByTransactionCurrency;

  /// No description provided for @tripReportsByPaymentNetwork.
  ///
  /// In en, this message translates to:
  /// **'By payment network'**
  String get tripReportsByPaymentNetwork;

  /// No description provided for @tripReportsByPaymentChannel.
  ///
  /// In en, this message translates to:
  /// **'By payment channel'**
  String get tripReportsByPaymentChannel;

  /// No description provided for @tripReportsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tripReportsOverview;

  /// No description provided for @tripReportsTotalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get tripReportsTotalExpenses;

  /// No description provided for @tripReportsDomestic.
  ///
  /// In en, this message translates to:
  /// **'Domestic'**
  String get tripReportsDomestic;

  /// No description provided for @tripReportsInternational.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get tripReportsInternational;

  /// No description provided for @tripReportsTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Top category'**
  String get tripReportsTopCategory;

  /// No description provided for @tripPredictionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get tripPredictionSectionTitle;

  /// No description provided for @tripPredictionBurnRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Current burn rate'**
  String get tripPredictionBurnRateTitle;

  /// No description provided for @tripPredictionForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Forecast total until trip end'**
  String get tripPredictionForecastTitle;

  /// No description provided for @tripReportsExpenseCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String tripReportsExpenseCountLabel(int count);

  /// No description provided for @tripReportsSmartSummary.
  ///
  /// In en, this message translates to:
  /// **'Smart summary'**
  String get tripReportsSmartSummary;

  /// No description provided for @tripReportsTopSpending.
  ///
  /// In en, this message translates to:
  /// **'Top spending'**
  String get tripReportsTopSpending;

  /// No description provided for @tripReportsInsightDominantCurrency.
  ///
  /// In en, this message translates to:
  /// **'Most of your spending was in {currency} ({percentage}%)'**
  String tripReportsInsightDominantCurrency(Object currency, int percentage);

  /// No description provided for @tripReportsInsightTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Top category: {category}'**
  String tripReportsInsightTopCategory(Object category);

  /// No description provided for @tripReportsInsightDominantPaymentChannel.
  ///
  /// In en, this message translates to:
  /// **'Most spending used {channel} ({percentage}%)'**
  String tripReportsInsightDominantPaymentChannel(Object channel, int percentage);

  /// No description provided for @tripReportsInsightInternationalShare.
  ///
  /// In en, this message translates to:
  /// **'International spending made up {percentage}% of your expenses'**
  String tripReportsInsightInternationalShare(int percentage);

  /// No description provided for @tripReportsInsightDomesticShare.
  ///
  /// In en, this message translates to:
  /// **'Domestic spending made up {percentage}% of your expenses'**
  String tripReportsInsightDomesticShare(int percentage);

  /// No description provided for @tripReportsInsightNoInternationalFees.
  ///
  /// In en, this message translates to:
  /// **'No international fees were charged'**
  String get tripReportsInsightNoInternationalFees;

  /// No description provided for @tripReportsInsightMultipleCurrencies.
  ///
  /// In en, this message translates to:
  /// **'You\'re dealing with {count} different currencies on this trip'**
  String tripReportsInsightMultipleCurrencies(int count);

  /// No description provided for @tripReportsInsightFeesPercentage.
  ///
  /// In en, this message translates to:
  /// **'Fees represent {percentage}% of your total spending'**
  String tripReportsInsightFeesPercentage(int percentage);

  /// No description provided for @tripReportsInsightInternationalDominant.
  ///
  /// In en, this message translates to:
  /// **'Most of your spending was international'**
  String get tripReportsInsightInternationalDominant;

  /// No description provided for @globalReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Global reports'**
  String get globalReportsTitle;

  /// No description provided for @globalReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Across all trips'**
  String get globalReportsSubtitle;

  /// No description provided for @globalReportsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Global reports'**
  String get globalReportsTooltip;

  /// No description provided for @globalReportsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load global report: {error}'**
  String globalReportsLoadError(Object error);

  /// No description provided for @globalReportsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips to analyze'**
  String get globalReportsEmptyTitle;

  /// No description provided for @globalReportsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a trip first to unlock global financial insights.'**
  String get globalReportsEmptyMessage;

  /// No description provided for @globalReportsZeroTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get globalReportsZeroTripsTitle;

  /// No description provided for @globalReportsZeroTripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first trip to start tracking expenses and see global reports.'**
  String get globalReportsZeroTripsSubtitle;

  /// No description provided for @globalReportsSingleTripNote.
  ///
  /// In en, this message translates to:
  /// **'Add more trips to unlock smarter cross-trip comparisons.'**
  String get globalReportsSingleTripNote;

  /// No description provided for @globalReportsSmartSummary.
  ///
  /// In en, this message translates to:
  /// **'Smart summary'**
  String get globalReportsSmartSummary;

  /// No description provided for @globalReportsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get globalReportsOverview;

  /// No description provided for @globalReportsTotalTrips.
  ///
  /// In en, this message translates to:
  /// **'Total trips'**
  String get globalReportsTotalTrips;

  /// No description provided for @globalReportsActiveTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips with expenses'**
  String get globalReportsActiveTrips;

  /// No description provided for @globalReportsTotalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get globalReportsTotalExpenses;

  /// No description provided for @globalReportsTotalFees.
  ///
  /// In en, this message translates to:
  /// **'Total international transaction fees'**
  String get globalReportsTotalFees;

  /// No description provided for @globalReportsTrackedDays.
  ///
  /// In en, this message translates to:
  /// **'Tracked trip days'**
  String get globalReportsTrackedDays;

  /// No description provided for @globalReportsTotalBilled.
  ///
  /// In en, this message translates to:
  /// **'Total billed'**
  String get globalReportsTotalBilled;

  /// No description provided for @globalReportsAveragePerTrip.
  ///
  /// In en, this message translates to:
  /// **'Average spending per trip'**
  String get globalReportsAveragePerTrip;

  /// No description provided for @globalReportsAveragePerDay.
  ///
  /// In en, this message translates to:
  /// **'Average daily spending'**
  String get globalReportsAveragePerDay;

  /// No description provided for @globalReportsTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Top category'**
  String get globalReportsTopCategory;

  /// No description provided for @globalReportsMostUsedPaymentChannel.
  ///
  /// In en, this message translates to:
  /// **'Most used payment channel'**
  String get globalReportsMostUsedPaymentChannel;

  /// No description provided for @globalReportsMostUsedPaymentNetwork.
  ///
  /// In en, this message translates to:
  /// **'Most used payment network'**
  String get globalReportsMostUsedPaymentNetwork;

  /// No description provided for @globalReportsDominantCurrency.
  ///
  /// In en, this message translates to:
  /// **'Dominant currency'**
  String get globalReportsDominantCurrency;

  /// No description provided for @globalReportsInternationalRatio.
  ///
  /// In en, this message translates to:
  /// **'International ratio'**
  String get globalReportsInternationalRatio;

  /// No description provided for @globalReportsDomesticRatio.
  ///
  /// In en, this message translates to:
  /// **'Domestic ratio'**
  String get globalReportsDomesticRatio;

  /// No description provided for @globalReportsInsightDominantPaymentChannel.
  ///
  /// In en, this message translates to:
  /// **'Most of your expenses were via {channel}'**
  String globalReportsInsightDominantPaymentChannel(Object channel);

  /// No description provided for @globalReportsInsightDominantCategory.
  ///
  /// In en, this message translates to:
  /// **'Top spending category: {category}'**
  String globalReportsInsightDominantCategory(Object category);

  /// No description provided for @globalReportsInsightAverageSpendPerTrip.
  ///
  /// In en, this message translates to:
  /// **'Average spend per trip: {amount}'**
  String globalReportsInsightAverageSpendPerTrip(Object amount);

  /// No description provided for @globalReportsInsightDominantCurrency.
  ///
  /// In en, this message translates to:
  /// **'Your spending is concentrated in {currency}'**
  String globalReportsInsightDominantCurrency(Object currency);

  /// No description provided for @globalReportsInsightCurrencyDistribution.
  ///
  /// In en, this message translates to:
  /// **'You spent in multiple currencies across your trips'**
  String get globalReportsInsightCurrencyDistribution;

  /// No description provided for @globalReportsInsightCategoryVariation.
  ///
  /// In en, this message translates to:
  /// **'Your spending was spread across more than one category'**
  String get globalReportsInsightCategoryVariation;

  /// No description provided for @globalReportsInsightPaymentVariation.
  ///
  /// In en, this message translates to:
  /// **'Your payment behavior varies across channels or networks'**
  String get globalReportsInsightPaymentVariation;

  /// No description provided for @globalReportsBehavioralInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Behavioral insights'**
  String get globalReportsBehavioralInsightsTitle;

  /// No description provided for @globalReportsBehavioralInsightTitleSpike.
  ///
  /// In en, this message translates to:
  /// **'Spending Spike'**
  String get globalReportsBehavioralInsightTitleSpike;

  /// No description provided for @globalReportsBehavioralInsightTitleCategoryDrift.
  ///
  /// In en, this message translates to:
  /// **'Category Concentration'**
  String get globalReportsBehavioralInsightTitleCategoryDrift;

  /// No description provided for @globalReportsBehavioralInsightTitleFees.
  ///
  /// In en, this message translates to:
  /// **'Fees Alert'**
  String get globalReportsBehavioralInsightTitleFees;

  /// No description provided for @globalReportsBehavioralInsightSpike.
  ///
  /// In en, this message translates to:
  /// **'Your spending in the second half is {percentage}% higher than the first half.'**
  String globalReportsBehavioralInsightSpike(int percentage);

  /// No description provided for @globalReportsBehavioralInsightSpikeAbove300.
  ///
  /// In en, this message translates to:
  /// **'Your spending in the second half is more than 3x the first half.'**
  String get globalReportsBehavioralInsightSpikeAbove300;

  /// No description provided for @globalReportsBehavioralInsightSpikeLarge.
  ///
  /// In en, this message translates to:
  /// **'Your spending in the second half is significantly higher than the first half.'**
  String get globalReportsBehavioralInsightSpikeLarge;

  /// No description provided for @globalReportsBehavioralInsightSpikeNoticeable.
  ///
  /// In en, this message translates to:
  /// **'Your spending in the second half is noticeably higher than the first half.'**
  String get globalReportsBehavioralInsightSpikeNoticeable;

  /// No description provided for @globalReportsBehavioralInsightCategoryDrift.
  ///
  /// In en, this message translates to:
  /// **'More than {percentage}% of your spending was in {category}.'**
  String globalReportsBehavioralInsightCategoryDrift(int percentage, Object category);

  /// No description provided for @globalReportsBehavioralInsightFees.
  ///
  /// In en, this message translates to:
  /// **'Fees are taking about {percentage}% of your spending. Consider a lower-fee payment method.'**
  String globalReportsBehavioralInsightFees(int percentage);

  /// No description provided for @globalReportsBehavioralInsightAttributionIn.
  ///
  /// In en, this message translates to:
  /// **'📍 In:'**
  String get globalReportsBehavioralInsightAttributionIn;

  /// No description provided for @globalReportsBehavioralInsightAttributionTop.
  ///
  /// In en, this message translates to:
  /// **'📊 Top impact:'**
  String get globalReportsBehavioralInsightAttributionTop;

  /// No description provided for @globalReportsInsightIntlDomesticRatio.
  ///
  /// In en, this message translates to:
  /// **'International {international}% vs domestic {domestic}%'**
  String globalReportsInsightIntlDomesticRatio(int international, int domestic);

  /// No description provided for @createTripHeading.
  ///
  /// In en, this message translates to:
  /// **'Where are you traveling?'**
  String get createTripHeading;

  /// No description provided for @createTripSubheading.
  ///
  /// In en, this message translates to:
  /// **'Choose your destination and we\'ll set the currency automatically'**
  String get createTripSubheading;

  /// No description provided for @tripFormDestinationSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search for a country'**
  String get tripFormDestinationSearchLabel;

  /// No description provided for @tripFormDestinationRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a destination to continue'**
  String get tripFormDestinationRequired;

  /// No description provided for @tripFormCustomTripNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip name (optional)'**
  String get tripFormCustomTripNameLabel;

  /// No description provided for @tripFormCustomTripNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Summer Getaway'**
  String get tripFormCustomTripNameHint;

  /// No description provided for @tripFormCurrencyAutoSelected.
  ///
  /// In en, this message translates to:
  /// **'Currency set to {currency}'**
  String tripFormCurrencyAutoSelected(Object currency);

  /// No description provided for @tripFormAutoGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated automatically'**
  String get tripFormAutoGeneratedTitle;

  /// No description provided for @tripFormEditCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Give your trip a custom name'**
  String get tripFormEditCustomTitle;

  /// No description provided for @tripFormCreateWithoutCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll create \"{tripTitle}\" as your trip name'**
  String tripFormCreateWithoutCustomTitle(Object tripTitle);

  /// No description provided for @tripFormCustomDestinationFallback.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find your destination? Add custom destination'**
  String get tripFormCustomDestinationFallback;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
