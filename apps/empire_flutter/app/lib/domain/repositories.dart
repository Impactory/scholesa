import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/telemetry_service.dart';
import 'models.dart';

class UserRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users');

  Future<UserModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<void> upsert(UserModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class LearnerProfileRepository {
  LearnerProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('learnerProfiles');

  Future<void> upsert(LearnerProfileModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<LearnerProfileModel?> getByLearnerAndSite({
    required String learnerId,
    required String siteId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('learnerId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LearnerProfileModel.fromDoc(snap.docs.first);
  }

  Future<List<LearnerProfileModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(LearnerProfileModel.fromDoc).toList();
  }
}

class LearnerReflectionRepository {
  LearnerReflectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('learnerReflections');

  Future<String> create({
    required String learnerId,
    required String siteId,
    required String reflectionType,
    required String response,
    String? prompt,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc = _col.doc();
    await doc.set(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'reflectionType': reflectionType,
      'prompt': prompt,
      'response': response,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    try {
      await TelemetryService.instance.logEvent(
        event: 'reflection.submitted',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'reflectionType': reflectionType,
          'responseLength': response.length,
          'hasPrompt': prompt != null && prompt.trim().isNotEmpty,
        },
      );
    } catch (_) {}
    return doc.id;
  }
}

class MetacognitiveCalibrationRepository {
  MetacognitiveCalibrationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('metacognitiveCalibrationRecords');

  Future<void> upsert(MetacognitiveCalibrationRecordModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MetacognitiveCalibrationRecordModel>> listByLearner({
    required String siteId,
    required String learnerId,
    int limit = 100,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(limit)
        .get();
    final List<MetacognitiveCalibrationRecordModel> records =
        snap.docs.map(MetacognitiveCalibrationRecordModel.fromDoc).toList();
    records.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return records;
  }
}

class ParentProfileRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('parentProfiles');

  Future<void> upsert(ParentProfileModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ParentProfileModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(ParentProfileModel.fromDoc).toList();
  }
}

class GuardianLinkRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('guardianLinks');

  Future<void> upsert(GuardianLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<String> create(
      {required String parentId,
      required String learnerId,
      required String siteId,
      String? relationship,
      bool? isPrimary}) async {
    final doc = _col.doc();
    final model = GuardianLinkModel(
      id: doc.id,
      parentId: parentId,
      learnerId: learnerId,
      siteId: siteId,
      relationship: relationship,
      isPrimary: isPrimary,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<GuardianLinkModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(GuardianLinkModel.fromDoc).toList();
  }

  Future<List<GuardianLinkModel>> listByParent(String parentId) async {
    final snap = await _col.where('parentId', isEqualTo: parentId).get();
    return snap.docs.map(GuardianLinkModel.fromDoc).toList();
  }
}

class HabitRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('habits');

  Future<void> upsert(HabitModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<HabitModel>> listActiveByLearner(String learnerId,
      {int limit = 20}) async {
    final snap = await _col
        .where('learnerId', isEqualTo: learnerId)
        .where('status', isEqualTo: 'active')
        .orderBy('nextCheckInAt', descending: false)
        .limit(limit)
        .get();
    return snap.docs.map(HabitModel.fromDoc).toList();
  }

  Future<void> markCompleted({required String id}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'completed',
      'lastCompletedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> recordReflection({required String id}) async {
    await _col.doc(id).set(<String, dynamic>{
      'lastReflectedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

class SiteRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('sites');

  Future<List<SiteModel>> list() async {
    final snap = await _col.get();
    return snap.docs.map(SiteModel.fromDoc).toList();
  }

  Future<void> upsert(SiteModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SessionRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('sessions');

  Future<List<SessionModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(SessionModel.fromDoc).toList();
  }

  Future<void> upsert(SessionModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SessionOccurrenceRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('sessionOccurrences');

  Future<List<SessionOccurrenceModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(SessionOccurrenceModel.fromDoc).toList();
  }

  Future<void> upsert(SessionOccurrenceModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class EnrollmentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('enrollments');

  Future<List<EnrollmentModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(EnrollmentModel.fromDoc).toList();
  }

  Future<List<EnrollmentModel>> listByLearnerIds(
      {required String siteId, required List<String> learnerIds}) async {
    if (learnerIds.isEmpty) return <EnrollmentModel>[];
    final limited = learnerIds.take(10).toList();
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', whereIn: limited)
        .get();
    return snap.docs.map(EnrollmentModel.fromDoc).toList();
  }

  Future<void> upsert(EnrollmentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AttendanceRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('attendanceRecords');

  String deterministicId(String sessionOccurrenceId, String learnerId) =>
      '${sessionOccurrenceId}_$learnerId';

  Future<void> upsert(AttendanceRecordModel model) {
    final id = model.id.isNotEmpty
        ? model.id
        : deterministicId(model.sessionOccurrenceId, model.learnerId);
    return _col.doc(id).set(model.toMap(), SetOptions(merge: true));
  }

  Future<List<AttendanceRecordModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(AttendanceRecordModel.fromDoc).toList();
  }

  Future<List<AttendanceRecordModel>> listRecentBySite(String siteId,
      {int limit = 10}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AttendanceRecordModel.fromDoc).toList();
  }

  Future<List<AttendanceRecordModel>> listRecentByLearners(
      List<String> learnerIds,
      {int limit = 20}) async {
    if (learnerIds.isEmpty) return <AttendanceRecordModel>[];
    final limited = learnerIds.take(10).toList();
    final snap = await _col
        .where('learnerId', whereIn: limited)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AttendanceRecordModel.fromDoc).toList();
  }
}

class PillarRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('pillars');

  Future<List<PillarModel>> list() async {
    final snap = await _col.get();
    return snap.docs.map(PillarModel.fromDoc).toList();
  }

  Future<void> upsert(PillarModel model) =>
      _col.doc(model.code).set(model.toMap(), SetOptions(merge: true));
}

class SkillRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('skills');

  Future<List<SkillModel>> listByPillar(String pillarCode) async {
    final snap = await _col.where('pillarCode', isEqualTo: pillarCode).get();
    return snap.docs.map(SkillModel.fromDoc).toList();
  }

  Future<void> upsert(SkillModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class SkillMasteryRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('skillMastery');

  Future<List<SkillMasteryModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(SkillMasteryModel.fromDoc).toList();
  }

  Future<void> upsert(SkillMasteryModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('missions');

  Future<List<MissionModel>> listBySiteOrGlobal(String siteId) async {
    final snap =
        await _col.where('siteId', whereIn: <String?>[siteId, null]).get();
    return snap.docs.map(MissionModel.fromDoc).toList();
  }

  Future<void> upsert(MissionModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionPlanRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('missionPlans');

  Future<void> upsert(MissionPlanModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class MissionAttemptRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('missionAttempts');

  Future<void> upsert(MissionAttemptModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MissionAttemptModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(MissionAttemptModel.fromDoc).toList();
  }

  Future<List<MissionAttemptModel>> listBySite(String siteId,
      {int limit = 50}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MissionAttemptModel.fromDoc).toList();
  }
}

class PortfolioRepository {
  PortfolioRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('portfolios');

  Future<void> upsert(PortfolioModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class PortfolioItemRepository {
  PortfolioItemRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('portfolioItems');

  Future<void> upsert(PortfolioItemModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<PortfolioItemModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(PortfolioItemModel.fromDoc).toList();
  }

  Future<List<PortfolioItemModel>> listByLearners(List<String> learnerIds,
      {int limit = 50}) async {
    if (learnerIds.isEmpty) return <PortfolioItemModel>[];
    final limited = learnerIds.take(10).toList();
    final snap = await _col
        .where('learnerId', whereIn: limited)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PortfolioItemModel.fromDoc).toList();
  }
}

class CredentialRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('credentials');

  Future<void> upsert(CredentialModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<CredentialModel>> listByLearner(String learnerId,
      {String? siteId, int limit = 10}) async {
    Query<Map<String, dynamic>> query = _col
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('issuedAt', descending: true)
        .limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    return snap.docs.map(CredentialModel.fromDoc).toList();
  }
}

class AccountabilityCycleRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('accountabilityCycles');

  Future<void> upsert(AccountabilityCycleModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AccountabilityKPIRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('accountabilityKPIs');

  Future<void> upsert(AccountabilityKPIModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<AccountabilityKPIModel>> listRecent({int limit = 6}) async {
    final snap =
        await _col.orderBy('updatedAt', descending: true).limit(limit).get();
    return snap.docs.map(AccountabilityKPIModel.fromDoc).toList();
  }
}

class AccountabilityCommitmentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('accountabilityCommitments');

  Future<void> upsert(AccountabilityCommitmentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AccountabilityReviewRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('accountabilityReviews');

  Future<void> upsert(AccountabilityReviewModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
}

class AuditLogRepository {
  AuditLogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('auditLogs');

  Future<void> log(AuditLogModel model) =>
      _col.doc(model.id).set(model.toMap());
}

class AnnouncementRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('announcements');

  Future<List<AnnouncementModel>> listBySiteAndRole(
      {required String siteId, required String role}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('roles', arrayContains: role)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return snap.docs.map(AnnouncementModel.fromDoc).toList();
  }
}

class CmsRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('cmsPages');

  Future<CmsPageModel?> fetchPublishedBySlug(
      {required String slug, String? role}) async {
    final docRef = _col.doc(slug);
    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await docRef.get(const GetOptions(source: Source.cache));
      if (!doc.exists) {
        doc = null;
      }
    } catch (_) {
      doc = null;
    }

    if (doc == null) {
      try {
        doc = await docRef.get();
      } catch (_) {
        return null;
      }
    }
    if (!doc.exists) return null;
    final model = CmsPageModel.fromDoc(doc);
    if (model.status != 'published') return null;
    final audience = model.audience.toLowerCase();
    final normalizedRole = role?.toLowerCase();
    final audienceAllowsAll =
        audience == 'public' || audience == 'any' || audience == 'all';
    final audienceMatchesRole = normalizedRole != null &&
        normalizedRole.isNotEmpty &&
        audience == normalizedRole;
    if (!audienceAllowsAll && !audienceMatchesRole) return null;
    return model;
  }
}

class MessageThreadRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('messageThreads');

  Future<void> upsert(MessageThreadModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MessageThreadModel>> listByParticipant(
      {required String userId, String? siteId, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _col
        .where('participantIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    return snap.docs.map(MessageThreadModel.fromDoc).toList();
  }
}

class MessageRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('messages');

  Future<void> add(MessageModel model) => _col.doc(model.id).set(model.toMap());

  Future<List<MessageModel>> listByThread(String threadId,
      {int limit = 50}) async {
    final snap = await _col
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MessageModel.fromDoc).toList();
  }
}

class LeadRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('leads');

  Future<void> createLead({
    required String name,
    required String email,
    required String source,
    String status = 'new',
    String? message,
    String? siteId,
    String? slug,
  }) async {
    final doc = _col.doc();
    final model = LeadModel(
      id: doc.id,
      name: name,
      email: email,
      source: source,
      status: status,
      message: message,
      siteId: siteId,
      slug: slug,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    try {
      await TelemetryService.instance.logEvent(
        event: 'lead.submitted',
        siteId: siteId,
        metadata: <String, dynamic>{
          'leadId': doc.id,
          'source': source,
          'status': status,
          'hasMessage': message != null && message.trim().isNotEmpty,
          if (slug != null && slug.isNotEmpty) 'slug': slug,
        },
      );
    } catch (_) {}
  }
}

class OrderRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('orders');

  Future<String> createPaidOrder({
    required String siteId,
    required String userId,
    required String productId,
    required String amount,
    required String currency,
    List<String> entitlementRoles = const <String>[],
  }) async {
    final doc = _col.doc();
    final model = OrderModel(
      id: doc.id,
      siteId: siteId,
      userId: userId,
      productId: productId,
      amount: amount,
      currency: currency,
      entitlementRoles: entitlementRoles,
      status: 'paid',
      createdAt: Timestamp.now(),
      paidAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<OrderModel>> listByUser(
      {required String userId, String? siteId, int limit = 20}) async {
    Query<Map<String, dynamic>> q = _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      q = q.where('siteId', isEqualTo: siteId);
    }
    final snap = await q.get();
    return snap.docs.map(OrderModel.fromDoc).toList();
  }
}

class EntitlementRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('entitlements');

  Future<void> grant({
    required String userId,
    required String siteId,
    required String productId,
    List<String> roles = const <String>[],
    Timestamp? expiresAt,
  }) async {
    final doc = _col.doc();
    final model = EntitlementModel(
      id: doc.id,
      userId: userId,
      siteId: siteId,
      productId: productId,
      roles: roles,
      expiresAt: expiresAt,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());

    // Attach entitlements to the user profile for quick lookup.
    await FirebaseFirestore.instance.collection('users').doc(userId).set(
      <String, dynamic>{
        'roles': FieldValue.arrayUnion(roles),
        'entitlements': FieldValue.arrayUnion(roles),
        'siteIds': FieldValue.arrayUnion(<String>[siteId]),
        'primarySiteId': siteId,
      },
      SetOptions(merge: true),
    );
  }

  Future<List<EntitlementModel>> listByUser(
      {required String userId, String? siteId, int limit = 50}) async {
    Query<Map<String, dynamic>> query = _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    return snap.docs.map(EntitlementModel.fromDoc).toList();
  }
}

class FulfillmentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('fulfillments');

  Future<void> upsert(FulfillmentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<String> createPending({
    required String orderId,
    required String listingId,
    required String userId,
    String? siteId,
    String? note,
  }) async {
    final doc = _col.doc();
    final model = FulfillmentModel(
      id: doc.id,
      orderId: orderId,
      listingId: listingId,
      userId: userId,
      status: 'pending',
      siteId: siteId,
      note: note,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<FulfillmentModel>> listByUser(String userId,
      {int limit = 20}) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(FulfillmentModel.fromDoc).toList();
  }

  Future<List<FulfillmentModel>> listByOrder(String orderId,
      {int limit = 10}) async {
    final snap = await _col
        .where('orderId', isEqualTo: orderId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(FulfillmentModel.fromDoc).toList();
  }
}

class MediaConsentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('mediaConsents');

  Future<void> upsert(MediaConsentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<MediaConsentModel>> listByLearner(String learnerId) async {
    final snap = await _col.where('learnerId', isEqualTo: learnerId).get();
    return snap.docs.map(MediaConsentModel.fromDoc).toList();
  }

  Future<List<MediaConsentModel>> listBySite(String siteId,
      {int limit = 100}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MediaConsentModel.fromDoc).toList();
  }
}

class RoomRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('rooms');

  Future<void> upsert(RoomModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<RoomModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(RoomModel.fromDoc).toList();
  }
}

class MissionSnapshotRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('missionSnapshots');

  Future<void> upsert(MissionSnapshotModel model) async {
    await _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'mission.snapshot.created',
        metadata: <String, dynamic>{
          'snapshotId': model.id,
          'missionId': model.missionId,
          'pillarCount': model.pillarCodes.length,
        },
      );
    } catch (_) {}
  }

  Future<List<MissionSnapshotModel>> listByMission(String missionId,
      {int limit = 20}) async {
    final snap = await _col
        .where('missionId', isEqualTo: missionId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MissionSnapshotModel.fromDoc).toList();
  }
}

class RubricRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('rubrics');

  Future<void> upsert(RubricModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<RubricModel>> listBySiteOrGlobal(String? siteId,
      {int limit = 20}) async {
    if (siteId == null || siteId.isEmpty) {
      final snap = await _col
          .where('siteId', isNull: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(RubricModel.fromDoc).toList();
    }

    final siteSnap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final globalSnap = await _col
        .where('siteId', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return <RubricModel>[
      ...siteSnap.docs.map(RubricModel.fromDoc),
      ...globalSnap.docs.map(RubricModel.fromDoc)
    ];
  }
}

class RubricApplicationRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('rubricApplications');

  Future<void> upsert(RubricApplicationModel model) async {
    await _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'rubric.applied',
        siteId: model.siteId,
        metadata: <String, dynamic>{
          'rubricId': model.rubricId,
          'missionAttemptId': model.missionAttemptId,
          'scoreCount': model.scores.length,
        },
      );
    } catch (_) {}
  }

  Future<List<RubricApplicationModel>> listByAttempt(String missionAttemptId,
      {int limit = 10}) async {
    final snap = await _col
        .where('missionAttemptId', isEqualTo: missionAttemptId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(RubricApplicationModel.fromDoc).toList();
  }
}

class IntegrationConnectionRepository {
  IntegrationConnectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('integrationConnections');

  Future<void> upsert(IntegrationConnectionModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<IntegrationConnectionModel>> listByOwner(String ownerUserId,
      {int limit = 10}) async {
    final snap = await _col
        .where('ownerUserId', isEqualTo: ownerUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(IntegrationConnectionModel.fromDoc).toList();
  }
}

class ExternalCourseLinkRepository {
  ExternalCourseLinkRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('externalCourseLinks');

  Future<void> upsert(ExternalCourseLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalCourseLinkModel>> listBySite(String siteId,
      {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalCourseLinkModel.fromDoc).toList();
  }
}

class ExternalUserLinkRepository {
  ExternalUserLinkRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('externalUserLinks');

  Future<void> upsert(ExternalUserLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalUserLinkModel>> listBySite(String siteId,
      {int limit = 50}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalUserLinkModel.fromDoc).toList();
  }
}

class ExternalCourseworkLinkRepository {
  ExternalCourseworkLinkRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('externalCourseworkLinks');

  Future<void> upsert(ExternalCourseworkLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalCourseworkLinkModel>> listBySite(String siteId,
      {int limit = 50}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalCourseworkLinkModel.fromDoc).toList();
  }
}

class SyncJobRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('syncJobs');

  Future<void> upsert(SyncJobModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<SyncJobModel>> listRecent({int limit = 20}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(SyncJobModel.fromDoc).toList();
  }

  Future<List<SyncJobModel>> listBySite(String siteId, {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SyncJobModel.fromDoc).toList();
  }

  Future<List<SyncJobModel>> listFailed({int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'failed')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SyncJobModel.fromDoc).toList();
  }
}

class LtiPlatformRegistrationRepository {
  LtiPlatformRegistrationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ltiPlatformRegistrations');

  Future<void> upsert(LtiPlatformRegistrationModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<LtiPlatformRegistrationModel>> listBySite(String siteId,
      {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LtiPlatformRegistrationModel.fromDoc).toList();
  }
}

class LtiResourceLinkRepository {
  LtiResourceLinkRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ltiResourceLinks');

  Future<void> upsert(LtiResourceLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<LtiResourceLinkModel>> listBySite(String siteId,
      {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LtiResourceLinkModel.fromDoc).toList();
  }
}

class LtiGradePassbackJobRepository {
  LtiGradePassbackJobRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ltiGradePassbackJobs');

  Future<void> upsert(LtiGradePassbackJobModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<LtiGradePassbackJobModel>> listBySite(String siteId,
      {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LtiGradePassbackJobModel.fromDoc).toList();
  }
}

class FederatedLearningExperimentRepository {
  FederatedLearningExperimentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningExperiments');

  Future<FederatedLearningExperimentModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return FederatedLearningExperimentModel.fromDoc(doc);
  }

  Future<List<FederatedLearningExperimentModel>> listAll({
    int limit = 100,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _col.limit(limit).get();
    final List<FederatedLearningExperimentModel> rows =
        snap.docs.map(FederatedLearningExperimentModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }

  Future<List<FederatedLearningExperimentModel>> listBySite(
    String siteId, {
    int limit = 40,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('allowedSiteIds', arrayContains: siteId)
        .limit(limit)
        .get();
    final List<FederatedLearningExperimentModel> rows = snap.docs
        .map(FederatedLearningExperimentModel.fromDoc)
        .where((model) => model.allowedSiteIds.contains(siteId))
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningUpdateSummaryRepository {
  FederatedLearningUpdateSummaryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningUpdateSummaries');

  Future<List<FederatedLearningUpdateSummaryModel>> listByIds(
    List<String> ids,
  ) async {
    final List<String> normalizedIds = ids
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <FederatedLearningUpdateSummaryModel>[];
    }

    final List<FederatedLearningUpdateSummaryModel> rows =
        <FederatedLearningUpdateSummaryModel>[];
    for (int start = 0; start < normalizedIds.length; start += 10) {
      final int end = (start + 10 > normalizedIds.length)
          ? normalizedIds.length
          : start + 10;
      final List<String> batch = normalizedIds.sublist(start, end);
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _col.where(FieldPath.documentId, whereIn: batch).get();
      rows.addAll(
        snap.docs.map(FederatedLearningUpdateSummaryModel.fromDoc),
      );
    }

    final Map<String, FederatedLearningUpdateSummaryModel> rowsById =
        <String, FederatedLearningUpdateSummaryModel>{
      for (final FederatedLearningUpdateSummaryModel row in rows) row.id: row,
    };
    return normalizedIds
        .where(rowsById.containsKey)
        .map((String id) => rowsById[id]!)
        .toList(growable: false);
  }

  Future<List<FederatedLearningUpdateSummaryModel>> listByExperiment(
    String experimentId, {
    String? siteId,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query =
        _col.where('experimentId', isEqualTo: experimentId).limit(limit);
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    final List<FederatedLearningUpdateSummaryModel> rows =
        snap.docs.map(FederatedLearningUpdateSummaryModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }

  Future<List<FederatedLearningUpdateSummaryModel>> listBySite(
    String siteId, {
    int limit = 50,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _col.where('siteId', isEqualTo: siteId).limit(limit).get();
    final List<FederatedLearningUpdateSummaryModel> rows =
        snap.docs.map(FederatedLearningUpdateSummaryModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningAggregationRunRepository {
  FederatedLearningAggregationRunRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningAggregationRuns');

  Future<List<FederatedLearningAggregationRunModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningAggregationRunModel> rows =
        snap.docs.map(FederatedLearningAggregationRunModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningMergeArtifactRepository {
  FederatedLearningMergeArtifactRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningMergeArtifacts');

  Future<List<FederatedLearningMergeArtifactModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningMergeArtifactModel> rows =
        snap.docs.map(FederatedLearningMergeArtifactModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningCandidateModelPackageRepository {
  FederatedLearningCandidateModelPackageRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningCandidateModelPackages');

  Future<List<FederatedLearningCandidateModelPackageModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningCandidateModelPackageModel> rows = snap.docs
        .map(FederatedLearningCandidateModelPackageModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningExperimentReviewRecordRepository {
  FederatedLearningExperimentReviewRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningExperimentReviewRecords');

  Future<List<FederatedLearningExperimentReviewRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningExperimentReviewRecordModel> rows = snap.docs
        .map(FederatedLearningExperimentReviewRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningPilotEvidenceRecordRepository {
  FederatedLearningPilotEvidenceRecordRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningPilotEvidenceRecords');

  Future<List<FederatedLearningPilotEvidenceRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningPilotEvidenceRecordModel> rows = snap.docs
        .map(FederatedLearningPilotEvidenceRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningPilotApprovalRecordRepository {
  FederatedLearningPilotApprovalRecordRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningPilotApprovalRecords');

  Future<List<FederatedLearningPilotApprovalRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningPilotApprovalRecordModel> rows = snap.docs
        .map(FederatedLearningPilotApprovalRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningPilotExecutionRecordRepository {
  FederatedLearningPilotExecutionRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningPilotExecutionRecords');

  Future<List<FederatedLearningPilotExecutionRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningPilotExecutionRecordModel> rows = snap.docs
        .map(FederatedLearningPilotExecutionRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningRuntimeDeliveryRecordRepository {
  FederatedLearningRuntimeDeliveryRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningRuntimeDeliveryRecords');

  Future<List<FederatedLearningRuntimeDeliveryRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningRuntimeDeliveryRecordModel> rows = snap.docs
        .map(FederatedLearningRuntimeDeliveryRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningRuntimeActivationRecordRepository {
  FederatedLearningRuntimeActivationRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningRuntimeActivationRecords');

  Future<List<FederatedLearningRuntimeActivationRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningRuntimeActivationRecordModel> rows = snap.docs
        .map(FederatedLearningRuntimeActivationRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningCandidatePromotionRecordRepository {
  FederatedLearningCandidatePromotionRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('federatedLearningCandidatePromotionRecords');

  Future<List<FederatedLearningCandidatePromotionRecordModel>> listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningCandidatePromotionRecordModel> rows = snap.docs
        .map(FederatedLearningCandidatePromotionRecordModel.fromDoc)
        .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class FederatedLearningCandidatePromotionRevocationRecordRepository {
  FederatedLearningCandidatePromotionRevocationRecordRepository(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection('federatedLearningCandidatePromotionRevocationRecords');

  Future<List<FederatedLearningCandidatePromotionRevocationRecordModel>>
      listByExperiment(
    String experimentId, {
    int limit = 20,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(limit)
        .get();
    final List<FederatedLearningCandidatePromotionRevocationRecordModel> rows =
        snap.docs
            .map(FederatedLearningCandidatePromotionRevocationRecordModel
                .fromDoc)
            .toList();
    rows.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }
}

class RosterImportRepository {
  RosterImportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('rosterImports');

  Future<List<RosterImportModel>> listBySite(
    String siteId, {
    int limit = 50,
    bool pendingOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _col.where('siteId', isEqualTo: siteId);
    if (pendingOnly) {
      query = query.where('status', isEqualTo: 'pending_provisioning');
    }
    final QuerySnapshot<Map<String, dynamic>> snap =
        await query.limit(limit).get();
    final List<RosterImportModel> rows =
        snap.docs.map(RosterImportModel.fromDoc).toList();
    rows.sort((a, b) {
      final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return rows;
  }

  Future<void> markReviewed({
    required String id,
    required String reviewerId,
    String? reviewNotes,
  }) {
    return _col.doc(id).set(<String, dynamic>{
      'status': 'reviewed',
      'reviewedBy': reviewerId,
      'reviewedAt': Timestamp.now(),
      'reviewNotes': reviewNotes,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

class SyncCursorRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('syncCursors');

  Future<void> upsert(SyncCursorModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<SyncCursorModel>> listByOwner(String ownerUserId,
      {int limit = 20}) async {
    final snap = await _col
        .where('ownerUserId', isEqualTo: ownerUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SyncCursorModel.fromDoc).toList();
  }
}

class GitHubConnectionRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('githubConnections');

  Future<void> upsert(GitHubConnectionModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<GitHubConnectionModel>> listByOwner(String ownerUserId,
      {int limit = 10}) async {
    final snap = await _col
        .where('ownerUserId', isEqualTo: ownerUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(GitHubConnectionModel.fromDoc).toList();
  }
}

class ExternalRepoLinkRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('externalRepoLinks');

  Future<void> upsert(ExternalRepoLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalRepoLinkModel>> listBySite(String siteId,
      {int limit = 20}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalRepoLinkModel.fromDoc).toList();
  }
}

class ExternalPullRequestLinkRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('externalPullRequestLinks');

  Future<void> upsert(ExternalPullRequestLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalPullRequestLinkModel>> listByRepo(String repoFullName,
      {int limit = 20}) async {
    final snap = await _col
        .where('repoFullName', isEqualTo: repoFullName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalPullRequestLinkModel.fromDoc).toList();
  }
}

class GitHubWebhookDeliveryRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('githubWebhookDeliveries');

  Future<void> upsert(GitHubWebhookDeliveryModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<GitHubWebhookDeliveryModel>> listRecent({int limit = 50}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(GitHubWebhookDeliveryModel.fromDoc).toList();
  }
}

class PartnerOrgRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('partnerOrgs');

  Future<String> create(
      {required String name,
      required String ownerId,
      String? contactEmail}) async {
    final doc = _col.doc();
    final model = PartnerOrgModel(
      id: doc.id,
      name: name,
      ownerId: ownerId,
      contactEmail: contactEmail,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<List<PartnerOrgModel>> listMine(String ownerId) async {
    final snap = await _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return snap.docs.map(PartnerOrgModel.fromDoc).toList();
  }

  Future<List<PartnerOrgModel>> listAll({int limit = 20}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(PartnerOrgModel.fromDoc).toList();
  }
}

class PartnerContractRepository {
  PartnerContractRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('partnerContracts');

  Future<String> createDraft({
    required String partnerOrgId,
    required String title,
    required String amount,
    required String currency,
    String? createdBy,
    Timestamp? dueDate,
  }) async {
    final doc = _col.doc();
    final model = PartnerContractModel(
      id: doc.id,
      partnerOrgId: partnerOrgId,
      title: title,
      amount: amount,
      currency: currency,
      status: 'draft',
      createdBy: createdBy,
      dueDate: dueDate,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    try {
      await TelemetryService.instance.logEvent(
        event: 'contract.created',
        metadata: <String, dynamic>{
          'contractId': doc.id,
          'partnerOrgId': partnerOrgId
        },
      );
    } catch (_) {}
    return doc.id;
  }

  Future<void> approve({required String id, required String approvedBy}) async {
    final DocumentReference<Map<String, dynamic>> ref = _col.doc(id);
    final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();
    final Map<String, dynamic>? existingData = existing.data();
    final String? siteId = existingData?['siteId'] as String?;
    final String? partnerOrgId = existingData?['partnerOrgId'] as String?;

    await ref.set(<String, dynamic>{
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'contract.approved',
        siteId: siteId,
        metadata: <String, dynamic>{
          'contractId': id,
          if (partnerOrgId != null && partnerOrgId.isNotEmpty)
            'partnerOrgId': partnerOrgId,
        },
      );
    } catch (_) {}
  }

  Future<List<PartnerContractModel>> listByOrg(String partnerOrgId,
      {int limit = 20}) async {
    final snap = await _col
        .where('partnerOrgId', isEqualTo: partnerOrgId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PartnerContractModel.fromDoc).toList();
  }

  Future<List<PartnerContractModel>> listPendingApproval(
      {int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'draft')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PartnerContractModel.fromDoc).toList();
  }
}

class PartnerDeliverableRepository {
  PartnerDeliverableRepository({
    FirebaseFirestore? firestore,
    AuditLogRepository? auditLogRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditLogRepository =
            auditLogRepository ?? AuditLogRepository(firestore: firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('partnerDeliverables');
  final AuditLogRepository _auditLogRepository;

  Future<String> submit({
    required String contractId,
    required String title,
    String? description,
    String? evidenceUrl,
    String? submittedBy,
    String actorRole = 'partner',
  }) async {
    final doc = _col.doc();
    final model = PartnerDeliverableModel(
      id: doc.id,
      contractId: contractId,
      title: title,
      description: description,
      evidenceUrl: evidenceUrl,
      status: 'submitted',
      submittedBy: submittedBy,
      submittedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    try {
      await _auditLogRepository.log(
        AuditLogModel(
          id: 'audit-deliverable-submit-${doc.id}-${Timestamp.now().millisecondsSinceEpoch}',
          actorId: submittedBy ?? 'unknown',
          actorRole: actorRole,
          action: 'deliverable.submit',
          entityType: 'partnerDeliverable',
          entityId: doc.id,
          details: {
            'contractId': contractId,
            'title': title,
            if (evidenceUrl != null) 'evidenceUrl': evidenceUrl,
          },
        ),
      );
    } catch (_) {
      // Audit should not block deliverable submission.
    }
    try {
      await TelemetryService.instance.logEvent(
        event: 'deliverable.submitted',
        metadata: <String, dynamic>{
          'deliverableId': doc.id,
          'contractId': contractId
        },
      );
    } catch (_) {}
    return doc.id;
  }

  Future<void> accept(
      {required String id,
      required String acceptedBy,
      String actorRole = 'hq'}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'accepted',
      'acceptedBy': acceptedBy,
      'acceptedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await _auditLogRepository.log(
        AuditLogModel(
          id: 'audit-deliverable-accept-$id-${Timestamp.now().millisecondsSinceEpoch}',
          actorId: acceptedBy,
          actorRole: actorRole,
          action: 'deliverable.accept',
          entityType: 'partnerDeliverable',
          entityId: id,
          details: const {
            'status': 'accepted',
          },
        ),
      );
    } catch (_) {
      // Audit should not block deliverable acceptance.
    }
    try {
      await TelemetryService.instance.logEvent(
        event: 'deliverable.accepted',
        metadata: <String, dynamic>{'deliverableId': id},
      );
    } catch (_) {}
  }

  Future<List<PartnerDeliverableModel>> listByContract(String contractId,
      {int limit = 20}) async {
    final snap = await _col
        .where('contractId', isEqualTo: contractId)
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PartnerDeliverableModel.fromDoc).toList();
  }

  Future<List<PartnerDeliverableModel>> listPendingAcceptance(
      {int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'submitted')
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PartnerDeliverableModel.fromDoc).toList();
  }
}

class PayoutRepository {
  PayoutRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('payouts');

  Future<String> createPending({
    required String contractId,
    required String amount,
    required String currency,
    String? createdBy,
  }) async {
    final doc = _col.doc();
    final model = PayoutModel(
      id: doc.id,
      contractId: contractId,
      amount: amount,
      currency: currency,
      status: 'pending',
      createdBy: createdBy,
      createdAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> approve({required String id, required String approvedBy}) async {
    final DocumentReference<Map<String, dynamic>> ref = _col.doc(id);
    final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();
    final Map<String, dynamic>? existingData = existing.data();
    final String? siteId = existingData?['siteId'] as String?;
    final String? contractId = existingData?['contractId'] as String?;

    await ref.set(<String, dynamic>{
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'payout.approved',
        siteId: siteId,
        metadata: <String, dynamic>{
          'payoutId': id,
          if (contractId != null && contractId.isNotEmpty)
            'contractId': contractId,
        },
      );
    } catch (_) {}
  }

  Future<List<PayoutModel>> listByContract(String contractId,
      {int limit = 20}) async {
    final snap = await _col
        .where('contractId', isEqualTo: contractId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PayoutModel.fromDoc).toList();
  }

  Future<List<PayoutModel>> listPendingApproval({int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PayoutModel.fromDoc).toList();
  }

  Future<List<PayoutModel>> listByContractIds(List<String> contractIds,
      {int limit = 50}) async {
    if (contractIds.isEmpty) return <PayoutModel>[];
    final List<PayoutModel> all = <PayoutModel>[];
    for (var i = 0; i < contractIds.length; i += 10) {
      final slice = contractIds.sublist(
          i, i + 10 > contractIds.length ? contractIds.length : i + 10);
      final snap = await _col
          .where('contractId', whereIn: slice)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      all.addAll(snap.docs.map(PayoutModel.fromDoc));
      if (all.length >= limit) break;
    }
    return all.take(limit).toList();
  }
}

class MarketplaceListingRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('marketplaceListings');

  Future<String> createDraft({
    required String partnerOrgId,
    required String title,
    required String price,
    required String currency,
    String? productId,
    List<String> entitlementRoles = const <String>[],
    String? description,
    String? createdBy,
  }) async {
    final doc = _col.doc();
    final model = MarketplaceListingModel(
      id: doc.id,
      partnerOrgId: partnerOrgId,
      title: title,
      price: price,
      currency: currency,
      productId: productId,
      entitlementRoles: entitlementRoles,
      description: description,
      status: 'draft',
      createdBy: createdBy,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }

  Future<void> submit({required String id, required String submittedBy}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'submitted',
      'submittedBy': submittedBy,
      'submittedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> approve({required String id, required String approverId}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'approved',
      'approvedBy': approverId,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> publish({required String id}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'published',
      'publishedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<MarketplaceListingModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return MarketplaceListingModel.fromDoc(doc);
  }

  Future<List<MarketplaceListingModel>> listPublished({int limit = 50}) async {
    final snap = await _col
        .where('status', isEqualTo: 'published')
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MarketplaceListingModel.fromDoc).toList();
  }

  Future<List<MarketplaceListingModel>> listByPartner(String partnerOrgId,
      {int limit = 20}) async {
    final snap = await _col
        .where('partnerOrgId', isEqualTo: partnerOrgId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MarketplaceListingModel.fromDoc).toList();
  }

  Future<List<MarketplaceListingModel>> listPendingApproval(
      {int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'submitted')
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MarketplaceListingModel.fromDoc).toList();
  }
}

class SiteCheckInOutRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('siteCheckInOut');

  Future<List<SiteCheckInOutModel>> listBySiteAndDate(
      {required String siteId, required String date, int limit = 200}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('date', isEqualTo: date)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SiteCheckInOutModel.fromDoc).toList();
  }

  Future<void> markCheckIn(
      {required String siteId,
      required String learnerId,
      required String userId,
      required String date}) async {
    final id = '${siteId}_${learnerId}_$date';
    await _col.doc(id).set(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'date': date,
      'checkInAt': Timestamp.now(),
      'checkInBy': userId,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'site.checkin',
        siteId: siteId,
        metadata: <String, dynamic>{
          'learnerId': learnerId,
          'date': date,
          'recordedBy': userId,
          'source': 'site_checkin_out_repository',
        },
      );
    } catch (_) {}
  }

  Future<void> markCheckOut(
      {required String siteId,
      required String learnerId,
      required String userId,
      required String date,
      String? pickedUpByName,
      bool? latePickupFlag}) async {
    final id = '${siteId}_${learnerId}_$date';
    await _col.doc(id).set(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'date': date,
      'checkOutAt': Timestamp.now(),
      'checkOutBy': userId,
      'pickedUpByName': pickedUpByName,
      'latePickupFlag': latePickupFlag,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'site.checkout',
        siteId: siteId,
        metadata: <String, dynamic>{
          'learnerId': learnerId,
          'date': date,
          'recordedBy': userId,
          'latePickup': latePickupFlag == true,
          'source': 'site_checkin_out_repository',
        },
      );
      if (latePickupFlag == true) {
        await TelemetryService.instance.logEvent(
          event: 'site.late_pickup.flagged',
          siteId: siteId,
          metadata: <String, dynamic>{
            'learnerId': learnerId,
            'date': date,
            'source': 'site_checkin_out_repository',
          },
        );
      }
    } catch (_) {}
  }
}

class IncidentReportRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('incidentReports');

  Future<List<IncidentReportModel>> listRecentBySite(String siteId,
      {int limit = 50}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(IncidentReportModel.fromDoc).toList();
  }

  Future<String> create({
    required String siteId,
    required String reportedBy,
    required String severity,
    required String category,
    required String summary,
    String? learnerId,
    String? sessionOccurrenceId,
    String status = 'submitted',
    String? details,
  }) async {
    final doc = _col.doc();
    final model = IncidentReportModel(
      id: doc.id,
      siteId: siteId,
      reportedBy: reportedBy,
      severity: severity,
      category: category,
      status: status,
      summary: summary,
      learnerId: learnerId,
      sessionOccurrenceId: sessionOccurrenceId,
      details: details,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    return doc.id;
  }
}

class ExternalIdentityLinkRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('externalIdentityLinks');

  Future<void> upsert(ExternalIdentityLinkModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<ExternalIdentityLinkModel>> listUnmatchedBySite(String siteId,
      {int limit = 50}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('status', isEqualTo: 'unmatched')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExternalIdentityLinkModel.fromDoc).toList();
  }

  Future<void> approveLink(
      {required String id,
      required String approverId,
      required String scholesaUserId}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'linked',
      'scholesaUserId': scholesaUserId,
      'approvedBy': approverId,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> markIgnored({required String id}) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': 'ignored',
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

class PickupAuthorizationRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('pickupAuthorizations');

  Future<PickupAuthorizationModel?> getByLearner(
      String learnerId, String siteId) async {
    final snap = await _col
        .where('learnerId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PickupAuthorizationModel.fromDoc(snap.docs.first);
  }

  Future<void> upsert(PickupAuthorizationModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<List<PickupAuthorizationModel>> listBySite(String siteId,
      {int limit = 100}) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PickupAuthorizationModel.fromDoc).toList();
  }
}

class AiDraftRepository {
  AiDraftRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('aiDrafts');

  Future<String> createRequest({
    required String requesterId,
    required String siteId,
    required String title,
    required String prompt,
  }) async {
    final doc = _col.doc();
    final model = AiDraftModel(
      id: doc.id,
      requesterId: requesterId,
      siteId: siteId,
      title: title,
      prompt: prompt,
      status: 'requested',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await doc.set(model.toMap());
    try {
      await TelemetryService.instance.logEvent(
        event: 'aiDraft.requested',
        siteId: siteId,
        metadata: <String, dynamic>{'draftId': doc.id},
      );
    } catch (_) {}
    return doc.id;
  }

  Future<void> review({
    required String id,
    required String reviewerId,
    required String status,
    String? notes,
  }) async {
    await _col.doc(id).set(<String, dynamic>{
      'status': status,
      'reviewerId': reviewerId,
      'reviewNotes': notes,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    try {
      await TelemetryService.instance.logEvent(
        event: 'aiDraft.reviewed',
        metadata: <String, dynamic>{'draftId': id, 'status': status},
      );
    } catch (_) {}
  }

  Future<List<AiDraftModel>> listMine(String requesterId,
      {int limit = 20}) async {
    final snap = await _col
        .where('requesterId', isEqualTo: requesterId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AiDraftModel.fromDoc).toList();
  }

  Future<List<AiDraftModel>> listPending({int limit = 20}) async {
    final snap = await _col
        .where('status', isEqualTo: 'requested')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AiDraftModel.fromDoc).toList();
  }
}

// ──────────────────────────────────────────────────────
// Research & Assessment Repositories (Vibe Master §B)
// ──────────────────────────────────────────────────────

class ResearchConsentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('researchConsents');

  Future<void> upsert(ResearchConsentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<ResearchConsentModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ResearchConsentModel.fromDoc(doc);
  }

  Future<ResearchConsentModel?> getForLearner({
    required String siteId,
    required String learnerId,
  }) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ResearchConsentModel.fromDoc(snap.docs.first);
  }

  Future<List<ResearchConsentModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(ResearchConsentModel.fromDoc).toList();
  }

  Future<void> revoke(String id) => _col.doc(id).set(<String, dynamic>{
        'consentGiven': false,
        'revokedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
}

class StudentAssentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('studentAssents');

  Future<void> upsert(StudentAssentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<StudentAssentModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return StudentAssentModel.fromDoc(doc);
  }

  Future<StudentAssentModel?> getForLearner({
    required String siteId,
    required String learnerId,
  }) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return StudentAssentModel.fromDoc(snap.docs.first);
  }

  Future<void> revoke(String id) => _col.doc(id).set(<String, dynamic>{
        'assentGiven': false,
        'revokedAt': Timestamp.now(),
      }, SetOptions(merge: true));

  Future<List<StudentAssentModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(StudentAssentModel.fromDoc).toList();
  }
}

class AssessmentInstrumentRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('assessmentInstruments');

  Future<void> upsert(AssessmentInstrumentModel model) =>
      _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));

  Future<AssessmentInstrumentModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AssessmentInstrumentModel.fromDoc(doc);
  }

  Future<List<AssessmentInstrumentModel>> listBySite(String siteId) async {
    final snap = await _col.where('siteId', isEqualTo: siteId).get();
    return snap.docs.map(AssessmentInstrumentModel.fromDoc).toList();
  }

  Future<List<AssessmentInstrumentModel>> listByType({
    required String siteId,
    required String type,
  }) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('type', isEqualTo: type)
        .get();
    return snap.docs.map(AssessmentInstrumentModel.fromDoc).toList();
  }

  Future<String> create(AssessmentInstrumentModel model) async {
    final doc = _col.doc();
    await doc.set(model.toMap());
    return doc.id;
  }
}

class ItemResponseRepository {
  ItemResponseRepository({
    FirebaseFirestore? firestore,
    MetacognitiveCalibrationRepository? calibrationRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _calibrationRepository = calibrationRepository ??
            MetacognitiveCalibrationRepository(
              firestore: firestore ?? FirebaseFirestore.instance,
            );

  final FirebaseFirestore _firestore;
  final MetacognitiveCalibrationRepository _calibrationRepository;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('itemResponses');

  Future<void> upsert(ItemResponseModel model) async {
    await _col.doc(model.id).set(model.toMap(), SetOptions(merge: true));
    await _persistCalibrationRecord(responseId: model.id, model: model);
  }

  Future<List<ItemResponseModel>> listByLearner({
    required String siteId,
    required String learnerId,
    String? instrumentId,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> q = _col
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId);
    if (instrumentId != null) {
      q = q.where('instrumentId', isEqualTo: instrumentId);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map(ItemResponseModel.fromDoc).toList();
  }

  Future<List<ItemResponseModel>> listByInstrument({
    required String siteId,
    required String instrumentId,
    int limit = 500,
  }) async {
    final snap = await _col
        .where('siteId', isEqualTo: siteId)
        .where('instrumentId', isEqualTo: instrumentId)
        .limit(limit)
        .get();
    return snap.docs.map(ItemResponseModel.fromDoc).toList();
  }

  Future<String> submit(ItemResponseModel model) async {
    final doc = _col.doc();
    await doc.set(model.toMap());
    await _persistCalibrationRecord(responseId: doc.id, model: model);
    return doc.id;
  }

  Future<void> _persistCalibrationRecord({
    required String responseId,
    required ItemResponseModel model,
  }) async {
    if (responseId.isEmpty ||
        model.confidenceLevel == null ||
        model.isCorrect == null) {
      return;
    }

    final double confidenceScore = model.confidenceLevel!.clamp(1, 5) / 5.0;
    final double accuracyScore = model.isCorrect! ? 1.0 : 0.0;
    final MetacognitiveCalibrationRecordModel record =
        MetacognitiveCalibrationRecordModel(
      id: responseId,
      siteId: model.siteId,
      learnerId: model.learnerId,
      sourceType: 'item_response',
      sourceId: responseId,
      instrumentId: model.instrumentId,
      itemId: model.itemId,
      confidenceLevel: model.confidenceLevel!,
      confidenceScore: confidenceScore,
      accuracyScore: accuracyScore,
      calibrationDelta: confidenceScore - accuracyScore,
      createdAt: model.createdAt ?? Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    await _calibrationRepository.upsert(record);
    try {
      await TelemetryService.instance.logEvent(
        event: 'calibration.recorded',
        role: 'learner',
        siteId: model.siteId,
        metadata: <String, dynamic>{
          'sourceType': 'item_response',
          'instrumentId': model.instrumentId,
          'itemId': model.itemId,
          'confidenceLevel': model.confidenceLevel,
          'accuracyScore': accuracyScore,
          'calibrationDelta': confidenceScore - accuracyScore,
        },
      );
    } catch (_) {}
  }
}
