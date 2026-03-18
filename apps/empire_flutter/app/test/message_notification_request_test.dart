import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/notification_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  test('educator direct message requests notification send with site context',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService service = MessageService(
      firestoreService: firestoreService,
      userId: 'educator-1',
    );
    final List<Map<String, dynamic>> notificationCalls =
        <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> telemetryPayloads =
        <Map<String, dynamic>>[];

    await firestore.collection('users').doc('educator-1').set(<String, dynamic>{
      'displayName': 'Educator One',
      'role': 'educator',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
      'displayName': 'Parent One',
      'role': 'parent',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });

    await NotificationService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        notificationCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': Map<String, dynamic>.from(payload),
        });
      },
      () async {
        await TelemetryService.runWithDispatcher(
          (Map<String, dynamic> payload) async {
            telemetryPayloads.add(Map<String, dynamic>.from(payload));
          },
          () async {
            final bool sent = await service.sendMessage(
              recipientId: 'parent-1',
              body: 'Progress update is ready for review.',
            );
            expect(sent, isTrue);
          },
        );
      },
    );

    final threads = await firestore.collection('messageThreads').get();
    expect(threads.docs, hasLength(1));
    expect(threads.docs.first.data()['siteId'], 'site-1');

    final messages = await firestore.collection('messages').get();
    expect(messages.docs, hasLength(1));
    final Map<String, dynamic> messageData = messages.docs.first.data();
    expect(messageData['recipientId'], 'parent-1');
    expect(messageData['siteId'], 'site-1');
    expect(messageData['threadId'], threads.docs.first.id);

    expect(notificationCalls, hasLength(1));
    expect(notificationCalls.first['callableName'], 'requestNotificationSend');
    expect(notificationCalls.first['payload']['channel'], 'push');
    expect(notificationCalls.first['payload']['siteId'], 'site-1');
    expect(notificationCalls.first['payload']['threadId'], threads.docs.first.id);
    expect(notificationCalls.first['payload']['messageId'], messages.docs.first.id);

    expect(
      telemetryPayloads.where(
        (Map<String, dynamic> payload) => payload['event'] == 'message.sent',
      ),
      hasLength(1),
    );
  });

  test('parent direct message does not request privileged notification send',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService service = MessageService(
      firestoreService: firestoreService,
      userId: 'parent-1',
    );
    final List<Map<String, dynamic>> notificationCalls =
        <Map<String, dynamic>>[];

    await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
      'displayName': 'Parent One',
      'role': 'parent',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('users').doc('educator-1').set(<String, dynamic>{
      'displayName': 'Educator One',
      'role': 'educator',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });

    await NotificationService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        notificationCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': Map<String, dynamic>.from(payload),
        });
      },
      () async {
        final bool sent = await service.sendMessage(
          recipientId: 'educator-1',
          body: 'Thanks for the update.',
        );
        expect(sent, isTrue);
      },
    );

    expect(notificationCalls, isEmpty);
  });

  test('direct message stores explicit unavailable sender labels when missing',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MessageService service = MessageService(
      firestoreService: firestoreService,
      userId: 'educator-1',
    );

    await firestore.collection('users').doc('educator-1').set(<String, dynamic>{
      'role': 'educator',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });
    await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
      'displayName': 'Parent One',
      'role': 'parent',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });

    await NotificationService.runWithCallableInvoker(
      (_, __) async {},
      () async {
        await TelemetryService.runWithDispatcher(
          (_) async {},
          () async {
            final bool sent = await service.sendMessage(
              recipientId: 'parent-1',
              body: 'Identity fallback check.',
            );
            expect(sent, isTrue);
          },
        );
      },
    );

    final QuerySnapshot<Map<String, dynamic>> messages =
        await firestore.collection('messages').get();
    expect(messages.docs, hasLength(1));
    expect(messages.docs.first.data()['senderName'], 'Sender unavailable');

    final QuerySnapshot<Map<String, dynamic>> threads =
        await firestore.collection('messageThreads').get();
    expect(threads.docs, hasLength(1));
    expect(
      (threads.docs.first.data()['participantNames'] as List<dynamic>).first,
      'Sender unavailable',
    );
  });
}