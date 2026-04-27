const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");
const sgMail = require("@sendgrid/mail");

let _stripe;
function getStripe() {
  if (_stripe) return _stripe;
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "STRIPE_SECRET_KEY is not configured"
    );
  }
  _stripe = require("stripe")(secret);
  return _stripe;
}

// Proxy lets existing code keep using `stripe.*` without eagerly initializing at module-load.
const stripe = new Proxy(
  {},
  {
    get(_target, prop) {
      return getStripe()[prop];
    },
  },
);

// Create Stripe Checkout Session
exports.createCheckoutSession = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId, email, priceId, employeeCount} = data;

      // If employeeCount is provided, determine the appropriate price ID
      let finalPriceId = priceId;
      if (employeeCount !== undefined && !priceId) {
        // Use the correct price IDs from your Stripe account
        if (employeeCount <= 5) {
          finalPriceId = "price_1Ro45qFzroJ5o7DAeALdyIBt"; // 1-5 employees - Starter $29
        } else if (employeeCount <= 25) {
          finalPriceId = "price_1Ro45qFzroJ5o7DAQg8WqsXy"; // 11-25 employees - Growth $99
        } else if (employeeCount <= 50) {
          finalPriceId = "price_1Ro45qFzroJ5o7DAYLZBKLv0"; // 26-50 employees - Professional $179
        } else if (employeeCount <= 100) {
          finalPriceId = "price_1Ro45qFzroJ5o7DAdoRurKMi"; // 51-100 employees - Enterprise $299
        } else {
          // For 100+ employees, we should handle this differently
          throw new functions.https.HttpsError(
              "invalid-argument",
              "For 100+ employees, please contact us for custom pricing.",
          );
        }
      }

      if (!finalPriceId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Either priceId or employeeCount must be provided.",
        );
      }

      const orgRef = db.collection("organizations").doc(orgId);
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
  line_items: [{price: finalPriceId, quantity: data.quantity || 1}],
        mode: "subscription",
        success_url: "https://plan-with-hands.web.app/payment-success",
        cancel_url: "https://plan-with-hands.web.app/payment-cancelled",
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
      const orgRef = db.collection("organizations").doc(orgId);
      const orgDoc = await orgRef.get();

      try {
        // stripeCustomerId might be stored on the org doc or in nested stripe docs
        let stripeCustomerId = orgDoc.exists ? orgDoc.data().stripeCustomerId : null;

        if (!stripeCustomerId) {
          // Try organizations/{orgId}/stripe/customer
          const customerDoc = await orgRef.collection("stripe").doc("customer").get();
          if (customerDoc.exists && customerDoc.data().stripeCustomerId) {
            stripeCustomerId = customerDoc.data().stripeCustomerId;
          }
        }

        if (!stripeCustomerId) {
          // Try organizations/{orgId}/stripe/subscription
          const subDoc = await orgRef.collection("stripe").doc("subscription").get();
          if (subDoc.exists && subDoc.data().stripeCustomerId) {
            stripeCustomerId = subDoc.data().stripeCustomerId;
          }
        }

        if (!stripeCustomerId) {
          // As a fallback, create a customer now so we can open the portal.
          const orgName = orgDoc.exists && orgDoc.data().name ? orgDoc.data().name : `Org ${orgId}`;
          const customer = await stripe.customers.create({
            name: orgName,
            metadata: {orgId},
          });
          stripeCustomerId = customer.id;
          await orgRef.collection("stripe").doc("customer").set({
            stripeCustomerId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        // Prefer configured base URL if available
        const appBase = process.env.APP_BASE_URL || "https://plan-with-hands.web.app";
        const portalSession = await stripe.billingPortal.sessions.create({
          customer: stripeCustomerId,
          return_url: `${appBase}/#/settings`,
        });
        return {url: portalSession.url};
      } catch (err) {
        console.error("createBillingPortalSession error", err);
        throw new functions.https.HttpsError("internal", err.message || "Failed to open billing portal");
      }
    });

// Cancel Subscription Function
exports.cancelSubscription = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId} = data;

      // Get subscription info from Firestore
      const subscriptionDoc = await db
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
        await db
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
        const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
        if (!webhookSecret) {
          return res.status(500).send("STRIPE_WEBHOOK_SECRET is not configured");
        }
        event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
      } catch (err) {
        return res.status(400).send(`Webhook Error: ${err.message}`);
      }

  if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const orgId = session.metadata.orgId;
        
        console.log("Processing checkout.session.completed event for orgId:", orgId);
        console.log("Session mode:", session.mode);
        console.log("Has subscription:", !!session.subscription);

        if (session.mode === "subscription" && session.subscription) {
          console.log("Processing subscription creation for:", session.subscription);
          
          // Retrieve the subscription to get trial details
          const subscription = await stripe.subscriptions.retrieve(session.subscription);
          console.log("Retrieved subscription:", subscription.id, "status:", subscription.status);

          const subscriptionData = {
            status: subscription.status, // "trialing" or "active"
            subscriptionId: subscription.id,
            stripeCustomerId: subscription.customer,
            priceId: subscription.items.data[0].price.id,
            quantity: (subscription.items.data[0] && subscription.items.data[0].quantity) || 1,
            cancellationRequested: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Add trial end if subscription is trialing
          if (subscription.status === "trialing" && subscription.trial_end) {
            subscriptionData.trialEnd = subscription.trial_end;
          }

          await db
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .set(subscriptionData, {merge: true});

          // Also update the organization document for backward compatibility
          await db
              .collection("organizations")
              .doc(orgId)
              .update({
                subscriptionStatus: subscription.status,
                stripeSubscriptionId: subscription.id,
                stripeCustomerId: subscription.customer,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

          console.log("Subscription data saved to Firestore");

          // Send welcome email after successful subscription creation
          console.log("Calling sendWelcomeEmail function...");
          await sendWelcomeEmail(session, orgId, subscription);
          console.log("sendWelcomeEmail function completed");
        } else {
          console.log("Skipping welcome email - not a subscription or missing subscription ID");
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
            quantity: (subscription.items.data[0] && subscription.items.data[0].quantity) || 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Add trial end if subscription is trialing
          if (subscription.status === "trialing" && subscription.trial_end) {
            subscriptionData.trialEnd = subscription.trial_end;
          }

          // Preserve cancellationRequested flag
          const existingDoc = await db
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .get();

          if (existingDoc.exists) {
            subscriptionData.cancellationRequested = existingDoc.data().cancellationRequested || false;
          }

          await db
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .set(subscriptionData, {merge: true});

          // Also update the organization document for backward compatibility
          await db
              .collection("organizations")
              .doc(orgId)
              .update({
                subscriptionStatus: subscription.status,
                stripeSubscriptionId: subscription.id,
                stripeCustomerId: subscription.customer,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
        }
      }

      // Ensure default payment method and status when SetupIntent completes (Elements trial path)
      if (event.type === "setup_intent.succeeded") {
        const si = event.data.object;
        const customerId = si.customer;
        const paymentMethodId = si.payment_method;
        const orgId = si.metadata && si.metadata.orgId;
        const subscriptionId = si.metadata && si.metadata.subscriptionId;

        try {
          if (customerId && paymentMethodId) {
            try {
              await stripe.paymentMethods.attach(paymentMethodId, {customer: customerId});
            } catch (attachErr) {
              if (!(attachErr && attachErr.code === 'resource_already_exists')) {
                console.warn('paymentMethods.attach failed:', attachErr && attachErr.message);
              }
            }

            if (subscriptionId) {
              try {
                await stripe.subscriptions.update(subscriptionId, {default_payment_method: paymentMethodId});
              } catch (e) {
                console.warn('Failed setting default_payment_method on subscription:', e && e.message);
              }
            } else {
              try {
                await stripe.customers.update(customerId, {invoice_settings: {default_payment_method: paymentMethodId}});
              } catch (e) {
                console.warn('Failed setting default_payment_method on customer:', e && e.message);
              }
            }
          }

          if (orgId && subscriptionId) {
            const sub = await stripe.subscriptions.retrieve(subscriptionId);
            await db.collection('organizations').doc(orgId).collection('stripe').doc('subscription').set({
              status: sub.status,
              subscriptionId: sub.id,
              stripeCustomerId: sub.customer,
              priceId: sub.items.data[0] && sub.items.data[0].price && sub.items.data[0].price.id,
              quantity: (sub.items.data[0] && sub.items.data[0].quantity) || 1,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              ...(sub.trial_end ? {trialEnd: sub.trial_end} : {}),
            }, {merge: true});

            await db.collection('organizations').doc(orgId).set({
              subscriptionStatus: sub.status,
              stripeSubscriptionId: sub.id,
              stripeCustomerId: sub.customer,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});
          }
        } catch (err) {
          console.error('Error processing setup_intent.succeeded:', err);
        }
      }

      // Keep Firestore in sync when invoice is paid (e.g., after initial payment)
      if (event.type === "invoice.payment_succeeded") {
        const invoice = event.data.object;
        const subscriptionId = invoice.subscription;
        try {
          if (subscriptionId) {
            const sub = await stripe.subscriptions.retrieve(subscriptionId);
            const orgId = sub.metadata && sub.metadata.orgId;
            if (orgId) {
              await db.collection('organizations').doc(orgId).collection('stripe').doc('subscription').set({
                status: sub.status,
                subscriptionId: sub.id,
                stripeCustomerId: sub.customer,
                priceId: sub.items.data[0] && sub.items.data[0].price && sub.items.data[0].price.id,
                quantity: (sub.items.data[0] && sub.items.data[0].quantity) || 1,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                ...(sub.trial_end ? {trialEnd: sub.trial_end} : {}),
              }, {merge: true});

              await db.collection('organizations').doc(orgId).set({
                subscriptionStatus: sub.status,
                stripeSubscriptionId: sub.id,
                stripeCustomerId: sub.customer,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});
            }
          }
        } catch (err) {
          console.error('Error processing invoice.payment_succeeded:', err);
        }
      }

      // New: Handle subscription created events (Elements and direct API)
      if (event.type === "customer.subscription.created") {
        const subscription = event.data.object;
        const orgId = subscription.metadata?.orgId;

        console.log("Processing customer.subscription.created for orgId:", orgId);

        if (orgId) {
          const subscriptionData = {
            status: subscription.status,
            subscriptionId: subscription.id,
            stripeCustomerId: subscription.customer,
            priceId: subscription.items.data[0]?.price?.id,
            quantity: (subscription.items.data[0] && subscription.items.data[0].quantity) || 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          if (subscription.status === "trialing" && subscription.trial_end) {
            subscriptionData.trialEnd = subscription.trial_end;
          }

          // Preserve cancellationRequested if it exists already
          try {
            const existingDoc = await db
              .collection("organizations")
              .doc(orgId)
              .collection("stripe")
              .doc("subscription")
              .get();
            if (existingDoc.exists) {
              subscriptionData.cancellationRequested = existingDoc.data().cancellationRequested || false;
            }
          } catch (e) {
            console.warn("Unable to read existing subscription doc for preservation:", e?.message || e);
          }

          await db
            .collection("organizations")
            .doc(orgId)
            .collection("stripe")
            .doc("subscription")
            .set(subscriptionData, { merge: true });

          // Also update the organization document for backward compatibility
          await db
            .collection("organizations")
            .doc(orgId)
            .update({
              subscriptionStatus: subscription.status,
              stripeSubscriptionId: subscription.id,
              stripeCustomerId: subscription.customer,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

          console.log("Subscription created data saved to Firestore");

          // Send welcome email for newly created subscriptions
          try {
            await sendWelcomeEmail({ customer_details: {} }, orgId, subscription);
            console.log("Welcome email sent via subscription.created");
          } catch (e) {
            console.error("Failed sending welcome email on subscription.created:", e);
          }
        } else {
          console.log("subscription.created missing orgId metadata; skipping welcome email");
        }
      }

      res.json({received: true});
    });

// Create Subscription for Elements (Web)
exports.createSubscriptionElements = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId, email, priceId, quantity = 1, couponId} = data;

      if (!orgId || !email || !priceId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Missing required parameters: orgId, email, priceId"
        );
      }

      try {
        console.log("Creating Elements subscription for:", {orgId, email, priceId, quantity, couponId});

        const orgRef = db.collection("organizations").doc(orgId);
        const orgDoc = await orgRef.get();

        // Get or create customer
        let customerId = orgDoc.exists && orgDoc.data().stripeCustomerId;
        if (!customerId) {
          const customer = await stripe.customers.create({
            email,
            metadata: {orgId}
          });
          customerId = customer.id;
          await orgRef.collection("stripe").doc("customer").set({
            stripeCustomerId: customerId,
            email: email,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        // Create subscription with metadata including orgId
        const subscriptionParams = {
          customer: customerId,
          items: [{
            price: priceId,
            quantity: quantity,
          }],
          metadata: {
            orgId: orgId,
            email: email,
          },
          payment_behavior: 'default_incomplete',
          payment_settings: {
            save_default_payment_method: 'on_subscription',
          },
          expand: ['latest_invoice.payment_intent'],
        };

        // Add coupon if provided
        if (couponId) {
          subscriptionParams.coupon = couponId;
        }

        const subscription = await stripe.subscriptions.create(subscriptionParams);

        console.log("Subscription created with ID:", subscription.id);
        console.log("Subscription metadata:", subscription.metadata);

        // Return client secret for frontend payment confirmation
        const clientSecret = subscription.latest_invoice?.payment_intent?.client_secret;

        return {
          subscriptionId: subscription.id,
          clientSecret: clientSecret,
          status: subscription.status
        };

      } catch (error) {
        console.error("Error creating Elements subscription:", error);
        throw new functions.https.HttpsError(
            "internal",
            `Failed to create subscription: ${error.message}`
        );
      }
    });

// Update subscription quantity (e.g., number of locations)
exports.updateSubscription = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {orgId, subscriptionId, newQuantity} = data;
      if (!orgId || !subscriptionId || !newQuantity || newQuantity <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Missing or invalid parameters");
      }
      try {
        // First retrieve the subscription to get all necessary details
        const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
          expand: ['default_payment_method', 'latest_invoice.payment_intent'],
        });

        // Update the subscription with existing payment method and payment behavior
        const updated = await stripe.subscriptions.update(subscriptionId, {
          items: [{id: subscription.items.data[0].id, quantity: newQuantity}],
          default_payment_method: subscription.default_payment_method,
          payment_behavior: 'allow_incomplete_reuse_existing',
        });

        await db
            .collection("organizations")
            .doc(orgId)
            .collection("stripe")
            .doc("subscription")
            .set({
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              quantity: newQuantity,
              status: updated.status,
            }, {merge: true});
        return {success: true};
      } catch (error) {
        throw new functions.https.HttpsError("internal", `Failed to update subscription: ${error.message}`);
      }
    });

