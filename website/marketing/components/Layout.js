import Link from 'next/link'
import Image from 'next/image'

export default function Layout({ children }) {
  return (
    <div className="min-h-screen bg-black text-white flex flex-col">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-primary/95 border-b border-white/10 backdrop-blur">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-14 sm:h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-3 sm:gap-5">
            <Image
              src="/images/hands_icon.png"
              alt="Hands logo"
              width={56}
              height={56}
              className="w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 rounded-lg sm:rounded-xl"
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
            <a href="https://plan-with-hands.web.app/login" className="px-3 py-2 rounded-xl bg-white/0 hover:bg-white/10 transition-colors text-sm">Login</a>
            <a href="https://plan-with-hands.web.app/create_account" className="px-3 sm:px-4 py-2 rounded-xl bg-accent text-primary font-semibold hover:opacity-90 transition-opacity text-sm">Sign up</a>
          </div>
          {/* Mobile menu button - we'll add this later if needed */}
        </div>
      </header>

      {/* Mobile nav */}
      <div className="lg:hidden bg-primary/95 border-b border-white/10 safe-area-inset">
        <div className="max-w-6xl mx-auto px-4 py-3 flex gap-3 text-sm overflow-x-auto scrollbar-hide">
          <Link href="/how-it-works" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">How it works</Link>
          <Link href="/features" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">Features</Link>
          <Link href="/pricing" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">Pricing</Link>
          <Link href="/about" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">About</Link>
          <Link href="/contact" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">Contact</Link>
          <a href="https://plan-with-hands.web.app/login" className="whitespace-nowrap px-3 py-1 rounded-lg hover:bg-white/10 transition-colors">Login</a>
          <a href="https://plan-with-hands.web.app/create_account" className="whitespace-nowrap px-3 py-1 rounded-lg bg-accent text-primary font-semibold hover:opacity-90 transition-opacity ml-auto">Sign up</a>
        </div>
      </div>

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
