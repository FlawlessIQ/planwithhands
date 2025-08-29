import '../styles/globals.css'
import Head from 'next/head'
import Layout from '../components/Layout'

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        <meta name="theme-color" content="#1C1C1E" />
        <meta name="description" content="Hands — run every shift on rails with checklists, documents, insights, and team messaging." />
      </Head>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </>
  )
}
