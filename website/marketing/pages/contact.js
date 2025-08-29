export default function Contact() {
  return (
    <div className="container mx-auto py-20">
      <h1 className="text-5xl font-bold mb-6 text-center">Contact Us</h1>
      <p className="text-white/80 text-center mb-12">
        Questions? Email <a href="mailto:support@planwithhands.com" className="text-accent">support@planwithhands.com</a> or use the form below.
      </p>
  <form className="max-w-xl mx-auto space-y-6 bg-surface text-white rounded-2xl shadow-xl p-8">
        <input type="text" placeholder="Name" className="w-full border p-3 rounded" />
        <input type="email" placeholder="Email" className="w-full border p-3 rounded" />
        <textarea placeholder="Message" rows="5" className="w-full border p-3 rounded"></textarea>
        <button className="bg-accent text-primary px-6 py-3 rounded-xl font-semibold w-full">Send Message</button>
      </form>
    </div>
  )
}
