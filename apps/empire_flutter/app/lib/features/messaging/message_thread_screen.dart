import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../services/notification_service.dart';
import '../../services/telemetry_service.dart';
import '../auth/app_state.dart';

class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({super.key, required this.thread});

  final MessageThreadModel thread;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _composer = TextEditingController();
  late Future<List<MessageModel>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<List<MessageModel>> _loadMessages() async {
    return MessageRepository().listByThread(widget.thread.id, limit: 100);
  }

  Future<void> _refresh() async {
    setState(() {
      _messagesFuture = _loadMessages();
    });
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final appState = context.read<AppState>();
    final role = appState.role ?? 'user';
    final siteId = widget.thread.siteId;
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      threadId: widget.thread.id,
      siteId: widget.thread.siteId,
      senderId: user.uid,
      senderRole: 'user',
      body: body,
      createdAt: null,
    );
    try {
      await MessageRepository().add(msg);
      _composer.clear();
      await TelemetryService.instance.logEvent(
        event: 'message.sent',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'threadId': widget.thread.id,
          'length': body.length,
        },
      );

      // Best-effort external notification for elevated roles.
      if (siteId.isNotEmpty && <String>{'hq', 'site', 'educator'}.contains(role)) {
        await NotificationService.instance.requestSend(
          channel: 'inapp',
          threadId: widget.thread.id,
          messageId: msg.id,
          siteId: siteId,
        );
      }
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.thread.subject ?? 'Thread')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<MessageModel>>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data ?? <MessageModel>[];
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages'));
                  }
                  return ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return ListTile(
                        leading: const Icon(Icons.account_circle),
                        title: Text(msg.body),
                        subtitle: Text('From ${msg.senderId} · ${msg.createdAt?.toDate() ?? DateTime.now()}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration: const InputDecoration(hintText: 'Message…'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
