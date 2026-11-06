import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GoAbacUs'**
  String get appTitle;

  /// No description provided for @resetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear the abacus'**
  String get resetTooltip;

  /// No description provided for @tiltOn.
  ///
  /// In en, this message translates to:
  /// **'Tilt: on'**
  String get tiltOn;

  /// No description provided for @tiltOff.
  ///
  /// In en, this message translates to:
  /// **'Tilt: off'**
  String get tiltOff;

  /// No description provided for @soundOn.
  ///
  /// In en, this message translates to:
  /// **'Sound: on'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In en, this message translates to:
  /// **'Sound: off'**
  String get soundOff;

  /// No description provided for @playTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show an example'**
  String get playTooltip;

  /// No description provided for @stopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopTooltip;

  /// No description provided for @replayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get replayTooltip;

  /// No description provided for @tapeHint.
  ///
  /// In en, this message translates to:
  /// **'Move the beads: I will write down what you do'**
  String get tapeHint;

  /// No description provided for @enterExample.
  ///
  /// In en, this message translates to:
  /// **'Type an example'**
  String get enterExample;

  /// No description provided for @showButton.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showButton;

  /// No description provided for @errorUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Finish the example with a number'**
  String get errorUnfinished;

  /// No description provided for @errorNegative.
  ///
  /// In en, this message translates to:
  /// **'The answer must not drop below zero'**
  String get errorNegative;

  /// No description provided for @errorTooBig.
  ///
  /// In en, this message translates to:
  /// **'This number does not fit on the abacus'**
  String get errorTooBig;

  /// No description provided for @clearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing the abacus'**
  String get clearing;

  /// No description provided for @stepSet.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String stepSet(String number);

  /// No description provided for @stepAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {number}'**
  String stepAdd(String number);

  /// No description provided for @stepSub.
  ///
  /// In en, this message translates to:
  /// **'Take away {number}'**
  String stepSub(String number);

  /// No description provided for @carryHint.
  ///
  /// In en, this message translates to:
  /// **'No room: one bead in the next row, {count} back here'**
  String carryHint(int count);

  /// No description provided for @borrowHint.
  ///
  /// In en, this message translates to:
  /// **'Not enough: one bead off the next row, {count} added here'**
  String borrowHint(int count);

  /// No description provided for @place0.
  ///
  /// In en, this message translates to:
  /// **'Ones'**
  String get place0;

  /// No description provided for @place1.
  ///
  /// In en, this message translates to:
  /// **'Tens'**
  String get place1;

  /// No description provided for @place2.
  ///
  /// In en, this message translates to:
  /// **'Hundreds'**
  String get place2;

  /// No description provided for @place3.
  ///
  /// In en, this message translates to:
  /// **'Thousands'**
  String get place3;

  /// No description provided for @place4.
  ///
  /// In en, this message translates to:
  /// **'Ten thousands'**
  String get place4;

  /// No description provided for @place5.
  ///
  /// In en, this message translates to:
  /// **'Hundred thousands'**
  String get place5;

  /// No description provided for @place6.
  ///
  /// In en, this message translates to:
  /// **'Millions'**
  String get place6;

  /// No description provided for @place7.
  ///
  /// In en, this message translates to:
  /// **'Ten millions'**
  String get place7;

  /// No description provided for @place8.
  ///
  /// In en, this message translates to:
  /// **'Hundred millions'**
  String get place8;

  /// No description provided for @place9.
  ///
  /// In en, this message translates to:
  /// **'Billions'**
  String get place9;

  /// No description provided for @exercisesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercisesTooltip;

  /// No description provided for @opsAdd.
  ///
  /// In en, this message translates to:
  /// **'Addition'**
  String get opsAdd;

  /// No description provided for @opsSub.
  ///
  /// In en, this message translates to:
  /// **'Subtraction'**
  String get opsSub;

  /// No description provided for @opsBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get opsBoth;

  /// No description provided for @levelEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get levelEasy;

  /// No description provided for @levelHard.
  ///
  /// In en, this message translates to:
  /// **'With carrying'**
  String get levelHard;

  /// No description provided for @levelEasyHint.
  ///
  /// In en, this message translates to:
  /// **'Numbers up to 99, no carrying'**
  String get levelEasyHint;

  /// No description provided for @levelHardHint.
  ///
  /// In en, this message translates to:
  /// **'Numbers up to 999, carrying and borrowing'**
  String get levelHardHint;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// No description provided for @taskNumber.
  ///
  /// In en, this message translates to:
  /// **'Task {n}'**
  String taskNumber(int n);

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @exitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Finish exercises'**
  String get exitTooltip;

  /// No description provided for @rightTitle.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get rightTitle;

  /// No description provided for @wrongTitle.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get wrongTitle;

  /// No description provided for @timeUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Time is up'**
  String get timeUpTitle;

  /// No description provided for @answerIs.
  ///
  /// In en, this message translates to:
  /// **'The answer is {answer}'**
  String answerIs(String answer);

  /// No description provided for @showSolution.
  ///
  /// In en, this message translates to:
  /// **'Show the solution'**
  String get showSolution;

  /// No description provided for @streakText.
  ///
  /// In en, this message translates to:
  /// **'{n} in a row!'**
  String streakText(int n);

  /// No description provided for @solveHint.
  ///
  /// In en, this message translates to:
  /// **'Work it out on the abacus'**
  String get solveHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
