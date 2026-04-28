import 'package:cloud_functions/cloud_functions.dart';

typedef ReportDeliveryAuditInvoker = Future<dynamic> Function(
  String callableName,
  Map<String, dynamic> payload,
);

class ReportDeliveryAuditService {
  ReportDeliveryAuditService._();

  static final ReportDeliveryAuditService instance =
      ReportDeliveryAuditService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instance;
  static ReportDeliveryAuditInvoker? _callableInvokerOverride;

  static Future<T> runWithCallableInvoker<T>(
    ReportDeliveryAuditInvoker invoker,
    Future<T> Function() action,
  ) async {
    final ReportDeliveryAuditInvoker? previous = _callableInvokerOverride;
    _callableInvokerOverride = invoker;
    try {
      return await action();
    } finally {
      _callableInvokerOverride = previous;
    }
  }

  Future<void> _call(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    if (_callableInvokerOverride != null) {
      await _callableInvokerOverride!(callableName, payload);
      return;
    }
    await _functions.httpsCallable(callableName).call(payload);
  }

  Future<void> record({
    required String? siteId,
    required String? learnerId,
    required String reportAction,
    required String reportDelivery,
    required String module,
    required String surface,
    required String cta,
    required Map<String, dynamic> metadata,
    String? reportBlockReason,
    String? fileName,
    String? shareRequestId,
  }) async {
    if ((siteId ?? '').trim().isEmpty ||
        (learnerId ?? '').trim().isEmpty ||
        metadata.isEmpty) {
      return;
    }

    try {
      await _call('recordReportDeliveryAudit', <String, dynamic>{
        'siteId': siteId!.trim(),
        'learnerId': learnerId!.trim(),
        'reportAction': reportAction,
        'reportDelivery': reportDelivery,
        if ((reportBlockReason ?? '').trim().isNotEmpty)
          'reportBlockReason': reportBlockReason!.trim(),
        'module': module,
        'surface': surface,
        'cta': cta,
        if ((fileName ?? '').trim().isNotEmpty) 'fileName': fileName!.trim(),
        if ((shareRequestId ?? '').trim().isNotEmpty)
          'shareRequestId': shareRequestId!.trim(),
        'metadata': metadata,
      });
    } catch (_) {
      // Best-effort audit; report delivery UX must not depend on this write.
    }
  }
}
