import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";
import {Firestore} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});
const RECENT_CANCEL_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const OLD_INACTIVE_WINDOW_MS = 45 * 24 * 60 * 60 * 1000;
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

let stripe: Stripe | null = null;
function getStripe(): Stripe {
  if (stripe) return stripe;
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    throw new functions.https.HttpsError("failed-precondition", "STRIPE_SECRET_KEY is not configured");
  }
  stripe = new Stripe(secret, {apiVersion: "2025-06-30.basil"});
  return stripe;
}

function addCallable<T = any, R = any>(
  name: string,
  handler: (data: T, context: functions.https.CallableContext) => Promise<R>
): functions.HttpsFunction {
  return functions.region("us-central1").https.onCall(async (data: T, context) => {
    try {
      return await handler(data, context);
    } catch (error: any) {
      console.error(`[${name}]`, error?.stack || error);
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError("internal", error?.message || "CRM request failed");
    }
  });
}

async function requirePlatformUser(context: functions.https.CallableContext) {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }
  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data() || {};
  if (user.platformAccess !== true) {
    throw new functions.https.HttpsError("permission-denied", "Platform CRM access required");
  }
  return {
    uid,
    email: (user.emailAddress || user.email || user.userEmail || context.auth?.token.email || "").toString(),
    platformRole: (user.platformRole || "support").toString(),
  };
}

function toMillis(value: any): number | null {
  if (!value) return null;
  if (typeof value === "number") return value * (value > 100000000000 ? 1 : 1000);
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value.seconds) return value.seconds * 1000;
  return null;
}

function currencyFromCents(cents?: number | null, currency = "usd") {
  if (cents == null) return "$0";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency.toUpperCase(),
    maximumFractionDigits: 0,
  }).format(cents / 100);
}

async function countQuery(query: FirebaseFirestore.Query): Promise<number> {
  const snap = await query.get();
  return snap.size;
}

function monthlyMultiplier(price: Stripe.Price): number {
  const recurring = price.recurring;
  if (!recurring) return 1;
  const intervalCount = recurring.interval_count || 1;
  switch (recurring.interval) {
  case "year":
    return 1 / (12 * intervalCount);
  case "month":
    return 1 / intervalCount;
  case "week":
    return 52 / (12 * intervalCount);
  case "day":
    return 365 / (12 * intervalCount);
  default:
    return 1;
  }
}

function getSubscriptionMrrCents(subscription: Stripe.Subscription): number {
  return Math.round(subscription.items.data.reduce((total, item) => {
    const unitAmount = item.price.unit_amount || 0;
    const quantity = item.quantity || 1;
    return total + (unitAmount * quantity * monthlyMultiplier(item.price));
  }, 0));
}

function discountToData(discount: string | Stripe.Discount | undefined | null) {
  if (!discount || typeof discount === "string") return null;
  return {
    id: discount.id,
    couponId: discount.coupon.id,
    couponName: discount.coupon.name || "",
    percentOff: discount.coupon.percent_off ?? null,
    amountOff: discount.coupon.amount_off ?? null,
    currency: discount.coupon.currency || "usd",
    duration: discount.coupon.duration,
    end: discount.end ? discount.end * 1000 : null,
    promotionCodeId: typeof discount.promotion_code === "string" ? discount.promotion_code : discount.promotion_code?.id || "",
  };
}

function applyPercentDiscounts(cents: number, discounts: Array<string | Stripe.Discount>): number {
  return discounts.reduce((value, discount) => {
    const data = discountToData(discount);
    const percentOff = Number(data?.percentOff || 0);
    if (percentOff <= 0) return value;
    return value * Math.max(0, 1 - percentOff / 100);
  }, cents);
}

