import 'package:cloud_functions/cloud_functions.dart';

class AttendanceTrendPoint {
  const AttendanceTrendPoint({
    required this.date,
    required this.records,
    required this.events,
    this.presentRate,
  });

  final String date;
  final int records;
  final int events;
  final double? presentRate;

  factory AttendanceTrendPoint.fromMap(Map<String, dynamic> data) {
    return AttendanceTrendPoint(
      date: (data['date'] as String?) ?? '',
      records: _asInt(data['records']),
      events: _asInt(data['events']),
      presentRate: _asDoubleOrNull(data['presentRate']),
    );
  }
}

class TelemetryDashboardMetrics {
  const TelemetryDashboardMetrics({
    required this.weeklyAccountabilityAdherenceRate,
    this.educatorReviewTurnaroundHoursAvg,
    this.educatorReviewWithinSlaRate,
    required this.educatorReviewSlaHours,
    this.interventionHelpedRate,
    required this.interventionTotal,
    required this.attendanceTrend,
  });

  final double weeklyAccountabilityAdherenceRate;
  final double? educatorReviewTurnaroundHoursAvg;
  final double? educatorReviewWithinSlaRate;
  final int educatorReviewSlaHours;
  final double? interventionHelpedRate;
  final int interventionTotal;
  final List<AttendanceTrendPoint> attendanceTrend;

  factory TelemetryDashboardMetrics.fromMap(Map<String, dynamic> data) {
    final List<dynamic> trendRaw =
        (data['attendanceTrend'] as List<dynamic>? ?? <dynamic>[]);
    return TelemetryDashboardMetrics(
      weeklyAccountabilityAdherenceRate:
          _asDouble(data['weeklyAccountabilityAdherenceRate']),
      educatorReviewTurnaroundHoursAvg:
          _asDoubleOrNull(data['educatorReviewTurnaroundHoursAvg']),
      educatorReviewWithinSlaRate:
          _asDoubleOrNull(data['educatorReviewWithinSlaRate']),
      educatorReviewSlaHours:
          _asInt(data['educatorReviewSlaHours'], fallback: 48),
      interventionHelpedRate: _asDoubleOrNull(data['interventionHelpedRate']),
      interventionTotal: _asInt(data['interventionTotal']),
      attendanceTrend: trendRaw
          .whereType<Map>()
          .map((Map raw) =>
              AttendanceTrendPoint.fromMap(Map<String, dynamic>.from(raw)))
          .toList(),
    );
  }
}

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();
  FirebaseFunctions? _functions;

  FirebaseFunctions get _requiredFunctions {
    return _functions ??= FirebaseFunctions.instance;
  }

  Future<TelemetryDashboardMetrics> getTelemetryDashboardMetrics({
    String? siteId,
    String period = 'week',
  }) async {
    final HttpsCallableResult<dynamic> result = await _requiredFunctions
        .httpsCallable('getTelemetryDashboardMetrics')
        .call(<String, dynamic>{
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      'period': period,
    });

    final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{});
    return TelemetryDashboardMetrics.fromMap(
      Map<String, dynamic>.from(
        data['metrics'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      ),
    );
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? _asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
