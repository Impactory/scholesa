'use client';

import { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../../firebase/client-init';
import { 
  RotateCcw, 
  AlertTriangle, 
  CheckCircle,
  Loader2,
  DollarSign
} from 'lucide-react';

interface RefundFormData {
  paymentIntentId: string;
  amount: string;
  reason: string;
}

interface RefundResult {
  success: boolean;
  refundId: string;
  status: string;
  amount: number;
}

export function RefundManager() {
  const [formData, setFormData] = useState<RefundFormData>({
    paymentIntentId: '',
    amount: '',
    reason: 'requested_by_customer',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<RefundResult | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!formData.paymentIntentId.trim()) {
      setError('Payment Intent ID is required');
      return;
    }

    setLoading(true);

    try {
      const processRefund = httpsCallable<
        { paymentIntentId: string; amount?: number; reason?: string },
        RefundResult
      >(functions, 'processRefund');

      const params: { paymentIntentId: string; amount?: number; reason?: string } = {
        paymentIntentId: formData.paymentIntentId.trim(),
        reason: formData.reason,
      };

      // Convert amount to cents if provided
      if (formData.amount.trim()) {
        const amountInCents = Math.round(parseFloat(formData.amount) * 100);
        if (isNaN(amountInCents) || amountInCents <= 0) {
          throw new Error('Invalid amount');
        }
        params.amount = amountInCents;
      }

      const result = await processRefund(params);
      setSuccess(result.data);
      
      // Reset form
      setFormData({
        paymentIntentId: '',
        amount: '',
        reason: 'requested_by_customer',
      });
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to process refund';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="p-2 bg-orange-100 rounded-lg">
          <RotateCcw className="w-6 h-6 text-orange-600" />
        </div>
        <div>
          <h2 className="text-xl font-semibold text-gray-900">Process Refund</h2>
          <p className="text-sm text-gray-500">Issue refunds for Stripe payments</p>
        </div>
      </div>

      {/* Warning */}
      <div className="mb-6 p-4 bg-amber-50 border border-amber-200 rounded-lg">
        <div className="flex items-start gap-2 text-amber-700">
          <AlertTriangle className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <div className="text-sm">
            <p className="font-medium">Warning: Refunds are permanent</p>
            <p className="mt-1">Once processed, refunds cannot be reversed. Partial refunds can be issued by specifying an amount.</p>
          </div>
        </div>
      </div>

      {/* Success Message */}
      {success && (
        <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
          <div className="flex items-start gap-2 text-green-700">
            <CheckCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
            <div className="text-sm">
              <p className="font-medium">Refund processed successfully!</p>
              <p className="mt-1">Refund ID: {success.refundId}</p>
              <p>Amount: ${(success.amount / 100).toFixed(2)}</p>
              <p>Status: {success.status}</p>
            </div>
          </div>
        </div>
      )}

      {/* Error Message */}
      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center gap-2 text-red-700">
            <AlertTriangle className="w-5 h-5" />
            <span className="text-sm">{error}</span>
          </div>
        </div>
      )}

      {/* Form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="paymentIntentId" className="block text-sm font-medium text-gray-700 mb-1">
            Payment Intent ID <span className="text-red-500">*</span>
          </label>
          <input
            type="text"
            id="paymentIntentId"
            value={formData.paymentIntentId}
            onChange={(e) => setFormData({ ...formData, paymentIntentId: e.target.value })}
            placeholder="pi_..."
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            disabled={loading}
          />
          <p className="mt-1 text-xs text-gray-500">
            Find this in your Stripe Dashboard or in the payment record
          </p>
        </div>

        <div>
          <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-1">
            Amount (optional)
          </label>
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <DollarSign className="h-4 w-4 text-gray-400" />
            </div>
            <input
              type="number"
              id="amount"
              value={formData.amount}
              onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
              placeholder="Leave empty for full refund"
              step="0.01"
              min="0.01"
              className="w-full pl-8 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              disabled={loading}
            />
          </div>
          <p className="mt-1 text-xs text-gray-500">
            Enter a specific amount for partial refund, or leave empty for full refund
          </p>
        </div>

        <div>
          <label htmlFor="reason" className="block text-sm font-medium text-gray-700 mb-1">
            Reason
          </label>
          <select
            id="reason"
            value={formData.reason}
            onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            disabled={loading}
          >
            <option value="requested_by_customer">Requested by Customer</option>
            <option value="duplicate">Duplicate Payment</option>
            <option value="fraudulent">Fraudulent</option>
          </select>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full flex items-center justify-center gap-2 px-4 py-3 text-white bg-orange-600 rounded-lg hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
        >
          {loading ? (
            <>
              <Loader2 className="w-5 h-5 animate-spin" />
              Processing...
            </>
          ) : (
            <>
              <RotateCcw className="w-5 h-5" />
              Process Refund
            </>
          )}
        </button>
      </form>
    </div>
  );
}
