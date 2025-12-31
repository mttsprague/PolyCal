/* eslint-disable quotes */
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK once when the function container starts
admin.initializeApp();

// Export Stripe payment functions
export * from "./stripe";

const db = admin.firestore();

/**
 * Generate a deterministic schedule document ID for a given start time.
 * Uses UTC and hour resolution to match iOS FirestoreService.scheduleDocId(for:).
 * Format: YYYY-MM-DDTHH (e.g., 2025-10-13T06)
 *
 * @param {Date} startTime UTC date/time of the slot start
 * @return {string} Deterministic document ID
 */
function generateScheduleDocId(startTime: Date): string {
  const date = new Date(startTime);
  date.setUTCMinutes(0, 0, 0); // normalize to top of the hour
  const year = date.getUTCFullYear();
  const month = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = date.getUTCDate().toString().padStart(2, "0");
  const hour = date.getUTCHours().toString().padStart(2, "0");
  // e.g., 2025-10-13T06
  return `${year}-${month}-${day}T${hour}`;
}

// --- Interfaces for function input data ---

/**
 * Interface for the input data to the bookLesson callable function.
 */
interface BookLessonData {
  trainerId: string;
  slotId: string; // deterministic ID "YYYY-MM-DDTHH"
  lessonPackageId: string;
}

/**
 * Interface for the input data to the registerForClass callable function.
 */
interface RegisterForClassData {
  classId: string;
  classPassPackageId: string;
}

/**
 * Interface for the input data to the processTrainerAvailability
 * callable function.
 */
interface ProcessTrainerAvailabilityData {
  startDate?: string; // YYYY-MM-DD (date-only)
  endDate?: string; // YYYY-MM-DD (date-only)
  dailyStartHour?: number; // 0...23 (LOCAL hour)
  dailyEndHour?: number; // 1...24 (exclusive end, LOCAL hour)
  slotDurationMinutes?: number; // usually 60
  daysOfWeek?: number[]; // 0=Sunday ... 6=Saturday (LOCAL weekday)
  timezoneOffsetMinutes?: number; // Date.getTimezoneOffset() from client (positive west of UTC)
}

// --- Cloud Functions ---

/**
 * Cloud Function to book a lesson for a user with a trainer.
 */
export const bookLesson = functions.https.onCall(
  async (request: functions.https.CallableRequest<BookLessonData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const userId = request.auth.uid;

    const {trainerId, slotId, lessonPackageId} = request.data;
    if (!trainerId || !slotId || !lessonPackageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing trainerId, slotId, or lessonPackageId in request data."
      );
    }

    const userRef = db.collection("users").doc(userId);
    const lessonPackageRef = userRef
      .collection("lessonPackages")
      .doc(lessonPackageId);
    const trainerRef = db.collection("trainers").doc(trainerId);
    // IMPORTANT: slotId is deterministic ("YYYY-MM-DDTHH")
    const trainerSlotRef = trainerRef.collection("schedules").doc(slotId);

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const lessonPackageDoc = await transaction.get(lessonPackageRef);
        const trainerDoc = await transaction.get(trainerRef);
        const trainerSlotDoc = await transaction.get(trainerSlotRef);

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

        const userData = userDoc.data();
        const lessonPackageData = lessonPackageDoc.data();
        const trainerData = trainerDoc.data();
        const trainerSlotData = trainerSlotDoc.data();

        if (!userData || !lessonPackageData || !trainerData || !trainerSlotData) {
          throw new functions.https.HttpsError(
            "internal",
            "Unexpected missing document data."
          );
        }

        if (lessonPackageData.lessonsUsed >= lessonPackageData.totalLessons) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has no lessons remaining."
          );
        }
        if (
          lessonPackageData.expirationDate &&
          lessonPackageData.expirationDate.toDate() < new Date()
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Lesson package has expired and cannot be used."
          );
        }

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

        const clientFullName = `${userData.firstName || ""} ${
          userData.lastName || ""
        }`.trim();
        if (!clientFullName) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "User name missing in profile; cannot create booking record."
          );
        }

        transaction.update(lessonPackageRef, {
          lessonsUsed: admin.firestore.FieldValue.increment(1),
        });

        transaction.update(trainerSlotRef, {
          status: "booked",
          clientId: userId,
          clientName: clientFullName,
          bookedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const newBookingRef = db.collection("bookings").doc();
        transaction.set(newBookingRef, {
          clientUID: userId,
          trainerId: trainerId,
          slotId: slotId, // deterministic schedule slot doc id
          startTime: trainerSlotData.startTime,
          endTime: trainerSlotData.endTime,
          packageId: lessonPackageId,
          bookedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "confirmed",
          trainerName: trainerData.name || "Unknown Trainer",
          clientName: clientFullName,
          scheduleSlotId: slotId,
        });
      });

      functions.logger.info(
        `Lesson booked successfully for user ${userId} with trainer ${trainerId}, slot ${slotId}.`
      );
      return {message: "Lesson booked successfully!"};
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
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
 * Cloud Function to register for a class using a class pass.
 */
