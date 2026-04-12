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
  /// **'Save Changes'**
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

  /// No description provided for @expenseFormDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense date'**
  String get expenseFormDateLabel;

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

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

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
