import SEO from '../components/SEO'

export default function Privacy() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Privacy Policy - Plan With Hands",
    "description": "Privacy policy for Plan With Hands restaurant management software. Learn how we collect, use, and protect your information.",
    "url": "https://planwithhands.com/privacy/"
  };

  return (
    <>
      <SEO
        title="Privacy Policy - Plan With Hands | Restaurant Management Software"
        description="Privacy policy for Plan With Hands restaurant management software. Learn how we collect, use, and protect your information when using our platform."
        canonical="https://planwithhands.com/privacy/"
        structuredData={structuredData}
        keywords="privacy policy, data protection, restaurant software privacy, plan with hands privacy"
      />
  return (
    <div className="container mx-auto px-4 py-20 max-w-3xl">
      <h1 className="text-5xl font-bold mb-6">Privacy Policy</h1>
      <p className="text-white/80 mb-8">Last updated: {new Date().toLocaleDateString()}</p>

      <div className="space-y-6 text-white/80 leading-relaxed">
        <p>
          At Plan With Hands (“Hands”), your privacy is important to us. This Privacy Policy
          explains how we collect, use, and protect your information when you use our website,
          mobile applications, and services.
        </p>

        <h2 className="text-2xl font-semibold text-white">Information We Collect</h2>
        <p>
          • Personal information you provide (such as name, email, role, organization).<br />
          • Information about how you use the app, including checklists, tasks, and uploads.<br />
          • Device and log information to help us improve performance and security.
        </p>

        <h2 className="text-2xl font-semibold text-white">How We Use Information</h2>
        <p>
          • To provide and improve our services.<br />
          • To communicate with you about product updates, changes, or support.<br />
          • To maintain security and prevent misuse of the platform.
        </p>

        <h2 className="text-2xl font-semibold text-white">Sharing of Information</h2>
        <p>
          We do not sell your personal data. We may share limited information with trusted
          service providers (e.g., cloud hosting, analytics) to operate our services.
        </p>

        <h2 className="text-2xl font-semibold text-white">Your Choices</h2>
        <p>
          You may request access, updates, or deletion of your personal information at any
          time by contacting <a href="mailto:support@planwithhands.com" className="text-accent">support@planwithhands.com</a>.
        </p>

        <h2 className="text-2xl font-semibold text-white">Contact Us</h2>
        <p>
          If you have any questions about this Privacy Policy, please reach out to us at
          <a href="mailto:support@planwithhands.com" className="text-accent"> support@planwithhands.com</a>.
        </p>
      </div>
    </div>
    </>
  )
}
