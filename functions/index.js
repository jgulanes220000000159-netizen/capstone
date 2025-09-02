/* Cloud Functions for MangoSense notifications */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize admin SDK once
try {
  admin.app();
} catch (e) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Utility: send a notification to a list of device tokens
async function sendToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0)
    return { successCount: 0, failureCount: 0 };
  const response = await messaging.sendEachForMulticast(
    { tokens, ...payload },
    false
  );
  return response;
}

// Trigger 1: When a new scan request is created → notify experts
exports.notifyExpertsOnNewRequest = functions.firestore
  .document("scan_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const status = data.status || "pending";
    if (status !== "pending" && status !== "pending_review") return null;

    const userName = data.userName || "A farmer";
    const requestId = context.params.requestId;

    // Fetch expert tokens
    const expertsSnapshot = await db
      .collection("users")
      .where("role", "==", "expert")
      .get();

    const tokens = [];
    expertsSnapshot.forEach((doc) => {
      const u = doc.data() || {};
      if (u.fcmToken && typeof u.fcmToken === "string") tokens.push(u.fcmToken);
    });

    if (tokens.length === 0) return null;

    const title = "New review request";
    const body = `${userName} submitted a leaf scan for expert review.`;

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        type: "scan_request_created",
        requestId: String(requestId || ""),
        userName: String(userName || ""),
      },
    };

    await sendToTokens(tokens, payload);
    return null;
  });

// Trigger 2: When a scan request is reviewed/completed → notify the farmer
exports.notifyUserOnReviewCompleted = functions.firestore
  .document("scan_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeStatus = before.status || "";
    const afterStatus = after.status || "";

    // Only proceed when transitioning into completed/reviewed
    if (
      beforeStatus === afterStatus ||
      (afterStatus !== "completed" && afterStatus !== "reviewed")
    ) {
      return null;
    }

    const userId = after.userId || before.userId;
    if (!userId) return null;

    // Get farmer token
    const userDoc = await db.collection("users").doc(userId).get();
    const user = userDoc.exists ? userDoc.data() || {} : {};
    const token = user.fcmToken;
    if (!token) return null;

    const expertName = after.expertName || "An expert";
    const title = "Your review is ready";
    const body = `${expertName} has completed the analysis of your leaf scan.`;

    const requestId = context.params.requestId;

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        type: "scan_request_completed",
        requestId: String(requestId || ""),
        expertName: String(expertName || ""),
      },
    };

    await sendToTokens([token], payload);
    return null;
  });
