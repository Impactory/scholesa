import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../modules/educator/educator_service.dart';
import 'bos_models.dart';

typedef SessionOccurrenceResolver = Future<String?> Function(
  BuildContext context, {
  required String siteId,
  required String learnerId,
});

/// Derive a BOS grade band from the active user role.
GradeBand gradeBandForRole(UserRole role) {
  switch (role) {
    case UserRole.learner:
    case UserRole.parent:
      return GradeBand.g4_6;
    case UserRole.educator:
    case UserRole.site:
    case UserRole.partner:
    case UserRole.hq:
      return GradeBand.g7_9;
  }
}

/// Best-effort Firestore lookup for the most recent sessionOccurrenceId.
Future<String?> lookupSessionOccurrenceFromFirestore(
  FirebaseFirestore firestore, {
  required String siteId,
  required String learnerId,
}) async {
  try {
    final QuerySnapshot<Map<String, dynamic>> attempts = await firestore
        .collection('missionAttempts')
        .where('learnerId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId)
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in attempts.docs) {
      final String value =
          (doc.data()['sessionOccurrenceId'] as String? ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  } catch (_) {
    // Best-effort only; continue to interaction event fallback.
  }

  try {
    final QuerySnapshot<Map<String, dynamic>> interactions = await firestore
        .collection('interactionEvents')
        .where('actorId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId)
        .where('eventType', isEqualTo: 'session_joined')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (interactions.docs.isNotEmpty) {
      final Map<String, dynamic> data = interactions.docs.first.data();
      final String topLevel =
          (data['sessionOccurrenceId'] as String? ?? '').trim();
      if (topLevel.isNotEmpty) {
        return topLevel;
      }
      final Map<String, dynamic>? payload =
          data['payload'] as Map<String, dynamic>?;
      final String fromPayload =
          (payload?['sessionOccurrenceId'] as String? ?? '').trim();
      if (fromPayload.isNotEmpty) {
        return fromPayload;
      }
    }
  } catch (_) {
    // Keep null when unavailable.
  }

  return null;
}

/// Resolve the session occurrence ID for the AI assistant.
///
/// Priority: custom resolver > educator service > Firestore lookup.
Future<String?> resolveSessionOccurrenceId(
  BuildContext context, {
  required String siteId,
  required String learnerId,
  UserRole? role,
  SessionOccurrenceResolver? sessionOccurrenceResolver,
  FirebaseFirestore? firestore,
}) async {
  if (sessionOccurrenceResolver != null) {
    return sessionOccurrenceResolver(
      context,
      siteId: siteId,
      learnerId: learnerId,
    );
  }

  if (role == UserRole.educator ||
      role == UserRole.site ||
      role == UserRole.hq) {
    final EducatorService? educatorService = context.read<EducatorService?>();
    final String? currentClassId = educatorService?.currentClass?.id;
    if (currentClassId != null && currentClassId.trim().isNotEmpty) {
      return currentClassId.trim();
    }
    if (educatorService != null && educatorService.todayClasses.isNotEmpty) {
      return educatorService.todayClasses.first.id.trim();
    }
  }

  return lookupSessionOccurrenceFromFirestore(
    firestore ?? FirebaseFirestore.instance,
    siteId: siteId,
    learnerId: learnerId,
  );
}
