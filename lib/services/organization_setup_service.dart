import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_ttl_helper.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Service to manage organization setup progress and readiness for metrics tracking
///
/// Controls when an organization is ready to start tracking daily metrics,
/// missed tasks, completion percentages, and other operational data.
class OrganizationSetupService {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Check if an organization has completed basic setup requirements
  Future<Map<String, dynamic>> getSetupStatus(String organizationId) async {
    try {
      logger.d('[OrganizationSetupService] Checking setup status for organization: $organizationId');

      // Get organization document to check if metrics are enabled
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      final orgData = orgDoc.data() ?? {};
      final metricsEnabled = orgData['metricsEnabled'] as bool? ?? false;

      // Check each setup requirement
      final setupChecks = await Future.wait([
        _checkLocations(organizationId),
        _checkShifts(organizationId),
        _checkChecklists(organizationId),
        _checkUsers(organizationId),
      ]);

      final locations = setupChecks[0];
      final shifts = setupChecks[1];
      final checklists = setupChecks[2];
      final users = setupChecks[3];

      final allRequirementsMet = locations['met'] && shifts['met'] && checklists['met'] && users['met'];

      final setupStatus = {
        'metricsEnabled': metricsEnabled,
        'allRequirementsMet': allRequirementsMet,
        'canEnableMetrics': allRequirementsMet && !metricsEnabled,
        'requirements': {'locations': locations, 'shifts': shifts, 'checklists': checklists, 'users': users},
        'setupCompletionPercentage': _calculateCompletionPercentage([locations, shifts, checklists, users]),
      };

      logger.d('[OrganizationSetupService] Setup status: metricsEnabled=$metricsEnabled, allMet=$allRequirementsMet');
      return setupStatus;
    } catch (e, stackTrace) {
      logger.e('[OrganizationSetupService] Error checking setup status', e, stackTrace);
      return {
        'metricsEnabled': false,
        'allRequirementsMet': false,
        'canEnableMetrics': false,
        'requirements': {},
        'setupCompletionPercentage': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Enable metrics tracking for an organization
  /// This should only be called when all setup requirements are met
  Future<bool> enableMetricsTracking(String organizationId) async {
    try {
      logger.d('[OrganizationSetupService] Enabling metrics tracking for organization: $organizationId');

      // Verify setup is complete before enabling
      final setupStatus = await getSetupStatus(organizationId);
      if (!setupStatus['allRequirementsMet']) {
        logger.w('[OrganizationSetupService] Cannot enable metrics - setup requirements not met');
        return false;
      }

      // Enable metrics in organization document
      final orgRef = _firestore.collection('organizations').doc(organizationId);
      await orgRef.update({
        'metricsEnabled': true,
        'metricsEnabledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the activation for audit purposes
      await _logSetupActivation(organizationId);

      logger.d('[OrganizationSetupService] Successfully enabled metrics tracking');
      return true;
    } catch (e, stackTrace) {
      logger.e('[OrganizationSetupService] Error enabling metrics tracking', e, stackTrace);
      return false;
    }
  }

  /// Check if metrics tracking is enabled for an organization
  Future<bool> isMetricsTrackingEnabled(String organizationId) async {
    try {
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      final orgData = orgDoc.data() ?? {};
      return orgData['metricsEnabled'] as bool? ?? false;
    } catch (e) {
      logger.e('[OrganizationSetupService] Error checking metrics enabled status: $e');
      return false;
    }
  }

  /// Check locations requirement (at least 1 location)
  Future<Map<String, dynamic>> _checkLocations(String organizationId) async {
    try {
      final locationsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').limit(1).get();

      final count = locationsQuery.docs.length;
      return {
        'met': count >= 1,
        'count': count,
        'required': 1,
        'name': 'Locations',
        'description': 'Create at least one location where work will be performed',
        'icon': '📍',
      };
    } catch (e) {
      logger.e('[OrganizationSetupService] Error checking locations: $e');
      return {
        'met': false,
        'count': 0,
        'required': 1,
        'name': 'Locations',
        'description': 'Create at least one location where work will be performed',
        'icon': '📍',
        'error': e.toString(),
      };
    }
  }

  /// Check shifts requirement (at least 1 shift)
  Future<Map<String, dynamic>> _checkShifts(String organizationId) async {
    try {
      final shiftsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('shifts').limit(1).get();

      final count = shiftsQuery.docs.length;
      return {
        'met': count >= 1,
        'count': count,
        'required': 1,
        'name': 'Shifts',
        'description': 'Define at least one work shift with start and end times',
        'icon': '⏰',
      };
    } catch (e) {
      logger.e('[OrganizationSetupService] Error checking shifts: $e');
      return {
        'met': false,
        'count': 0,
        'required': 1,
        'name': 'Shifts',
        'description': 'Define at least one work shift with start and end times',
        'icon': '⏰',
        'error': e.toString(),
      };
    }
  }

  /// Check checklists requirement (at least 1 checklist template)
  Future<Map<String, dynamic>> _checkChecklists(String organizationId) async {
    try {
      final checklistsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .limit(1)
              .get();

      final count = checklistsQuery.docs.length;
      return {
        'met': count >= 1,
        'count': count,
        'required': 1,
        'name': 'Checklists',
        'description': 'Create at least one checklist template with tasks',
        'icon': '📋',
      };
    } catch (e) {
      logger.e('[OrganizationSetupService] Error checking checklists: $e');
      return {
        'met': false,
        'count': 0,
        'required': 1,
        'name': 'Checklists',
        'description': 'Create at least one checklist template with tasks',
        'icon': '📋',
        'error': e.toString(),
      };
    }
  }

  /// Check users requirement (at least 2 users: admin + staff)
  Future<Map<String, dynamic>> _checkUsers(String organizationId) async {
    try {
      final usersQuery =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where('isActive', isEqualTo: true)
              .limit(2)
              .get();

      final count = usersQuery.docs.length;
      return {
        'met': count >= 2,
        'count': count,
        'required': 2,
        'name': 'Team Members',
        'description': 'Invite at least one staff member to your organization',
        'icon': '👥',
      };
    } catch (e) {
      logger.e('[OrganizationSetupService] Error checking users: $e');
      return {
        'met': false,
        'count': 0,
        'required': 2,
        'name': 'Team Members',
        'description': 'Invite at least one staff member to your organization',
        'icon': '👥',
        'error': e.toString(),
      };
    }
  }

  /// Calculate overall setup completion percentage
  double _calculateCompletionPercentage(List<Map<String, dynamic>> requirements) {
    final metCount = requirements.where((req) => req['met'] == true).length;
    return metCount / requirements.length;
  }

  /// Log when metrics tracking is activated
  Future<void> _logSetupActivation(String organizationId) async {
    try {
      final logRef = _firestore.collection('organizations').doc(organizationId).collection('setup_logs').doc();

      final logData = {
        'action': 'metrics_enabled',
        'timestamp': FieldValue.serverTimestamp(),
        'organizationId': organizationId,
        'description': 'Organization setup completed and metrics tracking enabled',
      };

      await FirestoreTTLHelper.setWithTTL(logRef, logData);
    } catch (e) {
      logger.e('[OrganizationSetupService] Error logging setup activation: $e');
      // Don't fail the main operation if logging fails
    }
  }

  /// Get setup recommendations for incomplete requirements
  List<Map<String, dynamic>> getSetupRecommendations(Map<String, dynamic> setupStatus) {
    final recommendations = <Map<String, dynamic>>[];
    final requirements = setupStatus['requirements'] as Map<String, dynamic>? ?? {};

    for (final reqEntry in requirements.entries) {
      Map<String, dynamic> requirement = {};
      try {
        if (reqEntry.value is Map) {
          requirement = Map<String, dynamic>.from(reqEntry.value as Map);
        }
      } catch (_) {
        // skip malformed entries silently
        continue;
      }
      if (!requirement['met']) {
        recommendations.add({
          'title': 'Complete ${requirement['name']} Setup',
          'description': requirement['description'],
          'icon': requirement['icon'],
          'action': _getRecommendedAction(reqEntry.key),
        });
      }
    }

    return recommendations;
  }

  /// Get recommended action for each setup type
  String _getRecommendedAction(String requirementType) {
    switch (requirementType) {
      case 'locations':
        return 'Go to Settings → Manage Locations to add your first location';
      case 'shifts':
        return 'Go to Settings → Manage Shifts to define work schedules';
      case 'checklists':
        return 'Go to Admin Dashboard → Checklists to create your first template';
      case 'users':
        return 'Go to Settings → Manage Users to invite team members';
      default:
        return 'Complete this setup step to continue';
    }
  }
}
