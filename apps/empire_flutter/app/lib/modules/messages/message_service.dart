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

  /// Load all messages
  Future<void> loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _messages = _generateMockMessages();
      _conversations = _generateMockConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a message as read
  Future<bool> markAsRead(String messageId) async {
    try {
      final int index = _messages.indexWhere((Message m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Mark all messages as read
  Future<void> markAllAsRead() async {
    final DateTime now = DateTime.now();
    _messages = _messages.map((Message m) => m.copyWith(
      isRead: true,
      readAt: m.readAt ?? now,
    )).toList();
    notifyListeners();
  }

  /// Delete a message
  Future<bool> deleteMessage(String messageId) async {
    try {
      _messages = _messages.where((Message m) => m.id != messageId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Mock data generators
  List<Message> _generateMockMessages() {
    final DateTime now = DateTime.now();
    return <Message>[
      Message(
        id: 'msg_001',
        title: 'Welcome to Scholesa!',
        body: "We're excited to have you on board. Start exploring your dashboard to discover all the amazing features.",
        type: MessageType.system,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      Message(
        id: 'msg_002',
        title: 'New Mission Available',
        body: 'A new coding mission "Build a Calculator" has been assigned to you. Due in 7 days.',
        type: MessageType.announcement,
        priority: MessagePriority.high,
        senderName: 'Ms. Johnson',
        createdAt: now.subtract(const Duration(hours: 2)),
        actionUrl: '/learner/missions',
      ),
      Message(
        id: 'msg_003',
        title: 'Great Progress! 🎉',
        body: "You've completed 5 habits in a row! Keep up the amazing work.",
        type: MessageType.system,
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: true,
        readAt: now.subtract(const Duration(hours: 4)),
      ),
      Message(
        id: 'msg_004',
        title: 'Schedule Change',
        body: "Tomorrow's Science class has been moved from 10:00 AM to 2:00 PM.",
        type: MessageType.alert,
        priority: MessagePriority.urgent,
        senderName: 'Admin',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      Message(
        id: 'msg_005',
        title: 'Parent-Teacher Conference',
        body: "Don't forget: Parent-Teacher conference is scheduled for Friday at 3:00 PM.",
        type: MessageType.reminder,
        priority: MessagePriority.high,
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
        readAt: now.subtract(const Duration(hours: 20)),
      ),
      Message(
        id: 'msg_006',
        title: 'Message from Ms. Chen',
        body: 'Hi! I wanted to discuss your project progress. Can we schedule a quick chat?',
        type: MessageType.direct,
        senderId: 'educator_001',
        senderName: 'Ms. Chen',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        isRead: true,
      ),
      Message(
        id: 'msg_007',
        title: 'Weekly Summary',
        body: "Here's your weekly learning summary: 3 missions completed, 15 habits tracked, 450 XP earned!",
        type: MessageType.system,
        priority: MessagePriority.low,
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }

  List<Conversation> _generateMockConversations() {
    final DateTime now = DateTime.now();
    return <Conversation>[
      Conversation(
        id: 'conv_001',
        participantIds: <String>[userId, 'educator_001'],
        participantNames: const <String>['You', 'Ms. Chen'],
        lastMessage: Message(
          id: 'msg_006',
          title: '',
          body: 'Hi! I wanted to discuss your project progress.',
          type: MessageType.direct,
          senderName: 'Ms. Chen',
          createdAt: now.subtract(const Duration(days: 1, hours: 4)),
          isRead: true,
        ),
        updatedAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      Conversation(
        id: 'conv_002',
        participantIds: <String>[userId, 'educator_002'],
        participantNames: const <String>['You', 'Mr. Williams'],
        lastMessage: Message(
          id: 'msg_temp',
          title: '',
          body: 'Your presentation was excellent!',
          type: MessageType.direct,
          senderName: 'Mr. Williams',
          createdAt: now.subtract(const Duration(days: 3)),
          isRead: true,
        ),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}
