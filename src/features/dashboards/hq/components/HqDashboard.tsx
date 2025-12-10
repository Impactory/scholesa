export function HqDashboard() {
  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">HQ Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-2">Total Students</h2>
          <p className="text-3xl font-bold text-blue-600">1,245</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-2">Active Studios</h2>
          <p className="text-3xl font-bold text-green-600">12</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-2">Revenue (MoM)</h2>
          <p className="text-3xl font-bold text-purple-600">+15%</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-2">Alerts</h2>
          <p className="text-3xl font-bold text-red-600">2</p>
        </div>
      </div>
    </div>
  );
}
