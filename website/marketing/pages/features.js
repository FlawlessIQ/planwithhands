import PhoneMockup from '../components/PhoneMockup'
import SEO from '../components/SEO'

export default function Features() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Restaurant Management Software Features",
    "description": "Comprehensive features for restaurant operations: digital checklists, team messaging, training documents, and real-time analytics.",
    "url": "https://planwithhands.com/features/",
    "mainEntity": {
      "@type": "SoftwareApplication",
      "name": "Plan With Hands",
      "featureList": [
        "Daily Digital Checklists with Photo Requirements",
        "Team Messaging with Push Notifications", 
        "Training Documents and Materials Library",
        "Real-time Analytics and Missed Task Insights",
        "Multi-location Management Dashboard",
        "Audit History and Compliance Tracking"
      ]
    }
  };

  return (
    <>
      <SEO
        title="Features - Plan With Hands | Restaurant Management Software Tools"
        description="Discover powerful features for restaurant operations: digital checklists, team messaging, training documents, real-time analytics, and multi-location management tools."
        canonical="https://planwithhands.com/features/"
        structuredData={structuredData}
        keywords="restaurant management features, digital checklists, team messaging, training documents, restaurant analytics, multi-location management, operational tools"
      />
  return (
    <div className="py-20">
      <header className="text-center max-w-3xl mx-auto px-4">
        <h1 className="text-5xl font-bold mb-4">Why restaurants choose Hands</h1>
        <p className="text-white/80">Daily checklists, documents & training, team messaging, and live insights. No more missed tasks.</p>
      </header>

      <div className="max-w-6xl mx-auto px-4 space-y-20 mt-16">
        {/* Checklists */}
        <div className="grid lg:grid-cols-3 gap-8 items-center">
          <PhoneMockup 
            src="/images/Checklist.png" 
            alt="Daily Checklists feature screenshot"
            className="max-w-[200px] mx-auto lg:mx-0"
          />
          <div className="lg:col-span-2 space-y-4">
            <h2 className="text-3xl lg:text-4xl font-semibold text-white">Daily Checklists</h2>
            <p className="text-white/70 text-lg leading-relaxed">
              Keep your team on track with structured daily tasks and accountability.
            </p>
            <ul className="text-white/80 space-y-3">
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Ordered tasks with required photos</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Audit history and missed task insights</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Notes and reasons for incomplete items</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Documents */}
        <div className="grid lg:grid-cols-3 gap-8 items-center">
          <div className="lg:col-span-2 space-y-4 order-2 lg:order-1">
            <h2 className="text-3xl lg:text-4xl font-semibold text-white">Documents & Training</h2>
            <p className="text-white/70 text-lg leading-relaxed">
              Centralize all your operational knowledge and keep everyone aligned.
            </p>
            <ul className="text-white/80 space-y-3">
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Centralize SOPs, recipes, and procedures</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Keep everyone on the latest version</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Available on mobile — no binders needed</span>
              </li>
            </ul>
          </div>
          <PhoneMockup 
            src="/images/Training.png" 
            alt="Documents & Training feature screenshot"
            className="order-1 lg:order-2 max-w-[200px] mx-auto lg:mx-0"
          />
        </div>

        {/* Messaging */}
        <div className="grid lg:grid-cols-3 gap-8 items-center">
          <PhoneMockup 
            src="/images/Messages.png" 
            alt="Team Messaging feature screenshot"
            className="max-w-[200px] mx-auto lg:mx-0"
          />
          <div className="lg:col-span-2 space-y-4">
            <h2 className="text-3xl lg:text-4xl font-semibold text-white">Team Messaging</h2>
            <p className="text-white/70 text-lg leading-relaxed">
              Keep your entire team connected with instant updates and announcements.
            </p>
            <ul className="text-white/80 space-y-3">
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Notify all staff, specific roles, or locations</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Push notifications to devices (if enabled)</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Keep everyone aligned on updates and standards</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Insights */}
        <div className="grid lg:grid-cols-3 gap-8 items-center">
          <div className="lg:col-span-2 space-y-4 order-2 lg:order-1">
            <h2 className="text-3xl lg:text-4xl font-semibold text-white">Insights & Analytics</h2>
            <p className="text-white/70 text-lg leading-relaxed">
              Make data-driven decisions with real-time operational insights.
            </p>
            <ul className="text-white/80 space-y-3">
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>See real-time completion and misses</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Identify coaching opportunities before peak hours</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-2 h-2 bg-accent rounded-full mt-2 flex-shrink-0"></div>
                <span>Compare trends across locations</span>
              </li>
            </ul>
          </div>
          <PhoneMockup 
            src="/images/Metrics.png" 
            alt="Insights & Analytics feature screenshot"
            className="order-1 lg:order-2 max-w-[200px] mx-auto lg:mx-0"
          />
        </div>
      </div>
    </div>
    </>
  )
}
