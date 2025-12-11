import { Card } from '@/src/components/ui/Card';

export function LearnerDashboard() {
  // Mock data for pillar scores
  const pillarScores = {
    FUTURE_SKILLS: 75,
    LEADERSHIP_AGENCY: 60,
    IMPACT_INNOVATION: 40,
  };

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Learner Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">Current Mission</h2>
          <p className="text-gray-600">Robotics 101: Building Your First Bot</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">Overall Progress</h2>
          <div className="w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700">
            <div className="bg-blue-600 h-2.5 rounded-full" style={{ width: '58%' }}></div>
          </div>
          <p className="text-sm text-gray-500 mt-2">58% Complete</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">AI Coach</h2>
          <p className="text-gray-600">&quot;Great job on the last quiz! Focus on &apos;Impact &amp; Innovation&apos; next.&quot;</p>
        </Card>
      </div>

      <h2 className="text-2xl font-bold mb-4">My Pillars</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Future Skills</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-green-500 h-2.5 rounded-full" style={{ width: `${pillarScores.FUTURE_SKILLS}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.FUTURE_SKILLS}%</p>
        </Card>
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Leadership & Agency</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-indigo-500 h-2.5 rounded-full" style={{ width: `${pillarScores.LEADERSHIP_AGENCY}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.LEADERSHIP_AGENCY}%</p>
        </Card>
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Impact & Innovation</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-purple-500 h-2.5 rounded-full" style={{ width: `${pillarScores.IMPACT_INNOVATION}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.IMPACT_INNOVATION}%</p>
        </Card>
      </div>
    </div>
  );
}
