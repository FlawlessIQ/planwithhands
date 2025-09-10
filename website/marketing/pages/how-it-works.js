import Link from 'next/link'
import SEO from '../components/SEO'

const admin = [
  { 
    title: 'Sign up & setup', 
    desc: 'Create your organization, add locations, and access the admin dashboard to configure everything.',
    icon: '🚀',
    color: 'from-blue-500 to-blue-600'
  },
  { 
    title: 'Define operations', 
    desc: 'Set up shifts, roles, and assign checklists with tasks to each location and shift.',
    icon: '⚙️',
    color: 'from-purple-500 to-purple-600'
  },
  { 
    title: 'Invite your team', 
    desc: 'Add managers and staff—invites prompt mobile app download and account setup.',
    icon: '👥',
    color: 'from-green-500 to-green-600'
  },
  { 
    title: 'Centralize documents', 
    desc: 'Upload training materials, SOPs, and procedures so everyone sees the latest version.',
    icon: '📚',
    color: 'from-yellow-500 to-yellow-600'
  },
  { 
    title: 'Go live & manage', 
    desc: 'Monitor completion in real-time, view photos/notes, spot misses, and message your team.',
    icon: '📊',
    color: 'from-red-500 to-red-600'
  },
]

const staff = [
  { 
    title: 'Complete daily tasks', 
    desc: 'Open the app to view shift checklists, upload required photos, and add notes or explanations.',
    icon: '✅',
    color: 'from-emerald-500 to-emerald-600'
  },
  { 
    title: 'Access training materials', 
    desc: 'Review the latest SOPs, recipes, and procedures from your phone—no binders needed.',
    icon: '📖',
    color: 'from-cyan-500 to-cyan-600'
  },
  { 
    title: 'Stay connected', 
    desc: 'Receive announcements and updates from management to keep aligned with standards.',
    icon: '💬',
    color: 'from-indigo-500 to-indigo-600'
  },
]

