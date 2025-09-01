export default function Contact() {
  return (
    <div className="container mx-auto py-12 sm:py-16 md:py-20 px-4 sm:px-6">
      <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4 sm:mb-6 text-center leading-tight">Contact Us</h1>
      <p className="text-white/80 text-center mb-8 sm:mb-12 text-sm sm:text-base px-2">
        Questions? Email <a href="mailto:support@planwithhands.com" className="text-accent hover:text-accent/80 transition-colors">support@planwithhands.com</a> or use the form below.
      </p>
      <form className="max-w-xl mx-auto space-y-4 sm:space-y-6 bg-surface text-white rounded-xl sm:rounded-2xl shadow-xl p-6 sm:p-8">
        <input type="text" placeholder="Name" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent min-h-[48px]" />
        <input type="email" placeholder="Email" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent min-h-[48px]" />
        <textarea placeholder="Message" rows="5" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent resize-vertical"></textarea>
        <button className="bg-accent text-primary px-6 py-3 rounded-xl font-semibold w-full hover:opacity-90 transition-colors duration-200 min-h-[48px] text-sm sm:text-base">Send Message</button>
      </form>
    </div>
  )
}
