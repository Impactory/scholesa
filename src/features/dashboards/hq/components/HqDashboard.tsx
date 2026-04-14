'use client';

import { useEffect, useState } from 'react';
import { Card } from '@/src/components/ui/Card';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';

interface Pillar {
  id: string;
  name: string;
  description: string;
}

export function HqDashboard() {
  const [pillars, setPillars] = useState<Pillar[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalLearners: 0,
    activeSites: 0,
    openAlerts: 0,
  });

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      setLoading(true);
      try {
        const [pillarsSnap, learnersSnap, sitesSnap, alertsSnap] = await Promise.all([
          getDocs(query(collection(firestore, 'pillars'))),
          getDocs(query(collection(firestore, 'users'), where('role', '==', 'learner'))),
          getDocs(query(collection(firestore, 'sites'))),
          getDocs(query(collection(firestore, 'alerts'), where('status', '==', 'open'))),
        ]);

        if (!isMounted) return;

        const pillarRows = pillarsSnap.docs.map((pillarDoc) => {
          const data = pillarDoc.data() as Record<string, unknown>;
          return {
            id: pillarDoc.id,
            name: typeof data.name === 'string' ? data.name : pillarDoc.id,
            description: typeof data.description === 'string' ? data.description : '',
          };
        });

        setPillars(pillarRows);
        setStats({
          totalLearners: learnersSnap.size,
          activeSites: sitesSnap.size,
          openAlerts: alertsSnap.size,
        });
      } catch (error) {
        console.error('Failed to load HQ dashboard data', error);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    void load();
    return () => {
      isMounted = false;
    };
  }, []);

  if (loading) {
    return (
      <div className="p-8">
        <h1 className="text-3xl font-bold mb-6">HQ Dashboard</h1>
        <div className="text-sm text-gray-500">Loading dashboard…</div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">HQ Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Total Students</h2>
          <p className="text-3xl font-bold text-blue-600">{stats.totalLearners}</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Active Studios</h2>
          <p className="text-3xl font-bold text-green-600">{stats.activeSites}</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Revenue (MoM)</h2>
          <p className="text-3xl font-bold text-purple-600">—</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Alerts</h2>
          <p className="text-3xl font-bold text-red-600">{stats.openAlerts}</p>
        </Card>
      </div>

      <h2 className="text-2xl font-bold mb-4">Legacy Curriculum Families</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {pillars.map((pillar) => (
          <Card key={pillar.id} className="p-6">
            <h3 className="text-xl font-semibold mb-2">{pillar.name}</h3>
            <p className="text-gray-600">{pillar.description}</p>
          </Card>
        ))}
      </div>
    </div>
  );
}
