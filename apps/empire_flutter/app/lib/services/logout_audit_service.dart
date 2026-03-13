import 'package:cloud_functions/cloud_functions.dart';

class LogoutAuditService {
  LogoutAuditService({FirebaseFunctions? functions}) : _functions = functions;

  static LogoutAuditService? _instance;
  static LogoutAuditService get instance =>
      _instance ??= LogoutAuditService();

  FirebaseFunctions? _functions;

  FirebaseFunctions get _requiredFunctions =>
      _functions ??= FirebaseFunctions.instance;

  Future<void> recordLogout({
    required String source,
    String? role,
    String? siteId,
    String? impersonatingRole,
  }) async {
    await _requiredFunctions.httpsCallable('recordLogoutAudit').call(
      <String, dynamic>{
        'source': source,
        if (role != null && role.isNotEmpty) 'role': role,
        if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
        if (impersonatingRole != null && impersonatingRole.isNotEmpty)
          'impersonatingRole': impersonatingRole,
      },
    );
  }
}