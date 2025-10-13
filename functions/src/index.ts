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
 * This function uses a Firestore transaction to ensure atomicity and
 * data consistency, decrementing the user's lesson package and marking
 * the trainer's slot as booked. It bypasses client-side security rules
 * for these sensitive operations by using the Admin SDK.
 *
 * @param {functions.https.CallableRequest<BookLessonData>} request - The
 *   callable request object, containing both data and context.
 * @returns {Promise<object>} - A promise that resolves with a success
 *   message or throws an HttpsError.
 */
export const bookLesson = functions.https.onCall(
  async (request: functions.https.CallableRequest<BookLessonData>) => {
    // 1. Authentication Check: Ensure a user is logged in to perform
    //    this action.
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const userId = request.auth.uid;

    // 2. Input Validation: Check for required parameters.
    const {trainerId, slotId, lessonPackageId} = request.data;
    if (!trainerId || !slotId || !lessonPackageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing trainerId, slotId, or lessonPackageId in request data."
      );
    }

    // References to the documents involved in this transaction.
    const userRef = db.collection("users").doc(userId);
    const lessonPackageRef = userRef
      .collection("lessonPackages")
      .doc(lessonPackageId);
    const trainerRef = db.collection("trainers").doc(trainerId);
    const trainerSlotRef = trainerRef.collection("schedules").doc(slotId);

    try {
      await db.runTransaction(async (transaction) => {
        // 3. Read Documents within the transaction to ensure they are current.
        const userDoc = await transaction.get(userRef);
        const lessonPackageDoc = await transaction.get(lessonPackageRef);
        const trainerDoc = await transaction.get(trainerRef);
        const trainerSlotDoc = await transaction.get(trainerSlotRef);

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

        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const userData = userDoc.data()!;
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const lessonPackageData = lessonPackageDoc.data()!;
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const trainerData = trainerDoc.data()!;
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const trainerSlotData = trainerSlotDoc.data()!;

        // Check if lesson package is valid and has lessons remaining
        // Note: Firebase `Timestamp` objects need `.toDate()` for comparison.
        if (
          lessonPackageData.lessonsUsed >= lessonPackageData.totalLessons
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has no lessons remaining."
          ); // eslint-disable-line max-len
        }
        if (
          lessonPackageData.expirationDate &&
          lessonPackageData.expirationDate.toDate() < new Date()
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has expired and cannot be used."
          ); // eslint-disable-line max-len
        }

        // Check if the trainer slot is currently available.
        if (
          trainerSlotData.status !== "open" ||
          trainerSlotData.clientId !== null
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "The requested trainer slot is not available or already booked."
          ); // eslint-disable-line max-len
        }

        // Construct client's full name for the booking record
        const clientFullName =
          `${userData.firstName || ""} ${userData.lastName || ""}`.trim();
        if (!clientFullName) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "User name missing in profile; cannot create booking record."
          );
        }

        // 5. Perform Atomic Updates within the transaction
        // Decrement the 'lessonsUsed' count in the user's lesson package.
        // This operation is allowed by the Admin SDK, bypassing client rules.
        transaction.update(lessonPackageRef, {
          lessonsUsed: admin.firestore.FieldValue.increment(1),
        });

        // Mark the trainer's schedule slot as 'booked' and assign client
        // details. This operation is allowed by the Admin SDK, bypassing
        // client rules.
        transaction.update(trainerSlotRef, {
          status: "booked",
          clientId: userId,
          clientName: clientFullName,
          bookedAt: admin.firestore.FieldValue.serverTimestamp(), // Server timestamp
        });

        // Create a new booking document in the top-level 'bookings'
        // collection.
        const newBookingRef = db.collection("bookings").doc(); // Auto-generated ID
        transaction.set(newBookingRef, {
          clientUID: userId,
          trainerId: trainerId,
          slotId: slotId, // Reference to the specific trainer schedule slot
          startTime: trainerSlotData.startTime,
          endTime: trainerSlotData.endTime,
          packageId: lessonPackageId, // User's lesson package used
          bookedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "confirmed", // Initial status for the booking
          trainerName: trainerData.name || "Unknown Trainer",
          clientName: clientFullName,
        });
      });

      functions.logger.info(
        `Lesson booked successfully for user ${userId} ` +
          `with trainer ${trainerId}, slot ${slotId}.`
      );
      return {message: "Lesson booked successfully!"};
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        // Re-throw Firebase HttpsErrors directly to the client
        throw error;
      }
      functions.logger.error("Error booking lesson:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while booking the lesson.",
        (error as Error).message // eslint-disable-line quotes
      );
    }
  }
);

