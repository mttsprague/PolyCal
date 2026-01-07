//
//  LessonPackage.swift
//  PolyCal
//
//  Created by GitHub Copilot
//

import Foundation

struct LessonPackage: Identifiable, Codable {
    var id: String
    var packageType: String
    var totalLessons: Int
    var lessonsUsed: Int
    var purchaseDate: Date
    var expirationDate: Date?
    var transactionId: String?
    
    var lessonsRemaining: Int {
        max(0, totalLessons - lessonsUsed)
    }
    
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return expiration < Date()
    }
    
    var packageDisplayName: String {
        switch packageType {
        case "single": return "Single Lesson"
        case "private": return "Private Lesson"
        case "two_athlete", "2_athlete": return "2 Athletes"
        case "three_athlete", "3_athlete": return "3 Athletes"
        case "class_pass": return "Class Pass"
        default: return packageType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    var statusText: String {
        if isExpired {
            return "Expired"
        } else if lessonsRemaining == 0 {
            return "Used"
        } else {
            return "\(lessonsRemaining) of \(totalLessons) remaining"
        }
    }
    
    var statusColor: String {
        if isExpired || lessonsRemaining == 0 {
            return "secondary"
        } else if lessonsRemaining <= 1 {
            return "orange"
        } else {
            return "green"
        }
    }
}

struct ClientBooking: Identifiable, Codable {
    var id: String
    var trainerId: String
    var trainerName: String
    var startTime: Date
    var endTime: Date
    var status: String
    var bookedAt: Date?
    var isClassBooking: Bool?
    var classId: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var duration: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute {
            return "\(minutes)m"
        }
        return "1h"
    }
}

struct ClientDocument: Identifiable, Codable {
    var id: String
    var name: String
    var type: String
    var uploadedAt: Date
    var url: String?
    
    var displayName: String {
        switch type {
        case "waiver": return "Waiver"
        case "medical": return "Medical Form"
        case "emergency_contact": return "Emergency Contact"
        default: return name
        }
    }
    
    var icon: String {
        switch type {
        case "waiver": return "doc.text.fill"
        case "medical": return "cross.circle.fill"
        case "emergency_contact": return "phone.circle.fill"
        default: return "doc.fill"
        }
    }
}
