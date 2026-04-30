import 'package:cloud_functions/cloud_functions.dart';

class CrmService {
  const CrmService();

  Future<Map<String, dynamic>> getDashboard({
    int limit = 100,
    bool includeArchived = false,
  }) async {
    return _call('getCrmDashboard', {
      'limit': limit,
      'includeArchived': includeArchived,
    });
  }

  Future<Map<String, dynamic>> getOrganization(String organizationId) async {
    return _call('getCrmOrganization', {'organizationId': organizationId});
  }

  Future<List<Map<String, dynamic>>> listPromotionCodes() async {
    final result = await _call('listCrmPromotionCodes', {});
    final codes = result['codes'];
    if (codes is List) {
      return codes
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createPromotionCode({
    required String code,
    required int percentOff,
    required String campaign,
    int? maxRedemptions,
  }) {
    return _call('createCrmPromotionCode', {
      'code': code,
      'percentOff': percentOff,
      'duration': 'once',
      if (campaign.trim().isNotEmpty) 'campaign': campaign.trim(),
      if (maxRedemptions != null && maxRedemptions > 0)
        'maxRedemptions': maxRedemptions,
    });
  }

  Future<void> updateOrganizationFlags({
    required String organizationId,
    bool? archived,
    bool? excludeFromMrr,
    bool? excludeFromMetrics,
    String? accountType,
    String? reason,
  }) async {
    await _call('updateCrmOrganizationFlags', {
      'organizationId': organizationId,
      if (archived != null) 'archived': archived,
      if (excludeFromMrr != null) 'excludeFromMrr': excludeFromMrr,
      if (excludeFromMetrics != null) 'excludeFromMetrics': excludeFromMetrics,
      if (accountType != null) 'accountType': accountType,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(functionName);
    final result = await callable.call(payload);
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
