export default function About() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-20 space-y-20">
      {/* Hero */}
      <section className="text-center max-w-3xl mx-auto">
        <h1 className="text-5xl font-bold mb-6">About Plan With Hands</h1>
        <p className="text-white/80 text-lg">
          We're on a mission to make restaurant operations effortless, consistent, and scalable —
          so every shift runs on rails and every guest gets the same great experience.
        </p>
      </section>

      {/* Story */}
      <section className="grid md:grid-cols-2 gap-12 items-center">
        <div className="bg-surface text-white p-10 rounded-2xl shadow-xl">
          <h2 className="text-3xl font-semibold mb-4">Where it started</h2>
          <p className="mb-4 text-white/80">
            Hands was born out of real-world challenges: missed tasks, inconsistent standards,
            and rushed training. We built a simple tool that brings checklists, documents, and
            live insights into one place.
          </p>
          <p className="text-white/80">
            Whether you run one location or fifty, Hands helps your team deliver consistently.
          </p>
        </div>
        <div className="rounded-2xl bg-surface p-12 flex items-center justify-center">
          <div className="text-center">
            <div className="w-24 h-24 mx-auto mb-6 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-12 h-12 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold text-white mb-2">Built by operators</h3>
            <p className="text-white/60">For operators who understand the daily challenges of restaurant management</p>
          </div>
        </div>
      </section>

      {/* Values */}
      <section>
        <h2 className="text-3xl font-semibold text-center mb-12">What we value</h2>
        <div className="grid md:grid-cols-3 gap-8">
          <div className="bg-surface text-white p-8 rounded-2xl shadow">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-8 h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2 text-center">Simplicity</h3>
            <p className="text-white/80 text-center">Intuitive tools that help staff focus on what matters.</p>
          </div>
          <div className="bg-surface text-white p-8 rounded-2xl shadow">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-8 h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4 2a2 2 0 00-2 2v11a3 3 0 106 0V4a2 2 0 00-2-2H4zm1 14a1 1 0 100-2 1 1 0 000 2zm5-1.757l4.9-4.9a2 2 0 000-2.828L13.485 5.1a2 2 0 00-2.828 0L10 5.757v8.486zM16 18H9.071l6-6H16a2 2 0 012 2v2a2 2 0 01-2 2z" clipRule="evenodd" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2 text-center">Consistency</h3>
            <p className="text-white/80 text-center">Standards that scale across shifts and locations.</p>
          </div>
          <div className="bg-surface text-white p-8 rounded-2xl shadow">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-accent/20 flex items-center justify-center">
              <svg className="w-8 h-8 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2 text-center">Scalability</h3>
            <p className="text-white/80 text-center">From one store to many, keep everyone aligned.</p>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="text-center py-16 bg-primary text-white rounded-2xl">
        <h2 className="text-3xl font-bold mb-4">Join us in reshaping operations</h2>
        <p className="mb-8 text-white/80">Hands helps teams save time, reduce stress, and deliver better shifts.</p>
        <a href="/pricing" className="px-6 py-3 bg-accent text-primary font-semibold rounded-xl shadow-lg hover:opacity-90 transition-colors duration-200">Start free trial</a>
      </section>
    </div>
  )
}