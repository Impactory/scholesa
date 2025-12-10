export function LearnerDashboard() {
  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Learner Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Current Mission</h2>
          <p className="text-gray-600">Robotics 101: Building Your First Bot</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Progress</h2>
          <div className="w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700">
            <div className="bg-blue-600 h-2.5 rounded-full" style={{ width: '45%' }}></div>
          </div>
          <p className="text-sm text-gray-500 mt-2">45% Complete</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">AI Coach</h2>
          <p className="text-gray-600">"Great job on the last quiz! Keep it up!"</p>
        </div>
      </div>
    </div>
  );
}
