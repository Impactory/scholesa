import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _notificationsEs = <String, String>{
  'Notifications': 'Notificaciones',
  'Mark all read': 'Marcar todo como leído',
  'No notifications': 'Sin notificaciones',
  'You\'re all caught up!': '¡Ya estás al día!',
  'Notification dismissed': 'Notificación descartada',
  'Opening:': 'Abriendo:',
  'All notifications marked as read':
    'Todas las notificaciones se marcaron como leídas',
  'm ago': 'min atrás',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'New Mission Available': 'Nueva misión disponible',
  'Check out the new AI Fundamentals mission for your learners!':
    '¡Revisa la nueva misión de Fundamentos de IA para tus estudiantes!',
  'Session Reminder': 'Recordatorio de sesión',
  'Robotics Club starts in 1 hour at Room 204':
    'El Club de Robótica comienza en 1 hora en el Aula 204',
  'Message from Ms. Johnson': 'Mensaje de la profesora Johnson',
  'Great progress on the coding project! Keep it up.':
    '¡Gran progreso en el proyecto de programación! Sigue así.',
  'System Update': 'Actualización del sistema',
  'Scholesa has been updated with new features. Check out what\'s new!':
    'Scholesa se actualizó con nuevas funciones. ¡Mira qué hay de nuevo!',
};

String _tNotifications(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _notificationsEs[input] ?? input;
}

/// Notifications page for all user roles
/// Based on docs/17_MESSAGING_NOTIFICATIONS_SPEC.md
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _NotificationType { message, reminder, alert, system }

class _Notification {
  _Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final _NotificationType type;
  final DateTime createdAt;
  bool isRead;
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_Notification> _notifications = <_Notification>[
    _Notification(
      id: '1',
      title: 'New Mission Available',
      body: 'Check out the new AI Fundamentals mission for your learners!',
      type: _NotificationType.alert,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
    ),
    _Notification(
      id: '2',
      title: 'Session Reminder',
      body: 'Robotics Club starts in 1 hour at Room 204',
      type: _NotificationType.reminder,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    _Notification(
      id: '3',
      title: 'Message from Ms. Johnson',
      body: 'Great progress on the coding project! Keep it up.',
      type: _NotificationType.message,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    _Notification(
      id: '4',
      title: 'System Update',
      body:
          'Scholesa has been updated with new features. Check out what\'s new!',
      type: _NotificationType.system,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final int unreadCount =
        _notifications.where((_Notification n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tNotifications(context, 'Notifications')),
        backgroundColor: ScholesaColors.primary,
        foregroundColor: Colors.white,
        actions: <Widget>[
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(_tNotifications(context, 'Mark all read'),
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (BuildContext context, int index) =>
                  _buildNotificationCard(_notifications[index]),
            ),
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

  Widget _buildNotificationCard(_Notification notification) {
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
        setState(() {
          _notifications
              .removeWhere((_Notification n) => n.id == notification.id);
        });
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
          onTap: () => _handleNotificationTap(notification),
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

  Widget _buildTypeIcon(_NotificationType type) {
    IconData icon;
    Color color;
    switch (type) {
      case _NotificationType.message:
        icon = Icons.chat_bubble_rounded;
        color = Colors.blue;
      case _NotificationType.reminder:
        icon = Icons.schedule_rounded;
        color = Colors.orange;
      case _NotificationType.alert:
        icon = Icons.notifications_active_rounded;
        color = Colors.green;
      case _NotificationType.system:
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

  void _handleNotificationTap(_Notification notification) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'notifications_open_item',
        'notification_id': notification.id,
        'notification_type': notification.type.name,
      },
    );
    setState(() {
      notification.isRead = true;
    });
    // Navigate based on notification type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_tNotifications(context, 'Opening:')} ${_tNotifications(context, notification.title)}',
        ),
      ),
    );
  }

  void _markAllAsRead() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'notifications_mark_all_read'},
    );
    setState(() {
      for (final _Notification n in _notifications) {
        n.isRead = true;
      }
    });
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
