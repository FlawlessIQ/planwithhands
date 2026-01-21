"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateCoupon = exports.backfillSubscriptionQuantityForOrg = exports.getSubscriptionData = exports.createBillingPortalSession = exports.cancelSubscription = exports.updateSubscriptionQuantity = exports.getStripePublishableKeyHttp = exports.getStripePublishableKey = exports.getCheckoutSessionStatus = exports.createEmbeddedCheckoutSession = exports.createSetupIntentForCustomer = exports.createSubscriptionElements = exports.ensureStripeCustomer = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const stripe_1 = __importDefault(require("stripe"));
const firestore_1 = require("@google-cloud/firestore");
let stripe = null;
function getStripe() {
    if (stripe)
        return stripe;
    const secret = process.env.STRIPE_SECRET_KEY;
    if (!secret) {
        throw new functions.https.HttpsError("failed-precondition", "STRIPE_SECRET_KEY is not configured");
    }
    stripe = new stripe_1.default(secret, {
        apiVersion: "2025-06-30.basil",
    });
    return stripe;
}
// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
function addCallable(name, handler) {
    return functions
        .region("us-central1")
        .https.onCall(async (data, context) => {
        try {
            return await handler(data, context);
        }
        catch (error) {
            console.error(`Error in ${name}:`, error?.stack || error);
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            // Surface underlying message to client for easier debugging
            throw new functions.https.HttpsError("internal", error?.message || "An error occurred processing your request");
        }
    });
}
async function ensureCustomer(orgId, email) {
    const orgRef = db.collection("organizations").doc(orgId);
    const orgDoc = await orgRef.get();
    let customerId = orgDoc.exists ? orgDoc.data()?.stripeCustomerId : null;
    if (!customerId) {
        const customer = await getStripe().customers.create({
            email,
            metadata: { orgId },
        });
        customerId = customer.id;
        // Use set with merge to create the org doc if it doesn't exist
        await orgRef.set({
            stripeCustomerId: customerId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    return customerId;
}
exports.ensureStripeCustomer = addCallable("ensureStripeCustomer", async (data) => {
    const { orgId, email } = data;
    if (!orgId || !email) {
        throw new functions.https.HttpsError("invalid-argument", "orgId and email are required");
    }
    const customerId = await ensureCustomer(orgId, email);
    return { customerId };
});
exports.createSubscriptionElements = addCallable("createSubscriptionElements", async (data) => {
    const { orgId, priceId, email, quantity = 1, trialDays, couponId } = data;
    if (!orgId || !priceId || !email) {
        throw new functions.https.HttpsError("invalid-argument", "orgId, priceId and email are required");
    }
    const customerId = await ensureCustomer(orgId, email);
    // Build subscription params with optional discount
    const subParams = {
        customer: customerId,
        items: [{ price: priceId, quantity }],
        payment_behavior: "default_incomplete",
        payment_settings: { save_default_payment_method: "on_subscription" },
        trial_period_days: trialDays || undefined,
        expand: ["latest_invoice.payment_intent"],
        metadata: { orgId },
        // IMPORTANT: Use discounts array for coupons on Subscriptions API
        ...(couponId ? { discounts: [{ coupon: couponId }] } : {}),
    };
    const subscription = await getStripe().subscriptions.create(subParams);
    const invoice = subscription.latest_invoice;
    const paymentIntent = invoice?.payment_intent;
    // When a free trial is applied or the first invoice totals $0, Stripe may not create a PaymentIntent.
    // In that case we return the subscription id and a null clientSecret so the client can treat it as success.
    const clientSecret = paymentIntent?.client_secret || null;
    // For free trials or when no payment is required, create a SetupIntent to save payment method
    let setupClientSecret;
    if (!clientSecret) {
        try {
            const setupIntent = await getStripe().setupIntents.create({
                customer: customerId,
                usage: "off_session",
                payment_method_types: ["card"],
                metadata: { orgId, subscriptionId: subscription.id },
            });
            setupClientSecret = setupIntent.client_secret || undefined;
        }
        catch (setupErr) {
            console.warn('[createSubscriptionElements] Failed to create SetupIntent for payment method saving:', setupErr);
        }
    }
    // Persist subscription status immediately so the app can react without waiting for webhooks
    try {
        const subStatus = subscription.status; // e.g., 'trialing', 'active', 'incomplete'
        const trialEnd = subscription.trial_end;
        const orgRef = db.collection('organizations').doc(orgId);
        await orgRef.collection('stripe').doc('subscription').set({
            status: subStatus,
            subscriptionId: subscription.id,
            stripeCustomerId: subscription.customer,
            priceId,
            quantity,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(trialEnd ? { trialEnd } : {}),
        }, { merge: true });
        // Mirror a simple status to settings.subscriptionStatus for legacy readers
        const mapped = subStatus === 'trialing' ? 'trial' : subStatus;
        const settingsUpdate = { subscriptionStatus: mapped };
        if (trialEnd)
            settingsUpdate.trialEnds = admin.firestore.Timestamp.fromMillis(trialEnd * 1000);
        await orgRef.set({ settings: settingsUpdate }, { merge: true });
    }
    catch (persistErr) {
        console.error('[createSubscriptionElements] Failed to persist subscription snapshot:', persistErr);
    }
    return {
        subscriptionId: subscription.id,
        clientSecret,
        setupClientSecret,
    };
});
exports.createSetupIntentForCustomer = addCallable("createSetupIntentForCustomer", async (data) => {
    const { orgId } = data;
    if (!orgId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId is required");
    }
    const orgRef = db.collection("organizations").doc(orgId);
    const orgDoc = await orgRef.get();
    const email = (orgDoc.exists ? orgDoc.data()?.email : undefined) || "";
    const customerId = await ensureCustomer(orgId, email);
    const setupIntent = await getStripe().setupIntents.create({
        customer: customerId,
        usage: "off_session",
        payment_method_types: ["card"],
    });
    if (!setupIntent.client_secret) {
        throw new functions.https.HttpsError("internal", "Failed to create setup intent");
    }
    return { clientSecret: setupIntent.client_secret };
});
exports.createEmbeddedCheckoutSession = addCallable("createEmbeddedCheckoutSession", async (data) => {
    const { orgId, priceId, quantity = 1, trialDays, returnBaseUrl, couponId } = data;
    if (!orgId || !priceId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId and priceId are required");
    }
    if (!/^price_/.test(priceId)) {
        throw new functions.https.HttpsError("invalid-argument", `Invalid priceId: ${priceId}`);
    }
    const orgRef = db.collection("organizations").doc(orgId);
    const snap = await orgRef.get();
    const email = (snap.exists ? snap.data()?.email : undefined) || "";
    const customerId = await ensureCustomer(orgId, email);
    // Use env var (dotenv) by default
    let APP_BASE_URL = process.env.APP_BASE_URL;
    // Allow client-provided base URL (used by web app) to drive return URL
    if (returnBaseUrl) {
        APP_BASE_URL = returnBaseUrl;
    }
    if (!APP_BASE_URL) {
        throw new functions.https.HttpsError("failed-precondition", "APP_BASE_URL is not configured");
    }
    try {
        console.log("[createEmbeddedCheckoutSession] Params", { orgId, priceId, quantity, trialDays, returnBaseUrl, couponId, APP_BASE_URL });
        const baseParams = {
            ui_mode: "embedded",
            mode: "subscription",
            customer: customerId,
            customer_update: { address: "auto", shipping: "auto" },
            line_items: [{ price: priceId, quantity }],
            subscription_data: {
                trial_period_days: trialDays || undefined,
                metadata: { orgId },
            },
            payment_method_types: ["card"],
            // Ensure payment method is collected even if first invoice is $0 (trial)
            payment_method_collection: 'always',
            return_url: `${APP_BASE_URL}/#/billing/checkout-complete?session_id={CHECKOUT_SESSION_ID}`,
            automatic_tax: { enabled: true },
        };
        // IMPORTANT: Stripe requires choosing ONE: allow_promotion_codes OR discounts
        const sessionParams = (couponId
            ? { ...baseParams, discounts: [{ coupon: couponId }] }
            : { ...baseParams, allow_promotion_codes: true });
        const session = await getStripe().checkout.sessions.create(sessionParams);
        if (!session.client_secret) {
            throw new functions.https.HttpsError("internal", "Missing client_secret on session");
        }
        return { client_secret: session.client_secret, sessionId: session.id };
    }
    catch (err) {
        console.error("[createEmbeddedCheckoutSession] Stripe error:", err?.message, err?.code, err);
        throw new functions.https.HttpsError("internal", err?.message || "Failed to create embedded session");
    }
});
exports.getCheckoutSessionStatus = addCallable("getCheckoutSessionStatus", async (data) => {
    const { sessionId } = data;
    if (!sessionId) {
        throw new functions.https.HttpsError("invalid-argument", "sessionId is required");
    }
    const session = await getStripe().checkout.sessions.retrieve(sessionId);
    return {
        status: session.status,
        paymentStatus: session.payment_status,
        subscriptionId: session.subscription,
    };
});
exports.getStripePublishableKey = addCallable("getStripePublishableKey", async () => {
    // Safe to expose publishable key
    const pk = process.env.STRIPE_PUBLISHABLE_KEY;
    if (!pk) {
        throw new functions.https.HttpsError('failed-precondition', 'Stripe publishable key is not configured');
    }
    return { publishableKey: pk };
});
// HTTP variant with explicit CORS for local development and non-callable clients
exports.getStripePublishableKeyHttp = functions
    .region('us-central1')
    .https.onRequest((req, res) => {
    const origin = req.headers.origin;
    res.set('Access-Control-Allow-Origin', origin || '*');
    res.set('Vary', 'Origin');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        const pk = process.env.STRIPE_PUBLISHABLE_KEY;
        if (!pk) {
            res.status(500).json({ error: 'Stripe publishable key is not configured' });
            return;
        }
        res.status(200).json({ publishableKey: pk });
    }
    catch (e) {
        res.status(500).json({ error: e?.message || 'Internal error' });
    }
});
exports.updateSubscriptionQuantity = addCallable("updateSubscriptionQuantity", async (data) => {
    const { orgId, subscriptionId, newQuantity } = data;
    if (!orgId || !subscriptionId || !newQuantity || newQuantity <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid parameters");
    }
    const subscription = await getStripe().subscriptions.retrieve(subscriptionId);
    if (!subscription.items.data[0]) {
        throw new functions.https.HttpsError("not-found", "No subscription items found");
    }
    const itemId = subscription.items.data[0].id;
    await getStripe().subscriptionItems.update(itemId, {
        quantity: newQuantity,
        proration_behavior: "create_prorations",
    });
    const updatedSubscription = await getStripe().subscriptions.retrieve(subscriptionId);
    return {
        quantity: newQuantity,
        status: updatedSubscription.status,
        current_period_end: updatedSubscription.current_period_end,
    };
});
exports.cancelSubscription = addCallable("cancelSubscription", async (data) => {
    const { orgId, subscriptionId } = data;
    if (!orgId || !subscriptionId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId and subscriptionId are required");
    }
    await getStripe().subscriptions.update(subscriptionId, {
        cancel_at_period_end: true,
    });
    return { cancel_at_period_end: true };
});
exports.createBillingPortalSession = addCallable("createBillingPortalSession", async (data) => {
    const { orgId } = data;
    if (!orgId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId is required");
    }
    const orgRef = db.collection("organizations").doc(orgId);
    const orgDoc = await orgRef.get();
    const email = (orgDoc.exists ? orgDoc.data()?.email : undefined) || "";
    const customerId = await ensureCustomer(orgId, email);
    // Prefer configured base URL to ensure we land back in the correct environment
    const returnBase = process.env.APP_BASE_URL || "https://plan-with-hands.web.app";
    const portalSession = await getStripe().billingPortal.sessions.create({
        customer: customerId,
        return_url: `${returnBase}/#/settings`,
    });
    return { url: portalSession.url };
});
exports.getSubscriptionData = addCallable("getSubscriptionData", async (data) => {
    const { orgId } = data;
    if (!orgId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId is required");
    }
    const subscriptionDoc = await db
        .collection("organizations")
        .doc(orgId)
        .collection("stripe")
        .doc("subscription")
        .get();
    if (!subscriptionDoc.exists || !subscriptionDoc.data()?.subscriptionId) {
        return {};
    }
    const { subscriptionId } = subscriptionDoc.data();
    const subscription = await getStripe().subscriptions.retrieve(subscriptionId, {
        expand: ["latest_invoice", "default_payment_method"],
    });
    const result = {
        status: subscription.status,
        current_period_end: subscription.current_period_end,
        quantity: subscription.items.data[0]?.quantity || 1,
    };
    if (subscription.latest_invoice) {
        const invoice = subscription.latest_invoice;
        result.latest_invoice_status = invoice.status;
    }
    if (subscription.default_payment_method) {
        const paymentMethod = subscription.default_payment_method;
        if (paymentMethod.card) {
            result.default_payment_method_last4 = paymentMethod.card.last4;
            result.brand = paymentMethod.card.brand;
        }
    }
    return result;
});
// Admin/backfill: Force Stripe subscription quantity to match intended location count
exports.backfillSubscriptionQuantityForOrg = addCallable("backfillSubscriptionQuantityForOrg", async (data) => {
    const { orgId } = data;
    if (!orgId) {
        throw new functions.https.HttpsError("invalid-argument", "orgId is required");
    }
    const orgRef = db.collection("organizations").doc(orgId);
    const orgDoc = await orgRef.get();
    if (!orgDoc.exists) {
        throw new functions.https.HttpsError("not-found", `Organization ${orgId} not found`);
    }
    const subDoc = await orgRef.collection("stripe").doc("subscription").get();
    if (!subDoc.exists || !subDoc.data()?.subscriptionId) {
        return { updated: false };
    }
    const subscriptionId = subDoc.data().subscriptionId;
    // Determine intended quantity: prefer intendedLocationQuantity, fallback to current locations count, default 1
    let intendedQty = orgDoc.data()?.intendedLocationQuantity || 0;
    if (!intendedQty || intendedQty <= 0) {
        const locSnap = await orgRef.collection("locations").get();
        intendedQty = locSnap.size > 0 ? locSnap.size : 1;
    }
    const subscription = await getStripe().subscriptions.retrieve(subscriptionId);
    const item = subscription.items.data[0];
    const beforeQty = item?.quantity || 1;
    if (beforeQty === intendedQty) {
        // Still write back to Firestore if missing
        await orgRef.collection("stripe").doc("subscription").set({ quantity: intendedQty }, { merge: true });
        return { updated: false, before: beforeQty, after: intendedQty, subscriptionId };
    }
    const updated = await getStripe().subscriptions.update(subscriptionId, {
        items: [{ id: item.id, quantity: intendedQty }],
    });
    await orgRef.collection("stripe").doc("subscription").set({
        quantity: intendedQty,
        status: updated.status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { updated: true, before: beforeQty, after: intendedQty, subscriptionId };
});
exports.validateCoupon = addCallable("validateCoupon", async (data) => {
    const { couponCode } = data;
    console.log("=== COUPON VALIDATION START (TypeScript) ===");
    console.log("Input couponCode:", couponCode);
    if (!couponCode) {
        console.log("ERROR: No coupon code provided");
        throw new functions.https.HttpsError("invalid-argument", "couponCode is required");
    }
    try {
        console.log("Validating coupon/promo code:", couponCode);
        let coupon = null;
        // First, try to find it as a promotion code
        try {
            console.log("Trying as promotion code...");
            const promoCodes = await getStripe().promotionCodes.list({
                code: couponCode,
                limit: 1
            });
            if (promoCodes.data.length > 0) {
                console.log("Found as promotion code!");
                const promoCode = promoCodes.data[0];
                console.log("Promotion code details:", JSON.stringify(promoCode, null, 2));
                // Check if promotion code is active
                if (!promoCode.active) {
                    console.log("Promotion code is not active");
                    return {
                        success: false,
                        error: "Promotion code is not active",
                    };
                }
                // Get the underlying coupon
                coupon = promoCode.coupon;
                console.log("Underlying coupon:", JSON.stringify(coupon, null, 2));
            }
        }
        catch (promoError) {
            console.log("Error checking promotion codes:", promoError.message);
        }
        // If not found as promotion code, try as direct coupon ID
        if (!coupon) {
            try {
                console.log("Trying as direct coupon ID...");
                coupon = await getStripe().coupons.retrieve(couponCode);
                console.log("Found as direct coupon!");
            }
            catch (couponError) {
                console.log("Error retrieving coupon:", couponError.message);
            }
        }
        if (!coupon) {
            console.log("No coupon or promotion code found");
            return {
                success: false,
                error: "Coupon code not found",
            };
        }
        console.log("Final coupon for validation:", JSON.stringify(coupon, null, 2));
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
        }
        else {
            console.log("Coupon is not valid or expired:", couponCode);
            const result = {
                success: false,
                error: "Coupon is not valid or has expired",
            };
            console.log("Returning error result:", JSON.stringify(result, null, 2));
            return result;
        }
    }
    catch (error) {
        console.error("=== COUPON VALIDATION ERROR ===");
        console.error("Error validating coupon:", error);
        console.error("Error message:", error.message);
        console.error("Error type:", error.type);
        console.error("Error code:", error.code);
        const result = {
            success: false,
            error: "Failed to validate coupon code",
        };
        console.log("Returning generic error result:", JSON.stringify(result, null, 2));
        console.log("=== COUPON VALIDATION END ===");
        return result;
    }
});
