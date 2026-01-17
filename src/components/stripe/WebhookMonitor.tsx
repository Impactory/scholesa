'use client';

import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../../firebase/client-init';
import { 
  Activity, 
  AlertTriangle, 
  CheckCircle, 
  XCircle,
  RefreshCw,
  Filter
} from 'lucide-react';

interface WebhookLog {
  id: string;
  eventType: string;
  status: string;
  timestamp: string;
  details?: Record<string, unknown>;
}

export function WebhookMonitor() {
  const [logs, setLogs] = useState<WebhookLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [refreshing, setRefreshing] = useState(false);

  const fetchLogs = async () => {
    try {
      setRefreshing(true);
      const getWebhookLogs = httpsCallable<
        { limit?: number; status?: string },
        { logs: WebhookLog[] }
      >(functions, 'getWebhookLogs');

      const params: { limit: number; status?: string } = { limit: 100 };
      if (statusFilter !== 'all') {
        params.status = statusFilter;
      }

      const result = await getWebhookLogs(params);
      setLogs(result.data.logs);
      setError(null);
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch logs';
      setError(errorMessage);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, [statusFilter]);

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'success':
      case 'processed':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'error':
      case 'failed':
        return <XCircle className="w-4 h-4 text-red-500" />;
      default:
        return <Activity className="w-4 h-4 text-yellow-500" />;
    }
  };

  const getStatusBadge = (status: string) => {
    const baseClasses = 'px-2 py-1 text-xs font-medium rounded-full';
    switch (status) {
      case 'success':
      case 'processed':
        return `${baseClasses} bg-green-100 text-green-800`;
      case 'error':
      case 'failed':
        return `${baseClasses} bg-red-100 text-red-800`;
      default:
        return `${baseClasses} bg-yellow-100 text-yellow-800`;
    }
  };

  const formatEventType = (eventType: string) => {
    return eventType.replace(/\./g, ' › ');
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3"></div>
          <div className="space-y-2">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="h-12 bg-gray-100 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  const errorCount = logs.filter(l => l.status === 'error' || l.status === 'failed').length;
  const successCount = logs.filter(l => l.status === 'success' || l.status === 'processed').length;

  return (
    <div className="bg-white rounded-lg shadow-md">
      {/* Header */}
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Activity className="w-6 h-6 text-indigo-600" />
            <h2 className="text-xl font-semibold text-gray-900">Webhook Monitor</h2>
          </div>
          <button
            onClick={fetchLogs}
            disabled={refreshing}
            className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>

        {/* Stats */}
        <div className="mt-4 grid grid-cols-3 gap-4">
          <div className="bg-gray-50 rounded-lg p-3">
            <div className="text-2xl font-bold text-gray-900">{logs.length}</div>
            <div className="text-sm text-gray-500">Total Events</div>
          </div>
          <div className="bg-green-50 rounded-lg p-3">
            <div className="text-2xl font-bold text-green-600">{successCount}</div>
            <div className="text-sm text-gray-500">Successful</div>
          </div>
          <div className="bg-red-50 rounded-lg p-3">
            <div className="flex items-center gap-2">
              <div className="text-2xl font-bold text-red-600">{errorCount}</div>
              {errorCount > 0 && <AlertTriangle className="w-5 h-5 text-red-500" />}
            </div>
            <div className="text-sm text-gray-500">Failed</div>
          </div>
        </div>

        {/* Filter */}
        <div className="mt-4 flex items-center gap-2">
          <Filter className="w-4 h-4 text-gray-400" />
          <label htmlFor="status-filter" className="sr-only">Filter by status</label>
          <select
            id="status-filter"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="text-sm border border-gray-300 rounded-md px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            <option value="all">All Events</option>
            <option value="success">Success Only</option>
            <option value="processed">Processed Only</option>
            <option value="error">Errors Only</option>
            <option value="failed">Failed Only</option>
          </select>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="p-4 bg-red-50 border-b border-red-200">
          <div className="flex items-center gap-2 text-red-700">
            <AlertTriangle className="w-4 h-4" />
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Logs Table */}
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Event Type
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Timestamp
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {logs.length === 0 ? (
              <tr>
                <td colSpan={3} className="px-6 py-12 text-center text-gray-500">
                  No webhook events found
                </td>
              </tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-2">
                      {getStatusIcon(log.status)}
                      <span className={getStatusBadge(log.status)}>
                        {log.status}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-sm font-medium text-gray-900">
                      {formatEventType(log.eventType)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {log.timestamp 
                      ? new Date(log.timestamp).toLocaleString()
                      : 'N/A'}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