/**
 * Cloud Function to generate or process trainer availability slots.
 * This function allows a trainer (or an administrator) to create new
 * 'open' schedule slots for a specified period. It ensures that duplicate
 * slots are not created for the same time.
 *
 * @param {functions.https.CallableRequest<ProcessTrainerAvailabilityData>} request - The
 *   callable request object, containing both data and context.
 * @returns {Promise<object>} - A promise that resolves with a success
 *   message and count of added slots.
 */
export const processTrainerAvailability = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<ProcessTrainerAvailabilityData>
  ) => {
    // 1. Authentication & Authorization Check: Only a registered trainer
    //    (or admin) can manage their schedule.
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const callingUserId = request.auth.uid;

    const trainerRef = db.collection("trainers").doc(callingUserId);
    const trainerDoc = await trainerRef.get();

    // Verify that the authenticated user is indeed a trainer.
    if (!trainerDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only a registered trainer can process their own availability slots."
      );
    }
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const trainerData = trainerDoc.data()!;
    const trainerId = callingUserId; // The caller is the trainer

    // 2. Input Data and Defaults for schedule generation
    const {
      startDate: rawStartDate,
      endDate: rawEndDate,
      dailyStartHour = 9,
      dailyEndHour = 17,
      slotDurationMinutes = 60,
    } = request.data;

    // Define default date range (today + 7 days) if not provided.
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Normalize to the beginning of the day
    const defaultEndDate = new Date(today);
    // Generates slots for today + next 6 days (7 days total).
    defaultEndDate.setDate(today.getDate() + 7);

    // Parse provided dates or use defaults.
    const startDate = rawStartDate ? new Date(rawStartDate) : today;
    const endDate = rawEndDate ? new Date(rawEndDate) : defaultEndDate;

    // 3. Input Validation for dates and times
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid start or end date provided. Use YYYY-MM-DD format."
      ); // eslint-disable-line max-len
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
      ); // eslint-disable-line max-len
    }
    if (
      slotDurationMinutes <= 0 ||
      slotDurationMinutes > 1440 // Max 24 hours
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Slot duration must be a positive number of minutes."
      ); // eslint-disable-line max-len
    }

    const trainerScheduleCollection = trainerRef.collection("schedules");
    const batch = db.batch(); // Use a single batch for efficient write operations
    let slotsAddedCount = 0;

    try {
      const currentDayLoop = new Date(startDate);
      // Loop through each day from the start date to the end date (inclusive)
      while (currentDayLoop <= endDate) {
        // For each day, iterate through potential time slots
        for (
          let currentHour = dailyStartHour;
          currentHour < dailyEndHour;
          currentHour += slotDurationMinutes / 60
        ) {
          const slotStartTime = new Date(currentDayLoop);
          // Set hours and minutes carefully to handle fractional hours
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

          // Prevent slots from extending past the defined dailyEndHour or
          // into the next day unexpectedly.
          if (
            slotEndTime.getHours() > dailyEndHour ||
            (slotEndTime.getHours() === dailyEndHour &&
              slotEndTime.getMinutes() > 0)
          ) {
            continue; // Skip this slot as it goes beyond the daily limit
          }

          // Check for existing slots at this exact time for this trainer.
          const existingSlotsSnapshot = await trainerScheduleCollection
            .where("startTime", "==", slotStartTime)
            .where("endTime", "==", slotEndTime)
            .limit(1) // Only need to find one to know it exists
            .get();

          // If no existing slot is found, add a new one to the batch
          if (existingSlotsSnapshot.empty) {
            const newSlotRef = trainerScheduleCollection.doc(); // Auto-generate ID
            batch.set(newSlotRef, {
              status: "open", // New slots are always "open"
              startTime: slotStartTime,
              endTime: slotEndTime,
              clientId: null, // No client initially
              clientName: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              trainerName: trainerData.name || "Unknown Trainer",
            });
            slotsAddedCount++;
          }
        }
        // Move to the next day
        currentDayLoop.setDate(currentDayLoop.getDate() + 1);
        currentDayLoop.setHours(0, 0, 0, 0); // Normalize to start of the next day
      }

      // Commit all collected write operations in a single batch
      if (slotsAddedCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `Trainer ${trainerId} availability processed. ` +
          `Added ${slotsAddedCount} new slots.`
      );
      return {
        message:
          `Availability processed successfully! ` +
          `Added ${slotsAddedCount} new slots.`,
        slotsAdded: slotsAddedCount,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error; // Re-throw any HttpsErrors already created
      }
      functions.logger.error(
        "Error processing trainer availability:",
        error
      );
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while processing trainer availability.",
        (error as Error).message // eslint-disable-line quotes
      );
    }
  }
);
/* eslint-enable quotes */
