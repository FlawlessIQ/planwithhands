import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionAccessService {
  static const Set<String> validSubscriptionStatuses = {
    'active',
    'trialing',
    'trial',
  };

  static bool hasAccess({
    Map<String, dynamic>? organizationData,
    Map<String, dynamic>? subscriptionData,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (isSubscriptionStatusValid(subscriptionData?['status'] as String?)) {
      return true;
    }

    final orgStatus = _readOrganizationStatus(organizationData);
    if (orgStatus == 'active' || orgStatus == 'trialing') {
      return true;
    }

    if (orgStatus == 'trial') {
      final trialEndsAt = trialEndsAtDate(organizationData);
      return trialEndsAt == null || !trialEndsAt.isBefore(currentTime);
    }

    return false;
  }

  static bool isOrganizationTrialActive(
    Map<String, dynamic>? organizationData, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    if (_readOrganizationStatus(organizationData) != 'trial') return false;
    final trialEndsAt = trialEndsAtDate(organizationData);
    return trialEndsAt == null || !trialEndsAt.isBefore(currentTime);
  }

  static bool isSubscriptionStatusValid(String? status) {
    return status != null && validSubscriptionStatuses.contains(status);
  }

  static DateTime? trialEndsAtDate(Map<String, dynamic>? organizationData) {
    final raw = organizationData?['trialEndsAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return raw > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    return null;
  }

  static int? remainingTrialDays(
    Map<String, dynamic>? organizationData, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final trialEndsAt = trialEndsAtDate(organizationData);
    if (trialEndsAt == null) return null;
    final difference = trialEndsAt.difference(currentTime);
    if (difference.isNegative) return 0;
    final wholeDays = difference.inDays;
    return difference.inHours % 24 == 0 ? wholeDays : wholeDays + 1;
  }

  static String? _readOrganizationStatus(
    Map<String, dynamic>? organizationData,
  ) {
    final direct = organizationData?['subscriptionStatus'];
    if (direct is String && direct.isNotEmpty) return direct;

    final settings = organizationData?['settings'];
    if (settings is Map<String, dynamic>) {
      final nested = settings['subscriptionStatus'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }
}
