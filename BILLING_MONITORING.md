# BILLING MONITORING CHECKLIST

## Daily Monitoring (While on Spark Plan)
- [ ] Check Firebase Console quotas daily
- [ ] Monitor for any quota warnings
- [ ] Watch for unexpected usage spikes

## Set Up Alerts
1. **Firebase Console → Project Settings → Usage and billing**
2. **Set budget alerts** for when you upgrade back to Blaze
3. **Monitor daily usage** patterns

## Safe Usage Practices
- **Avoid testing** functions that write to database heavily
- **Use emulator** for function testing when possible
- **Small test datasets** only
- **Monitor logs** for any unusual patterns

## Before Re-enabling onGeneralNotificationCreated
1. Test thoroughly in Firebase emulator
2. Deploy to test organization first
3. Monitor for 24 hours with minimal usage
4. Gradually scale up testing

## Recovery Plan
If Firebase Support helps:
1. Upgrade back to Blaze plan carefully
2. Re-enable the fixed function
3. Test admin messaging with single notification
4. Update client code to use userNotifications collection
5. Monitor closely for first week
