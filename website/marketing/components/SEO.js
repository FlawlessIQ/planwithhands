import Head from 'next/head'

export default function SEO({
  title = "Plan With Hands - Restaurant Operations Management Software",
  description = "Transform restaurant operations with Hands - digital checklists, team messaging, training documents, and real-time insights. No hardware needed. Start your free trial today.",
  canonical = "https://planwithhands.com/",
  // Prefer a dedicated hands OG image sized for social previews (1200x630).
  // If you don't have this file deployed yet, create `/public/images/hands-og-1200x630.png`
  // and deploy alongside the other images.
  ogImage = "https://planwithhands.com/images/hands-og-1200x630.png",
  structuredData = null,
  keywords = "restaurant management, digital checklists, restaurant operations, team communication, food service software, restaurant technology, operational excellence"
}) {
  const defaultStructuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "Plan With Hands",
    "alternateName": "Hands App",
    "description": description,
    "url": "https://planwithhands.com",
    "applicationCategory": "BusinessApplication",
    "operatingSystem": "iOS, Android, Web",
    "offers": {
      "@type": "Offer",
      "price": "49.99",
      "priceCurrency": "USD",
      "priceSpecification": {
        "@type": "UnitPriceSpecification",
        "price": "49.99",
        "priceCurrency": "USD",
        "unitText": "MONTH"
      }
    },
    "provider": {
      "@type": "Organization",
      "name": "Plan With Hands",
      "url": "https://planwithhands.com",
      "logo": {
        "@type": "ImageObject",
  // Use the larger favicon as the structured-data logo to improve crawl visibility.
  "url": "https://planwithhands.com/images/favicon-1024.png",
  "width": 1024,
  "height": 1024
      }
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "ratingCount": "127"
    }
  }

  return (
    <Head>
      {/* Basic Meta Tags */}
      <title>{title}</title>
      <meta name="description" content={description} />
      <meta name="keywords" content={keywords} />
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
      <meta name="theme-color" content="#1C1C1E" />
      <meta name="author" content="Plan With Hands" />
      
      {/* Canonical URL */}
      <link rel="canonical" href={canonical} />
      
      {/* Open Graph / Facebook */}
      <meta property="og:type" content="website" />
      <meta property="og:url" content={canonical} />
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:image" content={ogImage} />
      <meta property="og:image:width" content="1200" />
      <meta property="og:image:height" content="630" />
      <meta property="og:site_name" content="Plan With Hands" />
      <meta property="og:locale" content="en_US" />
      
      {/* Twitter Card */}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:url" content={canonical} />
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:image" content={ogImage} />
      <meta name="twitter:creator" content="@planwithhands" />
      
      {/* Apple specific */}
      <meta name="apple-mobile-web-app-capable" content="yes" />
      <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
      <meta name="apple-mobile-web-app-title" content="Plan With Hands" />
      
      {/* Favicon and App Icons */}
      <link rel="icon" type="image/x-icon" href="/favicon.ico" />
      <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png" />
      <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png" />
      <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png" />
      <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
      <link rel="manifest" href="/manifest.json" />
      
      {/* Performance Preloads */}
      <link rel="preload" href="/app-demo.mp4" as="video" type="video/mp4" />
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      
      {/* Structured Data */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(structuredData || defaultStructuredData)
        }}
      />
      
      {/* Additional SEO Tags */}
      <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1" />
      <meta name="googlebot" content="index, follow" />
      <link rel="sitemap" type="application/xml" href="/sitemap.xml" />
    </Head>
  )
}
