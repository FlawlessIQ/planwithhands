export default function Terms() {
  return (
    <div className="container mx-auto px-4 py-20 max-w-3xl">
      <h1 className="text-5xl font-bold mb-6">Terms of Service</h1>
      <p className="text-white/80 mb-8">Last updated: {new Date().toLocaleDateString()}</p>

      <div className="space-y-6 text-white/80 leading-relaxed">
        <p>
          Welcome to Plan With Hands (“Hands”). By accessing or using our website, mobile
          applications, or services, you agree to these Terms of Service.
        </p>

        <h2 className="text-2xl font-semibold text-white">Use of Services</h2>
        <p>
          You may use Hands only in compliance with applicable laws and these Terms.
          You are responsible for the activities of your organization and users you invite.
        </p>

        <h2 className="text-2xl font-semibold text-white">Accounts</h2>
        <p>
          You must provide accurate information when creating an account. You are responsible
          for maintaining the confidentiality of your login credentials.
        </p>

        <h2 className="text-2xl font-semibold text-white">Subscriptions & Payments</h2>
        <p>
          Hands is offered on a subscription basis. Pricing is published on our website and may
          change from time to time. Payments are billed in advance per billing cycle. Annual
          billing includes a discount as specified in our pricing page.
        </p>

        <h2 className="text-2xl font-semibold text-white">Termination</h2>
        <p>
          We may suspend or terminate accounts that violate these Terms or are used for unlawful
          purposes. You may cancel your subscription at any time.
        </p>

        <h2 className="text-2xl font-semibold text-white">Liability</h2>
        <p>
          To the fullest extent permitted by law, Hands is not liable for indirect, incidental,
          or consequential damages. Our total liability is limited to the subscription fees you
          have paid for the service.
        </p>

        <h2 className="text-2xl font-semibold text-white">Changes</h2>
        <p>
          We may update these Terms periodically. Continued use of the service after changes
          indicates your acceptance of the updated Terms.
        </p>

        <h2 className="text-2xl font-semibold text-white">Contact Us</h2>
        <p>
          If you have any questions about these Terms, please contact us at
          <a href="mailto:support@planwithhands.com" className="text-accent"> support@planwithhands.com</a>.
        </p>
      </div>
    </div>
  )
}