function getSubscriptionNetMrrCents(subscription: Stripe.Subscription, grossMrrCents: number): number {
  let itemNetMrr = subscription.items.data.reduce((total, item) => {
    const unitAmount = item.price.unit_amount || 0;
    const quantity = item.quantity || 1;
    const gross = unitAmount * quantity * monthlyMultiplier(item.price);
    const discounts = Array.isArray(item.discounts) ? item.discounts : [];
    return total + applyPercentDiscounts(gross, discounts);
  }, 0);

  itemNetMrr = applyPercentDiscounts(itemNetMrr, Array.isArray(subscription.discounts) ? subscription.discounts : []);

  const latestInvoice = subscription.latest_invoice as Stripe.Invoice | null;
  const hasDiscount = [
    ...(Array.isArray(subscription.discounts) ? subscription.discounts : []),
    ...subscription.items.data.flatMap((item) => Array.isArray(item.discounts) ? item.discounts : []),
  ].some((discount) => discountToData(discount) != null);

  if (hasDiscount && latestInvoice?.total === 0) return 0;
  return Math.max(0, Math.round(itemNetMrr || grossMrrCents));
}

function getSubscriptionDiscounts(subscription: Stripe.Subscription) {
  const discounts = [
    ...(Array.isArray(subscription.discounts) ? subscription.discounts : []),
    ...subscription.items.data.flatMap((item) => Array.isArray(item.discounts) ? item.discounts : []),
  ].map(discountToData).filter((value): value is NonNullable<ReturnType<typeof discountToData>> => value != null);

  return Array.from(new Map(discounts.map((discount) => [discount.id, discount])).values());
}

function getSubscriptionQuantity(subscription: Stripe.Subscription): number {
  return subscription.items.data.reduce((total, item) => total + (item.quantity || 0), 0);
}

function isCanceledStatus(status: string): boolean {
  return ["canceled", "cancelled", "ended"].includes(status);
}

function isBillableStatus(status: string): boolean {
  return ["active", "trialing", "past_due"].includes(status);
}

async function retrieveLiveSubscription(
  subscriptionId: string,
): Promise<Stripe.Subscription | null> {
  try {
    return await getStripe().subscriptions.retrieve(subscriptionId, {
      expand: ["latest_invoice", "discounts", "items.data.discounts"],
    });
  } catch (error) {
    console.warn("[CRM] Stripe subscription lookup failed", {subscriptionId, error});
    return null;
  }
}

async function findLiveSubscription(org: Record<string, any>, subscription: Record<string, any>): Promise<Stripe.Subscription | null> {
  const subscriptionId = (subscription.subscriptionId || org.stripeSubscriptionId || "").toString();
  if (subscriptionId) {
    return retrieveLiveSubscription(subscriptionId);
  }

  const customerId = (org.stripeCustomerId || subscription.stripeCustomerId || "").toString();
  if (!customerId) return null;

  try {
    const subscriptions = await getStripe().subscriptions.list({
      customer: customerId,
      status: "all",
      limit: 10,
      expand: ["data.latest_invoice", "data.discounts", "data.items.data.discounts"],
    });
    return subscriptions.data
      .sort((a, b) => {
        const priority = (status: string) => ["active", "trialing", "past_due"].includes(status) ? 0 : 1;
        return priority(a.status) - priority(b.status) || b.created - a.created;
      })[0] || null;
  } catch (error) {
    console.warn("[CRM] Stripe customer subscriptions lookup failed", {customerId, error});
    return null;
  }
}