// Helper function to send welcome email after subscription creation
async function sendWelcomeEmail(session, orgId, subscription) {
  try {
    console.log("=== WELCOME EMAIL FUNCTION START ===");
    console.log("Sending welcome email for subscription:", subscription.id);
    console.log("Organization ID:", orgId);
    
    // Get SendGrid API key from environment
    const sendgridApiKey = process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
    console.log("SendGrid API key configured:", !!sendgridApiKey);
    
    if (!sendgridApiKey) {
      console.log("SendGrid API key not configured - skipping welcome email");
      return;
    }

    // Set SendGrid API key
    sgMail.setApiKey(sendgridApiKey);
    console.log("SendGrid API key set successfully");

    // Get organization details
    console.log("Fetching organization details for:", orgId);
    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) {
      console.log("Organization not found:", orgId);
      return;
    }

    const orgData = orgDoc.data();
    const orgName = orgData.organizationName || orgData.name || `Org ${orgId}`;
    // Derive created date from explicit field if present; fall back to server time
    const createdTs = orgData.createdAt || orgData.created || orgDoc.createTime || null;
    const createdDate = (() => {
      try {
        const d = createdTs && createdTs.toDate ? createdTs.toDate() : (createdTs instanceof Date ? createdTs : new Date());
        const fmt = new Intl.DateTimeFormat('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
        return fmt.format(d);
      } catch (_) { return new Date().toISOString().substring(0, 10); }
    })();
    console.log("Organization name:", orgName);

  // Get customer details from Stripe
    console.log("Retrieving Stripe customer:", subscription.customer);
    const customer = await stripe.customers.retrieve(subscription.customer);
    const customerEmail = customer.email || session.customer_details?.email;
    const customerName = customer.name || session.customer_details?.name || "Valued Customer";
    
    console.log("Customer email:", customerEmail);
    console.log("Customer name:", customerName);

    if (!customerEmail) {
      console.log("Customer email not found for subscription:", subscription.id);
      return;
    }

    // Prepare plan description from subscription
    let planType = "Hands – Location License";
    try {
      const item = subscription.items && subscription.items.data && subscription.items.data[0];
      const qty = (item && item.quantity) || 1;
      const interval = (item && item.price && item.price.recurring && item.price.recurring.interval) || 'month';
      const label = interval === 'year' ? 'Annual' : 'Monthly';
      planType = `${qty} Location${qty > 1 ? 's' : ''} (${label})`;
    } catch (e) {
      console.warn('Failed to compute planType:', e && e.message);
    }

    // Prepare welcome email with the correct dynamic template
    const templateId = "d-93870b1c6d6943419a15117c553858da";
    
    const templateData = {
      firstName: (customerName && customerName.split(' ')[0]) || customerName,
      orgName,
      email: customerEmail,
      adminEmail: customerEmail,
      temporaryPassword: "N/A",
      welcomeUrl: "https://plan-with-hands.web.app/login?src=marketing_redirect",
      webPortalUrl: "https://plan-with-hands.web.app/login?src=marketing_redirect",
      createdDate,
      planType,
    };
    
    const msg = {
      to: customerEmail,
      from: process.env.SENDGRID_FROM_EMAIL || "noreply@planwithhands.com",
      templateId: templateId,
      dynamicTemplateData: templateData,
    };

    console.log("Email configuration:");
    console.log("- To:", customerEmail);
    console.log("- Template ID:", templateId);
    console.log("- Template data:", JSON.stringify(templateData, null, 2));
    
    console.log("Sending welcome email...");
    const result = await sgMail.send(msg);
    console.log("Welcome email sent successfully!");
    console.log("SendGrid response status:", result[0].statusCode);
    console.log("=== WELCOME EMAIL FUNCTION END ===");

  } catch (error) {
    console.error("=== WELCOME EMAIL ERROR ===");
    console.error("Failed to send welcome email:", error);
    console.error("Error message:", error.message);
    if (error.response) {
      console.error("SendGrid error response:", error.response.body);
    }
    console.error("=== WELCOME EMAIL ERROR END ===");
    // Don't throw error to avoid failing the webhook
  }
}

