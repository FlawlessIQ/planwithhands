import 'package:hands_app/features/help/models/help_topic.dart';

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

class AppRoleReleaseContent {
  final String title;
  final String body;
  final List<String> bullets;
  final String? tourVersion;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedBodies;
  final Map<String, List<String>> localizedBullets;

  const AppRoleReleaseContent({
    required this.title,
    required this.body,
    required this.bullets,
    this.tourVersion,
    this.localizedTitles = const {},
    this.localizedBodies = const {},
    this.localizedBullets = const {},
  });

  factory AppRoleReleaseContent.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseLocalizedStrings(String key) {
      final raw = json[key];
      if (raw is! Map) return const {};
      return raw.map(
        (locale, value) =>
            MapEntry(locale.toString(), value?.toString().trim() ?? ''),
      )..removeWhere((_, value) => value.isEmpty);
    }

    Map<String, List<String>> parseLocalizedLists(String key) {
      final raw = json[key];
      if (raw is! Map) return const {};
      final parsed = <String, List<String>>{};
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! List) continue;
        final items =
            value
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList();
        if (items.isNotEmpty) {
          parsed[entry.key.toString()] = items;
        }
      }
      return parsed;
    }

    return AppRoleReleaseContent(
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      bullets:
          ((json['bullets'] as List?) ?? const [])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
      tourVersion: (json['tourVersion'] as String?)?.trim(),
      localizedTitles: parseLocalizedStrings('localizedTitles'),
      localizedBodies: parseLocalizedStrings('localizedBodies'),
      localizedBullets: parseLocalizedLists('localizedBullets'),
    );
  }

  bool get isValid => title.isNotEmpty && body.isNotEmpty;

  String titleForLocale(String localeCode) =>
      _localizedString(localizedTitles, title, localeCode);

  String bodyForLocale(String localeCode) =>
      _localizedString(localizedBodies, body, localeCode);

  List<String> bulletsForLocale(String localeCode) =>
      _localizedList(localizedBullets, bullets, localeCode);
}

class AppReleaseManifest {
  final String buildVersion;
  final String? minimumBuildVersion;
  final String? experienceReleaseId;
  final bool announceExperienceRelease;
  final String? appStoreUrl;
  final String? playStoreUrl;
  final Map<HelpRole, AppRoleReleaseContent> roles;

  const AppReleaseManifest({
    required this.buildVersion,
    required this.minimumBuildVersion,
    required this.experienceReleaseId,
    required this.announceExperienceRelease,
    required this.appStoreUrl,
    required this.playStoreUrl,
    required this.roles,
  });

  factory AppReleaseManifest.fromJson(Map<String, dynamic> json) {
    final rolePayload = (json['roles'] as Map?) ?? const {};
    final roles = <HelpRole, AppRoleReleaseContent>{};

    for (final entry in rolePayload.entries) {
      final key = entry.key?.toString();
      final value = entry.value;
      if (key == null || value is! Map) continue;

      final role = HelpRoleX.fromSlug(key);
      final content = AppRoleReleaseContent.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (content.isValid) {
        roles[role] = content;
      }
    }

    return AppReleaseManifest(
      buildVersion: (json['buildVersion'] as String? ?? '').trim(),
      minimumBuildVersion: (json['minimumBuildVersion'] as String?)?.trim(),
      experienceReleaseId: (json['experienceReleaseId'] as String?)?.trim(),
      announceExperienceRelease:
          json['announceExperienceRelease'] as bool? ?? false,
      appStoreUrl: (json['appStoreUrl'] as String?)?.trim(),
      playStoreUrl: (json['playStoreUrl'] as String?)?.trim(),
      roles: roles,
    );
  }

  AppRoleReleaseContent? contentForRole(HelpRole role) => roles[role];

  bool get hasMajorExperienceRelease =>
      announceExperienceRelease &&
      (experienceReleaseId?.isNotEmpty ?? false) &&
      roles.isNotEmpty;
}
