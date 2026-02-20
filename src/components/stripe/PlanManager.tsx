'use client';

import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../../firebase/client-init';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { 
  Package, 
  Plus, 
  Edit2, 
  Archive, 
  DollarSign,
  RefreshCw,
  AlertTriangle,
  Check,
  X,
  Loader2,
  Tag
} from 'lucide-react';

interface Price {
  id: string;
  active: boolean;
  currency: string;
  unitAmount: number | null;
  unitAmountFormatted: string;
  recurring: {
    interval: string;
    intervalCount: number;
  } | null;
  type: string;
  nickname: string | null;
  metadata: Record<string, string>;
}

interface Product {
  id: string;
  name: string;
  description: string | null;
  active: boolean;
  metadata: Record<string, string>;
  images: string[];
  created: number;
  updated: number;
  prices: Price[];
}

type ModalType = 'createProduct' | 'editProduct' | 'createPrice' | 'editPrice' | null;

export function PlanManager() {
  const trackInteraction = useInteractionTracking();
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Form states
  const [productForm, setProductForm] = useState({
    name: '',
    description: '',
  });

  const [priceForm, setPriceForm] = useState({
    unitAmount: '',
    currency: 'usd',
    interval: 'month' as 'day' | 'week' | 'month' | 'year',
    intervalCount: '1',
    nickname: '',
    isRecurring: true,
  });

  const fetchProducts = async () => {
    trackInteraction('help_accessed', { cta: 'plan_manager_refresh' });
    try {
      setRefreshing(true);
      const getStripeProducts = httpsCallable<void, { products: Product[] }>(
        functions, 
        'getStripeProducts'
      );
      const result = await getStripeProducts();
      setProducts(result.data.products);
      setError(null);
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch products';
      setError(errorMessage);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchProducts();
  }, []);

  const handleCreateProduct = async () => {
    if (!productForm.name.trim()) {
      setError('Product name is required');
      return;
    }

    setActionLoading(true);
    trackInteraction('feature_discovered', { cta: 'plan_manager_create_product' });
    try {
      const createStripeProduct = httpsCallable<
        { name: string; description?: string },
        { success: boolean }
      >(functions, 'createStripeProduct');

      await createStripeProduct({
        name: productForm.name.trim(),
        description: productForm.description.trim() || undefined,
      });

      setModalType(null);
      setProductForm({ name: '', description: '' });
      fetchProducts();
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create product';
      setError(errorMessage);
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdateProduct = async () => {
    if (!selectedProduct) return;

    setActionLoading(true);
    trackInteraction('feature_discovered', { cta: 'plan_manager_update_product', productId: selectedProduct.id });
    try {
      const updateStripeProduct = httpsCallable<
        { productId: string; name?: string; description?: string; active?: boolean },
        { success: boolean }
      >(functions, 'updateStripeProduct');

      await updateStripeProduct({
        productId: selectedProduct.id,
        name: productForm.name.trim() || undefined,
        description: productForm.description.trim() || undefined,
      });

      setModalType(null);
      setSelectedProduct(null);
      setProductForm({ name: '', description: '' });
      fetchProducts();
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update product';
      setError(errorMessage);
    } finally {
      setActionLoading(false);
    }
  };

  const handleCreatePrice = async () => {
    if (!selectedProduct) return;

    const unitAmount = Math.round(parseFloat(priceForm.unitAmount) * 100);
    if (isNaN(unitAmount) || unitAmount < 0) {
      setError('Please enter a valid price');
      return;
    }

    setActionLoading(true);
    trackInteraction('feature_discovered', { cta: 'plan_manager_create_price', productId: selectedProduct.id });
    try {
      const createStripePrice = httpsCallable<
        {
          productId: string;
          unitAmount: number;
          currency: string;
          recurring?: { interval: string; intervalCount?: number };
          nickname?: string;
        },
        { success: boolean }
      >(functions, 'createStripePrice');

      const params: {
        productId: string;
        unitAmount: number;
        currency: string;
        recurring?: { interval: string; intervalCount?: number };
        nickname?: string;
      } = {
        productId: selectedProduct.id,
        unitAmount,
        currency: priceForm.currency,
      };

      if (priceForm.isRecurring) {
        params.recurring = {
          interval: priceForm.interval,
          intervalCount: parseInt(priceForm.intervalCount) || 1,
        };
      }

      if (priceForm.nickname.trim()) {
        params.nickname = priceForm.nickname.trim();
      }

      await createStripePrice(params);

      setModalType(null);
      setSelectedProduct(null);
      setPriceForm({
        unitAmount: '',
        currency: 'usd',
        interval: 'month',
        intervalCount: '1',
        nickname: '',
        isRecurring: true,
      });
      fetchProducts();
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create price';
      setError(errorMessage);
    } finally {
      setActionLoading(false);
    }
  };

  const handleTogglePriceActive = async (priceId: string, currentActive: boolean) => {
    setActionLoading(true);
    trackInteraction('feature_discovered', { cta: 'plan_manager_toggle_price_active', priceId, nextActive: !currentActive });
    try {
      const updateStripePrice = httpsCallable<
        { priceId: string; active: boolean },
        { success: boolean }
      >(functions, 'updateStripePrice');

      await updateStripePrice({
        priceId,
        active: !currentActive,
      });

      fetchProducts();
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update price';
      setError(errorMessage);
    } finally {
      setActionLoading(false);
    }
  };

  const handleArchiveProduct = async (product: Product) => {
    if (!confirm(`Are you sure you want to archive "${product.name}"? This will deactivate all its prices.`)) {
      return;
    }

    setActionLoading(true);
    trackInteraction('help_accessed', { cta: 'plan_manager_archive_product', productId: product.id });
    try {
      const archiveStripeProduct = httpsCallable<
        { productId: string },
        { success: boolean }
      >(functions, 'archiveStripeProduct');

      await archiveStripeProduct({ productId: product.id });
      fetchProducts();
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to archive product';
      setError(errorMessage);
    } finally {
      setActionLoading(false);
    }
  };

  const openEditProduct = (product: Product) => {
    setSelectedProduct(product);
    setProductForm({
      name: product.name,
      description: product.description || '',
    });
    setModalType('editProduct');
  };

  const openCreatePrice = (product: Product) => {
    setSelectedProduct(product);
    setPriceForm({
      unitAmount: '',
      currency: 'usd',
      interval: 'month',
      intervalCount: '1',
      nickname: '',
      isRecurring: true,
    });
    setModalType('createPrice');
  };

  const closeModal = () => {
    setModalType(null);
    setSelectedProduct(null);
    setProductForm({ name: '', description: '' });
    setPriceForm({
      unitAmount: '',
      currency: 'usd',
      interval: 'month',
      intervalCount: '1',
      nickname: '',
      isRecurring: true,
    });
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/3"></div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-24 bg-gray-100 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-md">
      {/* Header */}
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-purple-100 rounded-lg">
              <Package className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Plan Manager</h2>
              <p className="text-sm text-gray-500">Manage Stripe products and pricing</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={fetchProducts}
              disabled={refreshing}
              className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
              Refresh
            </button>
            <button
              onClick={() => setModalType('createProduct')}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-purple-600 rounded-lg hover:bg-purple-700"
            >
              <Plus className="w-4 h-4" />
              New Product
            </button>
          </div>
        </div>
      </div>

      {/* Error Banner */}
      {error && (
        <div className="p-4 bg-red-50 border-b border-red-200">
          <div className="flex items-center gap-2 text-red-700">
            <AlertTriangle className="w-4 h-4" />
            <span>{error}</span>
            <button onClick={() => setError(null)} className="ml-auto" title="Dismiss error" aria-label="Dismiss error">
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* Products List */}
      <div className="p-6 space-y-4">
        {products.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <Package className="w-12 h-12 mx-auto mb-4 text-gray-300" />
            <p>No products found. Create your first product to get started.</p>
          </div>
        ) : (
          products.map((product) => (
            <div
              key={product.id}
              className={`border rounded-lg p-4 ${
                product.active ? 'border-gray-200' : 'border-gray-100 bg-gray-50'
              }`}
            >
              {/* Product Header */}
              <div className="flex items-start justify-between mb-3">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-semibold text-gray-900">{product.name}</h3>
                    {product.active ? (
                      <span className="px-2 py-0.5 text-xs font-medium bg-green-100 text-green-700 rounded-full">
                        Active
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 text-xs font-medium bg-gray-100 text-gray-600 rounded-full">
                        Archived
                      </span>
                    )}
                  </div>
                  {product.description && (
                    <p className="text-sm text-gray-500 mt-1">{product.description}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">ID: {product.id}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => openEditProduct(product)}
                    className="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg"
                    title="Edit product"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => openCreatePrice(product)}
                    className="p-2 text-purple-500 hover:text-purple-700 hover:bg-purple-50 rounded-lg"
                    title="Add price"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                  {product.active && (
                    <button
                      onClick={() => handleArchiveProduct(product)}
                      className="p-2 text-orange-500 hover:text-orange-700 hover:bg-orange-50 rounded-lg"
                      title="Archive product"
                    >
                      <Archive className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>

              {/* Prices */}
              {product.prices.length > 0 ? (
                <div className="space-y-2">
                  <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Prices
                  </p>
                  <div className="grid gap-2">
                    {product.prices.map((price) => (
                      <div
                        key={price.id}
                        className={`flex items-center justify-between p-3 rounded-lg ${
                          price.active ? 'bg-gray-50' : 'bg-gray-100 opacity-60'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <div className="p-2 bg-white rounded-lg shadow-sm">
                            <DollarSign className="w-4 h-4 text-green-600" />
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="font-semibold text-gray-900">
                                {price.unitAmountFormatted}
                              </span>
                              {price.recurring && (
                                <span className="text-sm text-gray-500">
                                  / {price.recurring.intervalCount > 1 
                                    ? `${price.recurring.intervalCount} ${price.recurring.interval}s`
                                    : price.recurring.interval}
                                </span>
                              )}
                              {price.nickname && (
                                <span className="flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-100 text-blue-700 rounded-full">
                                  <Tag className="w-3 h-3" />
                                  {price.nickname}
                                </span>
                              )}
                            </div>
                            <p className="text-xs text-gray-400">
                              {price.id} • {price.type}
                            </p>
                          </div>
                        </div>
                        <button
                          onClick={() => handleTogglePriceActive(price.id, price.active)}
                          disabled={actionLoading}
                          className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
                            price.active
                              ? 'bg-red-100 text-red-700 hover:bg-red-200'
                              : 'bg-green-100 text-green-700 hover:bg-green-200'
                          } disabled:opacity-50`}
                        >
                          {price.active ? 'Deactivate' : 'Activate'}
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="text-sm text-gray-400 italic">
                  No prices configured
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {/* Modals */}
      {modalType && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-2xl w-full max-w-md mx-4">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-4 border-b">
              <h3 className="text-lg font-semibold text-gray-900">
                {modalType === 'createProduct' && 'Create Product'}
                {modalType === 'editProduct' && 'Edit Product'}
                {modalType === 'createPrice' && `Add Price to ${selectedProduct?.name}`}
              </h3>
              <button
                onClick={closeModal}
                className="p-2 text-gray-400 hover:text-gray-600 rounded-lg"
                title="Close"
                aria-label="Close modal"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Content */}
            <div className="p-4 space-y-4">
              {(modalType === 'createProduct' || modalType === 'editProduct') && (
                <>
                  <div>
                    <label htmlFor="product-name" className="block text-sm font-medium text-gray-700 mb-1">
                      Product Name <span className="text-red-500">*</span>
                    </label>
                    <input
                      id="product-name"
                      type="text"
                      value={productForm.name}
                      onChange={(e) => setProductForm({ ...productForm, name: e.target.value })}
                      placeholder="e.g., Learner Plan"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    />
                  </div>
                  <div>
                    <label htmlFor="product-desc" className="block text-sm font-medium text-gray-700 mb-1">
                      Description
                    </label>
                    <textarea
                      id="product-desc"
                      value={productForm.description}
                      onChange={(e) => setProductForm({ ...productForm, description: e.target.value })}
                      placeholder="Optional description..."
                      rows={3}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    />
                  </div>
                </>
              )}

              {modalType === 'createPrice' && (
                <>
                  <div>
                    <label htmlFor="price-amount" className="block text-sm font-medium text-gray-700 mb-1">
                      Price <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <DollarSign className="h-4 w-4 text-gray-400" />
                      </div>
                      <input
                        id="price-amount"
                        type="number"
                        value={priceForm.unitAmount}
                        onChange={(e) => setPriceForm({ ...priceForm, unitAmount: e.target.value })}
                        placeholder="29.00"
                        step="0.01"
                        min="0"
                        className="w-full pl-8 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                      />
                    </div>
                  </div>

                  <div>
                    <label htmlFor="price-nickname" className="block text-sm font-medium text-gray-700 mb-1">
                      Nickname (optional)
                    </label>
                    <input
                      id="price-nickname"
                      type="text"
                      value={priceForm.nickname}
                      onChange={(e) => setPriceForm({ ...priceForm, nickname: e.target.value })}
                      placeholder="e.g., Monthly, Annual"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    />
                  </div>

                  <div className="flex items-center gap-3">
                    <input
                      id="is-recurring"
                      type="checkbox"
                      checked={priceForm.isRecurring}
                      onChange={(e) => setPriceForm({ ...priceForm, isRecurring: e.target.checked })}
                      className="w-4 h-4 text-purple-600 border-gray-300 rounded focus:ring-purple-500"
                    />
                    <label htmlFor="is-recurring" className="text-sm font-medium text-gray-700">
                      Recurring subscription
                    </label>
                  </div>

                  {priceForm.isRecurring && (
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label htmlFor="price-interval" className="block text-sm font-medium text-gray-700 mb-1">
                          Billing Interval
                        </label>
                        <select
                          id="price-interval"
                          value={priceForm.interval}
                          onChange={(e) => setPriceForm({ 
                            ...priceForm, 
                            interval: e.target.value as 'day' | 'week' | 'month' | 'year'
                          })}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                        >
                          <option value="day">Daily</option>
                          <option value="week">Weekly</option>
                          <option value="month">Monthly</option>
                          <option value="year">Yearly</option>
                        </select>
                      </div>
                      <div>
                        <label htmlFor="interval-count" className="block text-sm font-medium text-gray-700 mb-1">
                          Interval Count
                        </label>
                        <input
                          id="interval-count"
                          type="number"
                          value={priceForm.intervalCount}
                          onChange={(e) => setPriceForm({ ...priceForm, intervalCount: e.target.value })}
                          min="1"
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                        />
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Modal Footer */}
            <div className="flex items-center justify-end gap-3 p-4 border-t bg-gray-50 rounded-b-xl">
              <button
                onClick={closeModal}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100 rounded-lg"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  if (modalType === 'createProduct') handleCreateProduct();
                  else if (modalType === 'editProduct') handleUpdateProduct();
                  else if (modalType === 'createPrice') handleCreatePrice();
                }}
                disabled={actionLoading}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-purple-600 rounded-lg hover:bg-purple-700 disabled:opacity-50"
              >
                {actionLoading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Saving...
                  </>
                ) : (
                  <>
                    <Check className="w-4 h-4" />
                    {modalType === 'createProduct' && 'Create Product'}
                    {modalType === 'editProduct' && 'Update Product'}
                    {modalType === 'createPrice' && 'Create Price'}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
