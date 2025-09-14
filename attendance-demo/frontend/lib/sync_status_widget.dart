import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sync_manager.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncManager>(
      builder: (context, syncManager, child) {
        if (!syncManager.isOnline && syncManager.queuedCount == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.red.shade100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (syncManager.queuedCount > 0) {
          return GestureDetector(
            onTap: () => _showQueueDialog(context, syncManager),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: syncManager.isSyncing 
                  ? Colors.blue.shade100 
                  : Colors.orange.shade100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncManager.isSyncing) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Syncing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      syncManager.isOnline ? Icons.sync : Icons.sync_disabled,
                      size: 16,
                      color: syncManager.isOnline 
                          ? Colors.orange.shade700 
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${syncManager.queuedCount} queued',
                      style: TextStyle(
                        fontSize: 12,
                        color: syncManager.isOnline 
                            ? Colors.orange.shade700 
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        if (syncManager.isOnline) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.green.shade100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showQueueDialog(BuildContext context, SyncManager syncManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.queue, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Queued Actions'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${syncManager.queuedCount} actions waiting to sync',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: syncManager.queuedActions.length,
                  itemBuilder: (context, index) {
                    final action = syncManager.queuedActions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        leading: _getActionIcon(action.type),
                        title: Text(
                          syncManager.getActionDescription(action),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(action.createdAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (action.retryCount > 0)
                              Text(
                                'Retries: ${action.retryCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
                        ),
                        trailing: action.filePath != null
                            ? Icon(Icons.attach_file, size: 16, color: Colors.blue.shade600)
                            : null,
                        isThreeLine: action.retryCount > 0,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (syncManager.isOnline && !syncManager.isSyncing)
            TextButton.icon(
              onPressed: () {
                syncManager.forceSyncNow();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          TextButton.icon(
            onPressed: () {
              _showClearQueueConfirmation(context, syncManager);
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Queue'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearQueueConfirmation(BuildContext context, SyncManager syncManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Queue'),
        content: const Text(
          'Are you sure you want to clear all queued actions? This will permanently delete unsynchronized data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              syncManager.clearQueue();
              Navigator.pop(context); // Close confirmation
              Navigator.pop(context); // Close queue dialog
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _getActionIcon(QueuedActionType type) {
    switch (type) {
      case QueuedActionType.enroll:
        return Icon(Icons.person_add, color: Colors.blue.shade600);
      case QueuedActionType.markAttendance:
        return Icon(Icons.check_circle, color: Colors.green.shade600);
      case QueuedActionType.odRequest:
        return Icon(Icons.assignment, color: Colors.purple.shade600);
      case QueuedActionType.heartbeat:
        return Icon(Icons.favorite, color: Colors.red.shade600);
      case QueuedActionType.attendanceUpdate:
        return Icon(Icons.edit, color: Colors.orange.shade600);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
