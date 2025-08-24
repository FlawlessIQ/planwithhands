// Firebase Cloud Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyC_bMJfH2D-BKJVqyMGjjQl1LqZW2FvNfA",
  authDomain: "planwithhands.firebaseapp.com",
  projectId: "planwithhands",
  storageBucket: "planwithhands.appspot.com",
  messagingSenderId: "467398659848",
  appId: "1:467398659848:web:6c862f53c5db0dffd80a62",
  measurementId: "G-74CE6M73BD"
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message.',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
