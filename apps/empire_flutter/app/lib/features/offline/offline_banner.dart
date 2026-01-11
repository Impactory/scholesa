import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'offline_queue.dart';
import 'offline_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer2<OfflineService, OfflineQueue>(
      builder: (context, offline, queue, _) {
        // Ensure queue is loaded before showing state; call once.
        if (!queue.initialized) {
          queue.load();
        }

        if (!offline.isOffline && queue.initialized) {
          // Kick off a flush as soon as we're back online; guard via queue.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            queue.flush(online: true);
          });
        }

        final showOffline = offline.isOffline;
        final showPendingOnline = !offline.isOffline && queue.hasPending;

        final banner = (showOffline || showPendingOnline)
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: showOffline
                        ? const [Color(0xFFef4444), Color(0xFFb91c1c)]
                        : const [Color(0xFF0ea5e9), Color(0xFF0284c7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      showOffline
                          ? Icons.wifi_off
                          : (queue.isFlushing ? Icons.sync : Icons.cloud_upload),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showOffline
                                ? (queue.hasPending
                                    ? 'Offline • ${queue.pending.length} update(s) queued. Will sync on reconnect.'
                                    : 'You are offline. Changes will sync on reconnect.')
                                : queue.isFlushing
                                    ? 'Syncing ${queue.pending.length} queued update(s)...'
                                    : '${queue.pending.length} update(s) queued. Tap sync to send now.',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          if (queue.lastSyncedAt != null)
                            Text(
                              'Last synced ${_formatTime(queue.lastSyncedAt!)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (!showOffline)
                      TextButton.icon(
                        onPressed: queue.isFlushing
                            ? null
                            : () {
                                queue.flush(online: true);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        icon: queue.isFlushing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(queue.isFlushing ? 'Syncing...' : 'Sync now'),
                      ),
                  ],
                ),
              )
            : null;

        return Stack(
          children: [
            Positioned.fill(child: child),
            if (banner != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: banner),
              ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
