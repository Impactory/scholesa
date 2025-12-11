import { useEffect, useState } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { pillarsCollection } from '@/src/lib/firestore/collections';
import { Card } from '@/src/components/ui/Card';

export function HqDashboard() {
  const [pillars, setPillars] = useState<any[]>([]);

  useEffect(() => {
    // Mocking pillars data for now as seeding script is separate
    // In a real app, this would come from firestore
    setPillars([
      { id: 'FUTURE_SKILLS', name: 'Future Skills', description: 'AI, coding, robotics, research' },
      { id: 'LEADERSHIP_AGENCY', name: 'Leadership & Agency', description: 'Self-direction, leading others' },
      { id: 'IMPACT_INNOVATION', name: 'Impact & Innovation', description: 'Creating value, solving problems' },
    ]);
  }, []);

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">HQ Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Total Students</h2>
          <p className="text-3xl font-bold text-blue-600">1,245</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Active Studios</h2>
          <p className="text-3xl font-bold text-green-600">12</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Revenue (MoM)</h2>
          <p className="text-3xl font-bold text-purple-600">+15%</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-lg font-semibold mb-2">Alerts</h2>
          <p className="text-3xl font-bold text-red-600">2</p>
        </Card>
      </div>

      <h2 className="text-2xl font-bold mb-4">The 3 Pillars</h2>
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
