import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'message_models.dart';
import 'message_service.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tNotifications(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Notifications page for all user roles
/// Based on docs/17_MESSAGING_NOTIFICATIONS_SPEC.md
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessageService>().loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageService>(
      builder: (BuildContext context, MessageService service, _) {
        final List<Message> notifications = service.notificationMessages;
        final int unreadCount = service.unreadNotificationCount;

        return Scaffold(
          backgroundColor: ScholesaColors.background,
          appBar: AppBar(
            title: Text(_tNotifications(context, 'Notifications')),
            backgroundColor: ScholesaColors.primary,
            foregroundColor: Colors.white,
            actions: <Widget>[
              if (unreadCount > 0)
                TextButton(
                  onPressed: () => _markAllAsRead(service),
                  child: Text(_tNotifications(context, 'Mark all read'),
                      style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _buildNotificationCard(notifications[index], service),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.notifications_none_rounded,
              size: 64,
              color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            _tNotifications(context, 'No notifications'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _tNotifications(context, 'You\'re all caught up!'),
            style: TextStyle(color: ScholesaColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Message notification, MessageService service) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        TelemetryService.instance.logEvent(
          event: 'nudge.snoozed',
          metadata: <String, dynamic>{
            'nudge_id': notification.id,
            'nudge_type': notification.type.name,
            'surface': 'notifications_list',
          },
        );
        service.deleteMessage(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tNotifications(context, 'Notification dismissed')),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: notification.isRead
            ? ScholesaColors.surface
            : ScholesaColors.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: notification.isRead
              ? BorderSide.none
              : BorderSide(
                  color: ScholesaColors.primary.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification, service),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildTypeIcon(notification.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _tNotifications(context, notification.title),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: ScholesaColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tNotifications(context, notification.body),
                        style: const TextStyle(
                            fontSize: 13, color: ScholesaColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(notification.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(MessageType type) {
    IconData icon;
    Color color;
    switch (type) {
      case MessageType.direct:
        icon = Icons.chat_bubble_rounded;
        color = Colors.blue;
      case MessageType.reminder:
        icon = Icons.schedule_rounded;
        color = Colors.orange;
      case MessageType.alert:
        icon = Icons.notifications_active_rounded;
        color = Colors.green;
      case MessageType.announcement:
        icon = Icons.campaign_rounded;
        color = Colors.teal;
      case MessageType.system:
        icon = Icons.settings_rounded;
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _handleNotificationTap(Message notification, MessageService service) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'notifications_open_item',
        'notification_id': notification.id,
        'notification_type': notification.type.name,
      },
    );
    service.markAsRead(notification.id);
    // Navigate based on notification type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_tNotifications(context, 'Opening:')} ${_tNotifications(context, notification.title)}',
        ),
      ),
    );
  }

  void _markAllAsRead(MessageService service) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'notifications_mark_all_read'},
    );
    service.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_tNotifications(context, 'All notifications marked as read')),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${_tNotifications(context, 'm ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${_tNotifications(context, 'h ago')}';
    }
    return '${diff.inDays}${_tNotifications(context, 'd ago')}';
  }
}
