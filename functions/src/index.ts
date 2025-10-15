/* eslint-disable quotes */
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK once when the function container starts
admin.initializeApp();

const db = admin.firestore();

// --- Interfaces for function input data ---

/**
 * Interface for the input data to the bookLesson callable function.
 */
interface BookLessonData {
  trainerId: string;
  slotId: string;
  lessonPackageId: string;
}

/**
 * Interface for the input data to the processTrainerAvailability
 * callable function.
 */
interface ProcessTrainerAvailabilityData {
  startDate?: string; // YYYY-MM-DD
  endDate?: string; // YYYY-MM-DD
  dailyStartHour?: number;
  dailyEndHour?: number;
  slotDurationMinutes?: number;
}

// --- Cloud Functions ---

/**
 * Cloud Function to book a lesson for a user with a trainer.
 * This version:
 *  - Validates authentication and inputs
 *  - Ensures the lesson package and slot are valid
 *  - Decrements lessonsUsed
 *  - Creates a booking document (with both alias field names)
 *  - Deletes the trainer's schedule slot document (removing the time from availability)
 *  - Returns a success message and the created booking data
 */
export const bookLesson = functions.https.onCall(
  async (request: functions.https.CallableRequest<BookLessonData>) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const userId = request.auth.uid;

    // 2. Input Validation
    // Adjusted spacing to satisfy object-curly-spacing rule in your config
    const {trainerId, slotId, lessonPackageId} = request.data;
    if (!trainerId || !slotId || !lessonPackageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing trainerId, slotId, or lessonPackageId in request data."
      );
    }

    // References
    const userRef = db.collection("users").doc(userId);
    const lessonPackageRef = userRef
      .collection("lessonPackages")
      .doc(lessonPackageId);
    const trainerRef = db.collection("trainers").doc(trainerId);
    const trainerSlotRef = trainerRef.collection("schedules").doc(slotId);

    // Prepare booking doc ref now so we can read it after the transaction
    const newBookingRef = db.collection("bookings").doc();

    try {
      await db.runTransaction(async (transaction) => {
        // 3. Read Documents within the transaction
        const [userDoc, lessonPackageDoc, trainerDoc, trainerSlotDoc] =
          await Promise.all([
            transaction.get(userRef),
            transaction.get(lessonPackageRef),
            transaction.get(trainerRef),
            transaction.get(trainerSlotRef),
          ]);

        // 4. Validate Document States and Business Logic
        if (!userDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "User profile not found for the authenticated user."
          );
        }
        if (!lessonPackageDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Specified lesson package not found."
          );
        }
        if (!trainerDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Trainer profile not found."
          );
        }
        if (!trainerSlotDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Specified trainer slot not found."
          );
        }

        // Replace non-null assertions with casts to satisfy lint rule
        const userData = userDoc.data() as FirebaseFirestore.DocumentData;
        const lessonPackageData = lessonPackageDoc.data() as FirebaseFirestore.DocumentData;
        const trainerData = trainerDoc.data() as FirebaseFirestore.DocumentData;
        const trainerSlotData = trainerSlotDoc.data() as FirebaseFirestore.DocumentData;

        // Check lesson package remaining and expiration
        if (
          (lessonPackageData.lessonsUsed as number) >=
          (lessonPackageData.totalLessons as number)
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has no lessons remaining."
          );
        }
        if (
          lessonPackageData.expirationDate &&
          typeof lessonPackageData.expirationDate.toDate === "function" &&
          lessonPackageData.expirationDate.toDate() < new Date()
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has expired and cannot be used."
          );
        }

        // Check slot availability (must be "open" and not already assigned)
        if (
          trainerSlotData.status !== "open" ||
          (trainerSlotData.clientId !== null &&
            trainerSlotData.clientId !== undefined)
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "The requested trainer slot is not available or already booked."
          );
        }

        // Construct client's full name for the booking record
        const clientFullName = `${userData.firstName || ""} ${
          userData.lastName || ""
        }`.trim();
        if (!clientFullName) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "User name missing in profile; cannot create booking record."
          );
        }

        // 5. Perform Atomic Updates within the transaction

        // 5a. Decrement lessonsUsed
        transaction.update(lessonPackageRef, {
          lessonsUsed: admin.firestore.FieldValue.increment(1),
        });

        // 5b. Create a booking document (include both alias field names)
        transaction.set(newBookingRef, {
          id: newBookingRef.id, // convenience for client decoding
          clientUID: userId,

          // Store both variants so existing clients decode reliably
          trainerId: trainerId,
          trainerUID: trainerId,

          slotId: slotId,
          scheduleSlotId: slotId,

          packageId: lessonPackageId,
          lessonPackageId: lessonPackageId,

          startTime: trainerSlotData.startTime,
          endTime: trainerSlotData.endTime,

          bookedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),

          status: "confirmed",
          trainerName: (trainerData.name as string) || "Unknown Trainer",
          clientName: clientFullName,
        });

        // 5c. Remove the time slot from availability by deleting the slot doc
        transaction.delete(trainerSlotRef);
      });

      // Read back the booking to return resolved timestamps
      const bookingSnap = await newBookingRef.get();
      const bookingData = bookingSnap.data() || {};
      const response = {
        message: "Lesson booked successfully!",
        booking: {
          id: newBookingRef.id,
          ...bookingData,
        },
      };

      functions.logger.info(
        `Lesson booked successfully for user ${userId} with trainer ${trainerId}, slot ${slotId}.`
      );
      return response;
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error; // Re-throw Firebase HttpsErrors directly
      }
      functions.logger.error("Error booking lesson:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while booking the lesson.",
        (error as Error).message
      );
    }
  }
);