function buildLiveBillingSummary(subscription: Stripe.Subscription | null) {
  if (!subscription) return null;
  const latestInvoice = subscription.latest_invoice as Stripe.Invoice | null;
  const currentPeriodEnds = subscription.items.data
    .map((item) => item.current_period_end)
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => b - a)[0] || null;
  const currentPeriodStarts = subscription.items.data
    .map((item) => item.current_period_start)
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => b - a)[0] || null;
  const grossMrrCents = getSubscriptionMrrCents(subscription);
  const netMrrCents = isCanceledStatus(subscription.status) ? 0 : getSubscriptionNetMrrCents(subscription, grossMrrCents);
  const quantity = getSubscriptionQuantity(subscription);
  const discounts = getSubscriptionDiscounts(subscription);

  return {
    status: subscription.status,
    subscriptionId: subscription.id,
    stripeCustomerId: typeof subscription.customer === "string" ? subscription.customer : subscription.customer?.id || "",
    currentPeriodStart: currentPeriodStarts ? currentPeriodStarts * 1000 : null,
    currentPeriodEnd: currentPeriodEnds ? currentPeriodEnds * 1000 : null,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
    cancelAt: subscription.cancel_at ? subscription.cancel_at * 1000 : null,
    canceledAt: subscription.canceled_at ? subscription.canceled_at * 1000 : null,
    endedAt: subscription.ended_at ? subscription.ended_at * 1000 : null,
    created: subscription.created * 1000,
    quantity,
    grossMrrCents,
    grossMrrLabel: currencyFromCents(grossMrrCents, subscription.currency),
    netMrrCents,
    netMrrLabel: currencyFromCents(netMrrCents, subscription.currency),
    mrrCents: netMrrCents,
    mrrLabel: currencyFromCents(netMrrCents, subscription.currency),
    discounts,
    discountLabel: discounts.length
      ? discounts.map((discount) => discount.percentOff ? `${discount.percentOff}% off` : discount.couponName || discount.couponId).join(", ")
      : "",
    currency: subscription.currency || "usd",
    latestInvoiceUrl: latestInvoice?.hosted_invoice_url || "",
    latestInvoicePdf: latestInvoice?.invoice_pdf || "",
    latestInvoiceTotal: latestInvoice?.total ?? null,
    latestInvoiceAmountDue: latestInvoice?.amount_due ?? null,
    latestInvoiceAmountPaid: latestInvoice?.amount_paid ?? null,
    latestInvoiceCreated: latestInvoice?.created ? latestInvoice.created * 1000 : null,
  };
}

