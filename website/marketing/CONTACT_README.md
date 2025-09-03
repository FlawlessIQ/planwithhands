Contact form and SendGrid setup

What I changed
- Added `pages/api/contact.js` which accepts POST { name, email, subject, message } and sends via SendGrid.
- Updated `pages/contact.js` to POST to `/api/contact` and show success/error messages.

Environment
- Create `website/marketing/.env.local` with the variables from `.env.local.example`.
- For local testing without a SendGrid key, set `DEV_FAKE_SEND=true` in `.env.local` and the API will log the payload and return success.

Production
- Set `SENDGRID_API_KEY` in your deployment provider (Vercel, Firebase, etc.). Ensure `SENDGRID_FROM` is a verified sender in your SendGrid account.

Testing locally
1. cd website/marketing
2. npm install
3. Create `.env.local` matching `.env.local.example`.
4. npm run dev
5. Open http://localhost:3000/contact, submit the form.

Notes
- The email subject is prefixed with "[Info question]" and the body explicitly notes this is an info question and not an in-app support request.
- The API includes a lightweight in-memory rate limiter (per-IP) to mitigate spam. For production use a proper rate limiter (Redis or provider-level).
- Do not commit `.env.local` or your SendGrid API key to git.
