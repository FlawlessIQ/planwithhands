import '../styles/globals.css'
import '../styles/mobile-optimizations.css'
import Head from 'next/head'
import Layout from '../components/Layout'

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#1C1C1E" />
        <meta name="description" content="Hands — get hands on every task with checklists, documents, insights, and team messaging." />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
      </Head>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </>
  )
}
