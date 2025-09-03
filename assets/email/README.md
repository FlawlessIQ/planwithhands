Invite email assets and instructions

This folder contains an email-friendly branded invite template and instructions for preparing the official store badges.

Files to add
- appstore-badge.png        -> Official Apple badge (1x PNG)
- appstore-badge@2x.png    -> Official Apple badge (2x retina PNG)
- playstore-badge.png       -> Official Google Play badge (1x PNG)
- playstore-badge@2x.png    -> Official Google Play badge (2x retina PNG)

Where to get them
- Apple App Store marketing & badge guidelines:
  https://developer.apple.com/app-store/marketing/guidelines/
  Use the "Download on the App Store" badge; export PNG at 1x and 2x sizes.

- Google Play badge assets:
  https://play.google.com/intl/en_us/badges/
  Download the "Get it on Google Play" badge PNG and export 1x/2x.

Naming & hosting
- Name the files exactly as above and place them in this folder. If you host these on your CDN, update the `src` and `srcset` URLs in `invite_branded.html`.
- Use PNG for email compatibility. Do not use SVGs inside email templates.

Commit
- This folder is tracked in git. After adding the PNGs, commit the files with a message like "Add email store badges and invite template".

Testing
- Use SendGrid/SES preview or send to a test address to verify rendering across clients (Gmail, Outlook, Apple Mail).