// Validate Coupon Function
exports.validateCoupon = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const {couponCode} = data;
      
      console.log("=== COUPON VALIDATION START ===");
      console.log("Input couponCode:", couponCode);
      console.log("Data received:", JSON.stringify(data, null, 2));

      if (!couponCode) {
        console.log("ERROR: No coupon code provided");
        throw new functions.https.HttpsError("invalid-argument", "Coupon code is required");
      }

      try {
        console.log("Validating coupon:", couponCode);
        
        // Retrieve coupon from Stripe
        const coupon = await stripe.coupons.retrieve(couponCode);
        console.log("Stripe response:", JSON.stringify(coupon, null, 2));
        
        // Check if coupon is valid (not deleted and meets basic criteria)
        const isValid = coupon && 
                       !coupon.deleted && 
                       (!coupon.redeem_by || coupon.redeem_by * 1000 > Date.now()) &&
                       (!coupon.max_redemptions || !coupon.times_redeemed || coupon.times_redeemed < coupon.max_redemptions);
        
        console.log("Validation checks:");
        console.log("- Coupon exists:", !!coupon);
        console.log("- Not deleted:", !coupon?.deleted);
        console.log("- Redeem by check:", !coupon?.redeem_by || coupon.redeem_by * 1000 > Date.now());
        console.log("- Max redemptions check:", !coupon?.max_redemptions || !coupon?.times_redeemed || coupon.times_redeemed < coupon.max_redemptions);
        console.log("- Overall valid:", isValid);

        if (isValid) {
          console.log("Coupon is valid:", coupon.id);
          const result = {
            success: true,
            coupon: {
              id: coupon.id,
              percent_off: coupon.percent_off,
              amount_off: coupon.amount_off,
              currency: coupon.currency,
              name: coupon.name,
              duration: coupon.duration,
              duration_in_months: coupon.duration_in_months,
              times_redeemed: coupon.times_redeemed,
              max_redemptions: coupon.max_redemptions,
              redeem_by: coupon.redeem_by,
              valid: isValid,
            },
          };
          console.log("Returning success result:", JSON.stringify(result, null, 2));
          return result;
        } else {
          console.log("Coupon is not valid or expired:", couponCode);
          const result = {
            success: false,
            error: "Coupon is not valid or has expired",
          };
          console.log("Returning error result:", JSON.stringify(result, null, 2));
          return result;
        }
      } catch (error) {
        console.error("=== COUPON VALIDATION ERROR ===");
        console.error("Error validating coupon:", error);
        console.error("Error message:", error.message);
        console.error("Error type:", error.type);
        console.error("Error code:", error.code);
        
        // Handle specific Stripe errors
        if (error.type === "StripeInvalidRequestError" && error.code === "resource_missing") {
          const result = {
            success: false,
            error: "Coupon code not found",
          };
          console.log("Returning not found result:", JSON.stringify(result, null, 2));
          return result;
        }
        
        const result = {
          success: false,
          error: "Failed to validate coupon code",
        };
        console.log("Returning generic error result:", JSON.stringify(result, null, 2));
        console.log("=== COUPON VALIDATION END ===");
        return result;
      }
    });
