import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Growth Engine — connects evidence capture to capability growth.
///
/// Routes all mastery and growth writes through Cloud Functions for
/// server-side validation, atomicity, and badge auto-evaluation.
class GrowthEngineService {
  GrowthEngineService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functionsOverride = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions => _functionsOverride ?? FirebaseFunctions.instance;

  static const Map<String, int> _levelToScore = <String, int>{
    'emerging': 1,
    'developing': 2,
    'proficient': 3,
    'advanced': 4,
  };

  /// Called after an educator applies a rubric judgment.
  ///
  /// Routes through `applyRubricToEvidence` Cloud Function which atomically:
  /// 1. Creates a RubricApplication doc
  /// 2. Upserts CapabilityMastery
  /// 3. Creates immutable CapabilityGrowthEvent
  /// 4. Writes skillMastery for linked microSkills
  /// 5. Triggers badge auto-evaluation
  Future<String?> onRubricApplied({
    required String learnerId,
    required String capabilityId,
    required String educatorId,
    required String rubricLevel,
    required String siteId,
    String? rubricApplicationId,
    List<String> evidenceIds = const <String>[],
    String? feedback,
    String? pillarCode,
  }) async {
    try {
      final int score = _levelToScore[rubricLevel.toLowerCase().trim()] ?? 1;
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('applyRubricToEvidence')
          .call(<String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'evidenceRecordIds': evidenceIds,
        'scores': <Map<String, dynamic>>[
          <String, dynamic>{
            'criterionId': rubricApplicationId ?? 'growth-engine',
            'capabilityId': capabilityId,
            'pillarCode': pillarCode ?? 'FUTURE_SKILLS',
            'score': score,
            'maxScore': 4,
          },
        ],
      });

      final Map<dynamic, dynamic>? data =
          result.data is Map<dynamic, dynamic>
              ? result.data as Map<dynamic, dynamic>
              : null;
      return data?['rubricApplicationId'] as String?;
    } catch (e) {
      debugPrint('GrowthEngine.onRubricApplied error: $e');
      rethrow;
    }
  }

  /// Called after a learner completes a checkpoint.
  ///
  /// Routes through `processCheckpointMasteryUpdate` Cloud Function which:
  /// 1. Updates skillMastery for linked skills
  /// 2. Updates capabilityMastery if threshold met
  /// 3. Creates immutable capabilityGrowthEvent
  /// 4. Triggers badge auto-evaluation
  Future<void> onCheckpointCompleted({
    required String learnerId,
    required String siteId,
    String? skillId,
    required bool isCorrect,
    String? checkpointId,
    String? educatorId,
  }) async {
    if (skillId == null || !isCorrect) return;

    try {
      await _functions
          .httpsCallable('processCheckpointMasteryUpdate')
          .call(<String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'checkpointId': checkpointId ?? 'checkpoint_${DateTime.now().millisecondsSinceEpoch}',
        'skillIds': <String>[skillId],
        'passed': true,
        if (educatorId != null) 'educatorId': educatorId,
      });
    } catch (e) {
      debugPrint('GrowthEngine.onCheckpointCompleted error: $e');
      rethrow;
    }
  }

  /// Called after an educator verifies a proof-of-learning bundle.
  ///
  /// Updates the linked portfolio item's proof status. This is a simple
  /// status update that doesn't need server-side mastery computation.
  Future<void> onProofVerified({
    required String bundleId,
    required String learnerId,
    String? portfolioItemId,
    String? capabilityId,
  }) async {
    try {
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
      rethrow;
    }
  }
}
