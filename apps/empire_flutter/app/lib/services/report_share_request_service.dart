import 'package:cloud_functions/cloud_functions.dart';

typedef ReportShareRequestInvoker = Future<dynamic> Function(
  String callableName,
  Map<String, dynamic> payload,
);

class ReportShareRequestService {
  ReportShareRequestService._();

  static final ReportShareRequestService instance =
      ReportShareRequestService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instance;
  static ReportShareRequestInvoker? _callableInvokerOverride;

  static Future<T> runWithCallableInvoker<T>(
    ReportShareRequestInvoker invoker,
    Future<T> Function() action,
  ) async {
    final ReportShareRequestInvoker? previous = _callableInvokerOverride;
    _callableInvokerOverride = invoker;
    try {
      return await action();
    } finally {
      _callableInvokerOverride = previous;
    }
  }

  static bool shouldCreate({
    required String reportDelivery,
    required Map<String, dynamic> metadata,
  }) {
    return <String>{'shared', 'copied', 'downloaded'}
            .contains(reportDelivery) &&
        metadata['report_meets_delivery_contract'] == true;
  }

  Future<dynamic> _call(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    if (_callableInvokerOverride != null) {
      return _callableInvokerOverride!(callableName, payload);
    }
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable(callableName).call(payload);
    return result.data;
  }

  Future<String?> create({
    required String? siteId,
    required String? learnerId,
    required String reportAction,
    required String reportDelivery,
    required String module,
    required String surface,
    required String cta,
    required Map<String, dynamic> metadata,
    String? fileName,
  }) async {
    if ((siteId ?? '').trim().isEmpty ||
        (learnerId ?? '').trim().isEmpty ||
        metadata.isEmpty ||
        !shouldCreate(reportDelivery: reportDelivery, metadata: metadata)) {
      return null;
    }

    try {
      final dynamic response = await _call(
        'createReportShareRequest',
        <String, dynamic>{
          'siteId': siteId!.trim(),
          'learnerId': learnerId!.trim(),
          'reportAction': reportAction,
          'reportDelivery': reportDelivery,
          'module': module,
          'source': module,
          'surface': surface,
          'cta': cta,
          if ((fileName ?? '').trim().isNotEmpty) 'fileName': fileName!.trim(),
          'audience': metadata['report_share_audience'],
          'visibility': metadata['report_share_visibility'],
          'metadata': metadata,
        },
      );
      if (response is Map && response['id'] is String) {
        return response['id'] as String;
      }
    } catch (_) {
      // Best-effort lifecycle record; report delivery UX must not depend on it.
    }
    return null;
  }

  Future<bool> revoke({
    required String? shareRequestId,
    String? reason,
  }) async {
    if ((shareRequestId ?? '').trim().isEmpty) {
      return false;
    }

    try {
      await _call(
        'revokeReportShareRequest',
        <String, dynamic>{
          'shareRequestId': shareRequestId!.trim(),
          if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
