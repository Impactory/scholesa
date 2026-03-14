import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/telemetry_service.dart';
import 'message_models.dart';

/// Service for messages and notifications
class MessageService extends ChangeNotifier {
  MessageService({
    required FirestoreService firestoreService,
    required this.userId,
    NotificationService? notificationService,
  })  : _firestoreService = firestoreService,
        _notificationService = notificationService ?? NotificationService.instance;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;
  final String userId;
  FirebaseFirestore get _firestore => _firestoreService.firestore;

  List<Message> _messages = <Message>[];
  List<Conversation> _conversations = <Conversation>[];
  bool _isLoading = false;
  String? _error;
  MessageType? _typeFilter;

  // Getters
  List<Message> get messages => _filteredMessages;
    List<Message> get notificationMessages => _filteredMessages
      .where((Message m) => m.type != MessageType.direct)
      .toList();
    List<Message> get directMessages =>
      _filteredMessages.where((Message m) => m.type == MessageType.direct).toList();
  List<Message> get unreadMessages =>
      _messages.where((Message m) => !m.isRead).toList();
    List<Message> get unreadNotificationMessages => _messages
      .where((Message m) => m.type != MessageType.direct && !m.isRead)
      .toList();
    List<Message> get unreadDirectMessages => _messages
      .where((Message m) => m.type == MessageType.direct && !m.isRead)
      .toList();
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => unreadMessages.length;
    int get unreadNotificationCount => unreadNotificationMessages.length;
    int get unreadDirectCount => unreadDirectMessages.length;
  MessageType? get typeFilter => _typeFilter;

  List<Message> get _filteredMessages {
    if (_typeFilter == null) return _messages;
    return _messages.where((Message m) => m.type == _typeFilter).toList();
  }

