import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used for your staff experience.'**
  String get languageDescription;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese (Brazil)'**
  String get languagePortuguese;

  /// No description provided for @languageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language updated.'**
  String get languageSaved;

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

  /// No description provided for @commonArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commonArchive;

  /// No description provided for @commonUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get commonUnarchive;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonErrorTitle;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get commonRole;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get commonBackToSignIn;

  /// No description provided for @commonGoToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to Sign In'**
  String get commonGoToSignIn;

  /// No description provided for @commonOpenHands.
  ///
  /// In en, this message translates to:
  /// **'Open Hands'**
  String get commonOpenHands;

  /// No description provided for @commonNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get commonNotSpecified;

  /// No description provided for @commonContinueIn.
  ///
  /// In en, this message translates to:
  /// **'Continue in'**
  String get commonContinueIn;

  /// No description provided for @commonWebApp.
  ///
  /// In en, this message translates to:
  /// **'Web App'**
  String get commonWebApp;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations, minus the chaos.'**
  String get loginIntroTitle;

  /// No description provided for @loginIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage shifts, tasks, documents, and team execution from one place.'**
  String get loginIntroBody;

  /// No description provided for @loginFeatureLiveTaskTracking.
  ///
  /// In en, this message translates to:
  /// **'Live task tracking'**
  String get loginFeatureLiveTaskTracking;

  /// No description provided for @loginFeatureSharedTeamWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Shared team workflows'**
  String get loginFeatureSharedTeamWorkflows;

  /// No description provided for @loginFeatureOperationalVisibility.
  ///
  /// In en, this message translates to:
  /// **'Operational visibility'**
  String get loginFeatureOperationalVisibility;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginWelcomeBackBody.
  ///
  /// In en, this message translates to:
  /// **'Use your email and password to continue.'**
  String get loginWelcomeBackBody;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@restaurant.com'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get loginPasswordHint;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNeedAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Need access?'**
  String get loginNeedAccessTitle;

  /// No description provided for @loginNeedAccessBody.
  ///
  /// In en, this message translates to:
  /// **'If you need access to an existing organization, ask your manager to send you an invite.'**
  String get loginNeedAccessBody;

  /// No description provided for @loginNeedAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Need an account?'**
  String get loginNeedAccountTitle;

  /// No description provided for @loginNeedAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Create a trial organization or accept an invite from your manager.'**
  String get loginNeedAccountBody;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginSignUp;

  /// No description provided for @loginVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String loginVersion(String version);

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get loginEnterEmail;

  /// No description provided for @loginEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get loginEnterValidEmail;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginEnterPassword;

  /// No description provided for @loginProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User profile not found. Please contact support.'**
  String get loginProfileNotFound;

  /// No description provided for @loginResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get loginResetPasswordTitle;

  /// No description provided for @loginResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email tied to your Hands account and we’ll send a secure reset link.'**
  String get loginResetPasswordSubtitle;

  /// No description provided for @loginResetPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll send a password reset email right away.'**
  String get loginResetPasswordBody;

  /// No description provided for @loginResetEmailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginResetEmailAddressLabel;

  /// No description provided for @loginResetEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get loginResetEmailHint;

  /// No description provided for @loginResetSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get loginResetSendButton;

  /// No description provided for @loginResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String loginResetEmailSent(String email);

  /// No description provided for @loginEnterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get loginEnterEmailAddress;

  /// No description provided for @loginEnterValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get loginEnterValidEmailAddress;

  /// No description provided for @loginResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get loginResetFailed;

  /// No description provided for @loginNoAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address.'**
  String get loginNoAccountFound;

  /// No description provided for @loginTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get loginTooManyRequests;

  /// No description provided for @welcomeInviteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invite unavailable'**
  String get welcomeInviteUnavailable;

  /// No description provided for @welcomeToOrganization.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {organizationName}!'**
  String welcomeToOrganization(String organizationName);

  /// No description provided for @welcomeInviteBody.
  ///
  /// In en, this message translates to:
  /// **'You’ve been invited to join {organizationName}. Complete your account setup to get started.'**
  String welcomeInviteBody(String organizationName);

  /// No description provided for @welcomeAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get welcomeAccountDetails;

  /// No description provided for @welcomeCompleteSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Account Setup'**
  String get welcomeCompleteSetupTitle;

  /// No description provided for @welcomeCompleteSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Create a password to finish setting up your account. Your organization access and role will be applied automatically from this invite.'**
  String get welcomeCompleteSetupBody;

  /// No description provided for @welcomeNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get welcomeNewPasswordLabel;

  /// No description provided for @welcomeNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get welcomeNewPasswordHint;

  /// No description provided for @welcomeConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get welcomeConfirmPasswordLabel;

  /// No description provided for @welcomeConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new password'**
  String get welcomeConfirmPasswordHint;

  /// No description provided for @welcomeEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get welcomeEnterNewPassword;

  /// No description provided for @welcomePasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get welcomePasswordMinLength;

  /// No description provided for @welcomeConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get welcomeConfirmNewPassword;

  /// No description provided for @welcomePasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get welcomePasswordsDoNotMatch;

  /// No description provided for @welcomeCompleteSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get welcomeCompleteSetupButton;

  /// No description provided for @welcomeAccountSetupCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Setup Complete'**
  String get welcomeAccountSetupCompleteTitle;

  /// No description provided for @welcomeAccountReady.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready to use.'**
  String get welcomeAccountReady;

  /// No description provided for @welcomeOpenOnWeb.
  ///
  /// In en, this message translates to:
  /// **'You can open Hands on the web right now. Mobile app download is optional.'**
  String get welcomeOpenOnWeb;

  /// No description provided for @welcomeDownloadOnThe.
  ///
  /// In en, this message translates to:
  /// **'Download on the'**
  String get welcomeDownloadOnThe;

  /// No description provided for @welcomeAppStore.
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get welcomeAppStore;

  /// No description provided for @welcomeUseSameCredentials.
  ///
  /// In en, this message translates to:
  /// **'Use the same email and password you just created anywhere you sign in.'**
  String get welcomeUseSameCredentials;

  /// No description provided for @welcomeInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'This invite has already been accepted. Sign in with your account to continue.'**
  String get welcomeInviteAccepted;

  /// No description provided for @welcomeInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite link has expired. Ask your administrator to send you a new invite.'**
  String get welcomeInviteExpired;

  /// No description provided for @welcomeInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'This invite was revoked by your administrator. Ask them to send a new invite if you still need access.'**
  String get welcomeInviteRevoked;

  /// No description provided for @welcomeInviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'This invite link is not valid or is no longer available.'**
  String get welcomeInviteInvalid;

  /// No description provided for @welcomeRoleGeneralUser.
  ///
  /// In en, this message translates to:
  /// **'General User'**
  String get welcomeRoleGeneralUser;

  /// No description provided for @welcomeRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get welcomeRoleManager;

  /// No description provided for @welcomeRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get welcomeRoleAdmin;

  /// No description provided for @welcomeRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get welcomeRoleUser;

  /// No description provided for @welcomeFailedSetup.
  ///
  /// In en, this message translates to:
  /// **'Failed to set up account: {error}'**
  String welcomeFailedSetup(String error);

  /// No description provided for @welcomeInviteUsed.
  ///
  /// In en, this message translates to:
  /// **'This invite has already been used. Sign in with your account instead.'**
  String get welcomeInviteUsed;

  /// No description provided for @welcomeInviteExistingAccount.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Sign in instead, or ask your administrator if you expected a fresh invite.'**
  String get welcomeInviteExistingAccount;

  /// No description provided for @welcomeInviteExpiredError.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired. Ask your administrator to send a new one.'**
  String get welcomeInviteExpiredError;

  /// No description provided for @welcomeInviteRevokedError.
  ///
  /// In en, this message translates to:
  /// **'This invite has been revoked. Ask your administrator for a new invite.'**
  String get welcomeInviteRevokedError;

  /// No description provided for @welcomeInviteMissingEmail.
  ///
  /// In en, this message translates to:
  /// **'Invite is missing an email address.'**
  String get welcomeInviteMissingEmail;

  /// No description provided for @notificationsInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notificationsInbox;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @notificationsRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notificationsRead;

  /// No description provided for @notificationsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get notificationsArchived;

  /// No description provided for @notificationsHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unread updates, read items, and archived messages.'**
  String get notificationsHeaderSubtitle;

  /// No description provided for @notificationsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get notificationsDeleteTitle;

  /// No description provided for @notificationsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this message? This action cannot be undone.'**
  String get notificationsDeleteBody;

  /// No description provided for @notificationsDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message deleted successfully'**
  String get notificationsDeleteSuccess;

  /// No description provided for @notificationsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message: {error}'**
  String notificationsDeleteFailed(String error);

  /// No description provided for @notificationsNoMessagesIn.
  ///
  /// In en, this message translates to:
  /// **'No messages in {filter}'**
  String notificationsNoMessagesIn(String filter);

  /// No description provided for @notificationsNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get notificationsNewMessage;

  /// No description provided for @notificationsNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get notificationsNoContent;

  /// No description provided for @notificationsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get notificationsLoadMore;

  /// No description provided for @notificationsUpdateType.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get notificationsUpdateType;

  /// No description provided for @notificationsSummaryType.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get notificationsSummaryType;

  /// No description provided for @notificationsSummaryOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get notificationsSummaryOverview;

  /// No description provided for @notificationsSummaryCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion'**
  String get notificationsSummaryCompletion;

  /// No description provided for @notificationsSummaryTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get notificationsSummaryTasks;

  /// No description provided for @notificationsSummaryMissedTasks.
  ///
  /// In en, this message translates to:
  /// **'Missed tasks'**
  String get notificationsSummaryMissedTasks;

  /// No description provided for @notificationsSummaryLocations.
  ///
  /// In en, this message translates to:
  /// **'Location performance'**
  String get notificationsSummaryLocations;

  /// No description provided for @notificationsSummaryNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notificationsSummaryNotes;

  /// No description provided for @notificationsSummaryPhotoBypassed.
  ///
  /// In en, this message translates to:
  /// **'Photo bypassed'**
  String get notificationsSummaryPhotoBypassed;

  /// No description provided for @notificationsSummaryNoReason.
  ///
  /// In en, this message translates to:
  /// **'No reason provided'**
  String get notificationsSummaryNoReason;

  /// No description provided for @notificationsSummaryMoreItems.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String notificationsSummaryMoreItems(int count);

  /// No description provided for @notificationsYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String notificationsYesterdayAt(String time);

  /// No description provided for @contactUsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUsTitle;

  /// No description provided for @contactUsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Help request sent successfully! We’ll get back to you within 24 hours.'**
  String get contactUsSuccess;

  /// No description provided for @contactUsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send help request'**
  String get contactUsFailed;

  /// No description provided for @contactUsNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get contactUsNetworkError;

  /// No description provided for @contactUsOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Support, without the back-and-forth.'**
  String get contactUsOverviewTitle;

  /// No description provided for @contactUsOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Send one clear request and our team will respond with the right help for setup, billing, bugs, or workflow questions.'**
  String get contactUsOverviewBody;

  /// No description provided for @contactUsTechnicalIssues.
  ///
  /// In en, this message translates to:
  /// **'Technical issues'**
  String get contactUsTechnicalIssues;

  /// No description provided for @contactUsBillingQuestions.
  ///
  /// In en, this message translates to:
  /// **'Billing questions'**
  String get contactUsBillingQuestions;

  /// No description provided for @contactUsTeamSetupHelp.
  ///
  /// In en, this message translates to:
  /// **'Team setup help'**
  String get contactUsTeamSetupHelp;

  /// No description provided for @contactUsWhatToExpect.
  ///
  /// In en, this message translates to:
  /// **'What to expect'**
  String get contactUsWhatToExpect;

  /// No description provided for @contactUsTypicalResponse.
  ///
  /// In en, this message translates to:
  /// **'Typical response'**
  String get contactUsTypicalResponse;

  /// No description provided for @contactUsTypicalResponseValue.
  ///
  /// In en, this message translates to:
  /// **'Within 24 hours'**
  String get contactUsTypicalResponseValue;

  /// No description provided for @contactUsBestFor.
  ///
  /// In en, this message translates to:
  /// **'Best for'**
  String get contactUsBestFor;

  /// No description provided for @contactUsBestForValue.
  ///
  /// In en, this message translates to:
  /// **'Product help, billing, and setup'**
  String get contactUsBestForValue;

  /// No description provided for @contactUsHelpfulDetails.
  ///
  /// In en, this message translates to:
  /// **'Helpful details'**
  String get contactUsHelpfulDetails;

  /// No description provided for @contactUsHelpfulDetailsValue.
  ///
  /// In en, this message translates to:
  /// **'Location, role, and what happened'**
  String get contactUsHelpfulDetailsValue;

  /// No description provided for @contactUsSupportContext.
  ///
  /// In en, this message translates to:
  /// **'Support context'**
  String get contactUsSupportContext;

  /// No description provided for @contactUsSupportContextBody.
  ///
  /// In en, this message translates to:
  /// **'We will include the current help and location context automatically.'**
  String get contactUsSupportContextBody;

  /// No description provided for @bottomNavTodayTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Tasks'**
  String get bottomNavTodayTasks;

  /// No description provided for @bottomNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get bottomNavDashboard;

  /// No description provided for @bottomNavSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get bottomNavSetup;

  /// No description provided for @bottomNavDocumentCenter.
  ///
  /// In en, this message translates to:
  /// **'Document Center'**
  String get bottomNavDocumentCenter;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get messagesTitle;

  /// No description provided for @messagesHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox keeps everyone up to date. Broadcasts send new updates. Audiences organize who receives them.'**
  String get messagesHeaderSubtitle;

  /// No description provided for @messagesInboxTab.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get messagesInboxTab;

  /// No description provided for @messagesBroadcastsTab.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts'**
  String get messagesBroadcastsTab;

  /// No description provided for @messagesAudiencesTab.
  ///
  /// In en, this message translates to:
  /// **'Audiences'**
  String get messagesAudiencesTab;

  /// No description provided for @messagesBroadcastsTitle.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts'**
  String get messagesBroadcastsTitle;

  /// No description provided for @messagesBroadcastsBody.
  ///
  /// In en, this message translates to:
  /// **'Send a clear update to everyone, a location, or a custom audience.'**
  String get messagesBroadcastsBody;

  /// No description provided for @messagesBroadcastsHelp.
  ///
  /// In en, this message translates to:
  /// **'Use broadcasts for clean team-wide or location-specific updates that should stay visible in Inbox.'**
  String get messagesBroadcastsHelp;

  /// No description provided for @messagesNewBroadcast.
  ///
  /// In en, this message translates to:
  /// **'New broadcast'**
  String get messagesNewBroadcast;

  /// No description provided for @messagesBroadcastsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts unavailable'**
  String get messagesBroadcastsUnavailable;

  /// No description provided for @messagesOrgContextMissing.
  ///
  /// In en, this message translates to:
  /// **'We could not determine your organization context.'**
  String get messagesOrgContextMissing;

  /// No description provided for @messagesNoBroadcasts.
  ///
  /// In en, this message translates to:
  /// **'No broadcasts yet'**
  String get messagesNoBroadcasts;

  /// No description provided for @messagesNoBroadcastsBody.
  ///
  /// In en, this message translates to:
  /// **'Your sent updates will appear here once you broadcast to the team.'**
  String get messagesNoBroadcastsBody;

  /// No description provided for @messagesSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get messagesSending;

  /// No description provided for @messagesEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get messagesEveryone;

  /// No description provided for @messagesCustomAudience.
  ///
  /// In en, this message translates to:
  /// **'Custom audience'**
  String get messagesCustomAudience;

  /// No description provided for @messagesLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get messagesLocation;

  /// No description provided for @messagesUntitledBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Untitled broadcast'**
  String get messagesUntitledBroadcast;

  /// No description provided for @messagesAudiencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Audiences'**
  String get messagesAudiencesTitle;

  /// No description provided for @messagesAudiencesBody.
  ///
  /// In en, this message translates to:
  /// **'Create reusable audience lists so the right team gets the right update every time.'**
  String get messagesAudiencesBody;

  /// No description provided for @messagesAudiencesHelp.
  ///
  /// In en, this message translates to:
  /// **'Audiences are reusable recipient groups that help you send the right broadcast to the right team.'**
  String get messagesAudiencesHelp;

  /// No description provided for @broadcastSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New broadcast'**
  String get broadcastSheetTitle;

  /// No description provided for @broadcastSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a clear update to everyone, a location, or a saved audience.'**
  String get broadcastSheetSubtitle;

  /// No description provided for @broadcastSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send broadcast'**
  String get broadcastSendButton;

  /// No description provided for @broadcastInfoTip.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts appear in the team inbox and can also send a push notification.'**
  String get broadcastInfoTip;

  /// No description provided for @broadcastAudienceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get broadcastAudienceSectionTitle;

  /// No description provided for @broadcastRecipientEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get broadcastRecipientEveryone;

  /// No description provided for @broadcastRecipientSavedAudience.
  ///
  /// In en, this message translates to:
  /// **'Saved audience'**
  String get broadcastRecipientSavedAudience;

  /// No description provided for @broadcastRecipientLocation.
  ///
  /// In en, this message translates to:
  /// **'Specific location'**
  String get broadcastRecipientLocation;

  /// No description provided for @broadcastSendToLabel.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get broadcastSendToLabel;

  /// No description provided for @broadcastChooseAudience.
  ///
  /// In en, this message translates to:
  /// **'Choose an audience'**
  String get broadcastChooseAudience;

  /// No description provided for @broadcastSelectAudience.
  ///
  /// In en, this message translates to:
  /// **'Select an audience'**
  String get broadcastSelectAudience;

  /// No description provided for @broadcastSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select a location'**
  String get broadcastSelectLocation;

  /// No description provided for @broadcastMessageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get broadcastMessageSectionTitle;

  /// No description provided for @broadcastHeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get broadcastHeadlineLabel;

  /// No description provided for @broadcastEnterHeadline.
  ///
  /// In en, this message translates to:
  /// **'Enter a headline'**
  String get broadcastEnterHeadline;

  /// No description provided for @broadcastMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get broadcastMessageLabel;

  /// No description provided for @broadcastMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What should the team know right now?'**
  String get broadcastMessageHint;

  /// No description provided for @broadcastEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a message'**
  String get broadcastEnterMessage;

  /// No description provided for @broadcastDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get broadcastDismiss;

  /// No description provided for @broadcastAutoTitleAudience.
  ///
  /// In en, this message translates to:
  /// **'Update for {name}'**
  String broadcastAutoTitleAudience(String name);

  /// No description provided for @broadcastAutoTitleAudienceFallback.
  ///
  /// In en, this message translates to:
  /// **'Audience update'**
  String get broadcastAutoTitleAudienceFallback;

  /// No description provided for @broadcastAutoTitleLocation.
  ///
  /// In en, this message translates to:
  /// **'Update for {name}'**
  String broadcastAutoTitleLocation(String name);

  /// No description provided for @broadcastAutoTitleLocationFallback.
  ///
  /// In en, this message translates to:
  /// **'Location update'**
  String get broadcastAutoTitleLocationFallback;

  /// No description provided for @broadcastAutoTitleTeam.
  ///
  /// In en, this message translates to:
  /// **'Team update'**
  String get broadcastAutoTitleTeam;

  /// No description provided for @audienceSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create reusable audience lists so managers can target the right team quickly.'**
  String get audienceSheetSubtitle;

  /// No description provided for @audienceSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved audiences'**
  String get audienceSavedTitle;

  /// No description provided for @audienceNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New audience'**
  String get audienceNewTitle;

  /// No description provided for @audienceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Audience name'**
  String get audienceNameLabel;

  /// No description provided for @audienceSearchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search team members'**
  String get audienceSearchMembers;

  /// No description provided for @audienceTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team members'**
  String get audienceTeamMembers;

  /// No description provided for @audienceMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Audience members'**
  String get audienceMembersTitle;

  /// No description provided for @audienceCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create audience'**
  String get audienceCreateButton;

  /// No description provided for @audienceEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit audience'**
  String get audienceEditTitle;

  /// No description provided for @audienceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete audience'**
  String get audienceDeleteTitle;

  /// No description provided for @audienceEnterNameAndMember.
  ///
  /// In en, this message translates to:
  /// **'Enter an audience name and select at least one team member.'**
  String get audienceEnterNameAndMember;

  /// No description provided for @audienceCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Audience created successfully!'**
  String get audienceCreatedSuccess;

  /// No description provided for @audienceUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Audience updated successfully!'**
  String get audienceUpdatedSuccess;

  /// No description provided for @audienceDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Audience deleted successfully!'**
  String get audienceDeletedSuccess;

  /// No description provided for @audienceDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the audience \"{groupName}\"? This action cannot be undone.'**
  String audienceDeleteBody(String groupName);

  /// No description provided for @messagesManageAudiences.
  ///
  /// In en, this message translates to:
  /// **'Manage audiences'**
  String get messagesManageAudiences;

  /// No description provided for @messagesAudiencesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audiences unavailable'**
  String get messagesAudiencesUnavailable;

  /// No description provided for @messagesNoAudiences.
  ///
  /// In en, this message translates to:
  /// **'No custom audiences yet'**
  String get messagesNoAudiences;

  /// No description provided for @messagesNoAudiencesBody.
  ///
  /// In en, this message translates to:
  /// **'Start with custom audiences for teams like Bar, Kitchen, or Weekend crew.'**
  String get messagesNoAudiencesBody;

  /// No description provided for @messagesCustomAudiencesMetric.
  ///
  /// In en, this message translates to:
  /// **'Custom audiences'**
  String get messagesCustomAudiencesMetric;

  /// No description provided for @messagesLinkedMembersMetric.
  ///
  /// In en, this message translates to:
  /// **'Linked members'**
  String get messagesLinkedMembersMetric;

  /// No description provided for @messagesUnnamedAudience.
  ///
  /// In en, this message translates to:
  /// **'Unnamed audience'**
  String get messagesUnnamedAudience;

  /// No description provided for @messagesMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String messagesMemberCount(int count);

  /// No description provided for @threadTitle.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get threadTitle;

  /// No description provided for @threadNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get threadNoMessages;

  /// No description provided for @threadMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get threadMessageHint;

  /// No description provided for @threadDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get threadDeleteTitle;

  /// No description provided for @threadDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message? This action cannot be undone.'**
  String get threadDeleteBody;

  /// No description provided for @threadDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message deleted successfully'**
  String get threadDeleteSuccess;

  /// No description provided for @threadDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message: {error}'**
  String threadDeleteFailed(String error);

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get commonReplay;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find the fastest way to complete work, set up operations, or fix a problem.'**
  String get helpSubtitle;

  /// No description provided for @helpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search help, setup, or troubleshooting'**
  String get helpSearchHint;

  /// No description provided for @helpSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get helpSearchResultsTitle;

  /// No description provided for @helpNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No help topics matched that search yet.'**
  String get helpNoSearchResults;

  /// No description provided for @helpTopicsFoundForRole.
  ///
  /// In en, this message translates to:
  /// **'{count} topics found for {role}'**
  String helpTopicsFoundForRole(int count, String role);

  /// No description provided for @helpStartHereTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Here'**
  String get helpStartHereTitle;

  /// No description provided for @helpOpenHelp.
  ///
  /// In en, this message translates to:
  /// **'Open Help'**
  String get helpOpenHelp;

  /// No description provided for @helpOpenWalkthrough.
  ///
  /// In en, this message translates to:
  /// **'Open walkthrough'**
  String get helpOpenWalkthrough;

  /// No description provided for @helpStartHereSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Begin with the shortest path for your role.'**
  String get helpStartHereSectionSubtitle;

  /// No description provided for @helpNewHereTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m new here'**
  String get helpNewHereTitle;

  /// No description provided for @helpNewHereBody.
  ///
  /// In en, this message translates to:
  /// **'Get the role-aware walkthrough of the app without reading every guide first.'**
  String get helpNewHereBody;

  /// No description provided for @helpOpenStartHere.
  ///
  /// In en, this message translates to:
  /// **'Open Start Here'**
  String get helpOpenStartHere;

  /// No description provided for @helpBrowseByRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse by role'**
  String get helpBrowseByRoleTitle;

  /// No description provided for @helpBrowseByRoleBody.
  ///
  /// In en, this message translates to:
  /// **'See only the topics for your job.'**
  String get helpBrowseByRoleBody;

  /// No description provided for @helpFixProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix a problem'**
  String get helpFixProblemTitle;

  /// No description provided for @helpFixProblemBody.
  ///
  /// In en, this message translates to:
  /// **'Go straight to troubleshooting.'**
  String get helpFixProblemBody;

  /// No description provided for @helpBrowseByRoleSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch perspective without changing accounts.'**
  String get helpBrowseByRoleSectionSubtitle;

  /// No description provided for @helpReplayGuidedTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay guided tour'**
  String get helpReplayGuidedTourTitle;

  /// No description provided for @helpReplayGuidedTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jump back into the in-app walkthrough for your current role whenever you need a refresher.'**
  String get helpReplayGuidedTourSubtitle;

  /// No description provided for @helpWhatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get helpWhatsNewTitle;

  /// No description provided for @helpWhatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reopen the latest major update summary and jump into the guided tour again.'**
  String get helpWhatsNewSubtitle;

  /// No description provided for @helpMajorUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Major update available'**
  String get helpMajorUpdateAvailable;

  /// No description provided for @helpLatestMajorRelease.
  ///
  /// In en, this message translates to:
  /// **'Latest major release'**
  String get helpLatestMajorRelease;

  /// No description provided for @helpOpenLatestReleaseUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'Open the latest release summary and update instructions for your role.'**
  String get helpOpenLatestReleaseUpdateBody;

  /// No description provided for @helpOpenLatestReleaseTourBody.
  ///
  /// In en, this message translates to:
  /// **'Open the latest release summary and relaunch the guided tour for your role.'**
  String get helpOpenLatestReleaseTourBody;

  /// No description provided for @helpPopularTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular tasks'**
  String get helpPopularTasksTitle;

  /// No description provided for @helpPopularTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The most useful guides for {role} right now.'**
  String helpPopularTasksSubtitle(String role);

  /// No description provided for @helpRoleBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Help for {role}'**
  String helpRoleBannerTitle(String role);

  /// No description provided for @helpStillStuckTitle.
  ///
  /// In en, this message translates to:
  /// **'Still stuck?'**
  String get helpStillStuckTitle;

  /// No description provided for @helpStillStuckBody.
  ///
  /// In en, this message translates to:
  /// **'Open troubleshooting first or contact support with the issue you are seeing right now.'**
  String get helpStillStuckBody;

  /// No description provided for @helpContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get helpContactSupport;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @settingsHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Account and workspace settings'**
  String get settingsHeroTitle;

  /// No description provided for @settingsHeroHelp.
  ///
  /// In en, this message translates to:
  /// **'Use Settings for account details, preferences, and support without losing focus on operations.'**
  String get settingsHeroHelp;

  /// No description provided for @settingsHeroAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile, business details, billing, and operational preferences from one place.'**
  String get settingsHeroAdminBody;

  /// No description provided for @settingsHeroStaffBody.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile, password, and notification preferences from one place.'**
  String get settingsHeroStaffBody;

  /// No description provided for @settingsPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesTitle;

  /// No description provided for @settingsPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved successfully!'**
  String get settingsPreferencesSaved;

  /// No description provided for @settingsPreferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save preferences: {error}'**
  String settingsPreferencesSaveFailed(String error);

  /// No description provided for @settingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileTitle;

  /// No description provided for @settingsProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account details and sign-in email.'**
  String get settingsProfileSubtitle;

  /// No description provided for @settingsBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get settingsBusinessTitle;

  /// No description provided for @settingsBusinessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Core organization details shown across the app.'**
  String get settingsBusinessSubtitle;

  /// No description provided for @settingsLocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get settingsLocationsTitle;

  /// No description provided for @settingsLocationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage where your team works and where shifts run.'**
  String get settingsLocationsSubtitle;

  /// No description provided for @settingsLocationsBody.
  ///
  /// In en, this message translates to:
  /// **'Add, review, or adjust locations tied to your organization.'**
  String get settingsLocationsBody;

  /// No description provided for @settingsLocationSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Please email us at support@planwithhands.com'**
  String get settingsLocationSupportEmail;

  /// No description provided for @settingsGuidedToursTitle.
  ///
  /// In en, this message translates to:
  /// **'Guided tours'**
  String get settingsGuidedToursTitle;

  /// No description provided for @settingsGuidedToursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay the in-app walkthrough for your current role whenever you need a refresher.'**
  String get settingsGuidedToursSubtitle;

  /// No description provided for @settingsReplayTour.
  ///
  /// In en, this message translates to:
  /// **'Replay {role} tour'**
  String settingsReplayTour(String role);

  /// No description provided for @settingsWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What’s new'**
  String get settingsWhatsNew;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password reset and session-related access controls.'**
  String get settingsSecuritySubtitle;

  /// No description provided for @settingsResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get settingsResetPassword;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get settingsSignedInAs;

  /// No description provided for @settingsOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get settingsOrganization;

  /// No description provided for @settingsSessionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Session Timeout'**
  String get settingsSessionTimeout;

  /// No description provided for @settingsSessionTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically log out after a period of inactivity'**
  String get settingsSessionTimeoutSubtitle;

  /// No description provided for @settingsSessionTimeoutDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsSessionTimeoutDone;

  /// No description provided for @settingsSessionTimeout2Hours.
  ///
  /// In en, this message translates to:
  /// **'2 Hours'**
  String get settingsSessionTimeout2Hours;

  /// No description provided for @settingsSessionTimeout2HoursBody.
  ///
  /// In en, this message translates to:
  /// **'High security - auto logout after 2 hours'**
  String get settingsSessionTimeout2HoursBody;

  /// No description provided for @settingsSessionTimeout4Hours.
  ///
  /// In en, this message translates to:
  /// **'4 Hours'**
  String get settingsSessionTimeout4Hours;

  /// No description provided for @settingsSessionTimeout4HoursBody.
  ///
  /// In en, this message translates to:
  /// **'Balanced security - auto logout after 4 hours'**
  String get settingsSessionTimeout4HoursBody;

  /// No description provided for @settingsSessionTimeout8Hours.
  ///
  /// In en, this message translates to:
  /// **'8 Hours'**
  String get settingsSessionTimeout8Hours;

  /// No description provided for @settingsSessionTimeout8HoursBody.
  ///
  /// In en, this message translates to:
  /// **'Recommended - good for work shifts'**
  String get settingsSessionTimeout8HoursBody;

  /// No description provided for @settingsSessionTimeout24Hours.
  ///
  /// In en, this message translates to:
  /// **'24 Hours'**
  String get settingsSessionTimeout24Hours;

  /// No description provided for @settingsSessionTimeout24HoursBody.
  ///
  /// In en, this message translates to:
  /// **'Extended access - logout after 1 day'**
  String get settingsSessionTimeout24HoursBody;

  /// No description provided for @settingsResetEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get settingsResetEmailInvalid;

  /// No description provided for @settingsResetEmailSentVerified.
  ///
  /// In en, this message translates to:
  /// **'Password reset sent to verified email {email}. Verify your new email to use it for login.'**
  String settingsResetEmailSentVerified(String email);

  /// No description provided for @settingsResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String settingsResetEmailSent(String email);

  /// No description provided for @settingsResetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email'**
  String get settingsResetEmailFailed;

  /// No description provided for @settingsResetEmailUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address'**
  String get settingsResetEmailUserNotFound;

  /// No description provided for @settingsResetEmailTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later'**
  String get settingsResetEmailTooManyRequests;

  /// No description provided for @settingsSummaryPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Select summary period'**
  String get settingsSummaryPeriodTitle;

  /// No description provided for @settingsSummaryPeriodCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar Day'**
  String get settingsSummaryPeriodCalendar;

  /// No description provided for @settingsSummaryPeriodCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tasks only (6am to 6am)'**
  String get settingsSummaryPeriodCalendarBody;

  /// No description provided for @settingsSummaryPeriodBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business Day'**
  String get settingsSummaryPeriodBusiness;

  /// No description provided for @settingsSummaryPeriodBusinessBody.
  ///
  /// In en, this message translates to:
  /// **'Includes last night\'s closing tasks'**
  String get settingsSummaryPeriodBusinessBody;

  /// No description provided for @settingsDailySummaryHourTitle.
  ///
  /// In en, this message translates to:
  /// **'Select daily summary hour'**
  String get settingsDailySummaryHourTitle;

  /// No description provided for @settingsDailySummaryFixedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes are fixed to :00'**
  String get settingsDailySummaryFixedMinutes;

  /// No description provided for @settingsOrganizationDailySummaryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Organization daily summary settings updated!'**
  String get settingsOrganizationDailySummaryUpdated;

  /// No description provided for @settingsOrganizationDailySummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save organization settings: {error}'**
  String settingsOrganizationDailySummaryFailed(String error);

  /// No description provided for @settingsDailySummaryEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Summary Email'**
  String get settingsDailySummaryEmailTitle;

  /// No description provided for @settingsDailySummaryEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive daily task completion summaries'**
  String get settingsDailySummaryEmailSubtitle;

  /// No description provided for @settingsDailySummaryTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Summary Time'**
  String get settingsDailySummaryTimeTitle;

  /// No description provided for @settingsDailySummaryTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When to receive your daily summary'**
  String get settingsDailySummaryTimeSubtitle;

  /// No description provided for @settingsDailySummaryRateLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Limit'**
  String get settingsDailySummaryRateLimitTitle;

  /// No description provided for @settingsDailySummaryChangeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot change the daily summary right now.'**
  String get settingsDailySummaryChangeBlocked;

  /// No description provided for @settingsDailySummaryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Time Change'**
  String get settingsDailySummaryConfirmTitle;

  /// No description provided for @settingsDailySummaryTimePassedTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Has Passed'**
  String get settingsDailySummaryTimePassedTitle;

  /// No description provided for @settingsDailySummaryProceedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Proceed with the time change?'**
  String get settingsDailySummaryProceedQuestion;

  /// No description provided for @settingsDailySummarySendNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Send now?'**
  String get settingsDailySummarySendNowTitle;

  /// No description provided for @settingsDailySummarySendNowBody.
  ///
  /// In en, this message translates to:
  /// **'Would you like to send today\'s summary immediately instead of waiting until tomorrow?'**
  String get settingsDailySummarySendNowBody;

  /// No description provided for @settingsDailySummarySendNowLater.
  ///
  /// In en, this message translates to:
  /// **'No, wait'**
  String get settingsDailySummarySendNowLater;

  /// No description provided for @settingsDailySummarySendNowAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, send now'**
  String get settingsDailySummarySendNowAction;

  /// No description provided for @settingsDailySummaryResultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get settingsDailySummaryResultSuccess;

  /// No description provided for @settingsDailySummaryResultError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get settingsDailySummaryResultError;

  /// No description provided for @settingsSummaryPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary Period'**
  String get settingsSummaryPeriodLabel;

  /// No description provided for @settingsSummaryPeriodLabelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose if summary includes late-night tasks'**
  String get settingsSummaryPeriodLabelSubtitle;

  /// No description provided for @settingsDashboardMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Metrics'**
  String get settingsDashboardMetricsTitle;

  /// No description provided for @settingsDashboardMetricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculate dashboard metrics from today'**
  String get settingsDashboardMetricsSubtitle;

  /// No description provided for @settingsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get settingsRefresh;

  /// No description provided for @settingsLoadingSubscriptionData.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription data...'**
  String get settingsLoadingSubscriptionData;

  /// No description provided for @settingsLoadingSubscriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription details...'**
  String get settingsLoadingSubscriptionDetails;

  /// No description provided for @settingsTrialEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Trial Ending Soon'**
  String get settingsTrialEndingSoon;

  /// No description provided for @settingsFreeTrialDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-Day Free Trial'**
  String settingsFreeTrialDays(int days);

  /// No description provided for @settingsTrialContinueUntil.
  ///
  /// In en, this message translates to:
  /// **'Your trial will continue until {date}, but you won\'t be charged.'**
  String settingsTrialContinueUntil(String date);

  /// No description provided for @settingsTrialChargeOn.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a {days}-day free trial. Your first charge will occur on {date} unless canceled.'**
  String settingsTrialChargeOn(String date, int days);

  /// No description provided for @settingsCancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get settingsCancelSubscription;

  /// No description provided for @settingsManageBilling.
  ///
  /// In en, this message translates to:
  /// **'Manage Billing'**
  String get settingsManageBilling;

  /// No description provided for @settingsBillingPortal.
  ///
  /// In en, this message translates to:
  /// **'Billing Portal'**
  String get settingsBillingPortal;

  /// No description provided for @settingsBillingPortalFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open billing portal: {error}'**
  String settingsBillingPortalFailed(String error);

  /// No description provided for @settingsTrialAndBilling.
  ///
  /// In en, this message translates to:
  /// **'Trial & Billing'**
  String get settingsTrialAndBilling;

  /// No description provided for @settingsSubscriptionManagement.
  ///
  /// In en, this message translates to:
  /// **'Subscription Management'**
  String get settingsSubscriptionManagement;

  /// No description provided for @settingsPlannedLocations.
  ///
  /// In en, this message translates to:
  /// **'Planned Locations:'**
  String get settingsPlannedLocations;

  /// No description provided for @settingsSubscribedLocations.
  ///
  /// In en, this message translates to:
  /// **'Subscribed Locations:'**
  String get settingsSubscribedLocations;

  /// No description provided for @settingsLocationsInUse.
  ///
  /// In en, this message translates to:
  /// **'Locations in Use:'**
  String get settingsLocationsInUse;

  /// No description provided for @settingsMonthlyCost.
  ///
  /// In en, this message translates to:
  /// **'Monthly Cost:'**
  String get settingsMonthlyCost;

  /// No description provided for @settingsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get settingsStatus;

  /// No description provided for @settingsSubscriptionOverUsage.
  ///
  /// In en, this message translates to:
  /// **'You\'re using more locations than your subscription allows. Please upgrade to avoid service interruption.'**
  String get settingsSubscriptionOverUsage;

  /// No description provided for @settingsAddBilling.
  ///
  /// In en, this message translates to:
  /// **'Add Billing'**
  String get settingsAddBilling;

  /// No description provided for @settingsManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get settingsManageSubscription;

  /// No description provided for @settingsBillingWebOnly.
  ///
  /// In en, this message translates to:
  /// **'To manage your subscription, please visit https://planwithhands.com and click \"Login\" on the top right. Subscriptions must be managed via the web portal.'**
  String get settingsBillingWebOnly;

  /// No description provided for @settingsBillingPortalWebOnly.
  ///
  /// In en, this message translates to:
  /// **'To manage billing, please open this page in Safari or Chrome and visit the billing portal. Subscriptions must be managed via the web portal.'**
  String get settingsBillingPortalWebOnly;

  /// No description provided for @settingsTalkToSales.
  ///
  /// In en, this message translates to:
  /// **'Talk to Sales'**
  String get settingsTalkToSales;

  /// No description provided for @settingsNoOrganizationFound.
  ///
  /// In en, this message translates to:
  /// **'No organization found. Please contact support.'**
  String get settingsNoOrganizationFound;

  /// No description provided for @settingsOrganizationInformation.
  ///
  /// In en, this message translates to:
  /// **'Organization Information'**
  String get settingsOrganizationInformation;

  /// No description provided for @settingsOrganizationLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization:'**
  String get settingsOrganizationLabel;

  /// No description provided for @settingsBusinessTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Type:'**
  String get settingsBusinessTypeLabel;

  /// No description provided for @settingsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsNotSet;

  /// No description provided for @settingsActiveLocations.
  ///
  /// In en, this message translates to:
  /// **'Active Locations:'**
  String get settingsActiveLocations;

  /// No description provided for @settingsNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get settingsNeedHelp;

  /// No description provided for @settingsSupportContactBody.
  ///
  /// In en, this message translates to:
  /// **'For subscription management, billing questions, or technical support, please contact us:'**
  String get settingsSupportContactBody;

  /// No description provided for @settingsSupportEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please email us at support@planwithhands.com'**
  String get settingsSupportEmailPrompt;

  /// No description provided for @settingsContactSalesBody.
  ///
  /// In en, this message translates to:
  /// **'For 5 or more locations, please contact our sales team for a customized plan.'**
  String get settingsContactSalesBody;

  /// No description provided for @settingsSubscriptionUpgraded.
  ///
  /// In en, this message translates to:
  /// **'Subscription upgraded!'**
  String get settingsSubscriptionUpgraded;

  /// No description provided for @settingsSubscriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscription updated!'**
  String get settingsSubscriptionUpdated;

  /// No description provided for @settingsSubscriptionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String settingsSubscriptionUpdateFailed(String error);

  /// No description provided for @settingsSubscriptionChangeIncrease.
  ///
  /// In en, this message translates to:
  /// **'increase'**
  String get settingsSubscriptionChangeIncrease;

  /// No description provided for @settingsSubscriptionChangeDecrease.
  ///
  /// In en, this message translates to:
  /// **'decrease'**
  String get settingsSubscriptionChangeDecrease;

  /// No description provided for @settingsUpgradeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Subscription'**
  String get settingsUpgradeSubscription;

  /// No description provided for @settingsDowngradeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Downgrade Subscription'**
  String get settingsDowngradeSubscription;

  /// No description provided for @settingsSubscriptionAboutToChange.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to {change} your location subscription:'**
  String settingsSubscriptionAboutToChange(String change);

  /// No description provided for @settingsFrom.
  ///
  /// In en, this message translates to:
  /// **'From:'**
  String get settingsFrom;

  /// No description provided for @settingsTo.
  ///
  /// In en, this message translates to:
  /// **'To:'**
  String get settingsTo;

  /// No description provided for @settingsLocationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} locations'**
  String settingsLocationsCount(int count);

  /// No description provided for @settingsMonthlyChange.
  ///
  /// In en, this message translates to:
  /// **'Monthly change:'**
  String get settingsMonthlyChange;

  /// No description provided for @settingsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get settingsPerMonth;

  /// No description provided for @settingsBillingEffectiveNextCycle.
  ///
  /// In en, this message translates to:
  /// **'New billing amount takes effect on your next billing cycle.'**
  String get settingsBillingEffectiveNextCycle;

  /// No description provided for @settingsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current:'**
  String get settingsCurrent;

  /// No description provided for @settingsInUse.
  ///
  /// In en, this message translates to:
  /// **'In use:'**
  String get settingsInUse;

  /// No description provided for @settingsCannotReduceBelow.
  ///
  /// In en, this message translates to:
  /// **'Cannot reduce below {currentUsage} (current usage). Delete locations first.'**
  String settingsCannotReduceBelow(int currentUsage);

  /// No description provided for @settingsNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No Changes'**
  String get settingsNoChanges;

  /// No description provided for @settingsUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get settingsUpgrade;

  /// No description provided for @settingsDowngrade.
  ///
  /// In en, this message translates to:
  /// **'Downgrade'**
  String get settingsDowngrade;

  /// No description provided for @settingsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get settingsStatusActive;

  /// No description provided for @settingsStatusTrial.
  ///
  /// In en, this message translates to:
  /// **'TRIAL'**
  String get settingsStatusTrial;

  /// No description provided for @settingsStatusPastDue.
  ///
  /// In en, this message translates to:
  /// **'PAST DUE'**
  String get settingsStatusPastDue;

  /// No description provided for @settingsStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'CANCELED'**
  String get settingsStatusCanceled;

  /// No description provided for @settingsStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'UNPAID'**
  String get settingsStatusUnpaid;

  /// No description provided for @settingsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get settingsStatusPending;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountTitle;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Device sign-out and irreversible account actions.'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This signs you out on this device and returns you to the login screen.'**
  String get settingsSignOutSubtitle;

  /// No description provided for @settingsSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get settingsSigningOut;

  /// No description provided for @settingsSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out: {error}'**
  String settingsSignOutFailed(String error);

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get settingsDeleteAccountWarningTitle;

  /// No description provided for @settingsDeleteAccountWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated personal data. This action CANNOT be undone.'**
  String get settingsDeleteAccountWarningBody;

  /// No description provided for @settingsDeleteAccountReinviteBody.
  ///
  /// In en, this message translates to:
  /// **'If you proceed and later want to use Hands again, you will need to receive a NEW INVITE from your administrator to re-sign up.'**
  String get settingsDeleteAccountReinviteBody;

  /// No description provided for @settingsDeleteAccountContinueQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you still want to continue?'**
  String get settingsDeleteAccountContinueQuestion;

  /// No description provided for @settingsDeleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get settingsDeleteAccountConfirmAction;

  /// No description provided for @settingsDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your data. This action cannot be undone.'**
  String get settingsDeleteAccountBody;

  /// No description provided for @settingsDeleteAccountPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password to confirm:'**
  String get settingsDeleteAccountPasswordPrompt;

  /// No description provided for @settingsDeleteAccountPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsDeleteAccountPasswordHint;

  /// No description provided for @settingsDeletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get settingsDeletingAccount;

  /// No description provided for @settingsDeleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get settingsDeleteAccountSuccess;

  /// No description provided for @settingsDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get settingsDeleteAccountFailed;

  /// No description provided for @settingsDeleteAccountWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get settingsDeleteAccountWrongPassword;

  /// No description provided for @settingsDeleteAccountRelogin.
  ///
  /// In en, this message translates to:
  /// **'Please log out and log back in, then try again.'**
  String get settingsDeleteAccountRelogin;

  /// No description provided for @settingsDeleteAccountTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later.'**
  String get settingsDeleteAccountTooManyRequests;

  /// No description provided for @settingsAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get settingsAddLocation;

  /// No description provided for @settingsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingsEdit;

  /// No description provided for @settingsFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get settingsFirstName;

  /// No description provided for @settingsLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get settingsLastName;

  /// No description provided for @settingsEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfileTitle;

  /// No description provided for @settingsEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your name and sign-in email.'**
  String get settingsEditProfileSubtitle;

  /// No description provided for @settingsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get settingsSaveChanges;

  /// No description provided for @settingsProfileSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to edit profile'**
  String get settingsProfileSignInRequired;

  /// No description provided for @settingsProfileSavedVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. Verify new email.'**
  String get settingsProfileSavedVerifyEmail;

  /// No description provided for @settingsProfileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get settingsProfileUpdatedSuccess;

  /// No description provided for @settingsProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get settingsProfileUpdateFailed;

  /// No description provided for @settingsProfileErrorReloginToChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Log out/in again to change email'**
  String get settingsProfileErrorReloginToChangeEmail;

  /// No description provided for @settingsProfileErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'Email already in use'**
  String get settingsProfileErrorEmailInUse;

  /// No description provided for @settingsProfileErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get settingsProfileErrorInvalidEmail;

  /// No description provided for @settingsFieldEnterFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get settingsFieldEnterFirstName;

  /// No description provided for @settingsFieldEnterLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get settingsFieldEnterLastName;

  /// No description provided for @settingsInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get settingsInvalidEmail;

  /// No description provided for @settingsBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get settingsBusinessName;

  /// No description provided for @settingsBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get settingsBusinessType;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// No description provided for @helpSupportRequest.
  ///
  /// In en, this message translates to:
  /// **'{role} support request'**
  String helpSupportRequest(String role);

  /// No description provided for @helpRolePageTitle.
  ///
  /// In en, this message translates to:
  /// **'{role} help'**
  String helpRolePageTitle(String role);

  /// No description provided for @helpTroubleshootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get helpTroubleshootingTitle;

  /// No description provided for @helpTroubleshootingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fix blockers fast by starting with the symptom you are seeing right now.'**
  String get helpTroubleshootingSubtitle;

  /// No description provided for @helpTroubleshootingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a problem like missing shift or wrong location'**
  String get helpTroubleshootingSearchHint;

  /// No description provided for @helpTroubleshootingIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting works best when you start with the exact symptom.'**
  String get helpTroubleshootingIntroTitle;

  /// No description provided for @helpTroubleshootingIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Check the active location, current role, and screen context first. A lot of issues are actually scoping or setup problems.'**
  String get helpTroubleshootingIntroBody;

  /// No description provided for @helpTroubleshootingCommonProblems.
  ///
  /// In en, this message translates to:
  /// **'Common problems'**
  String get helpTroubleshootingCommonProblems;

  /// No description provided for @helpTroubleshootingResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get helpTroubleshootingResults;

  /// No description provided for @helpTroubleshootingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No troubleshooting guides matched that search. Try a simpler symptom or contact support.'**
  String get helpTroubleshootingNoResults;

  /// No description provided for @helpNeedMoreHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need more help?'**
  String get helpNeedMoreHelpTitle;

  /// No description provided for @helpNeedMoreHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Send support the exact issue, location, and screen you were on. We will include the troubleshooting context automatically.'**
  String get helpNeedMoreHelpBody;

  /// No description provided for @helpTopicScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Help topic'**
  String get helpTopicScreenLabel;

  /// No description provided for @helpTopicMissingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'That topic could not be found.'**
  String get helpTopicMissingSubtitle;

  /// No description provided for @helpTopicMissingBody.
  ///
  /// In en, this message translates to:
  /// **'The guide you tried to open no longer exists or has not been added yet.'**
  String get helpTopicMissingBody;

  /// No description provided for @helpReturnToHelp.
  ///
  /// In en, this message translates to:
  /// **'Return to Help'**
  String get helpReturnToHelp;

  /// No description provided for @helpMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String helpMinutes(int count);

  /// No description provided for @helpWhyThisMatters.
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get helpWhyThisMatters;

  /// No description provided for @helpDoThisNow.
  ///
  /// In en, this message translates to:
  /// **'Do this now'**
  String get helpDoThisNow;

  /// No description provided for @helpWhatGoodLooksLike.
  ///
  /// In en, this message translates to:
  /// **'What good looks like'**
  String get helpWhatGoodLooksLike;

  /// No description provided for @helpCommonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get helpCommonMistakes;

  /// No description provided for @helpMoreRoleHelp.
  ///
  /// In en, this message translates to:
  /// **'More {role} help'**
  String helpMoreRoleHelp(String role);

  /// No description provided for @helpRelatedHelp.
  ///
  /// In en, this message translates to:
  /// **'Related help'**
  String get helpRelatedHelp;

  /// No description provided for @helpStartHerePageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A fast walkthrough of the essentials for your role so you can use the app without guesswork.'**
  String get helpStartHerePageSubtitle;

  /// No description provided for @helpFollowTheseSteps.
  ///
  /// In en, this message translates to:
  /// **'Follow these steps'**
  String get helpFollowTheseSteps;

  /// No description provided for @helpKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get helpKeepGoing;

  /// No description provided for @helpRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get helpRoleStaff;

  /// No description provided for @helpRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get helpRoleManager;

  /// No description provided for @helpRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get helpRoleAdmin;

  /// No description provided for @helpRoleStaffShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily work, shifts, tasks, and carryover'**
  String get helpRoleStaffShortDescription;

  /// No description provided for @helpRoleManagerShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily oversight, follow-up, and broadcasts'**
  String get helpRoleManagerShortDescription;

  /// No description provided for @helpRoleAdminShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Setup, workflows, team access, and operations'**
  String get helpRoleAdminShortDescription;

  /// No description provided for @helpCategoryDailyWork.
  ///
  /// In en, this message translates to:
  /// **'Daily Work'**
  String get helpCategoryDailyWork;

  /// No description provided for @helpCategoryDailyWorkDescription.
  ///
  /// In en, this message translates to:
  /// **'Get through your shift and finish tasks cleanly.'**
  String get helpCategoryDailyWorkDescription;

  /// No description provided for @helpCategoryOversight.
  ///
  /// In en, this message translates to:
  /// **'Daily Oversight'**
  String get helpCategoryOversight;

  /// No description provided for @helpCategoryOversightDescription.
  ///
  /// In en, this message translates to:
  /// **'Understand live service and respond to risks fast.'**
  String get helpCategoryOversightDescription;

  /// No description provided for @helpCategorySetup.
  ///
  /// In en, this message translates to:
  /// **'Operations Setup'**
  String get helpCategorySetup;

  /// No description provided for @helpCategorySetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the business in the right order.'**
  String get helpCategorySetupDescription;

  /// No description provided for @helpCategoryCommunications.
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get helpCategoryCommunications;

  /// No description provided for @helpCategoryCommunicationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the team aligned with inbox, broadcasts, and audiences.'**
  String get helpCategoryCommunicationsDescription;

  /// No description provided for @helpCategoryDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents & Training'**
  String get helpCategoryDocuments;

  /// No description provided for @helpCategoryDocumentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the Document Center for training, SOPs, and references.'**
  String get helpCategoryDocumentsDescription;

  /// No description provided for @helpCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & Access'**
  String get helpCategoryAccount;

  /// No description provided for @helpCategoryAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage sign-in, locations, access, and profile basics.'**
  String get helpCategoryAccountDescription;

  /// No description provided for @helpCategorySharedMode.
  ///
  /// In en, this message translates to:
  /// **'Shared Mode'**
  String get helpCategorySharedMode;

  /// No description provided for @helpCategorySharedModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use shared devices safely without losing control.'**
  String get helpCategorySharedModeDescription;

  /// No description provided for @helpCategoryTroubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get helpCategoryTroubleshooting;

  /// No description provided for @helpCategoryTroubleshootingDescription.
  ///
  /// In en, this message translates to:
  /// **'Fix blockers fast when work, access, or messages are missing.'**
  String get helpCategoryTroubleshootingDescription;

  /// No description provided for @helpCategoryOperationsControl.
  ///
  /// In en, this message translates to:
  /// **'Operations Control'**
  String get helpCategoryOperationsControl;

  /// No description provided for @helpCategoryOperationsControlDescription.
  ///
  /// In en, this message translates to:
  /// **'Run day-to-day operations and keep setup healthy over time.'**
  String get helpCategoryOperationsControlDescription;

  /// No description provided for @contactUsPrefillSubjectTopic.
  ///
  /// In en, this message translates to:
  /// **'Help with {topic}'**
  String contactUsPrefillSubjectTopic(String topic);

  /// No description provided for @contactUsPrefillSubjectIssue.
  ///
  /// In en, this message translates to:
  /// **'Help with {issue}'**
  String contactUsPrefillSubjectIssue(String issue);

  /// No description provided for @contactUsPrefillSubjectScreen.
  ///
  /// In en, this message translates to:
  /// **'Help on {screen}'**
  String contactUsPrefillSubjectScreen(String screen);

  /// No description provided for @contactUsPrefillSubjectDefault.
  ///
  /// In en, this message translates to:
  /// **'Support request'**
  String get contactUsPrefillSubjectDefault;

  /// No description provided for @contactUsPrefillPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please describe what happened, what you expected, and any error you saw.'**
  String get contactUsPrefillPrompt;

  /// No description provided for @contactUsPrefillContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get contactUsPrefillContextTitle;

  /// No description provided for @contactUsPrefillRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String contactUsPrefillRole(String role);

  /// No description provided for @contactUsPrefillHelpTopic.
  ///
  /// In en, this message translates to:
  /// **'Help topic: {topic}'**
  String contactUsPrefillHelpTopic(String topic);

  /// No description provided for @contactUsPrefillScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen: {screen}'**
  String contactUsPrefillScreen(String screen);

  /// No description provided for @contactUsPrefillLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String contactUsPrefillLocation(String location);

  /// No description provided for @contactUsPrefillIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue: {issue}'**
  String contactUsPrefillIssue(String issue);

  /// No description provided for @contactUsPrefillRoute.
  ///
  /// In en, this message translates to:
  /// **'Route: {route}'**
  String contactUsPrefillRoute(String route);

  /// No description provided for @contactUsSendRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a request'**
  String get contactUsSendRequestTitle;

  /// No description provided for @contactUsSendRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Keep it short and specific so we can help faster.'**
  String get contactUsSendRequestBody;

  /// No description provided for @contactUsAutoContextBody.
  ///
  /// In en, this message translates to:
  /// **'This request already includes your help topic, current screen, and active location so support can respond faster.'**
  String get contactUsAutoContextBody;

  /// No description provided for @contactUsSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get contactUsSubjectLabel;

  /// No description provided for @contactUsSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'What do you need help with?'**
  String get contactUsSubjectHint;

  /// No description provided for @contactUsMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactUsMessageLabel;

  /// No description provided for @contactUsMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue, what you expected, and what happened.'**
  String get contactUsMessageHint;

  /// No description provided for @contactUsEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get contactUsEmailRequired;

  /// No description provided for @contactUsValidEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get contactUsValidEmailRequired;

  /// No description provided for @contactUsSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Subject is required'**
  String get contactUsSubjectRequired;

  /// No description provided for @contactUsSubjectMinLength.
  ///
  /// In en, this message translates to:
  /// **'Subject must be at least 5 characters'**
  String get contactUsSubjectMinLength;

  /// No description provided for @contactUsMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Message is required'**
  String get contactUsMessageRequired;

  /// No description provided for @contactUsMessageMinLength.
  ///
  /// In en, this message translates to:
  /// **'Message must be at least 10 characters'**
  String get contactUsMessageMinLength;

  /// No description provided for @contactUsSendRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get contactUsSendRequestButton;

  /// No description provided for @contactUsUrgentIssueNote.
  ///
  /// In en, this message translates to:
  /// **'For urgent issues, include the location, affected shift, and any error message you saw.'**
  String get contactUsUrgentIssueNote;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document Center'**
  String get documentsTitle;

  /// No description provided for @documentsNoOrganization.
  ///
  /// In en, this message translates to:
  /// **'No organization found. Please contact support.'**
  String get documentsNoOrganization;

  /// No description provided for @documentsUploaded.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded'**
  String get documentsUploaded;

  /// No description provided for @documentsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Document updated'**
  String get documentsUpdated;

  /// No description provided for @documentsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get documentsDeleteTitle;

  /// No description provided for @documentsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this document? This action cannot be undone.'**
  String get documentsDeleteBody;

  /// No description provided for @documentsDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Document deleted successfully'**
  String get documentsDeletedSuccess;

  /// No description provided for @documentsDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting document: {error}'**
  String documentsDeleteError(String error);

  /// No description provided for @documentsAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize SOPs, training guides, and reference files for every location.'**
  String get documentsAdminSubtitle;

  /// No description provided for @documentsStaffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find the guides, policies, and reference materials you need for this shift.'**
  String get documentsStaffSubtitle;

  /// No description provided for @documentsHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Document Center for SOPs, training, and reference files that support work without cluttering task flows.'**
  String get documentsHelpSubtitle;

  /// No description provided for @documentsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get documentsUpload;

  /// No description provided for @documentsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title, category, or file name'**
  String get documentsSearchHint;

  /// No description provided for @documentsCurrentScope.
  ///
  /// In en, this message translates to:
  /// **'Current scope'**
  String get documentsCurrentScope;

  /// No description provided for @documentsAllLocations.
  ///
  /// In en, this message translates to:
  /// **'All Locations'**
  String get documentsAllLocations;

  /// No description provided for @documentsLocationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} locations'**
  String documentsLocationsCount(int count);

  /// No description provided for @documentsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading documents: {error}'**
  String documentsErrorLoading(String error);

  /// No description provided for @documentsVisibleFiles.
  ///
  /// In en, this message translates to:
  /// **'Visible files'**
  String get documentsVisibleFiles;

  /// No description provided for @documentsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get documentsCategories;

  /// No description provided for @documentsScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get documentsScope;

  /// No description provided for @documentsScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get documentsScopeAll;

  /// No description provided for @documentsScopeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get documentsScopeLocal;

  /// No description provided for @documentsBuildLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your document library'**
  String get documentsBuildLibraryTitle;

  /// No description provided for @documentsNoDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents available yet'**
  String get documentsNoDocumentsTitle;

  /// No description provided for @documentsBuildLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Upload SOPs, safety policies, equipment guides, and training files so your team has one clean source of truth.'**
  String get documentsBuildLibraryBody;

  /// No description provided for @documentsNoDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Your manager or admin will upload training guides, SOPs, and reference documents here.'**
  String get documentsNoDocumentsBody;

  /// No description provided for @documentsUploadFirst.
  ///
  /// In en, this message translates to:
  /// **'Upload first document'**
  String get documentsUploadFirst;

  /// No description provided for @documentsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No files matched \"{query}\" in the current scope.'**
  String documentsNoMatches(String query);

  /// No description provided for @documentsNoLocationDocs.
  ///
  /// In en, this message translates to:
  /// **'No documents are available in this location yet.'**
  String get documentsNoLocationDocs;

  /// No description provided for @documentsNoCategoryDocs.
  ///
  /// In en, this message translates to:
  /// **'No documents were found in {category}.'**
  String documentsNoCategoryDocs(String category);

  /// No description provided for @documentsNothingToShow.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get documentsNothingToShow;

  /// No description provided for @documentsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get documentsUntitled;

  /// No description provided for @documentsTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get documentsTypeVideo;

  /// No description provided for @documentsTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get documentsTypeImage;

  /// No description provided for @documentsTypeDoc.
  ///
  /// In en, this message translates to:
  /// **'Doc'**
  String get documentsTypeDoc;

  /// No description provided for @documentsGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get documentsGlobal;

  /// No description provided for @documentsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get documentsLocation;

  /// No description provided for @documentsEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get documentsEditTooltip;

  /// No description provided for @documentsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get documentsDeleteTooltip;

  /// No description provided for @documentsAddedDate.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String documentsAddedDate(String date);

  /// No description provided for @documentsOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open document. Please check your internet connection.'**
  String get documentsOpenError;

  /// No description provided for @documentsOpenErrorDetailed.
  ///
  /// In en, this message translates to:
  /// **'Error opening document: {error}'**
  String documentsOpenErrorDetailed(String error);

  /// No description provided for @documentsCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get documentsCategoryAll;

  /// No description provided for @documentsCategorySafetyProcedures.
  ///
  /// In en, this message translates to:
  /// **'Safety Procedures'**
  String get documentsCategorySafetyProcedures;

  /// No description provided for @documentsCategoryCleaningProtocols.
  ///
  /// In en, this message translates to:
  /// **'Cleaning Protocols'**
  String get documentsCategoryCleaningProtocols;

  /// No description provided for @documentsCategoryTrainingMaterials.
  ///
  /// In en, this message translates to:
  /// **'Training Materials'**
  String get documentsCategoryTrainingMaterials;

  /// No description provided for @documentsCategoryOperatingProcedures.
  ///
  /// In en, this message translates to:
  /// **'Operating Procedures'**
  String get documentsCategoryOperatingProcedures;

  /// No description provided for @documentsCategoryEmergencyProcedures.
  ///
  /// In en, this message translates to:
  /// **'Emergency Procedures'**
  String get documentsCategoryEmergencyProcedures;

  /// No description provided for @documentsCategoryEquipmentManuals.
  ///
  /// In en, this message translates to:
  /// **'Equipment Manuals'**
  String get documentsCategoryEquipmentManuals;

  /// No description provided for @documentsCategoryPolicyDocuments.
  ///
  /// In en, this message translates to:
  /// **'Policy Documents'**
  String get documentsCategoryPolicyDocuments;

  /// No description provided for @documentsCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get documentsCategoryOther;

  /// No description provided for @documentsViewerOpenExternalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open in external app'**
  String get documentsViewerOpenExternalTooltip;

  /// No description provided for @documentsViewerDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get documentsViewerDownloadTooltip;

  /// No description provided for @documentsViewerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading document...'**
  String get documentsViewerLoading;

  /// No description provided for @documentsViewerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error loading document'**
  String get documentsViewerErrorTitle;

  /// No description provided for @documentsViewerInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid document URL.'**
  String get documentsViewerInvalidUrl;

  /// No description provided for @documentsViewerDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download document.'**
  String get documentsViewerDownloadFailed;

  /// No description provided for @documentsViewerTestBrowser.
  ///
  /// In en, this message translates to:
  /// **'Test URL in Browser'**
  String get documentsViewerTestBrowser;

  /// No description provided for @documentsViewerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get documentsViewerRetry;

  /// No description provided for @documentsViewerNoPath.
  ///
  /// In en, this message translates to:
  /// **'No document path available'**
  String get documentsViewerNoPath;

  /// No description provided for @documentsViewerTrainingDocument.
  ///
  /// In en, this message translates to:
  /// **'Training Document'**
  String get documentsViewerTrainingDocument;

  /// No description provided for @documentsViewerNativeBody.
  ///
  /// In en, this message translates to:
  /// **'This document will open in your device\'s native viewer for the best experience.'**
  String get documentsViewerNativeBody;

  /// No description provided for @documentsViewerOpenDocument.
  ///
  /// In en, this message translates to:
  /// **'Open Document'**
  String get documentsViewerOpenDocument;

  /// No description provided for @documentsViewerNativeHelp.
  ///
  /// In en, this message translates to:
  /// **'Documents open in your device\'s built-in viewer for optimal performance and features.'**
  String get documentsViewerNativeHelp;

  /// No description provided for @documentsViewerPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get documentsViewerPdfTitle;

  /// No description provided for @documentsViewerOfficeTitle.
  ///
  /// In en, this message translates to:
  /// **'Office Document'**
  String get documentsViewerOfficeTitle;

  /// No description provided for @documentsViewerWebBody.
  ///
  /// In en, this message translates to:
  /// **'Click below to view or download this document'**
  String get documentsViewerWebBody;

  /// No description provided for @documentsViewerViewDocument.
  ///
  /// In en, this message translates to:
  /// **'View Document'**
  String get documentsViewerViewDocument;

  /// No description provided for @documentsViewerCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get documentsViewerCopyLink;

  /// No description provided for @documentsViewerTechnicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Technical Information'**
  String get documentsViewerTechnicalInfo;

  /// No description provided for @documentsViewerDocumentUrl.
  ///
  /// In en, this message translates to:
  /// **'Document URL:'**
  String get documentsViewerDocumentUrl;

  /// No description provided for @documentsViewerNewTabNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Documents open in a new tab due to browser security policies.'**
  String get documentsViewerNewTabNote;

  /// No description provided for @documentsViewerImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get documentsViewerImageFailed;

  /// No description provided for @documentsViewerPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview not available'**
  String get documentsViewerPreviewUnavailable;

  /// No description provided for @documentsViewerUnsupportedPreview.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported for preview'**
  String get documentsViewerUnsupportedPreview;

  /// No description provided for @documentsViewerOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in External App'**
  String get documentsViewerOpenExternal;

  /// No description provided for @documentsViewerUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get documentsViewerUrlCopied;

  /// No description provided for @documentsViewerCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy URL'**
  String get documentsViewerCopyFailed;

  /// No description provided for @documentsViewerVideoFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get documentsViewerVideoFailed;

  /// No description provided for @documentsViewerLoadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get documentsViewerLoadingVideo;

  /// No description provided for @documentsUploadSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentsUploadSheetTitle;

  /// No description provided for @documentsUploadSheetLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loading organization context...'**
  String get documentsUploadSheetLoadingSubtitle;

  /// No description provided for @documentsUploadSheetMissingOrgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We could not determine your organization.'**
  String get documentsUploadSheetMissingOrgSubtitle;

  /// No description provided for @documentsUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get documentsUploadTitle;

  /// No description provided for @documentsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit document'**
  String get documentsEditTitle;

  /// No description provided for @documentsUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add SOPs, policies, guides, and training files for the team.'**
  String get documentsUploadSubtitle;

  /// No description provided for @documentsLocationAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Document locations'**
  String get documentsLocationAccessTitle;

  /// No description provided for @documentsLocationAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Choose where this document appears in Document Center. Select one location or keep more than one selected if the file applies across sites.'**
  String get documentsLocationAccessBody;

  /// No description provided for @documentsLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one location for this document.'**
  String get documentsLocationRequired;

  /// No description provided for @documentsUploadNeedsLocation.
  ///
  /// In en, this message translates to:
  /// **'Add a location before uploading documents.'**
  String get documentsUploadNeedsLocation;

  /// No description provided for @documentsUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update document'**
  String get documentsUpdateButton;

  /// No description provided for @documentsInfoTip.
  ///
  /// In en, this message translates to:
  /// **'Upload PDFs, DOCX files, images, or videos up to 20 MB and place them in the right category.'**
  String get documentsInfoTip;

  /// No description provided for @documentsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get documentsDetails;

  /// No description provided for @documentsDocumentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Document title'**
  String get documentsDocumentTitleLabel;

  /// No description provided for @documentsDocumentTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear, descriptive title'**
  String get documentsDocumentTitleHint;

  /// No description provided for @documentsDocumentTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a document title'**
  String get documentsDocumentTitleRequired;

  /// No description provided for @documentsCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get documentsCategoryLabel;

  /// No description provided for @documentsCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get documentsCategoryRequired;

  /// No description provided for @documentsReplaceFileOptional.
  ///
  /// In en, this message translates to:
  /// **'Replace file (optional)'**
  String get documentsReplaceFileOptional;

  /// No description provided for @documentsSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get documentsSelectFile;

  /// No description provided for @documentsUnknownFile.
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get documentsUnknownFile;

  /// No description provided for @documentsChangeFile.
  ///
  /// In en, this message translates to:
  /// **'Change file'**
  String get documentsChangeFile;

  /// No description provided for @documentsTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select file'**
  String get documentsTapToSelect;

  /// No description provided for @documentsSupportedFileTypes.
  ///
  /// In en, this message translates to:
  /// **'PDF, DOCX, images, or video'**
  String get documentsSupportedFileTypes;

  /// No description provided for @documentsPickFileError.
  ///
  /// In en, this message translates to:
  /// **'Error picking file: {error}'**
  String documentsPickFileError(String error);

  /// No description provided for @documentsFillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get documentsFillRequiredFields;

  /// No description provided for @documentsSelectFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a file'**
  String get documentsSelectFileRequired;

  /// No description provided for @documentsMissingOrgId.
  ///
  /// In en, this message translates to:
  /// **'Organization ID is missing. Cannot upload document.'**
  String get documentsMissingOrgId;

  /// No description provided for @documentsUserNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated. Please log in again.'**
  String get documentsUserNotAuthenticated;

  /// No description provided for @documentsFileDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File data is not available. Please select the file again.'**
  String get documentsFileDataUnavailable;

  /// No description provided for @documentsUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Document updated successfully!'**
  String get documentsUpdatedSuccess;

  /// No description provided for @documentsUploadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded successfully!'**
  String get documentsUploadedSuccess;

  /// No description provided for @documentsUploadFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: '**
  String get documentsUploadFailedPrefix;

  /// No description provided for @documentsUploadFailedMissingData.
  ///
  /// In en, this message translates to:
  /// **'Missing required data. Please try selecting the file again.'**
  String get documentsUploadFailedMissingData;

  /// No description provided for @documentsUploadFailedPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Please check your account permissions.'**
  String get documentsUploadFailedPermission;

  /// No description provided for @documentsUploadFailedStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage error. Please check your internet connection.'**
  String get documentsUploadFailedStorage;

  /// No description provided for @documentsDismissTip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get documentsDismissTip;

  /// No description provided for @scheduleEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule Editor'**
  String get scheduleEditorTitle;

  /// No description provided for @scheduleMyTitle.
  ///
  /// In en, this message translates to:
  /// **'My Schedule'**
  String get scheduleMyTitle;

  /// No description provided for @scheduleOrganizationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Organization not found'**
  String get scheduleOrganizationNotFound;

  /// No description provided for @scheduleOrganizationLocationMissing.
  ///
  /// In en, this message translates to:
  /// **'Organization or location not set.'**
  String get scheduleOrganizationLocationMissing;

  /// No description provided for @scheduleLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get scheduleLocationLabel;

  /// No description provided for @schedulePickDateRange.
  ///
  /// In en, this message translates to:
  /// **'Pick a date range'**
  String get schedulePickDateRange;

  /// No description provided for @scheduleSelectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get scheduleSelectDateRange;

  /// No description provided for @scheduleNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 Days'**
  String get scheduleNext7Days;

  /// No description provided for @scheduleDaysWindow.
  ///
  /// In en, this message translates to:
  /// **'Days {start}-{end}'**
  String scheduleDaysWindow(int start, int end);

  /// No description provided for @scheduleSelectLocationAndDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select a location and date range to view schedule'**
  String get scheduleSelectLocationAndDateRange;

  /// No description provided for @schedulePublishSchedule.
  ///
  /// In en, this message translates to:
  /// **'Publish Schedule'**
  String get schedulePublishSchedule;

  /// No description provided for @scheduleCreateTemplateFirst.
  ///
  /// In en, this message translates to:
  /// **'Please create shift template first from admin dashboard'**
  String get scheduleCreateTemplateFirst;

  /// No description provided for @schedulePublishAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All schedules published successfully!'**
  String get schedulePublishAllSuccess;

  /// No description provided for @schedulePublishError.
  ///
  /// In en, this message translates to:
  /// **'Error publishing schedules: {error}'**
  String schedulePublishError(String error);

  /// No description provided for @scheduleDayPublished.
  ///
  /// In en, this message translates to:
  /// **'{date} schedule published!'**
  String scheduleDayPublished(String date);

  /// No description provided for @scheduleDayPublishError.
  ///
  /// In en, this message translates to:
  /// **'Error publishing schedule: {error}'**
  String scheduleDayPublishError(String error);

  /// No description provided for @scheduleNoPublishedShifts.
  ///
  /// In en, this message translates to:
  /// **'No published shifts.'**
  String get scheduleNoPublishedShifts;

  /// No description provided for @scheduleAssignedCount.
  ///
  /// In en, this message translates to:
  /// **'Assigned: {count}'**
  String scheduleAssignedCount(int count);

  /// No description provided for @scheduleUsersLabel.
  ///
  /// In en, this message translates to:
  /// **'Users: {users}'**
  String scheduleUsersLabel(String users);

  /// No description provided for @scheduleAssignedStatus.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get scheduleAssignedStatus;

  /// No description provided for @scheduleShiftsHeader.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get scheduleShiftsHeader;

  /// No description provided for @scheduleAssignedCell.
  ///
  /// In en, this message translates to:
  /// **'assigned'**
  String get scheduleAssignedCell;

  /// No description provided for @scheduleShiftTemplatesError.
  ///
  /// In en, this message translates to:
  /// **'Error loading shifts: {error}'**
  String scheduleShiftTemplatesError(String error);

  /// No description provided for @scheduleNoShiftTemplates.
  ///
  /// In en, this message translates to:
  /// **'No shift templates found for this location.\nCreate shift templates from the Admin Dashboard first.'**
  String get scheduleNoShiftTemplates;

  /// No description provided for @scheduleUnnamedShift.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Shift'**
  String get scheduleUnnamedShift;

  /// No description provided for @scheduleMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Schedule {start} to {end}'**
  String scheduleMessageTitle(String start, String end);

  /// No description provided for @scheduleMessageLine.
  ///
  /// In en, this message translates to:
  /// **'{date}: {shiftName} ({startTime} - {endTime})'**
  String scheduleMessageLine(
    String date,
    String shiftName,
    String startTime,
    String endTime,
  );

  /// No description provided for @dashboardSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get dashboardSwitch;

  /// No description provided for @dashboardLocationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} locations'**
  String dashboardLocationsCount(int count);

  /// No description provided for @dashboardNoActiveShift.
  ///
  /// In en, this message translates to:
  /// **'No Active Shift'**
  String get dashboardNoActiveShift;

  /// No description provided for @dashboardNothingAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is assigned right now'**
  String get dashboardNothingAssignedTitle;

  /// No description provided for @dashboardNothingAssignedBody.
  ///
  /// In en, this message translates to:
  /// **'You are set to work at {locationName}. Pick up an available shift when you are ready.'**
  String dashboardNothingAssignedBody(String locationName);

  /// No description provided for @dashboardSeeAvailableShifts.
  ///
  /// In en, this message translates to:
  /// **'See Available Shifts'**
  String get dashboardSeeAvailableShifts;

  /// No description provided for @dashboardNoVisibleShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'No visible shift right now'**
  String get dashboardNoVisibleShiftTitle;

  /// No description provided for @dashboardNoVisibleShiftBody.
  ///
  /// In en, this message translates to:
  /// **'Your assigned shifts may have ended, or your next shift is not yet available to start.'**
  String get dashboardNoVisibleShiftBody;

  /// No description provided for @dashboardMomentumBody.
  ///
  /// In en, this message translates to:
  /// **'Keep momentum moving when today\'s assigned work is in shape.'**
  String get dashboardMomentumBody;

  /// No description provided for @dashboardLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Loading today\'s tasks...'**
  String get dashboardLoadingTasks;

  /// No description provided for @dashboardNoTasksForShift.
  ///
  /// In en, this message translates to:
  /// **'No tasks are available for this shift yet.'**
  String get dashboardNoTasksForShift;

  /// No description provided for @dashboardEverythingCompleteShift.
  ///
  /// In en, this message translates to:
  /// **'Everything for this shift is complete.'**
  String get dashboardEverythingCompleteShift;

  /// No description provided for @dashboardTasksLeftShort.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String dashboardTasksLeftShort(int count);

  /// No description provided for @dashboardBlockedShort.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String dashboardBlockedShort(int count);

  /// No description provided for @dashboardNeedPhotosShort.
  ///
  /// In en, this message translates to:
  /// **'{count} need photos'**
  String dashboardNeedPhotosShort(int count);

  /// No description provided for @dashboardProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get dashboardProgress;

  /// No description provided for @dashboardWaitingForTasks.
  ///
  /// In en, this message translates to:
  /// **'Waiting for tasks'**
  String get dashboardWaitingForTasks;

  /// No description provided for @dashboardCompletedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} done'**
  String dashboardCompletedOfTotal(int completed, int total);

  /// No description provided for @dashboardRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get dashboardRemaining;

  /// No description provided for @dashboardTasksLeftInShift.
  ///
  /// In en, this message translates to:
  /// **'Tasks left in this shift'**
  String get dashboardTasksLeftInShift;

  /// No description provided for @dashboardAttention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get dashboardAttention;

  /// No description provided for @dashboardPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get dashboardPhotos;

  /// No description provided for @dashboardBlockedOrFlagged.
  ///
  /// In en, this message translates to:
  /// **'Blocked or flagged'**
  String get dashboardBlockedOrFlagged;

  /// No description provided for @dashboardNeedPhotoProof.
  ///
  /// In en, this message translates to:
  /// **'Need photo proof'**
  String get dashboardNeedPhotoProof;

  /// No description provided for @dashboardReviewTodaysWork.
  ///
  /// In en, this message translates to:
  /// **'Review Today\'s Work'**
  String get dashboardReviewTodaysWork;

  /// No description provided for @dashboardContinueWorking.
  ///
  /// In en, this message translates to:
  /// **'Continue Working'**
  String get dashboardContinueWorking;

  /// No description provided for @dashboardViewFullShift.
  ///
  /// In en, this message translates to:
  /// **'View Full Shift'**
  String get dashboardViewFullShift;

  /// No description provided for @dashboardNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get dashboardNextUp;

  /// No description provided for @dashboardNoRemainingTasks.
  ///
  /// In en, this message translates to:
  /// **'No remaining tasks in this shift right now.'**
  String get dashboardNoRemainingTasks;

  /// No description provided for @dashboardFastestPath.
  ///
  /// In en, this message translates to:
  /// **'The fastest path to finishing this shift.'**
  String get dashboardFastestPath;

  /// No description provided for @dashboardNextUpHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Next Up shows the fastest path through the unfinished tasks in your current shift.'**
  String get dashboardNextUpHelpSubtitle;

  /// No description provided for @dashboardQueuedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} queued'**
  String dashboardQueuedCount(int count);

  /// No description provided for @dashboardNoTasksAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks available yet'**
  String get dashboardNoTasksAvailableYet;

  /// No description provided for @dashboardCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re caught up on this shift'**
  String get dashboardCaughtUp;

  /// No description provided for @dashboardCheckChecklistSetup.
  ///
  /// In en, this message translates to:
  /// **'If this looks wrong, ask your manager to check this shift\'s checklist setup.'**
  String get dashboardCheckChecklistSetup;

  /// No description provided for @dashboardReviewCompletedOrPickShift.
  ///
  /// In en, this message translates to:
  /// **'Use the section below to review completed work or pick up another shift.'**
  String get dashboardReviewCompletedOrPickShift;

  /// No description provided for @dashboardCurrentShift.
  ///
  /// In en, this message translates to:
  /// **'Current Shift'**
  String get dashboardCurrentShift;

  /// No description provided for @dashboardLeaveShift.
  ///
  /// In en, this message translates to:
  /// **'Leave shift'**
  String get dashboardLeaveShift;

  /// No description provided for @dashboardPendingTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String dashboardPendingTasksRemaining(int count);

  /// No description provided for @dashboardListsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lists'**
  String dashboardListsCount(int count);

  /// No description provided for @dashboardNoTasksAvailableForShift.
  ///
  /// In en, this message translates to:
  /// **'No tasks available for this shift'**
  String get dashboardNoTasksAvailableForShift;

  /// No description provided for @dashboardAskManagerVerifyChecklist.
  ///
  /// In en, this message translates to:
  /// **'If this seems wrong, ask your manager to verify today\'s checklist setup.'**
  String get dashboardAskManagerVerifyChecklist;

  /// No description provided for @dashboardChecklistFallback.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get dashboardChecklistFallback;

  /// No description provided for @dashboardChecklistTasksLoading.
  ///
  /// In en, this message translates to:
  /// **'Tasks are loading for this checklist'**
  String get dashboardChecklistTasksLoading;

  /// No description provided for @dashboardChecklistCompletedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} tasks complete'**
  String dashboardChecklistCompletedOfTotal(int completed, int total);

  /// No description provided for @dashboardNeedPhotoChip.
  ///
  /// In en, this message translates to:
  /// **'{count} need photo'**
  String dashboardNeedPhotoChip(int count);

  /// No description provided for @dashboardEverythingHereComplete.
  ///
  /// In en, this message translates to:
  /// **'Everything here is complete'**
  String get dashboardEverythingHereComplete;

  /// No description provided for @dashboardCompletedBelow.
  ///
  /// In en, this message translates to:
  /// **'Completed work is tucked below for quick review.'**
  String get dashboardCompletedBelow;

  /// No description provided for @dashboardHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed ({count})'**
  String dashboardHideCompleted(int count);

  /// No description provided for @dashboardShowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Show completed ({count})'**
  String dashboardShowCompleted(int count);

  /// No description provided for @dashboardNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention: {reason}'**
  String dashboardNeedsAttention(String reason);

  /// No description provided for @dashboardPhotoRequiredBeforeSignoff.
  ///
  /// In en, this message translates to:
  /// **'Photo required before sign-off'**
  String get dashboardPhotoRequiredBeforeSignoff;

  /// No description provided for @dashboardReadyToComplete.
  ///
  /// In en, this message translates to:
  /// **'Ready to complete'**
  String get dashboardReadyToComplete;

  /// No description provided for @dashboardMustBeLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to complete tasks'**
  String get dashboardMustBeLoggedIn;

  /// No description provided for @dashboardPhotoRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo required'**
  String get dashboardPhotoRequiredTitle;

  /// No description provided for @dashboardPhotoRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This task requires a photo. Add a photo now, complete without a photo, or cancel.'**
  String get dashboardPhotoRequiredBody;

  /// No description provided for @dashboardCompleteWithoutPhoto.
  ///
  /// In en, this message translates to:
  /// **'Complete without photo'**
  String get dashboardCompleteWithoutPhoto;

  /// No description provided for @dashboardAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get dashboardAddPhoto;

  /// No description provided for @dashboardAddNoteRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Add note (required)'**
  String get dashboardAddNoteRequiredTitle;

  /// No description provided for @dashboardAddNoteRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Please add a brief note explaining why no photo was added.'**
  String get dashboardAddNoteRequiredBody;

  /// No description provided for @dashboardEnterNote.
  ///
  /// In en, this message translates to:
  /// **'Enter note...'**
  String get dashboardEnterNote;

  /// No description provided for @dashboardSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dashboardSave;

  /// No description provided for @dashboardTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed!'**
  String get dashboardTaskCompleted;

  /// No description provided for @dashboardTaskUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Task unchecked'**
  String get dashboardTaskUnchecked;

  /// No description provided for @dashboardTaskUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating task. Please try again.'**
  String get dashboardTaskUpdateError;

  /// No description provided for @dashboardCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dashboardCompleted;

  /// No description provided for @dashboardCompletedBy.
  ///
  /// In en, this message translates to:
  /// **'Completed by {name}'**
  String dashboardCompletedBy(String name);

  /// No description provided for @dashboardPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get dashboardPhotoAdded;

  /// No description provided for @dashboardPhotoRequiredChip.
  ///
  /// In en, this message translates to:
  /// **'Photo required'**
  String get dashboardPhotoRequiredChip;

  /// No description provided for @dashboardNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added'**
  String get dashboardNoteAdded;

  /// No description provided for @dashboardBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get dashboardBlocked;

  /// No description provided for @dashboardPhotoMenu.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get dashboardPhotoMenu;

  /// No description provided for @dashboardNotesMenu.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get dashboardNotesMenu;

  /// No description provided for @dashboardCannotComplete.
  ///
  /// In en, this message translates to:
  /// **'Cannot Complete'**
  String get dashboardCannotComplete;

  /// No description provided for @dashboardMarkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Incomplete'**
  String get dashboardMarkIncomplete;

  /// No description provided for @dashboardComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get dashboardComplete;

  /// No description provided for @dashboardViewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get dashboardViewPhoto;

  /// No description provided for @dashboardUpdateIssue.
  ///
  /// In en, this message translates to:
  /// **'Update Issue'**
  String get dashboardUpdateIssue;

  /// No description provided for @dashboardCantDo.
  ///
  /// In en, this message translates to:
  /// **'Can\'t Do'**
  String get dashboardCantDo;

  /// No description provided for @dashboardEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get dashboardEditNote;

  /// No description provided for @dashboardAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get dashboardAddNote;

  /// No description provided for @dashboardSwitchLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Location'**
  String get dashboardSwitchLocationTitle;

  /// No description provided for @dashboardSwitchLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Choose where you want to view and complete work.'**
  String get dashboardSwitchLocationBody;

  /// No description provided for @dashboardUnnamedLocation.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Location'**
  String get dashboardUnnamedLocation;

  /// No description provided for @dashboardCurrentlySelectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Currently selected'**
  String get dashboardCurrentlySelectedLocation;

  /// No description provided for @dashboardSwitchLocationError.
  ///
  /// In en, this message translates to:
  /// **'Could not switch locations. Please try again.'**
  String get dashboardSwitchLocationError;

  /// No description provided for @dashboardMissedTaskNotCompletedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Not completed yesterday'**
  String get dashboardMissedTaskNotCompletedYesterday;

  /// No description provided for @dashboardNoteChip.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get dashboardNoteChip;

  /// No description provided for @dashboardReasonChip.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get dashboardReasonChip;

  /// No description provided for @dashboardClearNotes.
  ///
  /// In en, this message translates to:
  /// **'Clear Notes'**
  String get dashboardClearNotes;

  /// No description provided for @dashboardClearReason.
  ///
  /// In en, this message translates to:
  /// **'Clear Reason'**
  String get dashboardClearReason;

  /// No description provided for @dashboardAlreadySignedUpForShift.
  ///
  /// In en, this message translates to:
  /// **'You are already signed up for {shiftName}.'**
  String dashboardAlreadySignedUpForShift(String shiftName);

  /// No description provided for @dashboardJoinedShift.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined {shiftName}!'**
  String dashboardJoinedShift(String shiftName);

  /// No description provided for @dashboardJoinShiftError.
  ///
  /// In en, this message translates to:
  /// **'Error joining shift. Please try again.'**
  String get dashboardJoinShiftError;

  /// No description provided for @dashboardMustBeLoggedInToLeaveShift.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to leave shifts'**
  String get dashboardMustBeLoggedInToLeaveShift;

  /// No description provided for @dashboardLeaveVolunteerShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Volunteer Shift'**
  String get dashboardLeaveVolunteerShiftTitle;

  /// No description provided for @dashboardLeaveVolunteerShiftBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the \"{shiftName}\" volunteer shift? This will remove you from future assignments for this shift.'**
  String dashboardLeaveVolunteerShiftBody(String shiftName);

  /// No description provided for @dashboardLeaveShiftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave Shift'**
  String get dashboardLeaveShiftConfirm;

  /// No description provided for @dashboardLeftVolunteerShift.
  ///
  /// In en, this message translates to:
  /// **'Successfully left volunteer shift!'**
  String get dashboardLeftVolunteerShift;

  /// No description provided for @dashboardLeaveShiftError.
  ///
  /// In en, this message translates to:
  /// **'Error leaving shift. Please try again.'**
  String get dashboardLeaveShiftError;

  /// No description provided for @dashboardAvailableShiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available shifts'**
  String get dashboardAvailableShiftsTitle;

  /// No description provided for @dashboardAvailableShiftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a shift to begin working at {locationName}'**
  String dashboardAvailableShiftsSubtitle(String locationName);

  /// No description provided for @dashboardAvailableShiftsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading shifts'**
  String get dashboardAvailableShiftsLoadError;

  /// No description provided for @dashboardNoAvailableShiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'No available shifts'**
  String get dashboardNoAvailableShiftsTitle;

  /// No description provided for @dashboardNoAvailableShiftsBody.
  ///
  /// In en, this message translates to:
  /// **'There are no shifts available for you to join today.'**
  String get dashboardNoAvailableShiftsBody;

  /// No description provided for @dashboardNoAvailableShiftsTiming.
  ///
  /// In en, this message translates to:
  /// **'Shifts will become available to select 30 minutes before their start time.'**
  String get dashboardNoAvailableShiftsTiming;

  /// No description provided for @dashboardJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get dashboardJoin;

  /// No description provided for @dashboardTaskNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Notes'**
  String get dashboardTaskNotesTitle;

  /// No description provided for @dashboardTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'Task: {taskName}'**
  String dashboardTaskLabel(String taskName);

  /// No description provided for @dashboardUnknownTask.
  ///
  /// In en, this message translates to:
  /// **'Unknown Task'**
  String get dashboardUnknownTask;

  /// No description provided for @dashboardTaskNotesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add notes or comments about this task:'**
  String get dashboardTaskNotesPrompt;

  /// No description provided for @dashboardNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved successfully!'**
  String get dashboardNotesSaved;

  /// No description provided for @dashboardNotesSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving notes: {error}'**
  String dashboardNotesSaveError(String error);

  /// No description provided for @dashboardNotesCleared.
  ///
  /// In en, this message translates to:
  /// **'Notes cleared'**
  String get dashboardNotesCleared;

  /// No description provided for @dashboardNotesClearError.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear notes: {error}'**
  String dashboardNotesClearError(String error);

  /// No description provided for @dashboardSaveNotes.
  ///
  /// In en, this message translates to:
  /// **'Save Notes'**
  String get dashboardSaveNotes;

  /// No description provided for @dashboardEnterNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your notes here...'**
  String get dashboardEnterNotesHint;

  /// No description provided for @dashboardSavingNotes.
  ///
  /// In en, this message translates to:
  /// **'Saving notes...'**
  String get dashboardSavingNotes;

  /// No description provided for @dashboardPhotoViewerResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get dashboardPhotoViewerResetZoom;

  /// No description provided for @dashboardPhotoViewerLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Loading image...'**
  String get dashboardPhotoViewerLoadingImage;

  /// No description provided for @dashboardPhotoViewerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get dashboardPhotoViewerLoadError;

  /// No description provided for @dashboardPhotoViewerGestureHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom • Drag to pan • Tap reset to fit screen'**
  String get dashboardPhotoViewerGestureHint;

  /// No description provided for @dashboardReasonEquipmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Equipment not available'**
  String get dashboardReasonEquipmentUnavailable;

  /// No description provided for @dashboardReasonSuppliesMissing.
  ///
  /// In en, this message translates to:
  /// **'Supplies missing'**
  String get dashboardReasonSuppliesMissing;

  /// No description provided for @dashboardReasonNotEnoughTime.
  ///
  /// In en, this message translates to:
  /// **'Not enough time'**
  String get dashboardReasonNotEnoughTime;

  /// No description provided for @dashboardReasonSafetyConcern.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get dashboardReasonSafetyConcern;

  /// No description provided for @dashboardReasonWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get dashboardReasonWaitingApproval;

  /// No description provided for @dashboardReasonAreaBlocked.
  ///
  /// In en, this message translates to:
  /// **'Area blocked/inaccessible'**
  String get dashboardReasonAreaBlocked;

  /// No description provided for @dashboardReasonTechnicalIssue.
  ///
  /// In en, this message translates to:
  /// **'Technical issue'**
  String get dashboardReasonTechnicalIssue;

  /// No description provided for @dashboardReasonStaffShortage.
  ///
  /// In en, this message translates to:
  /// **'Staff shortage'**
  String get dashboardReasonStaffShortage;

  /// No description provided for @dashboardReasonEmergencyPriority.
  ///
  /// In en, this message translates to:
  /// **'Emergency priority task'**
  String get dashboardReasonEmergencyPriority;

  /// No description provided for @dashboardReasonWeatherConditions.
  ///
  /// In en, this message translates to:
  /// **'Weather conditions'**
  String get dashboardReasonWeatherConditions;

  /// No description provided for @dashboardReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other (specify below)'**
  String get dashboardReasonOther;

  /// No description provided for @dashboardReasonSpecifyText.
  ///
  /// In en, this message translates to:
  /// **'Please specify a reason in the text field'**
  String get dashboardReasonSpecifyText;

  /// No description provided for @dashboardReasonSelectOrEnter.
  ///
  /// In en, this message translates to:
  /// **'Please select or enter a reason'**
  String get dashboardReasonSelectOrEnter;

  /// No description provided for @dashboardReasonSaved.
  ///
  /// In en, this message translates to:
  /// **'Reason saved successfully!'**
  String get dashboardReasonSaved;

  /// No description provided for @dashboardReasonSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving reason: {error}'**
  String dashboardReasonSaveError(String error);

  /// No description provided for @dashboardTaskNotCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Not Completed'**
  String get dashboardTaskNotCompletedTitle;

  /// No description provided for @dashboardSaveReason.
  ///
  /// In en, this message translates to:
  /// **'Save Reason'**
  String get dashboardSaveReason;

  /// No description provided for @dashboardTaskNotCompletedPrompt.
  ///
  /// In en, this message translates to:
  /// **'Why was this task not completed?'**
  String get dashboardTaskNotCompletedPrompt;

  /// No description provided for @dashboardEnterReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Please specify the reason...'**
  String get dashboardEnterReasonHint;

  /// No description provided for @dashboardSavingReason.
  ///
  /// In en, this message translates to:
  /// **'Saving reason...'**
  String get dashboardSavingReason;

  /// No description provided for @dashboardLoadingCarryover.
  ///
  /// In en, this message translates to:
  /// **'Loading carryover...'**
  String get dashboardLoadingCarryover;

  /// No description provided for @dashboardCurrentLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get dashboardCurrentLocationLabel;

  /// No description provided for @dashboardWorkingLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Working Location'**
  String get dashboardWorkingLocationLabel;

  /// No description provided for @dashboardLocationHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Location help'**
  String get dashboardLocationHelpTitle;

  /// No description provided for @dashboardLocationHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The active location controls which shifts, tasks, and documents you see on this page.'**
  String get dashboardLocationHelpSubtitle;

  /// No description provided for @dashboardSharedModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared Mode'**
  String get dashboardSharedModeTitle;

  /// No description provided for @dashboardSharedModeLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked — select your name to continue'**
  String get dashboardSharedModeLocked;

  /// No description provided for @dashboardSharedModeActive.
  ///
  /// In en, this message translates to:
  /// **'Active: {userName}'**
  String dashboardSharedModeActive(String userName);

  /// No description provided for @dashboardCarryoverClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Carryover is clear'**
  String get dashboardCarryoverClearTitle;

  /// No description provided for @dashboardCarryoverClearBody.
  ///
  /// In en, this message translates to:
  /// **'No missed tasks from yesterday.'**
  String get dashboardCarryoverClearBody;

  /// No description provided for @dashboardCarryoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Carryover from Yesterday'**
  String get dashboardCarryoverTitle;

  /// No description provided for @dashboardCarryoverHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Carryover from Yesterday'**
  String get dashboardCarryoverHelpTitle;

  /// No description provided for @dashboardCarryoverHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Carryover keeps unfinished work visible so it can be completed or blocked with context instead of disappearing.'**
  String get dashboardCarryoverHelpSubtitle;

  /// No description provided for @dashboardTasksCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} tasks completed'**
  String dashboardTasksCompletedCount(int completed, int total);

  /// No description provided for @dashboardShiftTaskSummary.
  ///
  /// In en, this message translates to:
  /// **'{shiftCount} {shiftCount, plural, one {shift} other {shifts}} • {taskCount} {taskCount, plural, one {task} other {tasks}}'**
  String dashboardShiftTaskSummary(int shiftCount, int taskCount);

  /// No description provided for @dashboardUnknownShift.
  ///
  /// In en, this message translates to:
  /// **'Unknown Shift'**
  String get dashboardUnknownShift;

  /// No description provided for @dashboardShiftTimingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get dashboardShiftTimingScheduled;

  /// No description provided for @dashboardShiftTimingCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Check timing details'**
  String get dashboardShiftTimingCheckDetails;

  /// No description provided for @dashboardShiftTimingStartsSoon.
  ///
  /// In en, this message translates to:
  /// **'Starts Soon'**
  String get dashboardShiftTimingStartsSoon;

  /// No description provided for @dashboardShiftTimingAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get dashboardShiftTimingAvailableNow;

  /// No description provided for @dashboardShiftTimingAvailableInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Available in {minutes}m'**
  String dashboardShiftTimingAvailableInMinutes(int minutes);

  /// No description provided for @dashboardShiftTimingInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get dashboardShiftTimingInProgress;

  /// No description provided for @dashboardShiftTimingHoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String dashboardShiftTimingHoursLeft(int hours);

  /// No description provided for @dashboardShiftTimingMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String dashboardShiftTimingMinutesLeft(int minutes);

  /// No description provided for @dashboardShiftTimingGracePeriod.
  ///
  /// In en, this message translates to:
  /// **'Grace Period'**
  String get dashboardShiftTimingGracePeriod;

  /// No description provided for @dashboardShiftTimingJustEnded.
  ///
  /// In en, this message translates to:
  /// **'Shift just ended'**
  String get dashboardShiftTimingJustEnded;

  /// No description provided for @dashboardShiftTimingEndedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Ended {minutes}m ago'**
  String dashboardShiftTimingEndedMinutesAgo(int minutes);

  /// No description provided for @dashboardShiftTimingCheckCurrentWork.
  ///
  /// In en, this message translates to:
  /// **'Check current work'**
  String get dashboardShiftTimingCheckCurrentWork;

  /// No description provided for @dashboardTourLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with the active location'**
  String get dashboardTourLocationTitle;

  /// No description provided for @dashboardTourLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Tasks, shifts, carryover, broadcasts, and documents all follow the selected location. Switch here before you start working.'**
  String get dashboardTourLocationDescription;

  /// No description provided for @dashboardTourShiftLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your shift summary first'**
  String get dashboardTourShiftLiveTitle;

  /// No description provided for @dashboardTourShiftIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'This is where your shift status appears'**
  String get dashboardTourShiftIdleTitle;

  /// No description provided for @dashboardTourShiftLiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Your shift hero shows what shift you are on, how much work is left, and whether anything is blocked or waiting for proof.'**
  String get dashboardTourShiftLiveDescription;

  /// No description provided for @dashboardTourShiftIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'If you have no live shift yet, this area tells you whether to wait, pick up another shift, or ask your manager to check setup.'**
  String get dashboardTourShiftIdleDescription;

  /// No description provided for @dashboardTourNextUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Next Up as your main work queue'**
  String get dashboardTourNextUpTitle;

  /// No description provided for @dashboardTourNextUpDescription.
  ///
  /// In en, this message translates to:
  /// **'Next Up surfaces the fastest path through unfinished work so you do not have to scan every checklist manually.'**
  String get dashboardTourNextUpDescription;

  /// No description provided for @dashboardTourTodaysWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'Review full checklists in Today\'s Work'**
  String get dashboardTourTodaysWorkTitle;

  /// No description provided for @dashboardTourTodaysWorkDescription.
  ///
  /// In en, this message translates to:
  /// **'Use this section when you need the full checklist view for your shift, completed tasks, or deeper task context beyond the top queue.'**
  String get dashboardTourTodaysWorkDescription;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @managerDashboardActiveShifts.
  ///
  /// In en, this message translates to:
  /// **'Active shifts'**
  String get managerDashboardActiveShifts;

  /// No description provided for @managerDashboardActiveShiftLiveNowOne.
  ///
  /// In en, this message translates to:
  /// **'1 shift live now'**
  String get managerDashboardActiveShiftLiveNowOne;

  /// No description provided for @managerDashboardActiveShiftLiveNowOther.
  ///
  /// In en, this message translates to:
  /// **'{count} shifts live now'**
  String managerDashboardActiveShiftLiveNowOther(int count);

  /// No description provided for @managerDashboardAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At risk'**
  String get managerDashboardAtRisk;

  /// No description provided for @managerDashboardNoShiftsSlipping.
  ///
  /// In en, this message translates to:
  /// **'No shifts slipping'**
  String get managerDashboardNoShiftsSlipping;

  /// No description provided for @managerDashboardNeedInterventionNow.
  ///
  /// In en, this message translates to:
  /// **'Need intervention now'**
  String get managerDashboardNeedInterventionNow;

  /// No description provided for @managerDashboardOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get managerDashboardOpenTasks;

  /// No description provided for @managerDashboardNoTrackedTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tracked tasks yet'**
  String get managerDashboardNoTrackedTasksYet;

  /// No description provided for @managerDashboardCompletedTracked.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} complete'**
  String managerDashboardCompletedTracked(int completed, int total);

  /// No description provided for @managerDashboardCarryover.
  ///
  /// In en, this message translates to:
  /// **'Carryover'**
  String get managerDashboardCarryover;

  /// No description provided for @managerDashboardYesterdayFinishedCleanly.
  ///
  /// In en, this message translates to:
  /// **'Yesterday finished cleanly'**
  String get managerDashboardYesterdayFinishedCleanly;

  /// No description provided for @managerDashboardShiftsAffected.
  ///
  /// In en, this message translates to:
  /// **'{count} shifts affected'**
  String managerDashboardShiftsAffected(int count);

  /// No description provided for @managerDashboardTourSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with the summary card'**
  String get managerDashboardTourSummaryTitle;

  /// No description provided for @managerDashboardTourSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'This top card tells you whether service is on track, how many shifts are at risk, and what needs your attention right now.'**
  String get managerDashboardTourSummaryDescription;

  /// No description provided for @managerDashboardTourIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Today at Risk as your action queue'**
  String get managerDashboardTourIssuesTitle;

  /// No description provided for @managerDashboardTourIssuesDescription.
  ///
  /// In en, this message translates to:
  /// **'Open these issues first when something slips. They help you prioritize missed work, live risks, and the next follow-up.'**
  String get managerDashboardTourIssuesDescription;

  /// No description provided for @managerDashboardTourReadinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Readiness shows the live board'**
  String get managerDashboardTourReadinessTitle;

  /// No description provided for @managerDashboardTourReadinessDescription.
  ///
  /// In en, this message translates to:
  /// **'Use this section to inspect open work, shift progress, and which runs are healthy versus drifting behind.'**
  String get managerDashboardTourReadinessDescription;

  /// No description provided for @managerDashboardCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get managerDashboardCurrentLocation;

  /// No description provided for @managerDashboardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading dashboard'**
  String get managerDashboardLoading;

  /// No description provided for @managerDashboardIssuesNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count} issues need attention'**
  String managerDashboardIssuesNeedAttention(int count);

  /// No description provided for @managerDashboardTodayOnTrack.
  ///
  /// In en, this message translates to:
  /// **'Today is on track'**
  String get managerDashboardTodayOnTrack;

  /// No description provided for @managerDashboardLoadingSummary.
  ///
  /// In en, this message translates to:
  /// **'Pulling today\'s shifts, missed work, and recurring issue signals for {locationName}.'**
  String managerDashboardLoadingSummary(String locationName);

  /// No description provided for @managerDashboardThisLocation.
  ///
  /// In en, this message translates to:
  /// **'this location'**
  String get managerDashboardThisLocation;

  /// No description provided for @managerDashboardIssuesSummary.
  ///
  /// In en, this message translates to:
  /// **'{riskCount} shifts are currently at risk and {openTaskCount} open tasks still need manager attention.'**
  String managerDashboardIssuesSummary(int riskCount, int openTaskCount);

  /// No description provided for @managerDashboardNoLiveShiftsSummary.
  ///
  /// In en, this message translates to:
  /// **'No live shifts are currently off track. Use the dashboard below to check readiness and recurring issues.'**
  String get managerDashboardNoLiveShiftsSummary;

  /// No description provided for @managerDashboardRefreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get managerDashboardRefreshNow;

  /// No description provided for @managerDashboardReviewIssues.
  ///
  /// In en, this message translates to:
  /// **'Review Issues'**
  String get managerDashboardReviewIssues;

  /// No description provided for @managerDashboardViewShiftReadiness.
  ///
  /// In en, this message translates to:
  /// **'View Shift Readiness'**
  String get managerDashboardViewShiftReadiness;

  /// No description provided for @managerDashboardHistoryReports.
  ///
  /// In en, this message translates to:
  /// **'History & Reports'**
  String get managerDashboardHistoryReports;

  /// No description provided for @managerDashboardTodayAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Today at Risk'**
  String get managerDashboardTodayAtRisk;

  /// No description provided for @managerDashboardTodayAtRiskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compact action queue for what needs attention first.'**
  String get managerDashboardTodayAtRiskSubtitle;

  /// No description provided for @managerDashboardShiftReadiness.
  ///
  /// In en, this message translates to:
  /// **'Shift Readiness'**
  String get managerDashboardShiftReadiness;

  /// No description provided for @managerDashboardShiftReadinessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live board of progress, open work, and shift health.'**
  String get managerDashboardShiftReadinessSubtitle;

  /// No description provided for @managerDashboardNoScheduledShiftsYet.
  ///
  /// In en, this message translates to:
  /// **'No scheduled shifts yet'**
  String get managerDashboardNoScheduledShiftsYet;

  /// No description provided for @managerDashboardNoScheduledShiftsBody.
  ///
  /// In en, this message translates to:
  /// **'Create and run shifts to see readiness here.'**
  String get managerDashboardNoScheduledShiftsBody;

  /// No description provided for @managerDashboardRecurringIssues.
  ///
  /// In en, this message translates to:
  /// **'Recurring Issues'**
  String get managerDashboardRecurringIssues;

  /// No description provided for @managerDashboardRecurringIssuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where misses and weak runs keep showing up.'**
  String get managerDashboardRecurringIssuesSubtitle;

  /// No description provided for @managerDashboardRecurringFailures.
  ///
  /// In en, this message translates to:
  /// **'Recurring Failures'**
  String get managerDashboardRecurringFailures;

  /// No description provided for @managerDashboardRecurringFailuresSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ranked by miss rate over the last 30 days.'**
  String get managerDashboardRecurringFailuresSubtitle;

  /// No description provided for @managerDashboardNoRecurringFailuresYet.
  ///
  /// In en, this message translates to:
  /// **'No recurring failures yet.'**
  String get managerDashboardNoRecurringFailuresYet;

  /// No description provided for @managerDashboardAtRiskShifts.
  ///
  /// In en, this message translates to:
  /// **'At-Risk Shifts'**
  String get managerDashboardAtRiskShifts;

  /// No description provided for @managerDashboardAtRiskShiftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shifts with the weakest completion trends over the last 30 days.'**
  String get managerDashboardAtRiskShiftsSubtitle;

  /// No description provided for @managerDashboardNoAtRiskShifts.
  ///
  /// In en, this message translates to:
  /// **'No at-risk shifts found.'**
  String get managerDashboardNoAtRiskShifts;

  /// No description provided for @managerDashboardAllMissedTasksYesterday.
  ///
  /// In en, this message translates to:
  /// **'All Missed Tasks Yesterday'**
  String get managerDashboardAllMissedTasksYesterday;

  /// No description provided for @managerDashboardUnknownTask.
  ///
  /// In en, this message translates to:
  /// **'Unknown Task'**
  String get managerDashboardUnknownTask;

  /// No description provided for @managerDashboardUnknownShift.
  ///
  /// In en, this message translates to:
  /// **'Unknown Shift'**
  String get managerDashboardUnknownShift;

  /// No description provided for @managerDashboardDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get managerDashboardDoneToday;

  /// No description provided for @adminSetupTourWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back — we’ll show you what’s new'**
  String get adminSetupTourWelcomeTitle;

  /// No description provided for @adminSetupTourWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Setup has been refreshed to make locations, team, shifts, and checklist templates easier to manage. This quick tour will show you the updated flow before you start editing.'**
  String get adminSetupTourWelcomeDescription;

  /// No description provided for @adminSetupTourLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep setup scoped to one location'**
  String get adminSetupTourLocationTitle;

  /// No description provided for @adminSetupTourLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Switch here when you want to focus on one restaurant. Shifts, team access, and checklist templates all become easier to manage when you narrow the location.'**
  String get adminSetupTourLocationDescription;

  /// No description provided for @adminSetupTourAreasTitle.
  ///
  /// In en, this message translates to:
  /// **'Move through setup by area'**
  String get adminSetupTourAreasTitle;

  /// No description provided for @adminSetupTourAreasDescription.
  ///
  /// In en, this message translates to:
  /// **'Use these quick setup areas to jump between Locations, Team, Shifts, and Checklist Library without losing your place.'**
  String get adminSetupTourAreasDescription;

  /// No description provided for @adminSetupTourPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Work in one setup area at a time'**
  String get adminSetupTourPanelTitle;

  /// No description provided for @adminSetupTourPanelDescription.
  ///
  /// In en, this message translates to:
  /// **'The main panel below is where you add, edit, and review the current setup area. Keep the selected location and setup area in sync as you configure operations.'**
  String get adminSetupTourPanelDescription;

  /// No description provided for @adminSetupActiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Active location'**
  String get adminSetupActiveLocation;

  /// No description provided for @adminSetupSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get adminSetupSelectLocation;

  /// No description provided for @adminSetupAreas.
  ///
  /// In en, this message translates to:
  /// **'Setup areas'**
  String get adminSetupAreas;

  /// No description provided for @adminViewLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get adminViewLocations;

  /// No description provided for @adminViewTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get adminViewTeam;

  /// No description provided for @adminViewShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get adminViewShifts;

  /// No description provided for @adminViewChecklistLibrary.
  ///
  /// In en, this message translates to:
  /// **'Checklist Library'**
  String get adminViewChecklistLibrary;

  /// No description provided for @adminViewEyebrowPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get adminViewEyebrowPlaces;

  /// No description provided for @adminViewEyebrowPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get adminViewEyebrowPeople;

  /// No description provided for @adminViewEyebrowOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get adminViewEyebrowOperations;

  /// No description provided for @adminViewEyebrowChecklistTemplates.
  ///
  /// In en, this message translates to:
  /// **'Checklist Templates'**
  String get adminViewEyebrowChecklistTemplates;

  /// No description provided for @adminViewLocationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage the places your team operates from and keep setup anchored to real locations.'**
  String get adminViewLocationsSubtitle;

  /// No description provided for @adminViewTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite staff, assign access, and keep every role aligned to the right locations.'**
  String get adminViewTeamSubtitle;

  /// No description provided for @adminViewShiftsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set when work happens and attach the right workflow to each shift.'**
  String get adminViewShiftsSubtitle;

  /// No description provided for @adminViewChecklistLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep reusable checklist templates for opening, closing, prep, and repeatable routines.'**
  String get adminViewChecklistLibrarySubtitle;

  /// No description provided for @adminSetupHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations Setup'**
  String get adminSetupHeroTitle;

  /// No description provided for @adminSetupAllLocations.
  ///
  /// In en, this message translates to:
  /// **'All locations'**
  String get adminSetupAllLocations;

  /// No description provided for @adminWorkflowNoneAttached.
  ///
  /// In en, this message translates to:
  /// **'No workflow attached yet'**
  String get adminWorkflowNoneAttached;

  /// No description provided for @adminWorkflowOneAttached.
  ///
  /// In en, this message translates to:
  /// **'1 workflow attached'**
  String get adminWorkflowOneAttached;

  /// No description provided for @adminWorkflowManyAttached.
  ///
  /// In en, this message translates to:
  /// **'{count} workflows attached'**
  String adminWorkflowManyAttached(int count);

  /// No description provided for @adminWorkflowTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} workflow'**
  String adminWorkflowTitle(String name);

  /// No description provided for @adminNoOrganizationDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No organization data available'**
  String get adminNoOrganizationDataAvailable;

  /// No description provided for @adminErrorLoadingUsers.
  ///
  /// In en, this message translates to:
  /// **'Error loading users: {error}'**
  String adminErrorLoadingUsers(String error);

  /// No description provided for @adminErrorLoadingLocations.
  ///
  /// In en, this message translates to:
  /// **'Error loading locations: {error}'**
  String adminErrorLoadingLocations(String error);

  /// No description provided for @adminNoTeamMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No team members found'**
  String get adminNoTeamMembersFound;

  /// No description provided for @adminInviteTeamToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Invite your team to get started'**
  String get adminInviteTeamToGetStarted;

  /// No description provided for @adminUnnamedUser.
  ///
  /// In en, this message translates to:
  /// **'Unnamed User'**
  String get adminUnnamedUser;

  /// No description provided for @adminDeleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get adminDeleteUserTitle;

  /// No description provided for @adminDeleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this user? This action cannot be undone.'**
  String get adminDeleteUserBody;

  /// No description provided for @adminNoLocationsFound.
  ///
  /// In en, this message translates to:
  /// **'No locations found'**
  String get adminNoLocationsFound;

  /// No description provided for @adminAddLocationToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Add a location to get started'**
  String get adminAddLocationToGetStarted;

  /// No description provided for @adminNoShiftsForSelectedLocation.
  ///
  /// In en, this message translates to:
  /// **'No shifts found for selected location'**
  String get adminNoShiftsForSelectedLocation;

  /// No description provided for @adminNoShiftsFound.
  ///
  /// In en, this message translates to:
  /// **'No shifts found'**
  String get adminNoShiftsFound;

  /// No description provided for @adminCreateShiftsAttachWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Create shifts, then attach workflows to them'**
  String get adminCreateShiftsAttachWorkflows;

  /// No description provided for @webAdminWorkflowLabel.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get webAdminWorkflowLabel;

  /// No description provided for @webAdminWorkflowCreated.
  ///
  /// In en, this message translates to:
  /// **'Workflow created successfully'**
  String get webAdminWorkflowCreated;

  /// No description provided for @webAdminScheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get webAdminScheduleDaily;

  /// No description provided for @webAdminDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get webAdminDayMon;

  /// No description provided for @webAdminDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get webAdminDayTue;

  /// No description provided for @webAdminDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get webAdminDayWed;

  /// No description provided for @webAdminDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get webAdminDayThu;

  /// No description provided for @webAdminDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get webAdminDayFri;

  /// No description provided for @webAdminDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get webAdminDaySat;

  /// No description provided for @webAdminDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get webAdminDaySun;

  /// No description provided for @webAdminSidebarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure places, people, shifts, and reusable workflows.'**
  String get webAdminSidebarSubtitle;

  /// No description provided for @webAdminSetupWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Setup workspace'**
  String get webAdminSetupWorkspace;

  /// No description provided for @webAdminScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get webAdminScope;

  /// No description provided for @webAdminAllActive.
  ///
  /// In en, this message translates to:
  /// **'All active'**
  String get webAdminAllActive;

  /// No description provided for @webAdminSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {name}...'**
  String webAdminSearchHint(String name);

  /// No description provided for @webAdminAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String webAdminAddItem(String name);

  /// No description provided for @webAdminSectionEyebrowShifts.
  ///
  /// In en, this message translates to:
  /// **'Operational setup'**
  String get webAdminSectionEyebrowShifts;

  /// No description provided for @webAdminSectionEyebrowChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklist templates'**
  String get webAdminSectionEyebrowChecklists;

  /// No description provided for @webAdminSectionEyebrowUsers.
  ///
  /// In en, this message translates to:
  /// **'People & access'**
  String get webAdminSectionEyebrowUsers;

  /// No description provided for @webAdminSectionEyebrowLocations.
  ///
  /// In en, this message translates to:
  /// **'Business footprint'**
  String get webAdminSectionEyebrowLocations;

  /// No description provided for @webAdminSectionTitleShifts.
  ///
  /// In en, this message translates to:
  /// **'Build shifts around real service workflows'**
  String get webAdminSectionTitleShifts;

  /// No description provided for @webAdminSectionTitleChecklists.
  ///
  /// In en, this message translates to:
  /// **'Maintain a clean workflow library'**
  String get webAdminSectionTitleChecklists;

  /// No description provided for @webAdminSectionTitleUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage your team with less friction'**
  String get webAdminSectionTitleUsers;

  /// No description provided for @webAdminSectionTitleLocations.
  ///
  /// In en, this message translates to:
  /// **'Keep every location ready to operate'**
  String get webAdminSectionTitleLocations;

  /// No description provided for @webAdminSectionSubtitleShifts.
  ///
  /// In en, this message translates to:
  /// **'Define when work happens, who it belongs to, and which workflow template runs during that shift.'**
  String get webAdminSectionSubtitleShifts;

  /// No description provided for @webAdminSectionSubtitleChecklists.
  ///
  /// In en, this message translates to:
  /// **'Create reusable checklist templates for opening, closing, prep, and recurring procedures across your operation.'**
  String get webAdminSectionSubtitleChecklists;

  /// No description provided for @webAdminSectionSubtitleUsers.
  ///
  /// In en, this message translates to:
  /// **'Invite managers and staff, assign their locations, and keep access aligned with the way the business runs.'**
  String get webAdminSectionSubtitleUsers;

  /// No description provided for @webAdminSectionSubtitleLocations.
  ///
  /// In en, this message translates to:
  /// **'Set up the places your team operates from, and use them to organize shifts, staffing, and workflow coverage.'**
  String get webAdminSectionSubtitleLocations;

  /// No description provided for @webAdminSectionTableSubtitleShifts.
  ///
  /// In en, this message translates to:
  /// **'Shift-centered setup with direct workflow visibility.'**
  String get webAdminSectionTableSubtitleShifts;

  /// No description provided for @webAdminSectionTableSubtitleChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklist templates stay reusable here and get attached from shifts.'**
  String get webAdminSectionTableSubtitleChecklists;

  /// No description provided for @webAdminSectionTableSubtitleUsers.
  ///
  /// In en, this message translates to:
  /// **'People, roles, invite state, and location coverage.'**
  String get webAdminSectionTableSubtitleUsers;

  /// No description provided for @webAdminSectionTableSubtitleLocations.
  ///
  /// In en, this message translates to:
  /// **'Your active places, addresses, and operating footprint.'**
  String get webAdminSectionTableSubtitleLocations;

  /// No description provided for @webAdminTabShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get webAdminTabShift;

  /// No description provided for @webAdminTabTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get webAdminTabTemplate;

  /// No description provided for @webAdminTabTeamMember.
  ///
  /// In en, this message translates to:
  /// **'Team Member'**
  String get webAdminTabTeamMember;

  /// No description provided for @webAdminTabLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get webAdminTabLocation;

  /// No description provided for @webAdminEmptyTitleShifts.
  ///
  /// In en, this message translates to:
  /// **'No Shifts Created Yet'**
  String get webAdminEmptyTitleShifts;

  /// No description provided for @webAdminEmptyDescriptionShifts.
  ///
  /// In en, this message translates to:
  /// **'Create your first shift to define when work happens, who works it, and which workflow should run. Shifts are the main place to set up operations.'**
  String get webAdminEmptyDescriptionShifts;

  /// No description provided for @webAdminEmptyActionShifts.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Shift'**
  String get webAdminEmptyActionShifts;

  /// No description provided for @webAdminEmptySupportLabelShifts.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get webAdminEmptySupportLabelShifts;

  /// No description provided for @webAdminEmptySupportValueShifts.
  ///
  /// In en, this message translates to:
  /// **'Attach workflow'**
  String get webAdminEmptySupportValueShifts;

  /// No description provided for @webAdminEmptySecondaryLabelShifts.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get webAdminEmptySecondaryLabelShifts;

  /// No description provided for @webAdminEmptySecondaryValueShifts.
  ///
  /// In en, this message translates to:
  /// **'Start with opening'**
  String get webAdminEmptySecondaryValueShifts;

  /// No description provided for @webAdminEmptyTitleChecklists.
  ///
  /// In en, this message translates to:
  /// **'No Checklist Templates Yet'**
  String get webAdminEmptyTitleChecklists;

  /// No description provided for @webAdminEmptyDescriptionChecklists.
  ///
  /// In en, this message translates to:
  /// **'Build reusable checklist templates for opening, closing, prep, and other repeatable work. Most owners will attach these from the Shifts screen.'**
  String get webAdminEmptyDescriptionChecklists;

  /// No description provided for @webAdminEmptyActionChecklists.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Template'**
  String get webAdminEmptyActionChecklists;

  /// No description provided for @webAdminEmptySupportLabelChecklists.
  ///
  /// In en, this message translates to:
  /// **'Best use'**
  String get webAdminEmptySupportLabelChecklists;

  /// No description provided for @webAdminEmptySupportValueChecklists.
  ///
  /// In en, this message translates to:
  /// **'Reusable workflows'**
  String get webAdminEmptySupportValueChecklists;

  /// No description provided for @webAdminEmptySecondaryLabelChecklists.
  ///
  /// In en, this message translates to:
  /// **'Most common'**
  String get webAdminEmptySecondaryLabelChecklists;

  /// No description provided for @webAdminEmptySecondaryValueChecklists.
  ///
  /// In en, this message translates to:
  /// **'Opening + closing'**
  String get webAdminEmptySecondaryValueChecklists;

  /// No description provided for @webAdminEmptyTitleUsers.
  ///
  /// In en, this message translates to:
  /// **'No Team Members Added Yet'**
  String get webAdminEmptyTitleUsers;

  /// No description provided for @webAdminEmptyDescriptionUsers.
  ///
  /// In en, this message translates to:
  /// **'Invite team members to join your organization. You can assign different roles and control which locations they can access.'**
  String get webAdminEmptyDescriptionUsers;

  /// No description provided for @webAdminEmptyActionUsers.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Team Member'**
  String get webAdminEmptyActionUsers;

  /// No description provided for @webAdminEmptySupportLabelUsers.
  ///
  /// In en, this message translates to:
  /// **'Most useful'**
  String get webAdminEmptySupportLabelUsers;

  /// No description provided for @webAdminEmptySupportValueUsers.
  ///
  /// In en, this message translates to:
  /// **'Invite managers first'**
  String get webAdminEmptySupportValueUsers;

  /// No description provided for @webAdminEmptySecondaryLabelUsers.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get webAdminEmptySecondaryLabelUsers;

  /// No description provided for @webAdminEmptySecondaryValueUsers.
  ///
  /// In en, this message translates to:
  /// **'Track invites here'**
  String get webAdminEmptySecondaryValueUsers;

  /// No description provided for @webAdminEmptyTitleLocations.
  ///
  /// In en, this message translates to:
  /// **'No Locations Added Yet'**
  String get webAdminEmptyTitleLocations;

  /// No description provided for @webAdminEmptyDescriptionLocations.
  ///
  /// In en, this message translates to:
  /// **'Set up your business locations to organize shifts, assign staff, and track operations. Each location can have its own shifts, checklists, and team members.'**
  String get webAdminEmptyDescriptionLocations;

  /// No description provided for @webAdminEmptyActionLocations.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Location'**
  String get webAdminEmptyActionLocations;

  /// No description provided for @webAdminEmptySupportLabelLocations.
  ///
  /// In en, this message translates to:
  /// **'Foundation'**
  String get webAdminEmptySupportLabelLocations;

  /// No description provided for @webAdminEmptySupportValueLocations.
  ///
  /// In en, this message translates to:
  /// **'Build setup around places'**
  String get webAdminEmptySupportValueLocations;

  /// No description provided for @webAdminEmptySecondaryLabelLocations.
  ///
  /// In en, this message translates to:
  /// **'After this'**
  String get webAdminEmptySecondaryLabelLocations;

  /// No description provided for @webAdminEmptySecondaryValueLocations.
  ///
  /// In en, this message translates to:
  /// **'Create shifts'**
  String get webAdminEmptySecondaryValueLocations;

  /// No description provided for @webAdminEmptyFooter.
  ///
  /// In en, this message translates to:
  /// **'Keep setup light: create the location, add your team, then build shifts with attached workflows.'**
  String get webAdminEmptyFooter;

  /// No description provided for @webAdminColumnShiftName.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get webAdminColumnShiftName;

  /// No description provided for @webAdminColumnTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get webAdminColumnTime;

  /// No description provided for @webAdminColumnSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get webAdminColumnSchedule;

  /// No description provided for @webAdminColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get webAdminColumnStatus;

  /// No description provided for @webAdminColumnActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get webAdminColumnActions;

  /// No description provided for @webAdminColumnTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get webAdminColumnTemplateName;

  /// No description provided for @webAdminColumnDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get webAdminColumnDescription;

  /// No description provided for @webAdminColumnTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get webAdminColumnTasks;

  /// No description provided for @webAdminColumnUsedInShifts.
  ///
  /// In en, this message translates to:
  /// **'Used in Shifts'**
  String get webAdminColumnUsedInShifts;

  /// No description provided for @webAdminColumnLocationName.
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get webAdminColumnLocationName;

  /// No description provided for @webAdminColumnAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get webAdminColumnAddress;

  /// No description provided for @webAdminStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get webAdminStatusActive;

  /// No description provided for @webAdminStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get webAdminStatusInactive;

  /// No description provided for @webAdminStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get webAdminStatusArchived;

  /// No description provided for @webAdminActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get webAdminActionEdit;

  /// No description provided for @webAdminActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get webAdminActionDuplicate;

  /// No description provided for @webAdminActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get webAdminActionArchive;

  /// No description provided for @webAdminActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get webAdminActionRestore;

  /// No description provided for @webAdminActionCreateWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Create workflow'**
  String get webAdminActionCreateWorkflow;

  /// No description provided for @webAdminActionEditWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Edit workflow'**
  String get webAdminActionEditWorkflow;

  /// No description provided for @webAdminActionDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get webAdminActionDeactivate;

  /// No description provided for @webAdminActionActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get webAdminActionActivate;

  /// No description provided for @webAdminActionDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get webAdminActionDeleteUser;

  /// No description provided for @webAdminNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get webAdminNoDescription;

  /// No description provided for @webAdminTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String webAdminTaskCount(int count);

  /// No description provided for @webAdminDeleteShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete shift?'**
  String get webAdminDeleteShiftTitle;

  /// No description provided for @webAdminDeleteShiftBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String webAdminDeleteShiftBody(String name);

  /// No description provided for @webAdminShiftUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shift updated successfully'**
  String get webAdminShiftUpdated;

  /// No description provided for @webAdminShiftUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update shift: {error}'**
  String webAdminShiftUpdateFailed(String error);

  /// No description provided for @webAdminChecklistUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update template'**
  String get webAdminChecklistUpdateFailed;

  /// No description provided for @webAdminDeleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get webAdminDeleteTemplateTitle;

  /// No description provided for @webAdminDeleteTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String webAdminDeleteTemplateBody(String name);

  /// No description provided for @webAdminTemplateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted successfully'**
  String get webAdminTemplateDeleted;

  /// No description provided for @webAdminTemplateDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete template: {error}'**
  String webAdminTemplateDeleteFailed(String error);

  /// No description provided for @webAdminCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (Copy)'**
  String webAdminCopyName(String name);

  /// No description provided for @webAdminLocationDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Location duplicated successfully'**
  String get webAdminLocationDuplicated;

  /// No description provided for @webAdminDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate item'**
  String get webAdminDuplicateFailed;

  /// No description provided for @webAdminShiftCreated.
  ///
  /// In en, this message translates to:
  /// **'Shift created successfully'**
  String get webAdminShiftCreated;

  /// No description provided for @webAdminShiftSaved.
  ///
  /// In en, this message translates to:
  /// **'Shift updated successfully'**
  String get webAdminShiftSaved;

  /// No description provided for @webAdminShiftEditorOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open shift editor'**
  String get webAdminShiftEditorOpenFailed;

  /// No description provided for @webAdminShiftDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Shift duplicated successfully'**
  String get webAdminShiftDuplicated;

  /// No description provided for @webAdminShiftDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate shift: {error}'**
  String webAdminShiftDuplicateFailed(String error);

  /// No description provided for @webAdminShiftArchived.
  ///
  /// In en, this message translates to:
  /// **'Shift archived successfully'**
  String get webAdminShiftArchived;

  /// No description provided for @webAdminShiftRestored.
  ///
  /// In en, this message translates to:
  /// **'Shift restored successfully'**
  String get webAdminShiftRestored;

  /// No description provided for @webAdminTemplateCreated.
  ///
  /// In en, this message translates to:
  /// **'Template created successfully'**
  String get webAdminTemplateCreated;

  /// No description provided for @webAdminTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template updated successfully'**
  String get webAdminTemplateSaved;

  /// No description provided for @webAdminTemplateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save template: {error}'**
  String webAdminTemplateSaveFailed(String error);

  /// No description provided for @webAdminTemplateEditorOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open template editor'**
  String get webAdminTemplateEditorOpenFailed;

  /// No description provided for @webAdminTemplateDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Template duplicated successfully'**
  String get webAdminTemplateDuplicated;

  /// No description provided for @webAdminTemplateDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate template: {error}'**
  String webAdminTemplateDuplicateFailed(String error);

  /// No description provided for @webAdminTemplateArchived.
  ///
  /// In en, this message translates to:
  /// **'Template archived successfully'**
  String get webAdminTemplateArchived;

  /// No description provided for @webAdminTemplateRestored.
  ///
  /// In en, this message translates to:
  /// **'Template restored successfully'**
  String get webAdminTemplateRestored;

  /// No description provided for @webAdminUserDeactivated.
  ///
  /// In en, this message translates to:
  /// **'User deactivated successfully'**
  String get webAdminUserDeactivated;

  /// No description provided for @webAdminUserActivated.
  ///
  /// In en, this message translates to:
  /// **'User activated successfully'**
  String get webAdminUserActivated;

  /// No description provided for @webAdminUserUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update user: {error}'**
  String webAdminUserUpdateFailed(String error);

  /// No description provided for @webAdminLocationCreated.
  ///
  /// In en, this message translates to:
  /// **'Location created successfully'**
  String get webAdminLocationCreated;

  /// No description provided for @webAdminLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Location updated successfully'**
  String get webAdminLocationSaved;

  /// No description provided for @webAdminLocationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update location: {error}'**
  String webAdminLocationUpdateFailed(String error);

  /// No description provided for @webAdminLocationArchived.
  ///
  /// In en, this message translates to:
  /// **'Location archived successfully'**
  String get webAdminLocationArchived;

  /// No description provided for @webAdminLocationRestored.
  ///
  /// In en, this message translates to:
  /// **'Location restored successfully'**
  String get webAdminLocationRestored;

  /// No description provided for @webAdminDeleteLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete location?'**
  String get webAdminDeleteLocationTitle;

  /// No description provided for @webAdminDeleteLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String webAdminDeleteLocationBody(String name);

  /// No description provided for @webAdminLocationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Location deleted successfully'**
  String get webAdminLocationDeleted;

  /// No description provided for @webAdminLocationDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete location: {error}'**
  String webAdminLocationDeleteFailed(String error);

  /// No description provided for @webAdminDeleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete user?'**
  String get webAdminDeleteUserTitle;

  /// No description provided for @webAdminDeleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String webAdminDeleteUserBody(String name);

  /// No description provided for @webAdminUserDeleted.
  ///
  /// In en, this message translates to:
  /// **'User deleted successfully'**
  String get webAdminUserDeleted;

  /// No description provided for @webAdminUserDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete user: {error}'**
  String webAdminUserDeleteFailed(String error);

  /// No description provided for @webAdminWorkflowSuggestion.
  ///
  /// In en, this message translates to:
  /// **'{name} workflow'**
  String webAdminWorkflowSuggestion(String name);

  /// No description provided for @webAdminStreamError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String webAdminStreamError(String error);

  /// No description provided for @webAdminUnnamedShift.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Shift'**
  String get webAdminUnnamedShift;

  /// No description provided for @webAdminUnnamedTemplate.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Template'**
  String get webAdminUnnamedTemplate;

  /// No description provided for @webAdminUnnamedLocation.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Location'**
  String get webAdminUnnamedLocation;

  /// No description provided for @webAdminUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get webAdminUnknownUser;

  /// No description provided for @webAdminNoEmail.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get webAdminNoEmail;

  /// No description provided for @webAdminNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No address'**
  String get webAdminNoAddress;

  /// No description provided for @guidedTourStepCounter.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String guidedTourStepCounter(int current, int total);

  /// No description provided for @guidedTourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get guidedTourSkip;

  /// No description provided for @guidedTourLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get guidedTourLearnMore;

  /// No description provided for @guidedTourBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get guidedTourBack;

  /// No description provided for @guidedTourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get guidedTourNext;

  /// No description provided for @guidedTourDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get guidedTourDone;

  /// No description provided for @guidedTourLanguageFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'New: language support'**
  String get guidedTourLanguageFeatureTitle;

  /// No description provided for @guidedTourLanguageFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'You can now switch between English, Spanish, and Portuguese anytime from Language in Settings.'**
  String get guidedTourLanguageFeatureBody;

  /// No description provided for @releaseDialogUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'A major update is available'**
  String get releaseDialogUpdateTitle;

  /// No description provided for @releaseDialogUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh or update to see the latest experience, language options, and guided walkthrough.'**
  String get releaseDialogUpdateSubtitle;

  /// No description provided for @releaseDialogWhatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A refreshed experience is live, including guided walkthrough updates and language support.'**
  String get releaseDialogWhatsNewSubtitle;

  /// No description provided for @releaseDialogNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get releaseDialogNotNow;

  /// No description provided for @releaseDialogTakeGuidedTour.
  ///
  /// In en, this message translates to:
  /// **'Take guided tour'**
  String get releaseDialogTakeGuidedTour;

  /// No description provided for @releaseDialogRefreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get releaseDialogRefreshNow;

  /// No description provided for @releaseDialogUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get releaseDialogUpdateNow;

  /// No description provided for @releaseDialogOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get releaseDialogOkay;

  /// No description provided for @releaseDialogMajorReleaseBadge.
  ///
  /// In en, this message translates to:
  /// **'Major release'**
  String get releaseDialogMajorReleaseBadge;

  /// No description provided for @releaseDialogNewExperienceBadge.
  ///
  /// In en, this message translates to:
  /// **'New experience'**
  String get releaseDialogNewExperienceBadge;

  /// No description provided for @releaseDialogWhatChanged.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get releaseDialogWhatChanged;

  /// No description provided for @releaseDialogLanguageFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'New: language support'**
  String get releaseDialogLanguageFeatureTitle;

  /// No description provided for @releaseDialogLanguageFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'English, Spanish, and Portuguese are now available from Language in Settings.'**
  String get releaseDialogLanguageFeatureBody;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @notificationsViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get notificationsViewAction;

  /// No description provided for @quickPdfViewerDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get quickPdfViewerDocumentTitle;

  /// No description provided for @quickPdfViewerTrainingDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Document'**
  String get quickPdfViewerTrainingDocumentTitle;

  /// No description provided for @quickPdfViewerDescription.
  ///
  /// In en, this message translates to:
  /// **'This document will open in your device\'s native viewer for the best experience.'**
  String get quickPdfViewerDescription;

  /// No description provided for @quickPdfViewerOpenDocument.
  ///
  /// In en, this message translates to:
  /// **'Open Document'**
  String get quickPdfViewerOpenDocument;

  /// No description provided for @quickPdfViewerCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get quickPdfViewerCopyLink;

  /// No description provided for @quickPdfViewerShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get quickPdfViewerShare;

  /// No description provided for @quickPdfViewerHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Documents open in your device\'s built-in viewer for optimal performance and feature support.'**
  String get quickPdfViewerHelpBody;

  /// No description provided for @quickPdfViewerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open document. Please check your internet connection.'**
  String get quickPdfViewerOpenFailed;

  /// No description provided for @quickPdfViewerOpenError.
  ///
  /// In en, this message translates to:
  /// **'Error opening document: {error}'**
  String quickPdfViewerOpenError(String error);

  /// No description provided for @quickPdfViewerCopied.
  ///
  /// In en, this message translates to:
  /// **'Document link copied to clipboard'**
  String get quickPdfViewerCopied;

  /// No description provided for @quickPdfViewerShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share document'**
  String get quickPdfViewerShareFailed;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsTestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test Notifications'**
  String get notificationSettingsTestTooltip;

  /// No description provided for @notificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay Updated with Hands'**
  String get notificationPermissionTitle;

  /// No description provided for @notificationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified about schedule changes, shift reminders, and important announcements from your team.'**
  String get notificationPermissionBody;

  /// No description provided for @notificationSettingsQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get notificationSettingsQuickActions;

  /// No description provided for @notificationSettingsSubscribeTopics.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Topics'**
  String get notificationSettingsSubscribeTopics;

  /// No description provided for @notificationSettingsSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get notificationSettingsSystemSettings;

  /// No description provided for @notificationSettingsTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Setup Test'**
  String get notificationSettingsTestTitle;

  /// No description provided for @notificationSettingsPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission: {value}'**
  String notificationSettingsPermission(String value);

  /// No description provided for @notificationSettingsToken.
  ///
  /// In en, this message translates to:
  /// **'Token: {value}'**
  String notificationSettingsToken(String value);

  /// No description provided for @notificationSettingsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {value}'**
  String notificationSettingsStatus(String value);

  /// No description provided for @notificationSettingsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get notificationSettingsNone;

  /// No description provided for @notificationSettingsReady.
  ///
  /// In en, this message translates to:
  /// **'✅ Ready'**
  String get notificationSettingsReady;

  /// No description provided for @notificationSettingsNotReady.
  ///
  /// In en, this message translates to:
  /// **'❌ Not Ready'**
  String get notificationSettingsNotReady;

  /// No description provided for @notificationOnboardingStayConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get notificationOnboardingStayConnected;

  /// No description provided for @notificationOnboardingBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified about:\n• Schedule updates\n• Shift reminders\n• Important announcements'**
  String get notificationOnboardingBody;

  /// No description provided for @notificationOnboardingEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationOnboardingEnableTitle;

  /// No description provided for @notificationOnboardingEnableBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll only send notifications that are relevant to your work schedule and important updates.'**
  String get notificationOnboardingEnableBody;

  /// No description provided for @notificationOnboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get notificationOnboardingSkip;

  /// No description provided for @checklistSheetInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get checklistSheetInfoLabel;

  /// No description provided for @checklistSheetNewChecklist.
  ///
  /// In en, this message translates to:
  /// **'New checklist'**
  String get checklistSheetNewChecklist;

  /// No description provided for @checklistSheetEditChecklist.
  ///
  /// In en, this message translates to:
  /// **'Edit checklist'**
  String get checklistSheetEditChecklist;

  /// No description provided for @checklistSheetSaveChecklist.
  ///
  /// In en, this message translates to:
  /// **'Save checklist'**
  String get checklistSheetSaveChecklist;

  /// No description provided for @checklistSheetStepBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get checklistSheetStepBasics;

  /// No description provided for @checklistSheetStepTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get checklistSheetStepTasks;

  /// No description provided for @checklistSheetStepAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get checklistSheetStepAdvanced;

  /// No description provided for @checklistSheetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Checklist name is required.'**
  String get checklistSheetNameRequired;

  /// No description provided for @checklistSheetAddOneTask.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one task.'**
  String get checklistSheetAddOneTask;

  /// No description provided for @checklistSheetAllTasksNamed.
  ///
  /// In en, this message translates to:
  /// **'All tasks must have names.'**
  String get checklistSheetAllTasksNamed;

  /// No description provided for @checklistSheetInfoTipBasics.
  ///
  /// In en, this message translates to:
  /// **'Name this workflow template and add a short description.'**
  String get checklistSheetInfoTipBasics;

  /// No description provided for @checklistSheetBasicsIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the basic information for this template:'**
  String get checklistSheetBasicsIntro;

  /// No description provided for @checklistSheetTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name *'**
  String get checklistSheetTemplateName;

  /// No description provided for @checklistSheetTemplateNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Opening Bar, Kitchen Close'**
  String get checklistSheetTemplateNameHint;

  /// No description provided for @checklistSheetDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get checklistSheetDescriptionOptional;

  /// No description provided for @checklistSheetDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of this checklist'**
  String get checklistSheetDescriptionHint;

  /// No description provided for @checklistSheetNoShiftsAttach.
  ///
  /// In en, this message translates to:
  /// **'No shifts are available to attach right now.'**
  String get checklistSheetNoShiftsAttach;

  /// No description provided for @checklistSheetNoShiftsFound.
  ///
  /// In en, this message translates to:
  /// **'No shifts found for this location. Please create shifts first.'**
  String get checklistSheetNoShiftsFound;

  /// No description provided for @checklistSheetShiftTip.
  ///
  /// In en, this message translates to:
  /// **'Select shifts where this checklist appears. You can leave this empty now and attach it later from the Shifts screen.'**
  String get checklistSheetShiftTip;

  /// No description provided for @checklistSheetSelectShifts.
  ///
  /// In en, this message translates to:
  /// **'Select which shifts should use this checklist:'**
  String get checklistSheetSelectShifts;

  /// No description provided for @checklistSheetTasksTip.
  ///
  /// In en, this message translates to:
  /// **'Tap the camera to require a photo. If a photo is not uploaded by staff, admins are notified.'**
  String get checklistSheetTasksTip;

  /// No description provided for @checklistSheetTasksIntro.
  ///
  /// In en, this message translates to:
  /// **'Add tasks to your checklist. Drag to reorder:'**
  String get checklistSheetTasksIntro;

  /// No description provided for @checklistSheetNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks added yet. Tap \"Add Task\" to get started.'**
  String get checklistSheetNoTasks;

  /// No description provided for @checklistSheetAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get checklistSheetAddTask;

  /// No description provided for @checklistSheetAdvancedTip.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings are optional. Use them if you want to limit who can see this checklist or attach it to one or more shifts now.'**
  String get checklistSheetAdvancedTip;

  /// No description provided for @checklistSheetVisibilityByJobType.
  ///
  /// In en, this message translates to:
  /// **'Visibility by job type'**
  String get checklistSheetVisibilityByJobType;

  /// No description provided for @checklistSheetAssignToShifts.
  ///
  /// In en, this message translates to:
  /// **'Assign to shifts'**
  String get checklistSheetAssignToShifts;

  /// No description provided for @checklistSheetSpanishTranslations.
  ///
  /// In en, this message translates to:
  /// **'Spanish translations'**
  String get checklistSheetSpanishTranslations;

  /// No description provided for @checklistSheetPortugueseTranslations.
  ///
  /// In en, this message translates to:
  /// **'Portuguese translations'**
  String get checklistSheetPortugueseTranslations;

  /// No description provided for @checklistSheetSpanishTip.
  ///
  /// In en, this message translates to:
  /// **'Optional: add Spanish versions of this template and its task names. English stays as the fallback when a Spanish field is left blank.'**
  String get checklistSheetSpanishTip;

  /// No description provided for @checklistSheetTemplateNameSpanish.
  ///
  /// In en, this message translates to:
  /// **'Template name (Spanish)'**
  String get checklistSheetTemplateNameSpanish;

  /// No description provided for @checklistSheetTemplateNameSpanishHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Apertura del bar'**
  String get checklistSheetTemplateNameSpanishHint;

  /// No description provided for @checklistSheetDescriptionSpanish.
  ///
  /// In en, this message translates to:
  /// **'Description (Spanish)'**
  String get checklistSheetDescriptionSpanish;

  /// No description provided for @checklistSheetDescriptionSpanishHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description in Spanish'**
  String get checklistSheetDescriptionSpanishHint;

  /// No description provided for @checklistSheetAddTasksForSpanish.
  ///
  /// In en, this message translates to:
  /// **'Add tasks first to include Spanish task labels.'**
  String get checklistSheetAddTasksForSpanish;

  /// No description provided for @checklistSheetSpanishTaskLabels.
  ///
  /// In en, this message translates to:
  /// **'Spanish task labels'**
  String get checklistSheetSpanishTaskLabels;

  /// No description provided for @checklistSheetTaskSpanish.
  ///
  /// In en, this message translates to:
  /// **'Task {index} (Spanish)'**
  String checklistSheetTaskSpanish(int index);

  /// No description provided for @checklistSheetSpanishTaskLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Spanish task label'**
  String get checklistSheetSpanishTaskLabelHint;

  /// No description provided for @checklistSheetSpanishFor.
  ///
  /// In en, this message translates to:
  /// **'Spanish for: {name}'**
  String checklistSheetSpanishFor(String name);

  /// No description provided for @checklistSheetPortugueseTip.
  ///
  /// In en, this message translates to:
  /// **'Optional: add Portuguese versions of this template and its task names. English stays as the fallback when a Portuguese field is left blank.'**
  String get checklistSheetPortugueseTip;

  /// No description provided for @checklistSheetTemplateNamePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Template name (Portuguese)'**
  String get checklistSheetTemplateNamePortuguese;

  /// No description provided for @checklistSheetTemplateNamePortugueseHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Abertura do bar'**
  String get checklistSheetTemplateNamePortugueseHint;

  /// No description provided for @checklistSheetDescriptionPortuguese.
  ///
  /// In en, this message translates to:
  /// **'Description (Portuguese)'**
  String get checklistSheetDescriptionPortuguese;

  /// No description provided for @checklistSheetDescriptionPortugueseHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description in Portuguese'**
  String get checklistSheetDescriptionPortugueseHint;

  /// No description provided for @checklistSheetAddTasksForPortuguese.
  ///
  /// In en, this message translates to:
  /// **'Add tasks first to include Portuguese task labels.'**
  String get checklistSheetAddTasksForPortuguese;

  /// No description provided for @checklistSheetPortugueseTaskLabels.
  ///
  /// In en, this message translates to:
  /// **'Portuguese task labels'**
  String get checklistSheetPortugueseTaskLabels;

  /// No description provided for @checklistSheetTaskPortuguese.
  ///
  /// In en, this message translates to:
  /// **'Task {index} (Portuguese)'**
  String checklistSheetTaskPortuguese(int index);

  /// No description provided for @checklistSheetPortugueseTaskLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Portuguese task label'**
  String get checklistSheetPortugueseTaskLabelHint;

  /// No description provided for @checklistSheetPortugueseFor.
  ///
  /// In en, this message translates to:
  /// **'Portuguese for: {name}'**
  String checklistSheetPortugueseFor(String name);

  /// No description provided for @checklistSheetTask.
  ///
  /// In en, this message translates to:
  /// **'Task {index}'**
  String checklistSheetTask(int index);

  /// No description provided for @checklistSheetTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Enter task description'**
  String get checklistSheetTaskHint;

  /// No description provided for @checklistSheetDeleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get checklistSheetDeleteTask;

  /// No description provided for @checklistSheetPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Photo required'**
  String get checklistSheetPhotoRequired;

  /// No description provided for @checklistSheetNoPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'No photo required'**
  String get checklistSheetNoPhotoRequired;

  /// No description provided for @checklistSheetTaskName.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get checklistSheetTaskName;

  /// No description provided for @checklistSheetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get checklistSheetPhoto;

  /// No description provided for @checklistSheetLoadShiftsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading shifts: {error}'**
  String checklistSheetLoadShiftsError(String error);

  /// No description provided for @checklistSheetJobTypesTip.
  ///
  /// In en, this message translates to:
  /// **'Job types control who will see this checklist. Leave this empty to make it visible to everyone on the shift.'**
  String get checklistSheetJobTypesTip;

  /// No description provided for @checklistSheetJobTypesIntro.
  ///
  /// In en, this message translates to:
  /// **'Optionally restrict this checklist to people with these job types. Leave empty to make it visible to all.'**
  String get checklistSheetJobTypesIntro;

  /// No description provided for @checklistSheetManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get checklistSheetManage;

  /// No description provided for @checklistSheetNoJobTypes.
  ///
  /// In en, this message translates to:
  /// **'No job types found yet. Use Manage to create your first one.'**
  String get checklistSheetNoJobTypes;

  /// No description provided for @checklistSheetAddJobType.
  ///
  /// In en, this message translates to:
  /// **'Add job type'**
  String get checklistSheetAddJobType;

  /// No description provided for @checklistSheetAddJobTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Dishwasher'**
  String get checklistSheetAddJobTypeHint;

  /// No description provided for @checklistSheetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get checklistSheetAdd;

  /// No description provided for @checklistSheetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save checklist: {error}'**
  String checklistSheetSaveFailed(String error);

  /// No description provided for @shiftSheetLoadDataError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String shiftSheetLoadDataError(String error);

  /// No description provided for @shiftSheetSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shift schedule updated successfully'**
  String get shiftSheetSavedSuccess;

  /// No description provided for @shiftSheetSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving schedule: {error}'**
  String shiftSheetSaveError(String error);

  /// No description provided for @shiftSheetAddRequiredRole.
  ///
  /// In en, this message translates to:
  /// **'Add Required Role'**
  String get shiftSheetAddRequiredRole;

  /// No description provided for @shiftSheetAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get shiftSheetAlreadyAdded;

  /// No description provided for @shiftSheetAssignedCount.
  ///
  /// In en, this message translates to:
  /// **'{assigned} of {required} assigned'**
  String shiftSheetAssignedCount(int assigned, int required);

  /// No description provided for @shiftSheetRequiredRoles.
  ///
  /// In en, this message translates to:
  /// **'Required Roles'**
  String get shiftSheetRequiredRoles;

  /// No description provided for @shiftSheetAddRole.
  ///
  /// In en, this message translates to:
  /// **'Add Role'**
  String get shiftSheetAddRole;

  /// No description provided for @shiftSheetNoRolesAssigned.
  ///
  /// In en, this message translates to:
  /// **'No roles assigned to this shift. Tap \"Add Role\" to add required positions.'**
  String get shiftSheetNoRolesAssigned;

  /// No description provided for @shiftSheetAssignedUsers.
  ///
  /// In en, this message translates to:
  /// **'Assigned Users'**
  String get shiftSheetAssignedUsers;

  /// No description provided for @shiftSheetNoUsersAssigned.
  ///
  /// In en, this message translates to:
  /// **'No users assigned yet.'**
  String get shiftSheetNoUsersAssigned;

  /// No description provided for @shiftSheetAvailableUsers.
  ///
  /// In en, this message translates to:
  /// **'Available Users (Matching Roles)'**
  String get shiftSheetAvailableUsers;

  /// No description provided for @shiftSheetOtherUsers.
  ///
  /// In en, this message translates to:
  /// **'Other Users (No Matching Role)'**
  String get shiftSheetOtherUsers;

  /// No description provided for @shiftSheetLoadUsersError.
  ///
  /// In en, this message translates to:
  /// **'Error loading users: {error}'**
  String shiftSheetLoadUsersError(String error);

  /// No description provided for @shiftSheetNoOtherUsers.
  ///
  /// In en, this message translates to:
  /// **'No other users available'**
  String get shiftSheetNoOtherUsers;

  /// No description provided for @shiftSheetSaveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save Schedule'**
  String get shiftSheetSaveSchedule;

  /// No description provided for @shiftSheetUnknownRole.
  ///
  /// In en, this message translates to:
  /// **'Unknown Role'**
  String get shiftSheetUnknownRole;

  /// No description provided for @shiftSheetRequiredCount.
  ///
  /// In en, this message translates to:
  /// **'Required: {count}'**
  String shiftSheetRequiredCount(int count);

  /// No description provided for @shiftSheetDecreaseCount.
  ///
  /// In en, this message translates to:
  /// **'Decrease count'**
  String get shiftSheetDecreaseCount;

  /// No description provided for @shiftSheetIncreaseCount.
  ///
  /// In en, this message translates to:
  /// **'Increase count'**
  String get shiftSheetIncreaseCount;

  /// No description provided for @shiftSheetRemoveRole.
  ///
  /// In en, this message translates to:
  /// **'Remove role'**
  String get shiftSheetRemoveRole;

  /// No description provided for @shiftSheetUnknownUserInitial.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get shiftSheetUnknownUserInitial;

  /// No description provided for @shiftSheetCheckAssignmentsError.
  ///
  /// In en, this message translates to:
  /// **'Error checking assignments: {error}'**
  String shiftSheetCheckAssignmentsError(String error);

  /// No description provided for @shiftSheetAlreadyAssignedAnotherShift.
  ///
  /// In en, this message translates to:
  /// **'Already assigned to another shift this day'**
  String get shiftSheetAlreadyAssignedAnotherShift;

  /// No description provided for @notificationTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Types'**
  String get notificationTopicsTitle;

  /// No description provided for @notificationTopicsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose which updates you want to stay on top of:'**
  String get notificationTopicsIntro;

  /// No description provided for @notificationTopicsScheduleUpdates.
  ///
  /// In en, this message translates to:
  /// **'Schedule updates keep you informed when shifts change.'**
  String get notificationTopicsScheduleUpdates;

  /// No description provided for @notificationTopicsShiftReminders.
  ///
  /// In en, this message translates to:
  /// **'Shift reminders prompt you before assigned work begins.'**
  String get notificationTopicsShiftReminders;

  /// No description provided for @notificationTopicsGeneralAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'General announcements share broader team and business updates.'**
  String get notificationTopicsGeneralAnnouncements;

  /// No description provided for @notificationTopicsGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get notificationTopicsGotIt;

  /// No description provided for @notificationTypesLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn about notification types'**
  String get notificationTypesLearnMore;

  /// No description provided for @notificationTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification types'**
  String get notificationTypesTitle;

  /// No description provided for @notificationPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationPushTitle;

  /// No description provided for @notificationPushEnabled.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are enabled on this device.'**
  String get notificationPushEnabled;

  /// No description provided for @notificationPushTapToEnable.
  ///
  /// In en, this message translates to:
  /// **'Tap enable to turn on alerts for this device.'**
  String get notificationPushTapToEnable;

  /// No description provided for @notificationEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get notificationEnable;

  /// No description provided for @notificationTypeScheduleUpdates.
  ///
  /// In en, this message translates to:
  /// **'Schedule updates'**
  String get notificationTypeScheduleUpdates;

  /// No description provided for @notificationTypeScheduleUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified when your shifts are added, removed, or changed.'**
  String get notificationTypeScheduleUpdatesBody;

  /// No description provided for @notificationTypeShiftReminders.
  ///
  /// In en, this message translates to:
  /// **'Shift reminders'**
  String get notificationTypeShiftReminders;

  /// No description provided for @notificationTypeShiftRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'Receive reminders before upcoming shifts start.'**
  String get notificationTypeShiftRemindersBody;

  /// No description provided for @notificationTypeGeneralAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'General announcements'**
  String get notificationTypeGeneralAnnouncements;

  /// No description provided for @notificationTypeGeneralAnnouncementsBody.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop on team-wide updates and important notices.'**
  String get notificationTypeGeneralAnnouncementsBody;

  /// No description provided for @notificationTypeEmail.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get notificationTypeEmail;

  /// No description provided for @notificationTypeEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Also receive the most important updates by email.'**
  String get notificationTypeEmailBody;

  /// No description provided for @notificationDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Debug info'**
  String get notificationDebugInfo;

  /// No description provided for @notificationFcmToken.
  ///
  /// In en, this message translates to:
  /// **'FCM token'**
  String get notificationFcmToken;

  /// No description provided for @notificationNoToken.
  ///
  /// In en, this message translates to:
  /// **'No token available yet'**
  String get notificationNoToken;

  /// No description provided for @notificationTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied'**
  String get notificationTokenCopied;

  /// No description provided for @pushPermissionExplanationBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications so you receive shift reminders, schedule changes, and important team updates right away.'**
  String get pushPermissionExplanationBody;

  /// No description provided for @pushPermissionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pushPermissionNotNow;

  /// No description provided for @pushPermissionEnabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Notifications are enabled.'**
  String get pushPermissionEnabledSuccess;

  /// No description provided for @pushPermissionError.
  ///
  /// In en, this message translates to:
  /// **'We could not enable notifications. Please try again.'**
  String get pushPermissionError;

  /// No description provided for @pushPermissionDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get pushPermissionDisabledTitle;

  /// No description provided for @pushPermissionDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'You can still use the app, but you may miss reminders and urgent updates until notifications are turned back on in your device settings.'**
  String get pushPermissionDisabledBody;

  /// No description provided for @pushPermissionMaybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get pushPermissionMaybeLater;

  /// No description provided for @pushPermissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get pushPermissionOpenSettings;

  /// No description provided for @pushPermissionShortBody.
  ///
  /// In en, this message translates to:
  /// **'Get shift reminders, schedule changes, and team updates delivered to this device.'**
  String get pushPermissionShortBody;

  /// No description provided for @pushPermissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pushPermissionSettings;

  /// No description provided for @pushPermissionRequestError.
  ///
  /// In en, this message translates to:
  /// **'We could not request notification permission. Please try again.'**
  String get pushPermissionRequestError;

  /// No description provided for @availabilitySavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Availability saved successfully.'**
  String get availabilitySavedSuccess;

  /// No description provided for @availabilitySaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving availability: {error}'**
  String availabilitySaveError(String error);

  /// No description provided for @availabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availabilityTitle;

  /// No description provided for @availabilityShiftAvailability.
  ///
  /// In en, this message translates to:
  /// **'Shift availability'**
  String get availabilityShiftAvailability;

  /// No description provided for @availabilityShiftAvailabilityBody.
  ///
  /// In en, this message translates to:
  /// **'Set which shift blocks you are generally available to work each day.'**
  String get availabilityShiftAvailabilityBody;

  /// No description provided for @availabilityEarliestStartTimes.
  ///
  /// In en, this message translates to:
  /// **'Earliest start times'**
  String get availabilityEarliestStartTimes;

  /// No description provided for @availabilityEarliestStartBody.
  ///
  /// In en, this message translates to:
  /// **'Set the earliest time you can usually start for each day of the week.'**
  String get availabilityEarliestStartBody;

  /// No description provided for @availabilityDefaultTime.
  ///
  /// In en, this message translates to:
  /// **'9:00 AM'**
  String get availabilityDefaultTime;

  /// No description provided for @availabilityNotificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get availabilityNotificationPreferences;

  /// No description provided for @availabilityScheduleUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'Stay updated when your published schedule changes.'**
  String get availabilityScheduleUpdatesBody;

  /// No description provided for @availabilityShiftRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'Receive reminders before your shifts begin.'**
  String get availabilityShiftRemindersBody;

  /// No description provided for @availabilityEmailNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Get key updates delivered to your email as well.'**
  String get availabilityEmailNotificationsBody;

  /// No description provided for @availabilityPushNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Allow this device to receive instant alerts.'**
  String get availabilityPushNotificationsBody;

  /// No description provided for @availabilitySavePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get availabilitySavePreferences;

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @shiftLabelMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get shiftLabelMorning;

  /// No description provided for @shiftLabelAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get shiftLabelAfternoon;

  /// No description provided for @shiftLabelEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get shiftLabelEvening;

  /// No description provided for @shiftLabelNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get shiftLabelNight;

  /// No description provided for @upgradeLocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add locations'**
  String get upgradeLocationsTitle;

  /// No description provided for @upgradeLocationsQuantity.
  ///
  /// In en, this message translates to:
  /// **'How many locations do you want to add?'**
  String get upgradeLocationsQuantity;

  /// No description provided for @upgradeLocationsSummary.
  ///
  /// In en, this message translates to:
  /// **'Add {count} location(s) for {price} per month.'**
  String upgradeLocationsSummary(int count, String price);

  /// No description provided for @upgradeLocationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update locations: {error}'**
  String upgradeLocationsFailed(String error);

  /// No description provided for @upgradeLocationsAction.
  ///
  /// In en, this message translates to:
  /// **'Upgrade and pay'**
  String get upgradeLocationsAction;
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
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
