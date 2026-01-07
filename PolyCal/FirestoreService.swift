//
//  FirestoreService.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

enum FirestoreServiceError: Error {
    case notAvailable
    case decoding
}

final class FirestoreService {
    static let shared = FirestoreService()
    private init() {}

    var db: Any? {
        #if canImport(FirebaseFirestore)
        return Firestore.firestore()
        #else
        return nil
        #endif
    }

    // MARK: - Schedule (fetch)
    func fetchTrainerSchedule(trainerId: String, from: Date, to: Date) async throws -> [TrainerScheduleSlot] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let startTs = Timestamp(date: from)
        let endTs = Timestamp(date: to)

        var mergedById: [String: TrainerScheduleSlot] = [:]

        // --- 1) Fetch open/unavailable slots from trainer subcollection
        let trainerScheduleSnapshot = try await db.collection("trainers")
            .document(trainerId)
            .collection("schedules")
            .whereField("startTime", isGreaterThanOrEqualTo: startTs)
            .whereField("startTime", isLessThan: endTs)
            .order(by: "startTime")
            .getDocuments()

        let subcollectionSlots: [TrainerScheduleSlot] = trainerScheduleSnapshot.documents.compactMap { doc in
            let data = doc.data()

            // Required time fields
            guard
                let startTs = data["startTime"] as? Timestamp,
                let endTs = data["endTime"] as? Timestamp
            else {
                return nil
            }

            // Status: if missing, default to .open. If somehow .booked, we’ll exclude below.
            let status: TrainerScheduleSlot.Status = {
                if let raw = data["status"] as? String, let s = TrainerScheduleSlot.Status(rawValue: raw) {
                    return s
                }
                return .open
            }()

            // Read class booking fields if present
            let isClassBooking = data["isClassBooking"] as? Bool
            let classId = data["classId"] as? String

            return TrainerScheduleSlot(
                id: doc.documentID,
                trainerId: trainerId,
                status: status,
                startTime: startTs.dateValue(),
                endTime: endTs.dateValue(),
                clientId: data["clientId"] as? String,
                clientName: data["clientName"] as? String,
                bookedAt: (data["bookedAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
                isClassBooking: isClassBooking,
                classId: classId
            )
        }

        for slot in subcollectionSlots {
            mergedById[slot.id] = slot
        }

        // --- 2) Fetch booked slots from top-level bookings collection
        // Accept both "confirmed" and "booked" as booked states (new data uses "confirmed").
        let bookingsSnapshot = try await db.collection("bookings")
            .whereField("trainerId", isEqualTo: trainerId)
            .whereField("startTime", isGreaterThanOrEqualTo: startTs)
            .whereField("startTime", isLessThan: endTs)
            .order(by: "startTime")
            .getDocuments()

        // Collect class IDs to check registration status
        var classIdsToCheck = Set<String>()
        for doc in bookingsSnapshot.documents {
            let data = doc.data()
            if let isClassBooking = data["isClassBooking"] as? Bool,
               isClassBooking == true,
               let classId = data["classId"] as? String {
                classIdsToCheck.insert(classId)
            }
        }
        
        // Fetch all class documents to check isOpenForRegistration
        var openClassIds = Set<String>()
        for classId in classIdsToCheck {
            do {
                let classDoc = try await db.collection("classes").document(classId).getDocument()
                if classDoc.exists,
                   let classData = classDoc.data(),
                   let isOpen = classData["isOpenForRegistration"] as? Bool,
                   isOpen == true {
                    openClassIds.insert(classId)
                }
            } catch {
                // If we can't fetch the class, skip it (treat as closed)
                continue
            }
        }
        
        let bookedSlots: [TrainerScheduleSlot] = bookingsSnapshot.documents.compactMap { doc in
            let data = doc.data()

            // Only include confirmed/booked bookings
            guard
                let bookedStatus = data["status"] as? String,
                bookedStatus == "confirmed" || bookedStatus == "booked",
                let startTs = data["startTime"] as? Timestamp,
                let endTs = data["endTime"] as? Timestamp
            else {
                return nil
            }
            
            // Filter out closed classes
            let isClassBooking = data["isClassBooking"] as? Bool
            let classId = data["classId"] as? String
            if isClassBooking == true, let classId = classId {
                // Only include if the class is open for registration
                guard openClassIds.contains(classId) else {
                    return nil
                }
            }

            // Prefer scheduleSlotId (often matches deterministic scheduleDocId), then slotId, then fallback to booking doc id
            let slotIdentifier =
                (data["scheduleSlotId"] as? String) ??
                (data["slotId"] as? String) ??
                doc.documentID

            let clientUID = data["clientUID"] as? String
            let clientName = data["clientName"] as? String

            return TrainerScheduleSlot(
                id: slotIdentifier,
                trainerId: trainerId,
                status: .booked,
                startTime: startTs.dateValue(),
                endTime: endTs.dateValue(),
                clientId: clientUID,
                clientName: clientName,
                bookedAt: (data["bookedAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
                isClassBooking: isClassBooking,
                classId: classId
            )
        }

        // Overwrite any open/unavailable slot with the booked one if ids collide.
        for slot in bookedSlots {
            mergedById[slot.id] = slot
        }

        // Return merged list; sorting by startTime for stable presentation
        let combined = Array(mergedById.values).sorted { $0.startTime < $1.startTime }
        return combined
        #else
        // No Firestore in this build; return empty to keep app usable
        return []
        #endif
    }

    // MARK: - Schedule (write APIs)
    // Deterministic document ID per trainer per startTime (UTC, hour resolution)
    private func scheduleDocId(for start: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let utcTimezone = TimeZone(secondsFromGMT: 0)!
        var utcCalendar = calendar
        utcCalendar.timeZone = utcTimezone
        
        let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let h = comps.hour ?? 0
        // e.g., 2025-10-13T06
        return String(format: "%04d-%02d-%02dT%02d", y, m, d, h)
    }

    func upsertTrainerSlot(trainerId: String, startTime: Date, endTime: Date, status: TrainerScheduleSlot.Status) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docId = scheduleDocId(for: startTime)
        let ref = db.collection("trainers").document(trainerId).collection("schedules").document(docId)

        let data: [String: Any] = [
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data, merge: true)
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }

    func deleteTrainerSlot(trainerId: String, startTime: Date) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docId = scheduleDocId(for: startTime)
        let ref = db.collection("trainers").document(trainerId).collection("schedules").document(docId)
        try await ref.delete()
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }

    // MARK: - Trainers (list)
    func fetchAllTrainers() async throws -> [Trainer] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("trainers").getDocuments()
        let trainers: [Trainer] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            let name = (data["name"] as? String) ?? "Unknown"
            let email = (data["email"] as? String) ?? ""
            let avatarUrl = data["avatarUrl"] as? String
            let photoURL = data["photoURL"] as? String
            let imageUrl = data["imageUrl"] as? String
            let active = (data["active"] as? Bool) ?? true
            return Trainer(
                id: doc.documentID,
                displayName: name,
                email: email,
                avatarUrl: avatarUrl,
                photoURL: photoURL,
                imageUrl: imageUrl,
                active: active
            )
        }
        return trainers
        #else
        // No Firestore in this build; provide a small placeholder list
        return [
            Trainer(id: "trainer_demo", displayName: "Demo Trainer", email: "demo@example.com", avatarUrl: nil, photoURL: nil, imageUrl: nil, active: true)
        ]
        #endif
    }

    // MARK: - Users (profiles) compliant with rules
    func createOrUpdateUserProfile(uid: String, firstName: String, lastName: String, emailAddress: String, phoneNumber: String? = nil, photoURL: String? = nil, active: Bool = true) async throws {
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("users").document(uid)

        let now = FieldValue.serverTimestamp()
        // Only allowed keys per rules
        var data: [String: Any] = [
            "emailAddress": emailAddress,
            "firstName": firstName,
            "lastName": lastName,
            "phoneNumber": phoneNumber ?? "",
            "photoURL": photoURL ?? "",
            "active": active,
            "updatedAt": now
        ]

        // If doc does not exist, also set createdAt
        let snap = try await ref.getDocument()
        if !snap.exists {
            data["createdAt"] = now
        }

        try await ref.setData(data, merge: true)
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }

    // MARK: - Trainers (owner-writable)
    func createOrUpdateTrainerProfile(trainerId: String, name: String, email: String, avatarUrl: String? = nil, photoURL: String? = nil, imageUrl: String? = nil, active: Bool = true) async throws {
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("trainers").document(trainerId)
        var data: [String: Any] = [
            "name": name,
            "email": email,
            "active": active
        ]
        if let avatarUrl { data["avatarUrl"] = avatarUrl }
        if let photoURL { data["photoURL"] = photoURL }
        if let imageUrl { data["imageUrl"] = imageUrl }

        try await ref.setData(data, merge: true)
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }

    // MARK: - Clients (from top-level users collection)
    func fetchTrainerClients(trainerId: String) async throws -> [Client] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let query: Query = db.collection("users")

        // NOTE: If your user docs may not have `active`, this filter will exclude them.
        // Remove or re-enable once data is normalized.
        // query = query.whereField("active", isEqualTo: true)

        // If you add a linkage field (e.g., "trainerId"), you can enable this filter:
        // query = query.whereField("trainerId", isEqualTo: trainerId)

        let snapshot = try await query.getDocuments()
        let clients: [Client] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let firstName = data["firstName"] as? String,
                let lastName = data["lastName"] as? String,
                let emailAddress = data["emailAddress"] as? String
            else {
                return nil
            }
            let phoneNumber = data["phoneNumber"] as? String ?? ""
            let photoURL = data["photoURL"] as? String
            let athleteFirstName = data["athleteFirstName"] as? String
            let athleteLastName = data["athleteLastName"] as? String
            let athlete2FirstName = data["athlete2FirstName"] as? String
            let athlete2LastName = data["athlete2LastName"] as? String
            let athlete3FirstName = data["athlete3FirstName"] as? String
            let athlete3LastName = data["athlete3LastName"] as? String
            let athletePosition = data["athletePosition"] as? String
            let athlete2Position = data["athlete2Position"] as? String
            let athlete3Position = data["athlete3Position"] as? String
            let notesForCoach = data["notesForCoach"] as? String
            return Client(
                id: doc.documentID,
                firstName: firstName,
                lastName: lastName,
                emailAddress: emailAddress,
                phoneNumber: phoneNumber,
                photoURL: photoURL,
                athleteFirstName: athleteFirstName,
                athleteLastName: athleteLastName,
                athlete2FirstName: athlete2FirstName,
                athlete2LastName: athlete2LastName,
                athlete3FirstName: athlete3FirstName,
                athlete3LastName: athlete3LastName,
                athletePosition: athletePosition,
                athlete2Position: athlete2Position,
                athlete3Position: athlete3Position,
                notesForCoach: notesForCoach
            )
        }
        return clients
        #else
        // No Firestore in this build; return a placeholder list
        return [
            Client(id: "client_demo", firstName: "Alex", lastName: "Smith", emailAddress: "alex@example.com", phoneNumber: "555-123-4567", photoURL: nil)
        ]
        #endif
    }

    // MARK: - Single client fetch
    func fetchClient(by uid: String) async throws -> Client? {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let data = snap.data() else { return nil }
        guard
            let firstName = data["firstName"] as? String,
            let lastName = data["lastName"] as? String,
            let emailAddress = data["emailAddress"] as? String
        else {
            return nil
        }
        let phoneNumber = data["phoneNumber"] as? String ?? ""
        let photoURL = data["photoURL"] as? String
        let athleteFirstName = data["athleteFirstName"] as? String
        let athleteLastName = data["athleteLastName"] as? String
        let athlete2FirstName = data["athlete2FirstName"] as? String
        let athlete2LastName = data["athlete2LastName"] as? String
        let athlete3FirstName = data["athlete3FirstName"] as? String
        let athlete3LastName = data["athlete3LastName"] as? String
        let athletePosition = data["athletePosition"] as? String
        let athlete2Position = data["athlete2Position"] as? String
        let athlete3Position = data["athlete3Position"] as? String
        let notesForCoach = data["notesForCoach"] as? String
        return Client(
            id: snap.documentID,
            firstName: firstName,
            lastName: lastName,
            emailAddress: emailAddress,
            phoneNumber: phoneNumber,
            photoURL: photoURL,
            athleteFirstName: athleteFirstName,
            athleteLastName: athleteLastName,
            athlete2FirstName: athlete2FirstName,
            athlete2LastName: athlete2LastName,
            athlete3FirstName: athlete3FirstName,
            athlete3LastName: athlete3LastName,
            athletePosition: athletePosition,
            athlete2Position: athlete2Position,
            athlete3Position: athlete3Position,
            notesForCoach: notesForCoach
        )
        #else
        return Client(id: "client_demo", firstName: "Alex", lastName: "Smith", emailAddress: "alex@example.com", phoneNumber: "555-123-4567", photoURL: nil)
        #endif
    }
    
    // MARK: - Client Lesson Packages
    func fetchClientPackages(clientId: String) async throws -> [LessonPackage] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users")
            .document(clientId)
            .collection("lessonPackages")
            .order(by: "purchaseDate", descending: true)
            .getDocuments()
        
        let packages: [LessonPackage] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let packageType = data["packageType"] as? String,
                let totalLessons = data["totalLessons"] as? Int,
                let lessonsUsed = data["lessonsUsed"] as? Int,
                let purchaseDateTs = data["purchaseDate"] as? Timestamp
            else {
                return nil
            }
            
            let expirationDate = (data["expirationDate"] as? Timestamp)?.dateValue()
            let transactionId = data["transactionId"] as? String
            
            return LessonPackage(
                id: doc.documentID,
                packageType: packageType,
                totalLessons: totalLessons,
                lessonsUsed: lessonsUsed,
                purchaseDate: purchaseDateTs.dateValue(),
                expirationDate: expirationDate,
                transactionId: transactionId
            )
        }
        return packages
        #else
        return []
        #endif
    }
    
    // MARK: - Admin Booking
    func adminBookLesson(trainerId: String, slotId: String, clientId: String, packageId: String) async throws {
        #if canImport(FirebaseFirestore)
        print("🔵 adminBookLesson: Start")
        let db = Firestore.firestore()
        
        print("🔵 Getting slot")
        // 1. Get the slot reference and data
        let slotRef = db.collection("trainers")
            .document(trainerId)
            .collection("schedules")
            .document(slotId)
        
        let slotSnap = try await slotRef.getDocument()
        guard let slotData = slotSnap.data(),
              let startTs = slotData["startTime"] as? Timestamp,
              let endTs = slotData["endTime"] as? Timestamp else {
            print("❌ Failed to get slot data")
            throw FirestoreServiceError.decoding
        }
        print("✅ Got slot data")
        
        print("🔵 Getting trainer name")
        // 2. Get trainer name
        let trainerSnap = try await db.collection("trainers").document(trainerId).getDocument()
        let trainerName = trainerSnap.data()?["name"] as? String ?? "Trainer"
        print("✅ Got trainer name: \(trainerName)")
        
        print("🔵 Getting client name")
        // 3. Get client name - create a local copy to avoid corruption
        let clientIdCopy = String(clientId)
        let clientRef = db.collection("users").document(clientIdCopy)
        let clientSnap = try await clientRef.getDocument()
        let clientData = clientSnap.data() ?? [:]
        let firstName = clientData["firstName"] as? String ?? ""
        let lastName = clientData["lastName"] as? String ?? ""
        let clientName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        print("✅ Got client name: \(clientName)")
        
        // 4. Create a batch
        print("🔵 Creating batch")
        let batch = db.batch()
        
        print("🔵 Adding booking to batch")
        // 5. Create the booking document with all required fields
        let bookingRef = db.collection("bookings").document()
        let packageIdCopy = String(packageId)
        batch.setData([
            "clientUID": clientIdCopy,
            "clientName": clientName,
            "trainerUID": trainerId,
            "trainerId": trainerId,
            "trainerName": trainerName,
            "startTime": startTs,
            "endTime": endTs,
            "status": "confirmed",
            "bookedAt": Timestamp(date: Date()),
            "packageId": packageIdCopy,
            "lessonPackageId": packageIdCopy,
            "scheduleSlotId": slotId,
            "slotId": slotId
        ], forDocument: bookingRef)
        
        print("🔵 Adding package update to batch")
        // 6. Increment the package lessons used
        let packageRef = db.collection("users")
            .document(clientIdCopy)
            .collection("lessonPackages")
            .document(packageIdCopy)
        
        batch.updateData([
            "lessonsUsed": FieldValue.increment(Int64(1))
        ], forDocument: packageRef)
        
        print("🔵 Updating slot status to booked")
        // 7. Update the slot to show it's booked
        batch.updateData([
            "status": "booked",
            "clientId": clientIdCopy,
            "clientName": clientName,
            "bookedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], forDocument: slotRef)
        
        print("🔵 Committing batch")
        // Commit all changes atomically
        try await batch.commit()
        
        print("✅ Admin booking created successfully:")
        print("   - bookingId: \(bookingRef.documentID)")
        print("   - clientName: \(clientName)")
        print("   - trainerName: \(trainerName)")
        print("   - slotId: \(slotId)")
        #else
        throw FirestoreServiceError.notAvailable
        #endif
    }
    
    // MARK: - Client Bookings
    func fetchClientBookings(clientId: String, upcoming: Bool) async throws -> [ClientBooking] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let now = Timestamp(date: Date())
        
        var query = db.collection("bookings")
            .whereField("clientUID", isEqualTo: clientId)
            .whereField("status", in: ["confirmed", "booked"])
        
        if upcoming {
            query = query.whereField("startTime", isGreaterThanOrEqualTo: now)
                .order(by: "startTime", descending: false)
        } else {
            query = query.whereField("startTime", isLessThan: now)
                .order(by: "startTime", descending: true)
        }
        
        let snapshot = try await query.limit(to: 20).getDocuments()
        
        let bookings: [ClientBooking] = await withTaskGroup(of: ClientBooking?.self) { group in
            for doc in snapshot.documents {
                group.addTask {
                    let data = doc.data()
                    guard
                        let trainerId = data["trainerId"] as? String,
                        let startTimeTs = data["startTime"] as? Timestamp,
                        let endTimeTs = data["endTime"] as? Timestamp,
                        let status = data["status"] as? String
                    else {
                        return nil
                    }
                    
                    let trainerName = data["trainerName"] as? String ?? "Unknown"
                    let bookedAt = (data["bookedAt"] as? Timestamp)?.dateValue()
                    let isClassBooking = data["isClassBooking"] as? Bool
                    let classId = data["classId"] as? String
                    let packageId = data["packageId"] as? String ?? data["lessonPackageId"] as? String
                    
                    // Fetch package type if packageId exists
                    var packageType: String? = nil
                    if let pkgId = packageId {
                        do {
                            let packageDoc = try await db.collection("users")
                                .document(clientId)
                                .collection("lessonPackages")
                                .document(pkgId)
                                .getDocument()
                            packageType = packageDoc.data()?["packageType"] as? String
                        } catch {
                            print("Failed to fetch package type: \(error)")
                        }
                    }
                    
                    return ClientBooking(
                        id: doc.documentID,
                        trainerId: trainerId,
                        trainerName: trainerName,
                        startTime: startTimeTs.dateValue(),
                        endTime: endTimeTs.dateValue(),
                        status: status,
                        bookedAt: bookedAt,
                        isClassBooking: isClassBooking,
                        classId: classId,
                        packageId: packageId,
                        packageType: packageType
                    )
                }
            }
            
            var results: [ClientBooking] = []
            for await booking in group {
                if let booking = booking {
                    results.append(booking)
                }
            }
            return results
        }
        
        return bookings
        #else
        return []
        #endif
    }
    
    // MARK: - Client Documents
    func fetchClientDocuments(clientId: String) async throws -> [ClientDocument] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users")
            .document(clientId)
            .collection("documents")
            .order(by: "uploadedAt", descending: true)
            .getDocuments()
        
        let documents: [ClientDocument] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let name = data["name"] as? String,
                let type = data["type"] as? String,
                let uploadedAtTs = data["uploadedAt"] as? Timestamp
            else {
                return nil
            }
            
            let url = data["url"] as? String
            
            return ClientDocument(
                id: doc.documentID,
                name: name,
                type: type,
                uploadedAt: uploadedAtTs.dateValue(),
                url: url
            )
        }
        return documents
        #else
        return []
        #endif
    }
}
