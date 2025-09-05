import '../styles/globals.css'
import '../styles/mobile-optimizations.css'
import Head from 'next/head'
import Layout from '../components/Layout'

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        {/* Viewport and Basic Meta */}
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#1C1C1E" />
        <meta name="description" content="Transform restaurant operations with Hands - digital checklists, team messaging, training documents, and real-time insights. No hardware needed. Start your free trial today." />
        <meta name="keywords" content="restaurant management, digital checklists, restaurant operations, team communication, food service software, restaurant technology, operational excellence" />
        <meta name="author" content="Plan With Hands" />
        
        {/* Open Graph / Facebook */}
        <meta property="og:type" content="website" />
        <meta property="og:url" content="https://planwithhands.com/" />
        <meta property="og:title" content="Plan With Hands - Get hands on every task" />
        <meta property="og:description" content="Transform restaurant operations with digital checklists, team messaging, training documents, and real-time insights. No hardware needed." />
        <meta property="og:image" content="https://planwithhands.com/images/favicon-192.png" />
        <meta property="og:site_name" content="Plan With Hands" />
        
        {/* Twitter */}
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:url" content="https://planwithhands.com/" />
        <meta name="twitter:title" content="Plan With Hands - Get hands on every task" />
        <meta name="twitter:description" content="Transform restaurant operations with digital checklists, team messaging, training documents, and real-time insights. No hardware needed." />
        <meta name="twitter:image" content="https://planwithhands.com/images/favicon-192.png" />
        
        {/* Apple specific */}
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Plan With Hands" />
        
        {/* Canonical URL - will be overridden by individual pages */}
        <link rel="canonical" href="https://planwithhands.com/" />
        
        {/* Favicon - Multiple sizes for better Google recognition */}
        <link rel="icon" type="image/x-icon" href="/favicon.ico" />
        <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png" />
        <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png" />
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
        
        {/* Web App Manifest */}
        <link rel="manifest" href="/manifest.json" />
        
        {/* Sitemap */}
        <link rel="sitemap" type="application/xml" href="/sitemap.xml" />
        
        
        {/* Structured Data for Google */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "Organization",
              name: "Plan With Hands",
              alternateName: "Hands",
              url: "https://planwithhands.com",
              logo: {
                "@type": "ImageObject",
                url: "https://planwithhands.com/images/favicon-192.png",
                width: 192,
                height: 192
              },
              description: "Transform restaurant operations with digital checklists, team messaging, training documents, and real-time insights. No hardware needed.",
              foundingDate: "2024",
              industry: "Restaurant Technology",
              sameAs: [],
              contactPoint: {
                "@type": "ContactPoint",
                contactType: "customer service",
                url: "https://planwithhands.com/contact"
              }
            })
          }}
        />
        
        {/* Default title - will be overridden by individual pages */}
        <title>Plan With Hands - Get hands on every task</title>
      </Head>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </>
  )
}
