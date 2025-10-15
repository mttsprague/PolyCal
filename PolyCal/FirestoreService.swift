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

        // We still query by startTime where possible; this will include all documents
        // that have startTime populated. We will also attempt to decode documents that
        // might be missing those fields by parsing the document ID formats.
        let snapshot = try await db.collection("trainers")
            .document(trainerId)
            .collection("schedules")
            .whereField("startTime", isGreaterThanOrEqualTo: startTs)
            .whereField("startTime", isLessThan: endTs)
            .order(by: "startTime")
            .getDocuments()

        var slots: [TrainerScheduleSlot] = snapshot.documents.compactMap { doc in
            decodeScheduleDoc(trainerId: trainerId, doc: doc)
        }

        // Additionally, fetch any docs in range that might not have startTime set (legacy or new minimal docs).
        // Firestore can’t query by ID range directly, so we perform a second pass: fetch the whole week collection
        // and locally filter by parsed ID. This keeps the first query efficient for normal cases.
        let weekAllSnap = try await db.collection("trainers")
            .document(trainerId)
            .collection("schedules")
            .getDocuments()

        let extra = weekAllSnap.documents.compactMap { doc -> TrainerScheduleSlot? in
            // Skip if already included above
            if slots.contains(where: { $0.id == doc.documentID }) { return nil }
            guard let parsed = parseDocId(doc.documentID) else { return nil }
            // Keep only those in range [from, to)
            guard parsed.start >= from && parsed.start < to else { return nil }
            return decodeScheduleDoc(trainerId: trainerId, doc: doc, fallback: parsed)
        }

        slots.append(contentsOf: extra)
        // Sort by start time for stable display
        slots.sort { $0.startTime < $1.startTime }
        return slots
        #else
        // No Firestore in this build; return empty to keep app usable
        return []
        #endif
    }

    // Attempt to decode a schedule document. If fields are missing, use fallback parsed from doc ID (if provided).
    #if canImport(FirebaseFirestore)
    private func decodeScheduleDoc(trainerId: String, doc: QueryDocumentSnapshot, fallback: (start: Date, end: Date)? = nil) -> TrainerScheduleSlot? {
        let data = doc.data()

        // Status (default to open if absent)
        let status: TrainerScheduleSlot.Status = {
            if let raw = data["status"] as? String, let s = TrainerScheduleSlot.Status(rawValue: raw) {
                return s
            } else {
                return .open
            }
        }()

        // Start/End
        let startDate: Date? = (data["startTime"] as? Timestamp)?.dateValue() ?? fallback?.start
        let endDate: Date? = (data["endTime"] as? Timestamp)?.dateValue() ?? fallback?.end

        guard let start = startDate, let end = endDate else {
            // Try to parse from doc ID if no explicit fallback was provided
            if fallback == nil, let parsed = parseDocId(doc.documentID) {
                return TrainerScheduleSlot(
                    id: doc.documentID,
                    trainerId: trainerId,
                    status: status,
                    startTime: parsed.start,
                    endTime: parsed.end,
                    clientId: data["clientId"] as? String,
                    clientName: data["clientName"] as? String,
                    bookedAt: (data["bookedAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                )
            }
            return nil
        }

        return TrainerScheduleSlot(
            id: doc.documentID,
            trainerId: trainerId,
            status: status,
            startTime: start,
            endTime: end,
            clientId: data["clientId"] as? String,
            clientName: data["clientName"] as? String,
            bookedAt: (data["bookedAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
    #endif

    // Parse known document ID formats into start/end dates (UTC):
    // - New: "YYYY-MM-DDTHH" (hour slot)
    // - Old: "<startEpochMillis>-<endEpochMillis>"
    private func parseDocId(_ id: String) -> (start: Date, end: Date)? {
        // New format: 2025-10-15T20
        if id.count == 13, id[id.index(id.startIndex, offsetBy: 10)] == "T" {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            let parts = id.split(separator: "T")
            if parts.count == 2 {
                let datePart = parts[0] // YYYY-MM-DD
                let hourPart = parts[1] // HH
                let datePieces = datePart.split(separator: "-")
                if datePieces.count == 3, let y = Int(datePieces[0]), let m = Int(datePieces[1]), let d = Int(datePieces[2]), let h = Int(hourPart) {
                    var comps = DateComponents()
                    comps.year = y; comps.month = m; comps.day = d; comps.hour = h
                    if let start = calendar.date(from: comps), let end = calendar.date(byAdding: .hour, value: 1, to: start) {
                        return (start, end)
                    }
                }
            }
        }

        // Old format: 1761080400000-1761084000000
        let parts = id.split(separator: "-")
        if parts.count == 2, let startMs = Double(parts[0]), let endMs = Double(parts[1]) {
            let start = Date(timeIntervalSince1970: startMs / 1000.0)
            let end = Date(timeIntervalSince1970: endMs / 1000.0)
            return (start, end)
        }

        return nil
    }

    // MARK: - Schedule (write APIs)
    // Deterministic document ID per trainer per startTime (UTC, hour resolution)
    private func scheduleDocId(for start: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: start)
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
            return Client(
                id: doc.documentID,
                firstName: firstName,
                lastName: lastName,
                emailAddress: emailAddress,
                phoneNumber: phoneNumber,
                photoURL: photoURL
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
        return Client(
            id: snap.documentID,
            firstName: firstName,
            lastName: lastName,
            emailAddress: emailAddress,
            phoneNumber: phoneNumber,
            photoURL: photoURL
        )
        #else
        return Client(id: "client_demo", firstName: "Alex", lastName: "Smith", emailAddress: "alex@example.com", phoneNumber: "555-123-4567", photoURL: nil)
        #endif
    }
}

