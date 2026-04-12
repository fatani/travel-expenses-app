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
  String get tripDetailsExpensesSection => 'Expenses';

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
  String get expenseFormDateLabel => 'Expense date';

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
}
