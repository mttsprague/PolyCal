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
        // Derived status (booked) will be inferred if clientId is set
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

    var isBooked: Bool { clientId != nil }

    var displayTitle: String {
        if isBooked {
            return clientName ?? "Booked"
        }
        switch status {
        case .open: return "Open"
        case .unavailable: return "Unavailable"
        }
    }

    var visualColor: Color {
        if isBooked { return .blue }
        switch status {
        case .open: return .green
        case .unavailable: return .red
        }
    }
}

