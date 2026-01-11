import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'message_models.dart';

/// Service for messages and notifications
class MessageService extends ChangeNotifier {

  MessageService({
    required FirestoreService firestoreService,
    required this.userId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Message> _messages = <Message>[];
  List<Conversation> _conversations = <Conversation>[];
  bool _isLoading = false;
  String? _error;
  MessageType? _typeFilter;

  // Getters
  List<Message> get messages => _filteredMessages;
  List<Message> get unreadMessages => _messages.where((Message m) => !m.isRead).toList();
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => unreadMessages.length;
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
      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _messages = messagesSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
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
        );
      }).toList();

      // Load conversations for this user
      final QuerySnapshot<Map<String, dynamic>> conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();

      _conversations = await Future.wait(
        conversationsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
          final Map<String, dynamic> data = doc.data();
          final List<String> participantIds = List<String>.from(data['participantIds'] as List? ?? <String>[]);
          final List<String> participantNames = List<String>.from(data['participantNames'] as List? ?? <String>[]);

          // Get the last message in the conversation
          final QuerySnapshot<Map<String, dynamic>> lastMsgSnapshot = await _firestore
              .collection('conversations')
              .doc(doc.id)
              .collection('messages')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          Message? lastMessage;
          if (lastMsgSnapshot.docs.isNotEmpty) {
            final Map<String, dynamic> msgData = lastMsgSnapshot.docs.first.data();
            lastMessage = Message(
              id: lastMsgSnapshot.docs.first.id,
              title: '',
              body: msgData['body'] as String? ?? '',
              type: MessageType.direct,
              senderName: msgData['senderName'] as String?,
              createdAt: _parseTimestamp(msgData['createdAt']) ?? DateTime.now(),
              isRead: msgData['isRead'] as bool? ?? false,
            );
          }

          return Conversation(
            id: doc.id,
            participantIds: participantIds,
            participantNames: participantNames,
            lastMessage: lastMessage,
            updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
            unreadCount: data['unreadCount'] as int? ?? 0,
          );
        }),
      );

      debugPrint('Loaded ${_messages.length} messages and ${_conversations.length} conversations');
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
      await _firestore.collection('messages').doc(messageId).update(<String, dynamic>{
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
        batch.update(_firestore.collection('messages').doc(message.id), <String, dynamic>{
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      _messages = _messages.map((Message m) => m.copyWith(
        isRead: true,
        readAt: m.readAt ?? now,
      )).toList();
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
      final DocumentSnapshot<Map<String, dynamic>> senderDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      final String senderName = senderDoc.data()?['displayName'] as String? ?? 'Unknown';

      if (conversationId != null) {
        // Add to existing conversation
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .add(<String, dynamic>{
          'body': body,
          'senderId': userId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        await _firestore.collection('conversations').doc(conversationId).update(<String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new conversation
        final DocumentReference<Map<String, dynamic>> convRef = await _firestore
            .collection('conversations')
            .add(<String, dynamic>{
          'participantIds': <String>[userId, recipientId],
          'participantNames': <String>[senderName, recipientId], // Will need to lookup recipient name
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await convRef.collection('messages').add(<String, dynamic>{
          'body': body,
          'senderId': userId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
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
}
