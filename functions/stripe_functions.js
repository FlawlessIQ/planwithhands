const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret);

admin.initializeApp();

// Create Stripe Checkout Session
exports.createCheckoutSession = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId, email, priceId} = data;
      const orgRef = admin.firestore().collection("organizations").doc(orgId);
      const orgDoc = await orgRef.get();

      let customerId = orgDoc.exists && orgDoc.data().stripeCustomerId;
      if (!customerId) {
        const customer = await stripe.customers.create({email, metadata: {orgId}});
        customerId = customer.id;
        await orgRef.collection("stripe").doc("customer").set({
          stripeCustomerId: customerId,
          email: email,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ["card"],
        line_items: [{price: priceId, quantity: 1}],
        mode: "subscription",
        success_url: "https://plan-with-hands.web.app/dashboard?payment=success",
        cancel_url: "https://plan-with-hands.web.app/pricing?payment=cancelled",
        allow_promotion_codes: true,
        subscription_data: {
          trial_period_days: 14,
          metadata: {orgId},
        },
        metadata: {orgId},
      });

      return {url: session.url};
    });

// Create Stripe Billing Portal Session
exports.createBillingPortalSession = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId} = data;
      const orgRef = admin.firestore().collection("organizations").doc(orgId);
      const orgDoc = await orgRef.get();
      if (!orgDoc.exists || !orgDoc.data().stripeCustomerId) {
        throw new functions.https.HttpsError("not-found", "Stripe customer not found");
      }
      const portalSession = await stripe.billingPortal.sessions.create({
        customer: orgDoc.data().stripeCustomerId,
        return_url: "https://plan-with-hands.web.app/settings",
      });
      return {url: portalSession.url};
    });

// Cancel Subscription Function
exports.cancelSubscription = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId} = data;

      // Get subscription info from Firestore
      const subscriptionDoc = await admin.firestore()
          .collection("organizations")
          .doc(orgId)
          .collection("stripe")
          .doc("subscription")
          .get();

      if (!subscriptionDoc.exists || !subscriptionDoc.data().subscriptionId) {
        throw new functions.https.HttpsError("not-found", "No active subscription found");
      }

      const {subscriptionId} = subscriptionDoc.data();

      try {
        // Cancel the subscription at period end
        await stripe.subscriptions.update(subscriptionId, {
          cancel_at_period_end: true,
        });

        // Update Firestore to mark cancellation requested
        await admin.firestore()
            .collection("organizations")
            .doc(orgId)
            .collection("stripe")
            .doc("subscription")
            .update({
              cancellationRequested: true,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        return {success: true, message: "Subscription will be canceled at the end of the current period"};
      } catch (error) {
        throw new functions.https.HttpsError("internal", `Failed to cancel subscription: ${error.message}`);
      }
    });

// Stripe Webhook Handler
exports.stripeWebhook = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      const sig = req.headers["stripe-signature"];
      let event;
      try {
        event = stripe.webhooks.constructEvent(req.rawBody, sig, functions.config().stripe.webhook_secret);
      } catch (err) {
        return res.status(400).send(`Webhook Error: ${err.message}`);
      }

      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const orgId = session.metadata.orgId;

        if (session.mode === "subscription" && session.subscription) {
          // Retrieve the subscription to get trial details
          const subscription = await stripe.subscriptions.retrieve(session.subscription);

          const subscriptionData = {
            status: subscription.status, // "trialing" or "active"
            subscriptionId: subscription.id,
            stripeCustomerId: subscription.customer,
            priceId: subscription.items.data[0].price.id,
            cancellationRequested: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Add trial end if subscription is trialing
          if (subscription.status === "trialing" && subscription.trial_end) {
            subscriptionData.trialEnd = subscription.trial_end;
          }

          await admin.firestore()
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .set(subscriptionData, {merge: true});
        }
      }

      if (event.type === "customer.subscription.updated") {
        const subscription = event.data.object;
        const orgId = subscription.metadata.orgId;

        if (orgId) {
          const subscriptionData = {
            status: subscription.status,
            subscriptionId: subscription.id,
            stripeCustomerId: subscription.customer,
            priceId: subscription.items.data[0].price.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Add trial end if subscription is trialing
          if (subscription.status === "trialing" && subscription.trial_end) {
            subscriptionData.trialEnd = subscription.trial_end;
          }

          // Preserve cancellationRequested flag
          const existingDoc = await admin.firestore()
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .get();

          if (existingDoc.exists) {
            subscriptionData.cancellationRequested = existingDoc.data().cancellationRequested || false;
          }

          await admin.firestore()
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .set(subscriptionData, {merge: true});
        }
      }

      res.json({received: true});
    });
