import Head from 'next/head'
import { useEffect, useState } from 'react'

const defaultTarget = 'https://plan-with-hands.web.app/create_account?src=marketing_signup';

function buildSignupTarget() {
  if (typeof window === 'undefined') return defaultTarget;
  const currentUrl = new URL(window.location.href);
  const target = new URL(defaultTarget);
  const source = currentUrl.searchParams.get('src') || currentUrl.searchParams.get('source');
  const referrer = currentUrl.searchParams.get('ref') || document.referrer || currentUrl.pathname;

  if (source) target.searchParams.set('src', source);
  if (referrer) target.searchParams.set('ref', referrer);
  target.searchParams.set('landing_url', currentUrl.href);

  ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content'].forEach((key) => {
    const value = currentUrl.searchParams.get(key);
    if (value) target.searchParams.set(key, value);
  });

  return target.toString();
}

export default function AppSignupRedirect() {
  const [target, setTarget] = useState(defaultTarget);

  useEffect(() => {
    const resolvedTarget = buildSignupTarget();
    setTarget(resolvedTarget);
    window.location.replace(resolvedTarget);
    const t = setTimeout(() => {
      if (window.location.href.includes('/app-signup')) {
        window.location.href = resolvedTarget;
      }
    }, 800);
    return () => clearTimeout(t);
  }, []);

  return (
    <>
      <Head>
        <meta httpEquiv="refresh" content={`0;url=${defaultTarget}`} />
      </Head>
      <main style={{minHeight:'100vh',display:'flex',alignItems:'center',justifyContent:'center',flexDirection:'column',background:'#000',color:'#fff',padding:'2rem',textAlign:'center'}}>
        <h1 style={{fontSize:'1.5rem',marginBottom:'1rem'}}>Opening your 14-day trial...</h1>
        <p style={{opacity:0.75,marginBottom:'0.5rem',maxWidth:'32rem'}}>No card required. You will create your organization, add locations, then build your first shift checklist.</p>
        <p style={{opacity:0.55,marginBottom:'1.5rem'}}>If you are not redirected, click below.</p>
        <a href={target} style={{background:'#FFCB47',color:'#111',padding:'0.75rem 1.25rem',borderRadius:'0.75rem',fontWeight:600,textDecoration:'none'}}>Create Trial</a>
        <noscript>
          <p style={{marginTop:'1.5rem'}}>JavaScript disabled. <a href={target}>Continue to signup</a>.</p>
        </noscript>
      </main>
    </>
  );
}
