'use client';

/**
 * Site Implementation Health Dashboard (S4-3)
 *
 * Shows site leads key implementation quality metrics:
 * - Educator adoption (rubric application rates)
 * - Evidence coverage (evidence records per learner)
 * - Proof verification adoption
 * - Growth event velocity
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  collection,
  getDocs,
  query,
  where,
} from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  ActivityIcon,
  CheckCircleIcon,
  UsersIcon,
  TrendingUpIcon,
  AlertTriangleIcon,
  ShieldCheckIcon,
} from 'lucide-react';

interface HealthMetrics {
  totalEducators: number;
  educatorsWithRubricApplications: number;
  totalLearners: number;
  learnersWithEvidence: number;
  learnersWithProofBundles: number;
  totalEvidenceRecords: number;
  totalGrowthEvents: number;
  totalRubricApplications: number;
  averageEvidencePerLearner: number;
  proofVerificationRate: number;
}

function healthScore(metrics: HealthMetrics): { score: number; label: string; color: string } {
  let score = 0;

  // Educator adoption (30 pts)
  if (metrics.totalEducators > 0) {
    score += Math.min(30, (metrics.educatorsWithRubricApplications / metrics.totalEducators) * 30);
  }

  // Evidence coverage (25 pts)
  if (metrics.totalLearners > 0) {
    score += Math.min(25, (metrics.learnersWithEvidence / metrics.totalLearners) * 25);
  }

  // Proof verification (25 pts)
  score += Math.min(25, metrics.proofVerificationRate * 25);

  // Growth events (20 pts)
  if (metrics.totalLearners > 0) {
    const eventsPerLearner = metrics.totalGrowthEvents / metrics.totalLearners;
    score += Math.min(20, eventsPerLearner * 10);
  }

  const rounded = Math.round(score);
  if (rounded >= 80) return { score: rounded, label: 'Strong', color: 'text-green-700 bg-green-100' };
  if (rounded >= 50) return { score: rounded, label: 'Developing', color: 'text-amber-700 bg-amber-100' };
  return { score: rounded, label: 'Emerging', color: 'text-red-700 bg-red-100' };
}

export default function SiteImplementationHealthRenderer({ ctx }: CustomRouteRendererProps) {
  const siteId = ctx.profile?.siteIds?.[0] || ctx.profile?.activeSiteId || '';
  const [metrics, setMetrics] = useState<HealthMetrics | null>(null);
  const [siteName, setSiteName] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadMetrics = useCallback(async () => {
    if (!siteId) return;
    setLoading(true);
    try {
      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { loadE2EWorkflowRecords } = await import('@/src/testing/e2e/fakeWebBackend');
        const result = await loadE2EWorkflowRecords({ ...ctx, routePath: '/site/dashboard' });
        const siteRecord = result.records[0];
        setSiteName(siteRecord?.title ?? '');
        setMetrics({
          totalEducators: 0,
          educatorsWithRubricApplications: 0,
          totalLearners: 0,
          learnersWithEvidence: 0,
          learnersWithProofBundles: 0,
          totalEvidenceRecords: 0,
          totalGrowthEvents: 0,
          totalRubricApplications: 0,
          averageEvidencePerLearner: 0,
          proofVerificationRate: 0,
        });
        return;
      }

      const [
        educatorsSnap,
        learnersSnap,
        rubricAppsSnap,
        evidenceSnap,
        growthSnap,
      ] = await Promise.all([
        getDocs(query(collection(firestore, 'users'), where('siteIds', 'array-contains', siteId), where('role', '==', 'educator'))),
        getDocs(query(collection(firestore, 'users'), where('siteIds', 'array-contains', siteId), where('role', '==', 'learner'))),
        getDocs(query(collection(firestore, 'rubricApplications'), where('siteId', '==', siteId))),
        getDocs(query(collection(firestore, 'evidenceRecords'), where('siteId', '==', siteId))),
        getDocs(query(collection(firestore, 'capabilityGrowthEvents'), where('siteId', '==', siteId))),
      ]);

      const educatorIds = new Set(educatorsSnap.docs.map((d) => d.id));
      const learnerIds = new Set(learnersSnap.docs.map((d) => d.id));

      // Proof bundles don't have siteId — batch-query by site learner IDs (max 30 per 'in' query)
      const learnerIdArr = Array.from(learnerIds);
      const proofDocs: FirebaseFirestore.DocumentData[] = [];
      for (let i = 0; i < learnerIdArr.length; i += 30) {
        const batch = learnerIdArr.slice(i, i + 30);
        const snap = await getDocs(
          query(collection(firestore, 'proofOfLearningBundles'), where('learnerId', 'in', batch)),
        );
        snap.docs.forEach((d) => proofDocs.push(d.data()));
      }

      // Educators who've applied rubrics
      const educatorsWithRubrics = new Set<string>();
      rubricAppsSnap.docs.forEach((d) => {
        const educatorId = d.data().educatorId as string;
        if (educatorId && educatorIds.has(educatorId)) {
          educatorsWithRubrics.add(educatorId);
        }
      });

      // Learners with evidence
      const learnersWithEvidence = new Set<string>();
      evidenceSnap.docs.forEach((d) => {
        const lid = d.data().learnerId as string;
        if (lid && learnerIds.has(lid)) learnersWithEvidence.add(lid);
      });

      // Learners with proof bundles
      const learnersWithProof = new Set<string>();
      let verifiedProofs = 0;
      proofDocs.forEach((data) => {
        const lid = data.learnerId as string;
        if (lid) learnersWithProof.add(lid);
        if (data.verificationStatus === 'verified') verifiedProofs++;
      });

      const totalLearners = learnerIds.size;
      const totalEvidence = evidenceSnap.size;
      const totalProof = proofDocs.length;

      setMetrics({
        totalEducators: educatorIds.size,
        educatorsWithRubricApplications: educatorsWithRubrics.size,
        totalLearners,
        learnersWithEvidence: learnersWithEvidence.size,
        learnersWithProofBundles: learnersWithProof.size,
        totalEvidenceRecords: totalEvidence,
        totalGrowthEvents: growthSnap.size,
        totalRubricApplications: rubricAppsSnap.size,
        averageEvidencePerLearner: totalLearners > 0 ? totalEvidence / totalLearners : 0,
        proofVerificationRate: totalProof > 0 ? verifiedProofs / totalProof : 0,
      });
    } catch (err) {
      console.error('Failed to load health metrics:', err);
      setError('Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [siteId, ctx]);

  useEffect(() => {
    loadMetrics();
  }, [loadMetrics]);

  if (!metrics) {
    return (
      <div className="space-y-6">
        {error && <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error}</div>}
        <div className="flex items-center gap-3">
          <ActivityIcon className="h-7 w-7 text-indigo-600" />
          <div>
            {siteName && <p className="text-sm font-semibold text-indigo-700">{siteName}</p>}
            <h2 className="text-xl font-bold text-gray-900">Implementation Health</h2>
            <p className="text-sm text-gray-500">Evidence chain adoption and quality metrics.</p>
          </div>
        </div>
        {loading
          ? <div className="p-6 text-center text-gray-500">Loading implementation health...</div>
          : !error && <div className="p-6 text-center text-gray-400">No data available for this site.</div>}
      </div>
    );
  }

  const health = healthScore(metrics);
  const educatorAdoption = metrics.totalEducators > 0
    ? Math.round((metrics.educatorsWithRubricApplications / metrics.totalEducators) * 100)
    : 0;
  const evidenceCoverage = metrics.totalLearners > 0
    ? Math.round((metrics.learnersWithEvidence / metrics.totalLearners) * 100)
    : 0;
  const proofAdoption = metrics.totalLearners > 0
    ? Math.round((metrics.learnersWithProofBundles / metrics.totalLearners) * 100)
    : 0;

  return (
    <div className="space-y-6">
      {error && <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error}</div>}
      {/* Header with overall health score */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <ActivityIcon className="h-7 w-7 text-indigo-600" />
          <div>
            {siteName && <p className="text-sm font-semibold text-indigo-700">{siteName}</p>}
            <h2 className="text-xl font-bold text-gray-900">Implementation Health</h2>
            <p className="text-sm text-gray-500">Evidence chain adoption and quality metrics.</p>
          </div>
        </div>
        <span className={`rounded-full px-4 py-1 text-lg font-bold ${health.color}`}>
          {health.score}/100 — {health.label}
        </span>
      </div>

      {/* KPI grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-1">
            <UsersIcon className="h-4 w-4 text-blue-500" />
            <p className="text-xs text-gray-500">Educator Adoption</p>
          </div>
          <p className="text-2xl font-bold text-gray-900">{educatorAdoption}%</p>
          <p className="text-xs text-gray-400">
            {metrics.educatorsWithRubricApplications}/{metrics.totalEducators} using rubrics
          </p>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-1">
            <CheckCircleIcon className="h-4 w-4 text-green-500" />
            <p className="text-xs text-gray-500">Evidence Coverage</p>
          </div>
          <p className="text-2xl font-bold text-gray-900">{evidenceCoverage}%</p>
          <p className="text-xs text-gray-400">
            {metrics.learnersWithEvidence}/{metrics.totalLearners} learners with evidence
          </p>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-1">
            <ShieldCheckIcon className="h-4 w-4 text-purple-500" />
            <p className="text-xs text-gray-500">Proof Adoption</p>
          </div>
          <p className="text-2xl font-bold text-gray-900">{proofAdoption}%</p>
          <p className="text-xs text-gray-400">
            {metrics.learnersWithProofBundles}/{metrics.totalLearners} with proof bundles
          </p>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-1">
            <TrendingUpIcon className="h-4 w-4 text-amber-500" />
            <p className="text-xs text-gray-500">Growth Velocity</p>
          </div>
          <p className="text-2xl font-bold text-gray-900">{metrics.totalGrowthEvents}</p>
          <p className="text-xs text-gray-400">growth events recorded</p>
        </div>
      </div>

      {/* Detail rows */}
      <div className="bg-white border border-gray-200 rounded-lg divide-y divide-gray-100">
        <div className="p-4 flex justify-between items-center">
          <span className="text-sm text-gray-700">Total evidence records</span>
          <span className="text-sm font-medium text-gray-900">{metrics.totalEvidenceRecords}</span>
        </div>
        <div className="p-4 flex justify-between items-center">
          <span className="text-sm text-gray-700">Average evidence per learner</span>
          <span className="text-sm font-medium text-gray-900">
            {metrics.averageEvidencePerLearner.toFixed(1)}
          </span>
        </div>
        <div className="p-4 flex justify-between items-center">
          <span className="text-sm text-gray-700">Rubric applications</span>
          <span className="text-sm font-medium text-gray-900">{metrics.totalRubricApplications}</span>
        </div>
        <div className="p-4 flex justify-between items-center">
          <span className="text-sm text-gray-700">Proof verification rate</span>
          <span className="text-sm font-medium text-gray-900">
            {Math.round(metrics.proofVerificationRate * 100)}%
          </span>
        </div>
      </div>

      {/* Alerts */}
      {educatorAdoption < 50 && (
        <div className="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-lg p-4">
          <AlertTriangleIcon className="h-5 w-5 text-amber-600 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-amber-800">Low educator adoption</p>
            <p className="text-xs text-amber-700">
              Less than half of educators have applied rubrics. Consider scheduling rubric training.
            </p>
          </div>
        </div>
      )}
      {evidenceCoverage < 50 && (
        <div className="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-lg p-4">
          <AlertTriangleIcon className="h-5 w-5 text-amber-600 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-amber-800">Evidence gap</p>
            <p className="text-xs text-amber-700">
              Less than half of learners have evidence records. Ensure sessions are capturing observations.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
