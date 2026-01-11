import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';
import 'message_thread_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  late Future<List<MessageThreadModel>> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = _loadThreads();
  }

  Future<List<MessageThreadModel>> _loadThreads() async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    final siteId = appState.primarySiteId;
    if (userId == null) return <MessageThreadModel>[];
    return MessageThreadRepository().listByParticipant(userId: userId, siteId: siteId, limit: 50);
  }

  Future<void> _refresh() async {
    setState(() {
      _threadsFuture = _loadThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messaging')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MessageThreadModel>>(
          future: _threadsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final threads = snapshot.data ?? <MessageThreadModel>[];
            if (threads.isEmpty) {
              return const Center(child: Text('No messages yet'));
            }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: threads.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(thread.subject ?? 'Thread ${thread.id}'),
                    subtitle: Text('Participants: ${thread.participantIds.join(', ')}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MessageThreadScreen(thread: thread)),
                    ),
                  );
                },
              );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewThread(context),
        icon: const Icon(Icons.add_comment),
        label: const Text('New thread'),
      ),
    );
  }

  Future<void> _createNewThread(BuildContext context) async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to start a thread')));
      return;
    }
    final threadId = UniqueKey().toString();
    final model = MessageThreadModel(
      id: threadId,
      siteId: appState.primarySiteId ?? '',
      participantIds: <String>[userId],
      subject: 'New thread',
      createdAt: null,
    );
    await MessageThreadRepository().upsert(model);
    await _refresh();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.push(context, MaterialPageRoute(builder: (_) => MessageThreadScreen(thread: model)));
  }
}
