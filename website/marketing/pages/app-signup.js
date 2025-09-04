import Head from 'next/head'
import { useEffect } from 'react'

export default function AppSignupRedirect() {
  const target = 'https://plan-with-hands.web.app/create_account?src=marketing_redirect';
  useEffect(() => {
    window.location.replace(target);
    const t = setTimeout(() => {
      if (window.location.href.includes('/app-signup')) {
        window.location.href = target;
      }
    }, 800);
    return () => clearTimeout(t);
  }, [target]);

  return (
    <>
      <Head>
        <meta httpEquiv="refresh" content={`0;url=${target}`} />
      </Head>
      <main style={{minHeight:'100vh',display:'flex',alignItems:'center',justifyContent:'center',flexDirection:'column',background:'#000',color:'#fff',padding:'2rem',textAlign:'center'}}>
        <h1 style={{fontSize:'1.5rem',marginBottom:'1rem'}}>Opening signup…</h1>
        <p style={{opacity:0.7,marginBottom:'1.5rem'}}>If you are not redirected, click below.</p>
        <a href={target} style={{background:'#FFCB47',color:'#111',padding:'0.75rem 1.25rem',borderRadius:'0.75rem',fontWeight:600,textDecoration:'none'}}>Create Account</a>
        <noscript>
          <p style={{marginTop:'1.5rem'}}>JavaScript disabled. <a href={target}>Continue to signup</a>.</p>
        </noscript>
      </main>
    </>
  );
}
