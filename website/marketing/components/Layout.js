import Link from 'next/link'
import Image from 'next/image'
import { useState, useEffect } from 'react'

export default function Layout({ children }) {
  const [mobileOpen, setMobileOpen] = useState(false)

  // Lock body scroll when mobile menu is open
  useEffect(() => {
    if (typeof document === 'undefined') return
    document.body.style.overflow = mobileOpen ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [mobileOpen])

  const closeMobile = () => setMobileOpen(false)

  // Append forceApp=1 to ensure full Flutter app loads (bypasses mobile Safari fallback)
  const loginUrl = '/app-login';
  const signupUrl = '/app-signup';

  return (
    <div className="min-h-screen bg-black text-white flex flex-col">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-primary/95 border-b border-white/10 backdrop-blur">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-14 sm:h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-3 sm:gap-5">
            <Image
              src="/images/hands_icon.png"
              alt="Hands logo"
              width={80}
              height={56}
              className="w-14 sm:w-16 md:w-20 h-10 sm:h-12 md:h-14 rounded-lg sm:rounded-xl object-contain"
              priority
            />
            <span className="font-semibold tracking-tight text-lg sm:text-xl md:text-2xl">Plan With Hands</span>
          </Link>

          <nav className="hidden lg:flex items-center gap-6 text-sm">
            <Link href="/how-it-works" className="hover:text-accent transition-colors">How it works</Link>
            <Link href="/features" className="hover:text-accent transition-colors">Features</Link>
            <Link href="/pricing" className="hover:text-accent transition-colors">Pricing</Link>
            <Link href="/about" className="hover:text-accent transition-colors">About</Link>
            <Link href="/contact" className="hover:text-accent transition-colors">Contact</Link>
          </nav>

          <div className="hidden sm:flex items-center gap-2">
            <a href={loginUrl} className="px-3 py-2 rounded-xl bg-white/0 hover:bg-white/10 transition-colors text-sm">Login</a>
            <a href={signupUrl} className="px-3 sm:px-4 py-2 rounded-xl bg-accent text-primary font-semibold hover:opacity-90 transition-opacity text-sm">Sign up</a>
          </div>

          {/* Mobile hamburger */}
          <button
            onClick={() => setMobileOpen(v => !v)}
            aria-label="Toggle menu"
            aria-expanded={mobileOpen}
            className="lg:hidden inline-flex items-center justify-center p-2 rounded-md hover:bg-white/5 focus:outline-none focus:ring-2 focus:ring-accent"
          >
            {mobileOpen ? (
              <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6L6 18M6 6l12 12" /></svg>
            ) : (
              <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12h18M3 6h18M3 18h18" /></svg>
            )}
          </button>
        </div>

        {/* Mobile dropdown overlay */}
        {mobileOpen && (
          <div className="lg:hidden">
            <div className="fixed inset-0 bg-black/40 z-30" onClick={closeMobile} aria-hidden />
            <div className="fixed top-full left-0 right-0 mt-0 bg-primary/95 border-t border-white/10 shadow-xl z-40 safe-area-inset">
              <div className="max-w-6xl mx-auto px-4 py-4 space-y-3">
                <Link href="/how-it-works" onClick={closeMobile} className="block px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">How it works</Link>
                <Link href="/features" onClick={closeMobile} className="block px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">Features</Link>
                <Link href="/pricing" onClick={closeMobile} className="block px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">Pricing</Link>
                <Link href="/about" onClick={closeMobile} className="block px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">About</Link>
                <Link href="/contact" onClick={closeMobile} className="block px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">Contact</Link>

                <div className="pt-2 border-t border-white/5 flex gap-2">
                  <a onClick={closeMobile} href={loginUrl} className="flex-1 text-center px-3 py-2 rounded-lg hover:bg-white/5 transition-colors">Login</a>
                  <a onClick={closeMobile} href={signupUrl} className="flex-1 text-center px-3 py-2 rounded-lg bg-accent text-primary font-semibold hover:opacity-90 transition-opacity">Sign up</a>
                </div>
              </div>
            </div>
          </div>
        )}
      </header>

      <main className="flex-1">{children}</main>

      {/* Footer */}
      <footer className="bg-primary border-t border-white/10 mt-12 sm:mt-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-8 sm:py-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 sm:gap-8 text-sm">
          <div className="space-y-3 sm:col-span-2 lg:col-span-1">
            <div className="flex items-center gap-3">
              <Image src="/images/hands_icon.png" alt="Hands logo" width={28} height={28} className="w-6 h-6 sm:w-7 sm:h-7 rounded" />
              <span className="font-semibold">Plan With Hands</span>
            </div>
            <p className="text-white/70 leading-relaxed">Get hands on every task — checklists, documents, insights, and messaging.</p>
          </div>
          <div>
            <h4 className="font-semibold mb-3 text-white">Product</h4>
            <ul className="space-y-2 text-white/80">
              <li><Link href="/how-it-works" className="hover:text-accent transition-colors">How it works</Link></li>
              <li><Link href="/features" className="hover:text-accent transition-colors">Features</Link></li>
              <li><Link href="/pricing" className="hover:text-accent transition-colors">Pricing</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-3 text-white">Company</h4>
            <ul className="space-y-2 text-white/80">
              <li><Link href="/about" className="hover:text-accent transition-colors">About</Link></li>
              <li><Link href="/contact" className="hover:text-accent transition-colors">Contact</Link></li>
              <li><Link href="/privacy" className="hover:text-accent transition-colors">Privacy Policy</Link></li>
              <li><Link href="/terms" className="hover:text-accent transition-colors">Terms of Service</Link></li>
            </ul>
          </div>
          <div className="pt-4 sm:pt-0 sm:self-end lg:text-right text-white/60 border-t border-white/10 sm:border-t-0 col-span-full sm:col-span-2 lg:col-span-1">
            © {new Date().getFullYear()} Plan With Hands
          </div>
        </div>
      </footer>
    </div>
  )
}
