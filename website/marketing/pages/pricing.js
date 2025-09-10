import { useMemo, useState } from 'react'
import SEO from '../components/SEO'

const MONTHLY = 'monthly'
const ANNUAL = 'annual'

export default function Pricing() {
  const [locations, setLocations] = useState(1)
  const [cycle, setCycle] = useState(MONTHLY)

  const { monthly, annual } = useMemo(() => {
    const first = 69.99
    const additional = 49.99
    const monthly = locations <= 1 ? first : first + (locations - 1) * additional
    const annualBeforeDiscount = monthly * 12
    const annual = annualBeforeDiscount * 0.9 // 10% discount
    return { monthly, annual }
  }, [locations])

  const price = cycle === MONTHLY ? monthly : annual
  const suffix = cycle === MONTHLY ? '/month' : '/year (10% off)'

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Product",
    "name": "Plan With Hands Restaurant Management Software",
    "description": "Restaurant operations management software with digital checklists, team messaging, training documents, and real-time insights",
    "brand": {
      "@type": "Brand",
      "name": "Plan With Hands"
    },
    "offers": [
      {
        "@type": "Offer",
        "name": "Monthly Plan",
        "price": "69.99",
        "priceCurrency": "USD",
        "priceSpecification": {
          "@type": "UnitPriceSpecification",
          "price": "69.99",
          "priceCurrency": "USD",
          "unitText": "MONTH"
        },
        "availability": "https://schema.org/InStock",
        "url": "https://planwithhands.com/pricing/"
      },
      {
        "@type": "Offer",
        "name": "Annual Plan (10% Discount)",
        "price": (69.99 * 12 * 0.9).toFixed(2),
        "priceCurrency": "USD",
        "priceSpecification": {
          "@type": "UnitPriceSpecification",
          "price": (69.99 * 12 * 0.9).toFixed(2),
          "priceCurrency": "USD",
          "unitText": "YEAR"
        },
        "availability": "https://schema.org/InStock",
        "url": "https://planwithhands.com/pricing/"
      }
    ]
  };

  return (
    <>
      <SEO
        title="Pricing - Plan With Hands | Restaurant Management Software"
        description="Simple, transparent pricing for restaurant management software. $69.99/month for first location, $49.99 for additional locations. Save 10% with annual billing. Free 14-day trial."
        canonical="https://planwithhands.com/pricing/"
        structuredData={structuredData}
        keywords="restaurant management software pricing, restaurant operations cost, digital checklist software price, restaurant technology pricing, food service software cost"
      />
      <div className="container mx-auto py-12 sm:py-16 md:py-20 text-center max-w-4xl px-4 sm:px-6">
      <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-3 sm:mb-4 leading-tight">Simple, transparent pricing</h1>
      <p className="text-white/80 mb-6 sm:mb-8 text-sm sm:text-base">Pay per location. Save 10% with annual billing.</p>

      <div className="bg-surface text-white rounded-xl sm:rounded-2xl shadow-xl p-6 sm:p-8 md:p-10 max-w-xl mx-auto">
        <h2 className="text-xl sm:text-2xl font-semibold mb-1">Hands Plan</h2>
        <p className="text-white/70 mb-4 text-xs sm:text-sm">First location: $69.99/mo • Additional: $49.99/mo each</p>
        
        {/* Locations control */}
        <div className="flex items-center justify-center gap-3 mb-6">
          <button onClick={()=>setLocations(Math.max(1, locations-1))} className="px-3 py-2 rounded-lg bg-white/10 text-white hover:bg-white/20 min-w-[44px] h-[44px] flex items-center justify-center text-lg">-</button>
          <div className="font-semibold min-w-[8rem] text-sm sm:text-base">Locations: {locations}</div>
          <button onClick={()=>setLocations(locations+1)} className="px-3 py-2 rounded-lg bg-white/10 text-white hover:bg-white/20 min-w-[44px] h-[44px] flex items-center justify-center text-lg">+</button>
        </div>

        {/* Billing cycle */}
        <div className="inline-flex bg-white/10 rounded-xl mb-6 w-full sm:w-auto">
          <button onClick={()=>setCycle(MONTHLY)} className={`px-3 sm:px-4 py-2 rounded-xl transition-colors duration-200 flex-1 sm:flex-none text-xs sm:text-sm ${cycle===MONTHLY?'bg-accent text-primary font-semibold shadow-soft':'text-white hover:bg-white/20'}`}>Monthly</button>
          <button onClick={()=>setCycle(ANNUAL)} className={`px-3 sm:px-4 py-2 rounded-xl transition-colors duration-200 flex-1 sm:flex-none text-xs sm:text-sm ${cycle===ANNUAL?'bg-accent text-primary font-semibold shadow-soft':'text-white hover:bg-white/20'}`}>Annual (10% off)</button>
        </div>

        <div className="text-3xl sm:text-4xl font-bold mb-1">${price.toFixed(2)}</div>
        <div className="text-xs sm:text-sm text-white/60 mb-6">{suffix} for {locations} {locations>1?'locations':'location'}</div>

        <button className="bg-accent text-primary px-6 py-3 rounded-xl font-semibold w-full hover:opacity-90 transition-colors duration-200 min-h-[48px] text-sm sm:text-base" onClick={() => window.location.href = 'https://plan-with-hands.web.app/create_account'}>Start free trial</button>

        <ul className="text-left text-white/90 mt-6 space-y-2 list-disc list-inside text-sm sm:text-base">
          <li>Daily checklists with photos & notes</li>
          <li>Documents & training library</li>
          <li>Team messaging with push notifications</li>
          <li>Live metrics & missed task insights</li>
          <li>Multi-location ready</li>
        </ul>
      </div>

      {/* FAQ */}
      <div className="mt-12 sm:mt-16 text-left max-w-2xl mx-auto">
        <h3 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6 text-center">Frequently Asked Questions</h3>
        <div className="space-y-3 sm:space-y-4">
          <details className="bg-surface text-white rounded-xl p-4 sm:p-5">
            <summary className="font-semibold text-sm sm:text-base cursor-pointer">How does billing work per location?</summary>
            <p className="mt-2 text-sm sm:text-base text-white/90">We bill $69.99 for your first location and $49.99 for each additional location. Annual billing applies a 10% discount to the yearly total.</p>
          </details>
          <details className="bg-surface text-white rounded-xl p-4 sm:p-5">
            <summary className="font-semibold text-sm sm:text-base cursor-pointer">Is there a free trial?</summary>
            <p className="mt-2 text-sm sm:text-base text-white/90">Yes! Get started free and see if Hands works for your team before paying.</p>
          </details>
          <details className="bg-surface text-white rounded-xl p-4 sm:p-5">
            <summary className="font-semibold text-sm sm:text-base cursor-pointer">Can I add or remove locations any time?</summary>
            <p className="mt-2 text-sm sm:text-base text-white/90">Absolutely. Your billing adjusts with your current number of active locations.</p>
          </details>
        </div>
      </div>
    </div>
    </>
  )
}
