export default function Features() {
  return (
    <div className="py-20">
      <header className="text-center max-w-3xl mx-auto px-4">
        <h1 className="text-5xl font-bold mb-4">Why restaurants choose Hands</h1>
        <p className="text-white/80">Daily checklists, documents & training, team messaging, and live insights. No more missed tasks.</p>
      </header>

      <div className="max-w-6xl mx-auto px-4 space-y-16 mt-16">
        {/* Checklists */}
        <div className="grid md:grid-cols-2 gap-10 items-center">
          <div className="bg-surface text-white p-10 rounded-2xl shadow">[Checklist screenshot]</div>
          <div>
            <h2 className="text-3xl font-semibold mb-3">Daily Checklists</h2>
            <ul className="text-white/80 list-disc list-inside space-y-2">
              <li>Ordered tasks with required photos</li>
              <li>Audit history and missed task insights</li>
              <li>Notes and reasons for incomplete items</li>
            </ul>
          </div>
        </div>

        {/* Documents */}
        <div className="grid md:grid-cols-2 gap-10 items-center">
          <div className="order-2 md:order-1">
            <h2 className="text-3xl font-semibold mb-3">Documents & Training</h2>
            <ul className="text-white/80 list-disc list-inside space-y-2">
              <li>Centralize SOPs, recipes, and procedures</li>
              <li>Keep everyone on the latest version</li>
              <li>Available on mobile — no binders needed</li>
            </ul>
          </div>
          <div className="order-1 md:order-2 bg-surface text-white p-10 rounded-2xl shadow">[Documents screenshot]</div>
        </div>

        {/* Messaging */}
        <div className="grid md:grid-cols-2 gap-10 items-center">
          <div className="bg-surface text-white p-10 rounded-2xl shadow">[Messaging screenshot]</div>
          <div>
            <h2 className="text-3xl font-semibold mb-3">Team Messaging</h2>
            <ul className="text-white/80 list-disc list-inside space-y-2">
              <li>Notify all staff, specific roles, or locations</li>
              <li>Push notifications to devices (if enabled)</li>
              <li>Keep everyone aligned on updates and standards</li>
            </ul>
          </div>
        </div>

        {/* Insights */}
        <div className="grid md:grid-cols-2 gap-10 items-center">
          <div className="order-2 md:order-1">
            <h2 className="text-3xl font-semibold mb-3">Insights & Analytics</h2>
            <ul className="text-white/80 list-disc list-inside space-y-2">
              <li>See real-time completion and misses</li>
              <li>Identify coaching opportunities before peak hours</li>
              <li>Compare trends across locations</li>
            </ul>
          </div>
          <div className="order-1 md:order-2 bg-surface text-white p-10 rounded-2xl shadow">[Insights screenshot]</div>
        </div>
      </div>
    </div>
  )
}
