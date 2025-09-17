/* Minimal Firebase Messaging service worker placeholder to avoid MIME type errors.
   If you need background notifications on web, replace this with the real FCM logic.
*/
self.addEventListener('install', (event) => {
  // Activate worker immediately after installation
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});

// Optional: no-op push handler to avoid console noise if FCM is not configured yet
self.addEventListener('push', (event) => {
  // Intentionally left blank. Your app may implement background handling here.
});
