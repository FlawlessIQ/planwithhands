import 'package:cloud_functions/cloud_functions.dart';

class InviteService {
  InviteService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  static Future<Map<String, dynamic>> createInvite({
    required String email,
    required String firstName,
    required String lastName,
    required int userRole,
    required String organizationId,
    required List<String> locationIds,
    required List<String> jobTypes,
    String? preferredLanguageCode,
  }) async {
    final callable = _functions.httpsCallable('createInvite');
    final response = await callable.call(<String, dynamic>{
      'email': email.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'userRole': userRole,
      'organizationId': organizationId,
      'locationIds': locationIds,
      'jobTypes': jobTypes,
      if (preferredLanguageCode != null)
        'preferredLanguageCode': preferredLanguageCode,
    });

    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> verifyInvite(String inviteId) async {
    final callable = _functions.httpsCallable('verifyInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> acceptInvite({
    required String inviteId,
    required String password,
    String? preferredLanguageCode,
  }) async {
    final callable = _functions.httpsCallable('acceptInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
      'password': password,
      if (preferredLanguageCode != null)
        'preferredLanguageCode': preferredLanguageCode,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> lookupInviteByEmail(
    String email, {
    bool logMatchEvent = false,
    String? source,
  }) async {
    final callable = _functions.httpsCallable('lookupInviteByEmail');
    final response = await callable.call(<String, dynamic>{
      'email': email.trim(),
      'logMatchEvent': logMatchEvent,
      'source': source,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> resendInvite(String inviteId) async {
    final callable = _functions.httpsCallable('resendInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> revokeInvite(String inviteId) async {
    final callable = _functions.httpsCallable('revokeInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}
