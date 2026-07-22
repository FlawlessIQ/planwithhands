# Daily Summary Email Configuration

## SendGrid API Key
To enable daily summary emails, you need to set the SendGrid API key as an environment variable:

### For Development (Flutter run):
```bash
flutter run --dart-define=SENDGRID_API_KEY=your_sendgrid_api_key_here
```

### For Production (Cloud Functions):
Add the SendGrid API key to your Firebase environment config:
```bash
firebase functions:config:set sendgrid.api_key="your_sendgrid_api_key_here"
```

### Getting a SendGrid API Key:
1. Sign up for SendGrid at https://sendgrid.com/
2. Go to Settings > API Keys
3. Create a new API key with "Mail Send" permissions
4. Copy the API key and use it in your environment configuration

### Email Template:
The daily summary email template is located at:
- `daily_summary_email_template.html` (full template)
- `lib/services/daily_summary_email_service.dart` (service implementation)

### Testing:
To test email functionality:
1. Set your SendGrid API key in the environment
2. Update the `_fromEmail` in `DailySummaryEmailService` to use a verified sender
3. Make sure your SendGrid account is configured with proper sender authentication