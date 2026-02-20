'use client';

import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { FileText, Download, RefreshCw, Loader2, CheckCircle, XCircle, Clock } from 'lucide-react';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';

interface Invoice {
  id: string;
  number: string;
  status: string;
  amount_due: number;
  amount_paid: number;
  currency: string;
  created: number;
  hosted_invoice_url?: string;
  invoice_pdf?: string;
}

const statusConfig: Record<string, { color: string; icon: typeof CheckCircle; label: string }> = {
  paid: { color: 'text-green-600 bg-green-50', icon: CheckCircle, label: 'Paid' },
  open: { color: 'text-yellow-600 bg-yellow-50', icon: Clock, label: 'Open' },
  draft: { color: 'text-gray-600 bg-gray-50', icon: FileText, label: 'Draft' },
  uncollectible: { color: 'text-red-600 bg-red-50', icon: XCircle, label: 'Uncollectible' },
  void: { color: 'text-gray-600 bg-gray-50', icon: XCircle, label: 'Void' },
};

export function InvoiceHistory() {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [retrying, setRetrying] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const trackInteraction = useInteractionTracking();

  const fetchInvoices = async () => {
    trackInteraction('help_accessed', { cta: 'invoice_history_refresh' });
    setLoading(true);
    setError(null);

    try {
      const getInvoiceHistory = httpsCallable(functions, 'getInvoiceHistory');
      const result = await getInvoiceHistory({ limit: 20 });
      const data = result.data as { invoices: Invoice[] };
      setInvoices(data.invoices || []);
    } catch (err: any) {
      setError(err.message || 'Failed to load invoices');
    } finally {
      setLoading(false);
    }
  };

  const handleRetryPayment = async (invoiceId: string) => {
    trackInteraction('feature_discovered', { cta: 'invoice_retry_payment', invoiceId });
    setRetrying(invoiceId);

    try {
      const retryInvoicePayment = httpsCallable(functions, 'retryInvoicePayment');
      await retryInvoicePayment({ invoiceId });
      await fetchInvoices();
    } catch (err: any) {
      setError(err.message || 'Failed to retry payment');
    } finally {
      setRetrying(null);
    }
  };

  useEffect(() => {
    fetchInvoices();
  }, []);

  const formatCurrency = (amount: number, currency: string) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency.toUpperCase(),
    }).format(amount / 100);
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-indigo-600" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-red-50 p-6 text-center">
        <p className="text-red-700">{error}</p>
        <button
          onClick={fetchInvoices}
          className="mt-4 text-sm font-medium text-red-600 hover:text-red-500"
        >
          Try again
        </button>
      </div>
    );
  }

  if (invoices.length === 0) {
    return (
      <div className="rounded-lg border-2 border-dashed border-gray-200 p-12 text-center">
        <FileText className="mx-auto h-12 w-12 text-gray-400" />
        <h3 className="mt-4 text-lg font-medium text-gray-900">No invoices yet</h3>
        <p className="mt-2 text-sm text-gray-500">
          Your invoices will appear here once you have an active subscription.
        </p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
              Invoice
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
              Date
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
              Amount
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
              Status
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white">
          {invoices.map((invoice) => {
            const status = statusConfig[invoice.status] || statusConfig.draft;
            const StatusIcon = status.icon;

            return (
              <tr key={invoice.id}>
                <td className="whitespace-nowrap px-6 py-4">
                  <div className="flex items-center gap-3">
                    <FileText className="h-5 w-5 text-gray-400" />
                    <span className="font-medium text-gray-900">{invoice.number || invoice.id.slice(-8)}</span>
                  </div>
                </td>
                <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500">
                  {formatDate(invoice.created)}
                </td>
                <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900">
                  {formatCurrency(invoice.amount_due, invoice.currency)}
                </td>
                <td className="whitespace-nowrap px-6 py-4">
                  <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium ${status.color}`}>
                    <StatusIcon className="h-3.5 w-3.5" />
                    {status.label}
                  </span>
                </td>
                <td className="whitespace-nowrap px-6 py-4 text-right text-sm">
                  <div className="flex items-center justify-end gap-2">
                    {invoice.status === 'open' && (
                      <button
                        onClick={() => handleRetryPayment(invoice.id)}
                        disabled={retrying === invoice.id}
                        className="inline-flex items-center gap-1 text-indigo-600 hover:text-indigo-500 disabled:opacity-50"
                      >
                        {retrying === invoice.id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <RefreshCw className="h-4 w-4" />
                        )}
                        Retry
                      </button>
                    )}
                    {invoice.hosted_invoice_url && (
                      <a
                        href={invoice.hosted_invoice_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        onClick={() => trackInteraction('feature_discovered', { cta: 'invoice_view', invoiceId: invoice.id })}
                        className="text-gray-600 hover:text-gray-500"
                      >
                        View
                      </a>
                    )}
                    {invoice.invoice_pdf && (
                      <a
                        href={invoice.invoice_pdf}
                        target="_blank"
                        rel="noopener noreferrer"
                        onClick={() => trackInteraction('feature_discovered', { cta: 'invoice_pdf_download', invoiceId: invoice.id })}
                        className="inline-flex items-center gap-1 text-gray-600 hover:text-gray-500"
                      >
                        <Download className="h-4 w-4" />
                        PDF
                      </a>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
