# Domain Configuration Guide for planwithhands.com

## Overview
This guide helps you configure the `planwithhands.com` domain to serve both:
- Marketing website (Next.js) on the main domain
- Flutter web app on app routes (`/login`, `/create_account`, etc.)

## Current Setup
- **Firebase Project**: plan-with-hands
- **Marketing Site**: planwithhands-marketing.web.app
- **Flutter App**: plan-with-hands.web.app  
- **Target Domain**: planwithhands.com

## Step 1: Firebase Console Domain Configuration

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/project/plan-with-hands/hosting
   - Click on "Add custom domain"

2. **Add planwithhands.com**
   - Enter domain: `planwithhands.com`
   - Select site: `planwithhands-marketing` (this will be the primary site)
   - Follow DNS verification steps

3. **Configure DNS Records**
   Add these DNS records in your domain provider (where you bought planwithhands.com):
   ```
   Type: A
   Name: @
   Value: [Firebase will provide IP addresses]
   
   Type: A  
   Name: www
   Value: [Same Firebase IP addresses]
   ```

## Step 2: Route Configuration

The Firebase hosting configuration is set up to:

### Marketing Website Routes (Next.js)
- `/` - Homepage
- `/about` - About page  
- `/pricing` - Pricing page
- `/contact` - Contact page
- `/how-it-works` - How it works
- `/features` - Features page

### App Routes (Flutter)
- `/login` - Login page (Flutter app)
- `/create_account` - Sign up page (Flutter app)  
- `/sign_in` - Alternative sign in (Flutter app)
- `/app/**` - All app routes (Flutter app)

### Automatic Redirects
- `/signup` → `/login` (301 redirect)
- `/register` → `/create_account` (301 redirect)

## Step 3: Deployment Commands

### Build and Deploy Everything
```bash
# Run from project root
./scripts/build-and-deploy.sh
```

### Deploy Only Marketing Site
```bash
cd website/marketing
npm run build
cd ../..
firebase deploy --only hosting:planwithhands-marketing
```

### Deploy Only Flutter App
```bash
flutter build web --web-renderer html --base-href "/" --release
firebase deploy --only hosting:hands-app
```

## Step 4: Testing

### After deployment, test these URLs:

**Marketing Site** (should load Next.js pages):
- https://planwithhands.com/
- https://planwithhands.com/about
- https://planwithhands.com/pricing
- https://planwithhands.com/contact

**App Routes** (should load Flutter app):  
- https://planwithhands.com/login
- https://planwithhands.com/create_account
- https://planwithhands.com/sign_in

## Step 5: SSL Certificate

Firebase automatically provisions SSL certificates for custom domains. After adding your domain:
1. Wait 24-48 hours for full propagation
2. Certificate status will show as "Active" in Firebase Console
3. Both HTTP and HTTPS will work, with HTTP redirecting to HTTPS

## Troubleshooting

### Domain Not Working
- Check DNS propagation: https://dnschecker.org/
- Verify DNS records match Firebase requirements
- Wait up to 24 hours for full propagation

### App Routes Not Working
- Clear browser cache
- Check Firebase hosting configuration in firebase.json
- Verify Flutter build completed successfully

### SSL Issues
- Wait 24-48 hours after domain verification
- Check certificate status in Firebase Console
- Try accessing via HTTPS directly

## Security Notes

- All routes automatically redirect HTTP to HTTPS
- Flutter app routes are authenticated via Firebase Auth
- Marketing site is static and served via CDN
- Domain is verified and owned through Firebase

## Support

If issues persist:
1. Check Firebase Console for deployment status
2. Review browser network tab for 404/500 errors  
3. Contact Firebase Support for domain verification issues
4. Check Flutter web compatibility for app-specific issues
