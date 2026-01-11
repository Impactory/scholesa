export function ParentDashboard() {
  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Parent Dashboard</h1>
      <div className="bg-white p-6 rounded-lg shadow mb-6">
        <h2 className="text-xl font-semibold mb-2">Student Overview</h2>
        <p className="text-gray-600">Alex is doing great! They recently completed the &quot;Robotics 101&quot; module.</p>
      </div>
      <div className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-xl font-semibold mb-2">Upcoming Events</h2>
        <p className="text-gray-600">Science Fair - Next Friday at 2 PM.</p>
      </div>
    </div>
  );
}
