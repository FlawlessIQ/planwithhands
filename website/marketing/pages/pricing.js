import { useMemo, useState } from 'react'

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

  return (
    <div className="container mx-auto py-20 text-center max-w-4xl">
      <h1 className="text-5xl font-bold mb-4">Simple, transparent pricing</h1>
      <p className="text-white/80 mb-8">Pay per location. Save 10% with annual billing.</p>

      <div className="bg-surface text-white rounded-2xl shadow-xl p-10 max-w-xl mx-auto">
        <h2 className="text-2xl font-semibold mb-1">Hands Plan</h2>
        <p className="text-white/70 mb-4">First location: $69.99/mo • Additional: $49.99/mo each</p>        {/* Locations control */}
        <div className="flex items-center justify-center gap-3 mb-6">
    <button onClick={()=>setLocations(Math.max(1, locations-1))} className="px-3 py-2 rounded-lg bg-white/10 text-white hover:bg-white/20">-</button>
          <div className="font-semibold min-w-[8rem]">Locations: {locations}</div>
    <button onClick={()=>setLocations(locations+1)} className="px-3 py-2 rounded-lg bg-white/10 text-white hover:bg-white/20">+</button>
        </div>

        {/* Billing cycle */}
        <div className="inline-flex bg-white/10 rounded-xl mb-6">
          <button onClick={()=>setCycle(MONTHLY)} className={`px-4 py-2 rounded-xl transition-colors duration-200 ${cycle===MONTHLY?'bg-accent text-primary font-semibold shadow-soft':'text-white hover:bg-white/20'}`}>Monthly</button>
          <button onClick={()=>setCycle(ANNUAL)} className={`px-4 py-2 rounded-xl transition-colors duration-200 ${cycle===ANNUAL?'bg-accent text-primary font-semibold shadow-soft':'text-white hover:bg-white/20'}`}>Annual (10% off)</button>
        </div>

        <div className="text-4xl font-bold mb-1">${price.toFixed(2)}</div>
        <div className="text-sm text-white/60 mb-6">{suffix} for {locations} {locations>1?'locations':'location'}</div>

  <button className="bg-accent text-primary px-6 py-3 rounded-xl font-semibold w-full hover:opacity-90 transition-colors duration-200">Start free trial</button>

  <ul className="text-left text-white/90 mt-6 space-y-2 list-disc list-inside">
          <li>Daily checklists with photos & notes</li>
          <li>Documents & training library</li>
          <li>Team messaging with push notifications</li>
          <li>Live metrics & missed task insights</li>
          <li>Multi-location ready</li>
        </ul>
      </div>

      {/* FAQ */}
      <div className="mt-16 text-left max-w-2xl mx-auto">
        <h3 className="text-2xl font-semibold mb-6 text-center">Frequently Asked Questions</h3>
        <div className="space-y-4">
          <details className="bg-surface text-white rounded-xl p-4">
            <summary className="font-semibold">How does billing work per location?</summary>
            <p>We bill $69.99 for your first location and $49.99 for each additional location. Annual billing applies a 10% discount to the yearly total.</p>
          </details>
          <details className="bg-surface text-white rounded-xl p-4">
            <summary className="font-semibold">Is there a free trial?</summary>
            <p>Yes! Get started free and see if Hands works for your team before paying.</p>
          </details>
          <details className="bg-surface text-white rounded-xl p-4">
            <summary className="font-semibold">Can I add or remove locations any time?</summary>
            <p>Absolutely. Your billing adjusts with your current number of active locations.</p>
          </details>
        </div>
      </div>
    </div>
  )
}
