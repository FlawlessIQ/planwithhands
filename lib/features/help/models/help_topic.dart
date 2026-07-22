import 'package:flutter/material.dart';

enum HelpRole { staff, manager, admin }

extension HelpRoleX on HelpRole {
  String get slug => switch (this) {
    HelpRole.staff => 'staff',
    HelpRole.manager => 'manager',
    HelpRole.admin => 'admin',
  };

  String get label => switch (this) {
    HelpRole.staff => 'Staff',
    HelpRole.manager => 'Manager',
    HelpRole.admin => 'Admin',
  };

  String get shortDescription => switch (this) {
    HelpRole.staff => 'Daily work, shifts, tasks, and carryover',
    HelpRole.manager => 'Daily oversight, follow-up, and broadcasts',
    HelpRole.admin => 'Setup, workflows, team access, and operations',
  };

  Color get accentColor => switch (this) {
    HelpRole.staff => const Color(0xFF4CC6B6),
    HelpRole.manager => const Color(0xFF4A90F2),
    HelpRole.admin => const Color(0xFFF6C344),
  };

  static HelpRole fromUserRole(int? userRole) {
    if ((userRole ?? 0) >= 2) return HelpRole.admin;
    if ((userRole ?? 0) >= 1) return HelpRole.manager;
    return HelpRole.staff;
  }

  static HelpRole fromSlug(String slug) {
    switch (slug.toLowerCase()) {
      case 'admin':
      case '2':
        return HelpRole.admin;
      case 'manager':
      case '1':
        return HelpRole.manager;
      case '0':
      default:
        return HelpRole.staff;
    }
  }
}

enum HelpTopicCategory {
  dailyWork,
  oversight,
  setup,
  communications,
  documents,
  account,
  sharedMode,
  troubleshooting,
  operationsControl,
}

extension HelpTopicCategoryX on HelpTopicCategory {
  String get label => switch (this) {
    HelpTopicCategory.dailyWork => 'Daily Work',
    HelpTopicCategory.oversight => 'Daily Oversight',
    HelpTopicCategory.setup => 'Operations Setup',
    HelpTopicCategory.communications => 'Communications',
    HelpTopicCategory.documents => 'Documents & Training',
    HelpTopicCategory.account => 'Account & Access',
    HelpTopicCategory.sharedMode => 'Shared Mode',
    HelpTopicCategory.troubleshooting => 'Troubleshooting',
    HelpTopicCategory.operationsControl => 'Operations Control',
  };

  String get description => switch (this) {
    HelpTopicCategory.dailyWork =>
      'Get through your shift and finish tasks cleanly.',
    HelpTopicCategory.oversight =>
      'Understand live service and respond to risks fast.',
    HelpTopicCategory.setup => 'Configure the business in the right order.',
    HelpTopicCategory.communications =>
      'Keep the team aligned with inbox, broadcasts, and audiences.',
    HelpTopicCategory.documents =>
      'Use the Document Center for training, SOPs, and references.',
    HelpTopicCategory.account =>
      'Manage sign-in, locations, access, and profile basics.',
    HelpTopicCategory.sharedMode =>
      'Use shared devices safely without losing control.',
    HelpTopicCategory.troubleshooting =>
      'Fix blockers fast when work, access, or messages are missing.',
    HelpTopicCategory.operationsControl =>
      'Run day-to-day operations and keep setup healthy over time.',
  };
}

String _normalizeLocaleKey(String localeCode) =>
    localeCode.toLowerCase().replaceAll('_', '-');

List<String> _localeCandidates(String localeCode) {
  final normalized = _normalizeLocaleKey(localeCode);
  final languageCode = normalized.split('-').first;
  return normalized == languageCode ? [normalized] : [normalized, languageCode];
}

String _localizedString(
  Map<String, String> values,
  String fallback,
  String localeCode,
) {
  for (final candidate in _localeCandidates(localeCode)) {
    final resolved = values[candidate];
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
  }
  return fallback;
}

List<String> _localizedList(
  Map<String, List<String>> values,
  List<String> fallback,
  String localeCode,
) {
  for (final candidate in _localeCandidates(localeCode)) {
    final resolved = values[candidate];
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
  }
  return fallback;
}

