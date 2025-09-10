import { useState } from 'react'
import SEO from '../components/SEO'

export default function Contact() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [subject, setSubject] = useState('')
  const [message, setMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const [notice, setNotice] = useState(null)

  const validate = () => {
    if (!email || !subject || !message) return false
    // simple email check
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return false
    return true
  }

  const onSubmit = async (e) => {
    e.preventDefault()
    setNotice(null)
    if (!validate()) {
      setNotice({ type: 'error', text: 'Please fill name/email/subject/message and provide a valid email.' })
      return
    }

    setLoading(true)
    try {
      // Add marketing site prefix to message to distinguish from in-app support requests
      const augmentedMessage = `[Marketing site — Info question] This message originated from the marketing site and is NOT an in-app support request.

${message}

Received at: ${new Date().toISOString()}`

      const resp = await fetch('https://us-central1-plan-with-hands.cloudfunctions.net/placesAutocompleteHttp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestType: 'help',
          email,
          subject,
          message: augmentedMessage,
        }),
      })

      const data = await resp.json()
      if (!resp.ok) {
        setNotice({ type: 'error', text: data?.error || 'Failed to send message' })
      } else {
        setNotice({ type: 'success', text: 'Message sent — we will respond to info questions by email.' })
        setName('')
        setEmail('')
        setSubject('')
        setMessage('')
      }
    } catch (err) {
      setNotice({ type: 'error', text: 'Network error. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "ContactPage",
    "name": "Contact Plan With Hands",
    "description": "Get in touch with Plan With Hands for restaurant management software questions, demos, and support.",
    "url": "https://planwithhands.com/contact/",
    "mainEntity": {
      "@type": "Organization",
      "name": "Plan With Hands",
      "contactPoint": {
        "@type": "ContactPoint",
        "contactType": "customer service",
        "email": "support@planwithhands.com",
        "url": "https://planwithhands.com/contact/"
      }
    }
  };

  return (
    <>
      <SEO
        title="Contact Us - Plan With Hands | Restaurant Management Software Support"
        description="Contact Plan With Hands for restaurant management software questions, demos, and support. Email support@planwithhands.com or use our contact form."
        canonical="https://planwithhands.com/contact/"
        structuredData={structuredData}
        keywords="contact plan with hands, restaurant software support, demo request, customer service, restaurant management help"
      />
    <div className="container mx-auto py-12 sm:py-16 md:py-20 px-4 sm:px-6">
      <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4 sm:mb-6 text-center leading-tight">Contact Us</h1>
      <p className="text-white/80 text-center mb-8 sm:mb-12 text-sm sm:text-base px-2">
        Questions? Email <a href="mailto:support@planwithhands.com" className="text-accent hover:text-accent/80 transition-colors">support@planwithhands.com</a> or use the form below.
      </p>
      <form onSubmit={onSubmit} className="max-w-xl mx-auto space-y-4 sm:space-y-6 bg-surface text-white rounded-xl sm:rounded-2xl shadow-xl p-6 sm:p-8">
        {notice && (
          <div className={`p-3 rounded-md ${notice.type === 'error' ? 'bg-red-600' : 'bg-green-600'}`}>
            {notice.text}
          </div>
        )}

        <input value={name} onChange={(e) => setName(e.target.value)} type="text" placeholder="Name" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent min-h-[48px]" />
        <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" placeholder="Email" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent min-h-[48px]" />
        <input value={subject} onChange={(e) => setSubject(e.target.value)} type="text" placeholder="Subject" className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent min-h-[48px]" />
        <textarea value={message} onChange={(e) => setMessage(e.target.value)} placeholder="Message" rows={5} className="w-full border border-white/20 bg-white/10 text-white placeholder-white/60 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent resize-vertical"></textarea>
        <button disabled={loading} type="submit" className="bg-accent text-primary px-6 py-3 rounded-xl font-semibold w-full hover:opacity-90 transition-colors duration-200 min-h-[48px] text-sm sm:text-base">
          {loading ? 'Sending…' : 'Send Message'}
        </button>
      </form>
    </div>
    </>
  )
}