function ModernTimeline({ steps, title, subtitle, variant = 'admin' }) {
  const isAdmin = variant === 'admin'
  
  return (
    <div className="relative">
      {/* Header */}
      <div className="text-center mb-16">
        <h2 className="text-4xl font-bold mb-4 bg-gradient-to-r from-white to-white/80 bg-clip-text text-transparent">
          {title}
        </h2>
        <p className="text-xl text-white/70 max-w-3xl mx-auto leading-relaxed">
          {subtitle}
        </p>
      </div>

      {/* Timeline */}
      <div className="relative max-w-4xl mx-auto">
        {/* Central line - only show on desktop */}
        <div className="hidden lg:block absolute left-1/2 transform -translate-x-1/2 w-1 h-full bg-gradient-to-b from-accent/30 via-accent/60 to-accent/30"></div>
        
        {steps.map((step, index) => {
          const isEven = index % 2 === 0
          const isLast = index === steps.length - 1
          
          return (
            <div key={index} className="relative mb-12 lg:mb-16">
              {/* Desktop Layout */}
              <div className={`hidden lg:flex items-center ${isEven ? 'flex-row' : 'flex-row-reverse'}`}>
                {/* Content Card */}
                <div className={`w-5/12 ${isEven ? 'pr-8 text-right' : 'pl-8 text-left'}`}>
                  <div className="group relative">
                    {/* Hover glow effect */}
                    <div className={`absolute inset-0 bg-gradient-to-r ${step.color} rounded-2xl opacity-0 group-hover:opacity-20 blur-xl transition-all duration-500`}></div>
                    
                    <div className="relative bg-surface/80 backdrop-blur-sm border border-white/10 rounded-2xl p-8 hover:border-accent/30 transition-all duration-300 hover:transform hover:scale-105">
                      <div className={`flex items-center gap-4 mb-4 ${isEven ? 'justify-end' : 'justify-start'}`}>
                        <div className={`text-3xl ${isEven ? 'order-2' : 'order-1'}`}>{step.icon}</div>
                        <h3 className={`text-2xl font-bold text-white ${isEven ? 'order-1' : 'order-2'}`}>
                          {step.title}
                        </h3>
                      </div>
                      <p className="text-white/80 leading-relaxed text-lg">{step.desc}</p>
                    </div>
                  </div>
                </div>

                {/* Center Circle */}
                <div className="relative flex-shrink-0 w-16 h-16 mx-auto">
                  <div className={`absolute inset-0 bg-gradient-to-r ${step.color} rounded-full`}></div>
                  <div className="absolute inset-2 bg-black rounded-full flex items-center justify-center">
                    <span className="text-white font-bold text-lg">{index + 1}</span>
                  </div>
                  {/* Connecting dot */}
                  <div className="absolute inset-0 animate-pulse">
                    <div className={`w-full h-full bg-gradient-to-r ${step.color} rounded-full opacity-30`}></div>
                  </div>
                </div>

                {/* Spacer for opposite side */}
                <div className="w-5/12"></div>
              </div>

              {/* Mobile Layout */}
              <div className="lg:hidden">
                <div className="flex items-start gap-6">
                  {/* Number circle */}
                  <div className="flex-shrink-0 relative">
                    <div className={`w-12 h-12 bg-gradient-to-r ${step.color} rounded-full flex items-center justify-center`}>
                      <span className="text-white font-bold">{index + 1}</span>
                    </div>
                    {/* Mobile connecting line */}
                    {!isLast && (
                      <div className="absolute left-1/2 transform -translate-x-1/2 w-0.5 h-16 bg-gradient-to-b from-accent/60 to-accent/30 mt-2"></div>
                    )}
                  </div>

                  {/* Content */}
                  <div className="flex-1 pb-8">
                    <div className="bg-surface/60 backdrop-blur-sm border border-white/10 rounded-xl p-6">
                      <div className="flex items-center gap-3 mb-3">
                        <span className="text-2xl">{step.icon}</span>
                        <h3 className="text-xl font-bold text-white">{step.title}</h3>
                      </div>
                      <p className="text-white/80 leading-relaxed">{step.desc}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default function HowItWorks() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "HowTo",
    "name": "How to Set Up Restaurant Management with Plan With Hands",
    "description": "Step-by-step guide to implementing Plan With Hands restaurant management software for digital checklists, team communication, and operational excellence.",
    "url": "https://planwithhands.com/how-it-works/",
    "step": [
      {
        "@type": "HowToStep",
        "name": "Sign up & setup",
        "text": "Create your organization, add locations, and access the admin dashboard to configure everything."
      },
      {
        "@type": "HowToStep", 
        "name": "Define operations",
        "text": "Set up shifts, roles, and assign checklists with tasks to each location and shift."
      },
      {
        "@type": "HowToStep",
        "name": "Invite your team", 
        "text": "Add managers and staff—invites prompt mobile app download and account setup."
      },
      {
        "@type": "HowToStep",
        "name": "Centralize documents",
        "text": "Upload training materials, SOPs, and procedures so everyone sees the latest version."
      },
      {
        "@type": "HowToStep",
        "name": "Go live & manage",
        "text": "Monitor completion in real-time, view photos/notes, spot misses, and message your team."
      }
    ]
  };

  return (
    <>
      <SEO
        title="How It Works - Plan With Hands | Restaurant Management Implementation Guide"
        description="Learn how to implement Plan With Hands restaurant management software. Step-by-step guide for digital checklists, team communication, and operational excellence."
        canonical="https://planwithhands.com/how-it-works/"
        structuredData={structuredData}
        keywords="how restaurant management software works, implementation guide, restaurant operations setup, digital checklist implementation, team management setup"
      />
  return (
    <div>
      {/* Hero Section */}
      <section className="relative py-24 overflow-hidden">
        {/* Background gradient */}
        <div className="absolute inset-0 bg-gradient-to-br from-black via-surface/50 to-black"></div>
        
        {/* Animated background elements */}
        <div className="absolute inset-0 opacity-30">
          <div className="absolute top-20 left-10 w-72 h-72 bg-accent/20 rounded-full blur-3xl animate-pulse"></div>
          <div className="absolute bottom-20 right-10 w-96 h-96 bg-blue-500/20 rounded-full blur-3xl animate-pulse delay-1000"></div>
        </div>

        <div className="relative max-w-5xl mx-auto px-4 text-center">
          <h1 className="text-6xl lg:text-7xl font-bold mb-6">
            <span className="bg-gradient-to-r from-white via-white to-accent bg-clip-text text-transparent">
              How Hands Works
            </span>
          </h1>
          <p className="text-xl lg:text-2xl text-white/70 mb-12 max-w-3xl mx-auto leading-relaxed">
            Configure once, repeat across locations, and get hands on every task.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Link href="/pricing" className="group relative px-8 py-4 bg-gradient-to-r from-accent to-accent/80 text-primary font-bold text-lg rounded-xl shadow-xl hover:shadow-2xl transition-all duration-300 transform hover:scale-105">
              <span className="relative z-10">Start Free Trial</span>
              <div className="absolute inset-0 bg-gradient-to-r from-accent/80 to-accent rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
            </Link>
            <Link href="/features" className="px-8 py-4 bg-white/10 backdrop-blur-sm text-white font-semibold text-lg rounded-xl border border-white/20 hover:bg-white/20 transition-all duration-300">
              Explore Features
            </Link>
          </div>
        </div>
      </section>

      {/* Admin Timeline */}
      <section className="py-20 bg-gradient-to-b from-black to-surface/30">
        <div className="max-w-7xl mx-auto px-4">
          <ModernTimeline
            steps={admin}
            title="Manager / Admin Setup"
            subtitle="Configure your organization, define operations, invite your team, and start monitoring performance across all locations."
            variant="admin"
          />
        </div>
      </section>

      {/* Divider */}
      <div className="relative py-16">
        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-accent/30 to-transparent"></div>
        <div className="relative text-center">
          <div className="inline-block bg-surface border border-accent/30 rounded-full px-8 py-4">
            <span className="text-accent font-semibold text-lg">Then your staff gets to work</span>
          </div>
        </div>
      </div>

      {/* Staff Timeline */}
      <section className="py-20 bg-gradient-to-b from-surface/30 to-black">
        <div className="max-w-7xl mx-auto px-4">
          <ModernTimeline
            steps={staff}
            title="Staff Workflow"
            subtitle="Mobile-first experience for completing tasks, accessing training, and staying connected with management."
            variant="staff"
          />
        </div>
      </section>

      {/* CTA Section */}
      <section className="relative py-24 bg-gradient-to-r from-primary via-surface to-primary">
        <div className="absolute inset-0 bg-gradient-to-br from-accent/10 via-transparent to-accent/10"></div>
        
        <div className="relative max-w-4xl mx-auto px-4 text-center">
          <h2 className="text-4xl lg:text-5xl font-bold mb-6 bg-gradient-to-r from-white to-accent bg-clip-text text-transparent">
            Ready to Transform Your Operations?
          </h2>
          <p className="text-xl text-white/80 mb-10 leading-relaxed">
            Set up locations, create checklists, invite your team, and start monitoring performance—all in one afternoon.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
            <Link href="/pricing" className="group relative px-10 py-5 bg-gradient-to-r from-accent to-accent/90 text-primary font-bold text-xl rounded-xl shadow-2xl hover:shadow-accent/25 transition-all duration-300 transform hover:scale-105">
              <span className="relative z-10">Start Free Trial</span>
              <div className="absolute inset-0 bg-white/20 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
            </Link>
            <Link href="/contact" className="px-10 py-5 bg-transparent text-white font-semibold text-xl rounded-xl border-2 border-white/30 hover:border-accent hover:bg-accent/10 transition-all duration-300">
              Book a Demo
            </Link>
          </div>
        </div>
      </section>
    </div>
    </>
  )
}
