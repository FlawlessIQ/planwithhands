import Link from 'next/link'
import Image from 'next/image'

export default function Layout({ children }) {
  return (
    <div className="min-h-screen bg-black text-white flex flex-col">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-primary/95 border-b border-white/10 backdrop-blur">
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-4">
            <Image src="/images/hands_icon.png" alt="Hands logo" width={56} height={56} className="rounded-xl" priority />
            <span className="font-semibold tracking-tight text-xl md:text-2xl">Plan With Hands</span>
          </Link>
          <nav className="hidden md:flex items-center gap-6 text-sm">
            <Link href="/how-it-works" className="hover:text-accent">How it works</Link>
            <Link href="/features" className="hover:text-accent">Features</Link>
            <Link href="/pricing" className="hover:text-accent">Pricing</Link>
            <Link href="/about" className="hover:text-accent">About</Link>
            <Link href="/contact" className="hover:text-accent">Contact</Link>
          </nav>
          <div className="hidden md:flex items-center gap-2">
            <a href="/#/lib/features/auth/pages/login_page" className="px-3 py-2 rounded-xl bg-white/0 hover:bg-white/10">Login</a>
            <a href="/#/lib/features/auth/pages/account_creation_page_simple_branded" className="px-4 py-2 rounded-xl bg-accent text-primary font-semibold hover:opacity-90">Sign up</a>
          </div>
        </div>
      </header>

      {/* Mobile nav */}
      <div className="md:hidden bg-primary/95 border-b border-white/10">
        <div className="max-w-6xl mx-auto px-4 py-2 flex gap-4 text-sm overflow-x-auto">
          <Link href="/how-it-works">How it works</Link>
          <Link href="/features">Features</Link>
          <Link href="/pricing">Pricing</Link>
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
          <a href="/#/lib/features/auth/pages/login_page">Login</a>
          <a href="/#/lib/features/auth/pages/account_creation_page_simple_branded" className="px-2 py-1 rounded-lg bg-accent text-primary font-semibold">Sign up</a>
        </div>
      </div>

      <main className="flex-1">{children}</main>

      {/* Footer */}
      <footer className="bg-primary border-t border-white/10 mt-20">
        <div className="max-w-6xl mx-auto px-4 py-10 grid md:grid-cols-4 gap-8 text-sm">
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Image src="/images/hands_icon.png" alt="Hands logo" width={20} height={20} className="rounded" />
              <span className="font-semibold">Plan With Hands</span>
            </div>
            <p className="text-white/70">Run every shift on rails — checklists, documents, insights, and messaging.</p>
          </div>
          <div>
            <h4 className="font-semibold mb-3">Product</h4>
            <ul className="space-y-2 text-white/80">
              <li><Link href="/how-it-works">How it works</Link></li>
              <li><Link href="/features">Features</Link></li>
              <li><Link href="/pricing">Pricing</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-3">Company</h4>
            <ul className="space-y-2 text-white/80">
              <li><Link href="/about">About</Link></li>
              <li><Link href="/contact">Contact</Link></li>
            </ul>
          </div>
          <div className="self-end md:text-right text-white/60">
            © {new Date().getFullYear()} Plan With Hands
          </div>
        </div>
      </footer>
    </div>
  )
}
