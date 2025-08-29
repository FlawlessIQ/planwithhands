import Link from 'next/link'

const admin = [
  { title:'Sign up', desc:'Create your organization and unlock the dashboard.' },
  { title:'Log in', desc:'Access the admin tools to configure your setup.' },
  { title:'Add locations', desc:'Create each store/venue to keep reporting clean.' },
  { title:'Define shifts & roles', desc:'For each location, add the shifts you run and which roles use them.' },
  { title:'Create checklists & assign', desc:'Attach checklists (with a set number of tasks) to relevant shifts.' },
  { title:'Add users', desc:'Invite managers and staff—invites prompt mobile app download.' },
  { title:'Upload training & procedures', desc:'Centralize SOPs/recipes so everyone sees the latest version.' },
  { title:'Go live with metrics', desc:'Monitor completion, view photos/notes, and spot misses in real time.' },
  { title:'Message your team', desc:'Send announcements to all staff, roles, or locations (push if enabled).' },
]

const staff = [
  { title:'See your tasks', desc:'Open the app to view current shift checklists and what’s due now.' },
  { title:'Complete with photos/notes', desc:'Upload photos, add context, or explain if something can’t be completed.' },
  { title:'Review training & procedures', desc:'Access the latest SOPs from your phone—no binders needed.' },
  { title:'Receive announcements', desc:'Keep aligned with messages from management.' },
]

function FlowMap({ steps }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {steps.map((step, index) => (
        <div key={index} className="relative">
          {/* Connection line to next step (not shown on last step) */}
          {index < steps.length - 1 && (
            <div className="hidden lg:block absolute top-8 -right-3 w-6 h-0.5 bg-accent z-10"></div>
          )}
          
          {/* Step card */}
          <div className="bg-surface rounded-xl p-6 border border-accent/20 hover:border-accent/40 transition-all duration-300 transform hover:scale-105 hover:shadow-xl-soft">
            {/* Step number */}
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-full bg-accent text-primary font-bold text-sm flex items-center justify-center shadow-soft">
                {index + 1}
              </div>
              <div className="h-0.5 flex-1 bg-gradient-to-r from-accent/60 to-transparent"></div>
            </div>
            
            {/* Content */}
            <h3 className="text-lg font-semibold text-white mb-3 tracking-tight">{step.title}</h3>
            <p className="text-white/80 text-sm leading-relaxed">{step.desc}</p>
          </div>
        </div>
      ))}
    </div>
  )
}

export default function HowItWorks() {
  return (
    <div>
      <section className="py-20 text-center bg-gradient-to-b from-black to-surface">
        <div className="max-w-4xl mx-auto px-4">
          <h1 className="text-5xl font-bold mb-3">How Hands Works</h1>
          <p className="text-white/80">Configure once, repeat across locations, and keep every shift on rails.</p>
          <div className="mt-8 flex justify-center gap-4">
            <Link href="/pricing" className="px-6 py-3 bg-accent text-primary font-semibold rounded-xl shadow-lg">Start free trial</Link>
            <Link href="/features" className="px-6 py-3 bg-white/10 text-white rounded-xl">Explore features</Link>
          </div>
        </div>
      </section>

      <section className="py-16 max-w-6xl mx-auto px-4">
        <h2 className="text-3xl font-bold mb-2">Manager / Admin flow</h2>
        <p className="text-white/80 mb-8 max-w-3xl">Add locations, define shifts and roles, attach checklists, invite users, and centralize documents. Then go live with metrics.</p>
        <FlowMap steps={admin} />
      </section>

      <section className="py-16 bg-surface">
        <div className="max-w-6xl mx-auto px-4">
          <h2 className="text-3xl font-bold mb-2">Staff flow</h2>
          <p className="text-white/80 mb-8 max-w-3xl">Mobile-first workflow: complete tasks, add photos and notes, review training, and receive announcements.</p>
          <FlowMap steps={staff} />
        </div>
      </section>

      <section className="py-24 bg-primary text-white text-center">
        <h2 className="text-4xl font-bold mb-4">Ready to roll out Hands?</h2>
        <p className="mb-8 text-white/80">Set up locations, attach checklists, invite your team, and go live with metrics—today.</p>
        <Link href="/pricing" className="px-6 py-3 bg-accent text-primary font-semibold rounded-xl shadow-lg">Start free trial</Link>
      </section>
    </div>
  )
}