  // Filters
  void setTypeFilter(MessageType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  /// Load all messages from Firebase
  Future<void> loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load messages for this user
      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot =
          await _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      _messages = messagesSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Message(
          id: doc.id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          type: _parseMessageType(data['type'] as String?),
          priority: _parseMessagePriority(data['priority'] as String?),
          senderId: data['senderId'] as String?,
          senderName: data['senderName'] as String?,
          createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
          isRead: data['isRead'] as bool? ?? false,
          readAt: _parseTimestamp(data['readAt']),
          actionUrl: data['actionUrl'] as String?,
          metadata: <String, dynamic>{
            if (data['threadId'] != null) 'threadId': data['threadId'],
          },
        );
      }).toList();

      // Load canonical conversation threads for this user
      final QuerySnapshot<Map<String, dynamic>> threadsSnapshot =
          await _firestore
              .collection('messageThreads')
              .where('participantIds', arrayContains: userId)
              .orderBy('updatedAt', descending: true)
              .limit(20)
              .get();

      _conversations = threadsSnapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final List<String> participantIds =
              List<String>.from(data['participantIds'] as List? ?? <String>[]);
          final List<String> participantNames = List<String>.from(
              data['participantNames'] as List? ?? <String>[]);
          final String lastPreview = data['lastMessagePreview'] as String? ?? '';
          final Message? lastMessage = lastPreview.isEmpty
              ? null
              : Message(
                  id: doc.id,
                  title: data['title'] as String? ?? '',
                  body: lastPreview,
                  type: MessageType.direct,
                  senderId: data['lastMessageSenderId'] as String?,
                  senderName: _participantNameForLastSender(
                    participantIds: participantIds,
                    participantNames: participantNames,
                    lastSenderId: data['lastMessageSenderId'] as String?,
                  ),
                  createdAt:
                      _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
                  isRead: false,
                );

          final int unreadCount = _messages
              .where((Message message) =>
                  message.metadata?['threadId'] == doc.id &&
                  !message.isRead &&
                  message.type == MessageType.direct)
              .length;

          return Conversation(
            id: doc.id,
            participantIds: participantIds,
            participantNames: participantNames,
            lastMessage: lastMessage,
            updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
            unreadCount: unreadCount,
          );
        })
        .toList();

      debugPrint(
          'Loaded ${_messages.length} messages and ${_conversations.length} conversations');
    } catch (e) {
      debugPrint('Error loading messages: $e');
      _error = 'Failed to load messages: $e';
      _messages = <Message>[];
      _conversations = <Conversation>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a message as read in Firebase
  Future<bool> markAsRead(String messageId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(messageId)
          .update(<String, dynamic>{
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      final int index = _messages.indexWhere((Message m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error marking message as read: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Mark all messages as read in Firebase
  Future<void> markAllAsRead() async {
    try {
      final WriteBatch batch = _firestore.batch();
      final DateTime now = DateTime.now();

      for (final Message message in _messages.where((Message m) => !m.isRead)) {
        batch.update(
            _firestore.collection('messages').doc(message.id),
            <String, dynamic>{
              'isRead': true,
              'readAt': FieldValue.serverTimestamp(),
            });
      }

      await batch.commit();

      _messages = _messages
          .map((Message m) => m.copyWith(
                isRead: true,
                readAt: m.readAt ?? now,
              ))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a message from Firebase
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
      _messages = _messages.where((Message m) => m.id != messageId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Send a direct message
  Future<bool> sendMessage({
    required String recipientId,
    required String body,
    String? conversationId,
  }) async {
    try {
      // Get sender info
      final DocumentSnapshot<Map<String, dynamic>> senderDoc =
          await _firestore.collection('users').doc(userId).get();
      final Map<String, dynamic> senderData =
          senderDoc.data() ?? <String, dynamic>{};
      final String senderName =
          senderData['displayName'] as String? ?? 'Unknown';
      final String senderRole =
          (senderData['role'] as String? ?? '').trim().toLowerCase();
      final List<String> senderSiteIds =
          List<String>.from(senderData['siteIds'] as List? ?? <String>[]);
      final String fallbackSiteId =
          ((senderData['activeSiteId'] as String?) ??
                  (senderSiteIds.isNotEmpty ? senderSiteIds.first : ''))
              .trim();

      final String recipientName =
          await _loadDisplayName(recipientId, fallback: recipientId);
      DocumentReference<Map<String, dynamic>> threadRef;
      String siteId = fallbackSiteId;
      if (conversationId != null && conversationId.trim().isNotEmpty) {
        threadRef = _firestore.collection('messageThreads').doc(conversationId);
        final DocumentSnapshot<Map<String, dynamic>> threadDoc =
          await threadRef.get();
        final Map<String, dynamic> threadData =
          threadDoc.data() ?? <String, dynamic>{};
        siteId = (threadData['siteId'] as String? ?? siteId).trim();
      } else {
        threadRef = _firestore.collection('messageThreads').doc();
        await threadRef.set(<String, dynamic>{
          'participantIds': <String>[userId, recipientId],
          'participantNames': <String>[senderName, recipientName],
          if (siteId.isNotEmpty) 'siteId': siteId,
          'title': 'Direct conversation',
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await threadRef.set(<String, dynamic>{
        'participantIds': <String>[userId, recipientId],
        'participantNames': <String>[senderName, recipientName],
        if (siteId.isNotEmpty) 'siteId': siteId,
        'status': 'open',
        'lastMessagePreview': body,
        'lastMessageSenderId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final DocumentReference<Map<String, dynamic>> messageRef =
          await _firestore.collection('messages').add(<String, dynamic>{
        'threadId': threadRef.id,
        'title': 'Direct message',
        'body': body,
        'type': 'direct',
        'priority': 'normal',
        'senderId': userId,
        'senderName': senderName,
        'recipientId': recipientId,
        if (siteId.isNotEmpty) 'siteId': siteId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'sent',
        'metadata': <String, dynamic>{'threadId': threadRef.id},
      });

      await TelemetryService.instance.logEvent(
        event: 'message.sent',
        metadata: <String, dynamic>{
          'recipient_id': recipientId,
          'conversation_id': threadRef.id,
          'message_length': body.length,
        },
      );

      if (siteId.isNotEmpty &&
          <String>{'educator', 'site', 'hq'}.contains(senderRole)) {
        await _notificationService.requestSend(
          channel: 'push',
          threadId: threadRef.id,
          messageId: messageRef.id,
          siteId: siteId,
        );
      }

      await loadMessages();
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'direct':
        return MessageType.direct;
      case 'announcement':
        return MessageType.announcement;
      case 'alert':
        return MessageType.alert;
      case 'reminder':
        return MessageType.reminder;
      default:
        return MessageType.system;
    }
  }

  MessagePriority _parseMessagePriority(String? priority) {
    switch (priority) {
      case 'urgent':
        return MessagePriority.urgent;
      case 'high':
        return MessagePriority.high;
      case 'low':
        return MessagePriority.low;
      default:
        return MessagePriority.normal;
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Future<String> _loadDisplayName(
    String uid, {
    required String fallback,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _firestore.collection('users').doc(uid).get();
      final String? displayName = snap.data()?['displayName'] as String?;
      final String? email = snap.data()?['email'] as String?;
      return (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
          : ((email?.trim().isNotEmpty ?? false) ? email!.trim() : fallback);
    } catch (_) {
      return fallback;
    }
  }

  String? _participantNameForLastSender({
    required List<String> participantIds,
    required List<String> participantNames,
    required String? lastSenderId,
  }) {
    if (lastSenderId == null || lastSenderId.isEmpty) return null;
    final int index = participantIds.indexOf(lastSenderId);
    if (index == -1 || index >= participantNames.length) return null;
    return participantNames[index];
  }
}
