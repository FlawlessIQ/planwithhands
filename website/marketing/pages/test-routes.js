import { useEffect } from 'react'

export default function TestRoutes() {
  useEffect(() => {
    // Test app routes
    const testRoutes = async () => {
      const routes = [
        '/login',
        '/create_account',
        '/user_dashboard',
        '/admin_dashboard'
      ];
      
      console.log('Testing app routes...');
      for (const route of routes) {
        try {
          const response = await fetch(`https://plan-with-hands.web.app${route}`, {
            method: 'HEAD',
            mode: 'no-cors'
          });
          console.log(`Route ${route}: ${response.status || 'OK'}`);
        } catch (e) {
          console.log(`Route ${route}: Error - ${e.message}`);
        }
      }
    };
    
    testRoutes();
  }, []);

  return (
    <main style={{padding: '2rem', fontFamily: 'monospace'}}>
      <h1>Route Testing Page</h1>
      <p>Check browser console for route test results.</p>
      
      <div style={{marginTop: '2rem'}}>
        <h2>Direct Links (Test These):</h2>
        <ul>
          <li><a href="https://plan-with-hands.web.app/login?src=test" target="_blank">Login Direct</a></li>
          <li><a href="https://plan-with-hands.web.app/create_account?src=test" target="_blank">Signup Direct</a></li>
          <li><a href="https://plan-with-hands.web.app/" target="_blank">Home (Auth Gate)</a></li>
        </ul>
      </div>
      
      <div style={{marginTop: '2rem'}}>
        <h2>Current URL Info:</h2>
        <p>Location: {typeof window !== 'undefined' ? window.location.href : 'SSR'}</p>
        <p>User Agent: {typeof navigator !== 'undefined' ? navigator.userAgent : 'SSR'}</p>
      </div>
    </main>
  );
}
