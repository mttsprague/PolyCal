import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";

const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
  functions.config().stripe?.secret_key || "";
const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2025-02-24.acacia",
});

const db = admin.firestore();

interface CreatePaymentIntentData {
  packageType: string;
  amount: number;
  trainerId: string;
  userId: string;
}

interface ConfirmPaymentData {
  paymentIntentId: string;
  userId: string;
}

export const createPaymentIntent = functions.https.onCall(
  async (request: functions.https.CallableRequest<CreatePaymentIntentData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to create a payment"
      );
    }

    const {packageType, amount, trainerId, userId} = request.data;

    if (!packageType || !amount || !trainerId || !userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields"
      );
    }

    if (request.auth.uid !== userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User ID does not match authenticated user"
      );
    }

    const validPackages: { [key: string]: number } = {
      single: 8000, // $80
      five_pack: 37500, // $375
      ten_pack: 70000, // $700
      two_athlete: 14000, // $140
      three_athlete: 18000, // $180
      class_registration: 4500, // $45
    };

    if (!validPackages[packageType] || validPackages[packageType] !== amount) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid package type or amount"
      );
    }

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency: "usd",
        metadata: {userId, packageType, trainerId},
        description: `${packageType.replace("_", " ")} lesson package`,
      });

      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error: unknown) {
      console.error("Error creating payment intent:", error);
      const message = error instanceof Error ? error.message : String(error);
      throw new functions.https.HttpsError("internal", message);
    }
  }
);

export const confirmPaymentAndCreatePackage = functions.https.onCall(
  async (request: functions.https.CallableRequest<ConfirmPaymentData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in"
      );
    }

    const {paymentIntentId, userId} = request.data;

    if (!paymentIntentId || !userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing paymentIntentId or userId"
      );
    }

    if (request.auth.uid !== userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User ID does not match authenticated user"
      );
    }

    try {
      const paymentIntent = await stripe.paymentIntents.retrieve(
        paymentIntentId
      );

      if (paymentIntent.status !== "succeeded") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Payment has not succeeded"
        );
      }

      const packageType = paymentIntent.metadata.packageType as string;

      const lessonCounts: { [key: string]: number } = {
        single: 1,
        five_pack: 5,
        ten_pack: 10,
        two_athlete: 1,
        three_athlete: 1,
        class_registration: 0, // Classes don't create lesson packages
      };

      const totalLessons = lessonCounts[packageType];
      if (!totalLessons) {
        throw new functions.https.HttpsError("internal", "Invalid package type");
      }

      const now = admin.firestore.Timestamp.now();
      const expirationDate = new Date();
      expirationDate.setMonth(expirationDate.getMonth() + 12);

      const packageData = {
        packageType,
        totalLessons,
        lessonsUsed: 0,
        purchaseDate: now,
        expirationDate: admin.firestore.Timestamp.fromDate(expirationDate),
        transactionId: paymentIntentId,
      };

      await db
        .collection("users")
        .doc(userId)
        .collection("lessonPackages")
        .add(packageData);

      return {success: true, packageId: paymentIntentId};
    } catch (error: unknown) {
      console.error("Error confirming payment:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new functions.https.HttpsError("internal", message);
    }
  }
);
