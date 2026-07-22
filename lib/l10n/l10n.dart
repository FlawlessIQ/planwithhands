import 'package:flutter/widgets.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/l10n/generated/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension HelpRoleLocalizationsX on HelpRole {
  String localizedLabel(BuildContext context) => switch (this) {
    HelpRole.staff => context.l10n.helpRoleStaff,
    HelpRole.manager => context.l10n.helpRoleManager,
    HelpRole.admin => context.l10n.helpRoleAdmin,
  };

  String localizedShortDescription(BuildContext context) => switch (this) {
    HelpRole.staff => context.l10n.helpRoleStaffShortDescription,
    HelpRole.manager => context.l10n.helpRoleManagerShortDescription,
    HelpRole.admin => context.l10n.helpRoleAdminShortDescription,
  };
}

extension HelpTopicCategoryLocalizationsX on HelpTopicCategory {
  String localizedLabel(BuildContext context) => switch (this) {
    HelpTopicCategory.dailyWork => context.l10n.helpCategoryDailyWork,
    HelpTopicCategory.oversight => context.l10n.helpCategoryOversight,
    HelpTopicCategory.setup => context.l10n.helpCategorySetup,
    HelpTopicCategory.communications => context.l10n.helpCategoryCommunications,
    HelpTopicCategory.documents => context.l10n.helpCategoryDocuments,
    HelpTopicCategory.account => context.l10n.helpCategoryAccount,
    HelpTopicCategory.sharedMode => context.l10n.helpCategorySharedMode,
    HelpTopicCategory.troubleshooting =>
      context.l10n.helpCategoryTroubleshooting,
    HelpTopicCategory.operationsControl =>
      context.l10n.helpCategoryOperationsControl,
  };

  String localizedDescription(BuildContext context) => switch (this) {
    HelpTopicCategory.dailyWork =>
      context.l10n.helpCategoryDailyWorkDescription,
    HelpTopicCategory.oversight =>
      context.l10n.helpCategoryOversightDescription,
    HelpTopicCategory.setup => context.l10n.helpCategorySetupDescription,
    HelpTopicCategory.communications =>
      context.l10n.helpCategoryCommunicationsDescription,
    HelpTopicCategory.documents =>
      context.l10n.helpCategoryDocumentsDescription,
    HelpTopicCategory.account => context.l10n.helpCategoryAccountDescription,
    HelpTopicCategory.sharedMode =>
      context.l10n.helpCategorySharedModeDescription,
    HelpTopicCategory.troubleshooting =>
      context.l10n.helpCategoryTroubleshootingDescription,
    HelpTopicCategory.operationsControl =>
      context.l10n.helpCategoryOperationsControlDescription,
  };
}
