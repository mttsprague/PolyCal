//
//  FunctionsService.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum FunctionsServiceError: Error, LocalizedError {
    case notAvailable
    case unauthenticated
    case invalidResponse
    case server(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Firebase Functions is not available in this build."
        case .unauthenticated: return "Please sign in to continue."
        case .invalidResponse: return "Unexpected response from the server."
        case .server(_, let message): return message
        }
    }
}

struct BookLessonResult: Decodable {
    let message: String
    let bookingId: String?
}

struct ProcessAvailabilityResult: Decodable {
    let message: String
    let slotsAdded: Int?
}

final class FunctionsService {
    static let shared = FunctionsService()

    private init() {}

    // Change region if your functions are deployed elsewhere
    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions(region: "us-central1")
    #endif

    // MARK: - Calls

    func bookLesson(trainerId: String, slotId: String, lessonPackageId: String) async throws -> BookLessonResult {
        #if canImport(FirebaseFunctions)
        guard Auth.auth().currentUser != nil else { throw FunctionsServiceError.unauthenticated }

        let payload: [String: Any] = [
            "trainerId": trainerId,
            "slotId": slotId,
            "lessonPackageId": lessonPackageId
        ]

        do {
            let result = try await functions.httpsCallable("bookLesson").call(payload)
            guard let dict = result.data as? [String: Any],
                  let message = dict["message"] as? String else {
                throw FunctionsServiceError.invalidResponse
            }
            let bookingId = dict["bookingId"] as? String
            return BookLessonResult(message: message, bookingId: bookingId)
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                let code = error.code
                let message = error.localizedDescription
                throw FunctionsServiceError.server(code: code, message: message)
            }
            throw error
        }
        #else
        throw FunctionsServiceError.notAvailable
        #endif
    }

    func processTrainerAvailability(
        startDate: String? = nil,
        endDate: String? = nil,
        dailyStartHour: Int? = nil,
        dailyEndHour: Int? = nil,
        slotDurationMinutes: Int? = nil
    ) async throws -> ProcessAvailabilityResult {
        #if canImport(FirebaseFunctions)
        guard Auth.auth().currentUser != nil else { throw FunctionsServiceError.unauthenticated }

        var payload: [String: Any] = [:]
        if let startDate { payload["startDate"] = startDate }
        if let endDate { payload["endDate"] = endDate }
        if let dailyStartHour { payload["dailyStartHour"] = dailyStartHour }
        if let dailyEndHour { payload["dailyEndHour"] = dailyEndHour }
        if let slotDurationMinutes { payload["slotDurationMinutes"] = slotDurationMinutes }

        do {
            let result = try await functions.httpsCallable("processTrainerAvailability").call(payload)
            guard let dict = result.data as? [String: Any],
                  let message = dict["message"] as? String else {
                throw FunctionsServiceError.invalidResponse
            }
            let slotsAdded = dict["slotsAdded"] as? Int
            return ProcessAvailabilityResult(message: message, slotsAdded: slotsAdded)
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                let code = error.code
                let message = error.localizedDescription
                throw FunctionsServiceError.server(code: code, message: message)
            }
            throw error
        }
        #else
        throw FunctionsServiceError.notAvailable
        #endif
    }
}
