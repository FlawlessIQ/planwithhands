import React, { useState, useRef, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import SEO from '../components/SEO'

export default function Home() {
  const signupUrl = '/app-signup?src=home_final_cta';
  const [showTransition, setShowTransition] = useState(false);
  const [nextHref, setNextHref] = useState(null);
  const videoRef = useRef(null);

  // Start the transition: show overlay and attempt to play the video.
  const startTransition = (href) => {
    setNextHref(href);
    setShowTransition(true);
  };

  // Intercept clicks and start transition
  const handleNavigate = (e, href) => {
    // Only operate in the browser
    if (typeof document === 'undefined') return;
    e.preventDefault();
    startTransition(href);
  };

  useEffect(() => {
    if (!showTransition) return;

    let endedHandler = null;
    let playTimeout = null;

    const vid = videoRef.current;
    if (vid) {
      // When the video ends, navigate
      endedHandler = () => {
        if (nextHref) window.location.href = nextHref;
      };
      vid.addEventListener('ended', endedHandler);

      // Try to play; if play() is rejected (autoplay policy), fallback to timed redirect
      const tryPlay = async () => {
        try {
          // muted is required for autoplay on many mobile browsers
          await vid.play();
          // nothing else to do; ended handler will redirect
        } catch (err) {
          // If playing failed, redirect after a short delay
          playTimeout = setTimeout(() => {
            if (nextHref) window.location.href = nextHref;
          }, 1200);
        }
      };

      // Small delay to let the overlay render
      setTimeout(tryPlay, 80);
    } else {
      // No video element available - fallback to timed redirect
      playTimeout = setTimeout(() => {
        if (nextHref) window.location.href = nextHref;
      }, 700);
    }

    return () => {
      if (vid && endedHandler) vid.removeEventListener('ended', endedHandler);
      if (playTimeout) clearTimeout(playTimeout);
    };
  }, [showTransition, nextHref]);
  
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "Plan With Hands",
    "alternateName": "Hands App",
    "description": "Restaurant operations software with shift checklists, photo proof, team messaging, training documents, daily summaries, and manager dashboards. No hardware needed.",
    "url": "https://planwithhands.com",
    "applicationCategory": "BusinessApplication",
    "operatingSystem": "iOS, Android, Web",
    "offers": {
      "@type": "Offer",
      "price": "49.99",
      "priceCurrency": "USD",
      "priceSpecification": {
        "@type": "UnitPriceSpecification",
        "price": "49.99",
        "priceCurrency": "USD",
        "unitText": "MONTH"
      }
    },
    "provider": {
      "@type": "Organization",
      "name": "Plan With Hands",
      "url": "https://planwithhands.com",
      "logo": {
        "@type": "ImageObject",
        "url": "https://planwithhands.com/images/favicon-192.png"
      }
    },
    "featureList": [
      "Shift Checklists",
      "Photo Proof",
      "Team Messaging",
      "Training Documents",
      "Daily Summaries",
      "Location Performance Dashboards",
      "English, Spanish, and Portuguese Workflows",
      "Shared Device Mode"
    ]
  };

  return (
    <>
      <SEO
        title="Plan With Hands - Restaurant Task & Team Management Software"
        description="Run every restaurant shift with proof. Hands combines checklists, photo proof, training docs, team messages, dashboards, and daily summaries. Start a 14-day trial with no card required."
        canonical="https://planwithhands.com/"
        structuredData={structuredData}
        keywords="restaurant management software, digital checklists, restaurant operations, team communication, food service software, restaurant technology, operational excellence, task management"
      />
      <div>
      {/* Transition handled globally in Layout.js */}
      {/* Hero Section */}
      <section className="relative px-4 sm:px-6 py-16 sm:py-20 md:py-32 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-black via-primary to-surface"></div>
        <div className="relative max-w-6xl mx-auto text-center">
          <div className="mb-6 sm:mb-8">
            <span className="inline-block px-3 sm:px-4 py-2 bg-accent/10 text-accent rounded-full text-xs sm:text-sm font-medium mb-4 sm:mb-6">
              Built for restaurant operators
            </span>
          </div>
          <h1 className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-bold mb-4 sm:mb-6 leading-tight">
            Run every shift
            <span className="block text-accent">with proof</span>
          </h1>
          <p className="text-lg sm:text-xl md:text-2xl text-white/80 mb-8 sm:mb-10 max-w-4xl mx-auto leading-relaxed px-2">
            Checklists, photo proof, training docs, team messages, dashboards, and daily summaries for restaurants that need every location operating the same way.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-3 sm:gap-4 mb-8 sm:mb-12 px-4">
            <Link href="/app-signup?src=home_hero_cta" className="px-6 sm:px-8 py-3 sm:py-4 bg-accent text-primary font-semibold rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-base sm:text-lg">
              Start 14-day trial
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
              <span className="whitespace-nowrap">No card required</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 sm:w-5 sm:h-5 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              <span className="whitespace-nowrap">English, Spanish, Portuguese</span>
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
                title: 'Shift Execution',
                description: 'Assign opening, prep, closing, and manager checks by location, shift, and role.',
              },
              {
                icon: (
                  <svg className="w-6 h-6 sm:w-8 sm:h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                    <path fillRule="evenodd" d="M4 5a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2V3a2 2 0 012-2v1a2 2 0 00-2 2v6a2 2 0 002 2h8a2 2 0 002-2V6a2 2 0 00-2-2h1zm0 5V9a1 1 0 011-1h1a1 1 0 110 2v1a1 1 0 11-2 0z" clipRule="evenodd" />
                  </svg>
                ),
                title: 'Proof of Work',
                description: 'Require photos, notes, and reasons so managers know what happened, when, and by whom.',
              },
              {
                icon: (
                  <svg className="w-6 h-6 sm:w-8 sm:h-8" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z" clipRule="evenodd" />
                    <path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z" />
                  </svg>
                ),
                title: 'Manager Visibility',
                description: 'Use live dashboards, daily summaries, and location breakdowns to catch issues early.',
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
                  <p className="text-white text-sm sm:text-base">Shift checklists with photo proof and notes</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Role-based workflows for staff, managers, and admins</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Daily summaries and location performance breakdowns</p>
                </div>
                <div className="flex gap-3 sm:gap-4 items-center">
                  <svg className="w-5 h-5 sm:w-6 sm:h-6 text-accent flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                  <p className="text-white text-sm sm:text-base">Training docs, team messages, and multilingual staff access</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Operations Outcomes */}
      <section className="py-16 sm:py-20 px-4 sm:px-6">
        <div className="max-w-6xl mx-auto text-center">
          <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-8 sm:mb-12">Built for the moments that break consistency</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
            {[
              {
                title: "Open stronger",
                body: "Give every location the same opening, prep, closing, and manager-check standards."
              },
              {
                title: "Train faster",
                body: "Keep procedures, documents, and task expectations in one place, available on staff phones and shared devices."
              },
              {
                title: "See issues sooner",
                body: "Use live dashboards and daily summaries to spot missed tasks before they turn into guest-facing problems."
              }
            ].map((item, index) => (
              <div key={index} className="bg-surface p-6 sm:p-8 rounded-2xl sm:rounded-3xl">
                <p className="font-semibold text-white text-lg sm:text-xl mb-3">{item.title}</p>
                <p className="text-white/75 leading-relaxed text-sm sm:text-base">{item.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 sm:py-20 md:py-24 px-4 sm:px-6 bg-gradient-to-r from-accent/10 to-primary">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold mb-4 sm:mb-6 leading-tight">Start your first location today</h2>
          <p className="text-base sm:text-lg md:text-xl text-white/80 mb-8 sm:mb-10 max-w-2xl mx-auto leading-relaxed px-2">
            Create your organization, add locations, build your first shift checklist, and invite the team. No card required to begin setup.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center mb-6 sm:mb-8 px-4">
            <a href={signupUrl} className="px-6 sm:px-8 py-3 sm:py-4 bg-accent text-primary font-semibold rounded-xl sm:rounded-2xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 text-base sm:text-lg min-h-[48px] flex items-center justify-center">
              Start 14-day trial
            </a>
            <Link href="/contact" className="px-6 sm:px-8 py-3 sm:py-4 border-2 border-white/20 text-white rounded-xl sm:rounded-2xl hover:bg-white/10 transition-all duration-300 text-base sm:text-lg min-h-[48px] flex items-center justify-center">
              Book a demo
            </Link>
          </div>
          <p className="text-white/60 text-xs sm:text-sm px-2">
            14-day trial • No card required • Cancel anytime
          </p>
        </div>
      </section>
    </div>
    </>
  )
}
