import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

/// Growth Engine — connects evidence capture to capability growth.
///
/// Transforms rubric applications, checkpoint completions, and proof
/// verifications into capability mastery updates and immutable growth events.
class GrowthEngineService {
  GrowthEngineService({
    FirestoreService? firestoreService,
    FirebaseFirestore? firestore,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirestoreService _firestoreService;
  final FirebaseFirestore _firestore;

  /// Called after an educator applies a rubric judgment.
  ///
  /// 1. Reads current capabilityMastery for learner+capability
  /// 2. Computes new mastery level from rubric level
  /// 3. Writes updated capabilityMastery doc
  /// 4. Appends immutable capabilityGrowthEvent (educator attribution)
  Future<String?> onRubricApplied({
    required String learnerId,
    required String capabilityId,
    required String educatorId,
    required String rubricLevel,
    required String siteId,
    String? rubricApplicationId,
    List<String> evidenceIds = const <String>[],
    String? feedback,
  }) async {
    try {
      // 1. Read current mastery
      final String masteryDocId = '${learnerId}_$capabilityId';
      final DocumentSnapshot<Map<String, dynamic>> masteryDoc =
          await _firestore
              .collection('capabilityMastery')
              .doc(masteryDocId)
              .get();

      final String? previousLevel = masteryDoc.exists
          ? (masteryDoc.data()?['currentLevel']) as String?
          : null;

      // 2. Compute new mastery level from rubric level
      final String newLevel = _computeMasteryLevel(rubricLevel, previousLevel);

      // 3. Write updated mastery
      await _firestoreService.updateCapabilityMastery(
        learnerId: learnerId,
        capabilityId: capabilityId,
        newLevel: newLevel,
        educatorId: educatorId,
      );

      // 4. Append growth event (only if level changed or first assessment)
      if (previousLevel != newLevel || previousLevel == null) {
        final String eventId =
            await _firestoreService.createCapabilityGrowthEvent(
          learnerId: learnerId,
          capabilityId: capabilityId,
          fromLevel: previousLevel,
          toLevel: newLevel,
          educatorId: educatorId,
          rubricApplicationId: rubricApplicationId,
          evidenceIds: evidenceIds,
          siteId: siteId,
        );
        return eventId;
      }

      return null;
    } catch (e) {
      debugPrint('GrowthEngine.onRubricApplied error: $e');
      rethrow;
    }
  }

  /// Called after a learner completes a checkpoint.
  ///
  /// 1. If checkpoint maps to a skill, updates skillMastery
  /// 2. If skill maps to a capability, checks threshold for mastery bump
  Future<void> onCheckpointCompleted({
    required String learnerId,
    required String siteId,
    String? skillId,
    required bool isCorrect,
  }) async {
    if (skillId == null || !isCorrect) return;

    try {
      // Update skill mastery count
      final String skillMasteryDocId = '${learnerId}_$skillId';
      final DocumentReference<Map<String, dynamic>> ref =
          _firestore.collection('skillMastery').doc(skillMasteryDocId);

      await _firestore.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> doc = await tx.get(ref);

        int correctCount = 1;
        int totalCount = 1;
        if (doc.exists) {
          correctCount =
              (doc.data()?['correctCount'] as int? ?? 0) + 1;
          totalCount = (doc.data()?['totalCount'] as int? ?? 0) + 1;
        }

        tx.set(
          ref,
          <String, dynamic>{
            'learnerId': learnerId,
            'skillId': skillId,
            'correctCount': correctCount,
            'totalCount': totalCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Check if skill's parent capability should be bumped
      await _checkCapabilityThreshold(learnerId: learnerId, skillId: skillId, siteId: siteId);
    } catch (e) {
      debugPrint('GrowthEngine.onCheckpointCompleted error: $e');
    }
  }

  /// Called after an educator verifies a proof-of-learning bundle.
  ///
  /// Updates the linked portfolio item's proof status and optionally
  /// bumps capability confidence.
  Future<void> onProofVerified({
    required String bundleId,
    required String learnerId,
    String? portfolioItemId,
    String? capabilityId,
  }) async {
    try {
      // Update portfolio item proof status if linked
      if (portfolioItemId != null) {
        await _firestore.collection('portfolioItems').doc(portfolioItemId).update(
          <String, dynamic>{
            'proofOfLearningStatus': 'verified',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (e) {
      debugPrint('GrowthEngine.onProofVerified error: $e');
    }
  }

  /// Maps rubric level strings to a canonical mastery progression.
  /// Takes the rubric level and optionally the previous mastery level.
  String _computeMasteryLevel(String rubricLevel, String? previousLevel) {
    const List<String> progression = <String>[
      'emerging',
      'developing',
      'proficient',
      'advanced',
    ];

    final String normalized = rubricLevel.toLowerCase().trim();
    if (progression.contains(normalized)) return normalized;

    // Map numeric scores to levels
    final int? score = int.tryParse(normalized);
    if (score != null) {
      if (score >= 4) return 'advanced';
      if (score >= 3) return 'proficient';
      if (score >= 2) return 'developing';
      return 'emerging';
    }

    // Fall back to previous level or emerging
    return previousLevel ?? 'emerging';
  }

  /// Check if enough skills in a capability have been mastered to bump
  /// the capability level.
  Future<void> _checkCapabilityThreshold({
    required String learnerId,
    required String skillId,
    required String siteId,
  }) async {
    // Look up which capability this skill belongs to
    final QuerySnapshot<Map<String, dynamic>> skillDocs = await _firestore
        .collection('microSkills')
        .where('id', isEqualTo: skillId)
        .limit(1)
        .get();

    if (skillDocs.docs.isEmpty) return;

    final String? capabilityId =
        skillDocs.docs.first.data()['capabilityId'] as String?;
    if (capabilityId == null) return;

    // Count mastered skills for this capability
    final QuerySnapshot<Map<String, dynamic>> allSkills = await _firestore
        .collection('microSkills')
        .where('capabilityId', isEqualTo: capabilityId)
        .get();

    if (allSkills.docs.isEmpty) return;

    int masteredCount = 0;
    for (final doc in allSkills.docs) {
      final String sid = doc.id;
      final DocumentSnapshot<Map<String, dynamic>> mastery = await _firestore
          .collection('skillMastery')
          .doc('${learnerId}_$sid')
          .get();

      if (mastery.exists) {
        final int correct = mastery.data()?['correctCount'] as int? ?? 0;
        final int total = mastery.data()?['totalCount'] as int? ?? 0;
        if (total >= 3 && correct / total >= 0.7) {
          masteredCount++;
        }
      }
    }

    // If 70%+ of skills mastered, bump capability to next level
    final double ratio = masteredCount / allSkills.docs.length;
    if (ratio >= 0.7) {
      final String masteryDocId = '${learnerId}_$capabilityId';
      final DocumentSnapshot<Map<String, dynamic>> currentMastery =
          await _firestore
              .collection('capabilityMastery')
              .doc(masteryDocId)
              .get();

      final String currentLevel =
          currentMastery.data()?['currentLevel'] as String? ?? 'emerging';

      String nextLevel = currentLevel;
      if (ratio >= 0.9 && currentLevel != 'advanced') {
        nextLevel = 'advanced';
      } else if (ratio >= 0.7 && currentLevel == 'emerging') {
        nextLevel = 'developing';
      } else if (ratio >= 0.7 && currentLevel == 'developing') {
        nextLevel = 'proficient';
      }

      if (nextLevel != currentLevel) {
        await _firestoreService.updateCapabilityMastery(
          learnerId: learnerId,
          capabilityId: capabilityId,
          newLevel: nextLevel,
          educatorId: 'system',
        );
        await _firestoreService.createCapabilityGrowthEvent(
          learnerId: learnerId,
          capabilityId: capabilityId,
          fromLevel: currentLevel,
          toLevel: nextLevel,
          educatorId: 'system',
          siteId: siteId,
        );
      }
    }
  }
}
