import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sync_coordinator.dart';

/// Sync status indicator widget
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncCoordinator>(
      builder: (BuildContext context, SyncCoordinator sync, _) {
        if (sync.isOnline && sync.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sync.isOnline ? Colors.orange[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (sync.isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  sync.isOnline ? Icons.sync : Icons.cloud_off,
                  size: 16,
                  color: sync.isOnline ? Colors.orange[800] : Colors.grey[700],
                ),
              const SizedBox(width: 6),
              Text(
                sync.isOnline
                    ? '${sync.pendingCount} pending'
                    : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: sync.isOnline ? Colors.orange[800] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline banner for screens
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncCoordinator>(
      builder: (BuildContext context, SyncCoordinator sync, _) {
        if (sync.isOnline) return const SizedBox.shrink();

        return MaterialBanner(
          backgroundColor: Colors.grey[800],
          content: const Text(
            "You're offline. Changes will sync when you reconnect.",
            style: TextStyle(color: Colors.white),
          ),
          leading: const Icon(Icons.cloud_off, color: Colors.white),
          actions: <Widget>[
            TextButton(
              onPressed: () => sync.retryFailed(),
              child: const Text(
                'RETRY',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
