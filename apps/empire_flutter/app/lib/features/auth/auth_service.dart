import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_routes.dart';

class EntitlementsResult {
  const EntitlementsResult({required this.roles, required this.siteIds, this.primarySiteId});

  final Set<String> roles;
  final List<String> siteIds;
  final String? primarySiteId;
}

abstract class AuthServiceBase {
  Future<User?> signIn({required String email, required String password});

  Future<User?> register({required String email, required String password});

  Future<void> signOut();

  Future<EntitlementsResult> loadEntitlements();
}

class AuthService implements AuthServiceBase {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  @override
  Future<User?> register({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<EntitlementsResult> loadEntitlements() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const EntitlementsResult(roles: <String>{}, siteIds: <String>[]);
    }

    // 1) Custom claims take precedence when present.
    final idToken = await user.getIdTokenResult(true);
    final claimRoles = <String>{}
      ..addAll(_parseRoles(idToken.claims?['roles']))
      ..addAll(_parseRoles(idToken.claims?['role']))
      ..addAll(_parseRoles(idToken.claims?['entitlements']));
    if (claimRoles.isNotEmpty) {
      return EntitlementsResult(roles: claimRoles, siteIds: <String>[], primarySiteId: null);
    }

    // 2) Firestore profile fallback: users/{uid}.roles (array) or .role (string).
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      final profileRoles = <String>{}
        ..addAll(_parseRoles(data['roles']))
        ..addAll(_parseRoles(data['role']))
        ..addAll(_parseRoles(data['entitlements']));
      final siteIds = _parseSiteIds(data['siteIds']);
      final primarySiteId = _parsePrimarySite(siteIds, data['primarySiteId']);
      if (profileRoles.isNotEmpty || siteIds.isNotEmpty) {
        return EntitlementsResult(
          roles: profileRoles.isNotEmpty ? profileRoles : const {'learner'},
          siteIds: siteIds,
          primarySiteId: primarySiteId,
        );
      }
    }

    // 3) Fallback: minimally allow learner role until entitlements are provisioned.
    return const EntitlementsResult(roles: {'learner'}, siteIds: <String>[], primarySiteId: null);
  }

  Set<String> _parseRoles(dynamic source) {
    final roles = <String>{};
    if (source is List) {
      roles.addAll(
        source
            .whereType<String>()
            .map((String role) => role.trim())
            .where((String role) => role.isNotEmpty),
      );
    }
    if (source is String) {
      roles.addAll(
        source
            .split(',')
            .map((String role) => role.trim())
            .where((String role) => role.isNotEmpty),
      );
    }
    return roles.map(normalizeRole).toSet();
  }

  List<String> _parseSiteIds(dynamic source) {
    if (source is List) {
      return source.whereType<String>().where((String id) => id.isNotEmpty).toList();
    }
    if (source is String && source.isNotEmpty) {
      return <String>[source];
    }
    return <String>[];
  }

  String? _parsePrimarySite(List<String> siteIds, dynamic fromData) {
    if (fromData is String && fromData.isNotEmpty) return fromData;
    return siteIds.isNotEmpty ? siteIds.first : null;
  }
}
