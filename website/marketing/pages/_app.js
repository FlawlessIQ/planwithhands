import '../styles/globals.css'
import '../styles/mobile-optimizations.css'
import Head from 'next/head'
import Layout from '../components/Layout'

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        {/* Performance Preloads */}
        <link rel="preload" href="/app-demo.mp4" as="video" type="video/mp4" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        
        {/* Default SEO (will be overridden by individual pages) */}
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#1C1C1E" />
        <meta name="author" content="Plan With Hands" />
        <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1" />
        <meta name="googlebot" content="index, follow" />
        
        {/* Apple specific */}
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Plan With Hands" />
        
        {/* Default Favicon and App Icons - Comprehensive set for all browsers and devices */}
        <link rel="icon" type="image/x-icon" href="/favicon.ico" />
        <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png" />
        <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png" />
        <link rel="icon" type="image/png" sizes="180x180" href="/images/favicon-180.png" />
        <link rel="icon" type="image/png" sizes="1024x1024" href="/images/favicon-1024.png" />
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
        
        {/* Additional icon sizes for better browser support */}
        <link rel="icon" type="image/png" sizes="192x192" href="/icon-192.png" />
        <link rel="icon" type="image/png" sizes="512x512" href="/icon-512.png" />
        
        {/* Microsoft tiles */}
        <meta name="msapplication-TileColor" content="#1C1C1E" />
        <meta name="msapplication-TileImage" content="/images/favicon-192.png" />
        
        {/* Safari Pinned Tab */}
        <link rel="mask-icon" href="/images/favicon-192.png" color="#1C1C1E" />
        
        {/* PWA Manifest */}
        <link rel="manifest" href="/manifest.json" />
        
        {/* Sitemap */}
        <link rel="sitemap" type="application/xml" href="/sitemap.xml" />
        
        {/* Default Organization Structured Data */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "Organization",
              "name": "Plan With Hands",
              "alternateName": "Hands",
              "url": "https://planwithhands.com",
              "logo": {
                "@type": "ImageObject",
                "url": "https://planwithhands.com/images/favicon-1024.png",
                "width": 1024,
                "height": 1024
              },
              "description": "Transform restaurant operations with digital checklists, team messaging, training documents, and real-time insights. No hardware needed.",
              "foundingDate": "2024",
              "industry": "Restaurant Technology",
              "sameAs": [],
              "contactPoint": {
                "@type": "ContactPoint",
                "contactType": "customer service", 
                "email": "support@planwithhands.com",
                "url": "https://planwithhands.com/contact"
              }
            })
          }}
        />
      </Head>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </>
  )
}
