import Link from 'next/link'
import Image from 'next/image'
import Head from 'next/head'

export default function Home() {
  const signupUrl = '/app-signup';
  return (
    <>
      <Head>
        <title>Plan With Hands - Restaurant Operations Management Software</title>
        <meta name="description" content="Transform restaurant operations with Hands - digital checklists, team messaging, training documents, and real-time insights. No hardware needed. Start your free trial today." />
        <meta property="og:title" content="Plan With Hands - Restaurant Operations Management Software" />
        <meta property="og:description" content="Transform restaurant operations with Hands - digital checklists, team messaging, training documents, and real-time insights. No hardware needed." />
        <link rel="canonical" href="https://planwithhands.com/" />
        
        {/* Structured Data for Restaurant Software */}
        <script type="application/ld+json">
          {`
            {
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              "name": "Plan With Hands",
              "description": "Restaurant operations management software with digital checklists, team messaging, and real-time insights",
              "url": "https://planwithhands.com",
              "applicationCategory": "Restaurant Management Software",
              "operatingSystem": "Web, iOS, Android",
              "offers": {
                "@type": "Offer",
                "price": "69.99",
                "priceCurrency": "USD",
                "priceSpecification": {
                  "@type": "UnitPriceSpecification",
                  "price": "69.99",
                  "priceCurrency": "USD",
                  "unitText": "MONTH"
                }
              },
              "provider": {
                "@type": "Organization",
                "name": "Plan With Hands",
                "url": "https://planwithhands.com"
              }
            }
          `}
        </script>
      </Head>
      <div>
      {/* Hero Section */}
      <section className="relative px-4 sm:px-6 py-16 sm:py-20 md:py-32 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-black via-primary to-surface"></div>
        <div className="relative max-w-6xl mx-auto text-center">
          <div className="mb-6 sm:mb-8">
            <span className="inline-block px-3 sm:px-4 py-2 bg-accent/10 text-accent rounded-full text-xs sm:text-sm font-medium mb-4 sm:mb-6">
              Trusted by restaurant operators
            </span>
          </div>
          <h1 className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-bold mb-4 sm:mb-6 leading-tight">
            Get hands on
            <span className="block text-accent">every task</span>
          </h1>
          <p className="text-lg sm:text-xl md:text-2xl text-white/80 mb-8 sm:mb-10 max-w-4xl mx-auto leading-relaxed px-2">
            Transform chaotic operations into consistent excellence with checklists, 
            documents, and real-time insights that scale across your entire business.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-3 sm:gap-4 mb-8 sm:mb-12 px-4">
            <Link href="/pricing" className="px-6 sm:px-8 py-3 sm:py-4 bg-accent text-primary font-semibold rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-base sm:text-lg">
              Start free trial
            </Link>
            <button
              onClick={() => {
                if (typeof document !== 'undefined') {
                  const el = document.getElementById('hero-demo-video');
                  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
              }}
              className="px-6 sm:px-8 py-3 sm:py-4 bg-white/10 text-white rounded-2xl hover:bg-white/20 transition-all duration-300 text-base sm:text-lg backdrop-blur"
            >
              Watch demo
            </button>
          </div>
          <div className="flex flex-wrap justify-center gap-4 sm:gap-6 text-white/60 text-xs sm:text-sm px-4">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 sm:w-5 sm:h-5 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              <span className="whitespace-nowrap">No hardware needed</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 sm:w-5 sm:h-5 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              <span className="whitespace-nowrap">Setup in minutes</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 sm:w-5 sm:h-5 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              <span className="whitespace-nowrap">Works on any device</span>
            </div>
          </div>
        </div>
      </section>

      {/* Hero Image/Demo */}
  <section id="hero-demo-video" className="px-4 sm:px-6 -mt-8 sm:-mt-10 mb-16 sm:mb-20">
        <div className="max-w-3xl mx-auto">
          <div className="bg-surface rounded-2xl sm:rounded-3xl p-4 sm:p-6 shadow-2xl border border-white/10">
            <div className="bg-primary rounded-xl sm:rounded-2xl overflow-hidden" style={{ aspectRatio: '1450/1502' }}>
              <video 
                className="w-full h-full object-cover rounded-xl sm:rounded-2xl" 
                controls 
                preload="metadata"
                playsInline
                poster="/app-demo-poster.jpg"
              >
                <source src="/app-demo.mp4" type="video/mp4" />
                {/* Fallback for browsers that don't support video */}
                <div className="flex items-center justify-center h-full">
                  <div className="text-center p-4">
                    <div className="w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-4 bg-accent/20 rounded-2xl flex items-center justify-center">
                      <svg className="w-8 h-8 sm:w-10 sm:h-10 text-accent" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
                      </svg>
                    </div>
                    <p className="text-white/60 text-sm">Your browser doesn't support video playback</p>
                  </div>
                </div>
              </video>
            </div>
          </div>
        </div>
      </section>

      {/* Core Benefits */}
      <section className="py-16 sm:py-20 px-4 sm:px-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12 sm:mb-16">
            <h2 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold mb-4 sm:mb-6">Why teams choose Hands</h2>
            <p className="text-lg sm:text-xl text-white/70 max-w-3xl mx-auto leading-relaxed px-2">
              Stop playing catch-up. Create predictable operations that work every single shift.
            </p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
            {[
              {
                icon: (
                  <svg className="w-6 h-6 sm:w-8 sm:h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                ),
                title: 'Bulletproof Consistency',
                description: 'Every location follows the same standards. No exceptions, no missed steps, no surprises.',
              },
              {
                icon: (
                  <svg className="w-6 h-6 sm:w-8 sm:h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                    <path fillRule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2V3a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2h1zm0 5V9a1 1 0 011-1h1a1 1 0 110 2v1a1 1 0 11-2 0z" clipRule="evenodd" />
                  </svg>
                ),
                title: 'Real-Time Visibility',
                description: 'See what\'s happening across all locations instantly. Spot issues before they become problems.',
              },
              {
                icon: (
                  <svg className="w-6 h-6 sm:w-8 sm:h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z" clipRule="evenodd" />
                    <path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z" />
                  </svg>
                ),
                title: 'Effortless Scaling',
                description: 'Add locations without adding chaos. Your systems grow with you, not against you.',
              }
            ].map((benefit, index) => (
              <div key={index} className="bg-surface text-white p-6 sm:p-8 rounded-2xl sm:rounded-3xl hover:bg-white/5 transition-all duration-300 group">
                <div className="w-12 h-12 sm:w-16 sm:h-16 bg-accent/20 rounded-xl sm:rounded-2xl flex items-center justify-center text-accent mb-4 sm:mb-6 group-hover:scale-110 transition-transform duration-300">
                  {benefit.icon}
                </div>
                <h3 className="text-lg sm:text-xl font-semibold mb-3 sm:mb-4">{benefit.title}</h3>
                <p className="text-white/70 leading-relaxed text-sm sm:text-base">{benefit.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Problem/Solution */}
      <section className="py-16 sm:py-20 px-4 sm:px-6 bg-gradient-to-r from-primary to-surface">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 sm:gap-12 lg:gap-16 items-center">
            <div>
              <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-4 sm:mb-6 text-white leading-tight">
                Stop fighting fires.<br />Start preventing them.
              </h2>
              <div className="space-y-4 sm:space-y-6">
                <div className="flex gap-3 sm:gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80 text-sm sm:text-base">Tasks get skipped when shifts get busy</p>
                </div>
                <div className="flex gap-3 sm:gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80 text-sm sm:text-base">Different standards across locations</p>
                </div>
                <div className="flex gap-3 sm:gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80 text-sm sm:text-base">No visibility into what's actually happening</p>
                </div>
                <div className="flex gap-3 sm:gap-4">
                  <div className="w-2 h-2 bg-red-400 rounded-full mt-2 flex-shrink-0"></div>
                  <p className="text-white/80 text-sm sm:text-base">Training takes forever and doesn't stick</p>
                </div>
              </div>
            </div>
            <div className="bg-black/40 rounded-2xl sm:rounded-3xl p-6 sm:p-8 backdrop-blur">
              <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6 text-white">With Hands, you get:</h3>
              <div className="space-y-3 sm:space-y-4">
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Foolproof checklists that can't be skipped</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Identical standards everywhere, automatically</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Live dashboard with real completion data</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Built-in docs and training materials</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Social Proof */}
      <section className="py-16 sm:py-20 px-4 sm:px-6">
        <div className="max-w-6xl mx-auto text-center">
          <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-8 sm:mb-12">Loved by operators like you</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
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
              <div key={index} className="bg-surface p-6 sm:p-8 rounded-2xl sm:rounded-3xl">
                <div className="text-accent mb-3 sm:mb-4 text-lg sm:text-xl">
                  {"★".repeat(5)}
                </div>
                <p className="text-white/90 italic mb-4 sm:mb-6 leading-relaxed text-sm sm:text-base">"{testimonial.quote}"</p>
                <div>
                  <p className="font-semibold text-white text-sm sm:text-base">{testimonial.name}</p>
                  <p className="text-white/60 text-xs sm:text-sm">{testimonial.title}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 sm:py-20 md:py-24 px-4 sm:px-6 bg-gradient-to-r from-accent/10 to-primary">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold mb-4 sm:mb-6 leading-tight">Stop stressing about operations</h2>
          <p className="text-base sm:text-lg md:text-xl text-white/80 mb-8 sm:mb-10 max-w-2xl mx-auto leading-relaxed px-2">
            Transform chaotic shifts into predictable success. Join hundreds of operators 
            who've eliminated missed tasks and inconsistent standards for good.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center mb-6 sm:mb-8 px-4">
            <a href={signupUrl} className="px-6 sm:px-8 py-3 sm:py-4 bg-accent text-primary font-semibold rounded-xl sm:rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-base sm:text-lg min-h-[48px] flex items-center justify-center">
              Start free trial
            </a>
            <Link href="/contact" className="px-6 sm:px-8 py-3 sm:py-4 border-2 border-white/20 text-white rounded-xl sm:rounded-2xl hover:bg-white/10 transition-all duration-300 text-base sm:text-lg min-h-[48px] flex items-center justify-center">
              Book a demo
            </Link>
          </div>
          <p className="text-white/60 text-xs sm:text-sm px-2">
            Free 14-day trial • Cancel anytime • No setup fees
          </p>
        </div>
      </section>
    </div>
    </>
  )
}
