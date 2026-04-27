import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/services/guided_tour_service.dart';
import 'package:hands_app/features/releases/models/app_release_manifest.dart';
import 'package:hands_app/features/releases/services/app_release_storage.dart';
import 'package:hands_app/features/releases/services/app_reload_stub.dart'
    if (dart.library.html) 'package:hands_app/features/releases/services/app_reload_web.dart'
    as app_reload;
import 'package:hands_app/features/releases/widgets/app_release_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppReleasePromptType { whatsNew, updateAvailable }

class AppReleasePromptDecision {
  final AppReleasePromptType type;
  final HelpRole role;
  final String releaseId;
  final AppRoleReleaseContent content;
  final String? updateUrl;

  const AppReleasePromptDecision({
    required this.type,
    required this.role,
    required this.releaseId,
    required this.content,
    this.updateUrl,
  });

  String get sessionKey => '${type.name}_${role.slug}_$releaseId';
}

class AppReleaseService {
  static const String _defaultManifestUrl = String.fromEnvironment(
    'EXPERIENCE_RELEASE_URL',
    defaultValue: 'https://plan-with-hands.web.app/version.json',
  );

  static Uri manifestUri() {
    if (kIsWeb) {
      return Uri.parse('${Uri.base.origin}/version.json');
    }
    return Uri.parse(_defaultManifestUrl);
  }

  static Future<AppReleaseManifest?> fetchManifest() async {
    try {
      final response = await http
          .get(
            manifestUri(),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AppReleaseManifest.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<AppReleasePromptDecision?> evaluate({
    required AppReleaseManifest manifest,
    required PackageInfo packageInfo,
    required String currentPath,
  }) async {
    if (!manifest.hasMajorExperienceRelease) return null;

    final role = _roleForPath(currentPath);
    if (role == null) return null;

    final content = manifest.contentForRole(role);
    final releaseId = manifest.experienceReleaseId;
    if (content == null || releaseId == null || releaseId.isEmpty) return null;

    final localVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final minimumVersion = manifest.minimumBuildVersion;

    if (minimumVersion != null &&
        minimumVersion.isNotEmpty &&
        compareVersions(localVersion, minimumVersion) < 0) {
      final updateUrl = _updateUrlForCurrentPlatform(manifest);
      return AppReleasePromptDecision(
        type: AppReleasePromptType.updateAvailable,
        role: role,
        releaseId: releaseId,
        content: content,
        updateUrl: updateUrl,
      );
    }

    final seen = await AppReleaseStorage.hasSeenRelease(role, releaseId);
    if (seen) return null;

    return AppReleasePromptDecision(
      type: AppReleasePromptType.whatsNew,
      role: role,
      releaseId: releaseId,
      content: content,
    );
  }

  static Future<AppReleasePromptDecision?> latestExperienceForRole(
    HelpRole role,
  ) async {
    final manifest = await fetchManifest();
    if (manifest == null || !manifest.hasMajorExperienceRelease) return null;

    final content = manifest.contentForRole(role);
    final releaseId = manifest.experienceReleaseId;
    if (content == null || releaseId == null || releaseId.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final localVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final minimumVersion = manifest.minimumBuildVersion;

    if (minimumVersion != null &&
        minimumVersion.isNotEmpty &&
        compareVersions(localVersion, minimumVersion) < 0) {
      final updateUrl = _updateUrlForCurrentPlatform(manifest);
      return AppReleasePromptDecision(
        type: AppReleasePromptType.updateAvailable,
        role: role,
        releaseId: releaseId,
        content: content,
        updateUrl: updateUrl,
      );
    }

    return AppReleasePromptDecision(
      type: AppReleasePromptType.whatsNew,
      role: role,
      releaseId: releaseId,
      content: content,
    );
  }

  static HelpRole? _roleForPath(String currentPath) {
    final path = Uri.parse(currentPath).path;
    switch (path) {
      case HelpDestinations.userDashboard:
        return HelpRole.staff;
      case HelpDestinations.managerDashboard:
        return HelpRole.manager;
      case HelpDestinations.adminDashboard:
      case '/admin':
      case '/setup':
        return HelpRole.admin;
      default:
        return null;
    }
  }

  static String? _updateUrlForCurrentPlatform(AppReleaseManifest manifest) {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (manifest.appStoreUrl?.isNotEmpty ?? false)
          ? manifest.appStoreUrl
          : null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return (manifest.playStoreUrl?.isNotEmpty ?? false)
          ? manifest.playStoreUrl
          : null;
    }
    return null;
  }

  static Future<void> handlePrimaryAction(
    BuildContext context,
    AppReleasePromptDecision decision,
  ) async {
    switch (decision.type) {
      case AppReleasePromptType.whatsNew:
        await AppReleaseStorage.markReleaseSeen(
          decision.role,
          decision.releaseId,
        );
        if (!context.mounted) return;
        await GuidedTourService.replayForRole(context, decision.role);
        return;
      case AppReleasePromptType.updateAvailable:
        if (kIsWeb) {
          await app_reload.reloadCurrentApp();
          return;
        }

        final updateUrl = decision.updateUrl;
        if (updateUrl != null && updateUrl.isNotEmpty) {
          await launchUrl(Uri.parse(updateUrl));
        }
        return;
    }
  }

  static Future<void> showLatestExperienceDialog(
    BuildContext context,
    HelpRole role,
  ) async {
    final decision = await latestExperienceForRole(role);
    if (!context.mounted || decision == null) return;

    final result = await showDialog<AppReleaseDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppReleaseDialog(decision: decision),
    );

    if (!context.mounted) return;
    if (result == AppReleaseDialogResult.primary) {
      await handlePrimaryAction(context, decision);
    }
  }

  static int compareVersions(String a, String b) {
    final parsedA = _parseVersion(a);
    final parsedB = _parseVersion(b);

    for (var i = 0; i < 3; i++) {
      final diff = parsedA.segments[i] - parsedB.segments[i];
      if (diff != 0) return diff.sign;
    }

    return (parsedA.build - parsedB.build).sign;
  }

  static _ParsedVersion _parseVersion(String input) {
    final cleaned = input.trim();
    final parts = cleaned.split('+');
    final semverParts =
        (parts.isNotEmpty ? parts.first : cleaned)
            .split('.')
            .map((value) => int.tryParse(value) ?? 0)
            .toList();

    final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return _ParsedVersion(
      segments: List<int>.generate(
        3,
        (index) => index < semverParts.length ? semverParts[index] : 0,
      ),
      build: build,
    );
  }
}

class _ParsedVersion {
  final List<int> segments;
  final int build;

  const _ParsedVersion({required this.segments, required this.build});
}
