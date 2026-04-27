// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageTitle => 'Language';

  @override
  String get languageDescription =>
      'Choose the language used for your staff experience.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languagePortuguese => 'Portuguese (Brazil)';

  @override
  String get languageSaved => 'Language updated.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonUnarchive => 'Unarchive';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Done';

  @override
  String get commonErrorTitle => 'Error';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRole => 'Role';

  @override
  String get commonName => 'Name';

  @override
  String get commonBackToSignIn => 'Back to Sign In';

  @override
  String get commonGoToSignIn => 'Go to Sign In';

  @override
  String get commonOpenHands => 'Open Hands';

  @override
  String get commonNotSpecified => 'Not specified';

  @override
  String get commonContinueIn => 'Continue in';

  @override
  String get commonWebApp => 'Web App';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginIntroTitle => 'Operations, minus the chaos.';

  @override
  String get loginIntroBody =>
      'Sign in to manage shifts, tasks, documents, and team execution from one place.';

  @override
  String get loginFeatureLiveTaskTracking => 'Live task tracking';

  @override
  String get loginFeatureSharedTeamWorkflows => 'Shared team workflows';

  @override
  String get loginFeatureOperationalVisibility => 'Operational visibility';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginWelcomeBackBody => 'Use your email and password to continue.';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'you@restaurant.com';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNeedAccessTitle => 'Need access?';

  @override
  String get loginNeedAccessBody =>
      'If you need access to an existing organization, ask your manager to send you an invite.';

  @override
  String get loginNeedAccountTitle => 'Need an account?';

  @override
  String get loginNeedAccountBody =>
      'Create a trial organization or accept an invite from your manager.';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String loginVersion(String version) {
    return 'Version $version';
  }

  @override
  String get loginEnterEmail => 'Please enter your email';

  @override
  String get loginEnterValidEmail => 'Please enter a valid email';

  @override
  String get loginEnterPassword => 'Please enter your password';

  @override
  String get loginProfileNotFound =>
      'User profile not found. Please contact support.';

  @override
  String get loginResetPasswordTitle => 'Reset Password';

  @override
  String get loginResetPasswordSubtitle =>
      'Enter the email tied to your Hands account and we’ll send a secure reset link.';

  @override
  String get loginResetPasswordBody =>
      'We’ll send a password reset email right away.';

  @override
  String get loginResetEmailAddressLabel => 'Email address';

  @override
  String get loginResetEmailHint => 'Email Address';

  @override
  String get loginResetSendButton => 'Send Reset Link';

  @override
  String loginResetEmailSent(String email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get loginEnterEmailAddress => 'Please enter your email address.';

  @override
  String get loginEnterValidEmailAddress =>
      'Please enter a valid email address.';

  @override
  String get loginResetFailed => 'Failed to send reset email.';

  @override
  String get loginNoAccountFound => 'No account found with this email address.';

  @override
  String get loginTooManyRequests =>
      'Too many requests. Please try again later.';

  @override
  String get welcomeInviteUnavailable => 'Invite unavailable';

  @override
  String welcomeToOrganization(String organizationName) {
    return 'Welcome to $organizationName!';
  }

  @override
  String welcomeInviteBody(String organizationName) {
    return 'You’ve been invited to join $organizationName. Complete your account setup to get started.';
  }

  @override
  String get welcomeAccountDetails => 'Account Details';

  @override
  String get welcomeCompleteSetupTitle => 'Complete Your Account Setup';

  @override
  String get welcomeCompleteSetupBody =>
      'Create a password to finish setting up your account. Your organization access and role will be applied automatically from this invite.';

  @override
  String get welcomeNewPasswordLabel => 'New Password';

  @override
  String get welcomeNewPasswordHint => 'Create a new password';

  @override
  String get welcomeConfirmPasswordLabel => 'Confirm New Password';

  @override
  String get welcomeConfirmPasswordHint => 'Confirm your new password';

  @override
  String get welcomeEnterNewPassword => 'Please enter a new password';

  @override
  String get welcomePasswordMinLength =>
      'Password must be at least 6 characters';

  @override
  String get welcomeConfirmNewPassword => 'Please confirm your new password';

  @override
  String get welcomePasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get welcomeCompleteSetupButton => 'Complete Setup';

  @override
  String get welcomeAccountSetupCompleteTitle => 'Account Setup Complete';

  @override
  String get welcomeAccountReady => 'Your account is ready to use.';

  @override
  String get welcomeOpenOnWeb =>
      'You can open Hands on the web right now. Mobile app download is optional.';

  @override
  String get welcomeDownloadOnThe => 'Download on the';

  @override
  String get welcomeAppStore => 'App Store';

  @override
  String get welcomeUseSameCredentials =>
      'Use the same email and password you just created anywhere you sign in.';

  @override
  String get welcomeInviteAccepted =>
      'This invite has already been accepted. Sign in with your account to continue.';

  @override
  String get welcomeInviteExpired =>
      'This invite link has expired. Ask your administrator to send you a new invite.';

  @override
  String get welcomeInviteRevoked =>
      'This invite was revoked by your administrator. Ask them to send a new invite if you still need access.';

  @override
  String get welcomeInviteInvalid =>
      'This invite link is not valid or is no longer available.';

  @override
  String get welcomeRoleGeneralUser => 'General User';

  @override
  String get welcomeRoleManager => 'Manager';

  @override
  String get welcomeRoleAdmin => 'Admin';

  @override
  String get welcomeRoleUser => 'User';

  @override
  String welcomeFailedSetup(String error) {
    return 'Failed to set up account: $error';
  }

  @override
  String get welcomeInviteUsed =>
      'This invite has already been used. Sign in with your account instead.';

  @override
  String get welcomeInviteExistingAccount =>
      'An account already exists for this email. Sign in instead, or ask your administrator if you expected a fresh invite.';

  @override
  String get welcomeInviteExpiredError =>
      'This invite has expired. Ask your administrator to send a new one.';

  @override
  String get welcomeInviteRevokedError =>
      'This invite has been revoked. Ask your administrator for a new invite.';

  @override
  String get welcomeInviteMissingEmail => 'Invite is missing an email address.';

  @override
  String get notificationsInbox => 'Inbox';

  @override
  String get notificationsUnread => 'Unread';

  @override
  String get notificationsRead => 'Read';

  @override
  String get notificationsArchived => 'Archived';

  @override
  String get notificationsHeaderSubtitle =>
      'Unread updates, read items, and archived messages.';

  @override
  String get notificationsDeleteTitle => 'Delete Message';

  @override
  String get notificationsDeleteBody =>
      'Are you sure you want to permanently delete this message? This action cannot be undone.';

  @override
  String get notificationsDeleteSuccess => 'Message deleted successfully';

  @override
  String notificationsDeleteFailed(String error) {
    return 'Failed to delete message: $error';
  }

  @override
  String notificationsNoMessagesIn(String filter) {
    return 'No messages in $filter';
  }

  @override
  String get notificationsNewMessage => 'New Message';

  @override
  String get notificationsNoContent => 'No content';

  @override
  String get notificationsLoadMore => 'Load More';

  @override
  String notificationsYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get contactUsTitle => 'Contact Us';

  @override
  String get contactUsSuccess =>
      'Help request sent successfully! We’ll get back to you within 24 hours.';

  @override
  String get contactUsFailed => 'Failed to send help request';

  @override
  String get contactUsNetworkError => 'Network error. Please try again.';

  @override
  String get contactUsOverviewTitle => 'Support, without the back-and-forth.';

  @override
  String get contactUsOverviewBody =>
      'Send one clear request and our team will respond with the right help for setup, billing, bugs, or workflow questions.';

  @override
  String get contactUsTechnicalIssues => 'Technical issues';

  @override
  String get contactUsBillingQuestions => 'Billing questions';

  @override
  String get contactUsTeamSetupHelp => 'Team setup help';

  @override
  String get contactUsWhatToExpect => 'What to expect';

  @override
  String get contactUsTypicalResponse => 'Typical response';

  @override
  String get contactUsTypicalResponseValue => 'Within 24 hours';

  @override
  String get contactUsBestFor => 'Best for';

  @override
  String get contactUsBestForValue => 'Product help, billing, and setup';

  @override
  String get contactUsHelpfulDetails => 'Helpful details';

  @override
  String get contactUsHelpfulDetailsValue =>
      'Location, role, and what happened';

  @override
  String get contactUsSupportContext => 'Support context';

  @override
  String get contactUsSupportContextBody =>
      'We will include the current help and location context automatically.';

  @override
  String get bottomNavTodayTasks => 'Today\'s Tasks';

  @override
  String get bottomNavDashboard => 'Dashboard';

  @override
  String get bottomNavSetup => 'Setup';

  @override
  String get bottomNavDocumentCenter => 'Document Center';

  @override
  String get messagesTitle => 'Communications';

  @override
  String get messagesHeaderSubtitle =>
      'Inbox keeps everyone up to date. Broadcasts send new updates. Audiences organize who receives them.';

  @override
  String get messagesInboxTab => 'Inbox';

  @override
  String get messagesBroadcastsTab => 'Broadcasts';

  @override
  String get messagesAudiencesTab => 'Audiences';

  @override
  String get messagesBroadcastsTitle => 'Broadcasts';

  @override
  String get messagesBroadcastsBody =>
      'Send a clear update to everyone, a location, or a custom audience.';

  @override
  String get messagesBroadcastsHelp =>
      'Use broadcasts for clean team-wide or location-specific updates that should stay visible in Inbox.';

  @override
  String get messagesNewBroadcast => 'New broadcast';

  @override
  String get messagesBroadcastsUnavailable => 'Broadcasts unavailable';

  @override
  String get messagesOrgContextMissing =>
      'We could not determine your organization context.';

  @override
  String get messagesNoBroadcasts => 'No broadcasts yet';

  @override
  String get messagesNoBroadcastsBody =>
      'Your sent updates will appear here once you broadcast to the team.';

  @override
  String get messagesSending => 'Sending...';

  @override
  String get messagesEveryone => 'Everyone';

  @override
  String get messagesCustomAudience => 'Custom audience';

  @override
  String get messagesLocation => 'Location';

  @override
  String get messagesUntitledBroadcast => 'Untitled broadcast';

  @override
  String get messagesAudiencesTitle => 'Audiences';

  @override
  String get messagesAudiencesBody =>
      'Create reusable audience lists so the right team gets the right update every time.';

  @override
  String get messagesAudiencesHelp =>
      'Audiences are reusable recipient groups that help you send the right broadcast to the right team.';

  @override
  String get broadcastSheetTitle => 'New broadcast';

  @override
  String get broadcastSheetSubtitle =>
      'Send a clear update to everyone, a location, or a saved audience.';

  @override
  String get broadcastSendButton => 'Send broadcast';

  @override
  String get broadcastInfoTip =>
      'Broadcasts appear in the team inbox and can also send a push notification.';

  @override
  String get broadcastAudienceSectionTitle => 'Audience';

  @override
  String get broadcastRecipientEveryone => 'Everyone';

  @override
  String get broadcastRecipientSavedAudience => 'Saved audience';

  @override
  String get broadcastRecipientLocation => 'Specific location';

  @override
  String get broadcastSendToLabel => 'Send to';

  @override
  String get broadcastChooseAudience => 'Choose an audience';

  @override
  String get broadcastSelectAudience => 'Select an audience';

  @override
  String get broadcastSelectLocation => 'Select a location';

  @override
  String get broadcastMessageSectionTitle => 'Message';

  @override
  String get broadcastHeadlineLabel => 'Headline';

  @override
  String get broadcastEnterHeadline => 'Enter a headline';

  @override
  String get broadcastMessageLabel => 'Message';

  @override
  String get broadcastMessageHint => 'What should the team know right now?';

  @override
  String get broadcastEnterMessage => 'Enter a message';

  @override
  String get broadcastDismiss => 'Dismiss';

  @override
  String broadcastAutoTitleAudience(String name) {
    return 'Update for $name';
  }

  @override
  String get broadcastAutoTitleAudienceFallback => 'Audience update';

  @override
  String broadcastAutoTitleLocation(String name) {
    return 'Update for $name';
  }

  @override
  String get broadcastAutoTitleLocationFallback => 'Location update';

  @override
  String get broadcastAutoTitleTeam => 'Team update';

  @override
  String get audienceSheetSubtitle =>
      'Create reusable audience lists so managers can target the right team quickly.';

  @override
  String get audienceSavedTitle => 'Saved audiences';

  @override
  String get audienceNewTitle => 'New audience';

  @override
  String get audienceNameLabel => 'Audience name';

  @override
  String get audienceSearchMembers => 'Search team members';

  @override
  String get audienceTeamMembers => 'Team members';

  @override
  String get audienceMembersTitle => 'Audience members';

  @override
  String get audienceCreateButton => 'Create audience';

  @override
  String get audienceEditTitle => 'Edit audience';

  @override
  String get audienceDeleteTitle => 'Delete audience';

  @override
  String get audienceEnterNameAndMember =>
      'Enter an audience name and select at least one team member.';

  @override
  String get audienceCreatedSuccess => 'Audience created successfully!';

  @override
  String get audienceUpdatedSuccess => 'Audience updated successfully!';

  @override
  String get audienceDeletedSuccess => 'Audience deleted successfully!';

  @override
  String audienceDeleteBody(String groupName) {
    return 'Are you sure you want to delete the audience \"$groupName\"? This action cannot be undone.';
  }

  @override
  String get messagesManageAudiences => 'Manage audiences';

  @override
  String get messagesAudiencesUnavailable => 'Audiences unavailable';

  @override
  String get messagesNoAudiences => 'No custom audiences yet';

  @override
  String get messagesNoAudiencesBody =>
      'Start with custom audiences for teams like Bar, Kitchen, or Weekend crew.';

  @override
  String get messagesCustomAudiencesMetric => 'Custom audiences';

  @override
  String get messagesLinkedMembersMetric => 'Linked members';

  @override
  String get messagesUnnamedAudience => 'Unnamed audience';

  @override
  String messagesMemberCount(int count) {
    return '$count members';
  }

  @override
  String get threadTitle => 'Thread';

  @override
  String get threadNoMessages => 'No messages yet';

  @override
  String get threadMessageHint => 'Message';

  @override
  String get threadDeleteTitle => 'Delete Message';

  @override
  String get threadDeleteBody =>
      'Are you sure you want to delete this message? This action cannot be undone.';

  @override
  String get threadDeleteSuccess => 'Message deleted successfully';

  @override
  String threadDeleteFailed(String error) {
    return 'Failed to delete message: $error';
  }

  @override
  String get commonOpen => 'Open';

  @override
  String get commonReplay => 'Replay';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpSubtitle =>
      'Find the fastest way to complete work, set up operations, or fix a problem.';

  @override
  String get helpSearchHint => 'Search help, setup, or troubleshooting';

  @override
  String get helpSearchResultsTitle => 'Search results';

  @override
  String get helpNoSearchResults => 'No help topics matched that search yet.';

  @override
  String helpTopicsFoundForRole(int count, String role) {
    return '$count topics found for $role';
  }

  @override
  String get helpStartHereTitle => 'Start Here';

  @override
  String get helpOpenHelp => 'Open Help';

  @override
  String get helpOpenWalkthrough => 'Open walkthrough';

  @override
  String get helpStartHereSectionSubtitle =>
      'Begin with the shortest path for your role.';

  @override
  String get helpNewHereTitle => 'I\'m new here';

  @override
  String get helpNewHereBody =>
      'Get the role-aware walkthrough of the app without reading every guide first.';

  @override
  String get helpOpenStartHere => 'Open Start Here';

  @override
  String get helpBrowseByRoleTitle => 'Browse by role';

  @override
  String get helpBrowseByRoleBody => 'See only the topics for your job.';

  @override
  String get helpFixProblemTitle => 'Fix a problem';

  @override
  String get helpFixProblemBody => 'Go straight to troubleshooting.';

  @override
  String get helpBrowseByRoleSectionSubtitle =>
      'Switch perspective without changing accounts.';

  @override
  String get helpReplayGuidedTourTitle => 'Replay guided tour';

  @override
  String get helpReplayGuidedTourSubtitle =>
      'Jump back into the in-app walkthrough for your current role whenever you need a refresher.';

  @override
  String get helpWhatsNewTitle => 'What\'s new';

  @override
  String get helpWhatsNewSubtitle =>
      'Reopen the latest major update summary and jump into the guided tour again.';

  @override
  String get helpMajorUpdateAvailable => 'Major update available';

  @override
  String get helpLatestMajorRelease => 'Latest major release';

  @override
  String get helpOpenLatestReleaseUpdateBody =>
      'Open the latest release summary and update instructions for your role.';

  @override
  String get helpOpenLatestReleaseTourBody =>
      'Open the latest release summary and relaunch the guided tour for your role.';

  @override
  String get helpPopularTasksTitle => 'Popular tasks';

  @override
  String helpPopularTasksSubtitle(String role) {
    return 'The most useful guides for $role right now.';
  }

  @override
  String helpRoleBannerTitle(String role) {
    return 'Help for $role';
  }

  @override
  String get helpStillStuckTitle => 'Still stuck?';

  @override
  String get helpStillStuckBody =>
      'Open troubleshooting first or contact support with the issue you are seeing right now.';

  @override
  String get helpContactSupport => 'Contact support';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsHeroTitle => 'Account and workspace settings';

  @override
  String get settingsHeroHelp =>
      'Use Settings for account details, preferences, and support without losing focus on operations.';

  @override
  String get settingsHeroAdminBody =>
      'Manage your profile, business details, billing, and operational preferences from one place.';

  @override
  String get settingsHeroStaffBody =>
      'Manage your profile, password, and notification preferences from one place.';

  @override
  String get settingsPreferencesTitle => 'Preferences';

  @override
  String get settingsPreferencesSaved => 'Preferences saved successfully!';

  @override
  String settingsPreferencesSaveFailed(String error) {
    return 'Failed to save preferences: $error';
  }

  @override
  String get settingsProfileTitle => 'Profile';

  @override
  String get settingsProfileSubtitle =>
      'Your account details and sign-in email.';

  @override
  String get settingsBusinessTitle => 'Business';

  @override
  String get settingsBusinessSubtitle =>
      'Core organization details shown across the app.';

  @override
  String get settingsLocationsTitle => 'Locations';

  @override
  String get settingsLocationsSubtitle =>
      'Manage where your team works and where shifts run.';

  @override
  String get settingsLocationsBody =>
      'Add, review, or adjust locations tied to your organization.';

  @override
  String get settingsLocationSupportEmail =>
      'Please email us at support@planwithhands.com';

  @override
  String get settingsGuidedToursTitle => 'Guided tours';

  @override
  String get settingsGuidedToursSubtitle =>
      'Replay the in-app walkthrough for your current role whenever you need a refresher.';

  @override
  String settingsReplayTour(String role) {
    return 'Replay $role tour';
  }

  @override
  String get settingsWhatsNew => 'What’s new';

  @override
  String get settingsSecurityTitle => 'Security';

  @override
  String get settingsSecuritySubtitle =>
      'Password reset and session-related access controls.';

  @override
  String get settingsResetPassword => 'Reset password';

  @override
  String get settingsSignedInAs => 'Signed in as';

  @override
  String get settingsOrganization => 'Organization';

  @override
  String get settingsSessionTimeout => 'Session Timeout';

  @override
  String get settingsSessionTimeoutSubtitle =>
      'Automatically log out after a period of inactivity';

  @override
  String get settingsSessionTimeoutDone => 'Done';

  @override
  String get settingsSessionTimeout2Hours => '2 Hours';

  @override
  String get settingsSessionTimeout2HoursBody =>
      'High security - auto logout after 2 hours';

  @override
  String get settingsSessionTimeout4Hours => '4 Hours';

  @override
  String get settingsSessionTimeout4HoursBody =>
      'Balanced security - auto logout after 4 hours';

  @override
  String get settingsSessionTimeout8Hours => '8 Hours';

  @override
  String get settingsSessionTimeout8HoursBody =>
      'Recommended - good for work shifts';

  @override
  String get settingsSessionTimeout24Hours => '24 Hours';

  @override
  String get settingsSessionTimeout24HoursBody =>
      'Extended access - logout after 1 day';

  @override
  String get settingsResetEmailInvalid => 'Please enter a valid email address';

  @override
  String settingsResetEmailSentVerified(String email) {
    return 'Password reset sent to verified email $email. Verify your new email to use it for login.';
  }

  @override
  String settingsResetEmailSent(String email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get settingsResetEmailFailed => 'Failed to send reset email';

  @override
  String get settingsResetEmailUserNotFound =>
      'No account found with this email address';

  @override
  String get settingsResetEmailTooManyRequests =>
      'Too many requests. Please try again later';

  @override
  String get settingsSummaryPeriodTitle => 'Select summary period';

  @override
  String get settingsSummaryPeriodCalendar => 'Calendar Day';

  @override
  String get settingsSummaryPeriodCalendarBody =>
      'Today\'s tasks only (6am to 6am)';

  @override
  String get settingsSummaryPeriodBusiness => 'Business Day';

  @override
  String get settingsSummaryPeriodBusinessBody =>
      'Includes last night\'s closing tasks';

  @override
  String get settingsDailySummaryHourTitle => 'Select daily summary hour';

  @override
  String get settingsDailySummaryFixedMinutes => 'Minutes are fixed to :00';

  @override
  String get settingsOrganizationDailySummaryUpdated =>
      'Organization daily summary settings updated!';

  @override
  String settingsOrganizationDailySummaryFailed(String error) {
    return 'Failed to save organization settings: $error';
  }

  @override
  String get settingsDailySummaryEmailTitle => 'Daily Summary Email';

  @override
  String get settingsDailySummaryEmailSubtitle =>
      'Receive daily task completion summaries';

  @override
  String get settingsDailySummaryTimeTitle => 'Daily Summary Time';

  @override
  String get settingsDailySummaryTimeSubtitle =>
      'When to receive your daily summary';

  @override
  String get settingsDailySummaryRateLimitTitle => 'Rate Limit';

  @override
  String get settingsDailySummaryChangeBlocked =>
      'Cannot change the daily summary right now.';

  @override
  String get settingsDailySummaryConfirmTitle => 'Confirm Time Change';

  @override
  String get settingsDailySummaryTimePassedTitle => 'Time Has Passed';

  @override
  String get settingsDailySummaryProceedQuestion =>
      'Proceed with the time change?';

  @override
  String get settingsDailySummarySendNowTitle => 'Send now?';

  @override
  String get settingsDailySummarySendNowBody =>
      'Would you like to send today\'s summary immediately instead of waiting until tomorrow?';

  @override
  String get settingsDailySummarySendNowLater => 'No, wait';

  @override
  String get settingsDailySummarySendNowAction => 'Yes, send now';

  @override
  String get settingsDailySummaryResultSuccess => 'Success';

  @override
  String get settingsDailySummaryResultError => 'Error';

  @override
  String get settingsSummaryPeriodLabel => 'Summary Period';

  @override
  String get settingsSummaryPeriodLabelSubtitle =>
      'Choose if summary includes late-night tasks';

  @override
  String get settingsDashboardMetricsTitle => 'Dashboard Metrics';

  @override
  String get settingsDashboardMetricsSubtitle =>
      'Recalculate dashboard metrics from today';

  @override
  String get settingsRefresh => 'Refresh';

  @override
  String get settingsLoadingSubscriptionData => 'Loading subscription data...';

  @override
  String get settingsLoadingSubscriptionDetails =>
      'Loading subscription details...';

  @override
  String get settingsTrialEndingSoon => 'Trial Ending Soon';

  @override
  String settingsFreeTrialDays(int days) {
    return '$days-Day Free Trial';
  }

  @override
  String settingsTrialContinueUntil(String date) {
    return 'Your trial will continue until $date, but you won\'t be charged.';
  }

  @override
  String settingsTrialChargeOn(String date, int days) {
    return 'You\'re on a $days-day free trial. Your first charge will occur on $date unless canceled.';
  }

  @override
  String get settingsCancelSubscription => 'Cancel Subscription';

  @override
  String get settingsManageBilling => 'Manage Billing';

  @override
  String get settingsBillingPortal => 'Billing Portal';

  @override
  String settingsBillingPortalFailed(String error) {
    return 'Failed to open billing portal: $error';
  }

  @override
  String get settingsTrialAndBilling => 'Trial & Billing';

  @override
  String get settingsSubscriptionManagement => 'Subscription Management';

  @override
  String get settingsPlannedLocations => 'Planned Locations:';

  @override
  String get settingsSubscribedLocations => 'Subscribed Locations:';

  @override
  String get settingsLocationsInUse => 'Locations in Use:';

  @override
  String get settingsMonthlyCost => 'Monthly Cost:';

  @override
  String get settingsStatus => 'Status:';

  @override
  String get settingsSubscriptionOverUsage =>
      'You\'re using more locations than your subscription allows. Please upgrade to avoid service interruption.';

  @override
  String get settingsAddBilling => 'Add Billing';

  @override
  String get settingsManageSubscription => 'Manage Subscription';

  @override
  String get settingsBillingWebOnly =>
      'To manage your subscription, please visit https://planwithhands.com and click \"Login\" on the top right. Subscriptions must be managed via the web portal.';

  @override
  String get settingsBillingPortalWebOnly =>
      'To manage billing, please open this page in Safari or Chrome and visit the billing portal. Subscriptions must be managed via the web portal.';

  @override
  String get settingsTalkToSales => 'Talk to Sales';

  @override
  String get settingsNoOrganizationFound =>
      'No organization found. Please contact support.';

  @override
  String get settingsOrganizationInformation => 'Organization Information';

  @override
  String get settingsOrganizationLabel => 'Organization:';

  @override
  String get settingsBusinessTypeLabel => 'Business Type:';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsActiveLocations => 'Active Locations:';

  @override
  String get settingsNeedHelp => 'Need Help?';

  @override
  String get settingsSupportContactBody =>
      'For subscription management, billing questions, or technical support, please contact us:';

  @override
  String get settingsSupportEmailPrompt =>
      'Please email us at support@planwithhands.com';

  @override
  String get settingsContactSalesBody =>
      'For 5 or more locations, please contact our sales team for a customized plan.';

  @override
  String get settingsSubscriptionUpgraded => 'Subscription upgraded!';

  @override
  String get settingsSubscriptionUpdated => 'Subscription updated!';

  @override
  String settingsSubscriptionUpdateFailed(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get settingsSubscriptionChangeIncrease => 'increase';

  @override
  String get settingsSubscriptionChangeDecrease => 'decrease';

  @override
  String get settingsUpgradeSubscription => 'Upgrade Subscription';

  @override
  String get settingsDowngradeSubscription => 'Downgrade Subscription';

  @override
  String settingsSubscriptionAboutToChange(String change) {
    return 'You\'re about to $change your location subscription:';
  }

  @override
  String get settingsFrom => 'From:';

  @override
  String get settingsTo => 'To:';

  @override
  String settingsLocationsCount(int count) {
    return '$count locations';
  }

  @override
  String get settingsMonthlyChange => 'Monthly change:';

  @override
  String get settingsPerMonth => '/month';

  @override
  String get settingsBillingEffectiveNextCycle =>
      'New billing amount takes effect on your next billing cycle.';

  @override
  String get settingsCurrent => 'Current:';

  @override
  String get settingsInUse => 'In use:';

  @override
  String settingsCannotReduceBelow(int currentUsage) {
    return 'Cannot reduce below $currentUsage (current usage). Delete locations first.';
  }

  @override
  String get settingsNoChanges => 'No Changes';

  @override
  String get settingsUpgrade => 'Upgrade';

  @override
  String get settingsDowngrade => 'Downgrade';

  @override
  String get settingsStatusActive => 'ACTIVE';

  @override
  String get settingsStatusTrial => 'TRIAL';

  @override
  String get settingsStatusPastDue => 'PAST DUE';

  @override
  String get settingsStatusCanceled => 'CANCELED';

  @override
  String get settingsStatusUnpaid => 'UNPAID';

  @override
  String get settingsStatusPending => 'PENDING';

  @override
  String get settingsAccountTitle => 'Account';

  @override
  String get settingsAccountSubtitle =>
      'Device sign-out and irreversible account actions.';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutSubtitle =>
      'This signs you out on this device and returns you to the login screen.';

  @override
  String get settingsSigningOut => 'Signing out...';

  @override
  String settingsSignOutFailed(String error) {
    return 'Failed to sign out: $error';
  }

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountWarningTitle => 'Delete Account?';

  @override
  String get settingsDeleteAccountWarningBody =>
      'This will permanently delete your account and all associated personal data. This action CANNOT be undone.';

  @override
  String get settingsDeleteAccountReinviteBody =>
      'If you proceed and later want to use Hands again, you will need to receive a NEW INVITE from your administrator to re-sign up.';

  @override
  String get settingsDeleteAccountContinueQuestion =>
      'Do you still want to continue?';

  @override
  String get settingsDeleteAccountConfirmAction => 'Yes, Delete';

  @override
  String get settingsDeleteAccountBody =>
      'This will permanently delete your account and all your data. This action cannot be undone.';

  @override
  String get settingsDeleteAccountPasswordPrompt =>
      'Please enter your password to confirm:';

  @override
  String get settingsDeleteAccountPasswordHint => 'Password';

  @override
  String get settingsDeletingAccount => 'Deleting account...';

  @override
  String get settingsDeleteAccountSuccess => 'Account deleted successfully';

  @override
  String get settingsDeleteAccountFailed => 'Failed to delete account';

  @override
  String get settingsDeleteAccountWrongPassword =>
      'Incorrect password. Please try again.';

  @override
  String get settingsDeleteAccountRelogin =>
      'Please log out and log back in, then try again.';

  @override
  String get settingsDeleteAccountTooManyRequests =>
      'Too many failed attempts. Please try again later.';

  @override
  String get settingsAddLocation => 'Add location';

  @override
  String get settingsEdit => 'Edit';

  @override
  String get settingsFirstName => 'First name';

  @override
  String get settingsLastName => 'Last name';

  @override
  String get settingsEditProfileTitle => 'Edit profile';

  @override
  String get settingsEditProfileSubtitle =>
      'Update your name and sign-in email.';

  @override
  String get settingsSaveChanges => 'Save changes';

  @override
  String get settingsProfileSignInRequired => 'Please sign in to edit profile';

  @override
  String get settingsProfileSavedVerifyEmail =>
      'Profile saved. Verify new email.';

  @override
  String get settingsProfileUpdatedSuccess => 'Profile updated successfully!';

  @override
  String get settingsProfileUpdateFailed => 'Failed to update profile';

  @override
  String get settingsProfileErrorReloginToChangeEmail =>
      'Log out/in again to change email';

  @override
  String get settingsProfileErrorEmailInUse => 'Email already in use';

  @override
  String get settingsProfileErrorInvalidEmail => 'Invalid email address';

  @override
  String get settingsFieldEnterFirstName => 'Enter first name';

  @override
  String get settingsFieldEnterLastName => 'Enter last name';

  @override
  String get settingsInvalidEmail => 'Invalid email';

  @override
  String get settingsBusinessName => 'Business name';

  @override
  String get settingsBusinessType => 'Business type';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonHide => 'Hide';

  @override
  String helpSupportRequest(String role) {
    return '$role support request';
  }

  @override
  String helpRolePageTitle(String role) {
    return '$role help';
  }

  @override
  String get helpTroubleshootingTitle => 'Troubleshooting';

  @override
  String get helpTroubleshootingSubtitle =>
      'Fix blockers fast by starting with the symptom you are seeing right now.';

  @override
  String get helpTroubleshootingSearchHint =>
      'Search a problem like missing shift or wrong location';

  @override
  String get helpTroubleshootingIntroTitle =>
      'Troubleshooting works best when you start with the exact symptom.';

  @override
  String get helpTroubleshootingIntroBody =>
      'Check the active location, current role, and screen context first. A lot of issues are actually scoping or setup problems.';

  @override
  String get helpTroubleshootingCommonProblems => 'Common problems';

  @override
  String get helpTroubleshootingResults => 'Results';

  @override
  String get helpTroubleshootingNoResults =>
      'No troubleshooting guides matched that search. Try a simpler symptom or contact support.';

  @override
  String get helpNeedMoreHelpTitle => 'Need more help?';

  @override
  String get helpNeedMoreHelpBody =>
      'Send support the exact issue, location, and screen you were on. We will include the troubleshooting context automatically.';

  @override
  String get helpTopicScreenLabel => 'Help topic';

  @override
  String get helpTopicMissingSubtitle => 'That topic could not be found.';

  @override
  String get helpTopicMissingBody =>
      'The guide you tried to open no longer exists or has not been added yet.';

  @override
  String get helpReturnToHelp => 'Return to Help';

  @override
  String helpMinutes(int count) {
    return '$count min';
  }

  @override
  String get helpWhyThisMatters => 'Why this matters';

  @override
  String get helpDoThisNow => 'Do this now';

  @override
  String get helpWhatGoodLooksLike => 'What good looks like';

  @override
  String get helpCommonMistakes => 'Common mistakes';

  @override
  String helpMoreRoleHelp(String role) {
    return 'More $role help';
  }

  @override
  String get helpRelatedHelp => 'Related help';

  @override
  String get helpStartHerePageSubtitle =>
      'A fast walkthrough of the essentials for your role so you can use the app without guesswork.';

  @override
  String get helpFollowTheseSteps => 'Follow these steps';

  @override
  String get helpKeepGoing => 'Keep going';

  @override
  String get helpRoleStaff => 'Staff';

  @override
  String get helpRoleManager => 'Manager';

  @override
  String get helpRoleAdmin => 'Admin';

  @override
  String get helpRoleStaffShortDescription =>
      'Daily work, shifts, tasks, and carryover';

  @override
  String get helpRoleManagerShortDescription =>
      'Daily oversight, follow-up, and broadcasts';

  @override
  String get helpRoleAdminShortDescription =>
      'Setup, workflows, team access, and operations';

  @override
  String get helpCategoryDailyWork => 'Daily Work';

  @override
  String get helpCategoryDailyWorkDescription =>
      'Get through your shift and finish tasks cleanly.';

  @override
  String get helpCategoryOversight => 'Daily Oversight';

  @override
  String get helpCategoryOversightDescription =>
      'Understand live service and respond to risks fast.';

  @override
  String get helpCategorySetup => 'Operations Setup';

  @override
  String get helpCategorySetupDescription =>
      'Configure the business in the right order.';

  @override
  String get helpCategoryCommunications => 'Communications';

  @override
  String get helpCategoryCommunicationsDescription =>
      'Keep the team aligned with inbox, broadcasts, and audiences.';

  @override
  String get helpCategoryDocuments => 'Documents & Training';

  @override
  String get helpCategoryDocumentsDescription =>
      'Use the Document Center for training, SOPs, and references.';

  @override
  String get helpCategoryAccount => 'Account & Access';

  @override
  String get helpCategoryAccountDescription =>
      'Manage sign-in, locations, access, and profile basics.';

  @override
  String get helpCategorySharedMode => 'Shared Mode';

  @override
  String get helpCategorySharedModeDescription =>
      'Use shared devices safely without losing control.';

  @override
  String get helpCategoryTroubleshooting => 'Troubleshooting';

  @override
  String get helpCategoryTroubleshootingDescription =>
      'Fix blockers fast when work, access, or messages are missing.';

  @override
  String get helpCategoryOperationsControl => 'Operations Control';

  @override
  String get helpCategoryOperationsControlDescription =>
      'Run day-to-day operations and keep setup healthy over time.';

  @override
  String contactUsPrefillSubjectTopic(String topic) {
    return 'Help with $topic';
  }

  @override
  String contactUsPrefillSubjectIssue(String issue) {
    return 'Help with $issue';
  }

  @override
  String contactUsPrefillSubjectScreen(String screen) {
    return 'Help on $screen';
  }

  @override
  String get contactUsPrefillSubjectDefault => 'Support request';

  @override
  String get contactUsPrefillPrompt =>
      'Please describe what happened, what you expected, and any error you saw.';

  @override
  String get contactUsPrefillContextTitle => 'Context';

  @override
  String contactUsPrefillRole(String role) {
    return 'Role: $role';
  }

  @override
  String contactUsPrefillHelpTopic(String topic) {
    return 'Help topic: $topic';
  }

  @override
  String contactUsPrefillScreen(String screen) {
    return 'Screen: $screen';
  }

  @override
  String contactUsPrefillLocation(String location) {
    return 'Location: $location';
  }

  @override
  String contactUsPrefillIssue(String issue) {
    return 'Issue: $issue';
  }

  @override
  String contactUsPrefillRoute(String route) {
    return 'Route: $route';
  }

  @override
  String get contactUsSendRequestTitle => 'Send a request';

  @override
  String get contactUsSendRequestBody =>
      'Keep it short and specific so we can help faster.';

  @override
  String get contactUsAutoContextBody =>
      'This request already includes your help topic, current screen, and active location so support can respond faster.';

  @override
  String get contactUsSubjectLabel => 'Subject';

  @override
  String get contactUsSubjectHint => 'What do you need help with?';

  @override
  String get contactUsMessageLabel => 'Message';

  @override
  String get contactUsMessageHint =>
      'Describe the issue, what you expected, and what happened.';

  @override
  String get contactUsEmailRequired => 'Email is required';

  @override
  String get contactUsValidEmailRequired => 'Enter a valid email';

  @override
  String get contactUsSubjectRequired => 'Subject is required';

  @override
  String get contactUsSubjectMinLength =>
      'Subject must be at least 5 characters';

  @override
  String get contactUsMessageRequired => 'Message is required';

  @override
  String get contactUsMessageMinLength =>
      'Message must be at least 10 characters';

  @override
  String get contactUsSendRequestButton => 'Send request';

  @override
  String get contactUsUrgentIssueNote =>
      'For urgent issues, include the location, affected shift, and any error message you saw.';

  @override
  String get documentsTitle => 'Document Center';

  @override
  String get documentsNoOrganization =>
      'No organization found. Please contact support.';

  @override
  String get documentsUploaded => 'Document uploaded';

  @override
  String get documentsUpdated => 'Document updated';

  @override
  String get documentsDeleteTitle => 'Delete Document';

  @override
  String get documentsDeleteBody =>
      'Are you sure you want to delete this document? This action cannot be undone.';

  @override
  String get documentsDeletedSuccess => 'Document deleted successfully';

  @override
  String documentsDeleteError(String error) {
    return 'Error deleting document: $error';
  }

  @override
  String get documentsAdminSubtitle =>
      'Organize SOPs, training guides, and reference files for every location.';

  @override
  String get documentsStaffSubtitle =>
      'Find the guides, policies, and reference materials you need for this shift.';

  @override
  String get documentsHelpSubtitle =>
      'Use Document Center for SOPs, training, and reference files that support work without cluttering task flows.';

  @override
  String get documentsUpload => 'Upload';

  @override
  String get documentsSearchHint => 'Search by title, category, or file name';

  @override
  String get documentsCurrentScope => 'Current scope';

  @override
  String get documentsAllLocations => 'All Locations';

  @override
  String documentsLocationsCount(int count) {
    return '$count locations';
  }

  @override
  String documentsErrorLoading(String error) {
    return 'Error loading documents: $error';
  }

  @override
  String get documentsVisibleFiles => 'Visible files';

  @override
  String get documentsCategories => 'Categories';

  @override
  String get documentsScope => 'Scope';

  @override
  String get documentsScopeAll => 'All';

  @override
  String get documentsScopeLocal => 'Local';

  @override
  String get documentsBuildLibraryTitle => 'Build your document library';

  @override
  String get documentsNoDocumentsTitle => 'No documents available yet';

  @override
  String get documentsBuildLibraryBody =>
      'Upload SOPs, safety policies, equipment guides, and training files so your team has one clean source of truth.';

  @override
  String get documentsNoDocumentsBody =>
      'Your manager or admin will upload training guides, SOPs, and reference documents here.';

  @override
  String get documentsUploadFirst => 'Upload first document';

  @override
  String documentsNoMatches(String query) {
    return 'No files matched \"$query\" in the current scope.';
  }

  @override
  String get documentsNoLocationDocs =>
      'No documents are available in this location yet.';

  @override
  String documentsNoCategoryDocs(String category) {
    return 'No documents were found in $category.';
  }

  @override
  String get documentsNothingToShow => 'Nothing to show';

  @override
  String get documentsUntitled => 'Untitled';

  @override
  String get documentsTypeVideo => 'Video';

  @override
  String get documentsTypeImage => 'Image';

  @override
  String get documentsTypeDoc => 'Doc';

  @override
  String get documentsGlobal => 'Global';

  @override
  String get documentsLocation => 'Location';

  @override
  String get documentsEditTooltip => 'Edit';

  @override
  String get documentsDeleteTooltip => 'Delete';

  @override
  String documentsAddedDate(String date) {
    return 'Added $date';
  }

  @override
  String get documentsOpenError =>
      'Could not open document. Please check your internet connection.';

  @override
  String documentsOpenErrorDetailed(String error) {
    return 'Error opening document: $error';
  }

  @override
  String get documentsCategoryAll => 'All';

  @override
  String get documentsCategorySafetyProcedures => 'Safety Procedures';

  @override
  String get documentsCategoryCleaningProtocols => 'Cleaning Protocols';

  @override
  String get documentsCategoryTrainingMaterials => 'Training Materials';

  @override
  String get documentsCategoryOperatingProcedures => 'Operating Procedures';

  @override
  String get documentsCategoryEmergencyProcedures => 'Emergency Procedures';

  @override
  String get documentsCategoryEquipmentManuals => 'Equipment Manuals';

  @override
  String get documentsCategoryPolicyDocuments => 'Policy Documents';

  @override
  String get documentsCategoryOther => 'Other';

  @override
  String get documentsViewerOpenExternalTooltip => 'Open in external app';

  @override
  String get documentsViewerDownloadTooltip => 'Download';

  @override
  String get documentsViewerLoading => 'Loading document...';

  @override
  String get documentsViewerErrorTitle => 'Error loading document';

  @override
  String get documentsViewerInvalidUrl => 'Invalid document URL.';

  @override
  String get documentsViewerDownloadFailed => 'Failed to download document.';

  @override
  String get documentsViewerTestBrowser => 'Test URL in Browser';

  @override
  String get documentsViewerRetry => 'Retry';

  @override
  String get documentsViewerNoPath => 'No document path available';

  @override
  String get documentsViewerTrainingDocument => 'Training Document';

  @override
  String get documentsViewerNativeBody =>
      'This document will open in your device\'s native viewer for the best experience.';

  @override
  String get documentsViewerOpenDocument => 'Open Document';

  @override
  String get documentsViewerNativeHelp =>
      'Documents open in your device\'s built-in viewer for optimal performance and features.';

  @override
  String get documentsViewerPdfTitle => 'PDF Document';

  @override
  String get documentsViewerOfficeTitle => 'Office Document';

  @override
  String get documentsViewerWebBody =>
      'Click below to view or download this document';

  @override
  String get documentsViewerViewDocument => 'View Document';

  @override
  String get documentsViewerCopyLink => 'Copy Link';

  @override
  String get documentsViewerTechnicalInfo => 'Technical Information';

  @override
  String get documentsViewerDocumentUrl => 'Document URL:';

  @override
  String get documentsViewerNewTabNote =>
      'Note: Documents open in a new tab due to browser security policies.';

  @override
  String get documentsViewerImageFailed => 'Failed to load image';

  @override
  String get documentsViewerPreviewUnavailable => 'Preview not available';

  @override
  String get documentsViewerUnsupportedPreview =>
      'This file type is not supported for preview';

  @override
  String get documentsViewerOpenExternal => 'Open in External App';

  @override
  String get documentsViewerUrlCopied => 'URL copied to clipboard';

  @override
  String get documentsViewerCopyFailed => 'Failed to copy URL';

  @override
  String get documentsViewerVideoFailed => 'Failed to load video';

  @override
  String get documentsViewerLoadingVideo => 'Loading video...';

  @override
  String get documentsUploadSheetTitle => 'Document';

  @override
  String get documentsUploadSheetLoadingSubtitle =>
      'Loading organization context...';

  @override
  String get documentsUploadSheetMissingOrgSubtitle =>
      'We could not determine your organization.';

  @override
  String get documentsUploadTitle => 'Upload document';

  @override
  String get documentsEditTitle => 'Edit document';

  @override
  String get documentsUploadSubtitle =>
      'Add SOPs, policies, guides, and training files for the team.';

  @override
  String get documentsUpdateButton => 'Update document';

  @override
  String get documentsInfoTip =>
      'Upload PDFs, DOCX files, images, or videos up to 20 MB and place them in the right category.';

  @override
  String get documentsDetails => 'Details';

  @override
  String get documentsDocumentTitleLabel => 'Document title';

  @override
  String get documentsDocumentTitleHint => 'Enter a clear, descriptive title';

  @override
  String get documentsDocumentTitleRequired => 'Please enter a document title';

  @override
  String get documentsCategoryLabel => 'Category';

  @override
  String get documentsCategoryRequired => 'Please select a category';

  @override
  String get documentsReplaceFileOptional => 'Replace file (optional)';

  @override
  String get documentsSelectFile => 'Select file';

  @override
  String get documentsUnknownFile => 'Unknown file';

  @override
  String get documentsChangeFile => 'Change file';

  @override
  String get documentsTapToSelect => 'Tap to select file';

  @override
  String get documentsSupportedFileTypes => 'PDF, DOCX, images, or video';

  @override
  String documentsPickFileError(String error) {
    return 'Error picking file: $error';
  }

  @override
  String get documentsFillRequiredFields => 'Please fill all required fields';

  @override
  String get documentsSelectFileRequired => 'Please select a file';

  @override
  String get documentsMissingOrgId =>
      'Organization ID is missing. Cannot upload document.';

  @override
  String get documentsUserNotAuthenticated =>
      'User not authenticated. Please log in again.';

  @override
  String get documentsFileDataUnavailable =>
      'File data is not available. Please select the file again.';

  @override
  String get documentsUpdatedSuccess => 'Document updated successfully!';

  @override
  String get documentsUploadedSuccess => 'Document uploaded successfully!';

  @override
  String get documentsUploadFailedPrefix => 'Upload failed: ';

  @override
  String get documentsUploadFailedMissingData =>
      'Missing required data. Please try selecting the file again.';

  @override
  String get documentsUploadFailedPermission =>
      'Permission denied. Please check your account permissions.';

  @override
  String get documentsUploadFailedStorage =>
      'Storage error. Please check your internet connection.';

  @override
  String get documentsDismissTip => 'Dismiss';

  @override
  String get scheduleEditorTitle => 'Schedule Editor';

  @override
  String get scheduleMyTitle => 'My Schedule';

  @override
  String get scheduleOrganizationNotFound => 'Organization not found';

  @override
  String get scheduleOrganizationLocationMissing =>
      'Organization or location not set.';

  @override
  String get scheduleLocationLabel => 'Location';

  @override
  String get schedulePickDateRange => 'Pick a date range';

  @override
  String get scheduleSelectDateRange => 'Select Date Range';

  @override
  String get scheduleNext7Days => 'Next 7 Days';

  @override
  String scheduleDaysWindow(int start, int end) {
    return 'Days $start-$end';
  }

  @override
  String get scheduleSelectLocationAndDateRange =>
      'Select a location and date range to view schedule';

  @override
  String get schedulePublishSchedule => 'Publish Schedule';

  @override
  String get scheduleCreateTemplateFirst =>
      'Please create shift template first from admin dashboard';

  @override
  String get schedulePublishAllSuccess =>
      'All schedules published successfully!';

  @override
  String schedulePublishError(String error) {
    return 'Error publishing schedules: $error';
  }

  @override
  String scheduleDayPublished(String date) {
    return '$date schedule published!';
  }

  @override
  String scheduleDayPublishError(String error) {
    return 'Error publishing schedule: $error';
  }

  @override
  String get scheduleNoPublishedShifts => 'No published shifts.';

  @override
  String scheduleAssignedCount(int count) {
    return 'Assigned: $count';
  }

  @override
  String scheduleUsersLabel(String users) {
    return 'Users: $users';
  }

  @override
  String get scheduleAssignedStatus => 'Assigned';

  @override
  String get scheduleShiftsHeader => 'Shifts';

  @override
  String get scheduleAssignedCell => 'assigned';

  @override
  String scheduleShiftTemplatesError(String error) {
    return 'Error loading shifts: $error';
  }

  @override
  String get scheduleNoShiftTemplates =>
      'No shift templates found for this location.\nCreate shift templates from the Admin Dashboard first.';

  @override
  String get scheduleUnnamedShift => 'Unnamed Shift';

  @override
  String scheduleMessageTitle(String start, String end) {
    return 'Your Schedule $start to $end';
  }

  @override
  String scheduleMessageLine(
    String date,
    String shiftName,
    String startTime,
    String endTime,
  ) {
    return '$date: $shiftName ($startTime - $endTime)';
  }

  @override
  String get dashboardSwitch => 'Switch';

  @override
  String dashboardLocationsCount(int count) {
    return '$count locations';
  }

  @override
  String get dashboardNoActiveShift => 'No Active Shift';

  @override
  String get dashboardNothingAssignedTitle => 'Nothing is assigned right now';

  @override
  String dashboardNothingAssignedBody(String locationName) {
    return 'You are set to work at $locationName. Pick up an available shift when you are ready.';
  }

  @override
  String get dashboardSeeAvailableShifts => 'See Available Shifts';

  @override
  String get dashboardNoVisibleShiftTitle => 'No visible shift right now';

  @override
  String get dashboardNoVisibleShiftBody =>
      'Your assigned shifts may have ended, or your next shift is not yet available to start.';

  @override
  String get dashboardMomentumBody =>
      'Keep momentum moving when today\'s assigned work is in shape.';

  @override
  String get dashboardLoadingTasks => 'Loading today\'s tasks...';

  @override
  String get dashboardNoTasksForShift =>
      'No tasks are available for this shift yet.';

  @override
  String get dashboardEverythingCompleteShift =>
      'Everything for this shift is complete.';

  @override
  String dashboardTasksLeftShort(int count) {
    return '$count left';
  }

  @override
  String dashboardBlockedShort(int count) {
    return '$count blocked';
  }

  @override
  String dashboardNeedPhotosShort(int count) {
    return '$count need photos';
  }

  @override
  String get dashboardProgress => 'Progress';

  @override
  String get dashboardWaitingForTasks => 'Waiting for tasks';

  @override
  String dashboardCompletedOfTotal(int completed, int total) {
    return '$completed of $total done';
  }

  @override
  String get dashboardRemaining => 'Remaining';

  @override
  String get dashboardTasksLeftInShift => 'Tasks left in this shift';

  @override
  String get dashboardAttention => 'Attention';

  @override
  String get dashboardPhotos => 'Photos';

  @override
  String get dashboardBlockedOrFlagged => 'Blocked or flagged';

  @override
  String get dashboardNeedPhotoProof => 'Need photo proof';

  @override
  String get dashboardReviewTodaysWork => 'Review Today\'s Work';

  @override
  String get dashboardContinueWorking => 'Continue Working';

  @override
  String get dashboardViewFullShift => 'View Full Shift';

  @override
  String get dashboardNextUp => 'Next Up';

  @override
  String get dashboardNoRemainingTasks =>
      'No remaining tasks in this shift right now.';

  @override
  String get dashboardFastestPath =>
      'The fastest path to finishing this shift.';

  @override
  String get dashboardNextUpHelpSubtitle =>
      'Next Up shows the fastest path through the unfinished tasks in your current shift.';

  @override
  String dashboardQueuedCount(int count) {
    return '$count queued';
  }

  @override
  String get dashboardNoTasksAvailableYet => 'No tasks available yet';

  @override
  String get dashboardCaughtUp => 'You\'re caught up on this shift';

  @override
  String get dashboardCheckChecklistSetup =>
      'If this looks wrong, ask your manager to check this shift\'s checklist setup.';

  @override
  String get dashboardReviewCompletedOrPickShift =>
      'Use the section below to review completed work or pick up another shift.';

  @override
  String get dashboardCurrentShift => 'Current Shift';

  @override
  String get dashboardLeaveShift => 'Leave shift';

  @override
  String dashboardPendingTasksRemaining(int count) {
    return '$count remaining';
  }

  @override
  String dashboardListsCount(int count) {
    return '$count lists';
  }

  @override
  String get dashboardNoTasksAvailableForShift =>
      'No tasks available for this shift';

  @override
  String get dashboardAskManagerVerifyChecklist =>
      'If this seems wrong, ask your manager to verify today\'s checklist setup.';

  @override
  String get dashboardChecklistFallback => 'Checklist';

  @override
  String get dashboardChecklistTasksLoading =>
      'Tasks are loading for this checklist';

  @override
  String dashboardChecklistCompletedOfTotal(int completed, int total) {
    return '$completed of $total tasks complete';
  }

  @override
  String dashboardNeedPhotoChip(int count) {
    return '$count need photo';
  }

  @override
  String get dashboardEverythingHereComplete => 'Everything here is complete';

  @override
  String get dashboardCompletedBelow =>
      'Completed work is tucked below for quick review.';

  @override
  String dashboardHideCompleted(int count) {
    return 'Hide completed ($count)';
  }

  @override
  String dashboardShowCompleted(int count) {
    return 'Show completed ($count)';
  }

  @override
  String dashboardNeedsAttention(String reason) {
    return 'Needs attention: $reason';
  }

  @override
  String get dashboardPhotoRequiredBeforeSignoff =>
      'Photo required before sign-off';

  @override
  String get dashboardReadyToComplete => 'Ready to complete';

  @override
  String get dashboardMustBeLoggedIn =>
      'You must be logged in to complete tasks';

  @override
  String get dashboardPhotoRequiredTitle => 'Photo required';

  @override
  String get dashboardPhotoRequiredBody =>
      'This task requires a photo. Add a photo now, complete without a photo, or cancel.';

  @override
  String get dashboardCompleteWithoutPhoto => 'Complete without photo';

  @override
  String get dashboardAddPhoto => 'Add photo';

  @override
  String get dashboardAddNoteRequiredTitle => 'Add note (required)';

  @override
  String get dashboardAddNoteRequiredBody =>
      'Please add a brief note explaining why no photo was added.';

  @override
  String get dashboardEnterNote => 'Enter note...';

  @override
  String get dashboardSave => 'Save';

  @override
  String get dashboardTaskCompleted => 'Task completed!';

  @override
  String get dashboardTaskUnchecked => 'Task unchecked';

  @override
  String get dashboardTaskUpdateError =>
      'Error updating task. Please try again.';

  @override
  String get dashboardCompleted => 'Completed';

  @override
  String dashboardCompletedBy(String name) {
    return 'Completed by $name';
  }

  @override
  String get dashboardPhotoAdded => 'Photo added';

  @override
  String get dashboardPhotoRequiredChip => 'Photo required';

  @override
  String get dashboardNoteAdded => 'Note added';

  @override
  String get dashboardBlocked => 'Blocked';

  @override
  String get dashboardPhotoMenu => 'Photo';

  @override
  String get dashboardNotesMenu => 'Notes';

  @override
  String get dashboardCannotComplete => 'Cannot Complete';

  @override
  String get dashboardMarkIncomplete => 'Mark Incomplete';

  @override
  String get dashboardComplete => 'Complete';

  @override
  String get dashboardViewPhoto => 'View Photo';

  @override
  String get dashboardUpdateIssue => 'Update Issue';

  @override
  String get dashboardCantDo => 'Can\'t Do';

  @override
  String get dashboardEditNote => 'Edit Note';

  @override
  String get dashboardAddNote => 'Add Note';

  @override
  String get dashboardSwitchLocationTitle => 'Switch Location';

  @override
  String get dashboardSwitchLocationBody =>
      'Choose where you want to view and complete work.';

  @override
  String get dashboardUnnamedLocation => 'Unnamed Location';

  @override
  String get dashboardCurrentlySelectedLocation => 'Currently selected';

  @override
  String get dashboardSwitchLocationError =>
      'Could not switch locations. Please try again.';

  @override
  String get dashboardMissedTaskNotCompletedYesterday =>
      'Not completed yesterday';

  @override
  String get dashboardNoteChip => 'Note';

  @override
  String get dashboardReasonChip => 'Reason';

  @override
  String get dashboardClearNotes => 'Clear Notes';

  @override
  String get dashboardClearReason => 'Clear Reason';

  @override
  String dashboardAlreadySignedUpForShift(String shiftName) {
    return 'You are already signed up for $shiftName.';
  }

  @override
  String dashboardJoinedShift(String shiftName) {
    return 'Successfully joined $shiftName!';
  }

  @override
  String get dashboardJoinShiftError =>
      'Error joining shift. Please try again.';

  @override
  String get dashboardMustBeLoggedInToLeaveShift =>
      'You must be logged in to leave shifts';

  @override
  String get dashboardLeaveVolunteerShiftTitle => 'Leave Volunteer Shift';

  @override
  String dashboardLeaveVolunteerShiftBody(String shiftName) {
    return 'Are you sure you want to leave the \"$shiftName\" volunteer shift? This will remove you from future assignments for this shift.';
  }

  @override
  String get dashboardLeaveShiftConfirm => 'Leave Shift';

  @override
  String get dashboardLeftVolunteerShift =>
      'Successfully left volunteer shift!';

  @override
  String get dashboardLeaveShiftError =>
      'Error leaving shift. Please try again.';

  @override
  String get dashboardAvailableShiftsTitle => 'Available shifts';

  @override
  String dashboardAvailableShiftsSubtitle(String locationName) {
    return 'Select a shift to begin working at $locationName';
  }

  @override
  String get dashboardAvailableShiftsLoadError => 'Error loading shifts';

  @override
  String get dashboardNoAvailableShiftsTitle => 'No available shifts';

  @override
  String get dashboardNoAvailableShiftsBody =>
      'There are no shifts available for you to join today.';

  @override
  String get dashboardNoAvailableShiftsTiming =>
      'Shifts will become available to select 30 minutes before their start time.';

  @override
  String get dashboardJoin => 'Join';

  @override
  String get dashboardTaskNotesTitle => 'Task Notes';

  @override
  String dashboardTaskLabel(String taskName) {
    return 'Task: $taskName';
  }

  @override
  String get dashboardUnknownTask => 'Unknown Task';

  @override
  String get dashboardTaskNotesPrompt =>
      'Add notes or comments about this task:';

  @override
  String get dashboardNotesSaved => 'Notes saved successfully!';

  @override
  String dashboardNotesSaveError(String error) {
    return 'Error saving notes: $error';
  }

  @override
  String get dashboardNotesCleared => 'Notes cleared';

  @override
  String dashboardNotesClearError(String error) {
    return 'Failed to clear notes: $error';
  }

  @override
  String get dashboardSaveNotes => 'Save Notes';

  @override
  String get dashboardEnterNotesHint => 'Enter your notes here...';

  @override
  String get dashboardSavingNotes => 'Saving notes...';

  @override
  String get dashboardPhotoViewerResetZoom => 'Reset Zoom';

  @override
  String get dashboardPhotoViewerLoadingImage => 'Loading image...';

  @override
  String get dashboardPhotoViewerLoadError => 'Failed to load image';

  @override
  String get dashboardPhotoViewerGestureHint =>
      'Pinch to zoom • Drag to pan • Tap reset to fit screen';

  @override
  String get dashboardReasonEquipmentUnavailable => 'Equipment not available';

  @override
  String get dashboardReasonSuppliesMissing => 'Supplies missing';

  @override
  String get dashboardReasonNotEnoughTime => 'Not enough time';

  @override
  String get dashboardReasonSafetyConcern => 'Safety concern';

  @override
  String get dashboardReasonWaitingApproval => 'Waiting for approval';

  @override
  String get dashboardReasonAreaBlocked => 'Area blocked/inaccessible';

  @override
  String get dashboardReasonTechnicalIssue => 'Technical issue';

  @override
  String get dashboardReasonStaffShortage => 'Staff shortage';

  @override
  String get dashboardReasonEmergencyPriority => 'Emergency priority task';

  @override
  String get dashboardReasonWeatherConditions => 'Weather conditions';

  @override
  String get dashboardReasonOther => 'Other (specify below)';

  @override
  String get dashboardReasonSpecifyText =>
      'Please specify a reason in the text field';

  @override
  String get dashboardReasonSelectOrEnter => 'Please select or enter a reason';

  @override
  String get dashboardReasonSaved => 'Reason saved successfully!';

  @override
  String dashboardReasonSaveError(String error) {
    return 'Error saving reason: $error';
  }

  @override
  String get dashboardTaskNotCompletedTitle => 'Task Not Completed';

  @override
  String get dashboardSaveReason => 'Save Reason';

  @override
  String get dashboardTaskNotCompletedPrompt =>
      'Why was this task not completed?';

  @override
  String get dashboardEnterReasonHint => 'Please specify the reason...';

  @override
  String get dashboardSavingReason => 'Saving reason...';

  @override
  String get dashboardLoadingCarryover => 'Loading carryover...';

  @override
  String get dashboardCurrentLocationLabel => 'Current Location';

  @override
  String get dashboardWorkingLocationLabel => 'Working Location';

  @override
  String get dashboardLocationHelpTitle => 'Location help';

  @override
  String get dashboardLocationHelpSubtitle =>
      'The active location controls which shifts, tasks, and documents you see on this page.';

  @override
  String get dashboardSharedModeTitle => 'Shared Mode';

  @override
  String get dashboardSharedModeLocked =>
      'Locked — select your name to continue';

  @override
  String dashboardSharedModeActive(String userName) {
    return 'Active: $userName';
  }

  @override
  String get dashboardCarryoverClearTitle => 'Carryover is clear';

  @override
  String get dashboardCarryoverClearBody => 'No missed tasks from yesterday.';

  @override
  String get dashboardCarryoverTitle => 'Carryover from Yesterday';

  @override
  String get dashboardCarryoverHelpTitle => 'Carryover from Yesterday';

  @override
  String get dashboardCarryoverHelpSubtitle =>
      'Carryover keeps unfinished work visible so it can be completed or blocked with context instead of disappearing.';

  @override
  String dashboardTasksCompletedCount(int completed, int total) {
    return '$completed of $total tasks completed';
  }

  @override
  String dashboardShiftTaskSummary(int shiftCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      shiftCount,
      locale: localeName,
      other: 'shifts',
      one: 'shift',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: 'tasks',
      one: 'task',
    );
    return '$shiftCount $_temp0 • $taskCount $_temp1';
  }

  @override
  String get dashboardUnknownShift => 'Unknown Shift';

  @override
  String get dashboardShiftTimingScheduled => 'Scheduled';

  @override
  String get dashboardShiftTimingCheckDetails => 'Check timing details';

  @override
  String get dashboardShiftTimingStartsSoon => 'Starts Soon';

  @override
  String get dashboardShiftTimingAvailableNow => 'Available now';

  @override
  String dashboardShiftTimingAvailableInMinutes(int minutes) {
    return 'Available in ${minutes}m';
  }

  @override
  String get dashboardShiftTimingInProgress => 'In Progress';

  @override
  String dashboardShiftTimingHoursLeft(int hours) {
    return '${hours}h left';
  }

  @override
  String dashboardShiftTimingMinutesLeft(int minutes) {
    return '${minutes}m left';
  }

  @override
  String get dashboardShiftTimingGracePeriod => 'Grace Period';

  @override
  String get dashboardShiftTimingJustEnded => 'Shift just ended';

  @override
  String dashboardShiftTimingEndedMinutesAgo(int minutes) {
    return 'Ended ${minutes}m ago';
  }

  @override
  String get dashboardShiftTimingCheckCurrentWork => 'Check current work';

  @override
  String get dashboardTourLocationTitle => 'Start with the active location';

  @override
  String get dashboardTourLocationDescription =>
      'Tasks, shifts, carryover, broadcasts, and documents all follow the selected location. Switch here before you start working.';

  @override
  String get dashboardTourShiftLiveTitle => 'Check your shift summary first';

  @override
  String get dashboardTourShiftIdleTitle =>
      'This is where your shift status appears';

  @override
  String get dashboardTourShiftLiveDescription =>
      'Your shift hero shows what shift you are on, how much work is left, and whether anything is blocked or waiting for proof.';

  @override
  String get dashboardTourShiftIdleDescription =>
      'If you have no live shift yet, this area tells you whether to wait, pick up another shift, or ask your manager to check setup.';

  @override
  String get dashboardTourNextUpTitle => 'Use Next Up as your main work queue';

  @override
  String get dashboardTourNextUpDescription =>
      'Next Up surfaces the fastest path through unfinished work so you do not have to scan every checklist manually.';

  @override
  String get dashboardTourTodaysWorkTitle =>
      'Review full checklists in Today\'s Work';

  @override
  String get dashboardTourTodaysWorkDescription =>
      'Use this section when you need the full checklist view for your shift, completed tasks, or deeper task context beyond the top queue.';

  @override
  String get commonAdd => 'Add';

  @override
  String get managerDashboardActiveShifts => 'Active shifts';

  @override
  String get managerDashboardActiveShiftLiveNowOne => '1 shift live now';

  @override
  String managerDashboardActiveShiftLiveNowOther(int count) {
    return '$count shifts live now';
  }

  @override
  String get managerDashboardAtRisk => 'At risk';

  @override
  String get managerDashboardNoShiftsSlipping => 'No shifts slipping';

  @override
  String get managerDashboardNeedInterventionNow => 'Need intervention now';

  @override
  String get managerDashboardOpenTasks => 'Open tasks';

  @override
  String get managerDashboardNoTrackedTasksYet => 'No tracked tasks yet';

  @override
  String managerDashboardCompletedTracked(int completed, int total) {
    return '$completed/$total complete';
  }

  @override
  String get managerDashboardCarryover => 'Carryover';

  @override
  String get managerDashboardYesterdayFinishedCleanly =>
      'Yesterday finished cleanly';

  @override
  String managerDashboardShiftsAffected(int count) {
    return '$count shifts affected';
  }

  @override
  String get managerDashboardTourSummaryTitle => 'Start with the summary card';

  @override
  String get managerDashboardTourSummaryDescription =>
      'This top card tells you whether service is on track, how many shifts are at risk, and what needs your attention right now.';

  @override
  String get managerDashboardTourIssuesTitle =>
      'Use Today at Risk as your action queue';

  @override
  String get managerDashboardTourIssuesDescription =>
      'Open these issues first when something slips. They help you prioritize missed work, live risks, and the next follow-up.';

  @override
  String get managerDashboardTourReadinessTitle =>
      'Shift Readiness shows the live board';

  @override
  String get managerDashboardTourReadinessDescription =>
      'Use this section to inspect open work, shift progress, and which runs are healthy versus drifting behind.';

  @override
  String get managerDashboardCurrentLocation => 'Current location';

  @override
  String get managerDashboardLoading => 'Loading dashboard';

  @override
  String managerDashboardIssuesNeedAttention(int count) {
    return '$count issues need attention';
  }

  @override
  String get managerDashboardTodayOnTrack => 'Today is on track';

  @override
  String managerDashboardLoadingSummary(String locationName) {
    return 'Pulling today\'s shifts, missed work, and recurring issue signals for $locationName.';
  }

  @override
  String get managerDashboardThisLocation => 'this location';

  @override
  String managerDashboardIssuesSummary(int riskCount, int openTaskCount) {
    return '$riskCount shifts are currently at risk and $openTaskCount open tasks still need manager attention.';
  }

  @override
  String get managerDashboardNoLiveShiftsSummary =>
      'No live shifts are currently off track. Use the dashboard below to check readiness and recurring issues.';

  @override
  String get managerDashboardRefreshNow => 'Refresh now';

  @override
  String get managerDashboardReviewIssues => 'Review Issues';

  @override
  String get managerDashboardViewShiftReadiness => 'View Shift Readiness';

  @override
  String get managerDashboardHistoryReports => 'History & Reports';

  @override
  String get managerDashboardTodayAtRisk => 'Today at Risk';

  @override
  String get managerDashboardTodayAtRiskSubtitle =>
      'Compact action queue for what needs attention first.';

  @override
  String get managerDashboardShiftReadiness => 'Shift Readiness';

  @override
  String get managerDashboardShiftReadinessSubtitle =>
      'Live board of progress, open work, and shift health.';

  @override
  String get managerDashboardNoScheduledShiftsYet => 'No scheduled shifts yet';

  @override
  String get managerDashboardNoScheduledShiftsBody =>
      'Create and run shifts to see readiness here.';

  @override
  String get managerDashboardRecurringIssues => 'Recurring Issues';

  @override
  String get managerDashboardRecurringIssuesSubtitle =>
      'Where misses and weak runs keep showing up.';

  @override
  String get managerDashboardRecurringFailures => 'Recurring Failures';

  @override
  String get managerDashboardRecurringFailuresSubtitle =>
      'Ranked by miss rate over the last 30 days.';

  @override
  String get managerDashboardNoRecurringFailuresYet =>
      'No recurring failures yet.';

  @override
  String get managerDashboardAtRiskShifts => 'At-Risk Shifts';

  @override
  String get managerDashboardAtRiskShiftsSubtitle =>
      'Shifts with the weakest completion trends over the last 30 days.';

  @override
  String get managerDashboardNoAtRiskShifts => 'No at-risk shifts found.';

  @override
  String get managerDashboardAllMissedTasksYesterday =>
      'All Missed Tasks Yesterday';

  @override
  String get managerDashboardUnknownTask => 'Unknown Task';

  @override
  String get managerDashboardUnknownShift => 'Unknown Shift';

  @override
  String get managerDashboardDoneToday => 'Done today';

  @override
  String get adminSetupTourWelcomeTitle =>
      'Welcome back — we’ll show you what’s new';

  @override
  String get adminSetupTourWelcomeDescription =>
      'Setup has been refreshed to make locations, team, shifts, and checklist templates easier to manage. This quick tour will show you the updated flow before you start editing.';

  @override
  String get adminSetupTourLocationTitle => 'Keep setup scoped to one location';

  @override
  String get adminSetupTourLocationDescription =>
      'Switch here when you want to focus on one restaurant. Shifts, team access, and checklist templates all become easier to manage when you narrow the location.';

  @override
  String get adminSetupTourAreasTitle => 'Move through setup by area';

  @override
  String get adminSetupTourAreasDescription =>
      'Use these quick setup areas to jump between Locations, Team, Shifts, and Checklist Library without losing your place.';

  @override
  String get adminSetupTourPanelTitle => 'Work in one setup area at a time';

  @override
  String get adminSetupTourPanelDescription =>
      'The main panel below is where you add, edit, and review the current setup area. Keep the selected location and setup area in sync as you configure operations.';

  @override
  String get adminSetupActiveLocation => 'Active location';

  @override
  String get adminSetupSelectLocation => 'Select location';

  @override
  String get adminSetupAreas => 'Setup areas';

  @override
  String get adminViewLocations => 'Locations';

  @override
  String get adminViewTeam => 'Team';

  @override
  String get adminViewShifts => 'Shifts';

  @override
  String get adminViewChecklistLibrary => 'Checklist Library';

  @override
  String get adminViewEyebrowPlaces => 'Places';

  @override
  String get adminViewEyebrowPeople => 'People';

  @override
  String get adminViewEyebrowOperations => 'Operations';

  @override
  String get adminViewEyebrowChecklistTemplates => 'Checklist Templates';

  @override
  String get adminViewLocationsSubtitle =>
      'Manage the places your team operates from and keep setup anchored to real locations.';

  @override
  String get adminViewTeamSubtitle =>
      'Invite staff, assign access, and keep every role aligned to the right locations.';

  @override
  String get adminViewShiftsSubtitle =>
      'Set when work happens and attach the right workflow to each shift.';

  @override
  String get adminViewChecklistLibrarySubtitle =>
      'Keep reusable checklist templates for opening, closing, prep, and repeatable routines.';

  @override
  String get adminSetupHeroTitle => 'Operations Setup';

  @override
  String get adminSetupAllLocations => 'All locations';

  @override
  String get adminWorkflowNoneAttached => 'No workflow attached yet';

  @override
  String get adminWorkflowOneAttached => '1 workflow attached';

  @override
  String adminWorkflowManyAttached(int count) {
    return '$count workflows attached';
  }

  @override
  String adminWorkflowTitle(String name) {
    return '$name workflow';
  }

  @override
  String get adminNoOrganizationDataAvailable =>
      'No organization data available';

  @override
  String adminErrorLoadingUsers(String error) {
    return 'Error loading users: $error';
  }

  @override
  String adminErrorLoadingLocations(String error) {
    return 'Error loading locations: $error';
  }

  @override
  String get adminNoTeamMembersFound => 'No team members found';

  @override
  String get adminInviteTeamToGetStarted => 'Invite your team to get started';

  @override
  String get adminUnnamedUser => 'Unnamed User';

  @override
  String get adminDeleteUserTitle => 'Delete User';

  @override
  String get adminDeleteUserBody =>
      'Are you sure you want to delete this user? This action cannot be undone.';

  @override
  String get adminNoLocationsFound => 'No locations found';

  @override
  String get adminAddLocationToGetStarted => 'Add a location to get started';

  @override
  String get adminNoShiftsForSelectedLocation =>
      'No shifts found for selected location';

  @override
  String get adminNoShiftsFound => 'No shifts found';

  @override
  String get adminCreateShiftsAttachWorkflows =>
      'Create shifts, then attach workflows to them';

  @override
  String get webAdminWorkflowLabel => 'Workflow';

  @override
  String get webAdminWorkflowCreated => 'Workflow created successfully';

  @override
  String get webAdminScheduleDaily => 'Daily';

  @override
  String get webAdminDayMon => 'Mon';

  @override
  String get webAdminDayTue => 'Tue';

  @override
  String get webAdminDayWed => 'Wed';

  @override
  String get webAdminDayThu => 'Thu';

  @override
  String get webAdminDayFri => 'Fri';

  @override
  String get webAdminDaySat => 'Sat';

  @override
  String get webAdminDaySun => 'Sun';

  @override
  String get webAdminSidebarSubtitle =>
      'Configure places, people, shifts, and reusable workflows.';

  @override
  String get webAdminSetupWorkspace => 'Setup workspace';

  @override
  String get webAdminScope => 'Scope';

  @override
  String get webAdminAllActive => 'All active';

  @override
  String webAdminSearchHint(String name) {
    return 'Search $name...';
  }

  @override
  String webAdminAddItem(String name) {
    return 'Add $name';
  }

  @override
  String get webAdminSectionEyebrowShifts => 'Operational setup';

  @override
  String get webAdminSectionEyebrowChecklists => 'Checklist templates';

  @override
  String get webAdminSectionEyebrowUsers => 'People & access';

  @override
  String get webAdminSectionEyebrowLocations => 'Business footprint';

  @override
  String get webAdminSectionTitleShifts =>
      'Build shifts around real service workflows';

  @override
  String get webAdminSectionTitleChecklists =>
      'Maintain a clean workflow library';

  @override
  String get webAdminSectionTitleUsers => 'Manage your team with less friction';

  @override
  String get webAdminSectionTitleLocations =>
      'Keep every location ready to operate';

  @override
  String get webAdminSectionSubtitleShifts =>
      'Define when work happens, who it belongs to, and which workflow template runs during that shift.';

  @override
  String get webAdminSectionSubtitleChecklists =>
      'Create reusable checklist templates for opening, closing, prep, and recurring procedures across your operation.';

  @override
  String get webAdminSectionSubtitleUsers =>
      'Invite managers and staff, assign their locations, and keep access aligned with the way the business runs.';

  @override
  String get webAdminSectionSubtitleLocations =>
      'Set up the places your team operates from, and use them to organize shifts, staffing, and workflow coverage.';

  @override
  String get webAdminSectionTableSubtitleShifts =>
      'Shift-centered setup with direct workflow visibility.';

  @override
  String get webAdminSectionTableSubtitleChecklists =>
      'Checklist templates stay reusable here and get attached from shifts.';

  @override
  String get webAdminSectionTableSubtitleUsers =>
      'People, roles, invite state, and location coverage.';

  @override
  String get webAdminSectionTableSubtitleLocations =>
      'Your active places, addresses, and operating footprint.';

  @override
  String get webAdminTabShift => 'Shift';

  @override
  String get webAdminTabTemplate => 'Template';

  @override
  String get webAdminTabTeamMember => 'Team Member';

  @override
  String get webAdminTabLocation => 'Location';

  @override
  String get webAdminEmptyTitleShifts => 'No Shifts Created Yet';

  @override
  String get webAdminEmptyDescriptionShifts =>
      'Create your first shift to define when work happens, who works it, and which workflow should run. Shifts are the main place to set up operations.';

  @override
  String get webAdminEmptyActionShifts => 'Create Your First Shift';

  @override
  String get webAdminEmptySupportLabelShifts => 'Next step';

  @override
  String get webAdminEmptySupportValueShifts => 'Attach workflow';

  @override
  String get webAdminEmptySecondaryLabelShifts => 'Recommended';

  @override
  String get webAdminEmptySecondaryValueShifts => 'Start with opening';

  @override
  String get webAdminEmptyTitleChecklists => 'No Checklist Templates Yet';

  @override
  String get webAdminEmptyDescriptionChecklists =>
      'Build reusable checklist templates for opening, closing, prep, and other repeatable work. Most owners will attach these from the Shifts screen.';

  @override
  String get webAdminEmptyActionChecklists => 'Create Your First Template';

  @override
  String get webAdminEmptySupportLabelChecklists => 'Best use';

  @override
  String get webAdminEmptySupportValueChecklists => 'Reusable workflows';

  @override
  String get webAdminEmptySecondaryLabelChecklists => 'Most common';

  @override
  String get webAdminEmptySecondaryValueChecklists => 'Opening + closing';

  @override
  String get webAdminEmptyTitleUsers => 'No Team Members Added Yet';

  @override
  String get webAdminEmptyDescriptionUsers =>
      'Invite team members to join your organization. You can assign different roles and control which locations they can access.';

  @override
  String get webAdminEmptyActionUsers => 'Add Your First Team Member';

  @override
  String get webAdminEmptySupportLabelUsers => 'Most useful';

  @override
  String get webAdminEmptySupportValueUsers => 'Invite managers first';

  @override
  String get webAdminEmptySecondaryLabelUsers => 'Status';

  @override
  String get webAdminEmptySecondaryValueUsers => 'Track invites here';

  @override
  String get webAdminEmptyTitleLocations => 'No Locations Added Yet';

  @override
  String get webAdminEmptyDescriptionLocations =>
      'Set up your business locations to organize shifts, assign staff, and track operations. Each location can have its own shifts, checklists, and team members.';

  @override
  String get webAdminEmptyActionLocations => 'Add Your First Location';

  @override
  String get webAdminEmptySupportLabelLocations => 'Foundation';

  @override
  String get webAdminEmptySupportValueLocations => 'Build setup around places';

  @override
  String get webAdminEmptySecondaryLabelLocations => 'After this';

  @override
  String get webAdminEmptySecondaryValueLocations => 'Create shifts';

  @override
  String get webAdminEmptyFooter =>
      'Keep setup light: create the location, add your team, then build shifts with attached workflows.';

  @override
  String get webAdminColumnShiftName => 'Shift Name';

  @override
  String get webAdminColumnTime => 'Time';

  @override
  String get webAdminColumnSchedule => 'Schedule';

  @override
  String get webAdminColumnStatus => 'Status';

  @override
  String get webAdminColumnActions => 'Actions';

  @override
  String get webAdminColumnTemplateName => 'Template Name';

  @override
  String get webAdminColumnDescription => 'Description';

  @override
  String get webAdminColumnTasks => 'Tasks';

  @override
  String get webAdminColumnUsedInShifts => 'Used in Shifts';

  @override
  String get webAdminColumnLocationName => 'Location Name';

  @override
  String get webAdminColumnAddress => 'Address';

  @override
  String get webAdminStatusActive => 'Active';

  @override
  String get webAdminStatusInactive => 'Inactive';

  @override
  String get webAdminStatusArchived => 'Archived';

  @override
  String get webAdminActionEdit => 'Edit';

  @override
  String get webAdminActionDuplicate => 'Duplicate';

  @override
  String get webAdminActionArchive => 'Archive';

  @override
  String get webAdminActionRestore => 'Restore';

  @override
  String get webAdminActionCreateWorkflow => 'Create workflow';

  @override
  String get webAdminActionEditWorkflow => 'Edit workflow';

  @override
  String get webAdminActionDeactivate => 'Deactivate';

  @override
  String get webAdminActionActivate => 'Activate';

  @override
  String get webAdminActionDeleteUser => 'Delete user';

  @override
  String get webAdminNoDescription => 'No description';

  @override
  String webAdminTaskCount(int count) {
    return '$count tasks';
  }

  @override
  String get webAdminDeleteShiftTitle => 'Delete shift?';

  @override
  String webAdminDeleteShiftBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get webAdminShiftUpdated => 'Shift updated successfully';

  @override
  String webAdminShiftUpdateFailed(String error) {
    return 'Failed to update shift: $error';
  }

  @override
  String get webAdminChecklistUpdateFailed => 'Failed to update template';

  @override
  String get webAdminDeleteTemplateTitle => 'Delete template?';

  @override
  String webAdminDeleteTemplateBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get webAdminTemplateDeleted => 'Template deleted successfully';

  @override
  String webAdminTemplateDeleteFailed(String error) {
    return 'Failed to delete template: $error';
  }

  @override
  String webAdminCopyName(String name) {
    return '$name (Copy)';
  }

  @override
  String get webAdminLocationDuplicated => 'Location duplicated successfully';

  @override
  String get webAdminDuplicateFailed => 'Failed to duplicate item';

  @override
  String get webAdminShiftCreated => 'Shift created successfully';

  @override
  String get webAdminShiftSaved => 'Shift updated successfully';

  @override
  String get webAdminShiftEditorOpenFailed => 'Failed to open shift editor';

  @override
  String get webAdminShiftDuplicated => 'Shift duplicated successfully';

  @override
  String webAdminShiftDuplicateFailed(String error) {
    return 'Failed to duplicate shift: $error';
  }

  @override
  String get webAdminShiftArchived => 'Shift archived successfully';

  @override
  String get webAdminShiftRestored => 'Shift restored successfully';

  @override
  String get webAdminTemplateCreated => 'Template created successfully';

  @override
  String get webAdminTemplateSaved => 'Template updated successfully';

  @override
  String webAdminTemplateSaveFailed(String error) {
    return 'Failed to save template: $error';
  }

  @override
  String get webAdminTemplateEditorOpenFailed =>
      'Failed to open template editor';

  @override
  String get webAdminTemplateDuplicated => 'Template duplicated successfully';

  @override
  String webAdminTemplateDuplicateFailed(String error) {
    return 'Failed to duplicate template: $error';
  }

  @override
  String get webAdminTemplateArchived => 'Template archived successfully';

  @override
  String get webAdminTemplateRestored => 'Template restored successfully';

  @override
  String get webAdminUserDeactivated => 'User deactivated successfully';

  @override
  String get webAdminUserActivated => 'User activated successfully';

  @override
  String webAdminUserUpdateFailed(String error) {
    return 'Failed to update user: $error';
  }

  @override
  String get webAdminLocationCreated => 'Location created successfully';

  @override
  String get webAdminLocationSaved => 'Location updated successfully';

  @override
  String webAdminLocationUpdateFailed(String error) {
    return 'Failed to update location: $error';
  }

  @override
  String get webAdminLocationArchived => 'Location archived successfully';

  @override
  String get webAdminLocationRestored => 'Location restored successfully';

  @override
  String get webAdminDeleteLocationTitle => 'Delete location?';

  @override
  String webAdminDeleteLocationBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get webAdminLocationDeleted => 'Location deleted successfully';

  @override
  String webAdminLocationDeleteFailed(String error) {
    return 'Failed to delete location: $error';
  }

  @override
  String get webAdminDeleteUserTitle => 'Delete user?';

  @override
  String webAdminDeleteUserBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get webAdminUserDeleted => 'User deleted successfully';

  @override
  String webAdminUserDeleteFailed(String error) {
    return 'Failed to delete user: $error';
  }

  @override
  String webAdminWorkflowSuggestion(String name) {
    return '$name workflow';
  }

  @override
  String webAdminStreamError(String error) {
    return 'Error: $error';
  }

  @override
  String get webAdminUnnamedShift => 'Unnamed Shift';

  @override
  String get webAdminUnnamedTemplate => 'Unnamed Template';

  @override
  String get webAdminUnnamedLocation => 'Unnamed Location';

  @override
  String get webAdminUnknownUser => 'Unknown User';

  @override
  String get webAdminNoEmail => 'No email';

  @override
  String get webAdminNoAddress => 'No address';

  @override
  String guidedTourStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get guidedTourSkip => 'Skip';

  @override
  String get guidedTourLearnMore => 'Learn more';

  @override
  String get guidedTourBack => 'Back';

  @override
  String get guidedTourNext => 'Next';

  @override
  String get guidedTourDone => 'Done';

  @override
  String get guidedTourLanguageFeatureTitle => 'New: language support';

  @override
  String get guidedTourLanguageFeatureBody =>
      'You can now switch between English, Spanish, and Portuguese anytime from Language in Settings.';

  @override
  String get releaseDialogUpdateTitle => 'A major update is available';

  @override
  String get releaseDialogUpdateSubtitle =>
      'Refresh or update to see the latest experience, language options, and guided walkthrough.';

  @override
  String get releaseDialogWhatsNewSubtitle =>
      'A refreshed experience is live, including guided walkthrough updates and language support.';

  @override
  String get releaseDialogNotNow => 'Not now';

  @override
  String get releaseDialogTakeGuidedTour => 'Take guided tour';

  @override
  String get releaseDialogRefreshNow => 'Refresh now';

  @override
  String get releaseDialogUpdateNow => 'Update now';

  @override
  String get releaseDialogOkay => 'Okay';

  @override
  String get releaseDialogMajorReleaseBadge => 'Major release';

  @override
  String get releaseDialogNewExperienceBadge => 'New experience';

  @override
  String get releaseDialogWhatChanged => 'What changed';

  @override
  String get releaseDialogLanguageFeatureTitle => 'New: language support';

  @override
  String get releaseDialogLanguageFeatureBody =>
      'English, Spanish, and Portuguese are now available from Language in Settings.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get notificationsViewAction => 'View';

  @override
  String get quickPdfViewerDocumentTitle => 'Document';

  @override
  String get quickPdfViewerTrainingDocumentTitle => 'Training Document';

  @override
  String get quickPdfViewerDescription =>
      'This document will open in your device\'s native viewer for the best experience.';

  @override
  String get quickPdfViewerOpenDocument => 'Open Document';

  @override
  String get quickPdfViewerCopyLink => 'Copy Link';

  @override
  String get quickPdfViewerShare => 'Share';

  @override
  String get quickPdfViewerHelpBody =>
      'Documents open in your device\'s built-in viewer for optimal performance and feature support.';

  @override
  String get quickPdfViewerOpenFailed =>
      'Could not open document. Please check your internet connection.';

  @override
  String quickPdfViewerOpenError(String error) {
    return 'Error opening document: $error';
  }

  @override
  String get quickPdfViewerCopied => 'Document link copied to clipboard';

  @override
  String get quickPdfViewerShareFailed => 'Could not share document';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationSettingsTestTooltip => 'Test Notifications';

  @override
  String get notificationPermissionTitle => 'Stay Updated with Hands';

  @override
  String get notificationPermissionBody =>
      'Get notified about schedule changes, shift reminders, and important announcements from your team.';

  @override
  String get notificationSettingsQuickActions => 'Quick Actions';

  @override
  String get notificationSettingsSubscribeTopics => 'Subscribe to Topics';

  @override
  String get notificationSettingsSystemSettings => 'System Settings';

  @override
  String get notificationSettingsTestTitle => 'Notification Setup Test';

  @override
  String notificationSettingsPermission(String value) {
    return 'Permission: $value';
  }

  @override
  String notificationSettingsToken(String value) {
    return 'Token: $value';
  }

  @override
  String notificationSettingsStatus(String value) {
    return 'Status: $value';
  }

  @override
  String get notificationSettingsNone => 'None';

  @override
  String get notificationSettingsReady => '✅ Ready';

  @override
  String get notificationSettingsNotReady => '❌ Not Ready';

  @override
  String get notificationOnboardingStayConnected => 'Stay Connected';

  @override
  String get notificationOnboardingBody =>
      'Get notified about:\n• Schedule updates\n• Shift reminders\n• Important announcements';

  @override
  String get notificationOnboardingEnableTitle => 'Enable Notifications';

  @override
  String get notificationOnboardingEnableBody =>
      'We\'ll only send notifications that are relevant to your work schedule and important updates.';

  @override
  String get notificationOnboardingSkip => 'Skip for now';

  @override
  String get checklistSheetInfoLabel => 'Info';

  @override
  String get checklistSheetNewChecklist => 'New checklist';

  @override
  String get checklistSheetEditChecklist => 'Edit checklist';

  @override
  String get checklistSheetSaveChecklist => 'Save checklist';

  @override
  String get checklistSheetStepBasics => 'Basics';

  @override
  String get checklistSheetStepTasks => 'Tasks';

  @override
  String get checklistSheetStepAdvanced => 'Advanced';

  @override
  String get checklistSheetNameRequired => 'Checklist name is required.';

  @override
  String get checklistSheetAddOneTask => 'Please add at least one task.';

  @override
  String get checklistSheetAllTasksNamed => 'All tasks must have names.';

  @override
  String get checklistSheetInfoTipBasics =>
      'Name this workflow template and add a short description.';

  @override
  String get checklistSheetBasicsIntro =>
      'Enter the basic information for this template:';

  @override
  String get checklistSheetTemplateName => 'Template name *';

  @override
  String get checklistSheetTemplateNameHint =>
      'e.g., Opening Bar, Kitchen Close';

  @override
  String get checklistSheetDescriptionOptional => 'Description (optional)';

  @override
  String get checklistSheetDescriptionHint =>
      'Brief description of this checklist';

  @override
  String get checklistSheetNoShiftsAttach =>
      'No shifts are available to attach right now.';

  @override
  String get checklistSheetNoShiftsFound =>
      'No shifts found for this location. Please create shifts first.';

  @override
  String get checklistSheetShiftTip =>
      'Select shifts where this checklist appears. You can leave this empty now and attach it later from the Shifts screen.';

  @override
  String get checklistSheetSelectShifts =>
      'Select which shifts should use this checklist:';

  @override
  String get checklistSheetTasksTip =>
      'Tap the camera to require a photo. If a photo is not uploaded by staff, admins are notified.';

  @override
  String get checklistSheetTasksIntro =>
      'Add tasks to your checklist. Drag to reorder:';

  @override
  String get checklistSheetNoTasks =>
      'No tasks added yet. Tap \"Add Task\" to get started.';

  @override
  String get checklistSheetAddTask => 'Add Task';

  @override
  String get checklistSheetAdvancedTip =>
      'Advanced settings are optional. Use them if you want to limit who can see this checklist or attach it to one or more shifts now.';

  @override
  String get checklistSheetVisibilityByJobType => 'Visibility by job type';

  @override
  String get checklistSheetAssignToShifts => 'Assign to shifts';

  @override
  String get checklistSheetSpanishTranslations => 'Spanish translations';

  @override
  String get checklistSheetPortugueseTranslations => 'Portuguese translations';

  @override
  String get checklistSheetSpanishTip =>
      'Optional: add Spanish versions of this template and its task names. English stays as the fallback when a Spanish field is left blank.';

  @override
  String get checklistSheetTemplateNameSpanish => 'Template name (Spanish)';

  @override
  String get checklistSheetTemplateNameSpanishHint => 'e.g., Apertura del bar';

  @override
  String get checklistSheetDescriptionSpanish => 'Description (Spanish)';

  @override
  String get checklistSheetDescriptionSpanishHint =>
      'Brief description in Spanish';

  @override
  String get checklistSheetAddTasksForSpanish =>
      'Add tasks first to include Spanish task labels.';

  @override
  String get checklistSheetSpanishTaskLabels => 'Spanish task labels';

  @override
  String checklistSheetTaskSpanish(int index) {
    return 'Task $index (Spanish)';
  }

  @override
  String get checklistSheetSpanishTaskLabelHint => 'Spanish task label';

  @override
  String checklistSheetSpanishFor(String name) {
    return 'Spanish for: $name';
  }

  @override
  String get checklistSheetPortugueseTip =>
      'Optional: add Portuguese versions of this template and its task names. English stays as the fallback when a Portuguese field is left blank.';

  @override
  String get checklistSheetTemplateNamePortuguese =>
      'Template name (Portuguese)';

  @override
  String get checklistSheetTemplateNamePortugueseHint =>
      'e.g., Abertura do bar';

  @override
  String get checklistSheetDescriptionPortuguese => 'Description (Portuguese)';

  @override
  String get checklistSheetDescriptionPortugueseHint =>
      'Brief description in Portuguese';

  @override
  String get checklistSheetAddTasksForPortuguese =>
      'Add tasks first to include Portuguese task labels.';

  @override
  String get checklistSheetPortugueseTaskLabels => 'Portuguese task labels';

  @override
  String checklistSheetTaskPortuguese(int index) {
    return 'Task $index (Portuguese)';
  }

  @override
  String get checklistSheetPortugueseTaskLabelHint => 'Portuguese task label';

  @override
  String checklistSheetPortugueseFor(String name) {
    return 'Portuguese for: $name';
  }

  @override
  String checklistSheetTask(int index) {
    return 'Task $index';
  }

  @override
  String get checklistSheetTaskHint => 'Enter task description';

  @override
  String get checklistSheetDeleteTask => 'Delete task';

  @override
  String get checklistSheetPhotoRequired => 'Photo required';

  @override
  String get checklistSheetNoPhotoRequired => 'No photo required';

  @override
  String get checklistSheetTaskName => 'Task name';

  @override
  String get checklistSheetPhoto => 'Photo';

  @override
  String checklistSheetLoadShiftsError(String error) {
    return 'Error loading shifts: $error';
  }

  @override
  String get checklistSheetJobTypesTip =>
      'Job types control who will see this checklist. Leave this empty to make it visible to everyone on the shift.';

  @override
  String get checklistSheetJobTypesIntro =>
      'Optionally restrict this checklist to people with these job types. Leave empty to make it visible to all.';

  @override
  String get checklistSheetManage => 'Manage';

  @override
  String get checklistSheetNoJobTypes =>
      'No job types found yet. Use Manage to create your first one.';

  @override
  String get checklistSheetAddJobType => 'Add job type';

  @override
  String get checklistSheetAddJobTypeHint => 'e.g., Dishwasher';

  @override
  String get checklistSheetAdd => 'Add';

  @override
  String checklistSheetSaveFailed(String error) {
    return 'Failed to save checklist: $error';
  }

  @override
  String shiftSheetLoadDataError(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get shiftSheetSavedSuccess => 'Shift schedule updated successfully';

  @override
  String shiftSheetSaveError(String error) {
    return 'Error saving schedule: $error';
  }

  @override
  String get shiftSheetAddRequiredRole => 'Add Required Role';

  @override
  String get shiftSheetAlreadyAdded => 'Already added';

  @override
  String shiftSheetAssignedCount(int assigned, int required) {
    return '$assigned of $required assigned';
  }

  @override
  String get shiftSheetRequiredRoles => 'Required Roles';

  @override
  String get shiftSheetAddRole => 'Add Role';

  @override
  String get shiftSheetNoRolesAssigned =>
      'No roles assigned to this shift. Tap \"Add Role\" to add required positions.';

  @override
  String get shiftSheetAssignedUsers => 'Assigned Users';

  @override
  String get shiftSheetNoUsersAssigned => 'No users assigned yet.';

  @override
  String get shiftSheetAvailableUsers => 'Available Users (Matching Roles)';

  @override
  String get shiftSheetOtherUsers => 'Other Users (No Matching Role)';

  @override
  String shiftSheetLoadUsersError(String error) {
    return 'Error loading users: $error';
  }

  @override
  String get shiftSheetNoOtherUsers => 'No other users available';

  @override
  String get shiftSheetSaveSchedule => 'Save Schedule';

  @override
  String get shiftSheetUnknownRole => 'Unknown Role';

  @override
  String shiftSheetRequiredCount(int count) {
    return 'Required: $count';
  }

  @override
  String get shiftSheetDecreaseCount => 'Decrease count';

  @override
  String get shiftSheetIncreaseCount => 'Increase count';

  @override
  String get shiftSheetRemoveRole => 'Remove role';

  @override
  String get shiftSheetUnknownUserInitial => 'U';

  @override
  String shiftSheetCheckAssignmentsError(String error) {
    return 'Error checking assignments: $error';
  }

  @override
  String get shiftSheetAlreadyAssignedAnotherShift =>
      'Already assigned to another shift this day';

  @override
  String get notificationTopicsTitle => 'Notification Types';

  @override
  String get notificationTopicsIntro =>
      'Choose which updates you want to stay on top of:';

  @override
  String get notificationTopicsScheduleUpdates =>
      'Schedule updates keep you informed when shifts change.';

  @override
  String get notificationTopicsShiftReminders =>
      'Shift reminders prompt you before assigned work begins.';

  @override
  String get notificationTopicsGeneralAnnouncements =>
      'General announcements share broader team and business updates.';

  @override
  String get notificationTopicsGotIt => 'Got it';

  @override
  String get notificationTypesLearnMore => 'Learn about notification types';

  @override
  String get notificationTypesTitle => 'Notification types';

  @override
  String get notificationPushTitle => 'Push notifications';

  @override
  String get notificationPushEnabled =>
      'Push notifications are enabled on this device.';

  @override
  String get notificationPushTapToEnable =>
      'Tap enable to turn on alerts for this device.';

  @override
  String get notificationEnable => 'Enable';

  @override
  String get notificationTypeScheduleUpdates => 'Schedule updates';

  @override
  String get notificationTypeScheduleUpdatesBody =>
      'Get notified when your shifts are added, removed, or changed.';

  @override
  String get notificationTypeShiftReminders => 'Shift reminders';

  @override
  String get notificationTypeShiftRemindersBody =>
      'Receive reminders before upcoming shifts start.';

  @override
  String get notificationTypeGeneralAnnouncements => 'General announcements';

  @override
  String get notificationTypeGeneralAnnouncementsBody =>
      'Stay in the loop on team-wide updates and important notices.';

  @override
  String get notificationTypeEmail => 'Email notifications';

  @override
  String get notificationTypeEmailBody =>
      'Also receive the most important updates by email.';

  @override
  String get notificationDebugInfo => 'Debug info';

  @override
  String get notificationFcmToken => 'FCM token';

  @override
  String get notificationNoToken => 'No token available yet';

  @override
  String get notificationTokenCopied => 'Token copied';

  @override
  String get pushPermissionExplanationBody =>
      'Turn on notifications so you receive shift reminders, schedule changes, and important team updates right away.';

  @override
  String get pushPermissionNotNow => 'Not now';

  @override
  String get pushPermissionEnabledSuccess => 'Notifications are enabled.';

  @override
  String get pushPermissionError =>
      'We could not enable notifications. Please try again.';

  @override
  String get pushPermissionDisabledTitle => 'Notifications are off';

  @override
  String get pushPermissionDisabledBody =>
      'You can still use the app, but you may miss reminders and urgent updates until notifications are turned back on in your device settings.';

  @override
  String get pushPermissionMaybeLater => 'Maybe later';

  @override
  String get pushPermissionOpenSettings => 'Open settings';

  @override
  String get pushPermissionShortBody =>
      'Get shift reminders, schedule changes, and team updates delivered to this device.';

  @override
  String get pushPermissionSettings => 'Settings';

  @override
  String get pushPermissionRequestError =>
      'We could not request notification permission. Please try again.';

  @override
  String get availabilitySavedSuccess => 'Availability saved successfully.';

  @override
  String availabilitySaveError(String error) {
    return 'Error saving availability: $error';
  }

  @override
  String get availabilityTitle => 'Availability';

  @override
  String get availabilityShiftAvailability => 'Shift availability';

  @override
  String get availabilityShiftAvailabilityBody =>
      'Set which shift blocks you are generally available to work each day.';

  @override
  String get availabilityEarliestStartTimes => 'Earliest start times';

  @override
  String get availabilityEarliestStartBody =>
      'Set the earliest time you can usually start for each day of the week.';

  @override
  String get availabilityDefaultTime => '9:00 AM';

  @override
  String get availabilityNotificationPreferences => 'Notification preferences';

  @override
  String get availabilityScheduleUpdatesBody =>
      'Stay updated when your published schedule changes.';

  @override
  String get availabilityShiftRemindersBody =>
      'Receive reminders before your shifts begin.';

  @override
  String get availabilityEmailNotificationsBody =>
      'Get key updates delivered to your email as well.';

  @override
  String get availabilityPushNotificationsBody =>
      'Allow this device to receive instant alerts.';

  @override
  String get availabilitySavePreferences => 'Save preferences';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get shiftLabelMorning => 'Morning';

  @override
  String get shiftLabelAfternoon => 'Afternoon';

  @override
  String get shiftLabelEvening => 'Evening';

  @override
  String get shiftLabelNight => 'Night';

  @override
  String get upgradeLocationsTitle => 'Add locations';

  @override
  String get upgradeLocationsQuantity =>
      'How many locations do you want to add?';

  @override
  String upgradeLocationsSummary(int count, String price) {
    return 'Add $count location(s) for $price per month.';
  }

  @override
  String upgradeLocationsFailed(String error) {
    return 'Could not update locations: $error';
  }

  @override
  String get upgradeLocationsAction => 'Upgrade and pay';
}