class HelpTopic {
  final String id;
  final String title;
  final String summary;
  final String whyItMatters;
  final List<HelpRole> roles;
  final HelpTopicCategory category;
  final IconData icon;
  final int estimatedMinutes;
  final List<String> steps;
  final List<String> goodOutcome;
  final List<String> commonMistakes;
  final List<String> keywords;
  final String? primaryCtaLabel;
  final String? primaryCtaRoute;
  final bool isFeatured;
  final bool isTroubleshooting;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedSummaries;
  final Map<String, String> localizedWhyItMatters;
  final Map<String, List<String>> localizedSteps;
  final Map<String, List<String>> localizedGoodOutcome;
  final Map<String, List<String>> localizedCommonMistakes;
  final Map<String, List<String>> localizedKeywords;
  final Map<String, String> localizedPrimaryCtaLabels;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.whyItMatters,
    required this.roles,
    required this.category,
    required this.icon,
    required this.estimatedMinutes,
    required this.steps,
    this.goodOutcome = const [],
    this.commonMistakes = const [],
    this.keywords = const [],
    this.primaryCtaLabel,
    this.primaryCtaRoute,
    this.isFeatured = false,
    this.isTroubleshooting = false,
    this.localizedTitles = const {},
    this.localizedSummaries = const {},
    this.localizedWhyItMatters = const {},
    this.localizedSteps = const {},
    this.localizedGoodOutcome = const {},
    this.localizedCommonMistakes = const {},
    this.localizedKeywords = const {},
    this.localizedPrimaryCtaLabels = const {},
  });

  String titleForLocale(String localeCode) =>
      _localizedString(localizedTitles, title, localeCode);

  String summaryForLocale(String localeCode) =>
      _localizedString(localizedSummaries, summary, localeCode);

  String whyItMattersForLocale(String localeCode) =>
      _localizedString(localizedWhyItMatters, whyItMatters, localeCode);

  List<String> stepsForLocale(String localeCode) =>
      _localizedList(localizedSteps, steps, localeCode);

  List<String> goodOutcomeForLocale(String localeCode) =>
      _localizedList(localizedGoodOutcome, goodOutcome, localeCode);

  List<String> commonMistakesForLocale(String localeCode) =>
      _localizedList(localizedCommonMistakes, commonMistakes, localeCode);

  List<String> keywordsForLocale(String localeCode) =>
      _localizedList(localizedKeywords, keywords, localeCode);

  String? primaryCtaLabelForLocale(String localeCode) {
    if (primaryCtaLabel == null) return null;
    return _localizedString(
      localizedPrimaryCtaLabels,
      primaryCtaLabel!,
      localeCode,
    );
  }

  List<String> searchTermsForLocale(String localeCode) {
    final terms = <String>{};

    void addAll(Iterable<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          terms.add(trimmed);
        }
      }
    }

    addAll([title, summary, whyItMatters]);
    addAll(steps);
    addAll(goodOutcome);
    addAll(commonMistakes);
    addAll(keywords);
    addAll([
      titleForLocale(localeCode),
      summaryForLocale(localeCode),
      whyItMattersForLocale(localeCode),
    ]);
    addAll(stepsForLocale(localeCode));
    addAll(goodOutcomeForLocale(localeCode));
    addAll(commonMistakesForLocale(localeCode));
    addAll(keywordsForLocale(localeCode));

    return terms.toList();
  }
}

class HelpStartStep {
  final String title;
  final String description;
  final String topicId;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedDescriptions;

  const HelpStartStep({
    required this.title,
    required this.description,
    required this.topicId,
    this.localizedTitles = const {},
    this.localizedDescriptions = const {},
  });

  String titleForLocale(String localeCode) =>
      _localizedString(localizedTitles, title, localeCode);

  String descriptionForLocale(String localeCode) =>
      _localizedString(localizedDescriptions, description, localeCode);
}

class HelpStartGuide {
  final HelpRole role;
  final String title;
  final String subtitle;
  final String primaryCtaLabel;
  final String primaryCtaRoute;
  final List<HelpStartStep> steps;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedSubtitles;
  final Map<String, String> localizedPrimaryCtaLabels;

  const HelpStartGuide({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.primaryCtaLabel,
    required this.primaryCtaRoute,
    required this.steps,
    this.localizedTitles = const {},
    this.localizedSubtitles = const {},
    this.localizedPrimaryCtaLabels = const {},
  });

  String titleForLocale(String localeCode) =>
      _localizedString(localizedTitles, title, localeCode);

  String subtitleForLocale(String localeCode) =>
      _localizedString(localizedSubtitles, subtitle, localeCode);

  String primaryCtaLabelForLocale(String localeCode) =>
      _localizedString(localizedPrimaryCtaLabels, primaryCtaLabel, localeCode);
}

class HelpNav {
  static const String home = '/how-to-use';
  static const String startHere = '/how-to-use/start';
  static const String troubleshooting = '/how-to-use/troubleshooting';

  static String role(HelpRole role) => '/how-to-use/role/${role.slug}';
  static String topic(String topicId) => '/how-to-use/topic/$topicId';
  static String startHereForRole(HelpRole role) =>
      '$startHere?role=${role.slug}';

  static String contactSupport({
    String? source,
    String? currentRoute,
    String? screenLabel,
    String? topicId,
    String? topicTitle,
    String? issueHint,
  }) {
    final query = <String, String>{};
    if (source != null && source.trim().isNotEmpty) query['source'] = source;
    if (currentRoute != null && currentRoute.trim().isNotEmpty) {
      query['route'] = currentRoute;
    }
    if (screenLabel != null && screenLabel.trim().isNotEmpty) {
      query['screen'] = screenLabel;
    }
    if (topicId != null && topicId.trim().isNotEmpty) query['topic'] = topicId;
    if (topicTitle != null && topicTitle.trim().isNotEmpty) {
      query['topicTitle'] = topicTitle;
    }
    if (issueHint != null && issueHint.trim().isNotEmpty) {
      query['issue'] = issueHint;
    }

    return Uri(
      path: HelpDestinations.contactSupport,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}

class HelpDestinations {
  static const String inbox = '/messages';
  static const String userDashboard = '/user_dashboard';
  static const String managerDashboard = '/manager_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String documents = '/training_materials';
  static const String settings = '/settings';
  static const String contactSupport = '/contact-us';
}