async function logCrmAction(actor: {uid: string; email: string; platformRole: string}, action: string, data: Record<string, any>) {
  await db.collection("platform_crm").doc("audit").collection("logs").add({
    actorUid: actor.uid,
    actorEmail: actor.email,
    platformRole: actor.platformRole,
    action,
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function buildOrgSummary(orgDoc: FirebaseFirestore.QueryDocumentSnapshot) {
  const orgId = orgDoc.id;
  const org = orgDoc.data() || {};
  const orgRef = db.collection("organizations").doc(orgId);
  const [subscriptionSnap, locationCount, userSnap] = await Promise.all([
    orgRef.collection("stripe").doc("subscription").get(),
    countQuery(orgRef.collection("locations")),
    db.collection("users").where("organizationId", "==", orgId).get(),
  ]);

  const users = userSnap.docs.map((doc) => doc.data());
  const adminUser = users.find((user) => (user.userRole || 0) >= 2) || users[0] || {};
  const subscription = subscriptionSnap.data() || {};
  const liveSubscription = await findLiveSubscription(org, subscription);
  const liveBilling = buildLiveBillingSummary(liveSubscription);
  const quantity = Number(liveBilling?.quantity || subscription.quantity || org.intendedLocationQuantity || locationCount || 0);
  const status = (liveBilling?.status || subscription.status || org.subscriptionStatus || org.settings?.subscriptionStatus || "unknown").toString();
  const unitAmount = Number(subscription.unitAmount || subscription.amount || 0);
  const grossMrrCents = liveBilling?.grossMrrCents ?? (unitAmount > 0 ? unitAmount * Math.max(quantity, 1) : 0);
  const netMrrCents = liveBilling?.netMrrCents ?? grossMrrCents;
  const canceledAt = liveBilling?.canceledAt || liveBilling?.endedAt || toMillis(subscription.canceledAt || subscription.cancelledAt || subscription.endedAt || org.canceledAt || org.cancelledAt);
  const recentlyCanceled = isCanceledStatus(status) && canceledAt != null && canceledAt >= Date.now() - RECENT_CANCEL_WINDOW_MS;
  const isArchived = org.crmArchived === true;
  const excludedFromMetrics = isArchived || org.crmExcludeFromMetrics === true;
  const excludedFromMrr = excludedFromMetrics || org.crmExcludeFromMrr === true || !isBillableStatus(status);
  const mrrCents = excludedFromMrr ? 0 : netMrrCents;
  const lastLogin = users
    .map((user) => toMillis(user.lastLogin))
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => b - a)[0] || null;
  const trialEnd = toMillis(subscription.trialEnd || org.trialEndsAt || org.settings?.trialEnds);
  const nextInvoiceAt = liveBilling?.currentPeriodEnd || toMillis(subscription.current_period_end || subscription.currentPeriodEnd || subscription.nextInvoiceAt);
  const paymentIssue = ["past_due", "unpaid", "incomplete", "incomplete_expired"].includes(status);
  const oldInactive = isCanceledStatus(status)
    ? !recentlyCanceled
    : lastLogin
      ? lastLogin < Date.now() - OLD_INACTIVE_WINDOW_MS
      : !isBillableStatus(status) && toMillis(org.createdAt) != null && (toMillis(org.createdAt) as number) < Date.now() - OLD_INACTIVE_WINDOW_MS;
  const healthStatus = paymentIssue
    ? "payment_issue"
    : recentlyCanceled
      ? "recently_canceled"
      : isCanceledStatus(status)
        ? "canceled"
        : trialEnd && trialEnd < Date.now() + 7 * 24 * 60 * 60 * 1000 && status === "trialing"
      ? "trial_ending"
      : oldInactive || (lastLogin && lastLogin < Date.now() - 14 * 24 * 60 * 60 * 1000)
        ? "inactive"
        : "healthy";

  return {
    organizationId: orgId,
    organizationName: org.organizationName || org.name || "Unnamed restaurant",
    businessType: org.businessType || "",
    ownerEmail: adminUser.emailAddress || adminUser.email || org.email || "",
    ownerName: [adminUser.firstName, adminUser.lastName].filter(Boolean).join(" "),
    subscriptionStatus: status,
    stripeCustomerId: org.stripeCustomerId || subscription.stripeCustomerId || "",
    stripeSubscriptionId: liveBilling?.subscriptionId || org.stripeSubscriptionId || subscription.subscriptionId || "",
    quantity,
    locationCount,
    userCount: users.length,
    activeUserCount7d: users.filter((user) => {
      const last = toMillis(user.lastLogin);
      return last != null && last >= Date.now() - 7 * 24 * 60 * 60 * 1000;
    }).length,
    grossMrrCents,
    grossMrrLabel: currencyFromCents(grossMrrCents, liveBilling?.currency || "usd"),
    netMrrCents,
    netMrrLabel: currencyFromCents(netMrrCents, liveBilling?.currency || "usd"),
    mrrCents,
    mrrLabel: currencyFromCents(mrrCents, liveBilling?.currency || "usd"),
    excludedFromMrr,
    excludedFromMetrics,
    oldInactive,
    recentlyCanceled,
    crmArchived: isArchived,
    crmAccountType: org.crmAccountType || (excludedFromMrr ? "test" : "customer"),
    crmArchiveReason: org.crmArchiveReason || "",
    billingSource: liveBilling ? "stripe_live" : unitAmount > 0 ? "firestore_snapshot" : "missing_price",
    discountLabel: liveBilling?.discountLabel || "",
    discounts: liveBilling?.discounts || [],
    trialEndsAt: trialEnd,
    nextInvoiceAt,
    canceledAt,
    cancelAt: liveBilling?.cancelAt || null,
    cancelAtPeriodEnd: liveBilling?.cancelAtPeriodEnd || false,
    lastActivityAt: lastLogin,
    healthStatus,
    stripeSubscriptionCreatedAt: liveBilling?.created || null,
    latestInvoiceCreatedAt: liveBilling?.latestInvoiceCreated || null,
    latestInvoiceTotalCents: liveBilling?.latestInvoiceTotal ?? null,
    createdAt: toMillis(org.createdAt),
  };
}

export const getCrmDashboard = addCallable<{limit?: number; includeArchived?: boolean}, any>("getCrmDashboard", async (data, context) => {
  const actor = await requirePlatformUser(context);
  const limit = Math.min(Math.max(Number(data?.limit || 100), 1), 250);
  const includeArchived = data?.includeArchived === true;
  const orgSnap = await db.collection("organizations").orderBy("createdAt", "desc").limit(limit).get();
  const allCustomers = await Promise.all(orgSnap.docs.map((doc) => buildOrgSummary(doc)));
  const customers = includeArchived ? allCustomers : allCustomers.filter((customer) => customer.crmArchived !== true);
  const metricCustomers = allCustomers.filter((customer) => customer.excludedFromMetrics !== true);
  const metrics = metricCustomers.reduce(
    (acc, customer) => {
      acc.totalCustomers += 1;
      acc.totalUsers += customer.userCount;
      acc.totalLocations += customer.locationCount;
      acc.mrrCents += customer.mrrCents;
      acc.activeCustomers += ["active", "trialing", "trial"].includes(customer.subscriptionStatus) ? 1 : 0;
      acc.paymentIssues += customer.healthStatus === "payment_issue" ? 1 : 0;
      acc.trialsEnding += customer.healthStatus === "trial_ending" ? 1 : 0;
      acc.recentlyCanceled += customer.recentlyCanceled ? 1 : 0;
      acc.oldInactive += customer.oldInactive ? 1 : 0;
      acc.newSignups7d += customer.createdAt != null && customer.createdAt >= Date.now() - SEVEN_DAYS_MS ? 1 : 0;
      acc.newSignups30d += customer.createdAt != null && customer.createdAt >= Date.now() - THIRTY_DAYS_MS ? 1 : 0;
      acc.stoppedSubscriptions7d += customer.canceledAt != null && customer.canceledAt >= Date.now() - SEVEN_DAYS_MS ? 1 : 0;
      acc.stoppedSubscriptions30d += customer.canceledAt != null && customer.canceledAt >= Date.now() - THIRTY_DAYS_MS ? 1 : 0;
      return acc;
    },
    {
      totalCustomers: 0,
      activeCustomers: 0,
      totalUsers: 0,
      totalLocations: 0,
      mrrCents: 0,
      paymentIssues: 0,
      trialsEnding: 0,
      recentlyCanceled: 0,
      oldInactive: 0,
      newSignups7d: 0,
      newSignups30d: 0,
      stoppedSubscriptions7d: 0,
      stoppedSubscriptions30d: 0,
    }
  );
  await logCrmAction(actor, "viewed_crm_dashboard", {customerCount: customers.length, includeArchived});
  return {
    ...metrics,
    archivedCustomers: allCustomers.filter((customer) => customer.crmArchived === true).length,
    excludedFromMrrCustomers: allCustomers.filter((customer) => customer.excludedFromMrr === true && customer.crmArchived !== true).length,
    mrrLabel: currencyFromCents(metrics.mrrCents),
    customers,
  };
});

export const getCrmOrganization = addCallable<{organizationId: string}, any>("getCrmOrganization", async (data, context) => {
  const actor = await requirePlatformUser(context);
  const orgId = data.organizationId;
  if (!orgId) throw new functions.https.HttpsError("invalid-argument", "organizationId is required");

  const orgRef = db.collection("organizations").doc(orgId);
  const orgDoc = await orgRef.get();
  if (!orgDoc.exists) throw new functions.https.HttpsError("not-found", "Organization not found");

  const [locationsSnap, usersSnap, checklistSnap, subscriptionSnap] = await Promise.all([
    orgRef.collection("locations").get(),
    db.collection("users").where("organizationId", "==", orgId).get(),
    orgRef.collection("checklist_templates").get(),
    orgRef.collection("stripe").doc("subscription").get(),
  ]);

  const org = orgDoc.data() || {};
  const subscription = subscriptionSnap.data() || {};
  const liveSubscription = buildLiveBillingSummary(await findLiveSubscription(org, subscription));

  await logCrmAction(actor, "viewed_crm_organization", {organizationId: orgId});
  return {
    organization: {
      organizationId: orgId,
      ...org,
      createdAt: toMillis(org.createdAt),
      updatedAt: toMillis(org.updatedAt),
    },
    locations: locationsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    users: usersSnap.docs.map((doc) => {
      const user = doc.data();
      return {
        id: doc.id,
        firstName: user.firstName || "",
        lastName: user.lastName || "",
        email: user.emailAddress || user.email || user.userEmail || "",
        userRole: user.userRole || 0,
        isActive: user.isActive !== false,
        createdAt: toMillis(user.createdAt),
        updatedAt: toMillis(user.updatedAt),
        lastLogin: toMillis(user.lastLogin),
      };
    }),
    checklistTemplateCount: checklistSnap.size,
    subscription: {
      ...subscription,
      trialEnd: toMillis(subscription.trialEnd),
      currentPeriodEnd: toMillis(subscription.current_period_end || subscription.currentPeriodEnd),
    },
    liveSubscription,
  };
});

export const updateCrmOrganizationFlags = addCallable<{
  organizationId: string;
  archived?: boolean;
  excludeFromMrr?: boolean;
  excludeFromMetrics?: boolean;
  accountType?: string;
  reason?: string;
}, any>("updateCrmOrganizationFlags", async (data, context) => {
  const actor = await requirePlatformUser(context);
  const orgId = (data.organizationId || "").toString();
  if (!orgId) throw new functions.https.HttpsError("invalid-argument", "organizationId is required");

  const update: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (typeof data.archived === "boolean") {
    update.crmArchived = data.archived;
    update.crmArchivedAt = data.archived ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.delete();
    update.crmArchivedBy = data.archived ? actor.uid : admin.firestore.FieldValue.delete();
    update.crmArchiveReason = data.archived ? (data.reason || "Archived from CRM") : admin.firestore.FieldValue.delete();
    update.crmExcludeFromMetrics = data.archived ? true : data.excludeFromMetrics === true;
    update.crmExcludeFromMrr = data.archived ? true : data.excludeFromMrr === true;
  }
  if (typeof data.excludeFromMrr === "boolean") {
    update.crmExcludeFromMrr = data.excludeFromMrr;
  }
  if (typeof data.excludeFromMetrics === "boolean") {
    update.crmExcludeFromMetrics = data.excludeFromMetrics;
  }
  if (data.accountType) {
    update.crmAccountType = data.accountType;
  }
  if (data.reason && data.archived !== true) {
    update.crmFlagReason = data.reason;
  }

  await db.collection("organizations").doc(orgId).set(update, {merge: true});
  await logCrmAction(actor, "updated_crm_organization_flags", {
    organizationId: orgId,
    archived: data.archived ?? null,
    excludeFromMrr: data.excludeFromMrr ?? null,
    excludeFromMetrics: data.excludeFromMetrics ?? null,
    accountType: data.accountType || "",
    reason: data.reason || "",
  });
  return {ok: true};
});

export const listCrmPromotionCodes = addCallable<{}, any>("listCrmPromotionCodes", async (_data, context) => {
  await requirePlatformUser(context);
  const promoCodes = await getStripe().promotionCodes.list({limit: 100, expand: ["data.coupon"]});
  return {
    codes: promoCodes.data.map((promo) => {
      const maxRedemptions = promo.max_redemptions ?? null;
      const timesRedeemed = promo.times_redeemed || 0;
      const remainingRedemptions = maxRedemptions == null ? null : Math.max(maxRedemptions - timesRedeemed, 0);
      const expired = promo.expires_at ? promo.expires_at * 1000 < Date.now() : false;
      return {
        id: promo.id,
        code: promo.code,
        active: promo.active,
        statusLabel: promo.active && !expired ? "active" : expired ? "expired" : "inactive",
        couponId: promo.coupon.id,
        percentOff: promo.coupon.percent_off,
        amountOff: promo.coupon.amount_off,
        currency: promo.coupon.currency,
        duration: promo.coupon.duration,
        durationInMonths: promo.coupon.duration_in_months,
        firstTimeCustomersOnly: promo.restrictions?.first_time_transaction === true,
        campaign: promo.metadata?.campaign || promo.coupon.metadata?.campaign || "",
        maxRedemptions,
        timesRedeemed,
        remainingRedemptions,
        expiresAt: promo.expires_at ? promo.expires_at * 1000 : null,
        created: promo.created * 1000,
        redemptionLabel: maxRedemptions == null ? `${timesRedeemed} used` : `${timesRedeemed}/${maxRedemptions} used`,
      };
    }).sort((a, b) => (b.timesRedeemed - a.timesRedeemed) || (b.created - a.created)),
  };
});

export const createCrmPromotionCode = addCallable<
  {
    code: string;
    percentOff?: number;
    amountOff?: number;
    currency?: string;
    duration?: string;
    durationInMonths?: number;
    maxRedemptions?: number;
    expiresAt?: number;
    campaign?: string;
    firstTimeCustomersOnly?: boolean;
  },
  any
>("createCrmPromotionCode", async (data, context) => {
  const actor = await requirePlatformUser(context);
  const code = (data.code || "").trim().toUpperCase();
  if (!code) throw new functions.https.HttpsError("invalid-argument", "code is required");
  const percentOff = Number(data.percentOff || 0);
  const amountOff = Number(data.amountOff || 0);
  if (percentOff <= 0 && amountOff <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Provide percentOff or amountOff");
  }
  if (percentOff > 100) {
    throw new functions.https.HttpsError("invalid-argument", "percentOff cannot be greater than 100");
  }
  const duration = (data.duration || "once") as Stripe.CouponCreateParams.Duration;
  if (!["once", "repeating", "forever"].includes(duration)) {
    throw new functions.https.HttpsError("invalid-argument", "duration must be once, repeating, or forever");
  }
  const durationInMonths = Number(data.durationInMonths || 0);
  if (duration === "repeating" && durationInMonths <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "durationInMonths is required for repeating discounts");
  }
  const expiresAtSeconds = data.expiresAt ? Math.floor(Number(data.expiresAt) / 1000) : undefined;
  if (expiresAtSeconds && expiresAtSeconds <= Math.floor(Date.now() / 1000)) {
    throw new functions.https.HttpsError("invalid-argument", "expiresAt must be in the future");
  }

  const coupon = await getStripe().coupons.create({
    name: data.campaign ? `${data.campaign} - ${code}` : code,
    duration,
    duration_in_months: duration === "repeating" ? durationInMonths : undefined,
    percent_off: percentOff > 0 ? percentOff : undefined,
    amount_off: amountOff > 0 ? amountOff : undefined,
    currency: amountOff > 0 ? (data.currency || "usd") : undefined,
    metadata: {
      campaign: data.campaign || "CRM",
      createdBy: actor.uid,
    },
  });
  const promotionCode = await getStripe().promotionCodes.create({
    coupon: coupon.id,
    code,
    max_redemptions: data.maxRedemptions ? Number(data.maxRedemptions) : undefined,
    expires_at: expiresAtSeconds,
    restrictions: data.firstTimeCustomersOnly === true ? {first_time_transaction: true} : undefined,
    metadata: {
      campaign: data.campaign || "CRM",
      createdBy: actor.uid,
    },
  });

  await db.collection("platform_crm").doc("campaign_codes").collection("codes").doc(promotionCode.id).set({
    code,
    stripeCouponId: coupon.id,
    stripePromotionCodeId: promotionCode.id,
    campaign: data.campaign || "CRM",
    duration,
    durationInMonths: duration === "repeating" ? durationInMonths : null,
    expiresAt: data.expiresAt || null,
    maxRedemptions: data.maxRedemptions ? Number(data.maxRedemptions) : null,
    firstTimeCustomersOnly: data.firstTimeCustomersOnly === true,
    createdBy: actor.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    active: true,
  }, {merge: true});
  await logCrmAction(actor, "created_promotion_code", {
    code,
    stripePromotionCodeId: promotionCode.id,
    duration,
    expiresAt: data.expiresAt || null,
    maxRedemptions: data.maxRedemptions || null,
    firstTimeCustomersOnly: data.firstTimeCustomersOnly === true,
  });
  return {id: promotionCode.id, code: promotionCode.code, couponId: coupon.id, active: promotionCode.active};
});
