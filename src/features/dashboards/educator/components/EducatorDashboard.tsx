export function EducatorDashboard() {
  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Educator Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Today's Classes</h2>
          <ul className="list-disc list-inside text-gray-600">
            <li>9:00 AM - Intro to AI</li>
            <li>11:00 AM - Python for Beginners</li>
            <li>2:00 PM - Robotics Lab</li>
          </ul>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Recent Submissions</h2>
          <p className="text-gray-600">5 new projects to review.</p>
        </div>
      </div>
    </div>
  );
}
