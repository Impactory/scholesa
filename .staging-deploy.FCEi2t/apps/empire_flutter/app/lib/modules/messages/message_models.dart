import 'package:equatable/equatable.dart';

/// Message type classification
enum MessageType {
  announcement,
  direct,
  system,
  alert,
  reminder;

  String get label {
    switch (this) {
      case MessageType.announcement:
        return 'Announcement';
      case MessageType.direct:
        return 'Direct Message';
      case MessageType.system:
        return 'System';
      case MessageType.alert:
        return 'Alert';
      case MessageType.reminder:
        return 'Reminder';
    }
  }

  String get emoji {
    switch (this) {
      case MessageType.announcement:
        return '📢';
      case MessageType.direct:
        return '💬';
      case MessageType.system:
        return '⚙️';
      case MessageType.alert:
        return '🚨';
      case MessageType.reminder:
        return '⏰';
    }
  }
}

/// Message priority
enum MessagePriority {
  low,
  normal,
  high,
  urgent;

  String get label {
    switch (this) {
      case MessagePriority.low:
        return 'Low';
      case MessagePriority.normal:
        return 'Normal';
      case MessagePriority.high:
        return 'High';
      case MessagePriority.urgent:
        return 'Urgent';
    }
  }
}

/// Model for a message/notification
class Message extends Equatable {

  const Message({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.priority = MessagePriority.normal,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.recipientId,
    this.siteId,
    required this.createdAt,
    this.readAt,
    this.isRead = false,
    this.actionUrl,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.system,
      ),
      priority: MessagePriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => MessagePriority.normal,
      ),
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      recipientId: json['recipientId'] as String?,
      siteId: json['siteId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      actionUrl: json['actionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String title;
  final String body;
  final MessageType type;
  final MessagePriority priority;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? recipientId;
  final String? siteId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'recipientId': recipientId,
      'siteId': siteId,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'actionUrl': actionUrl,
      'metadata': metadata,
    };
  }

  Message copyWith({
    String? id,
    String? title,
    String? body,
    MessageType? type,
    MessagePriority? priority,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? recipientId,
    String? siteId,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isRead,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      recipientId: recipientId ?? this.recipientId,
      siteId: siteId ?? this.siteId,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id, title, body, type, priority, senderId, senderName,
        senderAvatar, recipientId, siteId, createdAt, readAt,
        isRead, actionUrl, metadata,
      ];
}

/// Conversation thread for direct messages
class Conversation extends Equatable {

  const Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });
  final String id;
  final List<String> participantIds;
  final List<String> participantNames;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  @override
  List<Object?> get props => <Object?>[
        id, participantIds, participantNames, lastMessage,
        unreadCount, updatedAt,
      ];
}