export const registerForClass = functions.https.onCall(
  async (request: functions.https.CallableRequest<RegisterForClassData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const userId = request.auth.uid;

    const {classId, classPassPackageId} = request.data;
    if (!classId || !classPassPackageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing classId or classPassPackageId in request data."
      );
    }

    const userRef = db.collection("users").doc(userId);
    const classPassRef = userRef
      .collection("lessonPackages")
      .doc(classPassPackageId);
    const classRef = db.collection("classes").doc(classId);

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const classPassDoc = await transaction.get(classPassRef);
        const classDoc = await transaction.get(classRef);

        if (!userDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "User profile not found for the authenticated user."
          );
        }
        if (!classPassDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Specified class pass not found."
          );
        }
        if (!classDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Class not found."
          );
        }

        const userData = userDoc.data();
        const classPassData = classPassDoc.data();
        const classData = classDoc.data();

        if (!userData || !classPassData || !classData) {
          throw new functions.https.HttpsError(
            "internal",
            "Unexpected missing document data."
          );
        }

        // Verify it's a class pass
        if (classPassData.packageType !== "class_pass") {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "The specified package is not a class pass."
          );
        }

        // Check if pass has been used
        if (classPassData.lessonsUsed >= classPassData.totalLessons) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Class pass has already been used."
          );
        }

        // Check if pass is expired
        if (
          classPassData.expirationDate &&
          classPassData.expirationDate.toDate() < new Date()
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Class pass has expired and cannot be used."
          );
        }

        // Check if class is full
        if (classData.currentParticipants >= classData.maxParticipants) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Class is full."
          );
        }

        // Check if user is already registered
        const participantRef = classRef
          .collection("participants")
          .doc(userId);
        const participantDoc = await transaction.get(participantRef);
        if (participantDoc.exists) {
          throw new functions.https.HttpsError(
            "already-exists",
            "You are already registered for this class."
          );
        }

        // Increment lessonsUsed on the class pass
        transaction.update(classPassRef, {
          lessonsUsed: admin.firestore.FieldValue.increment(1),
        });

        // Increment class participants
        transaction.update(classRef, {
          currentParticipants: admin.firestore.FieldValue.increment(1),
        });

        // Add user to participants subcollection
        transaction.set(participantRef, {
          userId: userId,
          firstName: userData.firstName || "Unknown",
          lastName: userData.lastName || "User",
          registeredAt: admin.firestore.FieldValue.serverTimestamp(),
          classPassPackageId: classPassPackageId,
        });
      });

      functions.logger.info(
        `User ${userId} registered for class ${classId} using pass ${classPassPackageId}.`
      );
      return {message: "Successfully registered for class!"};
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      functions.logger.error("Error registering for class:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while registering for the class.",
        (error as Error).message
      );
    }
  }
);

/**
 * Cloud Function to generate or process trainer availability slots.
 * Creates 'open' schedule slots for the specified range and weekdays.
 *
 * Interprets provided dates and hours in the client's LOCAL timezone using timezoneOffsetMinutes.
 * timezoneOffsetMinutes must match JavaScript Date.getTimezoneOffset() (positive west of UTC).
 */
