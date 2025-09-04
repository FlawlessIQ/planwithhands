import Head from 'next/head'
import { useEffect } from 'react'

export default function AppLoginRedirect() {
  const target = 'https://plan-with-hands.web.app/login?src=marketing_redirect';
  useEffect(() => {
    // Attempt immediate hard navigation
    window.location.replace(target);
    // Fallback after 800ms if still on this origin
    const t = setTimeout(() => {
      if (window.location.href.includes('/app-login')) {
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
        <h1 style={{fontSize:'1.5rem',marginBottom:'1rem'}}>Taking you to the app…</h1>
        <p style={{opacity:0.7,marginBottom:'1.5rem'}}>If you are not redirected automatically, use the button below.</p>
        <a href={target} style={{background:'#FFCB47',color:'#111',padding:'0.75rem 1.25rem',borderRadius:'0.75rem',fontWeight:600,textDecoration:'none'}}>Go to Login</a>
        <noscript>
          <p style={{marginTop:'1.5rem'}}>JavaScript disabled. <a href={target}>Continue to login</a>.</p>
        </noscript>
      </main>
    </>
  );
}
