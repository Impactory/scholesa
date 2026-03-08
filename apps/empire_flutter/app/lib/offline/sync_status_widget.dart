import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/inline_locale_text.dart';
import 'sync_coordinator.dart';

const Map<String, String> _syncStatusZhCn = <String, String>{
  'pending': '待同步',
  'Offline': '离线',
  "You're offline. Changes will sync when you reconnect.":
      '你当前处于离线状态。重新连接后会自动同步更改。',
  'RETRY': '重试',
};

const Map<String, String> _syncStatusZhTw = <String, String>{
  'pending': '待同步',
  'Offline': '離線',
  "You're offline. Changes will sync when you reconnect.":
      '你目前處於離線狀態。重新連線後會自動同步變更。',
  'RETRY': '重試',
};

String _tSyncStatus(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _syncStatusZhCn,
    zhTw: _syncStatusZhTw,
  );
}

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
                    ? '${sync.pendingCount} ${_tSyncStatus(context, 'pending')}'
                    : _tSyncStatus(context, 'Offline'),
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
          content: Text(
            _tSyncStatus(
                context, "You're offline. Changes will sync when you reconnect."),
            style: TextStyle(color: Colors.white),
          ),
          leading: const Icon(Icons.cloud_off, color: Colors.white),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{'cta': 'offline_retry_failed'},
                );
                sync.retryFailed();
              },
              child: Text(
                _tSyncStatus(context, 'RETRY'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
