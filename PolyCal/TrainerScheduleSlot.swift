//
//  TrainerScheduleSlot.swift
//  PolyCal
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation
import SwiftUI

struct TrainerScheduleSlot: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case open
        case unavailable
        case booked
    }

    var id: String
    var trainerId: String
    var status: Status
    var startTime: Date
    var endTime: Date
    var clientId: String?
    var clientName: String?
    var bookedAt: Date?
    var updatedAt: Date? // Added to match schema
    var isClassBooking: Bool? // NEW: Indicates this is a class booking
    var classId: String? // NEW: Reference to the class document

    // Consider a slot booked if the backend sets status to "booked" OR if clientId is present.
    var isBooked: Bool { status == .booked || clientId != nil }
    
    // Check if this is a class
    var isClass: Bool { isClassBooking == true }

    var displayTitle: String {
        if isClass {
            return clientName ?? "Group Class"
        }
        if isBooked {
            return clientName ?? "Booked"
        }
        switch status {
        case .open: return "Open"
        case .unavailable: return "Unavailable"
        case .booked: return clientName ?? "Booked"
        }
    }

    var visualColor: Color {
        if isClass { return .orange }
        if isBooked { return .blue }
        switch status {
        case .open: return .green
        case .unavailable: return .red
        case .booked: return .blue
        }
    }
}

