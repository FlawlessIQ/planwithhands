import SEO from '../components/SEO'

export default function About() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "Plan With Hands",
    "alternateName": "Hands",
    "url": "https://planwithhands.com",
    "logo": {
      "@type": "ImageObject",
      "url": "https://planwithhands.com/images/favicon-192.png"
    },
    "description": "Restaurant operations management software company focused on digital checklists, team communication, and operational excellence.",
    "foundingDate": "2024",
    "industry": "Restaurant Technology",
    "mission": "Make restaurant operations effortless, consistent, and scalable so every guest gets the same great experience.",
    "contactPoint": {
      "@type": "ContactPoint",
      "contactType": "customer service",
      "url": "https://planwithhands.com/contact"
    }
  };

  return (
    <>
      <SEO
        title="About Plan With Hands | Restaurant Operations Management Company"
        description="Learn about Plan With Hands - restaurant operations management software built by operators for operators. Digital checklists, team communication, and operational excellence tools."
        canonical="https://planwithhands.com/about/"
        structuredData={structuredData}
        keywords="about plan with hands, restaurant management company, restaurant operations software company, digital checklist company, restaurant technology"
      />
    <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 sm:py-16 md:py-20 space-y-12 sm:space-y-16 md:space-y-20">
      {/* Hero */}
      <section className="text-center max-w-3xl mx-auto">
        <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4 sm:mb-6 leading-tight">About Plan With Hands</h1>
        <p className="text-white/80 text-base sm:text-lg leading-relaxed">
          We're on a mission to make restaurant operations effortless, consistent, and scalable —
          so you get hands on every task and every guest gets the same great experience.
        </p>
      </section>

      {/* Story */}
      <section className="grid grid-cols-1 md:grid-cols-2 gap-8 sm:gap-12 items-center">
        <div className="bg-surface text-white p-6 sm:p-8 md:p-10 rounded-xl sm:rounded-2xl shadow-xl">
          <h2 className="text-2xl sm:text-3xl font-semibold mb-3 sm:mb-4">Where it started</h2>
          <p className="mb-3 sm:mb-4 text-white/80 text-sm sm:text-base leading-relaxed">
            Hands was born out of real-world challenges: missed tasks, inconsistent standards,
            and rushed training. We built a simple tool that brings checklists, documents, and
            live insights into one place.
          </p>
          <p className="text-white/80 text-sm sm:text-base leading-relaxed">
            Whether you run one location or fifty, Hands helps your team deliver consistently.
          </p>
        </div>
        <div className="rounded-xl sm:rounded-2xl bg-surface p-8 sm:p-12 flex items-center justify-center">
          <div className="text-center">
            <div className="w-20 h-20 sm:w-24 sm:h-24 mx-auto mb-4 sm:mb-6 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-10 h-10 sm:w-12 sm:h-12 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-lg sm:text-xl font-semibold text-white mb-2">Built by operators</h3>
            <p className="text-white/60 text-sm sm:text-base">For operators who understand the daily challenges of restaurant management</p>
          </div>
        </div>
      </section>

      {/* Values */}
      <section>
        <h2 className="text-2xl sm:text-3xl font-semibold text-center mb-8 sm:mb-12">What we value</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 sm:gap-8">
          <div className="bg-surface text-white p-6 sm:p-8 rounded-xl sm:rounded-2xl shadow">
            <div className="w-12 h-12 sm:w-16 sm:h-16 mx-auto mb-3 sm:mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-6 h-6 sm:w-8 sm:h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2 text-center">Simplicity</h3>
            <p className="text-white/80 text-center text-sm sm:text-base">Intuitive tools that help staff focus on what matters.</p>
          </div>
          <div className="bg-surface text-white p-6 sm:p-8 rounded-xl sm:rounded-2xl shadow">
            <div className="w-12 h-12 sm:w-16 sm:h-16 mx-auto mb-3 sm:mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-6 h-6 sm:w-8 sm:h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4 2a2 2 0 00-2 2v11a3 3 0 106 0V4a2 2 0 00-2-2H4zm1 14a1 1 0 100-2 1 1 0 000 2zm5-1.757l4.9-4.9a2 2 0 000-2.828L13.485 5.1a2 2 0 00-2.828 0L10 5.757v8.486zM16 18H9.071l6-6H16a2 2 0 012 2v2a2 2 0 01-2 2z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2 text-center">Consistency</h3>
            <p className="text-white/80 text-center text-sm sm:text-base">Standards that scale across shifts and locations.</p>
          </div>
          <div className="bg-surface text-white p-6 sm:p-8 rounded-xl sm:rounded-2xl shadow">
            <div className="w-12 h-12 sm:w-16 sm:h-16 mx-auto mb-3 sm:mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-6 h-6 sm:w-8 sm:h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" />
              </svg>
            </div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2 text-center">Scalability</h3>
            <p className="text-white/80 text-center text-sm sm:text-base">From one store to many, keep everyone aligned.</p>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="text-center py-12 sm:py-16 bg-primary text-white rounded-xl sm:rounded-2xl px-4 sm:px-6">
        <h2 className="text-2xl sm:text-3xl font-bold mb-3 sm:mb-4 leading-tight">Join us in reshaping operations</h2>
        <p className="mb-6 sm:mb-8 text-white/80 text-sm sm:text-base max-w-2xl mx-auto">Hands helps teams save time, reduce stress, and deliver better shifts.</p>
        <a href="/app-signup?src=about_cta" className="px-5 sm:px-6 py-3 bg-accent text-primary font-semibold rounded-xl shadow-lg hover:opacity-90 transition-colors duration-200 text-sm sm:text-base min-h-[44px] inline-flex items-center justify-center">Start 14-day trial</a>
      </section>
    </div>
    </>
  )
}