export const processTrainerAvailability = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<ProcessTrainerAvailabilityData>
  ) => {
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
    const trainerData = trainerDoc.data();
    if (!trainerData) {
      throw new functions.https.HttpsError(
        "internal",
        "Unexpected missing trainer profile data."
      );
    }
    const trainerId = callingUserId;

    const {
      startDate: rawStartDate,
      endDate: rawEndDate,
      dailyStartHour = 9,
      dailyEndHour = 17,
      slotDurationMinutes = 60,
      daysOfWeek, // optional filter 0..6 (Sun..Sat), interpreted in LOCAL time
      timezoneOffsetMinutes, // required for local interpretation (JS getTimezoneOffset)
    } = request.data;

    if (typeof timezoneOffsetMinutes !== "number" || !isFinite(timezoneOffsetMinutes)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "timezoneOffsetMinutes (from Date.getTimezoneOffset()) is required."
      );
    }

    // Establish UTC start-of-day defaults
    const todayUTC = new Date();
    todayUTC.setUTCHours(0, 0, 0, 0);

    const defaultEndUTC = new Date(todayUTC);
    defaultEndUTC.setUTCDate(defaultEndUTC.getUTCDate() + 7);

    // Parse YYYY-MM-DD strictly
    const parseDateOnly = (s: string): {y: number; m: number; d: number} => {
      const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
      if (!match) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid start or end date provided. Use YYYY-MM-DD format."
        );
      }
      return {y: Number(match[1]), m: Number(match[2]), d: Number(match[3])};
    };

    // Convert a local date (y-m-d at local midnight) to the UTC instant that corresponds to that local midnight.
    // JS getTimezoneOffset(): minutes to add to LOCAL to get UTC (positive west of UTC).
    // Therefore, UTC instant for local midnight = Date.UTC(y,m,d,0) + offsetMinutes.
    const localMidnightToUTC = (y: number, m: number, d: number): Date => {
      const utcMs = Date.UTC(y, m - 1, d, 0, 0, 0, 0) + timezoneOffsetMinutes * 60_000;
      return new Date(utcMs);
    };

    // Build start and end UTC anchors from local dates (if provided)
    const startDateUTC = (() => {
      if (rawStartDate) {
        const {y, m, d} = parseDateOnly(rawStartDate);
        return localMidnightToUTC(y, m, d);
      }
      return new Date(todayUTC.getTime() + timezoneOffsetMinutes * 60_000);
    })();

    const endDateUTC = (() => {
      if (rawEndDate) {
        const {y, m, d} = parseDateOnly(rawEndDate);
        return localMidnightToUTC(y, m, d);
      }
      return new Date(defaultEndUTC.getTime() + timezoneOffsetMinutes * 60_000);
    })();

    // Validation
    if (isNaN(startDateUTC.getTime()) || isNaN(endDateUTC.getTime())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid start or end date provided. Use YYYY-MM-DD format."
      );
    }
    if (startDateUTC > endDateUTC) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Start date cannot be after end date."
      );
    }
    if (
      dailyStartHour < 0 ||
      dailyStartHour > 23 ||
      dailyEndHour < 1 ||
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
      // Walk LOCAL days by moving the "local midnight in UTC" anchor forward
      const currentLocalMidnightUTC = new Date(startDateUTC);
      while (currentLocalMidnightUTC <= endDateUTC) {
        // local weekday: getUTCDay() on the local-midnight-in-UTC anchor
        const localWeekday = currentLocalMidnightUTC.getUTCDay(); // 0..6 (Sun..Sat)

        // Filter by selected weekdays (LOCAL)
        if (Array.isArray(daysOfWeek) && daysOfWeek.length > 0) {
          if (!daysOfWeek.includes(localWeekday)) {
            currentLocalMidnightUTC.setUTCDate(currentLocalMidnightUTC.getUTCDate() + 1);
            continue;
          }
        }

        // Iterate by minutes to avoid FP drift
        const startMinutes = Math.round(dailyStartHour * 60);
        const endMinutesExclusive = Math.round(dailyEndHour * 60);

        for (
          let minuteOfDay = startMinutes;
          minuteOfDay + slotDurationMinutes <= endMinutesExclusive;
          minuteOfDay += slotDurationMinutes
        ) {
          const startHour = Math.floor(minuteOfDay / 60);
          const startMinute = minuteOfDay % 60;

          // Build UTC instants for local times on this day
          const slotStartTime = new Date(currentLocalMidnightUTC);
          // FIX: add the local hour to the UTC hour of the local-midnight anchor
          slotStartTime.setUTCHours(
            slotStartTime.getUTCHours() + startHour,
            startMinute,
            0,
            0
          );

          const slotEndTime = new Date(slotStartTime);
          slotEndTime.setUTCMinutes(slotEndTime.getUTCMinutes() + slotDurationMinutes);

          // Deterministic ID for this slot (UTC hour)
          const slotDocId = generateScheduleDocId(slotStartTime);
          const slotRef = trainerScheduleCollection.doc(slotDocId);
          const existingSlotDoc = await slotRef.get();

          if (!existingSlotDoc.exists) {
            batch.set(slotRef, {
              status: "open",
              startTime: slotStartTime,
              endTime: slotEndTime,
              clientId: null,
              clientName: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              trainerName: trainerData.name || "Unknown Trainer",
            });
            slotsAddedCount++;
          } else {
            functions.logger.debug(
              `Slot ${slotDocId} already exists for trainer ${trainerId}, skipping.`
            );
          }
        }

        // Next LOCAL day
        currentLocalMidnightUTC.setUTCDate(currentLocalMidnightUTC.getUTCDate() + 1);
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
      functions.logger.error(
        "Error processing trainer availability:",
        error
      );
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred while processing trainer availability.",
        (error as Error).message
      );
    }
  }
);
/* eslint-enable quotes */