/**
 * Cloud Function to generate or process trainer availability slots.
 * This function allows a trainer (or an administrator) to create new
 * 'open' schedule slots for a specified period. It ensures that duplicate
 * slots are not created for the same time.
 */
export const processTrainerAvailability = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<ProcessTrainerAvailabilityData>
  ) => {
    // 1. Authentication & Authorization Check
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const callingUserId = request.auth.uid;

    const trainerRef = db.collection("trainers").doc(callingUserId);
    const trainerDoc = await trainerRef.get();

    if (!trainerDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only a registered trainer can process their own availability slots."
      );
    }
    const trainerData = trainerDoc.data() as FirebaseFirestore.DocumentData;
    const trainerId = callingUserId;

    // 2. Input Data and Defaults
    const {
      startDate: rawStartDate,
      endDate: rawEndDate,
      dailyStartHour = 9,
      dailyEndHour = 17,
      slotDurationMinutes = 60,
    } = request.data;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const defaultEndDate = new Date(today);
    defaultEndDate.setDate(today.getDate() + 7);

    const startDate = rawStartDate ? new Date(rawStartDate) : today;
    const endDate = rawEndDate ? new Date(rawEndDate) : defaultEndDate;

    // 3. Validation
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid start or end date provided. Use YYYY-MM-DD format."
      );
    }
    if (startDate > endDate) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Start date cannot be after end date."
      );
    }
    if (
      dailyStartHour < 0 ||
      dailyStartHour > 23 ||
      dailyEndHour < 0 ||
      dailyEndHour > 24 ||
      dailyStartHour >= dailyEndHour
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid daily start or end hours."
      );
    }
    if (slotDurationMinutes <= 0 || slotDurationMinutes > 1440) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Slot duration must be a positive number of minutes."
      );
    }

    const trainerScheduleCollection = trainerRef.collection("schedules");
    const batch = db.batch();
    let slotsAddedCount = 0;

    try {
      const currentDayLoop = new Date(startDate);
      while (currentDayLoop <= endDate) {
        for (
          let currentHour = dailyStartHour;
          currentHour < dailyEndHour;
          currentHour += slotDurationMinutes / 60
        ) {
          const slotStartTime = new Date(currentDayLoop);
          slotStartTime.setHours(
            Math.floor(currentHour),
            (currentHour % 1) * 60,
            0,
            0
          );

          const slotEndTime = new Date(slotStartTime);
          slotEndTime.setMinutes(
            slotStartTime.getMinutes() + slotDurationMinutes
          );

          if (
            slotEndTime.getHours() > dailyEndHour ||
            (slotEndTime.getHours() === dailyEndHour &&
              slotEndTime.getMinutes() > 0)
          ) {
            continue;
          }

          const existingSlotsSnapshot = await trainerScheduleCollection
            .where("startTime", "==", slotStartTime)
            .where("endTime", "==", slotEndTime)
            .limit(1)
            .get();

          if (existingSlotsSnapshot.empty) {
            const newSlotRef = trainerScheduleCollection.doc();
            batch.set(newSlotRef, {
              status: "open",
              startTime: slotStartTime,
              endTime: slotEndTime,
              clientId: null,
              clientName: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              trainerName: (trainerData.name as string) || "Unknown Trainer",
            });
            slotsAddedCount++;
          }
        }
        currentDayLoop.setDate(currentDayLoop.getDate() + 1);
        currentDayLoop.setHours(0, 0, 0, 0);
      }

      if (slotsAddedCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `Trainer ${trainerId} availability processed. Added ${slotsAddedCount} new slots.`
      );
      return {
        message: `Availability processed successfully! Added ${slotsAddedCount} new slots.`,
        slotsAdded: slotsAddedCount,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      functions.logger.error("Error processing trainer availability:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while processing trainer availability.",
        (error as Error).message
      );
    }
  }
);
/* eslint-enable quotes */
