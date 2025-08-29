import Link from 'next/link'
import Image from 'next/image'

export default function Home() {
  return (
    <div>
      {/* Hero Section */}
      <section className="relative px-4 py-20 md:py-32 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-black via-primary to-surface"></div>
        <div className="relative max-w-6xl mx-auto text-center">
          <div className="mb-8">
            <span className="inline-block px-4 py-2 bg-accent/10 text-accent rounded-full text-sm font-medium mb-6">
              Trusted by restaurant operators
            </span>
          </div>
          <h1 className="text-4xl md:text-7xl font-bold mb-6 leading-tight">
            Every shift runs
            <span className="block text-accent">on rails</span>
          </h1>
          <p className="text-xl md:text-2xl text-white/80 mb-10 max-w-4xl mx-auto leading-relaxed">
            Transform chaotic operations into consistent excellence with checklists, 
            documents, and real-time insights that scale across your entire business.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-4 mb-12">
            <Link href="/pricing" className="px-8 py-4 bg-accent text-primary font-semibold rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-lg">
              Start free trial
            </Link>
            <Link href="/how-it-works" className="px-8 py-4 bg-white/10 text-white rounded-2xl hover:bg-white/20 transition-all duration-300 text-lg backdrop-blur">
              Watch demo
            </Link>
          </div>
          <div className="flex flex-wrap justify-center gap-6 text-white/60 text-sm">
            <div className="flex items-center gap-2">
              <svg className="w-5 h-5 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              No hardware needed
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-5 h-5 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              Setup in minutes
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-5 h-5 text-accent" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              Works on any device
            </div>
          </div>
        </div>
      </section>

      {/* Hero Image/Demo */}
      <section className="px-4 -mt-10 mb-20">
        <div className="max-w-5xl mx-auto">
          <div className="bg-surface rounded-3xl p-8 shadow-2xl border border-white/10">
            <div className="bg-primary rounded-2xl aspect-video flex items-center justify-center">
              <div className="text-center">
                <div className="w-20 h-20 mx-auto mb-4 bg-accent/20 rounded-2xl flex items-center justify-center">
                  <svg className="w-10 h-10 text-accent" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
                  </svg>
                </div>
                <p className="text-white/60">Interactive Product Demo</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Core Benefits */}
      <section className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-5xl font-bold mb-6">Why teams choose Hands</h2>
            <p className="text-xl text-white/70 max-w-3xl mx-auto">
              Stop playing catch-up. Create predictable operations that work every single shift.
            </p>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                icon: (
                  <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                ),
                title: 'Bulletproof Consistency',
                description: 'Every location follows the same standards. No exceptions, no missed steps, no surprises.',
              },
              {
                icon: (
                  <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                    <path fillRule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2V3a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2h1zm0 5V9a1 1 0 011-1h1a1 1 0 110 2v1a1 1 0 11-2 0z" clipRule="evenodd" />
                  </svg>
                ),
                title: 'Real-Time Visibility',
                description: 'See what\'s happening across all locations instantly. Spot issues before they become problems.',
              },
              {
                icon: (
                  <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z" clipRule="evenodd" />
                    <path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z" />
                  </svg>
                ),
                title: 'Effortless Scaling',
                description: 'Add locations without adding chaos. Your systems grow with you, not against you.',
              }
            ].map((benefit, index) => (
              <div key={index} className="bg-surface text-white p-8 rounded-3xl hover:bg-white/5 transition-all duration-300 group">
                <div className="w-16 h-16 bg-accent/20 rounded-2xl flex items-center justify-center text-accent mb-6 group-hover:scale-110 transition-transform duration-300">
                  {benefit.icon}
                </div>
                <h3 className="text-xl font-semibold mb-4">{benefit.title}</h3>
                <p className="text-white/70 leading-relaxed">{benefit.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Problem/Solution */}
      <section className="py-20 px-4 bg-gradient-to-r from-primary to-surface">
        <div className="max-w-6xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-16 items-center">
            <div>
              <h2 className="text-3xl md:text-4xl font-bold mb-6 text-white">
                Stop fighting fires.<br />Start preventing them.
              </h2>
              <div className="space-y-6">
                <div className="flex gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80">Tasks get skipped when shifts get busy</p>
                </div>
                <div className="flex gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80">Different standards across locations</p>
                </div>
                <div className="flex gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80">No visibility into what's actually happening</p>
                </div>
                <div className="flex gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80">Training takes forever and doesn't stick</p>
                </div>
              </div>
            </div>
            <div className="bg-black/40 rounded-3xl p-8 backdrop-blur">
              <h3 className="text-2xl font-semibold mb-6 text-white">With Hands, you get:</h3>
              <div className="space-y-4">
                <div className="flex gap-4 items-center">
                  <svg className="w-6 h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white">Foolproof checklists that can't be skipped</p>
                </div>
                <div className="flex gap-4 items-center">
                  <svg className="w-6 h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white">Identical standards everywhere, automatically</p>
                </div>
                <div className="flex gap-4 items-center">
                  <svg className="w-6 h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white">Live dashboard with real completion data</p>
                </div>
                <div className="flex gap-4 items-center">
                  <svg className="w-6 h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white">Built-in docs and training materials</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Social Proof */}
      <section className="py-20 px-4">
        <div className="max-w-6xl mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-12">Loved by operators like you</h2>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                quote: "Hands eliminated 90% of our missed opening tasks. Every location now opens the same way, every single day.",
                name: "Sarah Chen",
                title: "Regional Manager, 8 locations"
              },
              {
                quote: "We went from spending hours training to having new staff fully productive in their first week. Game changer.",
                name: "Marcus Rodriguez", 
                title: "Owner, Fast-casual chain"
              },
              {
                quote: "Finally have eyes on what's happening across all our stores. Caught three major issues before customers did.",
                name: "Jennifer Kim",
                title: "Operations Director"
              }
            ].map((testimonial, index) => (
              <div key={index} className="bg-surface p-8 rounded-3xl">
                <div className="text-accent mb-4">
                  {"★".repeat(5)}
                </div>
                <p className="text-white/90 italic mb-6 leading-relaxed">"{testimonial.quote}"</p>
                <div>
                  <p className="font-semibold text-white">{testimonial.name}</p>
                  <p className="text-white/60 text-sm">{testimonial.title}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 px-4 bg-gradient-to-r from-accent/10 to-primary">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl md:text-5xl font-bold mb-6">Stop stressing about operations</h2>
          <p className="text-xl text-white/80 mb-10 max-w-2xl mx-auto">
            Transform chaotic shifts into predictable success. Join hundreds of operators 
            who've eliminated missed tasks and inconsistent standards for good.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-8">
            <Link href="/pricing" className="px-8 py-4 bg-accent text-primary font-semibold rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-lg">
              Start free trial
            </Link>
            <Link href="/contact" className="px-8 py-4 border-2 border-white/20 text-white rounded-2xl hover:bg-white/10 transition-all duration-300 text-lg">
              Book a demo
            </Link>
          </div>
          <p className="text-white/60 text-sm">
            Free 14-day trial • Cancel anytime • No setup fees
          </p>
        </div>
      </section>
    </div>
  )
}
